#!/usr/bin/env Rscript
# ============================================================================
# Item 0 verification harness for
# quality_reports/plans/2026-09-04_interior-regime-and-general-X-theory.md
#
# Purpose: numerically verify the four structural claims underlying that
# plan (interior-regime closed form at both lambda extremes, Sigma structure,
# dyadic-sieve continuum limit + a genuinely different quantile-grid limit,
# and the boundary kink at lambda = min_k p0(k)) BEFORE any LaTeX is edited.
#
# This is throwaway proof-checking scaffolding, not a validation study:
# it is NOT part of the paper's reproducible artifact set and does not
# touch R/ or simulations/.
# ============================================================================

suppressMessages(devtools::load_all(".", quiet = TRUE))

set.seed(20260904)

pass <- TRUE
report <- function(label, ok, detail = "") {
  status <- if (ok) "PASS" else "FAIL"
  cat(sprintf("[%s] %s%s\n", status, label, if (nzchar(detail)) paste0(" -- ", detail) else ""))
  if (!ok) pass <<- FALSE
}

# ---------------------------------------------------------------------------
# Fixed DGP (shared across tasks 1, 2, 3, 5 -- plan Item 0, task 1)
# ---------------------------------------------------------------------------
K     <- 4
p0    <- c(0.4, 0.3, 0.2, 0.1)
tauS  <- c(1, 0.5, -0.5, -1)
tauY  <- c(1, -0.5, 0.5, -1)
CorrK <- cor(tauS, tauY)
stopifnot(abs(CorrK - 0.6) < 1e-12)          # 1.5/2.5 = 0.6 exactly
cat(sprintf("Corr_K(tauS, tauY) = %.10f (target 0.6)\n\n", CorrK))

M_draws <- 1e5
burn_in <- 1000

theta_hat <- function(lambda, M = M_draws) {
  Q <- sample_tv_ball(p0, lambda = lambda, M = M, burn_in = burn_in, thin = 1,
                       verbose = FALSE)
  DS <- as.numeric(Q %*% tauS)
  DY <- as.numeric(Q %*% tauY)
  list(theta = cor(DS, DY), Sigma = cov(Q), Q = Q, DS = DS, DY = DY)
}

# Monte Carlo SE of a Pearson correlation from n ~independent draws
# (classical asymptotic formula; adequate for this throwaway harness since
# thin = 1 and M = 1e5 for K = 4 gives ample effective sample size).
se_corr <- function(r, n) sqrt(pmax(1 - r^2, 0)^2 / (n - 1))

# ===========================================================================
# Task 2: flat-wander-flat curve at the two flat endpoints
#   lambda = 0.02 (< min_k p0 = 0.1)  and  lambda = 0.98 (> 1 - min_k p0 = 0.9)
# ===========================================================================
cat("== Task 2: flat endpoints ==\n")
fit_lo <- theta_hat(0.02)
fit_hi <- theta_hat(0.98)
se_lo  <- se_corr(fit_lo$theta, M_draws)
se_hi  <- se_corr(fit_hi$theta, M_draws)
report("theta(0.02) within 3*SE_MC of 0.6",
       abs(fit_lo$theta - CorrK) < 3 * se_lo,
       sprintf("theta_hat=%.5f, 3*SE=%.5f", fit_lo$theta, 3 * se_lo))
report("theta(0.98) within 3*SE_MC of 0.6",
       abs(fit_hi$theta - CorrK) < 3 * se_hi,
       sprintf("theta_hat=%.5f, 3*SE=%.5f", fit_hi$theta, 3 * se_hi))

# Task 2(b): pilot-and-reproduce at intermediate lambda = 0.25 (not a
# discovery test -- see plan Item 0, task 2 for the corrected framing).
cat("\n== Task 2(b): pilot-and-reproduce at lambda = 0.25 ==\n")
pilot   <- theta_hat(0.25)
rerun   <- theta_hat(0.25)
se_mid  <- se_corr(pilot$theta, M_draws)
report("theta(0.25) reproduces across independent draws (|diff| < 3*SE_MC)",
       abs(rerun$theta - pilot$theta) < 3 * se_mid,
       sprintf("pilot=%.5f, rerun=%.5f, 3*SE=%.5f", pilot$theta, rerun$theta, 3 * se_mid))
# Diagnostic only -- does NOT gate pass/fail (Item 3c is a possibility claim).
distinguishable <- abs(pilot$theta - CorrK) > 3 * se_mid
cat(sprintf("  [diagnostic, non-blocking] theta(0.25)=%.5f vs Corr_K=0.6, distinguishable=%s\n",
            pilot$theta, distinguishable))

# ===========================================================================
# Task 3: Sigma structure at the two flat endpoints
# ===========================================================================
cat("\n== Task 3: Sigma structure at flat endpoints ==\n")
check_sigma_structure <- function(Sigma, label) {
  diag_vals <- diag(Sigma)
  offdiag_vals <- Sigma[upper.tri(Sigma)]
  diag_spread    <- (max(diag_vals) - min(diag_vals)) / mean(diag_vals)
  offdiag_spread <- (max(offdiag_vals) - min(offdiag_vals)) / abs(mean(offdiag_vals))
  ok <- diag_spread < 0.10 && offdiag_spread < 0.10
  report(sprintf("Sigma diag/off-diag near-equal at %s", label), ok,
         sprintf("diag_spread=%.4f, offdiag_spread=%.4f", diag_spread, offdiag_spread))
}
check_sigma_structure(fit_lo$Sigma, "lambda=0.02")
check_sigma_structure(fit_hi$Sigma, "lambda=0.98")

# ===========================================================================
# Task 4: dyadic-sieve continuum limit vs. quantile-grid control
#   tauS(x) = x, tauY(x) = x^5 on X ~ Unif[0,1]
#   Both limits are purely analytic (deterministic conditional-mean
#   integrals over a *known* covariate law) -- no Monte Carlo needed.
# ===========================================================================
cat("\n== Task 4: dyadic sieve vs. quantile-grid control ==\n")

target_dyadic  <- sqrt(33) / 7      # Corr_{Unif[0,1]}(X, X^5), exact closed form
target_control <- sqrt(3)  / 2      # Corr_nu(X, X^5), nu has density 2x, exact closed form
cat(sprintf("target_dyadic (Corr_Unif[0,1])  = %.10f\n", target_dyadic))
cat(sprintf("target_control (Corr_nu, g=2x)  = %.10f\n", target_control))
cat(sprintf("|target_dyadic - target_control| = %.6f\n\n", abs(target_dyadic - target_control)))

# Coincidence note (Oracle round 6): Cov(X,X^5) = Cov_nu(X,X^5) = 5/84 exactly
# under BOTH measures. This is a genuine coincidence, not a bug -- the
# contrast between the two targets lives entirely in the variances.
cov_unif <- 1/7 - (1/2)*(1/6)
cov_nu   <- 1/4 - (2/3)*(2/7)
stopifnot(abs(cov_unif - 5/84) < 1e-12, abs(cov_nu - 5/84) < 1e-12)

# --- Dyadic sieve (equal P0-mass cells under Unif[0,1]) ---
theta_dyadic_m <- function(m) {
  K_m <- 2^m
  edges <- (0:K_m) / K_m
  # E[X | cell] = K_m * integral_{a}^{b} x dx = K_m * (b^2-a^2)/2
  tau_S_m <- K_m * (edges[-1]^2 - edges[-(K_m + 1)]^2) / 2
  # E[X^5 | cell] = K_m * (b^6-a^6)/6
  tau_Y_m <- K_m * (edges[-1]^6 - edges[-(K_m + 1)]^6) / 6
  cor(tau_S_m, tau_Y_m)
}

# --- Quantile-grid control: cells [sqrt(j/K), sqrt((j+1)/K)), conditional
#     means still taken under the TRUE covariate law P0 = Unif[0,1];
#     the cells themselves are unequal-P0-mass by construction. ---
theta_control_m <- function(m) {
  K_m <- 2^m
  u <- (0:K_m) / K_m
  edges <- sqrt(u)                      # G^{-1}(u) = sqrt(u), G(x) = x^2
  tau_S_m <- K_m_width_adjust(edges, power = 1)
  tau_Y_m <- K_m_width_adjust(edges, power = 5)
  cor(tau_S_m, tau_Y_m)
}
# E[X^p | cell=(a,b)] under Unif[0,1] = (b^{p+1}-a^{p+1}) / ((p+1)(b-a))
K_m_width_adjust <- function(edges, power) {
  a <- edges[-length(edges)]
  b <- edges[-1]
  (b^(power + 1) - a^(power + 1)) / ((power + 1) * (b - a))
}

m_grid <- 1:8
theta_dyadic  <- sapply(m_grid, theta_dyadic_m)
theta_control <- sapply(m_grid, theta_control_m)

for (i in seq_along(m_grid)) {
  cat(sprintf("  m=%d (K=%4d): theta_dyadic=%.6f  theta_control=%.6f\n",
              m_grid[i], 2^m_grid[i], theta_dyadic[i], theta_control[i]))
}

term_err_dyadic  <- abs(theta_dyadic[8]  - target_dyadic)
term_err_control <- abs(theta_control[8] - target_control)
pairwise_sep      <- abs(theta_dyadic[8] - theta_control[8])

report("dyadic sieve terminal error < 0.02", term_err_dyadic < 0.02,
       sprintf("theta_8=%.6f, target=%.6f, err=%.6f", theta_dyadic[8], target_dyadic, term_err_dyadic))
report("quantile-grid control terminal error < 0.02", term_err_control < 0.02,
       sprintf("theta_8=%.6f, target=%.6f, err=%.6f", theta_control[8], target_control, term_err_control))
report("belt-and-braces: |dyadic - control| > 0.025 (pairwise separation)",
       pairwise_sep > 0.025,
       sprintf("|diff|=%.6f", pairwise_sep))

# ===========================================================================
# Task 5: boundary kink at lambda = min_k p0(k) = 0.1
# ===========================================================================
cat("\n== Task 5: boundary kink at lambda = min_k p0(k) = 0.1 ==\n")

lambda_lo_grid <- seq(0.09, 0.10, length.out = 6)   # interior side
lambda_hi_grid <- seq(0.10, 0.11, length.out = 6)   # boundary-binding side

theta_at <- function(lambdas) sapply(lambdas, function(l) theta_hat(l, M = M_draws)$theta)

theta_lo <- theta_at(lambda_lo_grid)
theta_hi <- theta_at(lambda_hi_grid)

slope_with_se <- function(x, y) {
  fit <- lm(y ~ x)
  s <- coef(summary(fit))["x", ]
  c(slope = unname(s["Estimate"]), se = unname(s["Std. Error"]))
}

slope_lo <- slope_with_se(lambda_lo_grid, theta_lo)
slope_hi <- slope_with_se(lambda_hi_grid, theta_hi)

cat(sprintf("  interior-side slope: %.4f (SE %.4f) -> |slope|/SE = %.3f\n",
            slope_lo["slope"], slope_lo["se"], abs(slope_lo["slope"]) / slope_lo["se"]))
cat(sprintf("  boundary-side slope: %.4f (SE %.4f) -> |slope|/SE = %.3f\n",
            slope_hi["slope"], slope_hi["se"], abs(slope_hi["slope"]) / slope_hi["se"]))

report("interior-side slope statistically indistinguishable from 0 (< 2 SE)",
       abs(slope_lo["slope"]) < 2 * slope_lo["se"])
report("boundary-side slope statistically distinguishable from 0 (> 2 SE)",
       abs(slope_hi["slope"]) > 2 * slope_hi["se"])

# ===========================================================================
cat("\n============================================================\n")
cat(sprintf("OVERALL: %s\n", if (pass) "ALL CHECKS PASSED" else "SOME CHECKS FAILED"))
cat("============================================================\n")
if (!pass) quit(status = 1)
