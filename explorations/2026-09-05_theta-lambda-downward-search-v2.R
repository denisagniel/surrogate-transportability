#!/usr/bin/env Rscript
# ============================================================================
# Fixes explorations/2026-09-05_theta-lambda-downward-search.R's Designed A/B
# (tau_Y was constant there -> zero variance -> Corr_K undefined; a real bug,
# not a finding). DGP1's refined sweep already ran cleanly and is not
# re-run here (no need to re-spend that compute).
#
# Three corrected designs, all with genuine cell-to-cell variation in BOTH
# tau_S and tau_Y:
#   C: small cells agree, LARGE cells disagree (the mechanism argument
#      predicts this is the one likely to dip BELOW Corr_K: small/rare cells
#      hit their nonnegativity floor first as lambda grows, so their
#      [agreeing] variance contribution is suppressed early while the large,
#      disagreeing cells retain more freedom to move and dominate Sigma in
#      the intermediate regime).
#   A: large cells agree, small cells disagree (mirror of C; DGP1-like,
#      predicted to push Theta UP, same direction as DGP1).
#   B: same as A but a magnitude-mismatch rather than a sign flip on the
#      small cells (tests whether sign-flip specifically matters).
#
# Same memory discipline as the previous script: single sequential process,
# each M x K draw matrix discarded (rm + gc) right after use.
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
  rm(Q, Sigma)
  gc(verbose = FALSE, full = FALSE)
  theta
}

sweep_and_report <- function(label, p0, tauS, tauY, grid) {
  CorrK <- cor(tauS, tauY)
  cat(sprintf("\n=== %s ===\n", label))
  cat(sprintf("p0   = [%s]\n", paste(sprintf("%.3f", p0), collapse = ", ")))
  cat(sprintf("tauS = [%s]\n", paste(sprintf("%.2f", tauS), collapse = ", ")))
  cat(sprintf("tauY = [%s]\n", paste(sprintf("%.2f", tauY), collapse = ", ")))
  cat(sprintf("Corr_K = %.4f | min_k p0 = %.3f | saturation at %.3f\n",
              CorrK, min(p0), 1 - min(p0)))
  theta_vals <- vapply(grid, function(lam) theta_at(p0, lam, tauS, tauY), numeric(1))
  for (i in seq_along(grid)) {
    d <- theta_vals[i] - CorrK
    flag <- if (d < -0.02) " <-- BELOW baseline" else if (d > 0.02) " (above)" else ""
    cat(sprintf("  lambda=%.4f  Theta=%.4f  (Theta-CorrK=%+.4f)%s\n",
                grid[i], theta_vals[i], d, flag))
  }
  cat(sprintf("min(Theta-CorrK) = %+.4f | max(Theta-CorrK) = %+.4f\n",
              min(theta_vals - CorrK), max(theta_vals - CorrK)))
  invisible(list(label = label, theta = theta_vals, CorrK = CorrK))
}

# ---------------------------------------------------------------------------
# Design C: SMALL cells (3,4,5; combined mass 0.21) agree; LARGE cells (1,2;
# combined mass 0.79) disagree (opposite sign).
# ---------------------------------------------------------------------------
p0_C <- c(0.44, 0.35, 0.10, 0.06, 0.05)
tauS_C <- c(1, -1, 0, 0.5, 1)
tauY_C <- c(-1, 1, 0, 0.5, 1)
grid_C <- sort(unique(c(0.02, 0.049, 0.05, 0.051, 0.10, 0.20, 0.30, 0.40, 0.50,
                        0.65, 0.80, 0.94, 0.95, 0.96)))
res_C <- sweep_and_report("Design C: LARGE cells disagree, small cells agree", p0_C, tauS_C, tauY_C, grid_C)

# ---------------------------------------------------------------------------
# Design A (fixed): LARGE cells (1-3; mass 0.90) agree, SMALL cells (4,5;
# mass 0.10) disagree (opposite sign). Mirror of C.
# ---------------------------------------------------------------------------
p0_A <- c(0.45, 0.35, 0.10, 0.06, 0.04)
tauS_A <- c(0, 0.5, 1, 1.5, 2)
tauY_A <- c(0, 0.5, 1, -1.5, -3)
grid_A <- grid_C
res_A <- sweep_and_report("Design A: large cells agree, SMALL cells disagree (sign flip)", p0_A, tauS_A, tauY_A, grid_A)

cat("\n=== Summary ===\n")
for (r in list(res_C, res_A)) {
  cat(sprintf("%-55s: min(Theta-CorrK)=%+.4f  max(Theta-CorrK)=%+.4f  -> %s\n",
              r$label, min(r$theta - r$CorrK), max(r$theta - r$CorrK),
              if (min(r$theta - r$CorrK) < -0.02) "DOWNWARD DIP FOUND" else "no downward dip"))
}
