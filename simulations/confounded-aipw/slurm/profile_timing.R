#!/usr/bin/env Rscript
# =============================================================================
# profile_timing.R -- size the cluster job arrays, ONE SIZING PER COST STRATUM
# =============================================================================
# Adapted from simulations/lambda-sweep/slurm/profile_timing.R, with two lessons
# made structural rather than advisory.
#
# LESSON 1 -- NEVER SIZE FROM A LOCAL PROFILE. canonical-validation sized its
# array from a LOCAL profile of 4 units (median 61.409 s/unit, see its
# config/sizing.json) and the units actually took 191.8-254.6 s/unit on O2, a
# ~3.8x underestimate in the direction that times out every task. So the default
# and supported mode is --from-smoke-dir, reading a REAL sbatch array's partials.
# --local is retained for plumbing checks and REFUSES to write sizing files unless
# --i-know-local-underestimates-o2 is also passed.
#
# LESSON 2 -- A SMALL SMOKE SAMPLE UNDERSTATES THE TAIL, SO SIZE ON THE MAX.
# lambda-sweep's 8-unit smoke probe measured q0.9 = 85.2 s and max = 85.7 s; the
# full 720-unit run came in at q0.9 = 118.5 s (1.4x higher) and max = 269.2 s
# (3.1x higher). Its 1.5x TIME_SAFETY is the only reason no task timed out. This
# script therefore defaults to --quantile 1.0 (the MAX observed per-unit time)
# whenever the probe has fewer than MIN_UNITS_FOR_QUANTILE units, instead of a
# q0.9 that a handful of observations cannot estimate, and keeps TIME_SAFETY at
# 1.5 on top of that. Both choices are recorded in sizing.json.
#
# PER-STRATUM SIZING. config/grid.R's stratum_of() exists because per-unit cost
# differs by ~2 orders of magnitude between n = 10,000 and n = 250. Blending them
# into one number would either time out large_n or waste wall clock on small_n, so
# each stratum is sized from ITS OWN probe units and gets its own row in
# config/sizing.tsv. A stratum with no probe units is an error, not a silent
# extrapolation from the other stratum.
#
# MEMORY IS MEASURED, NOT FLOORED. run_replication.R reads /proc/self/status's
# VmHWM (the kernel's high-water mark) after every unit and stamps it on the
# result row, so --mem comes from observation. If the column is absent or all-NA
# (e.g. a non-Linux plumbing run) the MEM_FLOOR is used and sizing.json records
# that the figure was not measured.
#
# O2 limits respected: <=1000 tasks/array, <=10000 jobs queued at once.
# Writes config/sizing.tsv (one row per stratum, read by submit.sh),
# config/sizing_totals.env, and config/sizing.json.
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

# --- O2 scheduler limits (named constants; edit only if O2 policy changes) ----
MAX_ARRAY_SIZE      <- 1000L    # max tasks in a single --array
MAX_CONCURRENT_JOBS <- 10000L   # max jobs queued across all arrays at once
WALL_MIN_HOURS      <- 1        # target window lower bound
WALL_MAX_HOURS      <- 3        # target window upper bound
TIME_SAFETY         <- 1.5      # --time headroom; a FLOOR, see LESSON 2
MEM_SAFETY          <- 1.5
MEM_FLOOR_GB        <- 2L
# Below this many probe units in a stratum, a q0.9 is not estimable from the
# sample; size on the max instead. lambda-sweep's n=8 probe is exactly this case.
MIN_UNITS_FOR_QUANTILE <- 20L

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
  make_option("--n-units", type = "integer", dest = "n_units_probe", default = 4L,
              help = "Units per stratum to time under --local [default %default]"),
  make_option("--target-hours", type = "double", dest = "target_hours", default = 2,
              help = "Target wall time per task in hours, within [1,3] [default %default]"),
  make_option("--quantile", type = "double", dest = "quantile", default = NA_real_,
              help = paste("Quantile of per-unit seconds used for sizing. Default:",
                           "1.0 (max) when a stratum has fewer than",
                           MIN_UNITS_FOR_QUANTILE, "probe units, else 0.9."))
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

suppressPackageStartupMessages(library(surrogateTransportability))
source(file.path(opt$study_dir, "R", "dgp.R"))
source(file.path(opt$study_dir, "config", "grid.R"))

ut <- unit_table()
ut$stratum <- stratum_of(ut)
strata <- sort(unique(ut$stratum))
units_by_stratum <- table(ut$stratum)
cat(sprintf("Grid: %d configs, %d units total. Strata: %s\n",
            nrow(GRID), nrow(ut),
            paste(sprintf("%s=%d", names(units_by_stratum),
                          as.integer(units_by_stratum)), collapse = " ")))

# =============================================================================
# Source of the per-unit timings
# =============================================================================
timing_source <- NULL
probe <- NULL     # data frame: stratum, unit, dgp, method, n, secs, peak_rss_gb, M_final

if (!is.null(opt$smoke_dir)) {
  # --- REAL O2 timings, read from the smoke run's per-unit partials -----------
  pdir <- file.path(opt$smoke_dir, "partials")
  if (!dir.exists(pdir)) stop(sprintf("no partials/ under %s -- did the smoke array run?", pdir))
  pf <- list.files(pdir, pattern = "^unit_[0-9]+[.]rds$", full.names = TRUE)
  if (!length(pf)) stop(sprintf("no unit_*.rds in %s -- smoke array produced nothing.", pdir))
  rows <- lapply(pf, readRDS)
  keep <- c("unit", "stratum", "block", "dgp", "dgp_kind", "n", "method", "secs",
            "peak_rss_gb", "M_final", "converged", "n_clipped", "estimate",
            "error_msg", "r_version", "pkg_version", "backend")
  d <- do.call(rbind, lapply(rows, function(r) {
    for (k in setdiff(keep, names(r))) r[[k]] <- NA
    r[, keep, drop = FALSE]
  }))

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
  # A degenerate probe (all-NA estimates) means the science failed even though the
  # plumbing did not; sizing off ~0 s timings would be worse than refusing.
  if (all(is.na(d$estimate))) {
    stop("every successful smoke unit returned an all-NA `estimate`; refusing to size off a degenerate probe.")
  }
  probe <- d
  timing_source <- sprintf("o2_smoke_array:%s",
                           basename(normalizePath(opt$smoke_dir, mustWork = FALSE)))

  cat("\nREAL O2 per-unit wall time, slowest first:\n")
  pr <- probe[order(-probe$secs), ]
  print(data.frame(unit = pr$unit, stratum = pr$stratum, block = pr$block,
                   dgp = pr$dgp, n = pr$n, method = pr$method,
                   secs = round(pr$secs, 1),
                   peak_gb = round(pr$peak_rss_gb, 2),
                   M_final = pr$M_final, clipped = pr$n_clipped),
        row.names = FALSE)
  cat(sprintf("R %s | surrogateTransportability %s | backend %s\n",
              probe$r_version[1], probe$pkg_version[1], probe$backend[1]))

  # --- The IW-vs-AIPW question, answered rather than assumed -----------------
  # The AIPW arm fits five nuisances per replication that the IW arm never fits.
  # Whether that materially changes SIZING (as opposed to merely being slower) is
  # a per-stratum empirical question, so report it explicitly.
  cat("\nPer-unit seconds by stratum x method (the AIPW-nuisance cost question):\n")
  agg <- aggregate(secs ~ stratum + method, data = probe,
                   FUN = function(x) c(n = length(x), med = median(x), max = max(x)))
  flat <- do.call(rbind, lapply(seq_len(nrow(agg)), function(i) data.frame(
    stratum = agg$stratum[i], method = agg$method[i],
    n = agg$secs[i, "n"], median_secs = round(agg$secs[i, "med"], 1),
    max_secs = round(agg$secs[i, "max"], 1))))
  print(flat, row.names = FALSE)
  for (s in unique(flat$stratum)) {
    f <- flat[flat$stratum == s, ]
    if (nrow(f) == 2L) {
      ratio <- max(f$median_secs) / min(f$median_secs)
      cat(sprintf("  stratum %-8s AIPW/IW median cost ratio = %.2fx %s\n", s, ratio,
                  if (ratio >= 1.25) "-- MATERIAL for sizing" else
                    "-- immaterial; one array per stratum is fine"))
    }
  }
} else {
  # --- LOCAL profiling (plumbing only) ---------------------------------------
  source(file.path(opt$study_dir, "R", "estimators.R"))
  source(file.path(opt$study_dir, "R", "run_one.R"))
  library(mgcv); library(ranger)

  pieces <- list()
  for (s in strata) {
    t <- ut[ut$stratum == s, , drop = FALSE]
    t <- t[order(t$unit), , drop = FALSE]
    n_probe <- min(opt$n_units_probe, nrow(t))
    # Spread probes across the stratum: it is config-major, so the first n rows
    # are all one (dgp, method) cell and would never exercise the others.
    idx <- unique(round(seq(1, nrow(t), length.out = n_probe)))
    cat(sprintf("LOCAL profiling %d of %d units in stratum %s...\n",
                length(idx), nrow(t), s))
    for (i in idx) {
      res <- NULL
      tm <- system.time(res <- run_one(t[i, , drop = FALSE]))
      pieces[[length(pieces) + 1L]] <- data.frame(
        unit = t$unit[i], stratum = s, block = t$block[i], dgp = t$dgp[i],
        dgp_kind = t$dgp_kind[i], n = t$n[i], method = t$method[i],
        secs = unname(tm[["elapsed"]]), peak_rss_gb = NA_real_,
        M_final = if (!is.null(res)) res$M_final else NA_integer_,
        converged = NA_integer_, n_clipped = NA_integer_,
        estimate = if (!is.null(res)) res$estimate else NA_real_,
        error_msg = NA_character_,
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        pkg_version = as.character(utils::packageVersion("surrogateTransportability")),
        backend = "local_driver", stringsAsFactors = FALSE)
    }
  }
  probe <- do.call(rbind, pieces)
  if (all(is.na(probe$estimate))) {
    stop("All probe units produced only NA estimates; refusing to size off failed runs.")
  }
  timing_source <- "local_profile"
  if (!isTRUE(opt$force_local)) {
    for (s in strata) {
      v <- probe$secs[probe$stratum == s]
      cat(sprintf("\nLocal stratum %-8s per-unit: median %.1f s, max %.1f s (n=%d)\n",
                  s, median(v), max(v), length(v)))
    }
    stop(paste0("Refusing to WRITE sizing from a local profile.\n",
                "  canonical-validation's local median (61.4 s/unit) was ~3.8x below the\n",
                "  191.8-254.6 s/unit it actually saw on O2. Run a real probe instead:\n",
                "    bash slurm/submit.sh --smoke\n",
                "  Then size from it with --from-smoke-dir <smoke scratch>.\n",
                "  (Pass --i-know-local-underestimates-o2 to override deliberately.)"))
  }
}

# Every stratum in the grid must have been probed: extrapolating one stratum's
# cost onto the other is exactly the mistake stratum_of() exists to prevent.
missing_strata <- setdiff(strata, unique(probe$stratum))
if (length(missing_strata)) {
  stop(sprintf(paste0("no usable probe units for stratum/strata: %s.\n",
                      "  Refusing to extrapolate one stratum's per-unit cost onto another ",
                      "(they differ by ~2 orders of magnitude here).\n",
                      "  Re-run: bash slurm/submit.sh --smoke"),
               paste(missing_strata, collapse = ", ")))
}

# =============================================================================
# Sizing math, per stratum
# =============================================================================
fmt_slurm_time <- function(secs) {
  secs <- as.integer(ceiling(secs))
  d <- secs %/% 86400; secs <- secs %% 86400
  h <- secs %/% 3600;  secs <- secs %% 3600
  m <- secs %/% 60;    s <- secs %% 60
  sprintf("%d-%02d:%02d:%02d", d, h, m, s)
}

target_secs <- target_hours * 3600
max_secs    <- WALL_MAX_HOURS * 3600

plan <- list()
for (s in strata) {
  v <- probe$secs[probe$stratum == s]
  total_units <- as.integer(units_by_stratum[[s]])

  # Quantile choice: see LESSON 2 in the header. With a handful of probe units a
  # q0.9 is an interpolation between the top two observations, not an estimate of
  # the tail, so the max is the honest statistic.
  q_used <- if (!is.na(opt$quantile)) opt$quantile else
    if (length(v) < MIN_UNITS_FOR_QUANTILE) 1.0 else 0.9
  size_secs <- unname(quantile(v, q_used, type = 7))
  if (size_secs <= 0) stop(sprintf("stratum %s: non-positive per-unit time.", s))

  reps_per_job <- max(1L, min(as.integer(floor(target_secs / size_secs)), total_units))
  total_tasks  <- as.integer(ceiling(total_units / reps_per_job))

  if (total_tasks > MAX_CONCURRENT_JOBS) {
    reps_needed <- as.integer(ceiling(total_units / MAX_CONCURRENT_JOBS))
    if (reps_needed * size_secs <= max_secs) {
      reps_per_job <- reps_needed
      total_tasks  <- as.integer(ceiling(total_units / reps_per_job))
    } else {
      reps_per_job <- max(1L, as.integer(floor(max_secs / size_secs)))
      total_tasks  <- as.integer(ceiling(total_units / reps_per_job))
      cat(sprintf("WARNING stratum %s: cannot fit <= %d jobs within %g hr; %d tasks.\n",
                  s, MAX_CONCURRENT_JOBS, WALL_MAX_HOURS, total_tasks))
    }
  }

  est_task_secs <- reps_per_job * size_secs
  walltime_secs <- max(ceiling(est_task_secs * TIME_SAFETY), 600)

  pk <- probe$peak_rss_gb[probe$stratum == s]
  pk <- pk[is.finite(pk)]
  mem_measured <- length(pk) > 0L
  peak_gb <- if (mem_measured) max(pk) else NA_real_
  mem_gb <- if (mem_measured) max(MEM_FLOOR_GB, as.integer(ceiling(peak_gb * MEM_SAFETY)))
            else MEM_FLOOR_GB

  plan[[s]] <- list(
    stratum = s, total_units = total_units, n_probe = length(v),
    quantile = q_used, size_secs = size_secs,
    median_secs = median(v), max_secs = max(v),
    peak_gb = peak_gb, mem_measured = mem_measured,
    reps_per_job = reps_per_job, total_tasks = total_tasks,
    est_task_hours = est_task_secs / 3600,
    walltime = fmt_slurm_time(walltime_secs), mem_gb = mem_gb
  )
}

cat("\n===== SIZING (per cost stratum) =====\n")
cat(sprintf("timing source : %s\n", timing_source))
cat(sprintf("target hours  : %g   TIME_SAFETY %gx   MEM_SAFETY %gx\n",
            target_hours, TIME_SAFETY, MEM_SAFETY))
hdr <- sprintf("%-9s %6s %6s %5s %9s %9s %9s %7s %6s %7s %14s %5s",
               "stratum", "units", "nprobe", "q", "med_s", "size_s", "max_s",
               "units/t", "tasks", "est_hr", "--time", "--mem")
cat(hdr, "\n")
for (s in strata) {
  p <- plan[[s]]
  cat(sprintf("%-9s %6d %6d %5.2f %9.1f %9.1f %9.1f %7d %6d %7.2f %14s %4dG\n",
              p$stratum, p$total_units, p$n_probe, p$quantile, p$median_secs,
              p$size_secs, p$max_secs, p$reps_per_job, p$total_tasks,
              p$est_task_hours, p$walltime, p$mem_gb))
}
total_tasks_all <- sum(vapply(plan, function(p) p$total_tasks, integer(1)))
total_units_all <- sum(vapply(plan, function(p) p$total_units, integer(1)))
total_cpu_hours <- sum(vapply(plan, function(p) p$total_units * p$median_secs / 3600, numeric(1)))
cat(sprintf("TOTAL: %d units, %d tasks, ~%.1f CPU-hours at the observed medians\n",
            total_units_all, total_tasks_all, total_cpu_hours))
for (s in strata) if (!plan[[s]]$mem_measured) {
  cat(sprintf("NOTE stratum %s: peak RSS was NOT measured; --mem is the %dG floor.\n",
              s, MEM_FLOOR_GB))
}
cat("=====================================\n\n")

# =============================================================================
# Write sizing artifacts
# =============================================================================
config_dir <- file.path(opt$study_dir, "config")
dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)

# WRITE ORDER IS DELIBERATE: sizing.json (the provenance record) first, then the
# totals, and config/sizing.tsv -- the file submit.sh gates on -- LAST. If any
# formatting step throws, sizing.tsv does not exist, so submit.sh's preflight
# fails loudly with "size from a REAL O2 smoke run first" instead of submitting a
# 1120-unit run whose sizing was never recorded. The original order wrote the tsv
# first and a vectorisation bug in the JSON formatter below aborted the script
# after it, leaving exactly that silent hole (observed 2026-09-26; the run was
# submitted with no sizing.json).
jq <- function(x) ifelse(is.na(x), "null", sprintf("%.3f", x))
stratum_json <- paste(vapply(strata, function(s) {
  p <- plan[[s]]
  sprintf(paste0('    {"stratum": "%s", "total_units": %d, "probe_units": %d, ',
                 '"sizing_quantile": %g, "secs_per_unit_sizing": %.3f, ',
                 '"median_secs_per_unit": %.3f, "max_secs_per_unit_observed": %.3f, ',
                 '"peak_gb_measured": %s, "peak_gb": %s, "reps_per_job": %d, ',
                 '"total_tasks": %d, "est_task_hours": %.3f, "walltime": "%s", "mem_gb": %d}'),
          p$stratum, p$total_units, p$n_probe, p$quantile, p$size_secs,
          p$median_secs, p$max_secs,
          if (p$mem_measured) "true" else "false", jq(p$peak_gb),
          p$reps_per_job, p$total_tasks, p$est_task_hours, p$walltime, p$mem_gb)
}, character(1)), collapse = ",\n")

pr <- probe[order(probe$stratum, -probe$secs), ]
probe_json <- paste(sprintf(paste0('    {"unit": %d, "stratum": "%s", "block": "%s", ',
                                   '"dgp": "%s", "n": %d, "method": "%s", "secs": %.1f, ',
                                   '"peak_rss_gb": %s, "M_final": %s, "n_clipped": %s}'),
                            pr$unit, pr$stratum, pr$block, pr$dgp, pr$n, pr$method,
                            pr$secs, jq(pr$peak_rss_gb),
                            ifelse(is.na(pr$M_final), "null", as.character(pr$M_final)),
                            ifelse(is.na(pr$n_clipped), "null", as.character(pr$n_clipped))),
                    collapse = ",\n")

writeLines(sprintf(
'{
  "study": "%s",
  "timing_source": "%s",
  "target_hours": %g,
  "time_safety": %g,
  "mem_safety": %g,
  "mem_floor_gb": %d,
  "min_units_for_quantile": %d,
  "total_units": %d,
  "total_tasks": %d,
  "est_total_cpu_hours_at_median": %.2f,
  "max_array_size": %d,
  "max_concurrent_jobs": %d,
  "strata": [
%s
  ],
  "probe_units": [
%s
  ]
}',
  STUDY_NAME, timing_source, target_hours, TIME_SAFETY, MEM_SAFETY, MEM_FLOOR_GB,
  MIN_UNITS_FOR_QUANTILE, total_units_all, total_tasks_all, total_cpu_hours,
  MAX_ARRAY_SIZE, MAX_CONCURRENT_JOBS, stratum_json, probe_json),
  file.path(config_dir, "sizing.json"))

writeLines(c(
  sprintf("TOTAL_UNITS=%d", total_units_all),
  sprintf("TOTAL_TASKS=%d", total_tasks_all),
  sprintf("STRATA=%s", paste(strata, collapse = " ")),
  sprintf("MAX_ARRAY_SIZE=%d", MAX_ARRAY_SIZE),
  sprintf("MAX_CONCURRENT_JOBS=%d", MAX_CONCURRENT_JOBS),
  sprintf("TIMING_SOURCE=%s", timing_source)
), file.path(config_dir, "sizing_totals.env"))

# sizing.tsv: THE file submit.sh reads, and therefore written LAST (see above).
# Column order is part of the contract.
tsv_lines <- c("stratum\ttotal_units\treps_per_job\ttotal_tasks\twalltime\tmem_gb\tsecs_per_unit_sizing")
for (s in strata) {
  p <- plan[[s]]
  tsv_lines <- c(tsv_lines, sprintf("%s\t%d\t%d\t%d\t%s\t%d\t%.3f",
                                    p$stratum, p$total_units, p$reps_per_job,
                                    p$total_tasks, p$walltime, p$mem_gb, p$size_secs))
}
writeLines(tsv_lines, file.path(config_dir, "sizing.tsv"))

cat(sprintf("Wrote %s, %s and %s\n",
            file.path(config_dir, "sizing.tsv"),
            file.path(config_dir, "sizing_totals.env"),
            file.path(config_dir, "sizing.json")))
cat("Submit with: bash slurm/submit.sh\n")
