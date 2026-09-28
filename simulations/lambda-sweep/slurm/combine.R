#!/usr/bin/env Rscript
# =============================================================================
# combine.R -- aggregate per-task scratch results into ONE final file in home
# =============================================================================
# The O2 counterpart of local/combine.R. It keeps every guard that script had
# (rep-scope coverage assertion, de-dup by unit, failure report, single-build
# provenance) and adds the two the cluster path needs (stale-code hash, rep-scope
# agreement between submission and combination).
#
# Output name matches local/combine.R exactly -- results/<run-id>_reps<REP_TO>.rds
# -- so R/plot_lambda_profile.R consumes it with no change.
#
# Loud-failure guarantees (Constitution invariant #1, no silent fallbacks):
#   * Errors if the scratch dir's recorded code hash != the current source hash.
#   * Errors if the scratch dir's recorded REP SCOPE != the scope being asserted.
#   * Reports every missing task id; refuses to write unless --allow-partial.
#   * De-duplicates by `unit` (a resumed run legitimately rewrites a partial).
#   * Asserts the in-scope unit set is covered EXACTLY (unless --allow-partial).
#   * Reports rows carrying an `error_msg`, and non-converged units.
#   * REFUSES a result set mixing r_version / pkg_version / backend: numerics are
#     not bit-identical across R builds or BLAS, so a mixed set is not one
#     experiment. This is the guard that made the 236 local partials (R 4.5.1)
#     un-mergeable with this O2 run (R 4.4.2) -- see MANIFEST.md.
#
# Usage:
#   Rscript slurm/combine.R --run-id RID --scratch-dir DIR --study-dir . [--allow-partial]
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option("--run-id",      type = "character", dest = "run_id"),
  make_option("--scratch-dir", type = "character", dest = "scratch_dir",
              help = "Run-specific scratch dir containing task_*.rds and partials/"),
  make_option("--study-dir",   type = "character", dest = "study_dir", default = "..",
              help = "Study directory containing config/, R/, slurm/ [default %default]"),
  make_option("--from-partials", action = "store_true", dest = "from_partials",
              default = FALSE,
              help = "Read unit partials directly instead of assembled task files"),
  make_option("--allow-partial", action = "store_true", dest = "allow_partial",
              default = FALSE, help = "Write result even if units/tasks are missing")
)
opt <- parse_args(OptionParser(option_list = option_list))
stopifnot(!is.null(opt$run_id), !is.null(opt$scratch_dir))

source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "slurm", "_code_hash.R"))

# --- Stale-code guard ---------------------------------------------------------
recorded_hash_file <- file.path(opt$scratch_dir, "GRID_HASH")
current_hash <- code_hash(opt$study_dir)
if (file.exists(recorded_hash_file)) {
  recorded <- trimws(readLines(recorded_hash_file, warn = FALSE)[1])
  if (!identical(recorded, current_hash)) {
    stop(sprintf(paste0(
      "STALE RESULTS: scratch dir was created with code hash %s but the study ",
      "source files now hash to %s.\nThe simulation code (grid/cell_cates/dgp/",
      "estimators/run_one) changed after this run started. Re-profile and ",
      "re-submit, or clean this run-id with clean.sh."),
      recorded, current_hash))
  }
} else {
  warning("No GRID_HASH found in scratch dir; cannot verify code freshness.")
}

# --- Rep-scope guard ----------------------------------------------------------
# Which units this run was SUPPOSED to cover is not derivable from the grid alone
# (TOTAL_REPS = 40 declared, reps 1-20 executed), so submit.sh records it and we
# read it back rather than re-deriving it from a possibly-edited sizing.env.
scope_file <- file.path(opt$scratch_dir, "REP_SCOPE")
if (!file.exists(scope_file)) {
  stop(sprintf(paste0("No REP_SCOPE in %s. This run's executed replication range is ",
                      "unknown, so a coverage assertion would be meaningless. ",
                      "Refusing to combine."), opt$scratch_dir))
}
scope <- setNames(
  sub("^[^=]+=", "", readLines(scope_file, warn = FALSE)),
  sub("=.*$", "", readLines(scope_file, warn = FALSE))
)
rep_from <- as.integer(scope[["REP_FROM"]])
rep_to   <- as.integer(scope[["REP_TO"]])
expected_tasks <- as.integer(scope[["TOTAL_TASKS"]])
expected_units_n <- as.integer(scope[["TOTAL_UNITS"]])

sizing_env <- file.path(opt$study_dir, "config", "sizing.env")
if (file.exists(sizing_env)) {
  kv <- readLines(sizing_env, warn = FALSE)
  get_kv <- function(k) {
    hit <- grep(sprintf("^%s=", k), kv, value = TRUE)
    if (length(hit)) as.integer(sub("^[^=]+=", "", hit[1])) else NA_integer_
  }
  for (k in c("REP_FROM", "REP_TO")) {
    now <- get_kv(k); then <- as.integer(scope[[k]])
    if (!is.na(now) && !identical(now, then)) {
      stop(sprintf(paste0("REP SCOPE MISMATCH: run %s was submitted with %s=%d but ",
                          "config/sizing.env now says %d. The task->unit mapping depends ",
                          "on the rep scope, so this result set would be mis-asserted. ",
                          "Refusing to combine."), opt$run_id, k, then, now))
    }
  }
}

ut <- unit_table()
expected_units <- sort(ut$unit[ut$rep_id >= rep_from & ut$rep_id <= rep_to])
if (length(expected_units) != expected_units_n) {
  stop(sprintf(paste0("REP SCOPE INCONSISTENT: REP_SCOPE claims %d units for reps %d-%d ",
                      "but the current grid yields %d. config/grid.R changed shape. ",
                      "Refusing to combine."),
               expected_units_n, rep_from, rep_to, length(expected_units)))
}
cat(sprintf("Run %s: rep scope %d-%d -> %d expected units, %d expected tasks.\n",
            opt$run_id, rep_from, rep_to, length(expected_units), expected_tasks))

# --- Discover result files ----------------------------------------------------
if (isTRUE(opt$from_partials)) {
  pdir <- file.path(opt$scratch_dir, "partials")
  files <- list.files(pdir, pattern = "^unit_[0-9]+[.]rds$", full.names = TRUE)
  if (!length(files)) stop(sprintf("No unit_*.rds in %s", pdir))
  cat(sprintf("Reading %d unit partial(s) directly (--from-partials).\n", length(files)))
} else {
  files <- list.files(opt$scratch_dir, pattern = "^task_[0-9]+[.]rds$", full.names = TRUE)
  if (!length(files)) {
    stop(sprintf(paste0("No task_*.rds files in %s.\nIf the array is still running, ",
                        "use --from-partials to inspect progress, or wait."), opt$scratch_dir))
  }
  found_ids <- as.integer(sub("^task_0*([0-9]+)[.]rds$", "\\1", basename(files)))
  missing_tasks <- setdiff(seq_len(expected_tasks), found_ids)
  if (length(missing_tasks) > 0) {
    msg <- sprintf("MISSING %d/%d tasks: %s", length(missing_tasks), expected_tasks,
                   paste(head(missing_tasks, 50), collapse = ", "))
    if (opt$allow_partial) warning(msg, "\nProceeding with --allow-partial.")
    else stop(msg, "\nRefusing to write partial result. Retry missing tasks (slurm/retry_failed.sh) or pass --allow-partial.")
  }
  cat(sprintf("Combining %d task file(s)...\n", length(files)))
}

# Read newest-file-LAST so that on a duplicate `unit` the newest row wins the
# de-dup below (which keeps the last occurrence).
files <- files[order(file.info(files)$mtime)]
parts <- lapply(files, readRDS)

if (requireNamespace("data.table", quietly = TRUE)) {
  result <- as.data.frame(data.table::rbindlist(parts, use.names = TRUE, fill = TRUE))
} else {
  cat("NOTE: data.table not installed; using do.call(rbind).\n")
  cols  <- unique(unlist(lapply(parts, names)))
  parts <- lapply(parts, function(d) { for (c in setdiff(cols, names(d))) d[[c]] <- NA; d[, cols, drop = FALSE] })
  result <- do.call(rbind, parts)
}

# --- De-duplicate by unit (keep newest = last occurrence) ---------------------
n_raw <- nrow(result)
dup <- duplicated(result$unit, fromLast = TRUE)
if (any(dup)) {
  cat(sprintf("De-dup: dropping %d duplicate unit row(s) (kept newest).\n", sum(dup)))
  result <- result[!dup, , drop = FALSE]
}
result <- result[order(result$unit), , drop = FALSE]
cat(sprintf("Combined %d rows (from %d raw; expected %d units).\n",
            nrow(result), n_raw, length(expected_units)))

# --- Coverage assertion against the IN-SCOPE unit set ------------------------
missing_units <- setdiff(expected_units, result$unit)
extra_units   <- setdiff(result$unit, expected_units)
if (length(extra_units) > 0) {
  stop(sprintf(paste0("OUT-OF-SCOPE UNITS: %d row(s) are outside reps %d-%d (e.g. %s).\n",
                      "That means a task mapped to the wrong units. Refusing to write."),
               length(extra_units), rep_from, rep_to,
               paste(head(extra_units, 30), collapse = ", ")))
}
if (length(missing_units) > 0) {
  msg <- sprintf("COVERAGE: %d/%d in-scope unit(s) MISSING (e.g. %s).",
                 length(missing_units), length(expected_units),
                 paste(head(missing_units, 30), collapse = ", "))
  if (opt$allow_partial) warning(msg, "\nProceeding with --allow-partial.")
  else stop(msg, "\nRefusing to write. Resume with slurm/retry_failed.sh, or pass --allow-partial deliberately.")
}

# --- Health report -----------------------------------------------------------
n_err <- sum(!is.na(result$error_msg))
if (n_err > 0) {
  cat(sprintf("WARNING: %d/%d unit(s) (%.1f%%) carry an error_msg (failed replications).\n",
              n_err, nrow(result), 100 * n_err / nrow(result)))
  for (e in head(unique(result$error_msg[!is.na(result$error_msg)]), 3)) cat(sprintf("    - %s\n", e))
} else {
  cat("All units succeeded (no error_msg set).\n")
}
n_nonconv <- sum(result$converged == 0L & is.na(result$error_msg), na.rm = TRUE)
if (n_nonconv > 0) {
  cat(sprintf("NOTE: %d unit(s) hit M_max without meeting the adaptive tolerance.\n", n_nonconv))
}

# --- Single-build provenance (see header) ------------------------------------
for (col in c("r_version", "pkg_version", "backend")) {
  if (!col %in% names(result)) next
  vals <- unique(result[[col]])
  if (length(vals) > 1L) {
    stop(sprintf(paste0("Result set mixes %s: %s -- numerics are not comparable across ",
                        "builds/backends. Refusing to write a set that is not one experiment."),
                 col, paste(vals, collapse = ", ")))
  }
}
cat(sprintf("Provenance: backend %s | R %s | surrogateTransportability %s | git %s\n",
            result$backend[1], result$r_version[1], result$pkg_version[1],
            paste(unique(result$git_sha), collapse = ",")))

attr(result, "run_id")      <- opt$run_id
attr(result, "code_hash")   <- current_hash
attr(result, "rep_scope")   <- c(from = rep_from, to = rep_to)
attr(result, "combined_at") <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

results_dir <- file.path(opt$study_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(results_dir, sprintf("%s_reps%d.rds", opt$run_id, rep_to))
saveRDS(result, out)
cat(sprintf("Wrote FINAL result to home: %s\n", out))
cat("Plot with: Rscript R/plot_lambda_profile.R\n")
cat("Scratch per-task files can then be cleaned with slurm/clean.sh.\n")
