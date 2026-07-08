# =============================================================================
# 02_cate_estimators.R -- pluggable cell-level CATE estimators for the TV-ball
# correlation. EXPLORATION (fast-track).
#
# Key idea (from the CATE survey): with a 5-level X, the across-study correlation
# has a closed form in the cell CATEs and the sampler covariance Sigma_q:
#
#     rho = (tS' Sigma_q tY) / sqrt( (tS' Sigma_q tS)(tY' Sigma_q tY) )
#
# where tS,tY are the per-cell CATE vectors and Sigma_q = Cov_mu(q) over Q sampled
# uniformly from the TV ball. Sigma_q depends only on P0 and lambda, NOT on the
# CATE estimator -- so we sample it ONCE per dataset and plug in different CATE
# estimators cheaply. This isolates the effect of CATE estimation on rho_hat and
# avoids re-running MCMC per estimator.
#
# CATE estimators (all SEPARATE per outcome -> cannot manufacture correlation):
#   raw       : per-cell difference in means (current baseline; nonparametric MLE for 5-level X)
#   shrink    : empirical-Bayes / James-Stein shrinkage of the raw cell effects
#   poly2     : quadratic-in-X pooled regression (matches true tau_Y curvature)
#   linearX   : linear-in-X (DELIBERATELY misspecified for tau_Y -> manufacture-corr guardrail)
#   disatten  : raw effects, but rho DENOMINATOR corrected for cell-effect noise (measurement-error)
#
# The linearX arm is the guardrail: if an over-smoothed CATE forces dgp1/dgp2
# toward +/-1, we see it here.
# =============================================================================

suppressMessages(devtools::load_all("."))

# --- sampler covariance Sigma_q for the empirical P0 (shared across estimators)
sigma_q_from_data <- function(X, X_levels, lambda, M = 1500, burn_in = 300, thin = 3) {
  K <- length(X_levels)
  P0 <- as.numeric(table(factor(X, levels = X_levels))) / length(X)
  Q <- sample_tv_ball(P0, lambda = lambda, M = M, burn_in = burn_in, thin = thin,
                      verbose = FALSE)
  stats::cov(Q)                       # K x K covariance of q across sampled studies
}

# --- per-cell CATE estimators. Each returns list(tau = K-vector, var = K-vector)
#     var = estimation variance of tau per cell (for disattenuation); NA if n/a.

# raw per-cell difference in means + its variance.
# Robust to sparse arm-cells (0 or 1 obs): fall back to the pooled arm mean for
# tau (so a sparse cell contributes ~0 signal rather than NaN) and use a pooled
# variance estimate when a cell arm has <2 obs. This mirrors what any real
# implementation must do at small n; documented as an exploration choice.
cate_raw <- function(y, A, cell, K) {
  tau <- numeric(K); v <- numeric(K)
  pooled1 <- mean(y[A == 1]); pooled0 <- mean(y[A == 0])
  pooled_var <- stats::var(y)                       # crude fallback scale
  for (k in seq_len(K)) {
    y1 <- y[cell == k & A == 1]; y0 <- y[cell == k & A == 0]
    m1 <- if (length(y1) >= 1) mean(y1) else pooled1
    m0 <- if (length(y0) >= 1) mean(y0) else pooled0
    tau[k] <- m1 - m0
    var1 <- if (length(y1) >= 2) stats::var(y1) else pooled_var
    var0 <- if (length(y0) >= 2) stats::var(y0) else pooled_var
    n1 <- max(length(y1), 1); n0 <- max(length(y0), 1)
    v[k] <- var1/n1 + var0/n0
  }
  list(tau = tau, var = v)
}

# empirical-Bayes (Normal-Normal) shrinkage of raw cell effects toward grand mean
cate_shrink <- function(raw) {
  tau <- raw$tau; s2 <- raw$var
  mu <- mean(tau)
  tau_between <- max(stats::var(tau) - mean(s2), 1e-8)   # method-of-moments prior var
  w <- tau_between / (tau_between + s2)                  # shrink weight per cell
  list(tau = mu + w * (tau - mu),
       var = w * s2)                                     # posterior var (approx)
}

# pooled polynomial-in-X CATE via interacted lm; returns per-cell fitted effect + SE
cate_poly <- function(y, A, x_num, x_levels, degree) {
  df <- data.frame(y = y, A = A, x = x_num)
  form <- if (degree == 1) y ~ A * x else y ~ A * poly(x, degree, raw = TRUE)
  fit <- stats::lm(form, data = df)
  # per-cell effect = predicted(A=1) - predicted(A=0) at each x level
  nd1 <- data.frame(A = 1, x = x_levels); nd0 <- data.frame(A = 0, x = x_levels)
  p1 <- stats::predict(fit, nd1, se.fit = TRUE)
  p0 <- stats::predict(fit, nd0, se.fit = TRUE)
  list(tau = as.numeric(p1$fit - p0$fit),
       var = as.numeric(p1$se.fit^2 + p0$se.fit^2))      # approx (ignores covariance)
}

# --- rho from cell CATEs + Sigma_q (the closed form) -------------------------
rho_from_cate <- function(tS, tY, Sigma) {
  if (anyNA(tS) || anyNA(tY)) return(NA_real_)
  num <- as.numeric(t(tS) %*% Sigma %*% tY)
  dS  <- as.numeric(t(tS) %*% Sigma %*% tS)
  dY  <- as.numeric(t(tY) %*% Sigma %*% tY)
  if (!is.finite(dS) || !is.finite(dY) || dS <= 0 || dY <= 0) return(NA_real_)
  num / sqrt(dS * dY)
}

# disattenuated rho: subtract expected noise contribution E[eps' Sigma eps] = sum(diag(Sigma)*var)
# from each quadratic form. (Cross term for numerator uses cov(eps_S,eps_Y) per cell,
# which we approximate as 0 here -- refined in 03 if warranted.)
rho_disattenuated <- function(tS, tY, vS, vY, Sigma) {
  if (anyNA(tS) || anyNA(tY) || anyNA(vS) || anyNA(vY)) return(NA_real_)
  d <- diag(Sigma)
  num <- as.numeric(t(tS) %*% Sigma %*% tY)                       # cross-noise ~0 assumed
  dS  <- as.numeric(t(tS) %*% Sigma %*% tS) - sum(d * vS)
  dY  <- as.numeric(t(tY) %*% Sigma %*% tY) - sum(d * vY)
  if (!is.finite(dS) || !is.finite(dY) || dS <= 0 || dY <= 0) return(NA_real_)  # over-correction -> NA
  num / sqrt(dS * dY)
}

# --- estimate rho under all CATE variants for one dataset --------------------
estimate_all <- function(data, x_levels, Sigma) {
  K <- length(x_levels)
  cell <- match(data$X, x_levels)
  rawS <- cate_raw(data$S, data$A, cell, K)
  rawY <- cate_raw(data$Y, data$A, cell, K)
  shrS <- cate_shrink(rawS); shrY <- cate_shrink(rawY)
  p2S  <- cate_poly(data$S, data$A, data$X, x_levels, 2)
  p2Y  <- cate_poly(data$Y, data$A, data$X, x_levels, 2)
  p1S  <- cate_poly(data$S, data$A, data$X, x_levels, 1)
  p1Y  <- cate_poly(data$Y, data$A, data$X, x_levels, 1)
  c(
    raw      = rho_from_cate(rawS$tau, rawY$tau, Sigma),
    shrink   = rho_from_cate(shrS$tau, shrY$tau, Sigma),
    poly2    = rho_from_cate(p2S$tau,  p2Y$tau,  Sigma),
    linearX  = rho_from_cate(p1S$tau,  p1Y$tau,  Sigma),   # guardrail (misspecified tau_Y)
    disatten = rho_disattenuated(rawS$tau, rawY$tau, rawS$var, rawY$var, Sigma)
  )
}

# --- true rho for a DGP under the SAME Sigma (analytic cell CATEs) ------------
true_rho_analytic <- function(spec, Sigma) {
  x <- spec$X_levels; p <- spec$params
  tS <- p$gamma_A + p$gamma_AX * x
  tY <- (p$beta_A + p$beta_AX * x) + (p$beta_S + p$beta_SX * x) * (p$gamma_A + p$gamma_AX * x)
  rho_from_cate(tS, tY, Sigma)
}

if (identical(environment(), globalenv()) && !exists("SOURCED_ONLY")) {
  # quick smoke: one dataset per DGP at n=500
  for (id in c("dgp1", "dgp2")) {
    set.seed(42)
    spec <- canonical_dgp_params(id)
    d <- generate_dgp_data(500, spec$params, spec$p_X, spec$X_levels)
    Sig <- sigma_q_from_data(d$X, spec$X_levels, lambda = 0.3)
    cat(sprintf("\n%s (true rho ~ %.3f, analytic-under-Sigma %.3f):\n",
                id, spec$rho_true, true_rho_analytic(spec, Sig)))
    print(round(estimate_all(d, spec$X_levels, Sig), 4))
  }
}
