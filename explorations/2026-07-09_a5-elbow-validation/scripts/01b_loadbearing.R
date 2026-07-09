# Debiasing load-bearing check, done correctly: the plug-in bias for the DIAGONAL
# variance functional E[tau^2] is E[(tau_hat - tau)^2] > 0 (strictly positive;
# the disattenuation term). It should be large for rough designs and shrink
# faster than the debiased bias. Compare SS diagonal across designs.
root <- "explorations/2026-07-09_a5-elbow-validation"
source(file.path(root, "config/grid.R"))
source(file.path(root, "R/dgp_smooth.R"))
source(file.path(root, "R/pseudo_outcome.R"))
source(file.path(root, "R/bilinear_estimator.R"))
set.seed(20260709)

R <- 150; n <- 2000
for (dn in c("A_above", "G_gap", "B_below")) {
  cfg <- STAGE1_DESIGN[STAGE1_DESIGN$design == dn, ]
  truth <- psi_truth_config(cfg)["SS"]
  deb <- plug <- se <- numeric(R)
  for (r in seq_len(R)) {
    dd <- generate_stage1(n, cfg)
    rr <- psi_hat_dirac(dd, "SS", cfg$s_S, cfg$s_Y, cfg$d)
    deb[r] <- rr$psi_debiased; plug[r] <- rr$psi_plugin; se[r] <- rr$se_debiased
  }
  cover <- mean(truth >= deb - 1.96 * se & truth <= deb + 1.96 * se)
  cat(sprintf("%-9s (s=%.1f d=%d, SS) truth=%.3f | deb bias=%+.4f sd=%.4f | plug bias=%+.4f | cov=%.2f\n",
              dn, cfg$s_S, cfg$d, truth, mean(deb) - truth, sd(deb), mean(plug) - truth, cover))
}
