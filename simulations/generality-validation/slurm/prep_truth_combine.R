#!/usr/bin/env Rscript
# =============================================================================
# prep_truth_combine.R -- assemble per-config truth files into truth_table.rds
# =============================================================================
# Reads config/truth/truth_<id>.rds for every GRID config, in config_id order,
# and writes config/truth_table.rds (the vector unit_table() consumes). Fails
# loudly if any config's truth is missing (Constitution §9, no silent partial).
# =============================================================================

suppressPackageStartupMessages(library(optparse))
opt <- parse_args(OptionParser(option_list = list(
  make_option("--study-dir", type = "character", dest = "study_dir", default = ".")
)))

suppressWarnings(suppressPackageStartupMessages({
  library(surrogateTransportability); library(mgcv); library(ranger)
}))
sd <- opt$study_dir
source(file.path(sd, "R", "random_dgp.R"))
source(file.path(sd, "R", "true_rho.R"))
source(file.path(sd, "config", "grid.R"))

ids <- GRID$config_id
truth <- rep(NA_real_, length(ids))
missing <- integer(0)
for (i in seq_along(ids)) {
  f <- file.path(sd, "config", "truth", sprintf("truth_%03d.rds", ids[i]))
  if (file.exists(f)) truth[i] <- readRDS(f) else missing <- c(missing, ids[i])
}
if (length(missing) > 0) {
  stop(sprintf("Missing truth for %d configs: %s\nRe-run the truth array for these ids.",
               length(missing), paste(head(missing, 50), collapse = ", ")))
}

saveRDS(truth, file.path(sd, "config", "truth_table.rds"))
cat(sprintf("Wrote truth_table.rds (%d configs). rho range [%.3f, %.3f].\n",
            length(truth), min(truth), max(truth)))
cat("Next: Rscript slurm/profile_timing.R  then  bash slurm/submit.sh\n")
