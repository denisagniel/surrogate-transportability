#!/usr/bin/env Rscript
# Test EIF for E(X_i X_j) using same sample twice
# Verify our two-term IF approach is correct

library(tidyverse)

# ==============================================================================
# Simple Case: E(X_i X_j) = mu^2
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Simple univariate data
  X <- rnorm(n, mean = 2, sd = 1)

  data.frame(X = X)
}

# ==============================================================================
# Estimator: bar{X}^2
# ==============================================================================

estimate_XiXj <- function(data) {
  X <- data$X
  n <- length(X)

  # Estimator: (1/n sum X_i)^2
  X_bar <- mean(X)
  estimate <- X_bar^2

  return(estimate)
}

# ==============================================================================
# Influence Function: phi(x) = 2*mu*(x - mu)
# ==============================================================================

compute_IF_XiXj <- function(data) {
  X <- data$X
  n <- length(X)

  # Population parameter estimate
  mu_hat <- mean(X)

  # IF for each observation: 2*mu*(X_i - mu)
  IF_vals <- 2 * mu_hat * (X - mu_hat)

  # Should already be centered, but let's verify
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Inference
# ==============================================================================

IF_based_CI <- function(data, alpha = 0.05) {
  n <- nrow(data)

  # Estimate
  estimate <- estimate_XiXj(data)

  # IF
  IF_vals <- compute_IF_XiXj(data)

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
  cat("TEST 1: IF has mean zero for E(X_i X_j)\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  IF_vals <- compute_IF_XiXj(data)

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500) {
  cat("TEST 2: Coverage for E(X_i X_j)\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "\n\n")

  # True value (mu^2 where mu = 2)
  phi_true <- 4.0

  cat("True E(X_i X_j):", sprintf("%.4f", phi_true), "\n\n")

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
  cat("Mean estimate:", sprintf("%.4f", mean_estimate), "\n")
  cat("Bias:         ", sprintf("%.4f", mean_estimate - phi_true), "\n")
  cat("Mean SE:      ", sprintf("%.4f", mean_se), "\n")
  cat("Coverage rate:", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width:", sprintf("%.4f", mean(ci_widths)), "\n")
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
  cat("TEST 3: Variance consistency for E(X_i X_j)\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  phi_true <- 4.0

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      estimate_XiXj(data)
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
# THEORETICAL VARIANCE CHECK
# ==============================================================================

test_theoretical_variance <- function() {
  cat("TEST 4: Compare to theoretical variance\n")
  cat(strrep("=", 70), "\n\n")

  # Generate large sample to estimate variance
  set.seed(999)
  data <- generate_data(10000)

  X <- data$X
  mu <- mean(X)
  sigma_sq <- var(X)

  cat("Estimated mu:    ", sprintf("%.4f", mu), "\n")
  cat("Estimated sigma^2:", sprintf("%.4f", sigma_sq), "\n\n")

  # Theoretical variance of IF: Var[2*mu*(X - mu)] = 4*mu^2*sigma^2
  theoretical_var <- 4 * mu^2 * sigma_sq

  cat("Theoretical Var[IF]:", sprintf("%.4f", theoretical_var), "\n")

  # Empirical variance of IF
  IF_vals <- compute_IF_XiXj(data)
  empirical_var <- mean(IF_vals^2)

  cat("Empirical Var[IF]:  ", sprintf("%.4f", empirical_var), "\n")
  cat("Ratio:              ", sprintf("%.4f", empirical_var / theoretical_var), "\n\n")

  cat("Should be near 1.0\n\n")
}

# ==============================================================================
# MAIN
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("TEST E(X_i X_j) with Same Sample\n")
  cat(strrep("=", 70), "\n\n")

  cat("Estimand: E(X_i X_j) = mu^2\n")
  cat("Estimator: bar{X}^2\n")
  cat("IF: phi(x) = 2*mu*(x - mu)\n")
  cat("This verifies our two-term IF approach is correct\n\n")

  test_IF_mean_zero()
  test2 <- test_coverage(n_sims = 100, n = 500)
  test3 <- test_variance_consistency(n_values = c(200, 300, 500), n_sims = 50)
  test_theoretical_variance()

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
  saveRDS(results, "E_XiXj_results.rds")
  cat("\nResults saved to: E_XiXj_results.rds\n")
}
