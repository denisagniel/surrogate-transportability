#!/usr/bin/env Rscript
# =============================================================================
# run_replication.R -- run ONE array task's worth of work units (crash-safe)
# =============================================================================
# Invoked by array.slurm once per SLURM array index. Each task runs a contiguous
# block of `reps_per_job` work units, then writes ONE result file to the run's
# scratch directory. Output is idempotent: if the task's file already exists it
# exits immediately (cheap resume after partial failure).
#
# Crash safety (M3): each unit's result is flushed to partials/unit_NNNNNNN.rds
# the moment it finishes. A wall-time TIMEOUT (SLURM SIGTERM->SIGKILL) loses at
# most the one in-flight unit; a resubmit skips every completed unit and finishes
# the remainder cheaply. The task_*.rds file is assembled from the partials at
# the end (that is what combine.R reads).
#
# No silent all-NA (M4): if run_one() errors on a unit, the persisted row carries
# the error MESSAGE in an `error_msg` column (NA on success) instead of a silent
# all-NA row. combine.R surfaces these.
#
# Deliberately uses library() (module R has no devtools) and explicit dest= on
# every optparse option (guards against hyphenated-arg parsing bugs).
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option("--task-id",      type = "integer", dest = "task_id",
              help = "SLURM array task id (1-based)"),
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
# Libraries FIRST: grid.R sources random_dgp.R/true_rho.R and its truth build
# calls package functions (canonical_dgp_params, sample_tv_ball).
library(surrogateTransportability)
library(mgcv); library(ranger)
source(file.path(opt$study_dir, "R", "random_dgp.R"))
source(file.path(opt$study_dir, "R", "true_rho.R"))
source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "R", "dgp.R"))
source(file.path(opt$study_dir, "R", "estimators.R"))
source(file.path(opt$study_dir, "R", "run_one.R"))

# --- Determine this task's block of units ------------------------------------
ut <- unit_table()
start <- (opt$task_id - 1L) * opt$reps_per_job + 1L
end   <- min(opt$task_id * opt$reps_per_job, nrow(ut))
if (start > nrow(ut)) {
  # Task index beyond the last unit (padding in final array) -- nothing to do.
  cat(sprintf("[task %d] no units (start %d > %d); exiting.\n",
              opt$task_id, start, nrow(ut)))
  quit(save = "no", status = 0)
}
block <- ut[start:end, , drop = FALSE]

out_file <- file.path(opt$scratch_dir,
                      sprintf("task_%s.rds", formatC(opt$task_id, width = 6, flag = "0")))

# --- Idempotent skip: whole task already assembled ---------------------------
if (file.exists(out_file)) {
  cat(sprintf("[task %d] result already exists (%s); skipping.\n",
              opt$task_id, out_file))
  quit(save = "no", status = 0)
}

partials_dir <- file.path(opt$scratch_dir, "partials")
dir.create(partials_dir, recursive = TRUE, showWarnings = FALSE)
partial_path <- function(u) file.path(partials_dir,
                                      sprintf("unit_%s.rds", formatC(u, width = 7, flag = "0")))

# --- rbind that tolerates differing columns (error rows lack the full schema) -
.rbind_fill <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) return(NULL)
  if (requireNamespace("data.table", quietly = TRUE)) {
    return(as.data.frame(data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)))
  }
  cols <- unique(unlist(lapply(rows, names)))
  filled <- lapply(rows, function(r) {
    for (c in setdiff(cols, names(r))) r[[c]] <- NA
    r[, cols, drop = FALSE]
  })
  do.call(rbind, filled)
}

# --- Run one unit, persisting an error MESSAGE rather than a silent all-NA row -
run_unit <- function(unit_row) {
  err <- NA_character_
  res <- tryCatch(run_one(unit_row),
                  error = function(e) { err <<- conditionMessage(e); NULL })
  if (is.null(res)) {
    # Minimal identity row + the failure text; combine.R fills the rest with NA.
    res <- data.frame(unit = unit_row$unit, config_id = unit_row$config_id,
                      rep_id = unit_row$rep_id, estimate = NA_real_,
                      stringsAsFactors = FALSE)
  }
  if (!("error_msg" %in% names(res))) res$error_msg <- err
  else if (is.na(res$error_msg[1]))  res$error_msg <- err
  res
}

# --- Run the block, checkpointing each unit ----------------------------------
cat(sprintf("[task %d] running units %d-%d (%d units)\n",
            opt$task_id, start, end, nrow(block)))
t0 <- Sys.time()
n_done_resumed <- 0L
n_failed <- 0L
for (i in seq_len(nrow(block))) {
  u  <- block$unit[i]
  pf <- partial_path(u)
  if (file.exists(pf)) { n_done_resumed <- n_done_resumed + 1L; next }  # resume skip
  row <- run_unit(block[i, , drop = FALSE])
  if (!is.na(row$error_msg[1])) {
    n_failed <- n_failed + 1L
    cat(sprintf("[task %d] unit %d ERRORED: %s\n", opt$task_id, u, row$error_msg[1]))
  }
  tmp <- paste0(pf, ".tmp")
  saveRDS(row, tmp)
  file.rename(tmp, pf)                                  # atomic per-unit flush
}
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
if (n_done_resumed > 0)
  cat(sprintf("[task %d] resumed: %d unit(s) already done, skipped.\n",
              opt$task_id, n_done_resumed))
cat(sprintf("[task %d] block done in %.1f s (%d failed unit(s))\n",
            opt$task_id, elapsed, n_failed))

# --- Assemble the task file from this block's partials -----------------------
rows <- lapply(block$unit, function(u) {
  pf <- partial_path(u)
  if (file.exists(pf)) readRDS(pf) else NULL
})
result <- .rbind_fill(rows)
if (is.null(result) || nrow(result) < nrow(block)) {
  stop(sprintf("[task %d] only %s/%d unit partials present; not assembling task file.",
               opt$task_id, if (is.null(result)) 0 else nrow(result), nrow(block)))
}
result <- result[order(result$unit), , drop = FALSE]

# --- Write task file atomically (tmp then rename) ----------------------------
tmp <- paste0(out_file, ".tmp")
saveRDS(result, tmp)
file.rename(tmp, out_file)
cat(sprintf("[task %d] wrote %s (%d rows)\n", opt$task_id, out_file, nrow(result)))
