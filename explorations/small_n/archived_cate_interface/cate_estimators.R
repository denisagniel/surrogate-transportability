# =============================================================================
# cate_estimators.R -- pluggable CATE (conditional average treatment effect)
# estimators for the across-study correlation functional.
# =============================================================================
# A CATE estimator is a function with the contract
#
#     cate_fn(y, A, X, x_eval) -> list(tau    = <numeric, length(x_eval)>,
#                                       var    = <numeric, length(x_eval), or NA>,
#                                       if_mat = <n x length(x_eval) matrix, or NULL>)
#
# where `if_mat` (optional) holds per-observation influence contributions with
# tau_hat(x_k) - tau(x_k) ~ mean_i if_mat[i, k]. When BOTH outcomes' estimators
# return if_mat, tv_ball_correlation_cate(se = "if") can form an
# influence-function SE that includes the cross-outcome covariance (see
# IF_SE_derivation.md). Estimators without if_mat fall back to bootstrap SE.
#
# estimating E[y(1) - y(0) | X = x_eval] for ONE outcome at a time. It is called
# separately on the surrogate S and the outcome Y; estimating them separately is
# the structural safeguard against manufacturing across-study correlation -- a
# CATE model that ties the functional forms of tau_S and tau_Y (or over-smooths
# to a fixed low-order shape) can force their correlation to +/-1. See
# cate_estimator() for the built-ins.

#' Built-in CATE estimators
#'
#' Constructors for the built-in conditional-average-treatment-effect (CATE)
#' estimators used by [tv_ball_correlation_cate()]. Each returns a function with
#' the contract `function(y, A, X, x_eval)` returning a list with `tau` (the
#' estimated treatment effect at each value in `x_eval`) and `var` (per-point
#' estimation variance, or `NA`).
#'
#' @details
#' Estimators are always applied to one outcome at a time (surrogate `S` and
#' outcome `Y` separately). Do **not** supply a CATE estimator that shares
#' structure across the two outcomes or imposes a rigid low-order functional form:
#' either can artificially force the across-study correlation toward \eqn{\pm 1}.
#'
#' Built-ins:
#' \describe{
#'   \item{`"saturated"`}{Per-cell (per unique `X` value) difference in means.
#'     The nonparametric estimator for a discrete/few-level `X`; unbiased but
#'     high-variance in sparse cells at small `n`. Provides analytic per-cell
#'     variance. `x_eval` must be the unique `X` levels.}
#'   \item{`"grf"`}{Causal forest ([grf::causal_forest]) fit to one outcome, with
#'     known randomized-trial propensity `W.hat = 0.5`, predicted at `x_eval`.
#'     Data-adaptive and cross-fit; suitable for continuous or multivariate `X`.
#'     Requires the \pkg{grf} package. Provides per-point variance estimates.}
#' }
#'
#' @param which Character, one of `"saturated"` or `"grf"`.
#' @param num_trees For `"grf"`, number of trees (default 500).
#' @param w_hat For `"grf"`, known treatment probability (default 0.5, RCT).
#'
#' @return A CATE-estimator function with the contract described above.
#'
#' @seealso [tv_ball_correlation_cate()]
#' @examples
#' f <- cate_estimator("saturated")
#' # f(y, A, X, x_eval) -> list(tau=, var=)
#' @export
cate_estimator <- function(which = c("saturated", "grf"),
                           num_trees = 500L, w_hat = 0.5) {
  which <- match.arg(which)
  switch(
    which,
    saturated = function(y, A, X, x_eval) .cate_saturated(y, A, X, x_eval),
    grf       = function(y, A, X, x_eval) .cate_grf(y, A, X, x_eval,
                                                    num_trees = num_trees,
                                                    w_hat = w_hat)
  )
}

# --- saturated / per-cell difference in means --------------------------------
# Robust to sparse arm-cells: falls back to the pooled arm mean/variance when a
# cell arm has <1 (mean) or <2 (variance) observations, rather than returning NaN.
.cate_saturated <- function(y, A, X, x_eval) {
  n <- length(y); K <- length(x_eval)
  cell <- match(X, x_eval)
  tau <- numeric(K); v <- numeric(K)
  IF <- matrix(0, n, K)
  pooled1 <- mean(y[A == 1]); pooled0 <- mean(y[A == 0])
  pooled_var <- stats::var(y)
  for (k in seq_len(K)) {
    ink <- cell == k
    y1 <- y[ink & A == 1]; y0 <- y[ink & A == 0]
    m1 <- if (length(y1) >= 1) mean(y1) else pooled1
    m0 <- if (length(y0) >= 1) mean(y0) else pooled0
    tau[k] <- m1 - m0
    var1 <- if (length(y1) >= 2) stats::var(y1) else pooled_var
    var0 <- if (length(y0) >= 2) stats::var(y0) else pooled_var
    v[k] <- var1 / max(length(y1), 1) + var0 / max(length(y0), 1)
    # exact per-observation influence contribution to tau(k) (see IF_SE_derivation.md):
    # (1/p_k)[ A(y-m1)/e_k - (1-A)(y-m0)/(1-e_k) ] on the cell, 0 elsewhere.
    pk <- mean(ink); ek <- mean(A[ink])
    if (pk > 0 && ek > 0 && ek < 1) {
      idx <- which(ink)
      IF[idx, k] <- (1 / pk) * (A[idx] * (y[idx] - m1) / ek -
                                (1 - A[idx]) * (y[idx] - m0) / (1 - ek))
    }
  }
  list(tau = tau, var = v, if_mat = IF)
}

# --- grf causal forest, one outcome ------------------------------------------
.cate_grf <- function(y, A, X, x_eval, num_trees = 500L, w_hat = 0.5) {
  if (!requireNamespace("grf", quietly = TRUE)) {
    stop("cate_estimator('grf') requires the 'grf' package. Install it with ",
         "install.packages('grf').", call. = FALSE)
  }
  Xm <- as.matrix(X)
  cf <- grf::causal_forest(X = Xm, Y = y, W = A, W.hat = w_hat,
                           num.trees = num_trees)
  pr <- stats::predict(cf, newdata = as.matrix(x_eval),
                       estimate.variance = TRUE)
  # if_mat = NULL: grf's per-obs IF (infinitesimal jackknife) is not exposed here,
  # so the "if" SE path is unavailable for grf; use bootstrap instead.
  list(tau = as.numeric(pr$predictions),
       var = as.numeric(pr$variance.estimates),
       if_mat = NULL)
}
