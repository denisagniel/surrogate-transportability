#!/usr/bin/env Rscript
# =============================================================================
# _code_hash.R -- THE single definition of this study's source-code fingerprint
# =============================================================================
# Both a sourceable library and a CLI. submit.sh / retry_failed.sh call it as a
# CLI to record the hash at submission; combine.R sources it to re-check.
#
# WHY ONE FILE. canonical-validation carries this hash in THREE copies (inline in
# submit.sh, inline in retry_failed.sh, and as code_hash() in combine.R), kept in
# agreement only by a comment reading "must produce byte-identical output". A
# writer/reader disagreement there does not fail loudly -- it fails as a spurious
# "study code changed since run X", sending you to re-run a sweep that was fine.
#
# CLI GUARD. The guard is `sys.nframe() == 0L`, NOT `any(grepl("^--file=",
# commandArgs(FALSE)))`: `Rscript slurm/combine.R` also sets --file=, so the
# grepl form matches while merely being SOURCED, reads combine.R's arguments,
# prints usage and quits. That defect made combine.R unrunnable in the upstream
# scaffold; see the setup-cluster-simulations 2026-09-22 version note.
#
# Hash: bitwise-free polynomial rolling hash mod the Mersenne prime 2^31-1. All
# intermediates stay < 2^53 so double arithmetic is exact (base-R bitwXor/integer
# arithmetic overflows past 2^31 -- see MEMORY base-r-hashing-gotcha).
#
# Usage (CLI):  Rscript slurm/_code_hash.R <study-dir>
# =============================================================================

# The run path only. R/exit_interior_prediction.R and R/plot_lambda_profile.R are
# ANALYSIS code: editing them cannot change a single simulated number, so making
# them invalidate an in-flight 720-unit run would be a false alarm.
CODE_FILES <- c("config/grid.R", "R/cell_cates.R", "R/dgp.R",
                "R/estimators.R", "R/run_one.R")

code_hash <- function(study_dir) {
  MOD <- 2147483647                      # 2^31 - 1
  h <- 0
  for (f in CODE_FILES) {
    p <- file.path(study_dir, f)
    if (!file.exists(p)) stop(sprintf("code_hash(): missing source file %s", p))
    bytes <- readBin(p, what = "raw", n = file.size(p))
    for (b in as.integer(bytes)) h <- (h * 257 + b) %% MOD
  }
  sprintf("%.0f", h)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) {
    cat("usage: Rscript slurm/_code_hash.R <study-dir>\n", file = stderr())
    quit(save = "no", status = 2)
  }
  cat(code_hash(args[1]))
}
