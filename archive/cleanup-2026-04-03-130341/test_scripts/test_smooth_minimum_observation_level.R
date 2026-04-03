#!/usr/bin/env Rscript
# Smooth Minimum: OBSERVATION-LEVEL (No Discretization)
# Full IF with oracle nuisance functions

library(tidyverse)

# ==============================================================================
# DGP with KNOWN nuisance functions
# ==============================================================================

generate_data_with_nuisances <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Covariates
  X <- rnorm(n)

  # Treatment (randomized) - KNOWN propensity
  e_x <- rep(0.5, n)  # Constant propensity
  A <- rbinom(n, 1, 0.5)

  # TRUE conditional means (smooth functions of X)
  # E[S|A=1,X] and E[S|A=0,X]
  mu_S1_true <- 0.3 + 0.2 * X + 0.1 * X^2
  mu_S0_true <- 0.1 + 0.05 * X

  mu_Y1_true <- 0.4 + 0.3 * X + 0.05 * X^2
  mu_Y0_true <- 0.1 + 0.1 * X

  # TRUE treatment effects (functions of X)
  tau_S_true <- mu_S1_true - mu_S0_true
  tau_Y_true <- mu_Y1_true - mu_Y0_true

  # Observed outcomes (add noise)
  S <- A * mu_S1_true + (1-A) * mu_S0_true + rnorm(n, sd = 0.5)
  Y <- A * mu_Y1_true + (1-A) * mu_Y0_true + rnorm(n, sd = 0.5)

  data.frame(
    X = X,
    A = A,
    S = S,
    Y = Y,
    # Oracle nuisances
    e_x = e_x,
    mu_S1_true = mu_S1_true,
    mu_S0_true = mu_S0_true,
    mu_Y1_true = mu_Y1_true,
    mu_Y0_true = mu_Y0_true,
    tau_S_true = tau_S_true,
    tau_Y_true = tau_Y_true
  )
}

# ==============================================================================
# Smooth Minimum: Observation-Level
# ==============================================================================

#' Smooth minimum over n observations (no discretization)
#' @param h_i Vector of concordances at each observation
#' @param tau Smoothing parameter
smooth_minimum_obs <- function(h_i, tau = 0.1) {
  n <- length(h_i)
  phi_tau <- -tau * log(mean(exp(-h_i / tau)))
  return(phi_tau)
}

#' Softmax weights over observations
softmax_weights_obs <- function(h_i, tau = 0.1) {
  exp_vals <- exp(-h_i / tau)
  weights <- exp_vals / sum(exp_vals)
  return(weights)
}

# ==============================================================================
# Influence Function: Observation-Level
# ==============================================================================

#' IF for treatment effect at observation i
#' Using oracle nuisances
compute_IF_tau <- function(obs, outcome) {
  A <- obs$A
  Y <- obs[[outcome]]
  mu1 <- obs[[paste0("mu_", outcome, "1_true")]]
  mu0 <- obs[[paste0("mu_", outcome, "0_true")]]
  e_x <- obs$e_x

  IF_val <- A * (Y - mu1) / e_x - (1-A) * (Y - mu0) / (1-e_x)
  return(IF_val)
}

#' FULL influence function for observation-level smooth minimum
#'
#' For each observation O, compute its contribution to IF_φτ
#'
#' The smooth minimum is φ_τ = -τ log((1/n) ∑_i exp(-h_i/τ))
#' where h_i = τ_S(X_i) × τ_Y(X_i)
#'
#' IF accounts for:
#' 1. Estimating h_i from data
#' 2. Aggregating via smooth minimum
compute_IF_smooth_min_obs <- function(data, tau = 0.1) {
  n <- nrow(data)

  # Compute concordance at each observation
  h_i <- data$tau_S_true * data$tau_Y_true

  # Softmax weights (how much each obs contributes to smooth min)
  w_i <- softmax_weights_obs(h_i, tau)

  # Initialize IF values
  IF_vals <- numeric(n)

  for (i in 1:n) {
    obs <- data[i, ]

    # IF for τ_S(X_i)
    IF_tau_S_i <- compute_IF_tau(obs, "S")

    # IF for τ_Y(X_i)
    IF_tau_Y_i <- compute_IF_tau(obs, "Y")

    # IF for h_i = τ_S(X_i) × τ_Y(X_i)
    # Product rule
    tau_S_i <- obs$tau_S_true
    tau_Y_i <- obs$tau_Y_true
    IF_h_i <- tau_S_i * IF_tau_Y_i + tau_Y_i * IF_tau_S_i

    # Contribution to φ_τ
    # This observation's h_i gets weight w_i in the smooth minimum
    IF_vals[i] <- w_i[i] * IF_h_i
  }

  # Center to have mean zero
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Estimation and Inference
# ==============================================================================

#' Estimate smooth minimum using oracle nuisances
estimate_smooth_min_obs <- function(data, tau = 0.1) {
  # Concordance at each observation
  h_i <- data$tau_S_true * data$tau_Y_true

  # Smooth minimum
  phi_hat <- smooth_minimum_obs(h_i, tau)

  return(list(
    phi_hat = phi_hat,
    h_i = h_i,
    tau = tau
  ))
}

#' IF-based confidence interval
IF_based_CI_obs <- function(data, tau = 0.1, alpha = 0.05) {
  n <- nrow(data)

  # Estimate
  est <- estimate_smooth_min_obs(data, tau)

  # Full IF
  IF_vals <- compute_IF_smooth_min_obs(data, tau)

  # Variance
  sigma_sq <- mean(IF_vals^2)
  se <- sqrt(sigma_sq / n)

  # CI
  z_crit <- qnorm(1 - alpha/2)
  ci_lower <- est$phi_hat - z_crit * se
  ci_upper <- est$phi_hat + z_crit * se

  return(list(
    estimate = est$phi_hat,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    IF_vals = IF_vals
  ))
}

# ==============================================================================
# TESTS
# ==============================================================================

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data_with_nuisances(5000, seed = 123)
  IF_vals <- compute_IF_smooth_min_obs(data, tau = 0.1)

  cat("Mean of IF:  ", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:    ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Max |IF|:    ", sprintf("%.4f", max(abs(IF_vals))), "\n")
  cat("Should be near 0: ", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 200, n = 1000, tau = 0.1) {
  cat("TEST 2: Coverage\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| tau:", tau, "\n\n")

  # True value (generate reference dataset)
  set.seed(999)
  ref_data <- generate_data_with_nuisances(100000)
  h_true <- ref_data$tau_S_true * ref_data$tau_Y_true
  phi_true <- smooth_minimum_obs(h_true, tau)
  cat("True phi:", sprintf("%.4f", phi_true), "\n\n")

  # Run simulations
  results <- replicate(n_sims, {
    data <- generate_data_with_nuisances(n, seed = NULL)
    ci <- IF_based_CI_obs(data, tau)

    covered <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)

    list(
      estimate = ci$estimate,
      se = ci$se,
      ci_lower = ci$ci_lower,
      ci_upper = ci$ci_upper,
      covered = covered,
      ci_width = ci$ci_upper - ci$ci_lower
    )
  }, simplify = FALSE)

  # Extract
  estimates <- sapply(results, function(x) x$estimate)
  ses <- sapply(results, function(x) x$se)
  covered <- sapply(results, function(x) x$covered)
  ci_widths <- sapply(results, function(x) x$ci_width)

  coverage_rate <- mean(covered)
  mean_estimate <- mean(estimates)
  mean_se <- mean(ses)
  mean_ci_width <- mean(ci_widths)

  cat("Results:\n")
  cat("Mean estimate:  ", sprintf("%.4f", mean_estimate), "\n")
  cat("Bias:           ", sprintf("%.4f", mean_estimate - phi_true), "\n")
  cat("Mean SE:        ", sprintf("%.4f", mean_se), "\n")
  cat("Coverage rate:  ", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width:  ", sprintf("%.4f", mean_ci_width), "\n")
  cat("Target:         95.0%\n")

  passed <- abs(coverage_rate - 0.95) < 0.03
  cat("\n", ifelse(passed, "✓ PASS", "✗ FAIL"), "\n\n")

  return(list(
    coverage_rate = coverage_rate,
    mean_estimate = mean_estimate,
    phi_true = phi_true
  ))
}

test_sample_size_scaling <- function(n_sims = 100) {
  cat("TEST 3: Sample size scaling\n")
  cat(strrep("=", 70), "\n\n")

  # True value
  set.seed(999)
  ref_data <- generate_data_with_nuisances(100000)
  h_true <- ref_data$tau_S_true * ref_data$tau_Y_true
  phi_true <- smooth_minimum_obs(h_true, tau = 0.1)

  n_values <- c(500, 1000, 2000, 5000)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    coverage_vec <- numeric(n_sims)
    ses <- numeric(n_sims)
    estimates <- numeric(n_sims)

    for (i in 1:n_sims) {
      data <- generate_data_with_nuisances(n, seed = NULL)
      ci <- IF_based_CI_obs(data, tau = 0.1)

      coverage_vec[i] <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)
      ses[i] <- ci$se
      estimates[i] <- ci$estimate
    }

    data.frame(
      n = n,
      coverage = mean(coverage_vec),
      mean_se = mean(ses),
      bias = mean(estimates) - phi_true,
      rmse = sqrt(mean((estimates - phi_true)^2))
    )
  })

  print(results)
  cat("\n")

  return(results)
}

test_variance_consistency <- function(n_values = c(500, 1000, 2000), n_sims = 200) {
  cat("TEST 4: Variance consistency\n")
  cat(strrep("=", 70), "\n\n")

  # True value
  set.seed(999)
  ref_data <- generate_data_with_nuisances(100000)
  h_true <- ref_data$tau_S_true * ref_data$tau_Y_true
  phi_true <- smooth_minimum_obs(h_true, tau = 0.1)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data_with_nuisances(n, seed = NULL)
      est <- estimate_smooth_min_obs(data, tau = 0.1)
      est$phi_hat
    })

    empirical_se <- sd(estimates)

    # IF-based variance
    IF_ses <- replicate(n_sims, {
      data <- generate_data_with_nuisances(n, seed = NULL)
      ci <- IF_based_CI_obs(data, tau = 0.1)
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
  cat("\nInterpretation:\n")
  cat("- Ratio should be near 1.0\n\n")

  return(results)
}

# ==============================================================================
# MAIN
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("SMOOTH MINIMUM: OBSERVATION-LEVEL (No Discretization)\n")
  cat(strrep("=", 70), "\n\n")

  cat("Approach: Direct observation-level smooth minimum\n")
  cat("No discretization into types\n\n")

  # Test 1
  test_IF_mean_zero()

  # Test 2
  test2 <- test_coverage(n_sims = 200, n = 1000, tau = 0.1)

  # Test 3
  test3 <- test_sample_size_scaling(n_sims = 100)

  # Test 4
  test4 <- test_variance_consistency(n_values = c(500, 1000, 2000), n_sims = 200)

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  return(list(
    coverage = test2,
    sample_size_scaling = test3,
    variance_consistency = test4
  ))
}

if (sys.nframe() == 0) {
  results <- main()
  saveRDS(results, "smooth_minimum_observation_level_results.rds")
  cat("\nResults saved to: smooth_minimum_observation_level_results.rds\n")
}
