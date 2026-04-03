#!/usr/bin/env Rscript
# Observation-Level Wasserstein with CORRECT IF (Both Terms)
# Testing with observed h to verify IF formula

library(tidyverse)

# ==============================================================================
# DGP
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n)
  S <- rnorm(n, mean = 1, sd = 0.5)
  Y <- rnorm(n, mean = 2, sd = 0.5)
  h_obs <- S * Y * X^2

  data.frame(X = X, S = S, Y = Y, h_obs = h_obs)
}

# ==============================================================================
# Wasserstein Dual
# ==============================================================================

compute_obs_cost_matrix <- function(X) {
  n <- length(X)
  outer(X, X, function(x1, x2) (x1 - x2)^2)
}

smooth_min <- function(x, tau = 0.1) {
  -tau * log(mean(exp(-x / tau)))
}

obs_wasserstein_objective <- function(gamma, h, cost_matrix, lambda_w, tau) {
  n <- length(h)
  phi_j <- numeric(n)
  for (j in 1:n) {
    values <- h + gamma * cost_matrix[, j]
    phi_j[j] <- smooth_min(values, tau)
  }
  -gamma * lambda_w^2 + mean(phi_j)
}

solve_obs_wasserstein <- function(h, cost_matrix, lambda_w, tau = 0.1) {
  result <- optimize(
    f = function(g) obs_wasserstein_objective(g, h, cost_matrix, lambda_w, tau),
    interval = c(0, 10 / lambda_w^2),
    maximum = TRUE,
    tol = 1e-6
  )

  list(phi_star = result$objective, gamma_star = result$maximum)
}

# ==============================================================================
# CORRECT Influence Function (Both Outer and Inner Terms)
# ==============================================================================

#' Compute m(x) = E_{X'}[g(x, X')]
compute_m <- function(x_ref, X_all, h_all, gamma, tau) {
  n <- length(X_all)
  costs <- (X_all - x_ref)^2
  values <- exp(-(h_all + gamma * costs) / tau)
  mean(values)
}

#' Compute g(x, x')
compute_g <- function(x_ref, x_target, h_target, gamma, tau) {
  cost <- (x_target - x_ref)^2
  exp(-(h_target + gamma * cost) / tau)
}

#' CORRECTED IF with BOTH outer and inner terms
#'
#' phi(o) = OUTER_TERM + INNER_TERM
#'
#' OUTER_TERM = -tau*log(m(o)) - Psi
#'   (observation o as reference point)
#'
#' INNER_TERM = -tau * E_X[g(X,o)/m(X)] + tau
#'   (observation o appearing in all other expectations)
#'
compute_IF_corrected <- function(X_test, h_test, gamma_star, lambda_w, tau) {
  n <- length(X_test)

  # Compute m(X_k) for all observations
  m_vals <- numeric(n)
  for (k in 1:n) {
    m_vals[k] <- compute_m(X_test[k], X_test, h_test, gamma_star, tau)
  }

  # Compute Psi_hat
  psi_hat <- -gamma_star * lambda_w^2 + mean(-tau * log(m_vals))

  # Compute IF for each observation
  IF_vals <- numeric(n)

  for (k in 1:n) {
    # OUTER TERM: k as reference point
    outer_term <- -tau * log(m_vals[k]) - psi_hat

    # INNER TERM: k in all other reference points' expectations
    # E_X[g(X,k)/m(X)] ≈ (1/n) sum_j g(X_j,k)/m(X_j)
    g_vals_over_m <- numeric(n)
    for (j in 1:n) {
      g_vals_over_m[j] <- compute_g(X_test[j], X_test[k], h_test[k], gamma_star, tau) / m_vals[j]
    }
    inner_term <- -tau * mean(g_vals_over_m) + tau

    # TOTAL IF
    IF_vals[k] <- outer_term + inner_term
  }

  # Center
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Estimation and Inference
# ==============================================================================

estimate_with_corrected_IF <- function(data, lambda_w, tau = 0.1) {
  n <- nrow(data)
  h <- data$h_obs
  cost_matrix <- compute_obs_cost_matrix(data$X)

  result <- solve_obs_wasserstein(h, cost_matrix, lambda_w, tau)

  IF_vals <- compute_IF_corrected(data$X, h, result$gamma_star, lambda_w, tau)

  sigma_sq <- mean(IF_vals^2)
  se <- sqrt(sigma_sq / n)

  list(phi_star = result$phi_star, gamma_star = result$gamma_star,
       se = se, IF_vals = IF_vals)
}

IF_based_CI_corrected <- function(data, lambda_w, tau = 0.1, alpha = 0.05) {
  result <- estimate_with_corrected_IF(data, lambda_w, tau)

  z_crit <- qnorm(1 - alpha/2)
  ci_lower <- result$phi_star - z_crit * result$se
  ci_upper <- result$phi_star + z_crit * result$se

  list(estimate = result$phi_star, se = result$se,
       ci_lower = ci_lower, ci_upper = ci_upper,
       IF_vals = result$IF_vals)
}

# ==============================================================================
# TESTS
# ==============================================================================

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero (CORRECTED - both terms)\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  result <- estimate_with_corrected_IF(data, lambda_w = 0.5, tau = 0.1)

  cat("Mean of IF:", sprintf("%.8f", mean(result$IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(result$IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(result$IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(result$IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500, lambda_w = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage (CORRECTED IF with both terms)\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| lambda_w:", lambda_w, "| tau:", tau, "\n\n")

  # True value
  set.seed(999)
  large_data <- generate_data(10000)
  truth <- estimate_with_corrected_IF(large_data, lambda_w, tau)
  phi_true <- truth$phi_star

  cat("True phi (n=10000):", sprintf("%.4f", phi_true), "\n\n")

  # Simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI_corrected(data, lambda_w, tau)

    covered <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)

    list(estimate = ci$estimate, se = ci$se, covered = covered,
         ci_width = ci$ci_upper - ci$ci_lower)
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

  list(coverage_rate = coverage_rate, mean_estimate = mean_estimate,
       phi_true = phi_true)
}

test_variance_consistency <- function(n_values = c(200, 300, 500), n_sims = 50) {
  cat("TEST 3: Variance consistency (CORRECTED IF)\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  truth <- estimate_with_corrected_IF(large_data, lambda_w = 0.5, tau = 0.1)
  phi_true <- truth$phi_star

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      result <- estimate_with_corrected_IF(data, lambda_w = 0.5, tau = 0.1)
      result$phi_star
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI_corrected(data, lambda_w = 0.5, tau = 0.1)
      ci$se
    })

    mean_IF_se <- mean(IF_ses)

    data.frame(n = n, empirical_se = empirical_se,
               mean_IF_se = mean_IF_se,
               ratio = mean_IF_se / empirical_se)
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
  cat("CORRECTED IF: Both Outer and Inner Terms\n")
  cat(strrep("=", 70), "\n\n")

  cat("Formula: phi(o) = [outer term] + [inner term]\n")
  cat("Outer: -tau*log(m(o)) - Psi (o as reference)\n")
  cat("Inner: -tau*E[g(X,o)/m(X)] + tau (o in expectations)\n\n")

  test_IF_mean_zero()
  test2 <- test_coverage(n_sims = 100, n = 500)
  test3 <- test_variance_consistency(n_values = c(200, 300, 500), n_sims = 50)

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  list(coverage = test2, variance_consistency = test3)
}

if (sys.nframe() == 0) {
  results <- main()
  saveRDS(results, "observed_h_corrected_IF_results.rds")
  cat("\nResults saved to: observed_h_corrected_IF_results.rds\n")
}
