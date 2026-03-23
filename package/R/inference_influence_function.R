#' Surrogate inference using influence function variance
#'
#' Implements the plug-in estimator with delta-method variance estimation
#' as described in Proposition 1 of the methods paper. This is the theoretically
#' grounded approach using influence functions rather than nested bootstrap.
#'
#' @param current_data A tibble with the current study data.
#' @param lambda Numeric value in [0,1] controlling the perturbation distance.
#' @param n_innovations Integer. Number of innovations to draw from μ (M in the paper).
#'   Default: 1000 for stable functional estimation.
#' @param functional_type Character. Type of functional to compute.
#' @param epsilon_s Numeric. Threshold for probability functional.
#' @param epsilon_y Numeric. Threshold for probability functional.
#' @param alpha Numeric. Concentration parameter for Dirichlet innovation distribution.
#'   Default: 1 (uniform).
#' @param confidence_level Numeric. Confidence level for intervals. Default: 0.95.
#' @param gradient_method Character. How to compute gradient for delta method:
#'   "numerical" (default) or "analytical" (for correlation only).
#' @param epsilon_gradient Numeric. Step size for numerical gradient. Default: 0.01
#'   (1% perturbation). Smaller values increase numerical instability due to Monte Carlo noise.
#'
#' @return A list with elements:
#'   \item{estimate}{Point estimate of φ(F_λ)}
#'   \item{se}{Standard error from delta method}
#'   \item{ci_lower}{Lower confidence limit}
#'   \item{ci_upper}{Upper confidence limit}
#'   \item{gradient}{Gradient ∇H at the estimate}
#'   \item{variance_matrix}{V(λ) - influence function variance of (Δ_S, Δ_Y)}
#'   \item{treatment_effects}{Treatment effects in each innovation}
#'   \item{parameters}{Parameters used}
#'
#' @details
#' This implements the asymptotic theory from the paper:
#'
#' √n(φ̂_n(λ) - φ(F_λ)) → N(0, σ²(λ))
#'
#' where σ²(λ) = (∇H)ᵀ V(λ) (∇H)
#'
#' The algorithm:
#' 1. Generate M innovations P̃_m ~ Dirichlet(α,...,α)
#' 2. Form Q_m = (1-λ)P̂_n + λP̃_m
#' 3. Compute (Δ_S(Q_m), Δ_Y(Q_m)) using mixture weights
#' 4. Compute φ̂(λ) from the M pairs
#' 5. Compute V̂(λ) using influence functions for treatment effects
#' 6. Compute ∇H using numerical or analytical derivatives
#' 7. Compute σ̂²(λ) = (∇H)ᵀ V̂(λ) (∇H)
#'
#' @examples
#' # Generate data
#' data <- generate_study_data(n = 1000,
#'                             treatment_effect_surrogate = c(0.3, 0.9),
#'                             treatment_effect_outcome = c(0.2, 0.8))
#'
#' # Estimate with influence function variance
#' result <- surrogate_inference_if(data, lambda = 0.3, n_innovations = 1000)
#'
#' # 95% CI
#' cat(sprintf("φ(F_λ): %.3f [%.3f, %.3f]\n",
#'             result$estimate, result$ci_lower, result$ci_upper))
#'
#' @export
surrogate_inference_if <- function(current_data,
                                   lambda,
                                   n_innovations = 1000,
                                   functional_type = c("correlation", "probability", "conditional_mean"),
                                   epsilon_s = 0.2,
                                   epsilon_y = 0.1,
                                   alpha = 1,
                                   confidence_level = 0.95,
                                   gradient_method = c("numerical", "analytical"),
                                   epsilon_gradient = 0.01) {

  functional_type <- match.arg(functional_type)
  gradient_method <- match.arg(gradient_method)

  n <- nrow(current_data)

  # Step 1: Compute treatment effects in P̂_n and their influence functions
  delta_s_hat <- compute_treatment_effect(current_data, "S")
  delta_y_hat <- compute_treatment_effect(current_data, "Y")

  # Compute influence functions for treatment effects
  # For randomized trial: IF_i = (A_i/π - (1-A_i)/(1-π)) * (S_i - E[S|A_i])
  # This gives Var(Δ̂) = Var(IF)/n
  if_variance <- compute_treatment_effect_variance(current_data)
  V_lambda <- if_variance  # 2×2 variance matrix for (Δ̂_S, Δ̂_Y)

  # Step 2: Generate M innovations from Dirichlet(α,...,α)
  innovations <- MCMCpack::rdirichlet(n_innovations, rep(alpha, n))

  # Step 3: Form Q_m = (1-λ)P̂_n + λP̃_m and compute treatment effects
  treatment_effects <- matrix(NA, nrow = n_innovations, ncol = 2)
  colnames(treatment_effects) <- c("delta_s", "delta_y")

  for (m in 1:n_innovations) {
    # Mixture weights for Q_m
    p_hat <- rep(1/n, n)  # Empirical distribution
    p_tilde <- innovations[m, ]  # Innovation
    q_m_weights <- (1 - lambda) * p_hat + lambda * p_tilde

    # Compute treatment effects under Q_m using mixture weights
    # Δ_S(Q_m) = E_Qm[S(1) - S(0)]
    delta_s_qm <- compute_treatment_effect_weighted(current_data, "S", q_m_weights)
    delta_y_qm <- compute_treatment_effect_weighted(current_data, "Y", q_m_weights)

    treatment_effects[m, "delta_s"] <- delta_s_qm
    treatment_effects[m, "delta_y"] <- delta_y_qm
  }

  # Step 4: Compute φ̂(λ) from the M treatment effect pairs
  phi_hat <- compute_functional_from_effects(
    treatment_effects[, "delta_s"],
    treatment_effects[, "delta_y"],
    functional_type = functional_type,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y
  )

  # Step 5: Compute gradient ∇H at (Δ̂_S, Δ̂_Y)
  if (gradient_method == "analytical" && functional_type == "correlation") {
    grad_h <- gradient_correlation_analytical(
      delta_s_hat, delta_y_hat, lambda, alpha, n_innovations, current_data
    )
  } else {
    # Numerical gradient using finite differences
    grad_h <- gradient_numerical(
      delta_s_hat, delta_y_hat, lambda, alpha, n_innovations,
      functional_type, epsilon_s, epsilon_y, epsilon_gradient, current_data
    )
  }

  # Step 6: Delta method variance: σ²(λ) = (∇H)ᵀ V(λ) (∇H)
  sigma_sq <- as.numeric(t(grad_h) %*% V_lambda %*% grad_h)
  se <- sqrt(sigma_sq / n)

  # Step 7: Confidence interval
  z_alpha <- qnorm(1 - (1 - confidence_level) / 2)
  ci_lower <- phi_hat - z_alpha * se
  ci_upper <- phi_hat + z_alpha * se

  # Return results
  list(
    estimate = phi_hat,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    gradient = grad_h,
    variance_matrix = V_lambda,
    sigma_squared = sigma_sq,
    treatment_effects = treatment_effects,
    parameters = list(
      lambda = lambda,
      n_innovations = n_innovations,
      functional_type = functional_type,
      alpha = alpha,
      confidence_level = confidence_level,
      n = n
    )
  )
}

#' Compute treatment effect with mixture weights
#'
#' @param data Data frame
#' @param outcome Character. "S" or "Y"
#' @param weights Numeric vector of mixture weights (one per observation)
#' @keywords internal
compute_treatment_effect_weighted <- function(data, outcome, weights) {
  # For each observation, compute influence function contribution
  # Then weight by mixture probability

  # Δ = E_Q[outcome(1)] - E_Q[outcome(0)]
  # Under mixture Q with weights w_i on observation i

  pi_hat <- mean(data$A)

  delta_1 <- sum(weights * data$A * data[[outcome]] / pi_hat)
  delta_0 <- sum(weights * (1 - data$A) * data[[outcome]] / (1 - pi_hat))

  delta_1 - delta_0
}

#' Compute influence function variance for treatment effects
#'
#' Returns 2×2 covariance matrix of (Δ̂_S, Δ̂_Y)
#'
#' @param data Data frame with A, S, Y
#' @keywords internal
compute_treatment_effect_variance <- function(data) {
  n <- nrow(data)
  pi_hat <- mean(data$A)

  # Compute influence functions
  # IF_i = (A_i/π - (1-A_i)/(1-π)) * (outcome_i - E[outcome|A_i])

  # For S
  e_s_1 <- mean(data$S[data$A == 1])
  e_s_0 <- mean(data$S[data$A == 0])
  if_s <- (data$A / pi_hat - (1 - data$A) / (1 - pi_hat)) *
          ifelse(data$A == 1, data$S - e_s_1, data$S - e_s_0)

  # For Y
  e_y_1 <- mean(data$Y[data$A == 1])
  e_y_0 <- mean(data$Y[data$A == 0])
  if_y <- (data$A / pi_hat - (1 - data$A) / (1 - pi_hat)) *
          ifelse(data$A == 1, data$Y - e_y_1, data$Y - e_y_0)

  # Covariance matrix
  var_s <- var(if_s)
  var_y <- var(if_y)
  cov_sy <- cov(if_s, if_y)

  matrix(c(var_s, cov_sy, cov_sy, var_y), nrow = 2, ncol = 2)
}

#' Compute functional from treatment effect pairs
#'
#' @keywords internal
compute_functional_from_effects <- function(delta_s_vec, delta_y_vec,
                                           functional_type,
                                           epsilon_s, epsilon_y) {
  if (functional_type == "correlation") {
    # Handle zero variance case (e.g., all values identical)
    if (sd(delta_s_vec) == 0 || sd(delta_y_vec) == 0) {
      # If no variation in one variable, correlation is undefined
      # Return 0 as a reasonable default (no linear relationship detectable)
      return(0)
    }
    cor(delta_s_vec, delta_y_vec)
  } else if (functional_type == "probability") {
    mean((delta_s_vec > epsilon_s) & (delta_y_vec > epsilon_y)) /
      mean(delta_s_vec > epsilon_s)
  } else if (functional_type == "conditional_mean") {
    # Not implemented yet
    stop("conditional_mean functional not yet implemented with IF method")
  }
}

#' Evaluate H at a specific point
#'
#' Evaluates H(δ_S, δ_Y) = E_μ[φ((1-λ)δ_S + λΔ_S(P̃), (1-λ)δ_Y + λΔ_Y(P̃))]
#' by generating M innovations and computing the functional.
#'
#' @param delta_s Treatment effect on S at evaluation point
#' @param delta_y Treatment effect on Y at evaluation point
#' @param data Current study data (used only for sample size)
#' @param lambda Perturbation parameter
#' @param n_innovations Number of innovations M
#' @param alpha Dirichlet concentration parameter
#' @param functional_type Type of functional
#' @param epsilon_s Threshold for probability functional
#' @param epsilon_y Threshold for probability functional
#'
#' @return Scalar value of φ(F_λ) evaluated at (δ_S, δ_Y)
#' @keywords internal
evaluate_H_at_point <- function(delta_s, delta_y, data, lambda, n_innovations,
                                alpha, functional_type, epsilon_s, epsilon_y) {
  n <- nrow(data)

  # Generate M innovations from Dirichlet(α,...,α)
  innovations <- MCMCpack::rdirichlet(n_innovations, rep(alpha, n))

  # For each innovation, compute treatment effects under Q_m = (1-λ)P̂ + λP̃_m
  # But now we're evaluating at a specific (delta_s, delta_y) point, not the data's
  # treatment effects. So we form:
  #   Δ_S(Q_m) = (1-λ) * delta_s + λ * Δ_S(P̃_m)
  #   Δ_Y(Q_m) = (1-λ) * delta_y + λ * Δ_Y(P̃_m)

  treatment_effects <- matrix(NA, nrow = n_innovations, ncol = 2)

  for (m in 1:n_innovations) {
    # Compute treatment effect under the innovation P̃_m
    p_tilde <- innovations[m, ]
    delta_s_tilde <- compute_treatment_effect_weighted(data, "S", p_tilde)
    delta_y_tilde <- compute_treatment_effect_weighted(data, "Y", p_tilde)

    # Mixture: (1-λ) * point + λ * innovation
    delta_s_qm <- (1 - lambda) * delta_s + lambda * delta_s_tilde
    delta_y_qm <- (1 - lambda) * delta_y + lambda * delta_y_tilde

    treatment_effects[m, 1] <- delta_s_qm
    treatment_effects[m, 2] <- delta_y_qm
  }

  # Compute functional from the M pairs
  compute_functional_from_effects(
    treatment_effects[, 1],
    treatment_effects[, 2],
    functional_type = functional_type,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y
  )
}

#' Numerical gradient of H
#'
#' Computes ∇H = (∂H/∂δ_S, ∂H/∂δ_Y) using central finite differences.
#' Each evaluation draws fresh innovations (4M total for the gradient).
#'
#' @keywords internal
gradient_numerical <- function(delta_s, delta_y, lambda, alpha, n_innovations,
                               functional_type, epsilon_s, epsilon_y, eps,
                               data) {

  # Evaluate H at four points using central differences
  h_s_plus <- evaluate_H_at_point(
    delta_s + eps, delta_y, data, lambda, n_innovations,
    alpha, functional_type, epsilon_s, epsilon_y
  )

  h_s_minus <- evaluate_H_at_point(
    delta_s - eps, delta_y, data, lambda, n_innovations,
    alpha, functional_type, epsilon_s, epsilon_y
  )

  h_y_plus <- evaluate_H_at_point(
    delta_s, delta_y + eps, data, lambda, n_innovations,
    alpha, functional_type, epsilon_s, epsilon_y
  )

  h_y_minus <- evaluate_H_at_point(
    delta_s, delta_y - eps, data, lambda, n_innovations,
    alpha, functional_type, epsilon_s, epsilon_y
  )

  # Central differences
  grad_s <- (h_s_plus - h_s_minus) / (2 * eps)
  grad_y <- (h_y_plus - h_y_minus) / (2 * eps)

  c(grad_s, grad_y)
}

#' Analytical gradient for correlation functional
#'
#' For correlation, we can compute the gradient analytically
#'
#' @keywords internal
gradient_correlation_analytical <- function(delta_s, delta_y, lambda, alpha, n_innovations, data) {
  # This requires deriving ∂/∂δ_S of cor(Δ_S(Q), Δ_Y(Q)) where Q ~ F_λ
  # Complex - may need to approximate or use numerical method
  warning("Analytical gradient for correlation not yet implemented, using numerical")
  gradient_numerical(delta_s, delta_y, lambda, alpha, n_innovations,
                     "correlation", NULL, NULL, 1e-6, data)
}
