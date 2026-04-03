#!/usr/bin/env Rscript
# Test Bootstrap Inference on Wasserstein Dual (Exact Minimax Solution)
# This is the CLOSED-FORM solution for concordance functional

library(tidyverse)
source("package/R/type_level_effects.R")
source("package/R/wasserstein_concordance_dual.R")

# ==============================================================================
# DGP with Smooth Treatment Effect Heterogeneity
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Covariates
  X <- rnorm(n)

  # Treatment (randomized)
  A <- rbinom(n, 1, 0.5)

  # True treatment effects (smooth functions of X)
  tau_S_true <- 0.3 + 0.2 * X + 0.1 * X^2
  tau_Y_true <- 0.4 + 0.3 * X + 0.05 * X^2

  # Conditional means
  mu_S1 <- 0.2 + tau_S_true
  mu_S0 <- 0.2
  mu_Y1 <- 0.3 + tau_Y_true
  mu_Y0 <- 0.3

  # Observed outcomes
  S <- A * mu_S1 + (1-A) * mu_S0 + rnorm(n, sd = 0.5)
  Y <- A * mu_Y1 + (1-A) * mu_Y0 + rnorm(n, sd = 0.5)

  data.frame(
    X = X,
    A = A,
    S = S,
    Y = Y
  )
}

# ==============================================================================
# Discretization into Types
# ==============================================================================

discretize_into_types <- function(data, J = 4) {
  # Quantile-based discretization
  breaks <- quantile(data$X, probs = seq(0, 1, length.out = J + 1))
  type <- cut(data$X, breaks = breaks, labels = 1:J, include.lowest = TRUE)
  data$type <- as.numeric(type)
  return(data)
}

# ==============================================================================
# Type-Level Statistics
# ==============================================================================

compute_type_stats <- function(data) {
  # Estimate treatment effects by type
  type_summaries <- data %>%
    group_by(type) %>%
    summarize(
      n_type = n(),
      tau_S = mean(S[A==1]) - mean(S[A==0]),
      tau_Y = mean(Y[A==1]) - mean(Y[A==0]),
      .groups = "drop"
    )

  J <- nrow(type_summaries)
  p0 <- type_summaries$n_type / sum(type_summaries$n_type)

  list(
    J = J,
    p0 = p0,
    tau_s = type_summaries$tau_S,  # lowercase for validation
    tau_y = type_summaries$tau_Y,  # lowercase for validation
    concordances = type_summaries$tau_S * type_summaries$tau_Y
  )
}

# ==============================================================================
# Cost Matrix (for Wasserstein distance)
# ==============================================================================

compute_cost_matrix <- function(data) {
  # Compute type centroids in X space
  centroids <- data %>%
    group_by(type) %>%
    summarize(X_mean = mean(X), .groups = "drop") %>%
    pull(X_mean)

  J <- length(centroids)
  cost_matrix <- matrix(0, J, J)

  for (i in 1:J) {
    for (j in 1:J) {
      cost_matrix[i,j] <- (centroids[i] - centroids[j])^2
    }
  }

  return(cost_matrix)
}

# ==============================================================================
# Wasserstein Dual Estimator
# ==============================================================================

#' Estimate minimax concordance via Wasserstein dual
estimate_wasserstein_minimax <- function(data, lambda_w, J = 4) {
  # Discretize
  data <- discretize_into_types(data, J)

  # Compute type-level statistics
  type_stats <- compute_type_stats(data)

  # Cost matrix
  cost_matrix <- compute_cost_matrix(data)

  # Solve Wasserstein dual (closed-form)
  result <- wasserstein_concordance_dual(
    type_stats,
    cost_matrix,
    lambda_w,
    method = "brent"
  )

  return(list(
    phi_star = result$phi_star,
    optimal_gamma = result$optimal_gamma,
    phi_P0 = result$objective_at_zero,  # E_P0[concordance]
    type_stats = type_stats
  ))
}

# ==============================================================================
# Bootstrap Inference
# ==============================================================================

bootstrap_wasserstein_CI <- function(data, lambda_w, J = 4, B = 500, alpha = 0.05) {
  n <- nrow(data)

  # Original estimate
  est_orig <- estimate_wasserstein_minimax(data, lambda_w, J)

  # Bootstrap
  boot_estimates <- replicate(B, {
    boot_indices <- sample(1:n, n, replace = TRUE)
    boot_data <- data[boot_indices, ]

    est_boot <- estimate_wasserstein_minimax(boot_data, lambda_w, J)
    est_boot$phi_star
  })

  # Percentile CI
  ci_lower <- quantile(boot_estimates, alpha/2)
  ci_upper <- quantile(boot_estimates, 1 - alpha/2)

  return(list(
    estimate = est_orig$phi_star,
    phi_P0 = est_orig$phi_P0,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    boot_estimates = boot_estimates,
    optimal_gamma = est_orig$optimal_gamma
  ))
}

# ==============================================================================
# TESTS
# ==============================================================================

test_coverage <- function(n_sims = 200, n = 1000, lambda_w = 0.5, J = 4, B = 500) {
  cat("Testing Bootstrap Coverage for Wasserstein Dual\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| lambda_w:", lambda_w, "| B:", B, "\n\n")

  # Compute "truth" from large sample
  set.seed(999)
  large_data <- generate_data(100000)
  truth <- estimate_wasserstein_minimax(large_data, lambda_w, J)
  phi_true <- truth$phi_star

  cat("True minimax phi (large sample):", sprintf("%.4f", phi_true), "\n")
  cat("True E_P0[concordance]:         ", sprintf("%.4f", truth$phi_P0), "\n\n")

  # Run simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- bootstrap_wasserstein_CI(data, lambda_w, J, B)

    covered <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)

    list(
      estimate = ci$estimate,
      phi_P0 = ci$phi_P0,
      ci_lower = ci$ci_lower,
      ci_upper = ci$ci_upper,
      covered = covered,
      ci_width = ci$ci_upper - ci$ci_lower
    )
  }, simplify = FALSE)

  # Extract
  estimates <- sapply(results, function(x) x$estimate)
  phi_P0s <- sapply(results, function(x) x$phi_P0)
  covered <- sapply(results, function(x) x$covered)
  ci_widths <- sapply(results, function(x) x$ci_width)

  coverage_rate <- mean(covered)
  mean_estimate <- mean(estimates)
  mean_phi_P0 <- mean(phi_P0s)
  mean_ci_width <- mean(ci_widths)

  cat("Results:\n")
  cat("Mean minimax estimate:", sprintf("%.4f", mean_estimate), "\n")
  cat("Mean E_P0[concordance]:", sprintf("%.4f", mean_phi_P0), "\n")
  cat("Bias in minimax:       ", sprintf("%.4f", mean_estimate - phi_true), "\n")
  cat("Coverage rate:         ", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width:         ", sprintf("%.4f", mean_ci_width), "\n")
  cat("Target:                95.0%\n")

  passed <- abs(coverage_rate - 0.95) < 0.05
  cat("\n", ifelse(passed, "✓ PASS", "✗ FAIL"), "\n\n")

  return(list(
    coverage_rate = coverage_rate,
    mean_estimate = mean_estimate,
    phi_true = phi_true,
    mean_phi_P0 = mean_phi_P0
  ))
}

test_sample_size_scaling <- function(n_sims = 50, B = 500) {
  cat("Testing Sample Size Scaling\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(100000)
  truth <- estimate_wasserstein_minimax(large_data, lambda_w = 0.5, J = 4)
  phi_true <- truth$phi_star

  n_values <- c(500, 1000, 2000)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    coverage_vec <- numeric(n_sims)
    estimates <- numeric(n_sims)

    for (i in 1:n_sims) {
      data <- generate_data(n, seed = NULL)
      ci <- bootstrap_wasserstein_CI(data, lambda_w = 0.5, J = 4, B = B)

      coverage_vec[i] <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)
      estimates[i] <- ci$estimate
    }

    data.frame(
      n = n,
      coverage = mean(coverage_vec),
      bias = mean(estimates) - phi_true,
      rmse = sqrt(mean((estimates - phi_true)^2))
    )
  })

  print(results)
  cat("\n")

  return(results)
}

test_lambda_sensitivity <- function(n_sims = 50, n = 1000, B = 500) {
  cat("Testing Sensitivity to lambda_w\n")
  cat(strrep("=", 70), "\n\n")

  lambda_values <- c(0.3, 0.5, 0.8)

  results <- map_df(lambda_values, function(lambda_w) {
    cat("lambda_w =", lambda_w, "...\n")

    # Truth for this lambda
    set.seed(999)
    large_data <- generate_data(100000)
    truth <- estimate_wasserstein_minimax(large_data, lambda_w, J = 4)
    phi_true <- truth$phi_star

    coverage_vec <- numeric(n_sims)
    estimates <- numeric(n_sims)

    for (i in 1:n_sims) {
      data <- generate_data(n, seed = NULL)
      ci <- bootstrap_wasserstein_CI(data, lambda_w, J = 4, B = B)

      coverage_vec[i] <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)
      estimates[i] <- ci$estimate
    }

    data.frame(
      lambda_w = lambda_w,
      phi_true = phi_true,
      coverage = mean(coverage_vec),
      mean_estimate = mean(estimates),
      bias = mean(estimates) - phi_true
    )
  })

  print(results)
  cat("\n")

  return(results)
}

# ==============================================================================
# MAIN
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("WASSERSTEIN DUAL: BOOTSTRAP INFERENCE TESTS\n")
  cat(strrep("=", 70), "\n\n")

  cat("Method: Closed-form Wasserstein dual (exact minimax)\n")
  cat("Functional: Concordance E[tau_S * tau_Y]\n")
  cat("Inference: Bootstrap percentile CI\n\n")

  # Test 1: Coverage
  test1 <- test_coverage(n_sims = 200, n = 1000, lambda_w = 0.5, J = 4, B = 500)

  # Test 2: Sample size scaling
  test2 <- test_sample_size_scaling(n_sims = 50, B = 500)

  # Test 3: Lambda sensitivity
  test3 <- test_lambda_sensitivity(n_sims = 50, n = 1000, B = 500)

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  return(list(
    coverage = test1,
    sample_size_scaling = test2,
    lambda_sensitivity = test3
  ))
}

if (sys.nframe() == 0) {
  results <- main()
  saveRDS(results, "wasserstein_dual_inference_results.rds")
  cat("\nResults saved to: wasserstein_dual_inference_results.rds\n")
}
