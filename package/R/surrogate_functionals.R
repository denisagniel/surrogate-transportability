#' Compute correlation functional between treatment effects
#'
#' Calculates the correlation between treatment effects on surrogate and outcome
#' across future studies, which is a key functional for evaluating surrogate quality.
#'
#' @param treatment_effects A tibble with columns delta_s and delta_y containing
#'   treatment effects from multiple future studies.
#' @param method Character. Correlation method: "pearson" (default), "spearman", or "kendall".
#'
#' @return Numeric. The correlation between treatment effects.
#'
#' @details
#' This implements the functional φ(F) = cor(ΔS(Q), ΔY(Q)) where Q ~ F.
#' A high correlation indicates that the surrogate marker is informative about
#' the treatment effect on the outcome across different studies.
#'
#' @examples
#' # Generate treatment effects from future studies
#' current_data <- generate_study_data(n = 500)
#' future_studies <- generate_multiple_future_studies(current_data, n_future_studies = 100)
#' treatment_effects <- extract_treatment_effects(future_studies)
#'
#' # Compute correlation functional
#' correlation <- functional_correlation(treatment_effects)
#'
#' @export
functional_correlation <- function(treatment_effects, 
                                 method = c("pearson", "spearman", "kendall")) {
  
  method <- match.arg(method)
  
  if (!all(c("delta_s", "delta_y") %in% names(treatment_effects))) {
    stop("treatment_effects must contain columns 'delta_s' and 'delta_y'")
  }
  
  cor(treatment_effects$delta_s, treatment_effects$delta_y, method = method)
}

#' Compute probability functional
#'
#' Calculates the probability that a non-small treatment effect on the surrogate
#' implies a non-small treatment effect on the outcome.
#'
#' @param treatment_effects A tibble with columns delta_s and delta_y.
#' @param epsilon_s Numeric. Threshold for "non-small" surrogate effect.
#' @param epsilon_y Numeric. Threshold for "non-small" outcome effect.
#'
#' @return Numeric. The conditional probability P(ΔY > εY | ΔS > εS).
#'
#' @details
#' This implements the functional:
#' φ(F; εS, εY) = E_F[I{ΔS(Q) > εS, ΔY(Q) > εY}] / E_F[I{ΔS(Q) > εS}]
#'
#' This measures the probability that a meaningful treatment effect on the
#' surrogate translates to a meaningful treatment effect on the outcome.
#'
#' @examples
#' # Generate treatment effects
#' current_data <- generate_study_data(n = 500)
#' future_studies <- generate_multiple_future_studies(current_data, n_future_studies = 100)
#' treatment_effects <- extract_treatment_effects(future_studies)
#'
#' # Compute probability functional
#' prob <- functional_probability(treatment_effects, epsilon_s = 0.2, epsilon_y = 0.1)
#'
#' @export
functional_probability <- function(treatment_effects, epsilon_s, epsilon_y) {
  
  if (!all(c("delta_s", "delta_y") %in% names(treatment_effects))) {
    stop("treatment_effects must contain columns 'delta_s' and 'delta_y'")
  }
  
  # Indicator for non-small surrogate effect
  large_s_effect <- treatment_effects$delta_s > epsilon_s
  
  # Check if any studies have non-small surrogate effects
  if (sum(large_s_effect) == 0) {
    warning("No studies with delta_s > ", epsilon_s, ". Returning NA.")
    return(NA_real_)
  }
  
  # Conditional probability
  numerator <- sum(treatment_effects$delta_s > epsilon_s & 
                   treatment_effects$delta_y > epsilon_y)
  denominator <- sum(large_s_effect)
  
  numerator / denominator
}

#' Compute conditional mean functional
#'
#' Calculates the expected outcome treatment effect given a specific
#' surrogate treatment effect.
#'
#' @param treatment_effects A tibble with columns delta_s and delta_y.
#' @param delta_s_value Numeric. The specific surrogate treatment effect value.
#' @param bandwidth Numeric. Bandwidth for local averaging. If NULL, uses
#'   Silverman's rule of thumb.
#' @param method Character. Method for conditional mean: "local_linear" or "kernel".
#'
#' @return Numeric. The expected outcome treatment effect E[ΔY | ΔS = δ].
#'
#' @details
#' This implements the functional φ(F; δ) = E_F[ΔY(Q) | ΔS(Q) = δ].
#' This provides the expected outcome treatment effect for a given
#' surrogate treatment effect value.
#'
#' @examples
#' # Generate treatment effects
#' current_data <- generate_study_data(n = 500)
#' future_studies <- generate_multiple_future_studies(current_data, n_future_studies = 100)
#' treatment_effects <- extract_treatment_effects(future_studies)
#'
#' # Compute conditional mean for specific surrogate effect
#' conditional_mean <- functional_conditional_mean(treatment_effects, delta_s_value = 0.5)
#'
#' @export
functional_conditional_mean <- function(treatment_effects,
                                      delta_s_value,
                                      bandwidth = NULL,
                                      method = c("local_linear", "kernel")) {
  
  method <- match.arg(method)
  
  if (!all(c("delta_s", "delta_y") %in% names(treatment_effects))) {
    stop("treatment_effects must contain columns 'delta_s' and 'delta_y'")
  }
  
  delta_s <- treatment_effects$delta_s
  delta_y <- treatment_effects$delta_y
  
  # Set default bandwidth using Silverman's rule of thumb
  if (is.null(bandwidth)) {
    n <- length(delta_s)
    bandwidth <- 1.06 * sd(delta_s) * n^(-1/5)
  }
  
  switch(method,
    "kernel" = {
      # Kernel-weighted average
      weights <- dnorm((delta_s - delta_s_value) / bandwidth)
      if (sum(weights) == 0) {
        warning("No observations near delta_s = ", delta_s_value, ". Returning NA.")
        return(NA_real_)
      }
      sum(weights * delta_y) / sum(weights)
    },
    
    "local_linear" = {
      # Local linear regression
      weights <- dnorm((delta_s - delta_s_value) / bandwidth)
      if (sum(weights) == 0) {
        warning("No observations near delta_s = ", delta_s_value, ". Returning NA.")
        return(NA_real_)
      }
      
      # Weighted least squares
      X <- cbind(1, delta_s - delta_s_value)
      W <- diag(weights)
      
      tryCatch({
        beta <- solve(t(X) %*% W %*% X) %*% t(X) %*% W %*% delta_y
        beta[1]  # Intercept (value at delta_s_value)
      }, error = function(e) {
        warning("Local linear regression failed. Using kernel method.")
        sum(weights * delta_y) / sum(weights)
      })
    }
  )
}

#' Compute all surrogate functionals
#'
#' Convenience function to compute all three main surrogate functionals
#' simultaneously.
#'
#' @param treatment_effects A tibble with columns delta_s and delta_y.
#' @param epsilon_s Numeric. Threshold for probability functional.
#' @param epsilon_y Numeric. Threshold for probability functional.
#' @param delta_s_values Numeric vector. Values for conditional mean functional.
#' @param correlation_method Character. Method for correlation.
#' @param conditional_method Character. Method for conditional mean.
#'
#' @return A list with elements:
#'   \item{correlation}{Correlation between treatment effects}
#'   \item{probability}{Conditional probability}
#'   \item{conditional_means}{Conditional means for specified delta_s_values}
#'
#' @examples
#' # Generate treatment effects
#' current_data <- generate_study_data(n = 500)
#' future_studies <- generate_multiple_future_studies(current_data, n_future_studies = 100)
#' treatment_effects <- extract_treatment_effects(future_studies)
#'
#' # Compute all functionals
#' functionals <- compute_all_functionals(
#'   treatment_effects,
#'   epsilon_s = 0.2,
#'   epsilon_y = 0.1,
#'   delta_s_values = c(0.3, 0.5, 0.7)
#' )
#'
#' @export
compute_all_functionals <- function(treatment_effects,
                                  epsilon_s = 0.2,
                                  epsilon_y = 0.1,
                                  delta_s_values = c(0.3, 0.5, 0.7),
                                  correlation_method = c("pearson", "spearman", "kendall"),
                                  conditional_method = c("local_linear", "kernel")) {
  
  correlation_method <- match.arg(correlation_method)
  conditional_method <- match.arg(conditional_method)
  
  # Correlation functional
  correlation <- functional_correlation(treatment_effects, method = correlation_method)
  
  # Probability functional
  probability <- functional_probability(treatment_effects, epsilon_s, epsilon_y)
  
  # Conditional mean functionals
  conditional_means <- purrr::map_dbl(delta_s_values, function(delta_s_val) {
    functional_conditional_mean(
      treatment_effects, 
      delta_s_val, 
      method = conditional_method
    )
  })
  names(conditional_means) <- paste0("delta_s_", delta_s_values)
  
  list(
    correlation = correlation,
    probability = probability,
    conditional_means = conditional_means,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y,
    delta_s_values = delta_s_values
  )
}

#' Compute functional with uncertainty quantification
#'
#' Computes surrogate functionals with bootstrap confidence intervals
#' for uncertainty quantification.
#'
#' @param treatment_effects A tibble with columns delta_s and delta_y.
#' @param functional_type Character. Type of functional: "correlation", "probability", or "conditional_mean".
#' @param n_bootstrap Integer. Number of bootstrap samples.
#' @param confidence_level Numeric. Confidence level for intervals.
#' @param ... Additional arguments passed to the specific functional.
#'
#' @return A list with elements:
#'   \item{estimate}{Point estimate}
#'   \item{se}{Standard error}
#'   \item{ci_lower}{Lower confidence bound}
#'   \item{ci_upper}{Upper confidence bound}
#'   \item{bootstrap_samples}{Bootstrap samples}
#'
#' @examples
#' # Generate treatment effects
#' current_data <- generate_study_data(n = 500)
#' future_studies <- generate_multiple_future_studies(current_data, n_future_studies = 100)
#' treatment_effects <- extract_treatment_effects(future_studies)
#'
#' # Compute correlation with CI
#' correlation_ci <- compute_functional_with_ci(
#'   treatment_effects, 
#'   "correlation", 
#'   n_bootstrap = 1000
#' )
#'
#' @export
compute_functional_with_ci <- function(treatment_effects,
                                     functional_type = c("correlation", "probability", "conditional_mean"),
                                     n_bootstrap = 1000,
                                     confidence_level = 0.95,
                                     ...) {
  
  functional_type <- match.arg(functional_type)
  
  # Point estimate
  point_estimate <- switch(functional_type,
    "correlation" = functional_correlation(treatment_effects, ...),
    "probability" = functional_probability(treatment_effects, ...),
    "conditional_mean" = functional_conditional_mean(treatment_effects, ...)
  )
  
  # Bootstrap samples
  n <- nrow(treatment_effects)
  bootstrap_estimates <- numeric(n_bootstrap)
  
  for (i in 1:n_bootstrap) {
    # Bootstrap sample
    bootstrap_indices <- sample(1:n, size = n, replace = TRUE)
    bootstrap_treatment_effects <- treatment_effects[bootstrap_indices, ]
    
    # Compute functional on bootstrap sample
    bootstrap_estimates[i] <- switch(functional_type,
      "correlation" = functional_correlation(bootstrap_treatment_effects, ...),
      "probability" = functional_probability(bootstrap_treatment_effects, ...),
      "conditional_mean" = functional_conditional_mean(bootstrap_treatment_effects, ...)
    )
  }
  
  # Compute confidence interval
  alpha <- 1 - confidence_level
  ci_lower <- quantile(bootstrap_estimates, alpha/2, na.rm = TRUE)
  ci_upper <- quantile(bootstrap_estimates, 1 - alpha/2, na.rm = TRUE)
  se <- sd(bootstrap_estimates, na.rm = TRUE)
  
  list(
    estimate = point_estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    bootstrap_samples = bootstrap_estimates
  )
}


