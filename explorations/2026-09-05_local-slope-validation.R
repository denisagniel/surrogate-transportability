#!/usr/bin/env Rscript
# ============================================================================
# Decisive validation of the analytic first-order slope formula, per Oracle's
# action plan: test right AT the boundary (m, 1.3m), not 2-8x past it (every
# earlier check was outside the first-order validity window). Also adds a
# design with a UNIQUE minimizer and a larger m, since DGP1's minimizer is
# tied (cells 1 and 5, by its reflection symmetry) -- the worst case for a
# unique-minimizer formula.
#
# Analytic prediction (from the Oracle-derived Proposition):
#   Psi(k) = ((1+r)/4)*(zS(k)-zY(k))^2 - ((1-r)/4)*(zS(k)+zY(k))^2
#   where r = Corr_K(tauS,tauY), z_a(k) = (tau_a(k)-mean(tau_a))/||tau_a-mean(tau_a)||_2.
#   Predicted sign of d(Theta)/d(lambda) at lambda=m+ is sign(sum_{k in argmin} Psi(k)).
#   The exact interior-regime value Theta(m-) = Corr_K is known analytically
#   (no MCMC noise), so slope is estimated as (Theta_hat(lambda) - Corr_K) /
#   (lambda - m) for lambda just above m -- removing one of the two noise
#   sources entirely.
#
# Memory discipline unchanged: single sequential process, each M x K draw
# matrix discarded (rm + gc) immediately after its Sigma is computed.
# Higher M this time (80000, vs 15000 before) to resolve a much smaller
# window; still trivial memory for K=5 (a few MB per matrix, never retained).
# ============================================================================

suppressMessages(devtools::load_all(".", quiet = TRUE))

M_RUN <- 80000L
BURN_IN <- 2000L
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

psi_k <- function(tauS, tauY) {
  r <- cor(tauS, tauY)
  zS <- (tauS - mean(tauS)) / sqrt(sum((tauS - mean(tauS))^2))
  zY <- (tauY - mean(tauY)) / sqrt(sum((tauY - mean(tauY))^2))
  ((1 + r) / 4) * (zS - zY)^2 - ((1 - r) / 4) * (zS + zY)^2
}

run_design <- function(label, p0, tauS, tauY, window_mult = 1.3, n_grid = 5) {
  m <- min(p0)
  kstar <- which(p0 == m)
  r <- cor(tauS, tauY)
  Psi <- psi_k(tauS, tauY)
  PsiSum <- sum(Psi[kstar])
  cat(sprintf("\n=== %s ===\n", label))
  cat(sprintf("p0 = [%s]  m = min_k p0 = %.3f at cell(s) {%s}%s\n",
              paste(sprintf("%.3f", p0), collapse = ", "), m,
              paste(kstar, collapse = ","),
              if (length(kstar) > 1) " (TIED minimizer)" else " (unique minimizer)"))
  cat(sprintf("Corr_K = %.4f | Psi(k) = [%s] | sum_{k in argmin} Psi(k) = %+.5f -> predicted sign: %s\n",
              r, paste(sprintf("%+.4f", Psi), collapse = ", "), PsiSum,
              if (PsiSum > 0) "POSITIVE slope" else if (PsiSum < 0) "NEGATIVE slope" else "ZERO slope"))

  # Anchor point strictly inside the interior regime (sanity: should equal
  # Corr_K exactly up to MC noise) and a fine grid from just above m to 1.3*m.
  grid <- sort(unique(c(m * 0.9, seq(m * 1.01, m * window_mult, length.out = n_grid))))
  theta_vals <- vapply(grid, function(lam) theta_at(p0, lam, tauS, tauY), numeric(1))

  for (i in seq_along(grid)) {
    tag <- if (grid[i] < m) "(interior anchor)" else ""
    slope <- if (grid[i] >= m) (theta_vals[i] - r) / (grid[i] - m) else NA
    cat(sprintf("  lambda=%.4f  Theta_hat=%.4f  Theta-CorrK=%+.4f  empirical_slope=%+.3f %s\n",
                grid[i], theta_vals[i], theta_vals[i] - r, slope, tag))
  }
  post_m <- grid >= m & grid > m * 1.001
  mean_slope <- mean((theta_vals[post_m] - r) / (grid[post_m] - m))
  cat(sprintf("Mean empirical slope over (m, %.2fm] = %+.3f | sign match with prediction: %s\n",
              window_mult, mean_slope,
              if (sign(mean_slope) == sign(PsiSum) || PsiSum == 0) "YES" else "NO"))
  invisible(list(label = label, PsiSum = PsiSum, m = m, mean_slope = mean_slope))
}

results <- list()

# Design A: unique minimizer (cell 5, m=0.04)
results$A <- run_design("Design A (large agree / small disagree)",
                         c(0.45, 0.35, 0.10, 0.06, 0.04),
                         c(0, 0.5, 1, 1.5, 2), c(0, 0.5, 1, -1.5, -3))

# Design C: unique minimizer (cell 5, m=0.05)
results$C <- run_design("Design C (large disagree / small agree)",
                         c(0.44, 0.35, 0.10, 0.06, 0.05),
                         c(1, -1, 0, 0.5, 1), c(-1, 1, 0, 0.5, 1))

# DGP1: TIED minimizer (cells 1 and 5, m=0.05) -- the ambiguous case
spec <- canonical_dgp_params("dgp1")
pr <- spec$params
tauS_1 <- pr$gamma_A + pr$gamma_AX * spec$X_levels
tauY_1 <- (pr$beta_A + pr$beta_AX * spec$X_levels) + (pr$beta_S + pr$beta_SX * spec$X_levels) * tauS_1
results$dgp1 <- run_design("DGP1 (tied minimizer, canonical validated example)",
                            spec$p_X, tauS_1, tauY_1)

# New design: UNIQUE minimizer, larger m=0.10, same tau's as DGP1 (isolates
# the effect of p0's shape alone, holding the CATE pattern fixed).
results$D <- run_design("Design D (DGP1's tau's, unique min, larger m=0.10)",
                         c(0.30, 0.25, 0.20, 0.15, 0.10), tauS_1, tauY_1)

cat("\n=== Calibration: does a single positive C_K/m-independent constant fit? ===\n")
cat(sprintf("%-45s %10s %10s %10s\n", "design", "PsiSum", "m", "PsiSum/m"))
for (r in results) cat(sprintf("%-45s %10.4f %10.3f %10.3f\n", r$label, r$PsiSum, r$m, r$PsiSum / r$m))
x <- vapply(results, function(r) r$PsiSum / r$m, numeric(1))
y <- vapply(results, function(r) r$mean_slope, numeric(1))
fit <- lm(y ~ x)
cat(sprintf("\nRegression slope ~ PsiSum/m (no intercept forced): intercept=%.3f, C_K_hat=%.3f, R^2=%.3f\n",
            coef(fit)[1], coef(fit)[2], summary(fit)$r.squared))
