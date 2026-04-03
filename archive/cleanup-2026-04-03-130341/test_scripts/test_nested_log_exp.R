#!/usr/bin/env Rscript
# Test EIF for E_X[-log(E_{X'}[exp(-X*X')])] using same sample twice
# This is the NESTED structure like our Wasserstein problem

library(tidyverse)

# ==============================================================================
# Estimand: E_X[-log(E_{X'}[exp(-X*X')])]
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Use smaller positive values
  X <- abs(rnorm(n, mean = 1, sd = 0.3))

  data.frame(X = X)
}

# ==============================================================================
# Estimator
# ==============================================================================

estimate_nested <- function(data) {
  X <- data$X
  n <- length(X)

  # For each reference point j, compute inner expectation
  phi_j <- numeric(n)
  for (j in 1:n) {
    # E_{X'}[exp(-X_j * X')] ≈ (1/n) sum_i exp(-X_j * X_i)
    m_j <- mean(exp(-X[j] * X))
    phi_j[j] <- -log(m_j)
  }

  # Outer expectation: E_X[phi(X)]
  estimate <- mean(phi_j)

  return(estimate)
}

# ==============================================================================
# Influence Function (Two Terms: Outer + Inner)
#
# Psi(P) = ∫ [-log(∫ exp(-x*x') dP(x'))] dP(x)
#
# OUTER TERM: observation o as reference point x
#   phi_outer(o) = -log(m(o)) - Psi
#   where m(o) = E_{X'}[exp(-o*X')]
#
# INNER TERM: observation o appearing in all inner expectations
#   phi_inner(o) = ∫ [-exp(-x*o)/m(x)] dP(x) + 1
#   where o appears in m(x) = E_{X'}[exp(-x*X')] for all x
# ==============================================================================

compute_IF_nested <- function(data) {
  X <- data$X
  n <- length(X)

  # Compute m(X_j) for all j
  m_vals <- numeric(n)
  for (j in 1:n) {
    m_vals[j] <- mean(exp(-X[j] * X))
  }

  # Compute Psi_hat
  psi_hat <- mean(-log(m_vals))

  # IF for each observation k
  IF_vals <- numeric(n)

  for (k in 1:n) {
    # OUTER TERM: k as reference point
    outer_term <- -log(m_vals[k]) - psi_hat

    # INNER TERM: k appearing in all other reference points' expectations
    # For each reference j, k contributes exp(-X_j * X_k) to m(X_j)
    # Weight is -exp(-X_j * X_k) / m(X_j)
    inner_contrib <- numeric(n)
    for (j in 1:n) {
      inner_contrib[j] <- -exp(-X[j] * X[k]) / m_vals[j]
    }
    inner_term <- mean(inner_contrib) + 1

    # Total IF
    IF_vals[k] <- outer_term + inner_term
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
  estimate <- estimate_nested(data)

  # IF
  IF_vals <- compute_IF_nested(data)

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
  cat("TEST 1: IF has mean zero for nested expectation\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  IF_vals <- compute_IF_nested(data)

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500) {
  cat("TEST 2: Coverage for nested expectation\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "\n\n")

  # True value (large sample approximation)
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_nested(large_data)

  cat("True E_X[-log(E_{X'}[exp(-X*X')])] (n=10000):", sprintf("%.6f", phi_true), "\n\n")

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
  cat("TEST 3: Variance consistency for nested expectation\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_nested(large_data)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      estimate_nested(data)
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
  cat("TEST E_X[-log(E_{X'}[exp(-X*X')])] - NESTED STRUCTURE\n")
  cat(strrep("=", 70), "\n\n")

  cat("Estimand: E_X[-log(E_{X'}[exp(-X*X')])]\n")
  cat("Same sample for both X and X'\n")
  cat("IF has TWO terms:\n")
  cat("  1. Outer: observation as reference point\n")
  cat("  2. Inner: observation in all inner expectations\n")
  cat("This matches our Wasserstein dual structure!\n\n")

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
  saveRDS(results, "nested_log_exp_results.rds")
  cat("\nResults saved to: nested_log_exp_results.rds\n")
}
