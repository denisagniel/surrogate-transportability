# =============================================================================
# estimators.R -- the two estimation paths compared by the confounded-aipw study
# =============================================================================
# Both arms call the SAME package estimator, tv_ball_correlation_IF_adaptive(),
# and differ only in its `method` argument and the nuisances supplied. Nothing
# about the estimator is reimplemented here, so the study cannot silently test a
# different estimator than the package ships.
#
# AIPW arm: nuisances are cross-fit ONCE per replication on the observed sample
# (crossfit_nuisances_once) and passed through the estimator's external-nuisance
# mode. Under X-transportability the nuisances are properties of P0 and do not
# depend on the sampled future study Q, so this is exact, not an approximation --
# and it avoids the estimator's internal per-Q refitting, which costs a factor of
# M and is not viable at M = 900.
# =============================================================================

#' Estimate the across-study correlation for one unit
#'
#' @param data Data frame with `X`, `A`, `S`, `Y`.
#' @param config One row of `unit_table()`; supplies `lambda` and `method`.
#' @return A list with `estimate`, `std_error`, `ci_lower`, `ci_upper`,
#'   `M_final`, `converged`, and `n_clipped` (count of cross-fit propensities that
#'   hit the estimator's 0.01/0.99 clip; `NA` for the importance-weighting arm).
#'   `n_clipped` is the positivity diagnostic for the `conf2` stress cell.
estimate <- function(data, config) {
  method <- as.character(config$method)
  lambda <- as.numeric(config$lambda)

  common <- list(
    data = data, lambda = lambda,
    M_start = M_START, M_increment = M_INCREMENT, M_max = M_MAX,
    verbose = FALSE
  )

  if (method == "importance_weighting") {
    fit <- do.call(tv_ball_correlation_IF_adaptive,
                   c(common, list(method = "importance_weighting")))
    n_clipped <- NA_integer_
  } else if (method == "aipw") {
    # Count clipping BEFORE the utility clips, so the diagnostic is not erased by
    # the fix it triggers. The utility warns on the same condition; we take the
    # count rather than the warning so it lands in the results table.
    nu <- withCallingHandlers(
      crossfit_nuisances_once(data),
      warning = function(w) {
        if (grepl("clipped", conditionMessage(w))) invokeRestart("muffleWarning")
      }
    )
    n_clipped <- sum(nu$e_hat <= 0.01 | nu$e_hat >= 0.99)

    fit <- do.call(tv_ball_correlation_IF_adaptive,
                   c(common, list(method = "aipw",
                                  e_hat = nu$e_hat,
                                  mu_1_S = nu$mu_1_S, mu_0_S = nu$mu_0_S,
                                  mu_1_Y = nu$mu_1_Y, mu_0_Y = nu$mu_0_Y)))
  } else {
    stop("Unknown method '", method,
         "'; expected \"importance_weighting\" or \"aipw\".")
  }

  list(
    estimate  = fit$rho_hat,
    std_error = fit$se,
    ci_lower  = fit$ci_lower,
    ci_upper  = fit$ci_upper,
    M_final   = fit$M_final,
    converged = isTRUE(fit$converged),
    n_clipped = as.integer(n_clipped)
  )
}
