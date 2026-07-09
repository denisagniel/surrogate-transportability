# =============================================================================
# pseudo_outcome.R -- cosine-series sieve nuisances + AIPW CATE pseudo-outcome.
# =============================================================================
# The CATE learner is a fixed-smoothness cosine-series (sieve) regression with an
# ORACLE-RATE truncation J_n = round(c_J * n^{1/(2 s + d)}). This realizes the
# minimax L2 rate n^{-s/(2s+d)} for the DGP's true smoothness s -- deliberately
# NON-adaptive (unlike grf), so the composed bilinear estimator's rate tracks
# s_S + s_Y and the first-order boundary becomes visible. This cleanly
# instantiates the theorem's CATE-rate assumption (A6) and isolates the
# functional-estimation question (Stage 1's target) from CATE learning.
#
# RCT with known e = 1/2, so the propensity is not a nuisance. AIPW pseudo-outcome
# for outcome R_a:
#   xi_a(O) = mu_{a,1}(X) - mu_{a,0}(X) + 2 (2A - 1) ( R_a - mu_{a,A}(X) ),
# with E[xi_a | X] = tau_a(X)  (the 2 = 1/e).
# =============================================================================

# --- number of sieve features via the oracle minimax rule --------------------
# c_J = 2.0 chosen by a small sweep at the A_above design (best SE calibration /
# coverage at n=2000; larger c_J inflates Var(tau_hat) and worsens the negative
# remainder bias -E[(tau_hat-tau)^2]). Fast-track choice; not exhaustively tuned.
nfeat_rule <- function(n, s, d, c_J = 2.0, max_frac = 0.4) {
  J <- round(c_J * n^(1 / (2 * s + d)))
  J <- max(2L, as.integer(J))
  # never use more than max_frac of the per-arm sample as features (OLS stability)
  cap <- as.integer(max_frac * (n / 2))
  min(J, max(2L, cap))
}

# --- cosine sieve feature matrix ---------------------------------------------
# X: n x d in [0,1]. nfeat: number of basis functions (excluding intercept).
# For d=1 uses frequencies 1..nfeat. For d=2 uses the nfeat lowest-magnitude
# tensor frequencies (j,k), j,k >= 0, (0,0) excluded. Returns n x nfeat matrix
# (intercept added separately by the fitter).
sieve_features <- function(X, nfeat, d = ncol(X)) {
  X <- as.matrix(X)
  if (d == 1L) {
    freqs <- matrix(seq_len(nfeat), ncol = 1L)
  } else if (d == 2L) {
    # candidate frequencies up to some per-axis max, sorted by magnitude
    jmax <- ceiling(sqrt(nfeat)) + 2L
    grid <- expand.grid(j = 0:jmax, k = 0:jmax)
    grid <- grid[!(grid$j == 0 & grid$k == 0), ]
    grid <- grid[order(grid$j^2 + grid$k^2), ]
    freqs <- as.matrix(grid[seq_len(min(nfeat, nrow(grid))), , drop = FALSE])
  } else {
    stop("sieve supports d in {1,2}")
  }
  n <- nrow(X); nf <- nrow(freqs)
  Phi <- matrix(1, n, nf)
  for (l in seq_len(d)) {
    # a zero frequency contributes cos(0)=1 (constant along that axis)
    Phi <- Phi * (sqrt(2) * cos(pi * outer(X[, l], freqs[, l])))
  }
  Phi
}

# --- fit per-arm sieve regressions for one outcome ---------------------------
# Returns a closure predicting mu_1, mu_0, tau on new X, plus the fitted coefs.
# Uses OLS within each treatment arm on [intercept, sieve features].
fit_outcome_sieve <- function(X, R, A, nfeat, d) {
  Phi <- sieve_features(X, nfeat, d)
  D <- cbind(1, Phi)
  fit_arm <- function(idx) {
    if (length(idx) <= ncol(D)) {
      # too few obs for the feature count: ridge-stabilize
      qr.coef(qr(crossprod(D[idx, , drop = FALSE]) + diag(1e-6, ncol(D))),
              crossprod(D[idx, , drop = FALSE], R[idx]))
    } else {
      qr.solve(D[idx, , drop = FALSE], R[idx])
    }
  }
  b1 <- fit_arm(which(A == 1))
  b0 <- fit_arm(which(A == 0))
  list(b1 = b1, b0 = b0, nfeat = nfeat, d = d)
}

predict_outcome_sieve <- function(fit, Xnew) {
  Dn <- cbind(1, sieve_features(Xnew, fit$nfeat, fit$d))
  mu1 <- as.numeric(Dn %*% fit$b1)
  mu0 <- as.numeric(Dn %*% fit$b0)
  list(mu1 = mu1, mu0 = mu0, tau = mu1 - mu0)
}

# --- AIPW pseudo-outcome given fitted mu on the SAME rows --------------------
# A, R length-n; mu1, mu0 length-n predictions. e = 1/2 (RCT).
aipw_pseudo <- function(A, R, mu1, mu0) {
  muA <- ifelse(A == 1, mu1, mu0)
  (mu1 - mu0) + 2 * (2 * A - 1) * (R - muA)
}
