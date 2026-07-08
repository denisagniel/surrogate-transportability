#' Compute correlation functional between treatment effects
#'
#' Calculates the correlation between treatment effects on surrogate and outcome
#' across future studies, the primary functional for evaluating surrogate
#' transportability.
#'
#' @param treatment_effects A data frame with columns `delta_s` and `delta_y`
#'   containing treatment effects from multiple future studies. Each row is one
#'   study with its average treatment effects \eqn{\Delta_S(Q)} and
#'   \eqn{\Delta_Y(Q)}.
#' @param method Character. Correlation method: "pearson" (default), "spearman",
#'   or "kendall".
#'
#' @return Numeric. The correlation between treatment effects across studies.
#'
#' @details
#' This implements the functional \eqn{\phi(\mu) = \mathrm{cor}_\mu(\Delta_S(Q),
#' \Delta_Y(Q))} where \eqn{Q \sim \mu}. It is an **across-study** functional:
#' each row is one future study with scalar study-level effects, and the
#' correlation is computed across (between) the studies. A high correlation
#' indicates the surrogate transports well across the sampled future studies.
#'
#' For inference (confidence intervals via the influence function), use
#' [tv_ball_correlation_IF_adaptive()], which estimates this functional together
#' with a standard error over a TV ball of future studies.
#'
#' @examples
#' te <- data.frame(delta_s = rnorm(50, 0.3, 0.2), delta_y = rnorm(50, 0.4, 0.2))
#' functional_correlation(te)
#'
#' @export
functional_correlation <- function(treatment_effects,
                                    method = c("pearson", "spearman", "kendall")) {

  method <- match.arg(method)

  # Helpful error if raw study data is passed by mistake.
  if (all(c("A", "S", "Y") %in% names(treatment_effects)) &&
      !all(c("delta_s", "delta_y") %in% names(treatment_effects))) {
    stop(
      "functional_correlation() expects treatment-effect PAIRS (delta_s, delta_y), ",
      "not raw study data (A, S, Y). This is an across-study functional."
    )
  }

  if (!all(c("delta_s", "delta_y") %in% names(treatment_effects))) {
    stop("`treatment_effects` must contain columns 'delta_s' and 'delta_y'.")
  }

  stats::cor(treatment_effects$delta_s, treatment_effects$delta_y, method = method)
}
