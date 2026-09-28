#!/usr/bin/env Rscript
# =============================================================================
# run_replication.R -- run ONE array task's worth of work units (crash-safe)
# =============================================================================
# Invoked by array.slurm once per SLURM array index. Structurally the same as
# simulations/canonical-validation/slurm/run_replication.R and
# simulations/lambda-sweep/slurm/run_replication.R, with ONE substantive
# difference forced by this study's design (see "STRATUM SCOPING" below).
#
# Each task runs a contiguous block of `reps_per_job` units WITHIN ONE COST
# STRATUM, then writes ONE task_NNNNNN.rds to the run's scratch dir. Output is
# idempotent: if the task file already exists it exits immediately (cheap resume).
#
# Crash safety: each unit's result is flushed to partials/unit_NNNNNN.rds the
# moment it finishes. A wall-time TIMEOUT (SLURM SIGTERM->SIGKILL) loses at most
# the one in-flight unit; a resubmit against the same run-id skips every completed
# unit. The task file is assembled from the partials at the end.
#
# No silent all-NA: if run_one() throws, the persisted row carries the error
# MESSAGE in `error_msg` (NA on success). combine.R surfaces these.
#
# -----------------------------------------------------------------------------
# STRATUM SCOPING -- the one place this differs from canonical-validation
# -----------------------------------------------------------------------------
# canonical-validation has ONE cost stratum, so a task slices the unit table by
# absolute unit id: units [(t-1)*R+1, t*R], with one global `reps_per_job`.
#
# confounded-aipw cannot. config/grid.R defines stratum_of() precisely because
# per-unit cost differs by ~2 orders of magnitude between n = 10,000 (`agreement`
# + `confounded` blocks, stratum "large_n") and n = 250 (`smalln` block, stratum
# "small_n"). One global reps_per_job would either time out the large-n tasks or
# burn an hour of wall time per small-n task. So each stratum gets its OWN array
# with its OWN reps_per_job, --time and --mem.
#
# Consequence for the mapping: a task's block is a slice of the ROW INDEX of the
# STRATUM-FILTERED unit table, and the partial filename still uses the true global
# `unit` id. Global task ids stay contiguous and unique ACROSS strata
# (large_n gets 1..T_large, small_n gets T_large+1..T_large+T_small) so
# task_NNNNNN.rds never collides between arrays, and `--task-base` converts the
# global id back to the within-stratum index.
#
# Note on grid.R's OTHER indexing wrinkle: `reps` is a GRID COLUMN here (40 for
# `agreement`, 80 for `confounded`, 120 for `smalln`) and unit_table() builds
# per-config rep sequences with MAX_REPS-strided seeds. That does NOT need special
# handling in the mapping, because unlike lambda-sweep this study executes ALL of
# unit_table() -- there is no rep sub-scope. The seed stride matters only for
# reproducibility (raising a block's `reps` never shifts an existing unit's seed),
# not for slicing. Verified empirically by slurm/validate_mapping.R rather than
# assumed: it asserts every one of the 1120 units is covered exactly once, per
# stratum, for a range of reps_per_job values.
#
# Deliberately uses library() (module R has no devtools) and explicit dest= on
# every optparse option (guards against hyphenated-arg parsing bugs).
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option("--task-id",      type = "integer",   dest = "task_id",
              help = "GLOBAL array task id (1-based, contiguous across strata)"),
  make_option("--task-base",    type = "integer",   dest = "task_base", default = 0L,
              help = paste("Global task id of this stratum's FIRST task, minus one.",
                           "local_task = task_id - task_base [default %default]")),
  make_option("--stratum",      type = "character", dest = "stratum",
              help = "Cost stratum this task belongs to (a value of stratum_of())"),
  make_option("--reps-per-job", type = "integer",   dest = "reps_per_job",
              help = "Number of work units this task should run"),
  make_option("--study-dir",    type = "character", dest = "study_dir",
              help = "Absolute path to the study directory (contains config/, R/)"),
  make_option("--scratch-dir",  type = "character", dest = "scratch_dir",
              help = "Run-specific scratch dir for per-task result files"),
  make_option("--rows",         type = "character", dest = "rows", default = "",
              help = paste("Optional comma-separated 1-based ROW indices into the",
                           "STRATUM-filtered unit table, restricting the run to",
                           "those rows before task slicing. Used ONLY by",
                           "submit.sh --smoke, so a timing probe straddles the",
                           "cost axes (IW vs AIPW, canonical vs confounded)",
                           "instead of landing entirely on config 1, which",
                           "contiguous slicing would do. Empty = full stratum."))
)
opt <- parse_args(OptionParser(option_list = option_list))

stopifnot(!is.null(opt$task_id), !is.null(opt$reps_per_job),
          !is.null(opt$study_dir), !is.null(opt$scratch_dir),
          !is.null(opt$stratum), !is.null(opt$task_base))

# --- Load study code ---------------------------------------------------------
# ORDER MATTERS: config/grid.R's unit_table() calls spec_for(), which R/dgp.R
# defines, and spec_for() calls the package's spec accessors. Same order as
# run_study.R, so the two drivers cannot diverge on what they load.
library(surrogateTransportability)
library(mgcv); library(ranger)
source(file.path(opt$study_dir, "R", "dgp.R"))
source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "R", "estimators.R"))
source(file.path(opt$study_dir, "R", "run_one.R"))

# --- Determine this task's block of units (STRATUM-FILTERED, see header) ------
ut <- unit_table()
ut$stratum <- stratum_of(ut)
if (!(opt$stratum %in% unique(ut$stratum))) {
  stop(sprintf("--stratum '%s' is not one of stratum_of()'s values: %s",
               opt$stratum, paste(unique(ut$stratum), collapse = ", ")))
}
target <- ut[ut$stratum == opt$stratum, , drop = FALSE]
target <- target[order(target$unit), , drop = FALSE]

# Optional explicit row restriction (smoke probes only; see --rows help).
if (nzchar(opt$rows)) {
  rows <- as.integer(strsplit(opt$rows, ",", fixed = TRUE)[[1]])
  if (anyNA(rows) || any(rows < 1L) || any(rows > nrow(target))) {
    stop(sprintf("--rows out of range: need 1..%d, got %s", nrow(target), opt$rows))
  }
  target <- target[rows, , drop = FALSE]
  cat(sprintf("[task %d] --rows active: restricted to %d of the %d units in stratum %s.\n",
              opt$task_id, nrow(target), sum(ut$stratum == opt$stratum), opt$stratum))
}

local_task <- opt$task_id - opt$task_base
if (local_task < 1L) {
  stop(sprintf("task_id %d <= task_base %d: the global->local task map is wrong.",
               opt$task_id, opt$task_base))
}
start <- (local_task - 1L) * opt$reps_per_job + 1L
end   <- min(local_task * opt$reps_per_job, nrow(target))
if (start > nrow(target)) {
  # Task index beyond the last unit in this stratum (padding in the final array).
  cat(sprintf("[task %d] no units (row %d > %d rows in stratum %s); exiting.\n",
              opt$task_id, start, nrow(target), opt$stratum))
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
partial_path <- function(u) file.path(partials_dir, sprintf("unit_%06d.rds", u))

# --- Peak RSS, measured not guessed -------------------------------------------
# A finished SLURM job's high-water mark is not recoverable from its result row,
# so lambda-sweep's sizing.json had to record "peak_gb": null and fall back to the
# MEM_FLOOR. /proc/self/status's VmHWM IS the kernel's high-water mark for this
# process, so reading it turns --mem into a measurement. Linux only; NA elsewhere
# (a local plumbing run on macOS), which profile_timing.R handles explicitly
# rather than silently treating as zero.
peak_rss_gb <- function() {
  p <- "/proc/self/status"
  if (!file.exists(p)) return(NA_real_)
  hit <- grep("^VmHWM:", readLines(p, warn = FALSE), value = TRUE)
  if (!length(hit)) return(NA_real_)
  as.numeric(sub("^VmHWM:\\s*([0-9]+)\\s*kB.*$", "\\1", hit[1])) / 1024^2
}

# --- Provenance stamped on EVERY row, including error rows -------------------
# combine.R refuses a result set that mixes these: numerics are not bit-identical
# across R builds or BLAS implementations, so a mixed set is not one experiment.
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

stamp <- function(res, secs) {
  res$stratum     <- opt$stratum
  res$secs        <- secs
  res$peak_rss_gb <- peak_rss_gb()
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
# The error row's schema matches R/run_one.R's success schema column for column,
# so the two bind cleanly and analyze.R's failure accounting sees a real row.
run_unit <- function(unit_row) {
  err <- NA_character_
  t0  <- Sys.time()
  res <- tryCatch(run_one(unit_row),
                  error = function(e) { err <<- conditionMessage(e); NULL })
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (is.null(res)) {
    res <- data.frame(
      unit = unit_row$unit, config_id = unit_row$config_id,
      rep_id = unit_row$rep_id, block = unit_row$block,
      dgp_kind = unit_row$dgp_kind, dgp = unit_row$dgp, n = unit_row$n,
      lambda = unit_row$lambda, method = unit_row$method,
      estimate = NA_real_, std_error = NA_real_,
      ci_lower = NA_real_, ci_upper = NA_real_,
      truth = as.numeric(unit_row$rho_true),
      rho_iw_limit = as.numeric(unit_row$rho_iw_limit),
      error = NA_real_, error_vs_iw_limit = NA_real_,
      covered = NA_integer_, M_final = NA_integer_,
      converged = NA_integer_, n_clipped = NA_integer_,
      error_msg = err, stringsAsFactors = FALSE
    )
  }
  if (!("error_msg" %in% names(res)))     res$error_msg <- err
  else if (is.na(res$error_msg[1]))       res$error_msg <- err
  stamp(res, secs)
}

# --- Run the block, checkpointing each unit ----------------------------------
cat(sprintf("[task %d] stratum %s (local task %d): %d units in stratum; this task rows %d-%d (%d units, ids %d-%d)\n",
            opt$task_id, opt$stratum, local_task, nrow(target),
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
  cat(sprintf("[task %d] unit %d done in %.1f s (%.1f s cumulative)\n",
              opt$task_id, u, row$secs[1],
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
if (n_done_resumed > 0)
  cat(sprintf("[task %d] resumed: %d unit(s) already done, skipped.\n",
              opt$task_id, n_done_resumed))
cat(sprintf("[task %d] block done in %.1f s (%d failed unit(s)); peak RSS %.2f GB\n",
            opt$task_id, elapsed, n_failed, peak_rss_gb()))

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
