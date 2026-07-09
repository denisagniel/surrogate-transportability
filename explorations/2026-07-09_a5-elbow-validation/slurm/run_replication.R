#!/usr/bin/env Rscript
# =============================================================================
# run_replication.R -- run ONE array task's worth of Stage 1 work units
# =============================================================================
# Invoked by array.slurm once per SLURM array index. Each task runs a contiguous
# block of `reps_per_job` work units, then writes ONE result file to the run's
# scratch directory. Idempotent: if the task's file already exists it exits.
#
# Stage 1 needs NO project package -- it only source()s the study's own R/ files
# and uses base R + stats. (grf/ranger enter only in Stage 2.)
#
# Uses explicit dest= on every optparse option (guards hyphenated-arg parsing).
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option("--task-id",      type = "integer", dest = "task_id",
              help = "SLURM array task id (1-based, global)"),
  make_option("--reps-per-job", type = "integer", dest = "reps_per_job",
              help = "Number of work units this task should run"),
  make_option("--study-dir",    type = "character", dest = "study_dir",
              help = "Absolute path to the study directory (contains config/, R/)"),
  make_option("--scratch-dir",  type = "character", dest = "scratch_dir",
              help = "Run-specific scratch dir for per-task result files")
)
opt <- parse_args(OptionParser(option_list = option_list))

stopifnot(!is.null(opt$task_id), !is.null(opt$reps_per_job),
          !is.null(opt$study_dir), !is.null(opt$scratch_dir))

# --- Load study code (order matters) -----------------------------------------
source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "R", "dgp_smooth.R"))
source(file.path(opt$study_dir, "R", "pseudo_outcome.R"))
source(file.path(opt$study_dir, "R", "bilinear_estimator.R"))
source(file.path(opt$study_dir, "R", "run_one_stage1.R"))
# No project package and no extra CRAN packages for Stage 1 (base R + stats).

# --- Determine this task's block of units ------------------------------------
ut <- unit_table_stage1(REPS_STAGE1)
start <- (opt$task_id - 1L) * opt$reps_per_job + 1L
end   <- min(opt$task_id * opt$reps_per_job, nrow(ut))
if (start > nrow(ut)) {
  cat(sprintf("[task %d] no units (start %d > %d); exiting.\n",
              opt$task_id, start, nrow(ut)))
  quit(save = "no", status = 0)
}
block <- ut[start:end, , drop = FALSE]

# --- Idempotent skip ----------------------------------------------------------
out_file <- file.path(opt$scratch_dir,
                     sprintf("task_%s.rds", formatC(opt$task_id, width = 6, flag = "0")))
if (file.exists(out_file)) {
  cat(sprintf("[task %d] result already exists (%s); skipping.\n",
              opt$task_id, out_file))
  quit(save = "no", status = 0)
}

# --- Run the block ------------------------------------------------------------
cat(sprintf("[task %d] running units %d-%d (%d units)\n",
            opt$task_id, start, end, nrow(block)))
t0 <- Sys.time()
rows <- vector("list", nrow(block))
for (i in seq_len(nrow(block))) {
  rows[[i]] <- run_one_stage1(block[i, , drop = FALSE])
}
result <- do.call(rbind, rows)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("[task %d] done in %.1f s (%.2f s/unit)\n",
            opt$task_id, elapsed, elapsed / nrow(block)))

# --- Write atomically to scratch (tmp then rename) ---------------------------
dir.create(opt$scratch_dir, recursive = TRUE, showWarnings = FALSE)
tmp <- paste0(out_file, ".tmp")
saveRDS(result, tmp)
file.rename(tmp, out_file)
cat(sprintf("[task %d] wrote %s (%d rows)\n", opt$task_id, out_file, nrow(result)))
