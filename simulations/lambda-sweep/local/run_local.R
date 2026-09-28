#!/usr/bin/env Rscript
# =============================================================================
# run_local.R -- run the lambda sweep on ONE workstation (no scheduler)
# =============================================================================
# Why local and not O2: see README.md, "Cost and sizing decision". Short version:
# the whole sweep is ~26 CPU-hours, which is small for a cluster and large for a
# laptop, and -- decisively -- O2 can only run code that git has delivered, which
# this study is not permitted to push. So: one box, `parallel::mclapply`, per-unit
# checkpointing so a crash costs one unit rather than the run.
#
# Crash safety / resumability (same contract as the O2 scaffold's
# slurm/run_replication.R, minus SLURM):
#   * each finished unit is flushed atomically to
#     results/partials/<run-id>/unit_NNNNNN.rds;
#   * a re-invocation with the same --run-id SKIPS completed units;
#   * a unit that throws persists its ERROR TEXT in `error_msg` rather than a
#     silent all-NA row.
#
# Rep BLOCKS: --rep-from/--rep-to run a contiguous range of replications. Because
# config/grid.R keys the dataset seed on (dgp, rep) and the sampler seed on
# (config_id, rep), a later block EXTENDS the study without invalidating an
# earlier one; combine.R asserts coverage over whatever rep range you claim.
#
# Usage (from the study directory):
#   Rscript local/run_local.R --smoke                       # 8 units, ~2 min
#   Rscript local/run_local.R --rep-from 1 --rep-to 20      # first block
#   Rscript local/run_local.R --rep-from 1 --rep-to 20 --run-id <id>   # resume
#
# Run time: ~64 s per unit at n = 10,000 (measured, see README); 36 configs x 20
# reps = 720 units ~= 12.8 CPU-hours ~= 1.6 h wall on 8 workers.
# =============================================================================

suppressPackageStartupMessages({
  library(optparse)
  library(surrogateTransportability)
})

option_list <- list(
  make_option("--study-dir", type = "character", dest = "study_dir", default = ".",
              help = "Study directory containing config/ and R/ [default %default]"),
  make_option("--rep-from", type = "integer", dest = "rep_from", default = 1L,
              help = "First replication id to run [default %default]"),
  make_option("--rep-to", type = "integer", dest = "rep_to", default = 20L,
              help = "Last replication id to run [default %default]"),
  make_option("--workers", type = "integer", dest = "workers", default = 8L,
              help = "Parallel workers (mclapply cores) [default %default]"),
  make_option("--run-id", type = "character", dest = "run_id", default = NULL,
              help = "Existing run id to RESUME; a new one is minted if omitted"),
  make_option("--smoke", action = "store_true", dest = "smoke", default = FALSE,
              help = "Tiny run (rep 1, 2 lambdas x 4 DGPs) to check the plumbing")
)
opt <- parse_args(OptionParser(option_list = option_list))

# --- Load study code (order matters: cell_cates before estimators) ------------
source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "R", "cell_cates.R"))
source(file.path(opt$study_dir, "R", "dgp.R"))
source(file.path(opt$study_dir, "R", "estimators.R"))
source(file.path(opt$study_dir, "R", "run_one.R"))

# --- Assertions near the top: fail loudly, not three hours in -----------------
spec_p_min <- vapply(c("dgp1", "dgp2", "dgp4", "dgp5"),
                     function(d) min(canonical_dgp_params(d)$p_X), numeric(1))
if (!all(abs(spec_p_min - P_MIN_CANONICAL) < 1e-12)) {
  stop("p_min drifted from P_MIN_CANONICAL (", P_MIN_CANONICAL, "): ",
       paste(sprintf("%s=%.4g", names(spec_p_min), spec_p_min), collapse = ", "),
       ". The lambda grid's interior/exit split in config/grid.R is no longer valid.")
}
if (!any(LAMBDA_GRID <= P_MIN_CANONICAL) || !any(LAMBDA_GRID > P_MIN_CANONICAL)) {
  stop("LAMBDA_GRID must straddle p_min = ", P_MIN_CANONICAL,
       " (interior-regime boundary); it does not.")
}
if (opt$rep_from < 1L || opt$rep_to > TOTAL_REPS || opt$rep_from > opt$rep_to) {
  stop("Bad rep range [", opt$rep_from, ", ", opt$rep_to, "]; TOTAL_REPS = ", TOTAL_REPS, ".")
}

# --- Run identity ------------------------------------------------------------
# base::`%||%` only exists from R 4.4.0; define a local fallback for older R.
if (!exists("%||%")) `%||%` <- function(x, y) if (is.null(x)) y else x

git_sha <- tryCatch(
  sub("\\s+$", "", system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)),
  error = function(e) "nogit"
)
run_id <- opt$run_id %||% sprintf("%s_%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)

results_dir  <- file.path(opt$study_dir, "results")
partials_dir <- file.path(results_dir, "partials", run_id)
dir.create(partials_dir, recursive = TRUE, showWarnings = FALSE)

# --- Select this invocation's units -------------------------------------------
ut <- unit_table()
sel <- ut$rep_id >= opt$rep_from & ut$rep_id <= opt$rep_to
if (opt$smoke) {
  sel <- ut$rep_id == 1L & ut$lambda %in% c(min(LAMBDA_GRID), max(LAMBDA_GRID))
}
units <- ut[sel, , drop = FALSE]

done_files <- list.files(partials_dir, pattern = "^unit_[0-9]+\\.rds$")
done_units <- as.integer(sub("^unit_0*([0-9]+)\\.rds$", "\\1", done_files))
todo <- units[!units$unit %in% done_units, , drop = FALSE]

cat(sprintf(paste0("[lambda-sweep] run-id %s | git %s\n",
                   "  configs %d | reps %d-%d | units selected %d | already done %d | to run %d\n",
                   "  workers %d | partials %s\n"),
            run_id, git_sha, nrow(GRID), opt$rep_from, opt$rep_to,
            nrow(units), sum(units$unit %in% done_units), nrow(todo),
            opt$workers, partials_dir))
if (nrow(todo) == 0L) {
  cat("[lambda-sweep] nothing to do; every selected unit already has a partial.\n")
  quit(save = "no", status = 0)
}

# --- Worker: one unit -> one atomically-written partial ------------------------
run_unit <- function(i) {
  row  <- todo[i, , drop = FALSE]
  path <- file.path(partials_dir, sprintf("unit_%06d.rds", row$unit))
  res <- tryCatch(
    run_one(row),
    error = function(e) {
      # No silent all-NA row: persist the message alongside the unit identity.
      data.frame(
        unit = row$unit, config_id = row$config_id, rep_id = row$rep_id,
        dgp = row$dgp, n = row$n, lambda = row$lambda, method = row$method,
        estimate = NA_real_, std_error = NA_real_, ci_lower = NA_real_,
        ci_upper = NA_real_, truth = NA_real_, truth_source = NA_character_,
        error = NA_real_, covered = NA_integer_, M_final = NA_integer_,
        converged = 0L, secs = NA_real_,
        error_msg = conditionMessage(e), stringsAsFactors = FALSE
      )
    }
  )
  res$run_id      <- run_id
  res$git_sha     <- git_sha
  res$r_version   <- paste(R.version$major, R.version$minor, sep = ".")
  res$pkg_version <- as.character(utils::packageVersion("surrogateTransportability"))

  tmp <- paste0(path, ".tmp")
  readr::write_rds(res, tmp)
  file.rename(tmp, path)   # atomic: no half-written partial is ever visible
  invisible(NULL)
}

t_start <- proc.time()[["elapsed"]]
invisible(parallel::mclapply(seq_len(nrow(todo)), run_unit, mc.cores = opt$workers,
                             mc.preschedule = FALSE))
elapsed <- proc.time()[["elapsed"]] - t_start

n_done <- length(list.files(partials_dir, pattern = "^unit_[0-9]+\\.rds$"))
cat(sprintf("[lambda-sweep] finished %d units in %.1f min (%.1f s/unit/worker); partials now %d\n",
            nrow(todo), elapsed / 60, elapsed * opt$workers / max(nrow(todo), 1L), n_done))
cat(sprintf("[lambda-sweep] combine with:\n  Rscript local/combine.R --run-id %s --rep-to %d\n",
            run_id, opt$rep_to))
