#!/usr/bin/env Rscript
# =============================================================================
# prep_offline.R -- one-time offline prep for the generality-validation study
# =============================================================================
# Two compute-heavy steps that must run ONCE before profiling/submitting. Too
# slow for a laptop (each is many high-M MCMC truth computations) -- run on O2 as
# a single short interactive/batch job, NOT on the login node:
#
#   1. Balanced ensemble seeds  -> config/ensemble_seeds.rds
#      Scan candidate seeds, keep a rho-balanced subset (flat across [-1,1]) so
#      the ensemble stresses the estimator instead of piling up at |rho|~1.
#   2. Exact per-config truth   -> config/truth_table.rds
#      rho_true for every GRID config at high M_ref (noise << CI half-width).
#
# Usage (on O2, from the study dir, after `module load R`):
#   Rscript slurm/prep_offline.R [--study-dir .] [--scan A:B] [--per-bin K] \
#           [--m-ref N]
# Re-run only if the DGP family, grid, or lambda changes.
# =============================================================================

suppressPackageStartupMessages(library(optparse))
opt <- parse_args(OptionParser(option_list = list(
  make_option("--study-dir", type = "character", dest = "study_dir", default = "."),
  make_option("--scan",      type = "character", dest = "scan", default = "8000:8800",
              help = "seed scan range A:B for balanced selection [default %default]"),
  make_option("--per-bin",   type = "integer",   dest = "per_bin", default = 7L),
  make_option("--m-ref",     type = "integer",   dest = "m_ref", default = 100000L,
              help = "M_ref for the exact truth table [default %default]")
)))

suppressWarnings(suppressPackageStartupMessages({
  library(surrogateTransportability); library(mgcv); library(ranger)
}))
sd <- opt$study_dir
source(file.path(sd, "R", "random_dgp.R"))
source(file.path(sd, "R", "true_rho.R"))

# --- Step 1: balanced ensemble seeds -----------------------------------------
scan_bounds <- as.integer(strsplit(opt$scan, ":", fixed = TRUE)[[1]])
scan_seeds  <- scan_bounds[1]:scan_bounds[2]
cat(sprintf("Step 1: scanning %d seeds for a rho-balanced ensemble (per_bin=%d)...\n",
            length(scan_seeds), opt$per_bin))
seeds <- build_balanced_seeds(scan_seeds = scan_seeds, lambda = 0.3,
                              per_bin = opt$per_bin, M_ref = 4000L, thin = 12L)
cat(sprintf("  selected %d seeds; bin counts: %s\n",
            length(seeds), paste(attr(seeds, "bin_counts"), collapse = " ")))
saveRDS(seeds, file.path(sd, "config", "ensemble_seeds.rds"))

# --- Step 2: exact truth table (uses the seeds just written) -----------------
# Re-source grid.R now that ensemble_seeds.rds exists so GRID uses the real seeds.
source(file.path(sd, "config", "grid.R"))
cat(sprintf("Step 2: exact truth for %d configs at M_ref=%d...\n",
            nrow(GRID), opt$m_ref))
truth <- build_truth_table(GRID, M_ref = opt$m_ref, thin = 20L)
saveRDS(truth, file.path(sd, "config", "truth_table.rds"))
cat(sprintf("  truth range: [%.3f, %.3f]; NA: %d\n",
            min(truth, na.rm = TRUE), max(truth, na.rm = TRUE), sum(is.na(truth))))
cat("Done. Now: Rscript slurm/profile_timing.R  then  bash slurm/submit.sh\n")
