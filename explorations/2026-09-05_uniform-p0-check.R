#!/usr/bin/env Rscript
# ============================================================================
# Clean, cheap prediction check before consulting Oracle on the analytic
# mechanism: if the intermediate-regime deviation from Corr_K is driven by
# NON-uniformity of p0 (small cells hit their nonnegativity floor V_k>=-p0(k)
# before large cells do, breaking the permutation symmetry that pins
# Sigma = a(lambda)*(I-11^T/K) in the interior regime), then for a perfectly
# UNIFORM p0 every cell hits its floor at the SAME lambda simultaneously, so
# full permutation symmetry of the feasible region survives for every lambda,
# not just lambda <= min_k p0(k). Prediction: Theta(lambda) = Corr_K for
# EVERY lambda when p0 is uniform, not just in the interior/saturated regimes.
#
# Cheap, sequential, single process; each draw matrix discarded after use.
# ============================================================================

suppressMessages(devtools::load_all(".", quiet = TRUE))

M_RUN <- 15000L
BURN_IN <- 1500L
THIN <- 15L
CRN_SEED <- 20260905L

theta_at <- function(p0, lambda, tauS, tauY, seed = CRN_SEED) {
  set.seed(seed)
  Q <- sample_tv_ball(p0, lambda = lambda, M = M_RUN, burn_in = BURN_IN,
                       thin = THIN, verbose = FALSE)
  Sigma <- stats::cov(Q)
  theta <- as.numeric((tauS %*% Sigma %*% tauY) /
    sqrt((tauS %*% Sigma %*% tauS) * (tauY %*% Sigma %*% tauY)))
  rm(Q, Sigma); gc(verbose = FALSE, full = FALSE)
  theta
}

K <- 5
p0_unif <- rep(1 / K, K)
tauS_u <- c(1, -1, 0, 0.5, 1)   # same heterogeneous tau's as Design C, just p0 uniform now
tauY_u <- c(-1, 1, 0, 0.5, 1)
CorrK_u <- cor(tauS_u, tauY_u)

grid <- c(0.05, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.75)  # up to near saturation (1-1/5=0.8)
cat(sprintf("Uniform p0 = 1/%d each. Corr_K = %.4f. Prediction: Theta(lambda) = %.4f for ALL lambda.\n\n",
            K, CorrK_u, CorrK_u))

theta_vals <- vapply(grid, function(lam) theta_at(p0_unif, lam, tauS_u, tauY_u), numeric(1))
for (i in seq_along(grid)) {
  cat(sprintf("  lambda=%.2f  Theta=%.4f  (Theta-CorrK=%+.4f)\n",
              grid[i], theta_vals[i], theta_vals[i] - CorrK_u))
}
cat(sprintf("\nmax|Theta-CorrK| over grid = %.4f\n", max(abs(theta_vals - CorrK_u))))
