#!/usr/bin/env Rscript
# =============================================================================
# prep_seeds.R -- STEP 1 of offline prep: rho-balanced ensemble seeds
# =============================================================================
# Scans candidate seeds and keeps a rho-BALANCED subset (flat across [-1,1]) so
# the ensemble stresses the estimator instead of piling up at |rho|~1. Writes:
#   config/ensemble_seeds.rds  -- the chosen seeds (defines the ensemble block)
#   config/prep_ntasks.txt     -- nrow(GRID) once seeds are fixed (array sizing)
# Sequential (bin-fill is inherently ordered) but cheap (~2 s/seed at M_ref=4000).
# =============================================================================

suppressPackageStartupMessages(library(optparse))
opt <- parse_args(OptionParser(option_list = list(
  make_option("--study-dir", type = "character", dest = "study_dir", default = "."),
  make_option("--scan",      type = "character", dest = "scan", default = "8000:8800"),
  make_option("--per-bin",   type = "integer",   dest = "per_bin", default = 7L)
)))

suppressWarnings(suppressPackageStartupMessages({
  library(surrogateTransportability); library(mgcv); library(ranger)
}))
sd <- opt$study_dir
source(file.path(sd, "R", "random_dgp.R"))
source(file.path(sd, "R", "true_rho.R"))

b <- as.integer(strsplit(opt$scan, ":", fixed = TRUE)[[1]])
cat(sprintf("Scanning seeds %d:%d for a rho-balanced ensemble (per_bin=%d)...\n",
            b[1], b[2], opt$per_bin))
seeds <- build_balanced_seeds(scan_seeds = b[1]:b[2], lambda = 0.3,
                              per_bin = opt$per_bin, M_ref = 4000L, thin = 12L)
cat(sprintf("Selected %d seeds; bin counts: %s\n",
            length(seeds), paste(attr(seeds, "bin_counts"), collapse = " ")))
saveRDS(seeds, file.path(sd, "config", "ensemble_seeds.rds"))

# Now GRID uses the real seeds; record its size for array sizing.
source(file.path(sd, "config", "grid.R"))
writeLines(as.character(nrow(GRID)), file.path(sd, "config", "prep_ntasks.txt"))
cat(sprintf("GRID has %d configs -> config/prep_ntasks.txt\n", nrow(GRID)))
