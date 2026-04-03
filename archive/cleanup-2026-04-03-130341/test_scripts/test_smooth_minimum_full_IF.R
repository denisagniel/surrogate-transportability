#!/usr/bin/env Rscript
# Smooth Minimum: COMPLETE Influence Function
# Including uncertainty from treatment effect estimation
# Evaluated using ORACLE nuisance functions

library(tidyverse)

# ==============================================================================
# DGP with KNOWN nuisance functions
# ==============================================================================

generate_data_with_nuisances <- function(n, J = 4, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Covariates
  X <- rnorm(n)

  # Assign to types
  type_breaks <- quantile(X, probs = seq(0, 1, length.out = J + 1))
  type <- cut(X, breaks = type_breaks, labels = 1:J, include.lowest = TRUE)
  type <- as.numeric(type)

  # Treatment (randomized) - KNOWN propensity
  e_x <- 0.5  # Constant propensity (randomization)
  A <- rbinom(n, 1, e_x)

  # TRUE conditional means by type (KNOWN)
  # E[S|A=1,X] and E[S|A=0,X]
  mu_S1_true <- c(0.3, 0.6, 0.4, 0.2)[type]  # E[S|A=1,type]
  mu_S0_true <- c(0.1, 0.1, 0.1, 0.1)[type]  # E[S|A=0,type]

  mu_Y1_true <- c(0.4, 0.5, 0.7, 0.3)[type]  # E[Y|A=1,type]
  mu_Y0_true <- c(0.1, 0.1, 0.1, 0.1)[type]  # E[Y|A=0,type]

  # TRUE treatment effects
  tau_S_true <- mu_S1_true - mu_S0_true  # [0.2, 0.5, 0.3, 0.1]
  tau_Y_true <- mu_Y1_true - mu_Y0_true  # [0.3, 0.4, 0.6, 0.2]

  # Observed outcomes (add noise)
  S <- A * mu_S1_true + (1-A) * mu_S0_true + rnorm(n, sd = 0.5)
  Y <- A * mu_Y1_true + (1-A) * mu_Y0_true + rnorm(n, sd = 0.5)

  data.frame(
    X = X,
    type = type,
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
# FULL Influence Function Implementation
# ==============================================================================

#' Compute efficient IF for treatment effect at given observation
#' Using oracle nuisance functions
#'
#' IF_τ(O; X) = A(Y - μ^1(X))/e(X) - (1-A)(Y - μ^0(X))/(1-e(X))
compute_IF_treatment_effect <- function(O, outcome, mu1, mu0, e_x) {
  A <- O$A
  Y <- O[[outcome]]  # S or Y

  IF_val <- A * (Y - mu1) / e_x - (1-A) * (Y - mu0) / (1-e_x)
  return(IF_val)
}

#' Compute FULL influence function for smooth minimum
#' Accounts for estimation of treatment effects
#'
#' IF_φτ(O) = ∑_j w_j · IF_h_j(O)
#' where IF_h_j(O) includes uncertainty from estimating τ_S and τ_Y
compute_IF_smooth_min_FULL <- function(data, h_j, tau = 0.1) {
  n <- nrow(data)
  J <- length(h_j)

  # Softmax weights
  w_j <- softmax_weights(h_j, tau)

  # Type probabilities
  pi_j <- as.numeric(table(data$type) / n)

  # Initialize IF values
  IF_vals <- numeric(n)

  for (i in 1:n) {
    obs <- data[i, ]
    j <- obs$type

    # IF for τ_S at this observation (using oracle nuisances)
    IF_tau_S <- compute_IF_treatment_effect(
      obs,
      outcome = "S",
      mu1 = obs$mu_S1_true,
      mu0 = obs$mu_S0_true,
      e_x = obs$e_x
    )

    # IF for τ_Y at this observation (using oracle nuisances)
    IF_tau_Y <- compute_IF_treatment_effect(
      obs,
      outcome = "Y",
      mu1 = obs$mu_Y1_true,
      mu0 = obs$mu_Y0_true,
      e_x = obs$e_x
    )

    # IF for concordance h(X) = τ_S(X) · τ_Y(X) at this X
    # Product rule: τ_S · IF_τY + τ_Y · IF_τS
    tau_S_i <- obs$tau_S_true
    tau_Y_i <- obs$tau_Y_true
    IF_h_i <- tau_S_i * IF_tau_Y + tau_Y_i * IF_tau_S

    # IF for type-level concordance h_j
    # Only contributes if observation is in type j
    IF_h_j_full <- numeric(J)
    IF_h_j_full[j] <- (1 / pi_j[j]) * IF_h_i - h_j[j]

    # IF for smooth minimum (weighted sum over types)
    IF_vals[i] <- sum(w_j * IF_h_j_full)
  }

  return(IF_vals)
}

#' Helper: softmax weights for smooth minimum
softmax_weights <- function(h_j, tau = 0.1) {
  exp_vals <- exp(-h_j / tau)
  weights <- exp_vals / sum(exp_vals)
  return(weights)
}

#' Helper: smooth minimum
smooth_minimum <- function(h_j, tau = 0.1) {
  phi_tau <- -tau * log(sum(exp(-h_j / tau)))
  return(phi_tau)
}

# ==============================================================================
# Estimation with Oracle Nuisances
# ==============================================================================

#' Estimate smooth minimum using oracle nuisance functions
estimate_smooth_min_oracle <- function(data, tau = 0.1) {
  # Compute type-level concordances using TRUE treatment effects
  concordances <- data %>%
    group_by(type) %>%
    summarize(
      h_j = unique(tau_S_true[1]) * unique(tau_Y_true[1]),
      .groups = "drop"
    ) %>%
    pull(h_j)

  phi_hat <- smooth_minimum(concordances, tau)

  return(list(
    phi_hat = phi_hat,
    h_j = concordances,
    tau = tau
  ))
}

#' IF-based confidence interval using FULL influence function
IF_based_CI_FULL <- function(data, tau = 0.1, alpha = 0.05) {
  n <- nrow(data)

  # Estimate smooth minimum
  est <- estimate_smooth_min_oracle(data, tau)

  # Compute FULL influence function
  IF_vals <- compute_IF_smooth_min_FULL(data, est$h_j, tau)

  # Variance estimate
  sigma_sq <- mean(IF_vals^2)
  se <- sqrt(sigma_sq / n)

  # Normal approximation CI
  z_crit <- qnorm(1 - alpha/2)
  ci_lower <- est$phi_hat - z_crit * se
  ci_upper <- est$phi_hat + z_crit * se

  return(list(
    estimate = est$phi_hat,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    sigma_sq = sigma_sq,
    h_j = est$h_j,
    IF_vals = IF_vals
  ))
}

# ==============================================================================
# TEST 1: Verify IF has mean zero
# ==============================================================================

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data_with_nuisances(5000, seed = 123)

  # True concordances
  h_true <- c(0.2*0.3, 0.5*0.4, 0.3*0.6, 0.1*0.2)

  # Compute full IF
  IF_vals <- compute_IF_smooth_min_FULL(data, h_true, tau = 0.1)

  cat("Mean of IF:  ", sprintf("%.6f", mean(IF_vals)), "\n")
  cat("SD of IF:    ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0: ", abs(mean(IF_vals)) < 0.01, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 0.01)
  cat("✓ PASS\n\n")
}

# ==============================================================================
# TEST 2: Coverage Test
# ==============================================================================

test_coverage_full_IF <- function(n_sims = 200, n = 1000, tau = 0.1) {
  cat("TEST 2: Coverage with FULL IF\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| tau:", tau, "\n\n")

  # True values
  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau)
  cat("True phi:", sprintf("%.4f", phi_true), "\n\n")

  # Run simulations
  results <- replicate(n_sims, {
    data <- generate_data_with_nuisances(n, seed = NULL)

    # IF-based CI with FULL IF
    ci <- IF_based_CI_FULL(data, tau)

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

  # Extract results
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
    mean_se = mean_se,
    phi_true = phi_true
  ))
}

# ==============================================================================
# TEST 3: Sample Size Scaling
# ==============================================================================

test_sample_size_scaling <- function(n_sims = 100) {
  cat("TEST 3: Sample size scaling\n")
  cat(strrep("=", 70), "\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  tau <- 0.1
  phi_true <- smooth_minimum(h_true, tau)

  n_values <- c(500, 1000, 2000, 5000)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    coverage_vec <- numeric(n_sims)
    ses <- numeric(n_sims)
    estimates <- numeric(n_sims)

    for (i in 1:n_sims) {
      data <- generate_data_with_nuisances(n, seed = NULL)
      ci <- IF_based_CI_FULL(data, tau)

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

  cat("\nInterpretation:\n")
  cat("- Coverage should approach 95% as n increases\n")
  cat("- SE should shrink as 1/sqrt(n)\n\n")

  return(results)
}

# ==============================================================================
# TEST 4: Empirical vs IF Variance
# ==============================================================================

test_variance_consistency <- function(n_values = c(500, 1000, 2000), n_sims = 200) {
  cat("TEST 4: Empirical variance vs IF estimate\n")
  cat(strrep("=", 70), "\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  tau <- 0.1

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance of estimates
    estimates <- replicate(n_sims, {
      data <- generate_data_with_nuisances(n, seed = NULL)
      est <- estimate_smooth_min_oracle(data, tau)
      est$phi_hat
    })

    empirical_se <- sd(estimates)

    # Average IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data_with_nuisances(n, seed = NULL)
      ci <- IF_based_CI_FULL(data, tau)
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
  cat("- Ratio should be near 1.0 (IF correctly captures variance)\n")
  cat("- If ratio < 1: IF underestimates (CIs too narrow)\n")
  cat("- If ratio > 1: IF overestimates (CIs too wide)\n\n")

  return(results)
}

# ==============================================================================
# MAIN RUNNER
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("SMOOTH MINIMUM: FULL INFLUENCE FUNCTION\n")
  cat(strrep("=", 70), "\n\n")

  cat("Approach: Complete IF including treatment effect estimation\n")
  cat("Evaluation: Using ORACLE nuisance functions\n\n")

  # Test 1: IF mean zero
  test_IF_mean_zero()

  # Test 2: Coverage
  test2 <- test_coverage_full_IF(n_sims = 200, n = 1000, tau = 0.1)

  # Test 3: Sample size scaling
  test3 <- test_sample_size_scaling(n_sims = 100)

  # Test 4: Variance consistency
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

# Run if called as script
if (sys.nframe() == 0) {
  results <- main()

  saveRDS(results, "smooth_minimum_full_IF_results.rds")
  cat("\nResults saved to: smooth_minimum_full_IF_results.rds\n")
}
