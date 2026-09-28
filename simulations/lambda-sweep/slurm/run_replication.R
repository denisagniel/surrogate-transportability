#!/usr/bin/env Rscript
# =============================================================================
# run_replication.R -- run ONE array task's worth of work units (crash-safe)
# =============================================================================
# Invoked by array.slurm once per SLURM array index. Structurally the same as
# simulations/canonical-validation/slurm/run_replication.R, with ONE substantive
# difference forced by this study's design (see "REP SCOPING" below).
#
# Each task runs a contiguous block of `reps_per_job` work units, then writes ONE
# task_NNNNNN.rds to the run's scratch dir. Output is idempotent: if the task file
# already exists it exits immediately (cheap resume).
#
# Crash safety (M3): each unit's result is flushed to partials/unit_NNNNNN.rds the
# moment it finishes. A wall-time TIMEOUT (SLURM SIGTERM->SIGKILL) loses at most
# the one in-flight unit; a resubmit against the same run-id skips every completed
# unit. The task file is assembled from the partials at the end.
#
# No silent all-NA (M4): if run_one() throws, the persisted row carries the error
# MESSAGE in `error_msg` (NA on success). combine.R surfaces these.
#
# -----------------------------------------------------------------------------
# REP SCOPING -- the one place this differs from canonical-validation
# -----------------------------------------------------------------------------
# canonical-validation runs ALL of unit_table(), so a task can slice the unit
# table by absolute unit id: units [(t-1)*R+1, t*R].
#
# lambda-sweep cannot. config/grid.R declares TOTAL_REPS = 40 but the executed
# scope is reps 1-20, and unit_table() enumerates rep-FASTEST within config, so
# reps 1-20 are NOT a contiguous unit range -- they are 36 interleaved blocks of
# 20 (units 1-20, 41-60, 81-100, ...). Slicing by absolute unit id would silently
# run reps 21-40 and under-cover reps 1-20.
#
# So a task slices the ROW INDEX of the rep-FILTERED unit table, and the partial
# filename still uses the true global `unit` id. Consequences:
#   * coverage of reps REP_FROM..REP_TO is exact;
#   * unit ids match local/run_local.R's (same unit_table(), same %06d naming),
#     so a partial produced by either backend is recognisable by the other;
#   * the task -> unit mapping depends on (GRID, TOTAL_REPS, REP_FROM, REP_TO).
#     GRID/TOTAL_REPS are covered by the GRID_HASH stale-code guard; REP_FROM and
#     REP_TO are recorded by submit.sh in the scratch dir's REP_SCOPE file and
#     re-verified by combine.R, so a mid-run rescope fails loudly rather than
#     producing a silently mis-mapped result set.
#
# Deliberately uses library() (module R has no devtools) and explicit dest= on
# every optparse option (guards against hyphenated-arg parsing bugs).
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option("--task-id",      type = "integer",   dest = "task_id",
              help = "SLURM array task id (1-based, global across chunked arrays)"),
  make_option("--reps-per-job", type = "integer",   dest = "reps_per_job",
              help = "Number of work units this task should run"),
  make_option("--study-dir",    type = "character", dest = "study_dir",
              help = "Absolute path to the study directory (contains config/, R/)"),
  make_option("--scratch-dir",  type = "character", dest = "scratch_dir",
              help = "Run-specific scratch dir for per-task result files"),
  make_option("--rep-from",     type = "integer",   dest = "rep_from", default = 1L,
              help = "First replication id in the executed scope [default %default]"),
  make_option("--rep-to",       type = "integer",   dest = "rep_to",
              help = "Last replication id in the executed scope"),
  make_option("--rows",         type = "character", dest = "rows", default = "",
              help = paste("Optional comma-separated 1-based ROW indices into the",
                           "rep-filtered unit table, restricting the run to those",
                           "rows before task slicing. Used ONLY by submit.sh --smoke,",
                           "so a timing probe can straddle the grid (cheap dgp5 and",
                           "expensive dgp1, smallest and largest lambda) instead of",
                           "landing entirely on config 1, which contiguous slicing",
                           "would do. Empty (default) = the full rep scope."))
)
opt <- parse_args(OptionParser(option_list = option_list))

stopifnot(!is.null(opt$task_id), !is.null(opt$reps_per_job),
          !is.null(opt$study_dir), !is.null(opt$scratch_dir),
          !is.null(opt$rep_from), !is.null(opt$rep_to))

# --- Load study code (order matters: cell_cates before estimators) -----------
source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "R", "cell_cates.R"))
source(file.path(opt$study_dir, "R", "dgp.R"))
source(file.path(opt$study_dir, "R", "estimators.R"))
source(file.path(opt$study_dir, "R", "run_one.R"))
library(surrogateTransportability)
library(mgcv); library(ranger)

if (opt$rep_to > TOTAL_REPS) {
  stop(sprintf("--rep-to %d exceeds TOTAL_REPS %d declared in config/grid.R.",
               opt$rep_to, TOTAL_REPS))
}

# --- Determine this task's block of units (REP-FILTERED, see header) ---------
ut     <- unit_table()
target <- ut[ut$rep_id >= opt$rep_from & ut$rep_id <= opt$rep_to, , drop = FALSE]
target <- target[order(target$unit), , drop = FALSE]

# Optional explicit row restriction (smoke probes only; see --rows help).
if (nzchar(opt$rows)) {
  rows <- as.integer(strsplit(opt$rows, ",", fixed = TRUE)[[1]])
  if (anyNA(rows) || any(rows < 1L) || any(rows > nrow(target))) {
    stop(sprintf("--rows out of range: need 1..%d, got %s", nrow(target), opt$rows))
  }
  target <- target[rows, , drop = FALSE]
  cat(sprintf("[task %d] --rows active: restricted to %d of the %d in-scope rows.\n",
              opt$task_id, nrow(target), sum(ut$rep_id >= opt$rep_from & ut$rep_id <= opt$rep_to)))
}

start <- (opt$task_id - 1L) * opt$reps_per_job + 1L
end   <- min(opt$task_id * opt$reps_per_job, nrow(target))
if (start > nrow(target)) {
  # Task index beyond the last in-scope unit (padding in the final array).
  cat(sprintf("[task %d] no units (row %d > %d in-scope rows); exiting.\n",
              opt$task_id, start, nrow(target)))
  quit(save = "no", status = 0)
}
block <- target[start:end, , drop = FALSE]

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
# %06d, matching local/run_local.R exactly so unit ids are comparable across
# backends (canonical-validation uses %07d; this study's local run set %06d first).
partial_path <- function(u) file.path(partials_dir, sprintf("unit_%06d.rds", u))

# --- Provenance stamped on EVERY row, including error rows -------------------
# Same four columns local/run_local.R writes, plus `backend`. combine.R refuses a
# result set that mixes them: numerics are not bit-identical across R builds or
# BLAS implementations, so a mixed set is not a single comparable experiment.
RUN_ID  <- basename(normalizePath(opt$scratch_dir, mustWork = FALSE))
GIT_SHA <- tryCatch(
  sub("\\s+$", "", system2("git", c("-C", shQuote(opt$study_dir), "rev-parse", "--short", "HEAD"),
                           stdout = TRUE, stderr = FALSE)),
  error = function(e) "nogit"
)
if (length(GIT_SHA) != 1L || !nzchar(GIT_SHA)) GIT_SHA <- "nogit"

# DETECTED, not asserted. Hardcoding "o2_slurm" here would label a local plumbing
# invocation of this same script as a cluster result, which is exactly the mislabel
# combine.R's backend guard exists to catch -- the guard would then be inert.
BACKEND <- if (nzchar(Sys.getenv("SLURM_JOB_ID"))) "o2_slurm" else "local_driver"

stamp <- function(res) {
  res$run_id      <- RUN_ID
  res$git_sha     <- GIT_SHA
  res$r_version   <- paste(R.version$major, R.version$minor, sep = ".")
  res$pkg_version <- as.character(utils::packageVersion("surrogateTransportability"))
  res$backend     <- BACKEND
  res
}

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
    # Full schema so the error row binds cleanly against successful rows.
    res <- data.frame(
      unit = unit_row$unit, config_id = unit_row$config_id, rep_id = unit_row$rep_id,
      dgp = unit_row$dgp, n = unit_row$n, lambda = unit_row$lambda,
      method = unit_row$method,
      estimate = NA_real_, std_error = NA_real_, ci_lower = NA_real_,
      ci_upper = NA_real_, truth = NA_real_, truth_source = NA_character_,
      error = NA_real_, covered = NA_integer_, M_final = NA_integer_,
      converged = 0L, secs = NA_real_, error_msg = err,
      stringsAsFactors = FALSE
    )
  }
  if (!("error_msg" %in% names(res)))     res$error_msg <- err
  else if (is.na(res$error_msg[1]))       res$error_msg <- err
  stamp(res)
}

# --- Run the block, checkpointing each unit ----------------------------------
cat(sprintf("[task %d] reps %d-%d scope: %d in-scope units total; this task rows %d-%d (%d units %d-%d)\n",
            opt$task_id, opt$rep_from, opt$rep_to, nrow(target),
            start, end, nrow(block), min(block$unit), max(block$unit)))
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
  invisible(file.rename(tmp, pf))                       # atomic per-unit flush
  cat(sprintf("[task %d] unit %d done (%.1f s cumulative)\n", opt$task_id, u,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
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
invisible(file.rename(tmp, out_file))
cat(sprintf("[task %d] wrote %s (%d rows)\n", opt$task_id, out_file, nrow(result)))
