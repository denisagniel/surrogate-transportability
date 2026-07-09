# =============================================================================
# kernel_smooth.R -- smooth-kernel bilinear functional and its debiased estimator.
# =============================================================================
# Estimand (smooth bounded kernel C):
#   psi_ab^C = int int C(x,x') tau_a(x) tau_b(x') dP0(x) dP0(x').
# Representer of the one-step direction:
#   h_b(x) = int C(x,x') tau_b(x') dP0(x').
# Influence function (conditional on C, P0 fixed; the L2(P0) inner-product form):
#   IF_ab^C(O) = h_b(X)(xi_a(O) - tau_a(X)) + h_a(X)(xi_b(O) - tau_b(X))
#              + [ int int C tau_a tau_b dP0^2 - psi_ab^C ].
# The last bracket is the plug-in centering; the mean-zero score is the sum of the
# first two terms plus (Ctautau - psi). One-step estimator:
#   psi_hat = U-stat plug-in over held-out folds + P_n of the correction.
#
# We validate on d=1 with a Gaussian kernel C(x,x') = exp(-(x-x')^2/(2 ell^2)).
# The smoothing by C RELAXES the Dirac elbow: h_b is smoother than tau_b, so the
# remainder int int C (tau_hat_a-tau_a)(tau_hat_b-tau_b) dP0^2 is controlled under
# WEAKER smoothness than the Dirac functional. Rerunning B_below (which broke the
# Dirac case) under this kernel should restore coverage.
# =============================================================================

# expects pseudo_outcome.R + dgp_smooth.R sourced.

# Gaussian kernel matrix between two X vectors (d=1)
kernel_gauss <- function(x, xp, ell = 0.2) {
  exp(-outer(x, xp, function(a, b) (a - b)^2) / (2 * ell^2))
}

# --- closed-form-ish truth for psi_ab^C via tensor quadrature ----------------
# tau functions are cosine series; integrate C tau_a tau_b over [0,1]^2 by a fine
# Gauss/Riemann grid. Returns psi_ab^C. Validated against the analytic double
# series sum_{j,k} b^a_j b^b_k <phi_j, C phi_k> in the check script.
psi_true_smooth <- function(cfg, ell = 0.2, ngrid = 400, c_S = 1, c_Y = 1,
                            pair = "SY", J = 200L) {
  bS <- cate_basis(cfg$s_S, 1, J); bY <- cate_basis(cfg$s_Y, 1, J)
  xg <- (seq_len(ngrid) - 0.5) / ngrid           # midpoint rule on [0,1]
  w <- 1 / ngrid
  tS <- eval_cate(matrix(xg, ncol = 1), bS, c_S)
  tY <- eval_cate(matrix(xg, ncol = 1), bY, c_Y)
  ta <- if (pair == "YY") tY else tS
  tb <- if (pair == "SS") tS else tY
  Cm <- kernel_gauss(xg, xg, ell)
  # psi = w^2 * ta' C tb  (double integral by product midpoint rule)
  as.numeric(w^2 * (ta %*% Cm %*% tb))
}

# --- debiased estimator for the smooth-kernel functional ---------------------
# Approximates h_b(x)=int C(x,x')tau_b(x')dP0 by a Monte-Carlo average over the
# held-out sample's tau_hat_b (cross-fit): h_hat_b(x) = mean_j C(x,X_j) tau_hat_b(X_j).
# Uses the same crossfit_one() CATE/pseudo-outcome as the Dirac estimator.
psi_hat_smooth <- function(data, pair, s_S, s_Y, ell = 0.2, K = 5) {
  stopifnot(pair %in% c("SY", "SS", "YY"))
  X <- data$X1; n <- length(X)
  folds <- make_folds(n, K)
  cf_S <- crossfit_one(matrix(X, ncol = 1), data$S, data$A, s_S, 1, K, folds)
  cf_Y <- if (pair == "SS") cf_S else
          crossfit_one(matrix(X, ncol = 1), data$Y, data$A, s_Y, 1, K, folds)
  if (pair == "SY")      { ta <- cf_S$tau; xa <- cf_S$xi; tb <- cf_Y$tau; xb <- cf_Y$xi }
  else if (pair == "SS") { ta <- cf_S$tau; xa <- cf_S$xi; tb <- cf_S$tau; xb <- cf_S$xi }
  else                   { ta <- cf_Y$tau; xa <- cf_Y$xi; tb <- cf_Y$tau; xb <- cf_Y$xi }

  Cm <- kernel_gauss(X, X, ell)
  diag(Cm) <- 0                         # leave-one-out to avoid self-term bias
  denom <- n - 1
  # representers h_a(X_i)=mean_{j!=i} C_ij ta_j ; h_b similarly
  h_b <- as.numeric(Cm %*% tb) / denom
  h_a <- as.numeric(Cm %*% ta) / denom
  # plug-in double integral (U-stat, off-diagonal): (1/(n(n-1))) sum_{i!=j} C_ij ta_i tb_j
  plugin <- as.numeric(ta %*% Cm %*% tb) / (n * denom)
  # one-step: plugin + P_n[ h_b (xi_a - ta) + h_a (xi_b - tb) ]
  corr <- h_b * (xa - ta) + h_a * (xb - tb)
  psi <- plugin + mean(corr)
  # IF (mean-zero): h_b(xi_a-ta) + h_a(xi_b-tb) + (C-plug per obs - psi). Use the
  # standard one-step IF: score_i = h_b_i xi_a_i + h_a_i xi_b_i - h_b_i ta_i ... ;
  # for SE we use the correction + centered plug-in contribution.
  ctautau_i <- as.numeric(Cm %*% tb) / denom * ta   # per-obs plug-in contribution ~ h_b*ta
  IF <- h_b * xa + h_a * xb - ctautau_i - psi
  se <- sqrt(mean(IF^2) / n)
  z <- qnorm(0.975)
  list(psi = psi, se = se, ci_lower = psi - z * se, ci_upper = psi + z * se,
       plugin = plugin, n = n)
}
