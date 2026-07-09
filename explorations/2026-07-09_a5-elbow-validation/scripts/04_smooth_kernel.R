# =============================================================================
# 04_smooth_kernel.R -- smooth-kernel elbow relaxation (local, small R).
# =============================================================================
# Claim (Remark A5-conservative in the proof): a smooth bounded kernel C relaxes
# the Dirac elbow -- the representer h_b = int C(x,.) tau_b dP0 is SMOOTHER than
# tau_b, so the remainder int int C (tau_hat_a-tau_a)(tau_hat_b-tau_b) dP0^2 is
# controlled under WEAKER CATE smoothness. Demonstration: take a design that the
# Dirac functional handles poorly (rough CATEs, in/near the gap) and show the
# smooth-kernel functional's debiased estimator has better bias/coverage at the
# same n.
#
# Light + serial (single design, modest R, n<=8000) -- safe on a laptop.
# =============================================================================
root <- "explorations/2026-07-09_a5-elbow-validation"
source(file.path(root, "config/grid.R"))
source(file.path(root, "R/dgp_smooth.R"))
source(file.path(root, "R/pseudo_outcome.R"))
source(file.path(root, "R/bilinear_estimator.R"))
source(file.path(root, "R/kernel_smooth.R"))
set.seed(20260709)

R    <- as.integer(Sys.getenv("R_SMOOTH", "150"))
ELL  <- 0.25
# NOTE: the smooth-kernel estimator forms a dense n x n kernel matrix (O(n^2) time
# and memory). n=1000,2000 already show the relaxation clearly and run in minutes;
# n>=4000 is slow enough (dense matrix x 150 reps) that it belongs on the cluster.
NS   <- as.integer(strsplit(Sys.getenv("NS_SMOOTH", "1000,2000"), ",")[[1]])
# G_gap (s=0.4, sum=0.8) is in the gap for Dirac; B_below (s=0.2) is fully below.
DESIGNS <- c("G_gap", "B_below")

cat(sprintf("smooth-kernel relaxation: R=%d, ell=%.2f, pair=SY\n\n", R, ELL))
rows <- list(); ri <- 0
for (dn in DESIGNS) {
  cfg <- STAGE1_DESIGN[STAGE1_DESIGN$design == dn, ]
  truth_dirac  <- psi_truth_config(cfg)[["SY"]]
  truth_smooth <- psi_true_smooth(cfg, ell = ELL, ngrid = 2000, pair = "SY")
  for (n in NS) {
    dir_est <- dir_se <- sm_est <- sm_se <- numeric(R)
    for (r in seq_len(R)) {
      dd <- generate_stage1(n, cfg)
      rd <- psi_hat_dirac(dd, "SY", cfg$s_S, cfg$s_Y, 1)
      rs <- psi_hat_smooth(dd, "SY", cfg$s_S, cfg$s_Y, ell = ELL)
      dir_est[r] <- rd$psi_debiased; dir_se[r] <- rd$se_debiased
      sm_est[r]  <- rs$psi;          sm_se[r]  <- rs$se
    }
    covd <- mean(truth_dirac  >= dir_est - 1.96*dir_se & truth_dirac  <= dir_est + 1.96*dir_se)
    covs <- mean(truth_smooth >= sm_est  - 1.96*sm_se  & truth_smooth <= sm_est  + 1.96*sm_se)
    ri <- ri + 1
    rows[[ri]] <- data.frame(design=dn, s=cfg$s_S, n=n,
      dirac_bias = mean(dir_est)-truth_dirac, dirac_cov = covd,
      smooth_bias= mean(sm_est)-truth_smooth, smooth_cov= covs)
    cat(sprintf("  %-8s s=%.1f n=%5d | Dirac bias=%+.4f cov=%.2f | Smooth bias=%+.4f cov=%.2f\n",
                dn, cfg$s_S, n, mean(dir_est)-truth_dirac, covd, mean(sm_est)-truth_smooth, covs))
  }
}
res <- do.call(rbind, rows)
saveRDS(res, file.path(root, "output/smooth_kernel_check.rds"))
cat("\nsaved output/smooth_kernel_check.rds\n")
