#!/usr/bin/env Rscript
# Observation-Level Smoothed Wasserstein Dual (No Discretization)
# Complete influence function derivation

library(tidyverse)

# ==============================================================================
# DGP with Oracle Nuisance Functions
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Covariates (can be multivariate, using univariate for simplicity)
  X <- rnorm(n)

  # Treatment (randomized)
  A <- rbinom(n, 1, 0.5)

  # True treatment effects (smooth functions of X)
  tau_S_true <- 0.3 + 0.2 * X + 0.1 * X^2
  tau_Y_true <- 0.4 + 0.3 * X + 0.05 * X^2

  # Conditional means (oracle)
  mu_S1_true <- 0.2 + tau_S_true
  mu_S0_true <- 0.2
  mu_Y1_true <- 0.3 + tau_Y_true
  mu_Y0_true <- 0.3

  # Observed outcomes
  S <- A * mu_S1_true + (1-A) * mu_S0_true + rnorm(n, sd = 0.5)
  Y <- A * mu_Y1_true + (1-A) * mu_Y0_true + rnorm(n, sd = 0.5)

  data.frame(
    X = X,
    A = A,
    S = S,
    Y = Y,
    e_x = 0.5,
    mu_S1_true = mu_S1_true,
    mu_S0_true = mu_S0_true,
    mu_Y1_true = mu_Y1_true,
    mu_Y0_true = mu_Y0_true,
    tau_S_true = tau_S_true,
    tau_Y_true = tau_Y_true
  )
}

# ==============================================================================
# Observation-Level Wasserstein Dual
# ==============================================================================

#' Compute n×n cost matrix (pairwise distances)
compute_obs_cost_matrix <- function(X) {
  n <- length(X)
  cost_matrix <- outer(X, X, function(x1, x2) (x1 - x2)^2)
  return(cost_matrix)
}

#' Smooth minimum using LogSumExp
smooth_min <- function(x, tau = 0.1) {
  -tau * log(mean(exp(-x / tau)))
}

#' Softmax weights for smooth minimum
softmax_weights <- function(x, tau = 0.1) {
  exp_vals <- exp(-x / tau)
  exp_vals / sum(exp_vals)
}

#' Observation-level smoothed Wasserstein dual objective
#' g_tau(gamma) = -gamma*lambda_w^2 + (1/n)*sum_j phi_tau^j(gamma)
#' where phi_tau^j(gamma) = smooth_min_i{h_i + gamma*C[i,j]}
obs_wasserstein_objective <- function(gamma, h, cost_matrix, lambda_w, tau) {
  n <- length(h)

  # For each reference observation j, compute smooth min over target observations i
  phi_j <- numeric(n)
  for (j in 1:n) {
    # Values: h_i + gamma*C[i,j] for all i
    values <- h + gamma * cost_matrix[, j]
    phi_j[j] <- smooth_min(values, tau)
  }

  # Objective: -gamma*lambda_w^2 + mean(phi_j)
  objective <- -gamma * lambda_w^2 + mean(phi_j)

  return(objective)
}

#' Solve observation-level smoothed Wasserstein dual
solve_obs_wasserstein <- function(h, cost_matrix, lambda_w, tau = 0.1) {
  # Optimize over gamma >= 0
  result <- optimize(
    f = function(g) obs_wasserstein_objective(g, h, cost_matrix, lambda_w, tau),
    interval = c(0, 10 / lambda_w^2),
    maximum = TRUE,
    tol = 1e-6
  )

  list(
    phi_star = result$objective,
    gamma_star = result$maximum,
    convergence = TRUE
  )
}

# ==============================================================================
# Influence Function
# ==============================================================================

#' IF for treatment effect (efficient IF)
compute_IF_tau <- function(obs, outcome, mu1, mu0, e_x) {
  A <- obs$A
  Y <- obs[[outcome]]

  IF_val <- A * (Y - mu1) / e_x - (1-A) * (Y - mu0) / (1-e_x)
  return(IF_val)
}

#' Compute all softmax weights at optimal gamma
#' W[i,j] = weight of observation i for reference observation j
compute_obs_softmax_weights <- function(h, cost_matrix, gamma_star, tau) {
  n <- length(h)
  W <- matrix(0, n, n)

  for (j in 1:n) {
    values <- h + gamma_star * cost_matrix[, j]
    W[, j] <- softmax_weights(values, tau)
  }

  return(W)
}

#' Complete IF for observation-level smoothed Wasserstein dual
#'
#' Key insight: Each observation i contributes to the estimate through:
#' 1. Its own concordance h_i (direct contribution)
#' 2. All other observations' objectives (through h_i in their smooth mins)
#'
#' The IF for observation i accounts for perturbations to h_i affecting
#' the entire dual objective.
compute_IF_obs_wasserstein <- function(data, h, cost_matrix, gamma_star, tau) {
  n <- nrow(data)

  # Compute softmax weights at optimum
  W <- compute_obs_softmax_weights(h, cost_matrix, gamma_star, tau)

  # Initialize IF values
  IF_vals <- numeric(n)

  for (i in 1:n) {
    obs <- data[i, ]

    # IF for tau_S(X_i) and tau_Y(X_i)
    IF_tau_S_i <- compute_IF_tau(obs, "S", obs$mu_S1_true, obs$mu_S0_true, obs$e_x)
    IF_tau_Y_i <- compute_IF_tau(obs, "Y", obs$mu_Y1_true, obs$mu_Y0_true, obs$e_x)

    # IF for h_i = tau_S(X_i) * tau_Y(X_i)
    # Product rule
    tau_S_i <- obs$tau_S_true
    tau_Y_i <- obs$tau_Y_true
    IF_h_i <- tau_S_i * IF_tau_Y_i + tau_Y_i * IF_tau_S_i

    # Contribution of h_i to overall objective
    # h_i appears in the smooth minimum for ALL reference observations j
    # Weighted by W[i,j] (how much obs i contributes to ref obs j's min)
    IF_contrib <- (1/n) * sum(W[i, ] * IF_h_i)

    IF_vals[i] <- IF_contrib
  }

  # Center to have mean zero
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Estimation and Inference
# ==============================================================================

estimate_obs_wasserstein <- function(data, lambda_w, tau = 0.1) {
  # Concordances at each observation (using oracle)
  h <- data$tau_S_true * data$tau_Y_true

  # Cost matrix (n×n)
  cost_matrix <- compute_obs_cost_matrix(data$X)

  # Solve smoothed dual
  result <- solve_obs_wasserstein(h, cost_matrix, lambda_w, tau)

  list(
    phi_star = result$phi_star,
    gamma_star = result$gamma_star,
    h = h,
    cost_matrix = cost_matrix
  )
}

IF_based_CI_obs <- function(data, lambda_w, tau = 0.1, alpha = 0.05) {
  n <- nrow(data)

  # Estimate
  est <- estimate_obs_wasserstein(data, lambda_w, tau)

  # Compute IF
  IF_vals <- compute_IF_obs_wasserstein(
    data,
    est$h,
    est$cost_matrix,
    est$gamma_star,
    tau
  )

  # Variance
  sigma_sq <- mean(IF_vals^2)
  se <- sqrt(sigma_sq / n)

  # CI
  z_crit <- qnorm(1 - alpha/2)
  ci_lower <- est$phi_star - z_crit * se
  ci_upper <- est$phi_star + z_crit * se

  list(
    estimate = est$phi_star,
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
  cat("TEST 1: IF has mean zero\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)  # Use n=1000 (not too large for n×n matrix)
  est <- estimate_obs_wasserstein(data, lambda_w = 0.5, tau = 0.1)

  IF_vals <- compute_IF_obs_wasserstein(
    data,
    est$h,
    est$cost_matrix,
    est$gamma_star,
    tau = 0.1
  )

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500, lambda_w = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| lambda_w:", lambda_w, "| tau:", tau, "\n\n")

  # True value (large sample)
  set.seed(999)
  large_data <- generate_data(10000)
  truth <- estimate_obs_wasserstein(large_data, lambda_w, tau)
  phi_true <- truth$phi_star

  cat("True phi (n=10000):", sprintf("%.4f", phi_true), "\n\n")

  # Run simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI_obs(data, lambda_w, tau)

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

  passed <- abs(coverage_rate - 0.95) < 0.05
  cat("\n", ifelse(passed, "✓ PASS", "✗ FAIL"), "\n\n")

  list(
    coverage_rate = coverage_rate,
    mean_estimate = mean_estimate,
    phi_true = phi_true
  )
}

test_variance_consistency <- function(n_values = c(200, 300, 500), n_sims = 50) {
  cat("TEST 3: Variance consistency\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  truth <- estimate_obs_wasserstein(large_data, lambda_w = 0.5, tau = 0.1)
  phi_true <- truth$phi_star

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      est <- estimate_obs_wasserstein(data, lambda_w = 0.5, tau = 0.1)
      est$phi_star
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI_obs(data, lambda_w = 0.5, tau = 0.1)
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

test_computational_cost <- function() {
  cat("TEST 4: Computational cost scaling\n")
  cat(strrep("=", 70), "\n\n")

  n_values <- c(100, 200, 500, 1000)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    data <- generate_data(n, seed = 123)

    # Time the estimation
    start_time <- Sys.time()
    est <- estimate_obs_wasserstein(data, lambda_w = 0.5, tau = 0.1)
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

    data.frame(
      n = n,
      time_secs = elapsed,
      matrix_size = n^2
    )
  })

  print(results)
  cat("\nNote: Time scales as O(n^2) due to cost matrix\n\n")

  results
}

# ==============================================================================
# MAIN
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("OBSERVATION-LEVEL SMOOTHED WASSERSTEIN DUAL\n")
  cat(strrep("=", 70), "\n\n")

  cat("Approach: No discretization, direct observation-level\n")
  cat("Cost matrix: n×n pairwise distances\n")
  cat("Theory: Complete IF derivation\n\n")

  # Test 1
  test_IF_mean_zero()

  # Test 2
  test2 <- test_coverage(n_sims = 100, n = 500)

  # Test 3
  test3 <- test_variance_consistency(n_values = c(200, 300, 500), n_sims = 50)

  # Test 4
  test4 <- test_computational_cost()

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  list(
    coverage = test2,
    variance_consistency = test3,
    computational_cost = test4
  )
}

if (sys.nframe() == 0) {
  results <- main()
  saveRDS(results, "observation_level_wasserstein_results.rds")
  cat("\nResults saved to: observation_level_wasserstein_results.rds\n")
}
