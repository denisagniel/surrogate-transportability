#!/usr/bin/env Rscript
# Test EIF for -log(E[exp(X_i * X_j)]) using same sample twice
# This has log OUTSIDE the expectation, like our Wasserstein problem

library(tidyverse)

# ==============================================================================
# Estimand: -log(E[exp(X_i * X_j)])
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Use smaller values to keep exp manageable
  X <- rnorm(n, mean = 0, sd = 0.3)

  data.frame(X = X)
}

# ==============================================================================
# Estimator: -log((1/n^2) sum_{i,j} exp(X_i * X_j))
# ==============================================================================

estimate_neg_log_exp_XiXj <- function(data) {
  X <- data$X
  n <- length(X)

  # First compute E[exp(X_i * X_j)]
  total <- 0
  for (i in 1:n) {
    inner_sum <- sum(exp(X[i] * X))
    total <- total + inner_sum
  }

  E_exp <- total / n^2

  # Then take -log
  estimate <- -log(E_exp)

  return(estimate)
}

# ==============================================================================
# Influence Function via Chain Rule
#
# Psi(P) = -log(m(P))
# where m(P) = ∫∫ exp(x_i * x_j) dP(x_i) dP(x_j)
#
# Chain rule: phi_Psi = -(1/m) * phi_m
#
# We know: phi_m(o) = 2*E[exp(o*X)] - 2*m
#
# Therefore: phi_Psi(o) = -(2*E[exp(o*X)]/m) + 2
# ==============================================================================

compute_IF_neg_log_exp_XiXj <- function(data) {
  X <- data$X
  n <- length(X)

  # Compute m(P) = E[exp(X_i * X_j)]
  total <- 0
  for (i in 1:n) {
    inner_sum <- sum(exp(X[i] * X))
    total <- total + inner_sum
  }
  m_hat <- total / n^2

  # IF for each observation k
  IF_vals <- numeric(n)

  for (k in 1:n) {
    # E[exp(X_k * X)] ≈ (1/n) sum_j exp(X_k * X_j)
    E_exp_kX <- mean(exp(X[k] * X))

    # Chain rule: phi_Psi(k) = -(1/m) * phi_m(k)
    # where phi_m(k) = 2*E[exp(k*X)] - 2*m

    phi_m_k <- 2 * E_exp_kX - 2 * m_hat

    IF_vals[k] <- -(1/m_hat) * phi_m_k

    # Simplify: -(1/m) * (2*E[exp(k*X)] - 2*m)
    #         = -2*E[exp(k*X)]/m + 2
    # IF_vals[k] <- -2 * E_exp_kX / m_hat + 2
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
  estimate <- estimate_neg_log_exp_XiXj(data)

  # IF
  IF_vals <- compute_IF_neg_log_exp_XiXj(data)

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
  cat("TEST 1: IF has mean zero for -log(E[exp(X_i X_j)])\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  IF_vals <- compute_IF_neg_log_exp_XiXj(data)

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500) {
  cat("TEST 2: Coverage for -log(E[exp(X_i X_j)])\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "\n\n")

  # True value (large sample approximation)
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_neg_log_exp_XiXj(large_data)

  cat("True -log(E[exp(X_i X_j)]) (n=10000):", sprintf("%.6f", phi_true), "\n\n")

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
  cat("TEST 3: Variance consistency for -log(E[exp(X_i X_j)])\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_neg_log_exp_XiXj(large_data)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      estimate_neg_log_exp_XiXj(data)
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
  cat("TEST -log(E[exp(X_i X_j)]) with Same Sample\n")
  cat(strrep("=", 70), "\n\n")

  cat("Estimand: -log(E[exp(X_i * X_j)])\n")
  cat("Estimator: -log((1/n^2) sum_{i,j} exp(X_i * X_j))\n")
  cat("IF via chain rule: -(1/m) * IF_m where m = E[exp(X_i X_j)]\n")
  cat("This has log OUTSIDE expectation, like Wasserstein problem\n\n")

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
  saveRDS(results, "neg_log_E_exp_XiXj_results.rds")
  cat("\nResults saved to: neg_log_E_exp_XiXj_results.rds\n")
}
