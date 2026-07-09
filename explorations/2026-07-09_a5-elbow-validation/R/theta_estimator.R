# =============================================================================
# theta_estimator.R -- Stage 2 end-to-end correlation Theta at continuous X,
# conditional on a sampled discretize-to-cells geometry Sigma.
# =============================================================================
# Pipeline (matches the composed estimator of Theorem A, conditional on geometry):
#   1. cross-fit CATEs tau_S(x), tau_Y(x) on continuous X (grf causal_forest,
#      per outcome, W.hat = 0.5 for the RCT), predicted at each obs;
#   2. aggregate to per-cell CATEs tau_hat_a[k] = mean over obs in cell k, and the
#      per-cell CATE influence matrix IF_a (n x K) from the AIPW pseudo-outcome;
#   3. three DEBIASED quadratic functionals against the sampled Sigma:
#        var_a  = tau_a' Sigma tau_a - tr(Sigma V_a)
#        cov_SY = tau_S' Sigma tau_Y - tr(Sigma V_SY)
#      where V_ab[k,l] = Cov(IF_a[,k], IF_b[,l]) / n  (the per-cell CATE-mean
#      covariance; tr(Sigma V) is the discrete one-step debiasing term);
#   4. compose Theta_hat = cov_SY / sqrt(var_S var_Y)  (floor + clamp);
#   5. IF-based SE via the moment-vector gradient: psi_Theta = g' [IF_S | IF_Y],
#      SE = sqrt(g' V g) with the FULL 2K x 2K V (cross-outcome block included),
#      g = grad_theta(tau_S, tau_Y, Sigma) from 07_if_se_prototype.R (re-defined
#      here to keep Stage 2 self-contained).
#
# grf is used here (Stage 2) DELIBERATELY: this stage tests end-to-end behavior
# with the paper's recommended generalizable learner, not the elbow (Stage 1).
# Requires grf; loaded by the caller.
# =============================================================================

# analytic gradient of Theta wrt (tau_S, tau_Y) given Sigma (from 07 prototype).
grad_theta <- function(tS, tY, Sig) {
  num <- as.numeric(t(tS) %*% Sig %*% tY)
  a   <- as.numeric(t(tS) %*% Sig %*% tS)
  b   <- as.numeric(t(tY) %*% Sig %*% tY)
  gS <- (Sig %*% tY - (num / a) * (Sig %*% tS)) / sqrt(a * b)
  gY <- (Sig %*% tS - (num / b) * (Sig %*% tY)) / sqrt(a * b)
  c(as.numeric(gS), as.numeric(gY))
}

# cross-fit grf CATE for one outcome; returns per-obs tau_hat and the AIPW
# pseudo-outcome xi (E[xi|X]=tau). K folds. RCT known e=0.5.
crossfit_grf_one <- function(X, R, A, K = 5, folds = NULL, num.trees = 500) {
  n <- length(R)
  if (is.null(folds)) folds <- make_folds(n, K)
  tau_hat <- numeric(n); xi_hat <- numeric(n)
  Xm <- as.matrix(X)
  for (k in seq_along(folds)) {
    te <- folds[[k]]; tr <- setdiff(seq_len(n), te)
    cf <- grf::causal_forest(Xm[tr, , drop = FALSE], Y = R[tr], W = A[tr],
                             W.hat = 0.5, num.trees = num.trees)
    # tau at test points
    tau_hat[te] <- predict(cf, Xm[te, , drop = FALSE])$predictions
    # outcome regressions mu_a for the AIPW pseudo-outcome: grf's Y.hat is
    # E[Y|X]; recover mu1, mu0 from Y.hat and tau via mu1 = Yhat + (1-e)tau,
    # mu0 = Yhat - e tau (e = 0.5): mu1 = Yhat + 0.5 tau, mu0 = Yhat - 0.5 tau.
    yhat_te <- predict(cf, Xm[te, , drop = FALSE], estimate.variance = FALSE)$predictions
    # grf does not directly return Y.hat at new points; fit a quick Y.hat via the
    # forest's regression on the training fold (use ranger-free: local mean surrogate).
    # Simpler + valid: use the AIPW score with mu_A implied by tau and the observed
    # arm means is not needed -- use the doubly-robust score with mu from grf's
    # own Y.hat on training, predicted at test by a regression forest.
    rf <- grf::regression_forest(Xm[tr, , drop = FALSE], R[tr], num.trees = num.trees)
    mu_te <- predict(rf, Xm[te, , drop = FALSE])$predictions   # E[R|X]
    tau_te <- tau_hat[te]
    mu1 <- mu_te + 0.5 * tau_te
    mu0 <- mu_te - 0.5 * tau_te
    xi_hat[te] <- aipw_pseudo(A[te], R[te], mu1, mu0)
  }
  list(tau = tau_hat, xi = xi_hat)
}

# per-cell aggregation: cell-mean CATE (length K) and per-obs cell IF matrix
# (n x K) whose column k is the influence of tau_hat_bar[k] = mean_{i in k} xi_i.
# IF[i,k] = (1{cell_i=k}/p_k) (xi_i - tau_bar_k) / n_scale? -- we return the
# raw contribution so cov(.)/n gives Var of the cell mean.
cell_aggregate <- function(xi, cells, K) {
  n <- length(xi)
  tau_bar <- numeric(K); IF <- matrix(0, n, K)
  for (k in seq_len(K)) {
    ink <- cells == k
    nk <- sum(ink)
    if (nk == 0) { tau_bar[k] <- 0; next }
    tau_bar[k] <- mean(xi[ink])
    pk <- nk / n
    # IF of the cell mean of xi: (1{in k}/p_k)(xi - tau_bar_k). Var/n = Var(cell mean).
    IF[ink, k] <- (xi[ink] - tau_bar[k]) / pk
  }
  list(tau = tau_bar, IF = IF)
}

# main Stage 2 estimator.
theta_hat_stage2 <- function(data, Sig, K, floor_var = 1e-4, K_folds = 5) {
  X <- data$X1; n <- length(X)
  cells <- assign_cells(X, K)
  folds <- make_folds(n, K_folds)

  cf_S <- crossfit_grf_one(matrix(X, ncol = 1), data$S, data$A, K_folds, folds)
  cf_Y <- crossfit_grf_one(matrix(X, ncol = 1), data$Y, data$A, K_folds, folds)

  aggS <- cell_aggregate(cf_S$xi, cells, K)
  aggY <- cell_aggregate(cf_Y$xi, cells, K)
  tS <- aggS$tau; tY <- aggY$tau
  IFS <- aggS$IF; IFY <- aggY$IF

  # V blocks (2K x 2K), /n so these are covariances of the cell MEANS.
  Vfull <- stats::cov(cbind(IFS, IFY)) / n
  VSS <- Vfull[1:K, 1:K]
  VYY <- Vfull[(K + 1):(2 * K), (K + 1):(2 * K)]
  VSY <- Vfull[1:K, (K + 1):(2 * K)]

  # debiased quadratic functionals: plug-in minus tr(Sigma V) (one-step correction)
  var_S <- as.numeric(t(tS) %*% Sig %*% tS) - sum(Sig * VSS)   # tr(Sig VSS)=sum(Sig*VSS)
  var_Y <- as.numeric(t(tY) %*% Sig %*% tY) - sum(Sig * VYY)
  cov_SY <- as.numeric(t(tS) %*% Sig %*% tY) - sum(Sig * VSY)

  var_S <- max(var_S, floor_var); var_Y <- max(var_Y, floor_var)
  theta <- cov_SY / sqrt(var_S * var_Y)
  theta <- max(min(theta, 1), -1)

  # IF-based SE: g' V g with the full cross-outcome V. Gradient at the debiased
  # (plug-in) cell CATEs -- use tS, tY (the cell means) as the moment argument.
  g <- grad_theta(tS, tY, Sig)
  se <- sqrt(as.numeric(t(g) %*% Vfull %*% g))

  z <- qnorm(0.975)
  list(theta = theta, se = se, ci_lower = theta - z * se, ci_upper = theta + z * se,
       var_S = var_S, var_Y = var_Y, cov_SY = cov_SY, n = n, K = K)
}
