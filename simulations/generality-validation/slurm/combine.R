#!/usr/bin/env Rscript
# =============================================================================
# combine.R -- aggregate per-task scratch results into ONE final file in home
# =============================================================================
# Reads every task_*.rds from the run's scratch dir, verifies completeness
# against the expected task count, DE-DUPLICATES by work-unit id (keeping the
# newest file on collision), binds them into a single data frame, and writes the
# ONLY home-directory artifact of the run: results/<run-id>.rds.
#
# Loud-failure guarantees (Constitution Section 9, no silent fallbacks):
#   * Errors if the scratch dir does not match the current grid hash (stale code).
#   * Reports every missing task id; refuses to write unless --allow-partial.
#   * De-duplicates by `unit` (duplicate task files -- e.g. from a re-run --
#     otherwise inflate N).
#   * Asserts every unit in 1..TOTAL_UNITS appears exactly once (unless partial).
#   * Reports how many rows carry an `error_msg` (failed replications) so a high
#     silent-failure rate cannot hide.
#
# Usage:
#   Rscript slurm/combine.R --run-id RID --scratch-dir DIR --study-dir DIR \
#           [--allow-partial]
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
})

option_list <- list(
  make_option("--run-id",       type = "character", dest = "run_id"),
  make_option("--scratch-dir",  type = "character", dest = "scratch_dir",
              help = "Run-specific scratch dir containing task_*.rds"),
  make_option("--study-dir",    type = "character", dest = "study_dir", default = ".."),
  make_option("--allow-partial", action = "store_true", dest = "allow_partial",
              default = FALSE, help = "Write result even if some tasks are missing")
)
opt <- parse_args(OptionParser(option_list = option_list))
stopifnot(!is.null(opt$run_id), !is.null(opt$scratch_dir))

source(file.path(opt$study_dir, "config", "grid.R"))

# --- Stale-code guard: compare grid hash recorded at submit time -------------
# Fingerprint the study's SOURCE FILES (not just the GRID object) so any change
# to the design OR the DGP/estimator/run code invalidates an in-flight run.
# Files are hashed in a fixed order; must stay byte-identical to submit.sh.
CODE_FILES <- c("config/grid.R", "R/dgp.R", "R/estimators.R", "R/run_one.R",
                "R/random_dgp.R", "R/true_rho.R")

code_hash <- function(study_dir) {
  # Bitwise-free polynomial rolling hash mod the Mersenne prime 2^31-1. All
  # intermediates stay < 2^53 so double arithmetic is exact (no bitwXor, which
  # overflows past 2^31 in base R; no digest dependency).
  MOD <- 2147483647          # 2^31 - 1
  h <- 0
  for (f in CODE_FILES) {
    bytes <- readBin(file.path(study_dir, f), what = "raw", n = file.size(file.path(study_dir, f)))
    for (b in as.integer(bytes)) h <- (h * 257 + b) %% MOD
  }
  sprintf("%.0f", h)
}

recorded_hash_file <- file.path(opt$scratch_dir, "GRID_HASH")
current_hash <- code_hash(opt$study_dir)
if (file.exists(recorded_hash_file)) {
  recorded <- trimws(readLines(recorded_hash_file, warn = FALSE)[1])
  if (!identical(recorded, current_hash)) {
    stop(sprintf(paste0(
      "STALE RESULTS: scratch dir was created with code hash %s but the study ",
      "source files now hash to %s.\nThe simulation code (grid/dgp/estimators/",
      "run_one) changed after this run started. Re-profile and re-submit, or ",
      "clean this run-id with clean.sh."),
      recorded, current_hash))
  }
} else {
  warning("No GRID_HASH found in scratch dir; cannot verify code freshness.")
}

# --- Discover task files -----------------------------------------------------
files <- list.files(opt$scratch_dir, pattern = "^task_[0-9]+\\.rds$", full.names = TRUE)
if (length(files) == 0) stop(sprintf("No task_*.rds files in %s", opt$scratch_dir))

found_ids <- as.integer(sub("^task_0*([0-9]+)\\.rds$", "\\1", basename(files)))

# Expected task/unit counts from sizing.env (authoritative) if present.
sizing_env <- file.path(opt$study_dir, "config", "sizing.env")
expected_tasks <- NA_integer_
expected_units <- n_units()
if (file.exists(sizing_env)) {
  kv <- readLines(sizing_env, warn = FALSE)
  tt <- grep("^TOTAL_TASKS=", kv, value = TRUE)
  tu <- grep("^TOTAL_UNITS=", kv, value = TRUE)
  if (length(tt)) expected_tasks <- as.integer(sub("^TOTAL_TASKS=", "", tt[1]))
  if (length(tu)) expected_units <- as.integer(sub("^TOTAL_UNITS=", "", tu[1]))
}

if (!is.na(expected_tasks)) {
  missing <- setdiff(seq_len(expected_tasks), found_ids)
  if (length(missing) > 0) {
    msg <- sprintf("MISSING %d/%d tasks: %s", length(missing), expected_tasks,
                   paste(head(missing, 50), collapse = ", "))
    if (opt$allow_partial) {
      warning(msg, "\nProceeding with --allow-partial.")
    } else {
      stop(msg, "\nRefusing to write partial result. Re-run missing tasks or pass --allow-partial.")
    }
  }
}

# --- Stream + bind (data.table::rbindlist; fallback do.call(rbind)) -----------
cat(sprintf("Combining %d task files...\n", length(files)))
# Read newest-file-LAST so that on a duplicate `unit` the newest row wins the
# later de-dup (which keeps the last occurrence).
ord <- order(file.info(files)$mtime)
files <- files[ord]
parts <- lapply(files, readRDS)

use_dt <- requireNamespace("data.table", quietly = TRUE)
if (use_dt) {
  result <- as.data.frame(data.table::rbindlist(parts, use.names = TRUE, fill = TRUE))
} else {
  cat("NOTE: data.table not installed; using do.call(rbind) (slower, needs matching cols).\n")
  cols <- unique(unlist(lapply(parts, names)))
  parts <- lapply(parts, function(d) { for (c in setdiff(cols, names(d))) d[[c]] <- NA; d[, cols, drop = FALSE] })
  result <- do.call(rbind, parts)
}

# --- De-duplicate by unit (keep newest = last occurrence) --------------------
n_raw <- nrow(result)
dup <- duplicated(result$unit, fromLast = TRUE)
if (any(dup)) {
  cat(sprintf("De-dup: dropping %d duplicate unit row(s) (kept newest).\n", sum(dup)))
  result <- result[!dup, , drop = FALSE]
}
result <- result[order(result$unit), , drop = FALSE]
cat(sprintf("Combined %d rows (from %d raw; expected %d units).\n",
            nrow(result), n_raw, expected_units))

# --- Coverage assertion: every unit exactly once (catches mapping bugs) ------
if (!opt$allow_partial) {
  missing_units <- setdiff(seq_len(expected_units), result$unit)
  extra_units   <- setdiff(result$unit, seq_len(expected_units))
  if (length(missing_units) > 0 || length(extra_units) > 0) {
    stop(sprintf(paste0(
      "COVERAGE FAILURE: %d unit(s) missing, %d out-of-range.\n  missing: %s\n  extra: %s\n",
      "Refusing to write. This usually means a sizing mismatch or lost tasks."),
      length(missing_units), length(extra_units),
      paste(head(missing_units, 30), collapse = ", "),
      paste(head(extra_units, 30), collapse = ", ")))
  }
}

# --- Surface failed replications (M4: no silent all-NA) ----------------------
if ("error_msg" %in% names(result)) {
  n_err <- sum(!is.na(result$error_msg))
  if (n_err > 0) {
    cat(sprintf("WARNING: %d/%d unit(s) (%.1f%%) carry an error_msg (failed replications).\n",
                n_err, nrow(result), 100 * n_err / nrow(result)))
    ex <- head(unique(result$error_msg[!is.na(result$error_msg)]), 3)
    cat("  example error(s):\n"); for (e in ex) cat(sprintf("    - %s\n", e))
  } else {
    cat("All units succeeded (no error_msg set).\n")
  }
}

# --- Attach provenance metadata ----------------------------------------------
attr(result, "run_id")    <- opt$run_id
attr(result, "grid_hash") <- current_hash
attr(result, "combined_at") <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

# --- Write the ONE home artifact ---------------------------------------------
results_dir <- file.path(opt$study_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(results_dir, sprintf("%s.rds", opt$run_id))
saveRDS(result, out)
cat(sprintf("Wrote FINAL result to home: %s\n", out))
cat("Scratch per-task files can now be cleaned with clean.sh.\n")
