#!/usr/bin/env Rscript
# =============================================================================
# combine.R -- aggregate per-task scratch results into ONE final file in home
# =============================================================================
# The O2 counterpart of the integrity checks and provenance block that
# run_study.R (the local driver) performs inline. It keeps every guard that
# script had (exactly-once unit coverage, duplicate detection, failure report,
# provenance attributes) and adds the four the cluster path needs: a stale-code
# hash, per-STRATUM scope agreement between submission and combination, a
# single-build guard, and a missing-task report.
#
# OUTPUT NAME IS DELIBERATE: results/<run-id>.rds, exactly the path run_study.R
# writes and analyze.R's resolve_run() discovers (it globs
# ^[0-9]{8}-[0-9]{6}.*\.rds$ and excludes *_summary.rds). The provenance
# ATTRIBUTES analyze.R reads -- run_id, pkg_version, r_version, smoke -- are set
# below from the rows themselves, so analyze.R runs against a cluster result with
# no modification. That compatibility is the point: this is an infrastructure
# migration, not a reanalysis.
#
# Loud-failure guarantees (Constitution invariant #1, no silent fallbacks):
#   * Errors if the scratch dir's recorded code hash != the current source hash.
#   * Errors if the scratch dir's recorded STRATUM SCOPE != today's grid shape.
#   * Reports every missing task id; refuses to write unless --allow-partial.
#   * De-duplicates by `unit` (a resumed run legitimately rewrites a partial).
#   * Asserts the unit set is covered EXACTLY ONCE, and separately PER STRATUM,
#     so a task that ran the wrong stratum's rows cannot hide in a correct total.
#   * Reports rows carrying an `error_msg`, and non-converged units.
#   * REFUSES a result set mixing r_version / pkg_version / backend: numerics are
#     not bit-identical across R builds or BLAS, so a mixed set is not one
#     experiment.
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

# ORDER MATTERS: grid.R's unit_table() calls spec_for() from R/dgp.R, which calls
# the package's spec accessors.
suppressPackageStartupMessages(library(surrogateTransportability))
source(file.path(opt$study_dir, "R", "dgp.R"))
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
      "source files now hash to %s.\nThe simulation code (grid/dgp/estimators/",
      "run_one) changed after this run started. Re-profile and re-submit, or ",
      "clean this run-id with clean.sh."),
      recorded, current_hash))
  }
} else {
  warning("No GRID_HASH found in scratch dir; cannot verify code freshness.")
}

# --- Stratum-scope guard ------------------------------------------------------
# Which units this run was SUPPOSED to cover, and how tasks map onto them, is a
# function of (stratum, reps_per_job, task_base). submit.sh records it; we read it
# back rather than re-deriving it from a possibly re-profiled config/sizing.tsv.
scope_tsv <- file.path(opt$scratch_dir, "SCOPE.tsv")
scope_env <- file.path(opt$scratch_dir, "SCOPE.env")
if (!file.exists(scope_tsv)) {
  stop(sprintf(paste0("No SCOPE.tsv in %s. This run's stratum/task plan is unknown, so a ",
                      "coverage assertion would be meaningless. Refusing to combine."),
               opt$scratch_dir))
}
scope <- read.delim(scope_tsv, stringsAsFactors = FALSE)
stopifnot(all(c("stratum", "total_units", "reps_per_job", "total_tasks", "task_base")
              %in% names(scope)))
is_smoke <- FALSE
if (file.exists(scope_env)) {
  kv <- readLines(scope_env, warn = FALSE)
  hit <- grep("^SMOKE=", kv, value = TRUE)
  if (length(hit)) is_smoke <- identical(sub("^SMOKE=", "", hit[1]), "1")
}
if (is_smoke) {
  stop(paste0("This scratch dir is a SMOKE timing probe (SCOPE.env says SMOKE=1). Its ",
              "units are a deliberate non-representative subset, so combining it into ",
              "results/ would produce an unreportable file that analyze.R could not ",
              "distinguish from a real run. Refusing."))
}

ut <- unit_table()
ut$stratum <- stratum_of(ut)

# The grid must still have the shape it had at submission, per stratum.
for (i in seq_len(nrow(scope))) {
  s <- scope$stratum[i]
  now <- sum(ut$stratum == s)
  if (now != scope$total_units[i]) {
    stop(sprintf(paste0("STRATUM SCOPE INCONSISTENT: SCOPE.tsv claims %d units for stratum ",
                        "'%s' but the current grid yields %d. config/grid.R changed shape. ",
                        "Refusing to combine."),
                 scope$total_units[i], s, now))
  }
}
expected_by_stratum <- lapply(scope$stratum, function(s) sort(ut$unit[ut$stratum == s]))
names(expected_by_stratum) <- scope$stratum
expected_units <- sort(unlist(expected_by_stratum, use.names = FALSE))
expected_tasks <- sum(scope$total_tasks)

cat(sprintf("Run %s: %d expected units across %d strata, %d expected tasks.\n",
            opt$run_id, length(expected_units), nrow(scope), expected_tasks))
for (i in seq_len(nrow(scope))) {
  cat(sprintf("  stratum %-9s %4d units, %3d units/task, %3d tasks (global %d-%d)\n",
              scope$stratum[i], scope$total_units[i], scope$reps_per_job[i],
              scope$total_tasks[i], scope$task_base[i] + 1L,
              scope$task_base[i] + scope$total_tasks[i]))
}

# --- Discover result files ----------------------------------------------------
if (isTRUE(opt$from_partials)) {
  pdir <- file.path(opt$scratch_dir, "partials")
  files <- list.files(pdir, pattern = "^unit_[0-9]+[.]rds$", full.names = TRUE)
  if (!length(files)) stop(sprintf("No unit_*.rds in %s", pdir))
  cat(sprintf("Reading %d unit partial(s) directly (--from-partials).\n", length(files)))
} else {
  files <- list.files(opt$scratch_dir, pattern = "^task_[0-9]+[.]rds$", full.names = TRUE)
  if (!length(files)) {
    stop(sprintf(paste0("No task_*.rds files in %s.\nIf the arrays are still running, ",
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

# --- Coverage assertion: total AND per stratum --------------------------------
# Per-stratum is not redundant with the total. A task that computed its block from
# the WRONG stratum's filtered table could still land inside the global unit set
# (the strata partition it), producing duplicates in one stratum and gaps in the
# other. Checking both makes that failure mode visible.
extra_units <- setdiff(result$unit, expected_units)
if (length(extra_units) > 0) {
  stop(sprintf(paste0("OUT-OF-SCOPE UNITS: %d row(s) are outside the submitted stratum plan ",
                      "(e.g. %s).\nThat means a task mapped to the wrong units. Refusing to write."),
               length(extra_units), paste(head(extra_units, 30), collapse = ", ")))
}
missing_units <- setdiff(expected_units, result$unit)
if (length(missing_units) > 0) {
  msg <- sprintf("COVERAGE: %d/%d unit(s) MISSING (e.g. %s).",
                 length(missing_units), length(expected_units),
                 paste(head(missing_units, 30), collapse = ", "))
  if (opt$allow_partial) warning(msg, "\nProceeding with --allow-partial.")
  else stop(msg, "\nRefusing to write. Resume with slurm/retry_failed.sh, or pass --allow-partial deliberately.")
}
for (s in names(expected_by_stratum)) {
  got <- sort(result$unit[!is.na(result$stratum) & result$stratum == s])
  want <- expected_by_stratum[[s]]
  if (!opt$allow_partial && !identical(got, want)) {
    stop(sprintf(paste0("STRATUM COVERAGE FAILED for '%s': %d rows claim this stratum but ",
                        "%d units belong to it (%d missing, %d unexpected). Refusing to write."),
                 s, length(got), length(want),
                 length(setdiff(want, got)), length(setdiff(got, want))))
  }
  cat(sprintf("  stratum %-9s covered %d/%d units exactly once.\n",
              s, length(intersect(got, want)), length(want)))
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
  cat(sprintf("NOTE: %d unit(s) hit M_max = %d without meeting the adaptive tolerance.\n",
              n_nonconv, M_MAX))
}
if ("secs" %in% names(result)) {
  for (s in names(expected_by_stratum)) {
    v <- result$secs[!is.na(result$stratum) & result$stratum == s & is.finite(result$secs)]
    if (length(v)) {
      cat(sprintf("Observed per-unit secs, stratum %-9s n=%4d | median %6.1f | q0.9 %6.1f | max %7.1f\n",
                  s, length(v), median(v), quantile(v, 0.9, names = FALSE), max(v)))
    }
  }
}
if ("peak_rss_gb" %in% names(result)) {
  pk <- result$peak_rss_gb[is.finite(result$peak_rss_gb)]
  if (length(pk)) cat(sprintf("Observed peak RSS: median %.2f GB | max %.2f GB (n=%d)\n",
                              median(pk), max(pk), length(pk)))
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

# --- Attributes: the run_study.R contract, so analyze.R needs no change -------
attr(result, "run_id")      <- opt$run_id
attr(result, "smoke")       <- FALSE
attr(result, "grid")        <- GRID
attr(result, "M_max")       <- M_MAX
attr(result, "pkg_version") <- result$pkg_version[1]
# analyze.R prints this verbatim; make it read as a version string, matching what
# run_study.R stored (R.version.string) rather than the bare "4.4.2" the rows use.
attr(result, "r_version")   <- sprintf("R version %s (backend %s)",
                                       result$r_version[1], result$backend[1])
attr(result, "code_hash")   <- current_hash
attr(result, "strata")      <- scope
attr(result, "combined_at") <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
if ("secs" %in% names(result)) {
  attr(result, "runtime_mins") <- sum(result$secs, na.rm = TRUE) / 60   # CPU-minutes
}

results_dir <- file.path(opt$study_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(results_dir, sprintf("%s.rds", opt$run_id))
saveRDS(result, out)
cat(sprintf("Wrote FINAL result to home: %s\n", out))
cat(sprintf("Summarise with: Rscript analyze.R --run-id %s\n", opt$run_id))
cat("Scratch per-task files can then be cleaned with slurm/clean.sh.\n")
