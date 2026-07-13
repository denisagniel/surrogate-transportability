#!/usr/bin/env Rscript
# =============================================================================
# prep_truth_one.R -- STEP 2 (array task): exact truth for ONE grid config
# =============================================================================
# One SLURM array task = one GRID config. Computes rho_true at high M_ref and
# writes config/truth/truth_<id>.rds (a single numeric). prep_truth_combine.R
# assembles these into config/truth_table.rds. Idempotent: skips if the per-id
# file already exists (cheap resume).
#
# Requires config/ensemble_seeds.rds (from prep_seeds.R) so GRID matches the
# eventual run's grid.
# =============================================================================

suppressPackageStartupMessages(library(optparse))
opt <- parse_args(OptionParser(option_list = list(
  make_option("--config-id", type = "integer",   dest = "config_id"),
  make_option("--study-dir", type = "character", dest = "study_dir", default = "."),
  make_option("--m-ref",     type = "integer",   dest = "m_ref", default = 100000L)
)))
stopifnot(!is.null(opt$config_id))

suppressWarnings(suppressPackageStartupMessages({
  library(surrogateTransportability); library(mgcv); library(ranger)
}))
sd <- opt$study_dir
source(file.path(sd, "R", "random_dgp.R"))
source(file.path(sd, "R", "true_rho.R"))
source(file.path(sd, "config", "grid.R"))

out_dir <- file.path(sd, "config", "truth")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(out_dir, sprintf("truth_%03d.rds", opt$config_id))
if (file.exists(out)) {
  cat(sprintf("[config %d] exists; skipping.\n", opt$config_id)); quit(save = "no", status = 0)
}

g <- GRID[GRID$config_id == opt$config_id, ]
if (nrow(g) != 1) stop(sprintf("config_id %d not in GRID (nrow=%d)", opt$config_id, nrow(g)))

if (g$dgp_kind == "canonical") {
  sp <- canonical_dgp_params(g$dgp)
  cc <- canonical_cates(sp$params, sp$X_levels)
  rho <- true_rho_from_cates(cc$tau_S, cc$tau_Y, sp$p_X, g$lambda,
                             M_ref = opt$m_ref, thin = 20L)$rho_true
} else {
  sp <- draw_random_dgp(rng_seed = g$dgp_seed, allow_observational = FALSE)
  rho <- true_rho_from_cates(sp$tau_S, sp$tau_Y, sp$p_X, g$lambda,
                             M_ref = opt$m_ref, thin = 20L)$rho_true
}

tmp <- paste0(out, ".tmp"); saveRDS(rho, tmp); invisible(file.rename(tmp, out))
cat(sprintf("[config %d] %s rho_true=%.4f -> %s\n",
            opt$config_id, g$dgp_kind, rho, basename(out)))
