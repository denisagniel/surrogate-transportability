#!/usr/bin/env Rscript
# =============================================================================
# smoke_rows.R -- choose the timing-probe rows for ONE stratum
# =============================================================================
# Called by `submit.sh --smoke`. Prints a comma-separated list of 1-based ROW
# indices into the STRATUM-FILTERED unit table (the same table
# run_replication.R slices), for consumption as `--rows`.
#
# WHY NOT CONTIGUOUS. The unit table is config-major, so rows 1..8 of the
# `large_n` stratum are all config 1 (dgp1, importance_weighting) and would size
# the whole array off one corner of the grid. This study has TWO cost axes worth
# straddling inside a stratum:
#
#   * method -- the AIPW arm additionally cross-fits five nuisances per
#     replication via crossfit_nuisances_once() (mgcv GAMs + ranger forests),
#     which the importance-weighting arm does not do at all. That is a
#     structurally different cost, not a scaling factor, and whether it matters
#     for sizing is a question to MEASURE, not assume.
#   * dgp_kind -- confounded specs draw A | X ~ Bernoulli(e(X)), so the AIPW
#     nuisance fits face a genuinely non-constant propensity (and conf2 is the
#     positivity-stress cell, where clipping engages).
#
# So the probe takes rep 1 of every (dgp, method) cell listed below, giving both
# a within-stratum worst case for sizing and a direct IW-vs-AIPW timing contrast.
#
# Usage: Rscript slurm/smoke_rows.R <study-dir> <stratum> [max-rows]
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  cat("usage: Rscript slurm/smoke_rows.R <study-dir> <stratum> [max-rows]\n",
      file = stderr())
  quit(save = "no", status = 2)
}
study_dir <- args[[1]]
stratum   <- args[[2]]
max_rows  <- if (length(args) >= 3L) as.integer(args[[3]]) else NA_integer_

suppressPackageStartupMessages(library(surrogateTransportability))
source(file.path(study_dir, "R", "dgp.R"))
source(file.path(study_dir, "config", "grid.R"))

ut <- unit_table()
ut$stratum <- stratum_of(ut)
t <- ut[ut$stratum == stratum, , drop = FALSE]
t <- t[order(t$unit), , drop = FALSE]
if (!nrow(t)) stop(sprintf("stratum '%s' has no units", stratum))
t$row <- seq_len(nrow(t))

# One probe per (dgp, method, n) cell present in this stratum, at rep 1. `n` is
# part of the cell key -- not just (dgp, method) -- because since the ngrid
# block was added, a single stratum can span multiple n (small_n now covers
# n in {250, 500, 2000}): sizing reps_per_job from an n=250-only sample would
# silently under-cost the n=2000 units sharing that stratum's array. Every dgp
# and every n within the stratum is included rather than a subset.
cells <- unique(t[, c("dgp", "method", "n")])
cells <- cells[order(cells$dgp, cells$method, cells$n), , drop = FALSE]

idx <- integer(0)
for (i in seq_len(nrow(cells))) {
  hit <- t$row[t$dgp == cells$dgp[i] & t$method == cells$method[i] &
                 t$n == cells$n[i] & t$rep_id == 1L]
  if (!length(hit)) {
    stop(sprintf("no rep-1 row for dgp %s method %s n %s in stratum %s",
                 cells$dgp[i], cells$method[i], cells$n[i], stratum))
  }
  idx <- c(idx, hit[1])
}
idx <- unique(idx)
if (!is.na(max_rows) && max_rows > 0L) idx <- idx[seq_len(min(max_rows, length(idx)))]

cat(paste(idx, collapse = ","))
