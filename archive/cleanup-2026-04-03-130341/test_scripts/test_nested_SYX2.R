#!/usr/bin/env Rscript
# Test EIF with EXACT DGP from failing test: h = S * Y * X^2
# This should identify what's causing the failure

library(tidyverse)

# ==============================================================================
# EXACT DGP from test_observed_h_only.R
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # EXACT same as failing test
  X <- rnorm(n)
  S <- rnorm(n, mean = 1, sd = 0.5)
  Y <- rnorm(n, mean = 2, sd = 0.5)

  # Observed h (no estimation needed)
  h_obs <- S * Y * X^2

  data.frame(X = X, S = S, Y = Y, h_obs = h_obs)
}

# ==============================================================================
# Estimator
# ==============================================================================

estimate_nested_SYX2 <- function(data, gamma = 0.5, tau = 0.1) {
  X <- data$X
  h <- data$h_obs
  n <- length(X)

  # For each reference point j, compute inner expectation
  phi_j <- numeric(n)
  for (j in 1:n) {
    # Cost matrix: (X - X_j)^2
    costs <- (X - X[j])^2

    # E_{X'}[exp(-(h(X') + gamma*C)/tau)]
    values <- exp(-(h + gamma * costs) / tau)
    m_j <- mean(values)

    phi_j[j] <- -tau * log(m_j)
  }

  # Outer expectation
  estimate <- mean(phi_j)

  return(estimate)
}

# ==============================================================================
# Influence Function (Two Terms)
# ==============================================================================

compute_IF_nested_SYX2 <- function(data, gamma = 0.5, tau = 0.1) {
  X <- data$X
  h <- data$h_obs
  n <- length(X)

  # Compute m(X_j) for all j
  m_vals <- numeric(n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h + gamma * costs) / tau)
    m_vals[j] <- mean(values)
  }

  # Compute Psi_hat
  psi_hat <- mean(-tau * log(m_vals))

  # IF for each observation k
  IF_vals <- numeric(n)

  for (k in 1:n) {
    # OUTER TERM: k as reference point
    outer_term <- -tau * log(m_vals[k]) - psi_hat

    # INNER TERM: k appearing in all other reference points' expectations
    inner_contrib <- numeric(n)
    for (j in 1:n) {
      cost_kj <- (X[k] - X[j])^2
      g_kj <- exp(-(h[k] + gamma * cost_kj) / tau)
      inner_contrib[j] <- -tau * g_kj / m_vals[j]
    }
    inner_term <- mean(inner_contrib) + tau

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

IF_based_CI <- function(data, gamma = 0.5, tau = 0.1, alpha = 0.05) {
  n <- nrow(data)

  estimate <- estimate_nested_SYX2(data, gamma, tau)
  IF_vals <- compute_IF_nested_SYX2(data, gamma, tau)

  sigma_sq <- mean(IF_vals^2)
  se <- sqrt(sigma_sq / n)

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

test_h_distribution <- function() {
  cat("TEST 0: Examine h = S*Y*X^2 distribution\n")
  cat(strrep("=", 70), "\n\n")

  set.seed(123)
  data <- generate_data(1000)

  cat("Summary of h values:\n")
  print(summary(data$h_obs))
  cat("\nSD of h:      ", sprintf("%.4f", sd(data$h_obs)), "\n")
  cat("Min h:        ", sprintf("%.4f", min(data$h_obs)), "\n")
  cat("Max h:        ", sprintf("%.4f", max(data$h_obs)), "\n")
  cat("% negative:   ", sprintf("%.1f%%", 100*mean(data$h_obs < 0)), "\n")
  cat("% |h| > 10:   ", sprintf("%.1f%%", 100*mean(abs(data$h_obs) > 10)), "\n\n")

  # Check exp(-(h + gamma*cost)/tau) range
  gamma <- 0.5
  tau <- 0.1
  X <- data$X
  h <- data$h_obs
  n <- length(X)

  # Sample some values
  costs <- (X[1:100] - X[1])^2
  exp_vals <- exp(-(h[1:100] + gamma * costs) / tau)

  cat("Sample exp(-(h + gamma*cost)/tau) values:\n")
  cat("Min:  ", sprintf("%.2e", min(exp_vals)), "\n")
  cat("Max:  ", sprintf("%.2e", max(exp_vals)), "\n")
  cat("Mean: ", sprintf("%.2e", mean(exp_vals)), "\n\n")
}

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero (h = S*Y*X^2)\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  IF_vals <- compute_IF_nested_SYX2(data, gamma = 0.5, tau = 0.1)

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500, gamma = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage (h = S*Y*X^2)\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| gamma:", gamma, "| tau:", tau, "\n\n")

  # True value
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_nested_SYX2(large_data, gamma, tau)

  cat("True value (n=10000):", sprintf("%.6f", phi_true), "\n\n")

  # Simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI(data, gamma, tau)

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
  cat("TEST 3: Variance consistency (h = S*Y*X^2)\n")
  cat(strrep("=", 70), "\n\n")

  gamma <- 0.5
  tau <- 0.1

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  phi_true <- estimate_nested_SYX2(large_data, gamma, tau)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      estimate_nested_SYX2(data, gamma, tau)
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI(data, gamma, tau)
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
  cat("TEST WITH EXACT FAILING DGP: h = S*Y*X^2\n")
  cat(strrep("=", 70), "\n\n")

  cat("This uses the EXACT DGP from test_observed_h_only.R\n")
  cat("where h = S * Y * X^2 with S ~ N(1, 0.5), Y ~ N(2, 0.5), X ~ N(0,1)\n\n")

  test_h_distribution()
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
  saveRDS(results, "nested_SYX2_results.rds")
  cat("\nResults saved to: nested_SYX2_results.rds\n")
}
