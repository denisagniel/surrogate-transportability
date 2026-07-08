# Test: Does the method work in each setting?
#
# Validate that TV ball geometry correctly distinguishes:
# - Good surrogate (correlated effects)
# - Poor surrogate (uncorrelated effects)
# - Bad surrogate (negatively correlated effects)

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Generate current study data with specified effect correlation
#'
#' @param n Sample size
#' @param K Number of types
#' @param rho_effect Type-level effect correlation
#' @return List with data and parameters
generate_current_study <- function(
  n = 500,
  K = 10,
  rho_effect = 0.8
) {

  # Type probabilities
  P0 <- rep(1/K, K)
  types <- sample(1:K, n, replace = TRUE, prob = P0)

  # Treatment assignment
  Z <- rbinom(n, 1, 0.5)

  # Type-specific treatment effects
  set.seed(123)
  tau_S <- seq(0.2, 0.8, length.out = K)

  if (abs(rho_effect) < 0.01) {
    # Uncorrelated: use residualization
    tau_Y <- c(0.8, 0.3, 0.6, 0.4, 0.5, 0.7, 0.2, 0.9, 0.35, 0.65)
    tau_Y <- tau_Y - mean(tau_Y)
    tau_Y <- tau_Y - cor(tau_S, tau_Y) *
             (tau_S - mean(tau_S)) / var(tau_S) * var(tau_Y)
    tau_Y <- tau_Y + mean(tau_S)
  } else if (rho_effect > 0) {
    # Positive correlation
    tau_Y <- tau_S + rnorm(K, sd = sqrt(1 - rho_effect^2) * sd(tau_S))
  } else {
    # Negative correlation
    tau_Y <- rev(tau_S) + rnorm(K, sd = sqrt(1 - rho_effect^2) * sd(tau_S))
  }

  # Generate outcomes
  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]

    # Baseline outcomes (correlated)
    baseline_S <- rnorm(1, mean = 0)
    baseline_Y <- 0.7 * baseline_S + sqrt(1 - 0.7^2) * rnorm(1)

    # Add treatment effects
    S[i] <- baseline_S + Z[i] * tau_S[type_i] + rnorm(1, sd = 0.5)
    Y[i] <- baseline_Y + Z[i] * tau_Y[type_i] + rnorm(1, sd = 0.5)
  }

  data <- tibble(
    type = types,
    Z = Z,
    S = S,
    Y = Y
  )

  list(
    data = data,
    P0 = P0,
    tau_S = tau_S,
    tau_Y = tau_Y,
    true_cor = cor(tau_S, tau_Y)
  )
}

#' Estimate treatment effects from current study
#'
#' @param data Current study data
#' @param K Number of types
#' @return Estimated treatment effects by type
estimate_effects <- function(data, K) {

  tau_S_hat <- numeric(K)
  tau_Y_hat <- numeric(K)

  for (k in 1:K) {
    mask_k <- data$type == k

    if (sum(mask_k & data$Z == 1) > 0 && sum(mask_k & data$Z == 0) > 0) {
      tau_S_hat[k] <- mean(data$S[mask_k & data$Z == 1]) -
                      mean(data$S[mask_k & data$Z == 0])
      tau_Y_hat[k] <- mean(data$Y[mask_k & data$Z == 1]) -
                      mean(data$Y[mask_k & data$Z == 0])
    } else {
      # If no observations in type k, use population average
      tau_S_hat[k] <- mean(tau_S_hat[tau_S_hat != 0], na.rm = TRUE)
      tau_Y_hat[k] <- mean(tau_Y_hat[tau_Y_hat != 0], na.rm = TRUE)
    }
  }

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat)
}

#' Apply TV ball method to evaluate surrogate
#'
#' @param current_study Current study data and parameters
#' @param lambda TV ball radius
#' @param M Number of Q samples
#' @return Method results
apply_tv_ball_method <- function(
  current_study,
  lambda = 0.3,
  M = 2000
) {

  cat(sprintf("Applying TV ball method (λ = %.2f, M = %d)...\n", lambda, M))

  # Estimate effects from current study
  K <- length(current_study$P0)
  effects <- estimate_effects(current_study$data, K)

  # Sample from TV ball
  Q_samples <- hit_and_run_tv_ball(
    P0 = current_study$P0,
    lambda = lambda,
    n_samples = M,
    burn_in = 1000,
    thin = 10,
    verbose = FALSE
  )

  # Compute treatment effects for each Q
  Delta_S <- Q_samples %*% effects$tau_S_hat
  Delta_Y <- Q_samples %*% effects$tau_Y_hat

  # Estimate correlation
  cor_estimate <- cor(Delta_S, Delta_Y)

  # Bootstrap CI (simple percentile)
  n_boot <- 500
  cors_boot <- numeric(n_boot)

  for (b in 1:n_boot) {
    idx <- sample(1:M, M, replace = TRUE)
    cors_boot[b] <- cor(Delta_S[idx], Delta_Y[idx])
  }

  ci_lower <- quantile(cors_boot, 0.025)
  ci_upper <- quantile(cors_boot, 0.975)

  list(
    cor_estimate = cor_estimate,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    Delta_S = Delta_S,
    Delta_Y = Delta_Y,
    tau_S_hat = effects$tau_S_hat,
    tau_Y_hat = effects$tau_Y_hat
  )
}

#' Test method on all three scenarios
test_method_all_scenarios <- function(
  n = 500,
  K = 10,
  lambda = 0.3,
  M = 2000
) {

  cat("========================================\n")
  cat("METHOD VALIDATION ACROSS SCENARIOS\n")
  cat("========================================\n\n")

  # Scenario 1: Good surrogate (correlated effects)
  cat("SCENARIO 1: Good Surrogate (Correlated Effects)\n")
  cat("================================================\n\n")

  current_1 <- generate_current_study(n = n, K = K, rho_effect = 0.8)
  cat(sprintf("True type-level correlation: %.3f\n\n", current_1$true_cor))

  method_1 <- apply_tv_ball_method(current_1, lambda = lambda, M = M)

  cat(sprintf("Method estimate: %.3f [%.3f, %.3f]\n",
              method_1$cor_estimate,
              method_1$ci_lower,
              method_1$ci_upper))

  cat(sprintf("Bias: %+.3f\n", method_1$cor_estimate - current_1$true_cor))

  if (method_1$ci_lower > 0.3) {
    cat("✓ Method correctly identifies GOOD surrogate (CI excludes 0)\n")
  }
  cat("\n")

  # Scenario 2: Poor surrogate (uncorrelated effects)
  cat("SCENARIO 2: Poor Surrogate (Uncorrelated Effects)\n")
  cat("==================================================\n\n")

  current_2 <- generate_current_study(n = n, K = K, rho_effect = 0.0)
  cat(sprintf("True type-level correlation: %.3f\n\n", current_2$true_cor))

  method_2 <- apply_tv_ball_method(current_2, lambda = lambda, M = M)

  cat(sprintf("Method estimate: %.3f [%.3f, %.3f]\n",
              method_2$cor_estimate,
              method_2$ci_lower,
              method_2$ci_upper))

  cat(sprintf("Bias: %+.3f\n", method_2$cor_estimate - current_2$true_cor))

  if (method_2$ci_lower < 0.3 && method_2$ci_upper > -0.3) {
    cat("✓ Method correctly identifies POOR surrogate (CI includes 0)\n")
  }
  cat("\n")

  # Scenario 3: Bad surrogate (negatively correlated effects)
  cat("SCENARIO 3: Bad Surrogate (Negatively Correlated Effects)\n")
  cat("==========================================================\n\n")

  current_3 <- generate_current_study(n = n, K = K, rho_effect = -0.8)
  cat(sprintf("True type-level correlation: %.3f\n\n", current_3$true_cor))

  method_3 <- apply_tv_ball_method(current_3, lambda = lambda, M = M)

  cat(sprintf("Method estimate: %.3f [%.3f, %.3f]\n",
              method_3$cor_estimate,
              method_3$ci_lower,
              method_3$ci_upper))

  cat(sprintf("Bias: %+.3f\n", method_3$cor_estimate - current_3$true_cor))

  if (method_3$ci_upper < -0.3) {
    cat("✓ Method correctly identifies BAD surrogate (CI < 0)\n")
  }
  cat("\n")

  # Summary
  cat("========================================\n")
  cat("SUMMARY\n")
  cat("========================================\n\n")

  results <- tibble(
    scenario = c("Good (Correlated)", "Poor (Uncorrelated)", "Bad (Negative)"),
    true_cor = c(current_1$true_cor, current_2$true_cor, current_3$true_cor),
    estimated_cor = c(method_1$cor_estimate, method_2$cor_estimate, method_3$cor_estimate),
    ci_lower = c(method_1$ci_lower, method_2$ci_lower, method_3$ci_lower),
    ci_upper = c(method_1$ci_upper, method_2$ci_upper, method_3$ci_upper),
    bias = estimated_cor - true_cor
  )

  print(results, n = Inf)

  cat("\n")
  cat("Method performance:\n")
  cat(sprintf("  Mean absolute bias: %.3f\n", mean(abs(results$bias))))
  cat(sprintf("  Max absolute bias: %.3f\n", max(abs(results$bias))))

  # Check if CIs correctly distinguish scenarios
  ci_1_positive <- results$ci_lower[1] > 0.2
  ci_2_includes_zero <- results$ci_lower[2] < 0.1 & results$ci_upper[2] > -0.1
  ci_3_negative <- results$ci_upper[3] < -0.2

  if (ci_1_positive && ci_2_includes_zero && ci_3_negative) {
    cat("\n✓ Method correctly distinguishes all three scenarios!\n")
  } else {
    cat("\n⚠ Method may not distinguish all scenarios perfectly\n")
    if (!ci_1_positive) cat("  - Failed to identify good surrogate\n")
    if (!ci_2_includes_zero) cat("  - Failed to identify poor surrogate\n")
    if (!ci_3_negative) cat("  - Failed to identify bad surrogate\n")
  }

  # Visualization
  p <- ggplot(results, aes(x = scenario, y = estimated_cor)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_hline(yintercept = c(-0.5, 0.5), linetype = "dotted", color = "gray70") +
    geom_errorbar(
      aes(ymin = ci_lower, ymax = ci_upper),
      width = 0.2, linewidth = 1
    ) +
    geom_point(size = 4, color = "steelblue") +
    geom_point(aes(y = true_cor), size = 3, color = "red", shape = 4, stroke = 2) +
    labs(
      title = "TV Ball Method Performance Across Scenarios",
      subtitle = "Blue dots: Method estimates with 95% CI\nRed X: True correlation",
      x = "Scenario",
      y = "Across-Study Correlation",
      caption = sprintf("n = %d, K = %d, λ = %.2f, M = %d", n, K, lambda, M)
    ) +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 0, hjust = 0.5))

  print(p)
  ggsave(
    "explorations/tv_ball_geometry/figures/method_validation_scenarios.pdf",
    p, width = 8, height = 6
  )

  list(
    results = results,
    scenario1 = list(current = current_1, method = method_1),
    scenario2 = list(current = current_2, method = method_2),
    scenario3 = list(current = current_3, method = method_3),
    plot = p
  )
}

# Run if interactive
if (interactive()) {

  validation <- test_method_all_scenarios(
    n = 500,
    K = 10,
    lambda = 0.3,
    M = 2000
  )

  cat("\n\nResults saved to:\n")
  cat("  explorations/tv_ball_geometry/figures/method_validation_scenarios.pdf\n")
}
