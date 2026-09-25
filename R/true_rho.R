#' Analytic Cell CATEs for the Canonical DGP
#'
#' Returns the conditional average treatment effects on the surrogate and the
#' outcome at each covariate level, for the canonical linear DGP implemented by
#' [generate_dgp_data()].
#'
#' @details
#' For the canonical structural equations
#' \deqn{S = (\gamma_A + \gamma_{AX} X) A + \epsilon_S,}
#' \deqn{Y = (\beta_A + \beta_{AX} X) A + \beta_S S + \beta_{SX} (S X) + \epsilon_Y,}
#' with mean-zero errors independent of `(X, A)`, the cell CATEs are
#' \deqn{\tau_S(k) = \gamma_A + \gamma_{AX} k,}
#' \deqn{\tau_Y(k) = (\beta_A + \beta_{AX} k) + (\beta_S + \beta_{SX} k)
#'                   (\gamma_A + \gamma_{AX} k).}
#'
#' These depend only on the DGP's **mean structure**, not on the error law and
#' not on the treatment-assignment mechanism. In particular they are identical
#' for the randomized (`A ~ Bernoulli(0.5)`) and the confounded
#' (`A ~ Bernoulli(e(X))`) versions of the same parameter set, which is what
#' makes the confounded DGPs of [confounded_dgp_params()] a clean test: the
#' target `rho_true` is unchanged, only the estimator's requirements change.
#'
#' @param params Named list of canonical coefficients (see [generate_dgp_data()]).
#' @param X_levels Numeric vector of covariate values.
#'
#' @return A list with numeric vectors `tau_S` and `tau_Y`, each of length
#'   `length(X_levels)`.
#'
#' @seealso [true_rho_from_cates()], [iw_limit_from_cates()]
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' canonical_cates(spec$params, spec$X_levels)
#'
#' @export
canonical_cates <- function(params, X_levels) {
  required <- c("gamma_A", "gamma_AX", "beta_A", "beta_AX", "beta_S", "beta_SX")
  missing <- setdiff(required, names(params))
  if (length(missing) > 0) {
    stop("`params` is missing: ", paste(missing, collapse = ", "), ".")
  }
  if (!is.numeric(X_levels) || length(X_levels) == 0) {
    stop("`X_levels` must be a non-empty numeric vector.")
  }

  tau_S <- params$gamma_A + params$gamma_AX * X_levels
  tau_Y <- (params$beta_A + params$beta_AX * X_levels) +
    (params$beta_S + params$beta_SX * X_levels) * tau_S

  list(tau_S = tau_S, tau_Y = tau_Y)
}


#' Across-Study Correlation from Cell CATEs
#'
#' Computes the estimand
#' `Theta = cor_mu(Delta_S(Q), Delta_Y(Q))` targeted by
#' [tv_ball_correlation_IF_adaptive()], given the DGP's cell CATEs.
#'
#' @details
#' Per-study effects on finite covariate support are linear in the study measure,
#' `Delta_S(Q) = sum_k q_k tau_S(k)` and `Delta_Y(Q) = sum_k q_k tau_Y(k)`, so the
#' estimand depends on the DGP only through the cell CATEs — not through the
#' error law and not through the sample size. Given `Q`-draws from the ball the
#' value is therefore exact up to Monte Carlo error in the draws, which is driven
#' down by increasing `M_ref`. Run-to-run variation is on the order of 0.001 at
#' `M_ref = 2e4` and below 0.001 at `M_ref = 1e5`.
#'
#' Run time: roughly linear in `M_ref * thin`; `M_ref = 1e5` with `thin = 20`
#' takes on the order of a minute for `K = 5`, so callers that need many specs
#' should cache the result rather than recompute it.
#'
#' @param tau_S,tau_Y Numeric vectors of cell CATEs, same length as `p_X`.
#' @param p_X Numeric vector of reference covariate probabilities (the ball
#'   centre); must sum to 1.
#' @param lambda TV-ball radius.
#' @param M_ref Number of `Q`-draws (default `20000`).
#' @param burn_in,thin Hit-and-run MCMC tuning (defaults `2000`, `20`).
#' @param seed Integer seed, set once inside the function so the returned value
#'   is reproducible.
#'
#' @return A list with `rho_true`, `mean_dS`, `sd_dS`, `mean_dY`, `sd_dY`,
#'   `M_ref`.
#'
#' @seealso [canonical_cates()], [iw_limit_from_cates()]
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' cc <- canonical_cates(spec$params, spec$X_levels)
#' # small M_ref for a fast example; use >= 20000 for reportable values
#' true_rho_from_cates(cc$tau_S, cc$tau_Y, spec$p_X, spec$lambda, M_ref = 500)$rho_true
#'
#' @export
true_rho_from_cates <- function(tau_S, tau_Y, p_X, lambda,
                                M_ref = 20000L, burn_in = 2000L, thin = 20L,
                                seed = 20260713L) {
  .check_cate_inputs(tau_S, tau_Y, p_X)
  if (!is.numeric(lambda) || length(lambda) != 1 || lambda <= 0) {
    stop("`lambda` must be a single positive number.")
  }
  set.seed(seed)

  Q <- sample_tv_ball(P0 = p_X, lambda = lambda, M = M_ref,
                      burn_in = burn_in, thin = thin, verbose = FALSE)

  dS <- as.numeric(Q %*% tau_S)
  dY <- as.numeric(Q %*% tau_Y)

  list(
    rho_true = stats::cor(dS, dY),
    mean_dS = mean(dS), sd_dS = stats::sd(dS),
    mean_dY = mean(dY), sd_dY = stats::sd(dY),
    M_ref = M_ref
  )
}


#' Population Limit of the Importance-Weighting Correlation Under Confounding
#'
#' Computes what the importance-weighting (randomized-trial) path of
#' [tv_ball_correlation_IF_adaptive()] converges to when treatment assignment
#' actually depends on the covariate, `A | X = k ~ Bernoulli(e_k)`.
#'
#' @details
#' The importance-weighting estimator forms Hajek-weighted arm means with weights
#' `w_i = q_{k_i} / p_{0, k_i}`, which do **not** adjust for treatment selection.
#' In the canonical DGP the control arm has mean zero for both `S` and `Y`, so its
#' per-study surrogate effect converges to the **propensity-tilted** effect
#' \deqn{\Delta_S^{IW}(Q) = \frac{\sum_k q_k e_k \tau_S(k)}{\sum_k q_k e_k},}
#' and likewise for `Y`. The importance-weighting estimand is therefore
#' `cor_mu(Delta_S^IW(Q), Delta_Y^IW(Q))`, which differs from the target
#' `cor_mu(Delta_S(Q), Delta_Y(Q))` whenever `e_k` varies with `k`. The gap this
#' function returns is the asymptotic bias that cross-fitted AIPW removes.
#'
#' When `e_k` is constant the tilt cancels and this returns the target value, so
#' the function doubles as a consistency check on the randomized DGPs.
#'
#' @param tau_S,tau_Y Numeric vectors of cell CATEs.
#' @param e Numeric vector of cell propensities `P(A = 1 | X = k)`, in `(0, 1)`.
#' @param p_X Numeric vector of reference covariate probabilities; must sum to 1.
#' @param lambda TV-ball radius.
#' @param M_ref,burn_in,thin,seed As in [true_rho_from_cates()].
#'
#' @return A list with `rho_iw_limit` (the importance-weighting estimand),
#'   `rho_true` (the target estimand, computed from the same `Q`-draws), `bias`
#'   (`rho_iw_limit - rho_true`), and `M_ref`.
#'
#' @seealso [confounded_dgp_params()], [true_rho_from_cates()]
#'
#' @examples
#' spec <- confounded_dgp_params("conf1")
#' cc <- canonical_cates(spec$params, spec$X_levels)
#' e <- stats::plogis(spec$e_int + spec$e_coef * spec$X_levels)
#' iw_limit_from_cates(cc$tau_S, cc$tau_Y, e, spec$p_X, spec$lambda, M_ref = 500)$bias
#'
#' @export
iw_limit_from_cates <- function(tau_S, tau_Y, e, p_X, lambda,
                                M_ref = 20000L, burn_in = 2000L, thin = 20L,
                                seed = 20260713L) {
  .check_cate_inputs(tau_S, tau_Y, p_X)
  if (length(e) != length(p_X)) {
    stop("`e` must have the same length as `p_X`.")
  }
  if (any(e <= 0 | e >= 1)) {
    stop("`e` must lie strictly inside (0, 1).")
  }
  set.seed(seed)

  Q <- sample_tv_ball(P0 = p_X, lambda = lambda, M = M_ref,
                      burn_in = burn_in, thin = thin, verbose = FALSE)

  # Target: per-study effects average the CATEs under Q.
  dS <- as.numeric(Q %*% tau_S)
  dY <- as.numeric(Q %*% tau_Y)

  # Importance-weighting limit: the e-tilted effects (treated-arm Hajek mean over
  # a control arm whose mean is zero); see Details.
  den   <- as.numeric(Q %*% e)
  dS_iw <- as.numeric(Q %*% (e * tau_S)) / den
  dY_iw <- as.numeric(Q %*% (e * tau_Y)) / den

  rho_true <- stats::cor(dS, dY)
  rho_iw   <- stats::cor(dS_iw, dY_iw)

  list(rho_iw_limit = rho_iw, rho_true = rho_true,
       bias = rho_iw - rho_true, M_ref = M_ref)
}


# Shared input validation for the CATE-based truth utilities.
.check_cate_inputs <- function(tau_S, tau_Y, p_X) {
  if (!is.numeric(tau_S) || !is.numeric(tau_Y) || !is.numeric(p_X)) {
    stop("`tau_S`, `tau_Y` and `p_X` must all be numeric vectors.")
  }
  if (length(tau_S) != length(p_X) || length(tau_Y) != length(p_X)) {
    stop("`tau_S` and `tau_Y` must have the same length as `p_X`.")
  }
  if (abs(sum(p_X) - 1) > 1e-8) {
    stop("`p_X` must sum to 1 (current sum: ", sum(p_X), ").")
  }
  invisible(TRUE)
}
