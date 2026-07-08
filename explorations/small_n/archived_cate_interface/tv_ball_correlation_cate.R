# =============================================================================
# tv_ball_correlation_cate.R -- across-study correlation with a pluggable CATE
# estimator (for improved small-sample / general-DGP CATE estimation).
# =============================================================================
# This is a SEPARATE entry point from tv_ball_correlation_IF_adaptive(): that
# function is the canonical estimator with validated influence-function
# inference for the reweighting path, and is unchanged. This function lets a user
# plug in a data-adaptive CATE estimator (e.g. a causal forest) for the cell-level
# treatment effects, which reduces small-n attenuation of the correlation and
# generalizes to CATE shapes a fixed model cannot capture.
#
# The estimand is identical: Theta = cor_mu(Delta_S(Q), Delta_Y(Q)) over Q
# uniform on the TV ball. In closed form, given cell CATE vectors tau_S, tau_Y and
# the sampler covariance Sigma_q = Cov_mu(q),
#     Theta = (tau_S' Sigma_q tau_Y) / sqrt((tau_S' Sigma_q tau_S)(tau_Y' Sigma_q tau_Y)).
# We sample Sigma_q once and plug in CATEs from the chosen estimator.

#' Across-study surrogate correlation with a pluggable CATE estimator
#'
#' Estimates the across-study correlation of treatment effects,
#' \eqn{\Theta = \mathrm{cor}_\mu(\Delta_S(Q), \Delta_Y(Q))} over \eqn{Q} uniform
#' on the total-variation ball \eqn{U(P_0, \lambda)}, using a user-selectable
#' estimator for the cell-level conditional average treatment effects (CATEs).
#'
#' @details
#' The canonical [tv_ball_correlation_IF_adaptive()] estimates cell effects by
#' reweighting (with influence-function inference). This function instead plugs
#' the cell CATE vectors from `cate` into the closed-form correlation, which can
#' substantially reduce small-sample attenuation of \eqn{\Theta} and adapt to
#' CATE shapes a reweighting/fixed model cannot capture.
#'
#' The surrogate and outcome CATEs are estimated **separately** (the structural
#' safeguard against manufacturing correlation; see [cate_estimator()]).
#'
#' **Inference.** Two SE options beyond `"none"`:
#' \describe{
#'   \item{`"if"`}{Influence-function SE in the cell-CATE parameterization:
#'     \eqn{\mathrm{SE} = \sqrt{g^\top V g}} with \eqn{g = \nabla\Theta} (analytic)
#'     and \eqn{V} the joint covariance of the cell CATEs assembled from the
#'     estimator's per-observation influence matrices, **including the
#'     cross-outcome block** (surrogate and outcome errors are correlated within a
#'     cell). Requires the CATE estimator to return `if_mat` for both outcomes
#'     (the `"saturated"` built-in does; `"grf"` does not). See the exploration
#'     derivation for validation.}
#'   \item{`"bootstrap"`}{Nonparametric bootstrap over observations; works for any
#'     estimator.}
#' }
#' Note the canonical [tv_ball_correlation_IF_adaptive()] IF-SE (reweighting path)
#' is a different derivation and is not reused here.
#'
#' @param data Data frame with columns `X`, `A` (0/1), `S`, `Y`.
#' @param lambda TV-ball radius.
#' @param cate A CATE estimator: a string passed to [cate_estimator()]
#'   (`"saturated"` or `"grf"`), or a function with the contract
#'   `function(y, A, X, x_eval) -> list(tau, var)`.
#' @param x_eval Values of `X` at which to evaluate the CATEs. Defaults to the
#'   sorted unique values of `data$X` (appropriate for discrete/few-level `X`).
#' @param disattenuate Logical; if `TRUE` and per-cell variances are available,
#'   apply an (experimental) measurement-error correction to the correlation
#'   denominator. Off by default. Returns `NA` if the correction over-shoots.
#' @param se One of `"none"` (default), `"if"` (influence-function; requires the
#'   CATE estimator to supply `if_mat`), or `"bootstrap"`.
#' @param B Bootstrap replicates when `se = "bootstrap"` (default 200).
#' @param M,burn_in,thin Hit-and-run MCMC settings for sampling the TV ball.
#' @param alpha Significance level for the confidence interval (default 0.05).
#' @param verbose Print progress?
#'
#' @return A list with `rho_hat`, `se`, `ci_lower`, `ci_upper`, `se_type`,
#'   `cate`, `disattenuate`, and `K` (number of cells).
#'
#' @seealso [tv_ball_correlation_IF_adaptive()] (canonical, IF inference);
#'   [cate_estimator()] (built-in CATE estimators).
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' d <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)
#' # saturated (per-cell) CATE, no SE
#' tv_ball_correlation_cate(d, lambda = 0.3, cate = "saturated", verbose = FALSE)$rho_hat
#'
#' @export
tv_ball_correlation_cate <- function(data, lambda,
                                     cate = "saturated",
                                     x_eval = NULL,
                                     disattenuate = FALSE,
                                     se = c("none", "if", "bootstrap"),
                                     B = 200L,
                                     M = 800L, burn_in = 200L, thin = 5L,
                                     alpha = 0.05,
                                     verbose = FALSE) {
  se <- match.arg(se)
  required <- c("X", "A", "S", "Y")
  if (!all(required %in% names(data))) {
    stop("`data` must contain columns X, A, S, Y.", call. = FALSE)
  }
  if (!all(data$A %in% c(0, 1))) stop("Treatment A must be binary (0/1).", call. = FALSE)

  cate_fn <- if (is.function(cate)) cate else cate_estimator(cate)
  cate_label <- if (is.function(cate)) "user" else cate

  if (is.null(x_eval)) x_eval <- sort(unique(data$X))
  K <- length(x_eval)

  # Sampler covariance Sigma_q on the empirical cell distribution (sampled once).
  P0 <- as.numeric(table(factor(data$X, levels = x_eval))) / nrow(data)
  Q <- sample_tv_ball(P0, lambda = lambda, M = M, burn_in = burn_in,
                      thin = thin, verbose = FALSE)
  Sigma <- stats::cov(Q)

  point <- function(d) {
    cS <- cate_fn(d$S, d$A, d$X, x_eval)
    cY <- cate_fn(d$Y, d$A, d$X, x_eval)
    if (disattenuate && all(is.finite(c(cS$var, cY$var)))) {
      .rho_disattenuated(cS$tau, cY$tau, cS$var, cY$var, Sigma)
    } else {
      .rho_from_cate(cS$tau, cY$tau, Sigma)
    }
  }

  rho_hat <- point(data)

  se_val <- NA_real_; ci_lower <- NA_real_; ci_upper <- NA_real_
  se_type <- "none"
  if (se == "if") {
    cS <- cate_fn(data$S, data$A, data$X, x_eval)
    cY <- cate_fn(data$Y, data$A, data$X, x_eval)
    if (is.null(cS$if_mat) || is.null(cY$if_mat)) {
      stop("se = 'if' requires the CATE estimator to return `if_mat` for both ",
           "outcomes; '", cate_label, "' does not. Use se = 'bootstrap'.",
           call. = FALSE)
    }
    g <- .grad_theta(cS$tau, cY$tau, Sigma)                # analytic gradient
    V <- stats::cov(cbind(cS$if_mat, cY$if_mat)) / nrow(data)  # incl cross-outcome block
    var_theta <- as.numeric(t(g) %*% V %*% g)
    if (is.finite(var_theta) && var_theta > 0) {
      se_val <- sqrt(var_theta)
      z <- stats::qnorm(1 - alpha / 2)
      ci_lower <- rho_hat - z * se_val; ci_upper <- rho_hat + z * se_val
    }
    se_type <- "influence-function"
  } else if (se == "bootstrap") {
    n <- nrow(data)
    boot <- vapply(seq_len(B), function(b) {
      idx <- sample.int(n, n, replace = TRUE)
      tryCatch(point(data[idx, , drop = FALSE]), error = function(e) NA_real_)
    }, numeric(1))
    boot <- boot[is.finite(boot)]
    if (length(boot) >= 2) {
      se_val <- stats::sd(boot)
      qs <- stats::quantile(boot, c(alpha / 2, 1 - alpha / 2), names = FALSE)
      ci_lower <- qs[1]; ci_upper <- qs[2]
    }
    se_type <- sprintf("bootstrap(B=%d, eff=%d)", B, length(boot))
  }

  if (verbose) {
    message(sprintf("tv_ball_correlation_cate: cate=%s, K=%d, rho_hat=%.4f%s",
                    cate_label, K, rho_hat,
                    if (se == "bootstrap") sprintf(", se=%.4f", se_val) else ""))
  }

  list(rho_hat = rho_hat, se = se_val, ci_lower = ci_lower, ci_upper = ci_upper,
       se_type = se_type, cate = cate_label, disattenuate = disattenuate, K = K)
}

# --- internal: analytic gradient of Theta wrt (tau_S, tau_Y) given Sigma ------
# Returns the 2K-vector (dTheta/dtau_S ; dTheta/dtau_Y). See IF_SE_derivation.md.
.grad_theta <- function(tS, tY, Sigma) {
  num <- as.numeric(t(tS) %*% Sigma %*% tY)
  a   <- as.numeric(t(tS) %*% Sigma %*% tS)
  b   <- as.numeric(t(tY) %*% Sigma %*% tY)
  gS <- (Sigma %*% tY - (num / a) * (Sigma %*% tS)) / sqrt(a * b)
  gY <- (Sigma %*% tS - (num / b) * (Sigma %*% tY)) / sqrt(a * b)
  c(as.numeric(gS), as.numeric(gY))
}

# --- internal: closed-form correlation from cell CATEs + Sigma_q -------------
.rho_from_cate <- function(tS, tY, Sigma) {
  if (anyNA(tS) || anyNA(tY)) return(NA_real_)
  num <- as.numeric(t(tS) %*% Sigma %*% tY)
  dS  <- as.numeric(t(tS) %*% Sigma %*% tS)
  dY  <- as.numeric(t(tY) %*% Sigma %*% tY)
  if (!is.finite(dS) || !is.finite(dY) || dS <= 0 || dY <= 0) return(NA_real_)
  num / sqrt(dS * dY)
}

# Experimental measurement-error (disattenuation) correction: subtract the
# expected estimation-noise contribution sum(diag(Sigma) * var) from each
# denominator quadratic form. Returns NA if the correction over-shoots (a known
# small-n failure mode). The numerator cross-noise term is assumed ~0.
.rho_disattenuated <- function(tS, tY, vS, vY, Sigma) {
  if (anyNA(tS) || anyNA(tY) || anyNA(vS) || anyNA(vY)) return(NA_real_)
  d <- diag(Sigma)
  num <- as.numeric(t(tS) %*% Sigma %*% tY)
  dS  <- as.numeric(t(tS) %*% Sigma %*% tS) - sum(d * vS)
  dY  <- as.numeric(t(tY) %*% Sigma %*% tY) - sum(d * vY)
  if (!is.finite(dS) || !is.finite(dY) || dS <= 0 || dY <= 0) return(NA_real_)
  num / sqrt(dS * dY)
}
