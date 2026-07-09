# =============================================================================
# 01_smoke_estimator.R -- verification 1-4 before scaling.
#  1. pseudo-outcome sanity: mean(xi_a) ~ ATE, E[xi_a|X] ~ tau_a(X)
#  2. IF mean-zero at oracle nuisances; mean(psi_hat) ~ psi_true at large n
#  3. debiasing load-bearing: debiased bias ~ 0 while plug-in bias is nonzero
#  4. sanity on the smooth (A_above) design where first-order should be fine
# =============================================================================
root <- "explorations/2026-07-09_a5-elbow-validation"
source(file.path(root, "config/grid.R"))
source(file.path(root, "R/dgp_smooth.R"))
source(file.path(root, "R/pseudo_outcome.R"))
source(file.path(root, "R/bilinear_estimator.R"))
set.seed(20260709)

cfgA <- STAGE1_DESIGN[STAGE1_DESIGN$design == "A_above", ]

# ---- 1. pseudo-outcome sanity (oracle mu from a very rich sieve) ------------
cat("=== 1. pseudo-outcome sanity (n=1e5, A_above) ===\n")
d1 <- generate_stage1(1e5, cfgA)
X <- as.matrix(d1[, "X1", drop = FALSE])
# fit a rich sieve on ALL data as an "oracle" mu (in-sample; just for the check)
nf <- nfeat_rule(nrow(d1), cfgA$s_S, 1)
fitS <- fit_outcome_sieve(X, d1$S, d1$A, nf, 1)
prS <- predict_outcome_sieve(fitS, X)
xiS <- aipw_pseudo(d1$A, d1$S, prS$mu1, prS$mu0)
tauS <- attr(d1, "tau_S")
cat(sprintf("  mean(xi_S)=%.4f   ATE=mean(tau_S)=%.4f\n", mean(xiS), mean(tauS)))
# E[xi_S | X] ~ tau_S: bin by X and compare
bins <- cut(X[, 1], breaks = seq(0, 1, by = 0.1))
agg <- tapply(xiS, bins, mean); tru <- tapply(tauS, bins, mean)
cat(sprintf("  max |E[xi_S|bin] - tau_S(bin)| = %.4f  (should be small)\n",
            max(abs(agg - tru))))

# ---- 2. IF mean-zero + estimator ~ truth at large n ------------------------
cat("\n=== 2. estimator vs truth (n=2e4, A_above, pair SY) ===\n")
d2 <- generate_stage1(2e4, cfgA)
r2 <- psi_hat_dirac(d2, "SY", cfgA$s_S, cfgA$s_Y, 1)
tru_SY <- attr(d2, "psi_SY")
cat(sprintf("  psi_true=%.4f  debiased=%.4f (se %.4f)  plugin=%.4f\n",
            tru_SY, r2$psi_debiased, r2$se_debiased, r2$psi_plugin))

# ---- 3. debiasing load-bearing over reps -----------------------------------
cat("\n=== 3. debiasing load-bearing (A_above SY, n=2000, 100 reps) ===\n")
R <- 100
deb <- plug <- numeric(R)
for (r in seq_len(R)) {
  dd <- generate_stage1(2000, cfgA)
  rr <- psi_hat_dirac(dd, "SY", cfgA$s_S, cfgA$s_Y, 1)
  deb[r] <- rr$psi_debiased; plug[r] <- rr$psi_plugin
}
truth <- psi_truth_config(cfgA)["SY"]
cat(sprintf("  truth=%.4f\n", truth))
cat(sprintf("  debiased: bias=%+.4f  sd=%.4f\n", mean(deb) - truth, sd(deb)))
cat(sprintf("  plugin:   bias=%+.4f  sd=%.4f\n", mean(plug) - truth, sd(plug)))
cat(sprintf("  => debiasing reduces |bias| by %.1fx\n",
            abs(mean(plug) - truth) / max(1e-8, abs(mean(deb) - truth))))
