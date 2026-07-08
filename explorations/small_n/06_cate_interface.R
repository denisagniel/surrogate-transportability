# =============================================================================
# 06_cate_interface.R -- PROTOTYPE of a pluggable cate_estimator interface for
# the TV-ball correlation. EXPLORATION (fast-track). Not production; a design
# probe for a future package argument.
#
# DESIGN
# ------
# A CATE estimator is any function with the contract
#     cate_fn(y, A, X, x_eval) -> list(tau = <effect at each x_eval cell>,
#                                       var = <est. variance per cell, or NA>)
# estimated for ONE outcome at a time. This single abstraction is the
# generalization: raw cell means, saturated lm, grf, BART, a DR-learner, or a
# user's own estimator all satisfy it. Running it SEPARATELY on S and Y is the
# built-in guard against manufacturing correlation (no shared structure).
#
# The wrapper:
#   1. discretizes X to cells (or uses native levels),
#   2. samples Sigma_q = Cov_mu(q) once from the TV ball,
#   3. gets tau_S, tau_Y from cate_fn (per outcome),
#   4. returns rho via the closed form, optionally disattenuated.
#
# INFERENCE CAVEAT (important, surfaced not hidden):
#   The canonical package estimator's influence-function SE is derived for the
#   REWEIGHTING path (raw effects). A plugged-in learner (grf, ...) changes the
#   point estimate and INVALIDATES that SE. So: IF-SE only for cate="raw";
#   any other estimator -> SE by nonparametric bootstrap over observations
#   (or NA if not requested). We do not pretend the IF-SE transfers.
# =============================================================================

suppressMessages(devtools::load_all("."))
SOURCED_ONLY <- TRUE
source("explorations/small_n/02_cate_estimators.R")   # cate_raw/shrink/poly, rho_from_cate, rho_disattenuated

# ---- built-in CATE estimators (contract: (y,A,X,x_eval) -> list(tau,var)) ----

# raw / saturated per-cell diff-in-means (X must be discrete / matched to x_eval)
cate_fn_raw <- function(y, A, X, x_eval) {
  cell <- match(X, x_eval)
  cate_raw(y, A, cell, length(x_eval))
}

# grf causal forest, one outcome, known RCT propensity 0.5, predicted at x_eval
cate_fn_grf <- function(y, A, X, x_eval) {
  if (!requireNamespace("grf", quietly = TRUE)) stop("grf not installed")
  cf <- grf::causal_forest(matrix(X, ncol = 1), Y = y, W = A, W.hat = 0.5,
                           num.trees = 500)
  pr <- predict(cf, matrix(x_eval, ncol = 1), estimate.variance = TRUE)
  list(tau = pr$predictions, var = pr$variance.estimates)
}

# ---- the pluggable estimator -------------------------------------------------
# cate: "raw", "grf", or a user function with the contract above.
# se:   "if" (valid only for raw), "bootstrap", or "none".
tv_ball_correlation_pluggable <- function(data, lambda,
                                          cate = c("raw", "grf"),
                                          x_levels = NULL,
                                          disattenuate = FALSE,
                                          se = c("none", "bootstrap", "if"),
                                          B = 200, M = 800,
                                          burn_in = 200, thin = 2,
                                          verbose = FALSE) {
  se <- match.arg(se)
  cate_fn <- if (is.function(cate)) cate else
    switch(match.arg(cate), raw = cate_fn_raw, grf = cate_fn_grf)
  cate_label <- if (is.function(cate)) "user" else match.arg(cate)

  if (is.null(x_levels)) x_levels <- sort(unique(data$X))
  K <- length(x_levels)

  # Sigma_q (shared)
  P0 <- as.numeric(table(factor(data$X, levels = x_levels))) / nrow(data)
  Q <- sample_tv_ball(P0, lambda = lambda, M = M, burn_in = burn_in, thin = thin,
                      verbose = FALSE)
  Sig <- stats::cov(Q)

  point <- function(d) {
    cS <- cate_fn(d$S, d$A, d$X, x_levels)
    cY <- cate_fn(d$Y, d$A, d$X, x_levels)
    if (disattenuate && all(is.finite(c(cS$var, cY$var)))) {
      rho_disattenuated(cS$tau, cY$tau, cS$var, cY$var, Sig)
    } else {
      rho_from_cate(cS$tau, cY$tau, Sig)
    }
  }

  rho_hat <- point(data)

  # --- inference ---
  se_val <- NA_real_; se_type <- "none"
  if (se == "if") {
    if (cate_label != "raw")
      stop("IF-SE is only valid for cate='raw' (the reweighting derivation). ",
           "Use se='bootstrap' for other CATE estimators.")
    se_type <- "if-not-implemented-here"   # the package fn provides this; prototype defers
  } else if (se == "bootstrap") {
    n <- nrow(data)
    boot <- vapply(seq_len(B), function(b) {
      idx <- sample.int(n, n, replace = TRUE)
      tryCatch(point(data[idx, , drop = FALSE]), error = function(e) NA_real_)
    }, numeric(1))
    boot <- boot[is.finite(boot)]
    se_val <- stats::sd(boot)
    se_type <- sprintf("bootstrap(B=%d,eff=%d)", B, length(boot))
  }

  list(rho_hat = rho_hat, se = se_val, se_type = se_type,
       cate = cate_label, disattenuate = disattenuate, K = K)
}

if (identical(environment(), globalenv()) && !exists("SOURCED_ONLY_06")) {
  # smoke: canonical dgp1 (5-level X) with raw vs grf; shape sinusoid with grf
  set.seed(7)
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)
  cat("canonical dgp1 (true rho 0.69):\n")
  r1 <- tv_ball_correlation_pluggable(d, 0.3, cate = "raw",
                                      x_levels = spec$X_levels, se = "none")
  r2 <- tv_ball_correlation_pluggable(d, 0.3, cate = "grf",
                                      x_levels = spec$X_levels, se = "bootstrap", B = 100)
  cat(sprintf("  raw: rho=%.3f\n", r1$rho_hat))
  cat(sprintf("  grf: rho=%.3f  se=%.3f (%s)\n", r2$rho_hat, r2$se, r2$se_type))
}
