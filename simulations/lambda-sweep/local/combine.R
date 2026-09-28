#!/usr/bin/env Rscript
# =============================================================================
# combine.R -- assemble per-unit partials into ONE results object
# =============================================================================
# Reads results/partials/<run-id>/unit_*.rds, de-duplicates by `unit`, ASSERTS
# full coverage of the claimed rep range, and writes
# results/<run-id>_reps<rep-to>.rds.
#
# Fails loudly rather than quietly returning a partial result set (Constitution
# invariant #1): a missing unit, a mixed R/package version, or a non-empty
# `error_msg` is reported, and missing units abort unless --allow-partial is
# given explicitly.
#
# Usage (from the study directory):
#   Rscript local/combine.R --run-id <id> --rep-to 20
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
  library(data.table)
})

option_list <- list(
  make_option("--study-dir", type = "character", dest = "study_dir", default = ".",
              help = "Study directory containing config/ and results/ [default %default]"),
  make_option("--run-id", type = "character", dest = "run_id", default = NULL,
              help = "Run id whose partials to combine (required)"),
  make_option("--rep-from", type = "integer", dest = "rep_from", default = 1L,
              help = "First replication id the run claims to cover [default %default]"),
  make_option("--rep-to", type = "integer", dest = "rep_to", default = NULL,
              help = "Last replication id the run claims to cover (required)"),
  make_option("--allow-partial", action = "store_true", dest = "allow_partial",
              default = FALSE, help = "Write the result set even if units are missing")
)
opt <- parse_args(OptionParser(option_list = option_list))
if (is.null(opt$run_id) || is.null(opt$rep_to)) {
  stop("--run-id and --rep-to are both required.")
}

source(file.path(opt$study_dir, "config", "grid.R"))

partials_dir <- file.path(opt$study_dir, "results", "partials", opt$run_id)
if (!dir.exists(partials_dir)) stop("No partials directory: ", partials_dir)

files <- list.files(partials_dir, pattern = "^unit_[0-9]+\\.rds$", full.names = TRUE)
if (length(files) == 0L) stop("No partials found in ", partials_dir)

res <- rbindlist(lapply(files, readr::read_rds), use.names = TRUE, fill = TRUE)

# --- De-duplicate by unit (a resumed run can legitimately rewrite a partial) ---
n_raw <- nrow(res)
res   <- unique(res, by = "unit")
if (nrow(res) < n_raw) {
  cat(sprintf("[combine] de-duplicated %d duplicate unit rows\n", n_raw - nrow(res)))
}

# --- Coverage assertion -------------------------------------------------------
ut       <- unit_table()
expected <- ut$unit[ut$rep_id >= opt$rep_from & ut$rep_id <= opt$rep_to]
missing  <- setdiff(expected, res$unit)
extra    <- setdiff(res$unit, expected)

cat(sprintf("[combine] run-id %s | expected %d units (reps %d-%d) | present %d | missing %d | extra %d\n",
            opt$run_id, length(expected), opt$rep_from, opt$rep_to,
            sum(res$unit %in% expected), length(missing), length(extra)))
if (length(missing) > 0L && !opt$allow_partial) {
  stop(sprintf("%d expected units are MISSING (e.g. %s). Re-run run_local.R with --run-id %s, or pass --allow-partial deliberately.",
               length(missing), paste(utils::head(missing, 10), collapse = ", "), opt$run_id))
}

res <- res[res$unit %in% expected, ]
setorder(res, unit)

# --- Health report ------------------------------------------------------------
n_err <- sum(!is.na(res$error_msg))
if (n_err > 0L) {
  cat(sprintf("[combine] WARNING: %d of %d units (%.1f%%) FAILED; first message: %s\n",
              n_err, nrow(res), 100 * n_err / nrow(res),
              res$error_msg[!is.na(res$error_msg)][1]))
}
n_nonconv <- sum(res$converged == 0L & is.na(res$error_msg))
if (n_nonconv > 0L) {
  cat(sprintf("[combine] NOTE: %d units hit M_max without meeting the adaptive tolerance\n",
              n_nonconv))
}
for (col in c("r_version", "pkg_version")) {
  vals <- unique(res[[col]])
  if (length(vals) > 1L) {
    stop("Result set mixes ", col, ": ", paste(vals, collapse = ", "),
         " -- numerics are not comparable across builds.")
  }
}
cat(sprintf("[combine] provenance: R %s | surrogateTransportability %s | git %s\n",
            res$r_version[1], res$pkg_version[1], paste(unique(res$git_sha), collapse = ",")))

out <- file.path(opt$study_dir, "results",
                 sprintf("%s_reps%d.rds", opt$run_id, opt$rep_to))
readr::write_rds(as.data.frame(res), out)
cat(sprintf("[combine] wrote %d rows -> %s\n", nrow(res), out))
