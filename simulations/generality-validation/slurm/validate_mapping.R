#!/usr/bin/env Rscript
# =============================================================================
# validate_mapping.R -- prove the task -> unit mapping is exact, before spending
# any cluster time
# =============================================================================
# This study never had this check (unlike confounded-aipw/lambda-sweep, where
# the equivalent script caught 3 real infra bugs on 2026-09-28). Added the same
# day, before relaunching this study post-RNG-fix, given its scale (51500 units)
# and history (one already-invalidated run).
#
# Reimplements slurm/run_replication.R's slicing arithmetic
# (`start <- (task_id-1)*reps_per_job + 1`, single GLOBAL array, no
# stratification -- unlike confounded-aipw, this study sizes ONE
# worst-case reps_per_job for the whole grid) and asserts that, for every
# plausible reps_per_job, the units a full run would execute equal the units
# config/grid.R defines, each exactly once.
#
# Also checks the two offline-prep artifacts submit.sh's own preflight
# requires (config/ensemble_seeds.rds, config/truth_table.rds): present, and
# every unit has a non-NA rho_true. Coverage numbers computed against an
# all-NA truth table would be silently meaningless -- this is the exact
# failure mode submit.sh's preflight (b) already guards at submission time;
# this script re-checks it here so it is caught before ANY offline-prep step
# is trusted, not just before the final submit.
#
# Usage: Rscript slurm/validate_mapping.R            (from the study directory)
#        Rscript slurm/validate_mapping.R <study-dir>
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
study_dir <- if (length(args) >= 1L) args[[1]] else "."

suppressPackageStartupMessages(library(surrogateTransportability))
source(file.path(study_dir, "R", "random_dgp.R"))
source(file.path(study_dir, "R", "true_rho.R"))
source(file.path(study_dir, "R", "dgp.R"))
source(file.path(study_dir, "config", "grid.R"))

cat("=== grid shape ===\n")
cat(sprintf("configs %d | block sizes: %s\n", nrow(GRID),
            paste(sprintf("%s=%d", names(table(GRID$block)), table(GRID$block)), collapse = " ")))
cat(sprintf("TOTAL_REPS %d | n_units() %d\n", TOTAL_REPS, n_units()))

ut <- unit_table()
stopifnot(nrow(ut) == n_units())
stopifnot(nrow(ut) == nrow(GRID) * TOTAL_REPS)
cat("PASS: n_units() matches nrow(GRID) * TOTAL_REPS and unit_table() row count.\n")

# (1) unit ids dense 1..N, seeds distinct, seeds are NOT unit ids, seeds are a
#     pure function of (config_id, rep_id) -- the exact property lambda-sweep's
#     migration found missing once (a "naive contiguous slice" silently ran the
#     wrong units because that study's unit_table() was rep-fastest within
#     config with a DIFFERENT stride convention).
stopifnot(identical(ut$unit, seq_len(nrow(ut))))
stopifnot(!anyDuplicated(ut$seed))
stopifnot(!identical(as.integer(ut$seed), ut$unit))
seed_recomputed <- .unit_seed(ut$config_id, ut$rep_id)
stopifnot(identical(as.integer(ut$seed), as.integer(seed_recomputed)))
cat(sprintf("PASS: unit ids dense 1..%d; %d distinct seeds, pure function of (config_id, rep_id).\n",
            nrow(ut), length(unique(ut$seed))))

# (2) Offline-prep artifacts submit.sh's preflight (b) requires. Fail loud here
#     too, before trusting anything downstream of them.
ens_path   <- file.path(study_dir, "config", "ensemble_seeds.rds")
truth_path <- file.path(study_dir, "config", "truth_table.rds")
cat("\n=== offline-prep artifacts ===\n")
if (!file.exists(ens_path)) {
  stop(sprintf("MISSING: %s -- run slurm/prep_offline.sh first (defines the balanced ensemble).", ens_path))
}
if (!file.exists(truth_path)) {
  stop(sprintf("MISSING: %s -- run slurm/prep_offline.sh first (rho_true for every config).", truth_path))
}
cat(sprintf("PASS: %s and %s both present.\n", ens_path, truth_path))

n_na_truth <- sum(is.na(ut$rho_true))
if (n_na_truth > 0) {
  bad <- unique(ut$config_id[is.na(ut$rho_true)])
  stop(sprintf(
    "%d/%d units have NA rho_true (config_id(s): %s). Coverage against an all-NA truth table is silently meaningless -- see submit.sh's own preflight (b). Re-run slurm/prep_offline.sh before proceeding.",
    n_na_truth, nrow(ut), paste(head(bad, 10), collapse = ",")))
}
cat(sprintf("PASS: rho_true present (non-NA) for all %d units across %d configs.\n",
            nrow(ut), length(unique(ut$config_id))))

# (3) THE MAPPING. Reimplement run_replication.R's single-global-array slice for
#     a range of reps_per_job, including the degenerate ends (1 unit/task, and
#     one task for the whole grid) and values that do not divide the unit count.
cat("\n=== task -> unit mapping (single global array, no stratification) ===\n")
slice_all <- function(reps_per_job) {
  n_tasks <- as.integer(ceiling(nrow(ut) / reps_per_job))
  out <- list(units = integer(0), task_ids = integer(0))
  for (task_id in seq_len(n_tasks)) {
    start <- (task_id - 1L) * reps_per_job + 1L
    end   <- min(task_id * reps_per_job, nrow(ut))
    if (start > nrow(ut)) next
    out$units <- c(out$units, ut$unit[start:end])
    out$task_ids <- c(out$task_ids, rep(task_id, end - start + 1L))
  }
  out$n_tasks <- n_tasks
  out
}

cand <- unique(c(1L, 24L, 103L, 500L, 1000L,
                 as.integer(ceiling(nrow(ut) / c(2, 5, 10, 51, 103))), nrow(ut)))
cand <- sort(cand[cand >= 1L & cand <= nrow(ut)])
for (rpj in cand) {
  r <- slice_all(rpj)
  ok_exact <- identical(sort(r$units), ut$unit)
  ok_nodup <- !anyDuplicated(r$units)
  cat(sprintf("  units/task %5d -> %5d tasks | exact coverage %-5s | no duplicates %-5s\n",
              rpj, r$n_tasks, ok_exact, ok_nodup))
  stopifnot(ok_exact, ok_nodup)
}
cat("PASS: every reps_per_job tried covers the full unit set exactly once.\n")

# (4) MAX_ARRAY_SIZE / MAX_CONCURRENT_JOBS constraint sanity, mirroring
#     submit.sh's own chunking so a bad sizing.env is caught here too, not only
#     after burning a submission.
cat("\n=== chunking sanity (informational; submit.sh reads real values from sizing.env) ===\n")
MAX_ARRAY_SIZE <- 1000L
sizing_env <- file.path(study_dir, "config", "sizing.env")
if (file.exists(sizing_env)) {
  env <- new.env()
  lines <- readLines(sizing_env)
  for (ln in lines) {
    if (!grepl("^[A-Z_]+=", ln)) next
    kv <- strsplit(ln, "=", fixed = TRUE)[[1]]
    assign(kv[1], kv[2], envir = env)
  }
  rpj <- suppressWarnings(as.integer(get0("REPS_PER_JOB", envir = env)))
  tt  <- suppressWarnings(as.integer(get0("TOTAL_TASKS", envir = env)))
  if (!is.na(rpj) && !is.na(tt)) {
    r <- slice_all(rpj)
    stopifnot(identical(r$n_tasks, tt))
    stopifnot(identical(sort(r$units), ut$unit))
    cat(sprintf("PASS: config/sizing.env's REPS_PER_JOB=%d, TOTAL_TASKS=%d reproduce exact coverage.\n",
                rpj, tt))
  } else {
    cat("NOTE: config/sizing.env present but REPS_PER_JOB/TOTAL_TASKS not parsed; skipping cross-check.\n")
  }
} else {
  cat("NOTE: config/sizing.env not found yet (run slurm/profile_timing.R first); skipping cross-check.\n")
}

cat("\nALL MAPPING CHECKS PASSED\n")
