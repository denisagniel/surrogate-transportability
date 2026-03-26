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
#' data <- generate_study_data(n = 500)
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
#' data <- generate_study_data(n = 500)
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
#' data <- generate_study_data(n = 500)
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
#' @param data Tibble with columns A, S, Y (and optionally X)
#' @param adjust_covariates Logical. Whether to adjust for covariates. Default: TRUE.
#' @return List with results from all methods.
#'
#' @examples
#' data <- generate_study_data(n = 500)
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


#' Classify transportability using traditional method
#'
#' Applies decision rule based on traditional surrogate evaluation metrics.
#'
#' @param data Tibble with study data
#' @param method Character. Which traditional method: "pte", "correlation", "mediation"
#' @param threshold Numeric. Threshold for classification. Default: 0.5 for correlation, 0.6 for PTE/mediation.
#' @param adjust_covariates Logical. For PTE and mediation. Default: TRUE.
#' @return Logical. TRUE if classified as transportable, FALSE otherwise.
#'
#' @details
#' Traditional decision rules:
#' - **Correlation:** Transportable if cor(S, Y) > 0.5
#' - **PTE:** Transportable if PTE > 0.6
#' - **Mediation:** Transportable if proportion mediated > 0.6
#'
#' These thresholds are commonly used in practice but are somewhat arbitrary.
#'
#' @examples
#' data <- generate_study_data(n = 500)
#' classify_traditional(data, method = "correlation")
#' classify_traditional(data, method = "pte")
#'
#' @export
classify_traditional <- function(data,
                                 method = c("correlation", "pte", "mediation"),
                                 threshold = NULL,
                                 adjust_covariates = TRUE) {
  method <- match.arg(method)

  # Set default thresholds
  if (is.null(threshold)) {
    threshold <- switch(method,
                       "correlation" = 0.5,
                       "pte" = 0.6,
                       "mediation" = 0.6)
  }

  # Compute metric
  metric_value <- switch(method,
    "correlation" = compute_within_study_correlation(data),
    "pte" = compute_pte(data, adjust_covariates),
    "mediation" = compute_mediation_effects(data, adjust_covariates)$proportion_mediated
  )

  # Classify
  if (is.na(metric_value)) {
    return(NA)
  }

  metric_value > threshold
}


#' Classify transportability using local geometric method
#'
#' Applies decision rule based on worst-case functional value over local geometry.
#'
#' @param data Tibble with study data including type assignments
#' @param lambda Numeric. Neighborhood size parameter
#' @param functional Character. Which functional: "concordance", "correlation"
#' @param threshold Numeric. Threshold for classification. Default: 0.5.
#' @param method Character. Method: "tv_minimax" or "wasserstein_minimax"
#' @return Logical. TRUE if classified as transportable, FALSE otherwise.
#'
#' @details
#' Local geometric decision rule:
#' - Compute worst-case functional value φ*(λ) over local geometry
#' - Classify as transportable if φ*(λ) > threshold
#'
#' This explicitly evaluates transportability by considering plausible future studies.
#'
#' **Key difference from traditional:**
#' - Traditional: Uses within-study metrics
#' - Ours: Evaluates worst-case over plausible future studies
#'
#' @examples
#' data <- generate_study_data(n = 500)
#' # Add type assignments (required)
#' data$type <- sample(1:16, nrow(data), replace = TRUE)
#' classify_local_geometric(data, lambda = 0.3, method = "tv_minimax")
#'
#' @export
classify_local_geometric <- function(data,
                                     lambda = 0.3,
                                     functional = c("concordance", "correlation"),
                                     threshold = 0.5,
                                     method = c("tv_minimax", "wasserstein_minimax")) {
  functional <- match.arg(functional)
  method <- match.arg(method)

  # Check for type assignments
  if (!"type" %in% names(data)) {
    stop("data must contain 'type' column for local geometric methods")
  }

  # Compute type-level treatment effects
  type_effects <- data %>%
    group_by(type) %>%
    summarize(
      tau_s = mean(S[A == 1]) - mean(S[A == 0]),
      tau_y = mean(Y[A == 1]) - mean(Y[A == 0]),
      n = n(),
      .groups = "drop"
    )

  # Estimate type probabilities
  pi_hat <- table(data$type) / nrow(data)

  # Compute worst-case functional
  if (method == "tv_minimax" && functional == "concordance") {
    # Use closed-form TV-ball minimax for concordance
    source(here::here("package/R/type_level_minimax.R"))
    result <- minimax_concordance_tv_ball(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = as.numeric(pi_hat),
      lambda = lambda
    )
    worst_case_value <- result$phi_star
  } else if (method == "wasserstein_minimax" && functional == "concordance") {
    # Use dual form for Wasserstein minimax
    source(here::here("package/R/wasserstein_concordance_dual.R"))
    result <- minimax_concordance_wasserstein_dual(
      tau_s = type_effects$tau_s,
      tau_y = type_effects$tau_y,
      pi_hat = as.numeric(pi_hat),
      lambda = lambda
    )
    worst_case_value <- result$phi_star
  } else {
    stop("Method-functional combination not yet implemented")
  }

  # Classify
  if (is.na(worst_case_value)) {
    return(NA)
  }

  worst_case_value > threshold
}
