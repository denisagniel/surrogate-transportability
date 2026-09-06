#!/usr/bin/env Rscript
# ============================================================================
# Quick check before formalizing a "sensitivity value" lambda*(c):
# is Theta(P0, lambda) monotone in lambda, or does it have interior structure
# (e.g. a hump, as informally suggested by DGP1's Theta(0.3)=0.69 > Corr_K=0.6455
# > Theta at both regime endpoints)?
#
# For each of the 4 canonical DGPs, sweep lambda over a grid from just above 0
# to just below the saturation threshold (1 - min_k p0(k)) and compute
# Theta_hat(lambda) via a long hit-and-run run at each grid point (same method
# as explorations/2026-09-04_sigma-decomposition-gap-check.R, just repeated
# over a lambda grid instead of one lambda).
#
# Throwaway proof-checking scaffolding. Run time: ~2 min (4 DGPs x 15 lambda
# points x M=8000 draws each -- lighter than the M=30000 precision runs since
# we only need qualitative shape here, not 4-decimal precision).
# ============================================================================

suppressMessages(devtools::load_all(".", quiet = TRUE))
set.seed(20260904)

cate_fns <- function(pr, X_levels) {
  tauS <- pr$gamma_A + pr$gamma_AX * X_levels
  tauY <- (pr$beta_A + pr$beta_AX * X_levels) + (pr$beta_S + pr$beta_SX * X_levels) * tauS
  list(tauS = tauS, tauY = tauY)
}

theta_at <- function(p0, lambda, tauS, tauY, M = 8000L) {
  Q <- sample_tv_ball(p0, lambda = lambda, M = M, burn_in = 1500, thin = 15, verbose = FALSE)
  Sigma <- stats::cov(Q)
  as.numeric((tauS %*% Sigma %*% tauY) /
    sqrt((tauS %*% Sigma %*% tauS) * (tauY %*% Sigma %*% tauY)))
}

dgp_ids <- c("dgp1", "dgp2", "dgp4", "dgp5")
results <- list()

for (id in dgp_ids) {
  spec <- canonical_dgp_params(id)
  p0 <- spec$p_X
  X_levels <- spec$X_levels
  cates <- cate_fns(spec$params, X_levels)
  Corr_K <- cor(cates$tauS, cates$tauY)
  m <- min(p0)                       # interior threshold
  Mmax <- 1 - m                      # saturation threshold

  # Grid: a few points inside (0, m] (should all equal Corr_K exactly, sanity
  # check), then a dense sweep across the intermediate band (m, Mmax), then a
  # couple of points inside [Mmax, 1) (should also equal Corr_K).
  grid <- sort(unique(c(
    seq(m * 0.3, m, length.out = 3),
    seq(m + 1e-3, Mmax - 1e-3, length.out = 12),
    seq(Mmax, min(0.999, Mmax + 2 * m), length.out = 3)
  )))
  grid <- grid[grid > 0 & grid < 1]

  theta_vals <- vapply(grid, function(lam) theta_at(p0, lam, cates$tauS, cates$tauY), numeric(1))
  results[[id]] <- data.frame(dgp = id, lambda = grid, theta = theta_vals)

  cat(sprintf("\n=== %s ===  Corr_K = %.4f, min_k p0 = %.3f, saturation at %.3f\n",
              id, Corr_K, m, Mmax))
  cat(sprintf("%-8s %-8s %-8s\n", "lambda", "Theta", "Theta-CorrK"))
  for (i in seq_along(grid)) {
    tag <- if (grid[i] <= m) "(interior)" else if (grid[i] >= Mmax) "(saturated)" else ""
    cat(sprintf("%-8.3f %-8.4f %+-8.4f %s\n", grid[i], theta_vals[i], theta_vals[i] - Corr_K, tag))
  }

  # Monotonicity check on the intermediate band only.
  mid <- theta_vals[grid > m & grid < Mmax]
  diffs <- diff(mid)
  n_up <- sum(diffs > 1e-3)
  n_down <- sum(diffs < -1e-3)
  cat(sprintf("Intermediate band: %d increases, %d decreases (of %d steps) -> %s\n",
              n_up, n_down, length(diffs),
              if (n_up > 0 && n_down > 0) "NON-MONOTONE" else "monotone (this run)"))
}

cat("\n=== Summary across all 4 DGPs ===\n")
for (id in dgp_ids) {
  r <- results[[id]]
  peak_idx <- which.max(abs(r$theta - r$theta[1]))
  cat(sprintf("%s: Theta ranges [%.4f, %.4f] over the swept grid (endpoints ~%.4f)\n",
              id, min(r$theta), max(r$theta), r$theta[1]))
}
