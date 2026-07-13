# =============================================================================
# random_dgp.R -- draw random DGPs spanning the assumption class (generality)
# =============================================================================
# The generality headline: coverage across MANY random DGPs, not 4 hand-picked
# ones. Each draw specifies a full DGP on finite X-support with:
#   - K covariate levels (support size varies)
#   - p_X reference distribution (concentration varies)
#   - cell CATEs tau_S(k), tau_Y(k) from a flexible (incl. NONLINEAR) mean model
#   - error law (Gaussian / t / heteroskedastic) -- a FREE stressor: it does not
#     change the estimand (truth depends only on the CATEs), but stresses the
#     estimator's finite-sample behavior.
#   - propensity: RCT (0.5) or X-dependent e(X) for the observational/AIPW path
#   - lambda (TV-ball radius)
#
# Staying INSIDE the class: the canonical estimand needs non-degenerate
# Var_mu(Delta_S), Var_mu(Delta_Y) > 0 (derivation §4). We reject draws whose
# true rho is undefined (near-zero effect variance) so we don't score the
# estimator where the target itself is ill-posed -- that would be an unfair
# "failure". Such rejections are LOGGED, not hidden (Constitution §9).
#
# generate_random_data(spec, n) simulates one dataset from a drawn spec.
# The CATEs are stored ON the spec so true_rho() uses the exact same mean model.
# =============================================================================

# Draw ONE random DGP spec. `regime` lets the ensemble weight toward RCT vs obs.
draw_random_dgp <- function(rng_seed,
                            K_choices = c(3L, 5L, 8L),
                            lambda_range = c(0.1, 0.4),
                            allow_observational = TRUE,
                            error_laws = c("gaussian", "t", "hetero")) {
  set.seed(rng_seed)

  K <- sample(K_choices, 1)
  X_levels <- seq_len(K) - (K + 1) / 2          # centered integer levels
  X_levels <- X_levels / max(abs(X_levels))     # scale to [-1, 1]

  # p_X: Dirichlet-ish via normalized exponentials; alpha controls concentration
  alpha <- runif(1, 0.5, 4)
  p_X <- rgamma(K, shape = alpha); p_X <- p_X / sum(p_X)

  # --- Flexible cell CATEs (nonlinear in X allowed) ---------------------------
  # tau_S(x), tau_Y(x) as low-order polynomials in x with random coefficients;
  # this spans linear + curved effect modification without leaving finite support.
  poly <- function() {
    a0 <- runif(1, -1, 1); a1 <- runif(1, -1.5, 1.5)
    a2 <- runif(1, -1, 1) * sample(c(0, 1), 1, prob = c(0.4, 0.6))  # sometimes curved
    function(x) a0 + a1 * x + a2 * x^2
  }
  fS <- poly(); fY_direct <- poly()
  tau_S <- fS(X_levels)
  # Y-CATE = direct modification + surrogate pathway (beta_S * tau_S, beta_S random sign)
  beta_S <- runif(1, -1.5, 1.5)
  tau_Y <- fY_direct(X_levels) + beta_S * tau_S

  # scale of the surrogate/outcome noise
  sigma_S <- runif(1, 0.3, 1.0)
  sigma_Y <- runif(1, 0.3, 1.0)
  error_law <- sample(error_laws, 1)

  # propensity
  observational <- allow_observational && (runif(1) < 0.5)
  # e(X): logistic in x if observational, else 0.5. Kept away from 0/1.
  e_coef <- if (observational) runif(1, -1.2, 1.2) else 0
  e_int  <- if (observational) runif(1, -0.4, 0.4) else 0

  lambda <- runif(1, lambda_range[1], lambda_range[2])

  list(
    K = K, X_levels = X_levels, p_X = p_X,
    tau_S = tau_S, tau_Y = tau_Y,
    beta_S = beta_S, sigma_S = sigma_S, sigma_Y = sigma_Y,
    error_law = error_law,
    observational = observational, e_coef = e_coef, e_int = e_int,
    lambda = lambda, rng_seed = rng_seed
  )
}

# propensity vector for given X (logistic), clipped away from 0/1
.e_of_x <- function(spec, x) {
  if (!spec$observational) return(rep(0.5, length(x)))
  p <- plogis(spec$e_int + spec$e_coef * x)
  pmax(pmin(p, 0.9), 0.1)
}

# Simulate one dataset (n rows) from a drawn spec. Mean structure = the CATEs;
# we realize S, Y so that E[S|A=a,x], E[Y|A=a,x] reproduce tau_S, tau_Y exactly.
generate_random_data <- function(spec, n) {
  X <- sample(spec$X_levels, n, replace = TRUE, prob = spec$p_X)
  eX <- .e_of_x(spec, X)
  A <- rbinom(n, 1, eX)

  # map X value -> cell index for CATE lookup
  k <- match(X, spec$X_levels)
  tS <- spec$tau_S[k]; tY <- spec$tau_Y[k]

  err <- function(sig) {
    switch(spec$error_law,
      gaussian = rnorm(n, 0, sig),
      t        = sig * rt(n, df = 4) / sqrt(4 / (4 - 2)),          # scaled t_4, unit var
      hetero   = rnorm(n, 0, sig * (0.5 + abs(X)))                 # variance grows with |X|
    )
  }
  # baseline (A=0) means set to 0; treatment adds the CATE. Truth uses only CATEs.
  S <- A * tS + err(spec$sigma_S)
  Y <- A * tY + err(spec$sigma_Y)
  data.frame(X = X, A = A, S = S, Y = Y)
}
