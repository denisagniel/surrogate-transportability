#!/usr/bin/env Rscript
# ============================================================================
# Follow-up to explorations/2026-09-04_theta-lambda-shape-check.R, per Oracle's
# action plan for the lambda*(c)/sensitivity-value question:
#   (1) Re-run DGP1's lambda-sweep with more precision AND common random
#       numbers (CRN) across lambda (same seed re-set before each
#       sample_tv_ball() call, varying only lambda), with grid points placed
#       at the DGP's actual kinks {p0(k)} rather than a uniform grid.
#   (2) Test generality: try DGPs deliberately designed so tau_S, tau_Y agree
#       on the LARGE cells and disagree on the SMALL cells -- the case Oracle
#       flagged as most likely to produce a DOWNWARD hump (Theta(lambda) <
#       Corr_K somewhere), which is the case that would make a lambda*(c)
#       sensitivity value non-degenerate.
#
# Memory discipline (explicit ask): single sequential R process, no parallel
# workers; each M x K draw matrix is discarded (rm + gc) immediately after
# its Sigma is computed, so memory stays flat across the whole sweep rather
# than accumulating with the number of grid points/DGPs.
#
# Throwaway proof-checking scaffolding. Run time: ~5-6 min sequential.
# ============================================================================

suppressMessages(devtools::load_all(".", quiet = TRUE))

M_RUN <- 15000L
BURN_IN <- 1500L
THIN <- 15L
CRN_SEED <- 20260905L  # same seed re-set before every sample_tv_ball() call
                        # within one DGP's sweep -- isolates the effect of
                        # lambda (which changes the feasible region) from the
                        # effect of which random draws happened to occur.

theta_at <- function(p0, lambda, tauS, tauY, seed = CRN_SEED) {
  set.seed(seed)
  Q <- sample_tv_ball(p0, lambda = lambda, M = M_RUN, burn_in = BURN_IN,
                       thin = THIN, verbose = FALSE)
  Sigma <- stats::cov(Q)
  theta <- as.numeric((tauS %*% Sigma %*% tauY) /
    sqrt((tauS %*% Sigma %*% tauS) * (tauY %*% Sigma %*% tauY)))
  rm(Q, Sigma)
  gc(verbose = FALSE, full = FALSE)  # keep memory flat across the sweep
  theta
}

sweep_and_report <- function(label, p0, tauS, tauY, grid) {
  K <- length(p0)
  CorrK <- cor(tauS, tauY)
  cat(sprintf("\n=== %s ===\n", label))
  cat(sprintf("p0   = [%s]\n", paste(sprintf("%.3f", p0), collapse = ", ")))
  cat(sprintf("tauS = [%s]\n", paste(sprintf("%.2f", tauS), collapse = ", ")))
  cat(sprintf("tauY = [%s]\n", paste(sprintf("%.2f", tauY), collapse = ", ")))
  cat(sprintf("Corr_K = %.4f | min_k p0 = %.3f | saturation at %.3f\n",
              CorrK, min(p0), 1 - min(p0)))

  theta_vals <- vapply(grid, function(lam) theta_at(p0, lam, tauS, tauY), numeric(1))
  below <- theta_vals < CorrK - 0.02  # meaningfully below baseline, past noise floor
  for (i in seq_along(grid)) {
    flag <- if (below[i]) " <-- BELOW baseline" else ""
    cat(sprintf("  lambda=%.4f  Theta=%.4f  (Theta-CorrK=%+.4f)%s\n",
                grid[i], theta_vals[i], theta_vals[i] - CorrK, flag))
  }
  Delta_star <- max(0, CorrK - min(theta_vals))
  cat(sprintf("Delta* (plug-in, this grid) = %.4f | sup|Theta-CorrK| = %.4f\n",
              Delta_star, max(abs(theta_vals - CorrK))))
  invisible(list(label = label, grid = grid, theta = theta_vals, CorrK = CorrK))
}

# ---------------------------------------------------------------------------
# (1) DGP1, refined: grid anchored at the actual kinks {0.05, 0.25, 0.40} plus
# a dense pass through the observed peak region and saturation at 0.95.
# ---------------------------------------------------------------------------
spec <- canonical_dgp_params("dgp1")
p0_1 <- spec$p_X
X_levels <- spec$X_levels
pr <- spec$params
tauS_1 <- pr$gamma_A + pr$gamma_AX * X_levels
tauY_1 <- (pr$beta_A + pr$beta_AX * X_levels) + (pr$beta_S + pr$beta_SX * X_levels) * tauS_1

grid_1 <- sort(unique(c(0.02, 0.049, 0.05, 0.051, 0.10, 0.15, 0.20, 0.249, 0.25, 0.251,
                        0.30, 0.35, 0.399, 0.40, 0.401, 0.55, 0.70, 0.85, 0.949, 0.95, 0.97)))
res_dgp1 <- sweep_and_report("DGP1 (refined, CRN)", p0_1, tauS_1, tauY_1, grid_1)

# ---------------------------------------------------------------------------
# (2) Designed adversarial cases: tau_S, tau_Y AGREE on large-mass cells,
# DISAGREE on small-mass cells. K=5, p0 heavily skewed toward cells 1-2.
# ---------------------------------------------------------------------------
p0_A <- c(0.45, 0.35, 0.10, 0.06, 0.04)
tauS_A <- c(1.0, 1.0, 1.0, -1.0, -1.0)
tauY_A <- c(1.0, 1.0, 1.0,  1.0,  1.0)  # agree on cells 1-3 (mass 0.90), disagree on 4-5
grid_A <- sort(unique(c(0.02, 0.039, 0.04, 0.041, 0.059, 0.06, 0.061, 0.10, 0.20,
                        0.30, 0.40, 0.50, 0.65, 0.80, 0.94, 0.96, 0.97)))
res_A <- sweep_and_report("Designed A: agree on 90% mass, oppose on 10%", p0_A, tauS_A, tauY_A, grid_A)

# A second design: same idea but disagreement is a MAGNITUDE mismatch, not a
# sign flip (agree in direction everywhere, but small cells have wildly
# different slopes) -- tests whether it's the sign-flip specifically that
# matters or any small-cell CATE heterogeneity.
p0_B <- c(0.45, 0.35, 0.10, 0.06, 0.04)
tauS_B <- c(1.0, 1.0, 1.0, 3.0, 5.0)
tauY_B <- c(1.0, 1.0, 1.0, 0.2, 0.1)
grid_B <- grid_A
res_B <- sweep_and_report("Designed B: agree on 90% mass, magnitude-mismatch on 10%", p0_B, tauS_B, tauY_B, grid_B)

cat("\n=== Summary ===\n")
for (r in list(res_dgp1, res_A, res_B)) {
  any_below <- any(r$theta < r$CorrK - 0.02)
  cat(sprintf("%-45s: %s (min Theta-CorrK = %+.4f)\n",
              r$label, if (any_below) "DOWNWARD DIP FOUND" else "no downward dip",
              min(r$theta) - r$CorrK))
}
