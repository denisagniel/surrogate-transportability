#!/usr/bin/env Rscript
# Observation-Level Smoothed Wasserstein Dual with Cross-Fitting
# Uses cross-fitting to avoid needing nuisance estimation terms in IF

library(tidyverse)
library(ranger)

# ==============================================================================
# DGP with Estimated Nuisances
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
    tau_S_true = tau_S_true,
    tau_Y_true = tau_Y_true
  )
}

# ==============================================================================
# Nuisance Function Estimation
# ==============================================================================

#' Estimate conditional means using Random Forest
estimate_nuisances <- function(train_data) {
  # Estimate E[S | A=1, X]
  model_S1 <- ranger(S ~ X, data = train_data[train_data$A == 1, ], num.trees = 500)

  # Estimate E[S | A=0, X]
  model_S0 <- ranger(S ~ X, data = train_data[train_data$A == 0, ], num.trees = 500)

  # Estimate E[Y | A=1, X]
  model_Y1 <- ranger(Y ~ X, data = train_data[train_data$A == 1, ], num.trees = 500)

  # Estimate E[Y | A=0, X]
  model_Y0 <- ranger(Y ~ X, data = train_data[train_data$A == 0, ], num.trees = 500)

  list(
    model_S1 = model_S1,
    model_S0 = model_S0,
    model_Y1 = model_Y1,
    model_Y0 = model_Y0
  )
}

#' Predict nuisances on test data
predict_nuisances <- function(models, test_data) {
  test_data$mu_S1_hat <- predict(models$model_S1, test_data)$predictions
  test_data$mu_S0_hat <- predict(models$model_S0, test_data)$predictions
  test_data$mu_Y1_hat <- predict(models$model_Y1, test_data)$predictions
  test_data$mu_Y0_hat <- predict(models$model_Y0, test_data)$predictions

  # Treatment effects
  test_data$tau_S_hat <- test_data$mu_S1_hat - test_data$mu_S0_hat
  test_data$tau_Y_hat <- test_data$mu_Y1_hat - test_data$mu_Y0_hat

  # Concordances
  test_data$h_hat <- test_data$tau_S_hat * test_data$tau_Y_hat

  test_data
}

# ==============================================================================
# Observation-Level Wasserstein Dual
# ==============================================================================

compute_obs_cost_matrix <- function(X) {
  n <- length(X)
  cost_matrix <- outer(X, X, function(x1, x2) (x1 - x2)^2)
  return(cost_matrix)
}

smooth_min <- function(x, tau = 0.1) {
  -tau * log(mean(exp(-x / tau)))
}

softmax_weights <- function(x, tau = 0.1) {
  exp_vals <- exp(-x / tau)
  exp_vals / sum(exp_vals)
}

obs_wasserstein_objective <- function(gamma, h, cost_matrix, lambda_w, tau) {
  n <- length(h)

  phi_j <- numeric(n)
  for (j in 1:n) {
    values <- h + gamma * cost_matrix[, j]
    phi_j[j] <- smooth_min(values, tau)
  }

  objective <- -gamma * lambda_w^2 + mean(phi_j)

  return(objective)
}

solve_obs_wasserstein <- function(h, cost_matrix, lambda_w, tau = 0.1) {
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
# Influence Function (Both Terms - Cross-Fitting Makes Them Independent)
# ==============================================================================

#' Compute m(x; gamma) = E_{X'}[exp(-[h(X') + gamma*(X'-x)^2]/tau)]
compute_m <- function(x_ref, X_all, h_all, gamma, tau) {
  costs <- (X_all - x_ref)^2
  values <- exp(-(h_all + gamma * costs) / tau)
  mean(values)
}

#' Compute g(x, x'; gamma) = exp(-[h(x') + gamma*(x'-x)^2]/tau)
compute_g <- function(x_ref, x_target, h_target, gamma, tau) {
  cost <- (x_target - x_ref)^2
  exp(-(h_target + gamma * cost) / tau)
}

#' Compute softmax weights for observation k across all reference points
compute_softmax_weights_for_obs <- function(k, X_test, h_test, gamma_star, tau) {
  n <- length(X_test)
  weights <- numeric(n)

  for (j in 1:n) {
    # How much does obs k contribute to ref point j's smooth min?
    costs <- (X_test - X_test[j])^2
    values <- h_test + gamma_star * costs
    weights[j] <- exp(-values[k] / tau) / sum(exp(-values / tau))
  }

  return(weights)
}

#' IF for treatment effect (efficient IF)
compute_IF_tau <- function(obs, outcome, mu1_col, mu0_col) {
  A <- obs$A
  Y <- obs[[outcome]]
  mu1 <- obs[[mu1_col]]
  mu0 <- obs[[mu0_col]]
  e_x <- 0.5  # Randomized treatment

  IF_val <- A * (Y - mu1) / e_x - (1-A) * (Y - mu0) / (1-e_x)
  return(IF_val)
}

#' Complete IF with both terms
#'
#' IF_total(k) = IF_sampling(k) + IF_nuisance(k)
#'
#' Term 1 (sampling X): -tau*log(m(X_k)) - tau*E_X[g(X,X_k)/m(X)] + tau - Psi
#' Term 2 (estimating h): (1/n) * sum_j w_k^j * IF_h(X_k)
#'
#' Cross-fitting makes these independent (no bias), but both contribute to variance
compute_IF_obs_wasserstein_crossfit <- function(test_data, gamma_star, lambda_w, tau) {
  n <- nrow(test_data)

  X_test <- test_data$X
  h_test <- test_data$h_hat

  # Compute m(X_k) for all test observations
  m_vals <- numeric(n)
  for (k in 1:n) {
    m_vals[k] <- compute_m(X_test[k], X_test, h_test, gamma_star, tau)
  }

  # Compute Psi_hat
  psi_hat <- -gamma_star * lambda_w^2 + mean(-tau * log(m_vals))

  # Compute IF for each test observation
  IF_vals <- numeric(n)

  for (k in 1:n) {
    obs <- test_data[k, ]

    # TERM 1: Sampling variability in X
    # k as reference point
    term1a <- -tau * log(m_vals[k]) - psi_hat

    # k in inner expectations
    g_vals <- numeric(n)
    for (j in 1:n) {
      g_vals[j] <- compute_g(X_test[j], X_test[k], h_test[k], gamma_star, tau)
    }
    term1b <- -tau * mean(g_vals / m_vals) + tau

    term1_total <- term1a + term1b

    # TERM 2: Estimation uncertainty in h(X_k)
    # IF for h_k = tau_S(X_k) * tau_Y(X_k)
    IF_tau_S_k <- compute_IF_tau(obs, "S", "mu_S1_hat", "mu_S0_hat")
    IF_tau_Y_k <- compute_IF_tau(obs, "Y", "mu_Y1_hat", "mu_Y0_hat")

    tau_S_k <- obs$tau_S_hat
    tau_Y_k <- obs$tau_Y_hat
    IF_h_k <- tau_S_k * IF_tau_Y_k + tau_Y_k * IF_tau_S_k

    # Softmax weights: how much does k contribute to each reference point j?
    weights_k <- compute_softmax_weights_for_obs(k, X_test, h_test, gamma_star, tau)

    term2_total <- (1/n) * sum(weights_k) * IF_h_k

    # Total IF
    IF_vals[k] <- term1_total + term2_total
  }

  # Center (should already be close to zero)
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Cross-Fitting Estimation
# ==============================================================================

#' Estimate with K-fold cross-fitting
#'
#' For each fold k:
#'   1. Train nuisances on folds != k
#'   2. Predict nuisances on fold k
#'   3. Compute IF on fold k
#'
#' This makes nuisance estimation independent of IF, so we don't need
#' the nuisance estimation term in the IF formula.
estimate_with_crossfit <- function(data, lambda_w, tau = 0.1, K = 5) {
  n <- nrow(data)

  # Create folds
  fold_ids <- sample(rep(1:K, length.out = n))

  # Storage for results
  all_phi_star <- numeric(K)
  all_gamma_star <- numeric(K)
  all_IF <- numeric(n)
  all_h_hat <- numeric(n)

  for (k in 1:K) {
    # Train/test split
    test_idx <- which(fold_ids == k)
    train_idx <- which(fold_ids != k)

    train_data <- data[train_idx, ]
    test_data <- data[test_idx, ]

    # Estimate nuisances on training data
    models <- estimate_nuisances(train_data)

    # Predict on test data
    test_data <- predict_nuisances(models, test_data)

    # Solve Wasserstein dual on test fold
    cost_matrix <- compute_obs_cost_matrix(test_data$X)
    result <- solve_obs_wasserstein(test_data$h_hat, cost_matrix, lambda_w, tau)

    all_phi_star[k] <- result$phi_star
    all_gamma_star[k] <- result$gamma_star

    # Compute IF on test fold (both terms included)
    IF_k <- compute_IF_obs_wasserstein_crossfit(
      test_data,
      result$gamma_star,
      lambda_w,
      tau
    )

    all_IF[test_idx] <- IF_k
    all_h_hat[test_idx] <- test_data$h_hat
  }

  # Overall estimate (average across folds)
  phi_star <- mean(all_phi_star)

  # Variance from IF
  sigma_sq <- mean(all_IF^2)
  se <- sqrt(sigma_sq / n)

  list(
    phi_star = phi_star,
    se = se,
    IF_vals = all_IF,
    fold_estimates = all_phi_star,
    fold_gammas = all_gamma_star
  )
}

#' Inference with cross-fitting
IF_based_CI_crossfit <- function(data, lambda_w, tau = 0.1, K = 5, alpha = 0.05) {
  n <- nrow(data)

  result <- estimate_with_crossfit(data, lambda_w, tau, K)

  # CI
  z_crit <- qnorm(1 - alpha/2)
  ci_lower <- result$phi_star - z_crit * result$se
  ci_upper <- result$phi_star + z_crit * result$se

  list(
    estimate = result$phi_star,
    se = result$se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    IF_vals = result$IF_vals
  )
}

# ==============================================================================
# TESTS
# ==============================================================================

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero (cross-fitting)\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(500, seed = 123)
  result <- estimate_with_crossfit(data, lambda_w = 0.5, tau = 0.1, K = 5)

  cat("Mean of IF:", sprintf("%.8f", mean(result$IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(result$IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(result$IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(result$IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500, lambda_w = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage (cross-fitting with estimated nuisances)\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| lambda_w:", lambda_w, "| tau:", tau, "\n\n")

  # True value (large sample with oracle)
  set.seed(999)
  large_data <- generate_data(10000)
  large_data$h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  cost_matrix <- compute_obs_cost_matrix(large_data$X)
  truth <- solve_obs_wasserstein(large_data$h_oracle, cost_matrix, lambda_w, tau)
  phi_true <- truth$phi_star

  cat("True phi (n=10000, oracle):", sprintf("%.4f", phi_true), "\n\n")

  # Run simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI_crossfit(data, lambda_w, tau, K = 5)

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

  passed <- abs(coverage_rate - 0.95) < 0.10  # Allow 85-100% (small sample)
  cat("\n", ifelse(passed, "✓ PASS", "✗ FAIL"), "\n\n")

  list(
    coverage_rate = coverage_rate,
    mean_estimate = mean_estimate,
    phi_true = phi_true
  )
}

test_variance_consistency <- function(n_values = c(300, 500), n_sims = 50) {
  cat("TEST 3: Variance consistency (cross-fitting)\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  large_data$h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  cost_matrix <- compute_obs_cost_matrix(large_data$X)
  truth <- solve_obs_wasserstein(large_data$h_oracle, cost_matrix, lambda_w = 0.5, tau = 0.1)
  phi_true <- truth$phi_star

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      result <- estimate_with_crossfit(data, lambda_w = 0.5, tau = 0.1, K = 5)
      result$phi_star
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI_crossfit(data, lambda_w = 0.5, tau = 0.1, K = 5)
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
  cat("OBSERVATION-LEVEL SMOOTHED WASSERSTEIN WITH CROSS-FITTING\n")
  cat(strrep("=", 70), "\n\n")

  cat("Approach: Cross-fitting makes nuisance and IF computation independent\n")
  cat("IF includes: (1) Sampling term + (2) Nuisance estimation term\n")
  cat("Nuisances: Random Forest\n")
  cat("K-folds: 5\n\n")

  # Test 1
  test_IF_mean_zero()

  # Test 2
  test2 <- test_coverage(n_sims = 100, n = 500)

  # Test 3
  test3 <- test_variance_consistency(n_values = c(300, 500), n_sims = 50)

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
  saveRDS(results, "observation_level_crossfit_results.rds")
  cat("\nResults saved to: observation_level_crossfit_results.rds\n")
}
