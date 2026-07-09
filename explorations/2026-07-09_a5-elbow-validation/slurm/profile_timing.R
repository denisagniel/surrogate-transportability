#!/usr/bin/env Rscript
# =============================================================================
# profile_timing.R -- LOCAL profiling to size the cluster job array
# =============================================================================
# Runs a handful of Stage 1 work units locally, measures median per-unit wall
# time and peak memory, then computes job sizing targeting a 1-3 hr wall time per
# task while respecting O2 limits (<=1000 tasks/array, <=10000 queued).
#
# Because Stage 1 per-unit time varies A LOT with n (n=500 ~ 0.05s, n=16000 ~ 2s),
# we profile a SPREAD across the n-grid and size off the MEAN per unit (the units
# are enumerated rep-fastest within config, so a task's block mixes n values).
#
# Writes config/sizing.env (sourced by submit.sh) and config/sizing.json.
# Run locally BEFORE submitting.
# Usage: Rscript slurm/profile_timing.R [--n-units N] [--target-hours H] [--study-dir DIR]
# =============================================================================

suppressPackageStartupMessages({ library(optparse) })

MAX_ARRAY_SIZE      <- 1000L
MAX_CONCURRENT_JOBS <- 10000L
WALL_MIN_HOURS      <- 1
WALL_MAX_HOURS      <- 3
TIME_SAFETY         <- 1.5
MEM_SAFETY          <- 1.5
MEM_FLOOR_GB        <- 2L

option_list <- list(
  make_option("--n-units",      type = "integer",   dest = "n_units_probe", default = 30L,
              help = "How many units to time locally [default %default]"),
  make_option("--target-hours", type = "double",    dest = "target_hours", default = 2,
              help = "Target wall time per task in hours, within [1,3] [default %default]"),
  make_option("--study-dir",    type = "character", dest = "study_dir", default = "..",
              help = "Path to study dir (contains config/, R/) [default %default]")
)
opt <- parse_args(OptionParser(option_list = option_list))

target_hours <- min(max(opt$target_hours, WALL_MIN_HOURS), WALL_MAX_HOURS)

source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "R", "dgp_smooth.R"))
source(file.path(opt$study_dir, "R", "pseudo_outcome.R"))
source(file.path(opt$study_dir, "R", "bilinear_estimator.R"))
source(file.path(opt$study_dir, "R", "run_one_stage1.R"))

ut <- unit_table_stage1(REPS_STAGE1)
total_units <- nrow(ut)

# Profile a SPREAD across n (units are rep-fastest, so sample evenly across the
# table to hit all n values, not just the first config).
n_probe <- min(opt$n_units_probe, total_units)
probe_idx <- unique(round(seq(1, total_units, length.out = n_probe)))
cat(sprintf("Profiling %d of %d total work units (spread across the grid)...\n",
            length(probe_idx), total_units))

invisible(gc(reset = TRUE))
per_unit_secs <- numeric(length(probe_idx))
n_degenerate  <- 0L
for (i in seq_along(probe_idx)) {
  res <- NULL
  t <- system.time(res <- run_one_stage1(ut[probe_idx[i], , drop = FALSE]))
  per_unit_secs[i] <- unname(t["elapsed"])
  if (is.null(res) || !("estimate" %in% names(res)) || all(is.na(res$estimate))) {
    n_degenerate <- n_degenerate + 1L
  }
}
if (n_degenerate == length(probe_idx)) {
  stop("All probe units produced only NA estimates -- every replication failed.")
}

gcinfo <- gc()
peak_mb <- sum(gcinfo[, ncol(gcinfo)])
peak_gb <- peak_mb / 1024

med_secs  <- median(per_unit_secs)
mean_secs <- mean(per_unit_secs)   # size off the MEAN (blocks mix n values)
cat(sprintf("Per-unit wall time: median %.3f s, mean %.3f s (n=%d probes)\n",
            med_secs, mean_secs, length(probe_idx)))
cat(sprintf("Peak memory during profiling: %.2f GB\n", peak_gb))

size_secs <- mean_secs
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
  } else {
    reps_per_job <- max(1L, floor(max_secs / size_secs))
    total_tasks  <- as.integer(ceiling(total_units / reps_per_job))
  }
}

n_arrays <- as.integer(ceiling(total_tasks / MAX_ARRAY_SIZE))
concurrency_cap <- min(MAX_ARRAY_SIZE, MAX_CONCURRENT_JOBS)

est_task_secs <- reps_per_job * size_secs
walltime_secs <- ceiling(est_task_secs * TIME_SAFETY)
walltime_secs <- max(walltime_secs, 600)

fmt_slurm_time <- function(secs) {
  secs <- as.integer(ceiling(secs))
  d <- secs %/% 86400; secs <- secs %% 86400
  h <- secs %/% 3600;  secs <- secs %% 3600
  m <- secs %/% 60;    s <- secs %% 60
  sprintf("%d-%02d:%02d:%02d", d, h, m, s)
}
walltime <- fmt_slurm_time(walltime_secs)
mem_gb <- max(MEM_FLOOR_GB, as.integer(ceiling(peak_gb * MEM_SAFETY)))

cat("\n===== SIZING =====\n")
cat(sprintf("total_units      : %d\n", total_units))
cat(sprintf("reps_per_job     : %d\n", reps_per_job))
cat(sprintf("total_tasks      : %d\n", total_tasks))
cat(sprintf("tasks_per_array  : <= %d (%d array(s))\n", MAX_ARRAY_SIZE, n_arrays))
cat(sprintf("concurrency_cap  : %d\n", concurrency_cap))
cat(sprintf("est wall / task  : %.2f hr\n", est_task_secs / 3600))
cat(sprintf("--time           : %s\n", walltime))
cat(sprintf("--mem            : %dG\n", mem_gb))
cat("==================\n\n")

config_dir <- file.path(opt$study_dir, "config")
dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)

env_lines <- c(
  sprintf("TOTAL_UNITS=%d", total_units),
  sprintf("REPS_PER_JOB=%d", reps_per_job),
  sprintf("TOTAL_TASKS=%d", total_tasks),
  sprintf("MAX_ARRAY_SIZE=%d", MAX_ARRAY_SIZE),
  sprintf("MAX_CONCURRENT_JOBS=%d", MAX_CONCURRENT_JOBS),
  sprintf("N_ARRAYS=%d", n_arrays),
  sprintf("CONCURRENCY_CAP=%d", concurrency_cap),
  sprintf("WALLTIME=%s", walltime),
  sprintf("MEM_GB=%d", mem_gb)
)
writeLines(env_lines, file.path(config_dir, "sizing.env"))

json <- sprintf(
'{
  "study": "%s",
  "profiled_units": %d,
  "median_secs_per_unit": %.6f,
  "mean_secs_per_unit": %.6f,
  "peak_gb": %.3f,
  "target_hours": %g,
  "total_units": %d,
  "reps_per_job": %d,
  "total_tasks": %d,
  "walltime": "%s",
  "mem_gb": %d
}',
  STUDY_NAME, length(probe_idx), med_secs, mean_secs, peak_gb, target_hours,
  total_units, reps_per_job, total_tasks, walltime, mem_gb)
writeLines(json, file.path(config_dir, "sizing.json"))

cat(sprintf("Wrote %s and %s\n",
            file.path(config_dir, "sizing.env"),
            file.path(config_dir, "sizing.json")))
