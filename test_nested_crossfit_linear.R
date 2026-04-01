#!/usr/bin/env Rscript
# Test EIF with CROSS-FITTING and LINEAR REGRESSION
# This should avoid both the bias (RF) and variance (no cross-fit) problems

library(tidyverse)

# ==============================================================================
# DGP
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)

  # True linear treatment effects
  tau_S_true <- 0.3 + 0.2 * X
  tau_Y_true <- 0.4 + 0.3 * X

  S <- A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- A * tau_Y_true + rnorm(n, sd = 0.5)

  data.frame(X = X, A = A, S = S, Y = Y,
             tau_S_true = tau_S_true, tau_Y_true = tau_Y_true)
}

# ==============================================================================
# Nuisance Estimation
# ==============================================================================

estimate_nuisances_linear <- function(train_data) {
  fit_S1 <- lm(S ~ X, data = train_data[train_data$A == 1, ])
  fit_S0 <- lm(S ~ X, data = train_data[train_data$A == 0, ])
  fit_Y1 <- lm(Y ~ X, data = train_data[train_data$A == 1, ])
  fit_Y0 <- lm(Y ~ X, data = train_data[train_data$A == 0, ])

  list(fit_S1 = fit_S1, fit_S0 = fit_S0,
       fit_Y1 = fit_Y1, fit_Y0 = fit_Y0)
}

predict_nuisances <- function(fits, test_data) {
  mu_S1_hat <- predict(fits$fit_S1, newdata = test_data)
  mu_S0_hat <- predict(fits$fit_S0, newdata = test_data)
  mu_Y1_hat <- predict(fits$fit_Y1, newdata = test_data)
  mu_Y0_hat <- predict(fits$fit_Y0, newdata = test_data)

  tau_S_hat <- mu_S1_hat - mu_S0_hat
  tau_Y_hat <- mu_Y1_hat - mu_Y0_hat
  h_hat <- tau_S_hat * tau_Y_hat

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat, h_hat = h_hat,
       mu_S1_hat = mu_S1_hat, mu_S0_hat = mu_S0_hat,
       mu_Y1_hat = mu_Y1_hat, mu_Y0_hat = mu_Y0_hat)
}

# ==============================================================================
# Wasserstein Dual Estimator
# ==============================================================================

estimate_dual_on_fold <- function(test_data, h_hat, gamma = 0.5, tau = 0.1) {
  X <- test_data$X
  n <- length(X)

  phi_j <- numeric(n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h_hat + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# ==============================================================================
# IF Computation (Three Terms)
# ==============================================================================

compute_IF_tau <- function(obs, outcome, mu1_hat, mu0_hat) {
  A <- obs$A
  Y <- obs[[outcome]]
  e <- 0.5

  IF_val <- A * (Y - mu1_hat) / e - (1 - A) * (Y - mu0_hat) / (1 - e)
  return(IF_val)
}

compute_IF_on_fold <- function(test_data, h_hat, nuisances, gamma = 0.5, tau = 0.1) {
  X <- test_data$X
  n <- length(X)

  # Compute m(X_j) for all j in test fold
  m_vals <- numeric(n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h_hat + gamma * costs) / tau)
    m_vals[j] <- mean(values)
  }

  # Compute Psi_hat on this fold
  psi_hat <- mean(-tau * log(m_vals))

  # Compute softmax weights
  W <- matrix(0, n, n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h_hat + gamma * costs) / tau)
    W[, j] <- values / sum(values)
  }

  # IF for each observation k in test fold
  IF_vals <- numeric(n)

  for (k in 1:n) {
    obs <- test_data[k, ]

    # TERM 1 (OUTER): k as reference point
    term1 <- -tau * log(m_vals[k]) - psi_hat

    # TERM 2 (INNER): k in all other expectations
    inner_contrib <- numeric(n)
    for (j in 1:n) {
      cost_kj <- (X[k] - X[j])^2
      g_kj <- exp(-(h_hat[k] + gamma * cost_kj) / tau)
      inner_contrib[j] <- -tau * g_kj / m_vals[j]
    }
    term2 <- mean(inner_contrib) + tau

    # TERM 3 (NUISANCE): from estimating h(X_k)
    IF_tau_S_k <- compute_IF_tau(obs, "S", nuisances$mu_S1_hat[k], nuisances$mu_S0_hat[k])
    IF_tau_Y_k <- compute_IF_tau(obs, "Y", nuisances$mu_Y1_hat[k], nuisances$mu_Y0_hat[k])

    IF_h_k <- nuisances$tau_S_hat[k] * IF_tau_Y_k + nuisances$tau_Y_hat[k] * IF_tau_S_k

    term3 <- sum(W[k, ]) * IF_h_k

    # Total
    IF_vals[k] <- term1 + term2 + term3
  }

  return(IF_vals)
}

# ==============================================================================
# Cross-Fitting Estimation
# ==============================================================================

estimate_with_crossfit <- function(data, gamma = 0.5, tau = 0.1, K = 5) {
  n <- nrow(data)

  # Create folds
  fold_ids <- sample(rep(1:K, length.out = n))

  # Storage
  all_phi <- numeric(K)
  all_IF <- numeric(n)

  for (k in 1:K) {
    test_idx <- which(fold_ids == k)
    train_idx <- which(fold_ids != k)

    train_data <- data[train_idx, ]
    test_data <- data[test_idx, ]

    # Estimate nuisances on training data
    fits <- estimate_nuisances_linear(train_data)

    # Predict on test data
    nuisances <- predict_nuisances(fits, test_data)

    # Estimate dual on test fold
    phi_k <- estimate_dual_on_fold(test_data, nuisances$h_hat, gamma, tau)
    all_phi[k] <- phi_k

    # Compute IF on test fold
    IF_k <- compute_IF_on_fold(test_data, nuisances$h_hat, nuisances, gamma, tau)

    # Center within fold
    IF_k <- IF_k - mean(IF_k)

    all_IF[test_idx] <- IF_k
  }

  # Overall estimate (average across folds)
  phi_star <- mean(all_phi)

  # Variance from IF
  sigma_sq <- mean(all_IF^2)
  se <- sqrt(sigma_sq / n)

  list(phi_star = phi_star, se = se, IF_vals = all_IF)
}

IF_based_CI_crossfit <- function(data, gamma = 0.5, tau = 0.1, K = 5, alpha = 0.05) {
  result <- estimate_with_crossfit(data, gamma, tau, K)

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
  cat("TEST 1: IF has mean zero (cross-fitting + linear)\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  result <- estimate_with_crossfit(data, gamma = 0.5, tau = 0.1, K = 5)

  cat("Mean of IF:", sprintf("%.8f", mean(result$IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(result$IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(result$IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(result$IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500, gamma = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage (cross-fitting + linear)\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| gamma:", gamma, "| tau:", tau, "\n\n")

  # True value (large sample with oracle)
  set.seed(999)
  large_data <- generate_data(10000)
  h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  X <- large_data$X
  n_large <- length(X)

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- (X - X[j])^2
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }
  phi_true <- mean(phi_j)

  cat("True value (n=10000, oracle):", sprintf("%.6f", phi_true), "\n\n")

  # Simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI_crossfit(data, gamma, tau, K = 5)

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
  cat("Mean estimate:", sprintf("%.6f", mean_estimate), "\n")
  cat("Bias:         ", sprintf("%.6f", mean_estimate - phi_true), "\n")
  cat("Mean SE:      ", sprintf("%.6f", mean_se), "\n")
  cat("Coverage rate:", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width:", sprintf("%.6f", mean(ci_widths)), "\n")
  cat("Target:       95.0%\n")

  passed <- abs(coverage_rate - 0.95) < 0.10
  cat("\n", ifelse(passed, "✓ PASS", "✗ FAIL"), "\n\n")

  list(coverage_rate = coverage_rate, mean_estimate = mean_estimate,
       phi_true = phi_true)
}

test_variance_consistency <- function(n_values = c(300, 500), n_sims = 50) {
  cat("TEST 3: Variance consistency (cross-fitting + linear)\n")
  cat(strrep("=", 70), "\n\n")

  gamma <- 0.5
  tau <- 0.1

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  X <- large_data$X
  n_large <- length(X)

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- (X - X[j])^2
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }
  phi_true <- mean(phi_j)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      result <- estimate_with_crossfit(data, gamma, tau, K = 5)
      result$phi_star
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI_crossfit(data, gamma, tau, K = 5)
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
  cat("CROSS-FITTING WITH LINEAR REGRESSION\n")
  cat(strrep("=", 70), "\n\n")

  cat("Approach: K-fold cross-fitting (K=5)\n")
  cat("Nuisances: Linear regression (parametric)\n")
  cat("IF: Three terms (outer + inner + nuisance)\n")
  cat("Should avoid both RF bias and no-crossfit variance problems\n\n")

  test_IF_mean_zero()
  test2 <- test_coverage(n_sims = 100, n = 500)
  test3 <- test_variance_consistency(n_values = c(300, 500), n_sims = 50)

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  list(coverage = test2, variance_consistency = test3)
}

if (sys.nframe() == 0) {
  results <- main()
  saveRDS(results, "nested_crossfit_linear_results.rds")
  cat("\nResults saved to: nested_crossfit_linear_results.rds\n")
}
