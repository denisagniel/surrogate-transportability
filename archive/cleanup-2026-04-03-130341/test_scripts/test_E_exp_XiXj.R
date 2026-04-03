#!/usr/bin/env Rscript
# Test EIF for E[exp(X_i * X_j)] using same sample twice
# This has the nonlinearity (exp) like our Wasserstein problem

library(tidyverse)

# ==============================================================================
# Estimand: E[exp(X_i * X_j)]
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Use smaller values to keep exp manageable
  X <- rnorm(n, mean = 0, sd = 0.3)

  data.frame(X = X)
}

# ==============================================================================
# Estimator: (1/n^2) sum_i sum_j exp(X_i * X_j)
# ==============================================================================

estimate_exp_XiXj <- function(data) {
  X <- data$X
  n <- length(X)

  # Estimator: (1/n^2) * sum_{i,j} exp(X_i * X_j)
  # Can be computed as: (1/n) * sum_i [ (1/n) * sum_j exp(X_i * X_j) ]
  total <- 0
  for (i in 1:n) {
    inner_sum <- sum(exp(X[i] * X))
    total <- total + inner_sum
  }

  estimate <- total / n^2

  return(estimate)
}

# ==============================================================================
# Influence Function via Gâteaux Derivative
#
# Psi(P) = ∫∫ exp(x_i * x_j) dP(x_i) dP(x_j)
#
# Using product rule (distribution P appears twice):
# phi(o) = 2 * E[exp(o * X)] - 2 * Psi
# ==============================================================================

compute_IF_exp_XiXj <- function(data) {
  X <- data$X
  n <- length(X)

  # Estimate of Psi
  psi_hat <- estimate_exp_XiXj(data)

  # IF for each observation k
  IF_vals <- numeric(n)

  for (k in 1:n) {
    # E[exp(X_k * X)] ≈ (1/n) sum_j exp(X_k * X_j)
    E_exp_oX <- mean(exp(X[k] * X))

    # IF: 2 * E[exp(o*X)] - 2*Psi
    IF_vals[k] <- 2 * E_exp_oX - 2 * psi_hat
  }

  # Center
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Inference
# ==============================================================================

IF_based_CI <- function(data, alpha = 0.05) {
  n <- nrow(data)

  # Estimate
  estimate <- estimate_exp_XiXj(data)

  # IF
  IF_vals <- compute_IF_exp_XiXj(data)

  # Variance
  sigma_sq <- mean(IF_vals^2)
  se <- sqrt(sigma_sq / n)

  # CI
  z_crit <- qnorm(1 - alpha/2)
  ci_lower <- estimate - z_crit * se
  ci_upper <- estimate + z_crit * se

  list(
    estimate = estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    IF_vals = IF_vals
  )
}

# ==============================================================================
# TESTS
# ==============================================================================

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero for E[exp(X_i X_j)]\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  IF_vals <- compute_IF_exp_XiXj(data)

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500) {
  cat("TEST 2: Coverage for E[exp(X_i X_j)]\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "\n\n")

  # True value (large sample approximation)
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_exp_XiXj(large_data)

  cat("True E[exp(X_i X_j)] (n=10000):", sprintf("%.6f", phi_true), "\n\n")

  # Simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI(data)

    covered <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)

    list(
      estimate = ci$estimate,
      se = ci$se,
      covered = covered,
      ci_width = ci$ci_upper - ci$ci_lower
    )
  }, simplify = FALSE)

  estimates <- sapply(results, function(x) x$estimate)
  ses <- sapply(results, function(x) x$se)
  covered <- sapply(results, function(x) x$covered)
  ci_widths <- sapply(results, function(x) x$ci_width)

  coverage_rate <- mean(covered)
  mean_estimate <- mean(estimates)
  mean_se <- mean(ses)

  cat("Results:\n")
  cat("Mean estimate:", sprintf("%.6f", mean_estimate), "\n")
  cat("Bias:         ", sprintf("%.6f", mean_estimate - phi_true), "\n")
  cat("Mean SE:      ", sprintf("%.6f", mean_se), "\n")
  cat("Coverage rate:", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width:", sprintf("%.6f", mean(ci_widths)), "\n")
  cat("Target:       95.0%\n")

  passed <- abs(coverage_rate - 0.95) < 0.10
  cat("\n", ifelse(passed, "✓ PASS", "✗ FAIL"), "\n\n")

  list(
    coverage_rate = coverage_rate,
    mean_estimate = mean_estimate,
    phi_true = phi_true
  )
}

test_variance_consistency <- function(n_values = c(200, 300, 500), n_sims = 50) {
  cat("TEST 3: Variance consistency for E[exp(X_i X_j)]\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_exp_XiXj(large_data)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      estimate_exp_XiXj(data)
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI(data)
      ci$se
    })

    mean_IF_se <- mean(IF_ses)

    data.frame(
      n = n,
      empirical_se = empirical_se,
      mean_IF_se = mean_IF_se,
      ratio = mean_IF_se / empirical_se
    )
  })

  print(results)
  cat("\nInterpretation: Ratio should be near 1.0\n\n")

  results
}

# ==============================================================================
# MAIN
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("TEST E[exp(X_i X_j)] with Same Sample\n")
  cat(strrep("=", 70), "\n\n")

  cat("Estimand: E[exp(X_i * X_j)]\n")
  cat("Estimator: (1/n^2) sum_{i,j} exp(X_i * X_j)\n")
  cat("IF: phi(o) = 2*E[exp(o*X)] - 2*Psi\n")
  cat("Tests nonlinear case (exp) like Wasserstein problem\n\n")

  test_IF_mean_zero()
  test2 <- test_coverage(n_sims = 100, n = 500)
  test3 <- test_variance_consistency(n_values = c(200, 300, 500), n_sims = 50)

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  list(
    coverage = test2,
    variance_consistency = test3
  )
}

if (sys.nframe() == 0) {
  results <- main()
  saveRDS(results, "E_exp_XiXj_results.rds")
  cat("\nResults saved to: E_exp_XiXj_results.rds\n")
}
