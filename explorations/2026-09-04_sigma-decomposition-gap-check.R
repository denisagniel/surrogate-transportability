#!/usr/bin/env Rscript
# ============================================================================
# Follow-up to explorations/2026-09-04_interior-regime-numerics.R.
#
# Open thread from session_notes/2026-09-04.md ("Open thread, not yet
# started"): eq. (10)/(11) (Corr_K(tau_S,tau_Y) and its EIF) are defined for
# any K-cell discretization regardless of lambda/p0/regime. The paper's own
# Example (ex:binding) shows Corr_K UNDER-approximates the true Theta(P0,
# lambda) at DGP1's validated lambda=0.3 (Corr_K=0.6455 vs Theta=0.6907, a
# ~7% relative gap). This script checks whether that gap is explained by the
# anisotropic remainder of the sampled reweighting-covariance kernel Sigma:
#
#   Sigma = a_bar * P_perp + Sigma_0,   P_perp = I_K - (1/K) 11^T,
#
# where a_bar is Sigma's Frobenius projection onto P_perp (the exact form
# Sigma takes in the interior AND saturated regimes, theory.tex Prop 3.2/3.4)
# and Sigma_0 is the leftover anisotropic part that is exactly zero at both
# of those extremes. Theta(Sigma) = tauS' Sigma tauY / sqrt(tauS'Sigma tauS *
# tauY'Sigma tauY) is homogeneous of degree 0 in Sigma, so Theta(a_bar*P_perp)
# = Corr_K exactly (independent of a_bar) and the only source of the gap is
# Sigma_0. We check a first-order (linear-in-Sigma_0) Taylor expansion of
# Theta around Sigma_0=0 against the exact numerical value, and separately
# check whether the scalar ||Sigma_0||_op / a_bar tracks the gap's rough
# magnitude (a bound, not an exact predictor -- see writeup below).
#
# Throwaway proof-checking scaffolding: NOT part of the paper's reproducible
# artifact set. Does not touch R/ or simulations/. Run time: ~15s at
# M = 30000 (matches the M_ref used for DGP1/DGP2's rho_true recomputation
# per R/dgp_canonical.R's 2026-08-21 correction note).
# ============================================================================

suppressMessages(devtools::load_all(".", quiet = TRUE))

set.seed(20260904)

# ---------------------------------------------------------------------------
# DGP1's analytic CATEs (closed form, not simulated -- no S/Y data needed).
# From R/dgp_canonical.R's linear DGP:
#   tau_S(x) = gamma_A + gamma_AX * x
#   tau_Y(x) = (beta_A + beta_AX * x) + (beta_S + beta_SX * x) * tau_S(x)
# (S(1)-S(0) is deterministic given X since eps_S is common to both potential
# outcomes in this DGP; Y(1)-Y(0) then follows by substitution.)
# ---------------------------------------------------------------------------
spec <- canonical_dgp_params("dgp1")
p0 <- spec$p_X
X_levels <- spec$X_levels
lambda <- spec$lambda
K <- length(p0)
pr <- spec$params

tauS <- pr$gamma_A + pr$gamma_AX * X_levels
tauY <- (pr$beta_A + pr$beta_AX * X_levels) + (pr$beta_S + pr$beta_SX * X_levels) * tauS

cat(sprintf("DGP1: K=%d, lambda=%.2f, min_k p0=%.2f\n", K, lambda, min(p0)))
cat(sprintf("tau_S = [%s]\n", paste(sprintf("%.3f", tauS), collapse = ", ")))
cat(sprintf("tau_Y = [%s]\n\n", paste(sprintf("%.3f", tauY), collapse = ", ")))

Corr_K <- cor(tauS, tauY)
cat(sprintf("Corr_K(tauS, tauY)      = %.4f  (paper's ex:binding: 0.6455)\n", Corr_K))
w_cov <- function(a, b, w) sum(w * (a - sum(w * a)) * (b - sum(w * b)))
Corr_p0 <- w_cov(tauS, tauY, p0) / sqrt(w_cov(tauS, tauS, p0) * w_cov(tauY, tauY, p0))
cat(sprintf("Corr_p0-weighted         = %.4f  (paper's ex:binding: 0.6411)\n\n", Corr_p0))

# ---------------------------------------------------------------------------
# Sigma_hat from a long hit-and-run run (M_ref = 30000, thin = 20, matching
# R/dgp_canonical.R's documented recomputation precision of ~0.001).
# ---------------------------------------------------------------------------
M_ref <- 30000L
Q <- sample_tv_ball(p0, lambda = lambda, M = M_ref, burn_in = 2000, thin = 20, verbose = FALSE)
stopifnot(nrow(Q) == M_ref, all(abs(rowSums(Q) - 1) < 1e-6))

Sigma_hat <- stats::cov(Q)  # K x K sample covariance of the M draws (mu-covariance of Q)

Theta_hat <- as.numeric((tauS %*% Sigma_hat %*% tauY) /
  sqrt((tauS %*% Sigma_hat %*% tauS) * (tauY %*% Sigma_hat %*% tauY)))
cat(sprintf("Theta_hat (true, from Sigma_hat) = %.4f  (stored rho_true: %.4f)\n\n",
            Theta_hat, spec$rho_true))

# ---------------------------------------------------------------------------
# Decomposition Sigma_hat = a_bar * P_perp + Sigma_0.
# a_bar is the Frobenius projection of Sigma_hat onto P_perp: since P_perp is
# symmetric idempotent (P_perp^2 = P_perp, tr(P_perp) = K-1),
#   a_bar = <Sigma_hat, P_perp>_F / <P_perp, P_perp>_F = tr(Sigma_hat %*% P_perp) / (K-1).
# ---------------------------------------------------------------------------
P_perp <- diag(K) - matrix(1, K, K) / K
a_bar <- sum(diag(Sigma_hat %*% P_perp)) / (K - 1)
Sigma_0 <- Sigma_hat - a_bar * P_perp

op_norm <- function(M) max(abs(eigen(M, symmetric = TRUE, only.values = TRUE)$values))
fro_norm <- function(M) sqrt(sum(M^2))

cat(sprintf("a_bar                    = %.6f\n", a_bar))
cat(sprintf("||Sigma_0||_op           = %.6f\n", op_norm(Sigma_0)))
cat(sprintf("||Sigma_0||_F            = %.6f\n", fro_norm(Sigma_0)))
cat(sprintf("||Sigma_0||_op / a_bar   = %.4f\n", op_norm(Sigma_0) / a_bar))
cat(sprintf("||Sigma_0||_F  / a_bar   = %.4f\n\n", fro_norm(Sigma_0) / a_bar))

# ---------------------------------------------------------------------------
# Exact relative gap and its first-order (linear-in-Sigma_0) approximation.
# g(t) = Theta(a_bar*P_perp + t*Sigma_0); g(0) = Corr_K exactly (a_bar
# cancels); g(1) = Theta_hat exactly. Compare g(1) to the tangent-line
# prediction g(0) + g'(0), where
#   g'(0) = B_N/sqrt(A_S*A_Y) - (Corr_K/2)*(B_S/A_S + B_Y/A_Y),
#   A_N = a_bar * tauS'P_perp tauY,  B_N = tauS' Sigma_0 tauY   (and _S/_Y analogues)
# ---------------------------------------------------------------------------
A_N <- as.numeric(a_bar * (tauS %*% P_perp %*% tauY))
A_S <- as.numeric(a_bar * (tauS %*% P_perp %*% tauS))
A_Y <- as.numeric(a_bar * (tauY %*% P_perp %*% tauY))
stopifnot(abs(A_N / sqrt(A_S * A_Y) - Corr_K) < 1e-10)  # sanity: g(0) = Corr_K exactly

B_N <- as.numeric(tauS %*% Sigma_0 %*% tauY)
B_S <- as.numeric(tauS %*% Sigma_0 %*% tauS)
B_Y <- as.numeric(tauY %*% Sigma_0 %*% tauY)

g_prime_0 <- B_N / sqrt(A_S * A_Y) - (Corr_K / 2) * (B_S / A_S + B_Y / A_Y)
Theta_linear_approx <- Corr_K + g_prime_0

exact_gap <- Theta_hat - Corr_K
exact_rel_gap <- exact_gap / Corr_K
linear_gap <- g_prime_0
linear_rel_gap <- g_prime_0 / Corr_K

cat("--- First-order (linear-in-Sigma_0) approximation check ---\n")
cat(sprintf("Exact gap   Theta_hat - Corr_K       = %+.4f  (%.1f%% relative)\n",
            exact_gap, 100 * exact_rel_gap))
cat(sprintf("Linear-order prediction g'(0)         = %+.4f  (%.1f%% relative)\n",
            linear_gap, 100 * linear_rel_gap))
cat(sprintf("Linear approx of Theta (Corr_K+g'(0)) = %.4f  vs exact Theta_hat = %.4f\n",
            Theta_linear_approx, Theta_hat))
cat(sprintf("Residual (2nd-order+) = exact - linear = %+.4f (%.1f%% of the exact gap)\n\n",
            exact_gap - linear_gap, 100 * (exact_gap - linear_gap) / exact_gap))

# ---------------------------------------------------------------------------
# Does the single scalar ||Sigma_0||_op / a_bar track the gap's magnitude?
# Cauchy-Schwarz bound: |B_N| <= ||Sigma_0||_op * ||tauS|| * ||tauY||, and
# likewise for B_S, B_Y -- so |g'(0)| is bounded by ||Sigma_0||_op / a_bar
# times a factor depending on tauS, tauY's angle/norms through P_perp, not by
# ||Sigma_0||_op / a_bar alone. Report both the raw ratio and the actual
# Cauchy-Schwarz-implied bound on |g'(0)| for comparison.
# ---------------------------------------------------------------------------
cs_bound_N <- op_norm(Sigma_0) * sqrt(sum(tauS^2)) * sqrt(sum(tauY^2))
cs_bound_S <- op_norm(Sigma_0) * sum(tauS^2)
cs_bound_Y <- op_norm(Sigma_0) * sum(tauY^2)
cs_bound_gprime <- cs_bound_N / sqrt(A_S * A_Y) + (abs(Corr_K) / 2) * (cs_bound_S / A_S + cs_bound_Y / A_Y)

cat("--- Does ||Sigma_0||_op/a_bar alone predict the gap? ---\n")
cat(sprintf("||Sigma_0||_op / a_bar                    = %.4f\n", op_norm(Sigma_0) / a_bar))
cat(sprintf("Observed |relative gap|                   = %.4f\n", abs(exact_rel_gap)))
cat(sprintf("Cauchy-Schwarz bound on |g'(0)| (unscaled) = %.4f\n", cs_bound_gprime))
cat(sprintf("Actual |g'(0)|                             = %.4f  (bound is %.1fx looser)\n\n",
            abs(g_prime_0), cs_bound_gprime / abs(g_prime_0)))

cat("=== Summary ===\n")
cat(sprintf(
  "%s: the linear-in-Sigma_0 term explains %.0f%% of the exact gap (residual %.1f%% of gap).\n",
  if (abs((exact_gap - linear_gap) / exact_gap) < 0.25) "PASS" else "PARTIAL",
  100 * linear_gap / exact_gap, 100 * (exact_gap - linear_gap) / exact_gap
))
cat(sprintf(
  "%s: ||Sigma_0||_op/a_bar (%.3f) is NOT a tight predictor of the %.1f%% relative gap on its own\n",
  "NOTE", op_norm(Sigma_0) / a_bar, 100 * abs(exact_rel_gap)
))
cat("     -- it enters only through a Cauchy-Schwarz bound that is loose here\n")
cat("     (direction-dependent: also needs tauS, tauY's alignment with Sigma_0's eigenvectors).\n")
cat("     The exact, sharp first-order object is g'(0) itself (a specific bilinear\n")
cat("     form of Sigma_0 against tauS, tauY), not a scalar norm ratio.\n")
