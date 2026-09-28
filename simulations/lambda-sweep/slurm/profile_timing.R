#!/usr/bin/env Rscript
# =============================================================================
# profile_timing.R -- size the cluster job array
# =============================================================================
# Adapted from simulations/canonical-validation/slurm/profile_timing.R, with the
# lesson that study learned the hard way made STRUCTURAL rather than advisory.
#
# WHY THE DEFAULT MODE IS --from-smoke-dir, NOT LOCAL PROFILING.
# canonical-validation sized its array from a LOCAL profile of 4 units: median
# 61.409 s/unit (see its config/sizing.json). The units actually took 191.8-254.6
# s/unit on O2 -- a ~3.8x underestimate. Sizing off a local number is therefore
# not conservative, it is wrong in the dangerous direction: it under-requests
# --time and every task dies at the wall clock having flushed only part of its
# block. So the supported path is:
#
#     bash slurm/submit.sh --smoke 8        # REAL sbatch array, real nodes
#     Rscript slurm/profile_timing.R --from-smoke-dir <smoke scratch> --target-hours 2
#     bash slurm/submit.sh
#
# Sizing uses a HIGH QUANTILE (default 0.9) of the observed per-unit seconds, not
# the median: a task's wall time is the SUM of its block, so the binding risk is
# the expensive tail of the cost distribution (dgp1 ran ~1.6x dgp5 locally), and
# the smoke probe deliberately straddles that spread (see submit.sh --smoke).
#
# --local is retained for plumbing checks only and REFUSES to write sizing files
# unless --i-know-local-underestimates-o2 is also passed.
#
# O2 limits respected: <=1000 tasks/array, <=10000 jobs queued at once.
# Writes config/sizing.env (KEY=VALUE, sourced by submit.sh) and config/sizing.json.
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

# --- O2 scheduler limits (named constants; edit only if O2 policy changes) ----
MAX_ARRAY_SIZE      <- 1000L    # max tasks in a single --array
MAX_CONCURRENT_JOBS <- 10000L   # max jobs queued across all arrays at once
WALL_MIN_HOURS      <- 1        # target window lower bound
WALL_MAX_HOURS      <- 3        # target window upper bound
TIME_SAFETY         <- 1.5      # --time headroom; matches canonical-validation
MEM_SAFETY          <- 1.5
MEM_FLOOR_GB        <- 2L

option_list <- list(
  make_option("--study-dir", type = "character", dest = "study_dir", default = "..",
              help = "Path to study dir (contains config/, R/) [default %default]"),
  make_option("--from-smoke-dir", type = "character", dest = "smoke_dir", default = NULL,
              help = "Scratch dir of a REAL O2 smoke run; sizes from its unit partials"),
  make_option("--local", action = "store_true", dest = "local", default = FALSE,
              help = "Profile locally (PLUMBING ONLY -- underestimates O2, see header)"),
  make_option("--i-know-local-underestimates-o2", action = "store_true",
              dest = "force_local", default = FALSE,
              help = "Permit --local sizing to be written anyway"),
  make_option("--n-units", type = "integer", dest = "n_units_probe", default = 8L,
              help = "Units to time under --local [default %default]"),
  make_option("--target-hours", type = "double", dest = "target_hours", default = 2,
              help = "Target wall time per task in hours, within [1,3] [default %default]"),
  make_option("--quantile", type = "double", dest = "quantile", default = 0.9,
              help = "Quantile of per-unit seconds used for sizing [default %default]"),
  make_option("--rep-from", type = "integer", dest = "rep_from", default = 1L,
              help = "First replication id in the executed scope [default %default]"),
  make_option("--rep-to", type = "integer", dest = "rep_to", default = 20L,
              help = "Last replication id in the executed scope [default %default]")
)
opt <- parse_args(OptionParser(option_list = option_list))

if (is.null(opt$smoke_dir) && !isTRUE(opt$local)) {
  stop(paste0("Give either --from-smoke-dir <dir> (a real O2 smoke run; the supported\n",
              "  path) or --local (plumbing only). See this script's header for why a\n",
              "  local number must not size an O2 array."))
}

target_hours <- min(max(opt$target_hours, WALL_MIN_HOURS), WALL_MAX_HOURS)
if (target_hours != opt$target_hours) {
  cat(sprintf("NOTE: target-hours clamped to [%g, %g] -> %g\n",
              WALL_MIN_HOURS, WALL_MAX_HOURS, target_hours))
}

source(file.path(opt$study_dir, "config", "grid.R"))

if (opt$rep_to > TOTAL_REPS) {
  stop(sprintf("--rep-to %d exceeds TOTAL_REPS %d in config/grid.R.", opt$rep_to, TOTAL_REPS))
}
ut <- unit_table()
total_units <- sum(ut$rep_id >= opt$rep_from & ut$rep_id <= opt$rep_to)
cat(sprintf("Rep scope %d-%d of %d declared -> %d in-scope work units (%d configs).\n",
            opt$rep_from, opt$rep_to, TOTAL_REPS, total_units, nrow(GRID)))

# =============================================================================
# Source of the per-unit timings
# =============================================================================
peak_gb <- NA_real_
timing_source <- NULL
per_unit_secs <- numeric(0)
probe_detail  <- NULL

if (!is.null(opt$smoke_dir)) {
  # --- REAL O2 timings, read from the smoke run's per-unit partials -----------
  pdir <- file.path(opt$smoke_dir, "partials")
  if (!dir.exists(pdir)) stop(sprintf("no partials/ under %s -- did the smoke array run?", pdir))
  pf <- list.files(pdir, pattern = "^unit_[0-9]+[.]rds$", full.names = TRUE)
  if (!length(pf)) stop(sprintf("no unit_*.rds in %s -- smoke array produced nothing.", pdir))
  rows <- lapply(pf, readRDS)
  d <- do.call(rbind, lapply(rows, function(r)
    r[, c("unit", "dgp", "lambda", "secs", "M_final", "converged", "error_msg",
          "r_version", "pkg_version", "backend")]))

  n_err <- sum(!is.na(d$error_msg))
  if (n_err == nrow(d)) {
    stop(sprintf(paste0("All %d smoke units FAILED; refusing to size off failed runs.\n",
                        "  first error: %s"), nrow(d), d$error_msg[1]))
  }
  if (n_err > 0) {
    cat(sprintf("WARNING: %d/%d smoke units errored; sizing off the %d that succeeded.\n",
                n_err, nrow(d), nrow(d) - n_err))
  }
  d <- d[is.na(d$error_msg) & !is.na(d$secs), , drop = FALSE]
  if (!nrow(d)) stop("no smoke unit produced a usable `secs`.")
  if (!all(d$backend == "o2_slurm")) {
    stop("smoke partials are not all backend='o2_slurm' -- this mode requires REAL cluster timings.")
  }

  per_unit_secs <- d$secs
  timing_source <- sprintf("o2_smoke_array:%s", basename(normalizePath(opt$smoke_dir, mustWork = FALSE)))
  probe_detail  <- d[order(-d$secs), c("unit", "dgp", "lambda", "secs", "M_final")]
  cat("\nREAL O2 per-unit wall time, slowest first:\n")
  print(data.frame(unit = probe_detail$unit, dgp = probe_detail$dgp,
                   lambda = probe_detail$lambda,
                   secs = round(probe_detail$secs, 1),
                   M_final = probe_detail$M_final), row.names = FALSE)
  cat(sprintf("R %s | %s %s | backend %s\n",
              d$r_version[1], "surrogateTransportability", d$pkg_version[1], d$backend[1]))
} else {
  # --- LOCAL profiling (plumbing only) ---------------------------------------
  source(file.path(opt$study_dir, "R", "cell_cates.R"))
  source(file.path(opt$study_dir, "R", "dgp.R"))
  source(file.path(opt$study_dir, "R", "estimators.R"))
  source(file.path(opt$study_dir, "R", "run_one.R"))
  library(surrogateTransportability)
  library(mgcv); library(ranger)

  target <- ut[ut$rep_id >= opt$rep_from & ut$rep_id <= opt$rep_to, , drop = FALSE]
  target <- target[order(target$unit), , drop = FALSE]
  n_probe <- min(opt$n_units_probe, nrow(target))
  # Spread probes across the table: it is config-major, so the first n rows are
  # all one (dgp, lambda) cell and would never exercise the others.
  probe_idx <- unique(round(seq(1, nrow(target), length.out = n_probe)))
  cat(sprintf("LOCAL profiling %d of %d in-scope units...\n", length(probe_idx), nrow(target)))

  invisible(gc(reset = TRUE))
  per_unit_secs <- numeric(length(probe_idx))
  n_degenerate <- 0L
  for (i in seq_along(probe_idx)) {
    res <- NULL
    t <- system.time(res <- run_one(target[probe_idx[i], , drop = FALSE]))
    per_unit_secs[i] <- unname(t[["elapsed"]])
    if (is.null(res) || !("estimate" %in% names(res)) || all(is.na(res$estimate))) {
      n_degenerate <- n_degenerate + 1L
    }
  }
  if (n_degenerate == length(probe_idx)) {
    stop("All probe units produced only NA estimates; refusing to size off failed runs.")
  }
  gcinfo <- gc()
  peak_gb <- sum(gcinfo[, ncol(gcinfo)]) / 1024
  timing_source <- "local_profile"
  if (!isTRUE(opt$force_local)) {
    cat(sprintf("\nLocal per-unit: median %.1f s, q%g %.1f s, peak %.2f GB\n",
                median(per_unit_secs), opt$quantile,
                unname(quantile(per_unit_secs, opt$quantile)), peak_gb))
    stop(paste0("Refusing to WRITE sizing from a local profile.\n",
                "  canonical-validation's local median (61.4 s/unit) was ~3.8x below the\n",
                "  191.8-254.6 s/unit it actually saw on O2. Run a real probe instead:\n",
                "    bash slurm/submit.sh --smoke 8\n",
                "  Then size from it with --from-smoke-dir <smoke scratch>.\n",
                "  (Pass --i-know-local-underestimates-o2 to override deliberately.)"))
  }
}

# =============================================================================
# Sizing math
# =============================================================================
q_secs   <- unname(quantile(per_unit_secs, opt$quantile, type = 7))
med_secs <- median(per_unit_secs)
max_secs_obs <- max(per_unit_secs)
size_secs <- q_secs                       # the per-unit figure sizing is based on

cat(sprintf("\nPer-unit seconds (n=%d): median %.1f | q%g %.1f | max %.1f\n",
            length(per_unit_secs), med_secs, opt$quantile, q_secs, max_secs_obs))
cat(sprintf("Sizing on q%g = %.1f s/unit (task wall time is the SUM of a block, so the\n",
            opt$quantile, size_secs))
cat("  expensive tail binds, not the centre).\n")
if (size_secs <= 0) stop("Non-positive per-unit time; cannot size jobs.")

target_secs <- target_hours * 3600
max_secs    <- WALL_MAX_HOURS * 3600

reps_per_job <- max(1L, min(as.integer(floor(target_secs / size_secs)), total_units))
total_tasks  <- as.integer(ceiling(total_units / reps_per_job))

if (total_tasks > MAX_CONCURRENT_JOBS) {
  reps_needed <- as.integer(ceiling(total_units / MAX_CONCURRENT_JOBS))
  wall_at_needed <- reps_needed * size_secs
  if (wall_at_needed <= max_secs) {
    reps_per_job <- reps_needed
    total_tasks  <- as.integer(ceiling(total_units / reps_per_job))
    cat(sprintf("Packed to %d reps/job to keep total tasks <= %d (wall ~%.2f hr)\n",
                reps_per_job, MAX_CONCURRENT_JOBS, wall_at_needed / 3600))
  } else {
    reps_per_job <- max(1L, floor(max_secs / size_secs))
    total_tasks  <- as.integer(ceiling(total_units / reps_per_job))
    cat(sprintf("WARNING: cannot fit <= %d jobs within %g hr; %d reps/job, %d tasks -> WAVES.\n",
                MAX_CONCURRENT_JOBS, WALL_MAX_HOURS, reps_per_job, total_tasks))
  }
}

n_arrays <- as.integer(ceiling(total_tasks / MAX_ARRAY_SIZE))
concurrency_cap <- min(MAX_ARRAY_SIZE, MAX_CONCURRENT_JOBS)

est_task_secs <- reps_per_job * size_secs
walltime_secs <- max(ceiling(est_task_secs * TIME_SAFETY), 600)

fmt_slurm_time <- function(secs) {
  secs <- as.integer(ceiling(secs))
  d <- secs %/% 86400; secs <- secs %% 86400
  h <- secs %/% 3600;  secs <- secs %% 3600
  m <- secs %/% 60;    s <- secs %% 60
  sprintf("%d-%02d:%02d:%02d", d, h, m, s)
}
walltime <- fmt_slurm_time(walltime_secs)

# Memory. A smoke run gives real wall time but not peak RSS (R cannot read a
# finished job's high-water mark from its result row), so under --from-smoke-dir
# fall back to the MEM_FLOOR unless a local profile measured more. The local
# profile of this study peaked at ~0.6 GB, matching canonical-validation's 0.589
# GB at the same n and sampler settings, and that study ran 4000 units at --mem 2G
# with no OOM -- so the floor is evidence-backed here, not a guess.
mem_gb <- if (is.na(peak_gb)) MEM_FLOOR_GB else max(MEM_FLOOR_GB, as.integer(ceiling(peak_gb * MEM_SAFETY)))

cat("\n===== SIZING =====\n")
cat(sprintf("timing source    : %s\n", timing_source))
cat(sprintf("rep scope        : reps %d-%d\n", opt$rep_from, opt$rep_to))
cat(sprintf("total_units      : %d\n", total_units))
cat(sprintf("secs/unit (q%g)  : %.1f\n", opt$quantile, size_secs))
cat(sprintf("reps_per_job     : %d\n", reps_per_job))
cat(sprintf("total_tasks      : %d\n", total_tasks))
cat(sprintf("tasks_per_array  : <= %d (%d array(s))\n", MAX_ARRAY_SIZE, n_arrays))
cat(sprintf("concurrency_cap  : %d\n", concurrency_cap))
cat(sprintf("est wall / task  : %.2f hr (%.2f hr with %gx safety)\n",
            est_task_secs / 3600, walltime_secs / 3600, TIME_SAFETY))
cat(sprintf("--time           : %s\n", walltime))
cat(sprintf("--mem            : %dG\n", mem_gb))
cat("==================\n\n")

config_dir <- file.path(opt$study_dir, "config")
dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)

writeLines(c(
  sprintf("TOTAL_UNITS=%d", total_units),
  sprintf("REPS_PER_JOB=%d", reps_per_job),
  sprintf("TOTAL_TASKS=%d", total_tasks),
  sprintf("MAX_ARRAY_SIZE=%d", MAX_ARRAY_SIZE),
  sprintf("MAX_CONCURRENT_JOBS=%d", MAX_CONCURRENT_JOBS),
  sprintf("N_ARRAYS=%d", n_arrays),
  sprintf("CONCURRENCY_CAP=%d", concurrency_cap),
  sprintf("WALLTIME=%s", walltime),
  sprintf("MEM_GB=%d", mem_gb),
  sprintf("REP_FROM=%d", opt$rep_from),
  sprintf("REP_TO=%d", opt$rep_to)
), file.path(config_dir, "sizing.env"))

probe_json <- if (is.null(probe_detail)) "null" else paste0("[\n",
  paste(sprintf('    {"unit": %d, "dgp": "%s", "lambda": %g, "secs": %.1f, "M_final": %s}',
                probe_detail$unit, probe_detail$dgp, probe_detail$lambda,
                probe_detail$secs, probe_detail$M_final), collapse = ",\n"),
  "\n  ]")

writeLines(sprintf(
'{
  "study": "%s",
  "timing_source": "%s",
  "rep_from": %d,
  "rep_to": %d,
  "profiled_units": %d,
  "sizing_quantile": %g,
  "secs_per_unit_sizing": %.3f,
  "median_secs_per_unit": %.3f,
  "max_secs_per_unit_observed": %.3f,
  "peak_gb": %s,
  "target_hours": %g,
  "time_safety": %g,
  "total_units": %d,
  "reps_per_job": %d,
  "total_tasks": %d,
  "max_array_size": %d,
  "max_concurrent_jobs": %d,
  "n_arrays": %d,
  "concurrency_cap": %d,
  "est_task_hours": %.3f,
  "walltime": "%s",
  "mem_gb": %d,
  "probe_units": %s
}',
  STUDY_NAME, timing_source, opt$rep_from, opt$rep_to, length(per_unit_secs),
  opt$quantile, size_secs, med_secs, max_secs_obs,
  if (is.na(peak_gb)) "null" else sprintf("%.3f", peak_gb),
  target_hours, TIME_SAFETY, total_units, reps_per_job, total_tasks,
  MAX_ARRAY_SIZE, MAX_CONCURRENT_JOBS, n_arrays, concurrency_cap,
  est_task_secs / 3600, walltime, mem_gb, probe_json),
  file.path(config_dir, "sizing.json"))

cat(sprintf("Wrote %s and %s\n",
            file.path(config_dir, "sizing.env"),
            file.path(config_dir, "sizing.json")))
