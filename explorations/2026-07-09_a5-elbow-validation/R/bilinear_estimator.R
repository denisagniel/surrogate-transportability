# =============================================================================
# bilinear_estimator.R -- one-step cross-fit debiased estimator of the Dirac
# bilinear functional psi_ab = E[tau_a(X) tau_b(X)], with IF-based SE, plus the
# naive plug-in comparator.
# =============================================================================
# Influence function (Dirac kernel, one-step direction h = 2 tau):
#   IF_ab(O) = tau_a(X) xi_b(O) + tau_b(X) xi_a(O) - tau_a(X) tau_b(X) - psi_ab,
# where xi_a is the AIPW pseudo-outcome (E[xi_a|X] = tau_a). Mean-zero:
#   E[tau_a xi_b] = E[tau_a tau_b] = psi_ab, likewise the second term, so
#   E[IF_ab] = 2 psi_ab - psi_ab - psi_ab = 0.
#
# One-step cross-fit estimator (K folds): for each obs i in fold k, tau_hat and
# mu_hat come from a model fit on the OTHER folds; then
#   psi_hat_ab = P_n[ tau_hat_a xi_hat_b + tau_hat_b xi_hat_a - tau_hat_a tau_hat_b ].
# SE = sqrt( P_n[ IF_hat^2 ] / n ),  IF_hat = tau_hat_a xi_hat_b + tau_hat_b xi_hat_a
#   - tau_hat_a tau_hat_b - psi_hat_ab.
#
# Plug-in comparator: psi_plug = P_n[ tau_hat_a tau_hat_b ] (still cross-fit for a
# fair rate comparison, but with NO one-step correction) -- shows debiasing is
# load-bearing.
# =============================================================================

# expects pseudo_outcome.R sourced (nfeat_rule, fit_outcome_sieve,
# predict_outcome_sieve, aipw_pseudo).

make_folds <- function(n, K) {
  fold <- sample(rep_len(seq_len(K), n))
  split(seq_len(n), fold)
}

# --- cross-fit the CATE + pseudo-outcome for ONE outcome ---------------------
# Returns per-observation tau_hat and xi_hat (both length n), assembled from
# out-of-fold fits. s is the smoothness used for the nfeat rule (Stage 1 knows
# the true s; this is the deliberate oracle-rate sieve).
crossfit_one <- function(X, R, A, s, d, K, folds) {
  n <- length(R)
  tau_hat <- numeric(n); xi_hat <- numeric(n)
  for (k in seq_along(folds)) {
    te <- folds[[k]]; tr <- setdiff(seq_len(n), te)
    nf <- nfeat_rule(length(tr), s, d)
    fit <- fit_outcome_sieve(X[tr, , drop = FALSE], R[tr], A[tr], nf, d)
    pr <- predict_outcome_sieve(fit, X[te, , drop = FALSE])
    tau_hat[te] <- pr$tau
    xi_hat[te]  <- aipw_pseudo(A[te], R[te], pr$mu1, pr$mu0)
  }
  list(tau = tau_hat, xi = xi_hat)
}

# --- main estimator ----------------------------------------------------------
# data: data.frame with X1..Xd, A, S, Y. pair: "SY","SS","YY". s_a,s_b: true
# smoothness of the two outcomes in the pair (for the sieve rule). Returns a list
# with debiased + plug-in estimates, IF-based SE, and diagnostics.
psi_hat_dirac <- function(data, pair, s_S, s_Y, d, K = 5) {
  Xcols <- grep("^X", names(data), value = TRUE)
  X <- as.matrix(data[, Xcols, drop = FALSE])
  n <- nrow(X)
  folds <- make_folds(n, K)

  # cross-fit each needed outcome once
  cf_S <- crossfit_one(X, data$S, data$A, s_S, d, K, folds)
  cf_Y <- if (pair == "SS") cf_S else crossfit_one(X, data$Y, data$A, s_Y, d, K, folds)

  if (pair == "SY") {
    ta <- cf_S$tau; xa <- cf_S$xi; tb <- cf_Y$tau; xb <- cf_Y$xi
  } else if (pair == "SS") {
    ta <- cf_S$tau; xa <- cf_S$xi; tb <- cf_S$tau; xb <- cf_S$xi
  } else if (pair == "YY") {
    ta <- cf_Y$tau; xa <- cf_Y$xi; tb <- cf_Y$tau; xb <- cf_Y$xi
  } else stop("pair must be SY, SS, or YY")

  # one-step debiased
  plug_terms <- ta * tb
  onestep_terms <- ta * xb + tb * xa - ta * tb
  psi_deb <- mean(onestep_terms)
  IF <- onestep_terms - psi_deb
  se_deb <- sqrt(mean(IF^2) / n)

  # naive plug-in (cross-fit, no correction)
  psi_plug <- mean(plug_terms)
  # plug-in SE via the delta-ish IF of E[tau_a tau_b] treating tau as known would
  # understate; report the same one-step IF scale is NOT valid for plug-in, so we
  # give plug-in a bootstrap-free nominal SE = sd(plug_terms)/sqrt(n) (naive; only
  # used to show its CI miscovers).
  se_plug <- sd(plug_terms) / sqrt(n)

  z <- qnorm(0.975)
  list(
    psi_debiased = psi_deb, se_debiased = se_deb,
    ci_lower_deb = psi_deb - z * se_deb, ci_upper_deb = psi_deb + z * se_deb,
    psi_plugin = psi_plug, se_plugin = se_plug,
    ci_lower_plug = psi_plug - z * se_plug, ci_upper_plug = psi_plug + z * se_plug,
    n = n, K = K
  )
}
