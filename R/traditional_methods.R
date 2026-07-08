#' Traditional Surrogate Evaluation Methods
#'
#' Implements traditional methods for evaluating surrogate markers, including
#' proportion of treatment effect (PTE), within-study correlation, and mediation.
#'
#' @name traditional_methods
NULL

#' Compute proportion of treatment effect (PTE)
#'
#' Calculates the proportion of treatment effect on the outcome that is
#' explained by the treatment effect on the surrogate.
#'
#' @param data Tibble with columns A (treatment), S (surrogate), Y (outcome)
#' @param adjust_covariates Logical. Whether to adjust for covariates. Default: TRUE.
#' @return Numeric. The PTE estimate.
#'
#' @details
#' PTE is defined as:
#'   PTE = [E[Y|A=1] - E[Y|A=0] - (E[Y|A=1,S] - E[Y|A=0,S])] / [E[Y|A=1] - E[Y|A=0]]
#'
#' Equivalently:
#'   PTE = (Total effect - Direct effect) / Total effect
#'       = Indirect effect / Total effect
#'
#' A high PTE (> 0.6) is often interpreted as the surrogate capturing most of
#' the treatment effect, suggesting good surrogate properties.
#'
#' **Limitation:** PTE is a within-study measure and may not reflect how well
#' the surrogate transports across studies.
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' data <- generate_dgp_data(500, spec$params, spec$p_X, spec$X_levels)
#' pte <- compute_pte(data)
#'
#' @export
compute_pte <- function(data, adjust_covariates = TRUE) {
  if (!all(c("A", "S", "Y") %in% names(data))) {
    stop("data must contain columns A, S, and Y")
  }

  # Total treatment effect: E[Y|A=1] - E[Y|A=0]
  total_effect <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])

  if (abs(total_effect) < 1e-10) {
    warning("Total treatment effect is near zero. PTE undefined.")
    return(NA_real_)
  }

  # Controlled direct effect: adjust for surrogate
  if (adjust_covariates && "X" %in% names(data)) {
    # Regression adjusting for S and X
    model_adjusted <- lm(Y ~ A + S + X, data = data)
    direct_effect <- coef(model_adjusted)["A"]
  } else {
    # Simple adjustment for S only
    model_adjusted <- lm(Y ~ A + S, data = data)
    direct_effect <- coef(model_adjusted)["A"]
  }

  # PTE = (Total - Direct) / Total = Indirect / Total
  pte <- (total_effect - direct_effect) / total_effect

  as.numeric(pte)
}


#' Compute within-study correlation
#'
#' Calculates the correlation between surrogate and outcome in observed data.
#'
#' @param data Tibble with columns S (surrogate) and Y (outcome)
#' @param method Character. Correlation method: "pearson", "spearman", or "kendall"
#' @param adjust_treatment Logical. Whether to compute correlation separately by treatment. Default: FALSE.
#' @return Numeric. The within-study correlation.
#'
#' @details
#' Within-study correlation measures the association between S and Y in the
#' current study. A high correlation (> 0.5) suggests S is associated with Y.
#'
#' **Limitation:** High within-study correlation can arise from:
#' - True surrogate relationship (good)
#' - Confounding (bad - spurious association)
#' - Both S and Y responding to treatment (not necessarily predictive)
#'
#' Traditional methods often use cor(S, Y) > 0.5 as a threshold for "good" surrogate.
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' data <- generate_dgp_data(500, spec$params, spec$p_X, spec$X_levels)
#' cor_within <- compute_within_study_correlation(data)
#'
#' @export
compute_within_study_correlation <- function(data,
                                             method = c("pearson", "spearman", "kendall"),
                                             adjust_treatment = FALSE) {
  if (!all(c("S", "Y") %in% names(data))) {
    stop("data must contain columns S and Y")
  }

  method <- match.arg(method)

  if (adjust_treatment && "A" %in% names(data)) {
    # Compute correlation within treatment arms and average
    cor_treated <- cor(data$S[data$A == 1], data$Y[data$A == 1], method = method)
    cor_control <- cor(data$S[data$A == 0], data$Y[data$A == 0], method = method)
    return((cor_treated + cor_control) / 2)
  } else {
    # Overall correlation
    cor(data$S, data$Y, method = method)
  }
}


#' Compute mediation effects
#'
#' Estimates indirect and direct effects using mediation analysis framework.
#'
#' @param data Tibble with columns A (treatment), S (surrogate/mediator), Y (outcome)
#' @param adjust_covariates Logical. Whether to adjust for covariates. Default: TRUE.
#' @return List with indirect effect, direct effect, total effect, and proportion mediated.
#'
#' @details
#' Mediation analysis decomposes the total treatment effect into:
#' - **Indirect effect:** Effect mediated through S
#' - **Direct effect:** Effect not mediated through S
#' - **Proportion mediated:** Indirect / Total (similar to PTE)
#'
#' Implementation uses the product-of-coefficients approach:
#' - Indirect = (effect of A on S) × (effect of S on Y)
#' - Direct = effect of A on Y controlling for S
#'
#' **Limitation:** Assumes no unmeasured confounding and sequential ignorability.
#' Proportion mediated > 0.6 often used as threshold for "good" surrogate.
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' data <- generate_dgp_data(500, spec$params, spec$p_X, spec$X_levels)
#' mediation <- compute_mediation_effects(data)
#'
#' @export
compute_mediation_effects <- function(data, adjust_covariates = TRUE) {
  if (!all(c("A", "S", "Y") %in% names(data))) {
    stop("data must contain columns A, S, and Y")
  }

  # Step 1: Effect of treatment on mediator (S)
  if (adjust_covariates && "X" %in% names(data)) {
    model_s <- lm(S ~ A + X, data = data)
  } else {
    model_s <- lm(S ~ A, data = data)
  }
  effect_a_on_s <- coef(model_s)["A"]

  # Step 2: Effect of mediator on outcome (controlling for treatment)
  if (adjust_covariates && "X" %in% names(data)) {
    model_y <- lm(Y ~ A + S + X, data = data)
  } else {
    model_y <- lm(Y ~ A + S, data = data)
  }
  effect_s_on_y <- coef(model_y)["S"]
  direct_effect <- coef(model_y)["A"]

  # Indirect effect (product of coefficients)
  indirect_effect <- effect_a_on_s * effect_s_on_y

  # Total effect
  if (adjust_covariates && "X" %in% names(data)) {
    model_total <- lm(Y ~ A + X, data = data)
  } else {
    model_total <- lm(Y ~ A, data = data)
  }
  total_effect <- coef(model_total)["A"]

  # Proportion mediated
  if (abs(total_effect) > 1e-10) {
    prop_mediated <- indirect_effect / total_effect
  } else {
    prop_mediated <- NA_real_
  }

  list(
    indirect_effect = as.numeric(indirect_effect),
    direct_effect = as.numeric(direct_effect),
    total_effect = as.numeric(total_effect),
    proportion_mediated = as.numeric(prop_mediated)
  )
}


#' Compute all traditional methods
#'
#' Convenience function to compute all traditional surrogate evaluation methods.
#'
#' @param data Data frame with columns A, S, Y (and optionally X)
#' @param adjust_covariates Logical. Whether to adjust for covariates. Default: TRUE.
#' @return List with results from all methods.
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' data <- generate_dgp_data(500, spec$params, spec$p_X, spec$X_levels)
#' traditional <- compute_all_traditional_methods(data)
#'
#' @export
compute_all_traditional_methods <- function(data, adjust_covariates = TRUE) {
  list(
    pte = compute_pte(data, adjust_covariates),
    within_study_cor = compute_within_study_correlation(data),
    mediation = compute_mediation_effects(data, adjust_covariates)
  )
}
