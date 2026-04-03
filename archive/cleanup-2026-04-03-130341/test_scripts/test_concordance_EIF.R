#!/usr/bin/env Rscript
# Test EIF for E[tau_S(X) * tau_Y(X)] with cross-fitting
# This is the simplest case - no nested expectations, just concordance

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

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat,
       mu_S1_hat = mu_S1_hat, mu_S0_hat = mu_S0_hat,
       mu_Y1_hat = mu_Y1_hat, mu_Y0_hat = mu_Y0_hat)
}

# ==============================================================================
# Estimator: E[tau_S(X) * tau_Y(X)]
# ==============================================================================

estimate_concordance <- function(tau_S_hat, tau_Y_hat) {
  mean(tau_S_hat * tau_Y_hat)
}

# ==============================================================================
# IF for Treatment Effect
# ==============================================================================

compute_IF_tau <- function(obs, outcome, mu1_hat, mu0_hat) {
  A <- obs$A
  Y <- obs[[outcome]]
  e <- 0.5

  IF_val <- A * (Y - mu1_hat) / e - (1 - A) * (Y - mu0_hat) / (1 - e)
  return(IF_val)
}

# ==============================================================================
# IF for Concordance: Product Rule
#
# psi = E[tau_S(X) * tau_Y(X)]
#
# IF(O) = tau_S(X) * IF_tau_Y(O) + tau_Y(X) * IF_tau_S(O) +
#         tau_S(X) * tau_Y(X) - psi
# ==============================================================================

compute_IF_concordance <- function(test_data, nuisances) {
  n <- nrow(test_data)

  tau_S_hat <- nuisances$tau_S_hat
  tau_Y_hat <- nuisances$tau_Y_hat

  # Concordance estimate
  psi_hat <- mean(tau_S_hat * tau_Y_hat)

  # IF for each observation
  IF_vals <- numeric(n)

  for (i in 1:n) {
    obs <- test_data[i, ]

    # IF for tau_S(X_i)
    IF_tau_S_i <- compute_IF_tau(obs, "S", nuisances$mu_S1_hat[i],
                                  nuisances$mu_S0_hat[i])

    # IF for tau_Y(X_i)
    IF_tau_Y_i <- compute_IF_tau(obs, "Y", nuisances$mu_Y1_hat[i],
                                  nuisances$mu_Y0_hat[i])

    # Product rule for concordance
    # IF = tau_Y * IF_tau_S + tau_S * IF_tau_Y + (tau_S * tau_Y - psi)
    IF_vals[i] <- tau_Y_hat[i] * IF_tau_S_i +
                  tau_S_hat[i] * IF_tau_Y_i +
                  (tau_S_hat[i] * tau_Y_hat[i] - psi_hat)
  }

  return(IF_vals)
}

# ==============================================================================
# Cross-Fitting Estimation
# ==============================================================================

estimate_concordance_crossfit <- function(data, K = 5) {
  n <- nrow(data)

  # Create folds
  fold_ids <- sample(rep(1:K, length.out = n))

  # Storage
  all_concordance <- numeric(K)
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

    # Concordance on this fold
    concordance_k <- estimate_concordance(nuisances$tau_S_hat,
                                          nuisances$tau_Y_hat)
    all_concordance[k] <- concordance_k

    # IF on this fold
    IF_k <- compute_IF_concordance(test_data, nuisances)

    # Center within fold
    IF_k <- IF_k - mean(IF_k)

    all_IF[test_idx] <- IF_k
  }

  # Overall estimate
  psi_star <- mean(all_concordance)

  # Variance from IF
  sigma_sq <- mean(all_IF^2)
  se <- sqrt(sigma_sq / n)

  list(psi_star = psi_star, se = se, IF_vals = all_IF)
}

IF_based_CI_concordance <- function(data, K = 5, alpha = 0.05) {
  result <- estimate_concordance_crossfit(data, K)

  z_crit <- qnorm(1 - alpha/2)
  ci_lower <- result$psi_star - z_crit * result$se
  ci_upper <- result$psi_star + z_crit * result$se

  list(estimate = result$psi_star, se = result$se,
       ci_lower = ci_lower, ci_upper = ci_upper,
       IF_vals = result$IF_vals)
}

# ==============================================================================
# TESTS
# ==============================================================================

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero for E[tau_S * tau_Y]\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  result <- estimate_concordance_crossfit(data, K = 5)

  cat("Mean of IF:", sprintf("%.8f", mean(result$IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(result$IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(result$IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(result$IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500) {
  cat("TEST 2: Coverage for E[tau_S * tau_Y]\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "\n\n")

  # True value
  # E[tau_S * tau_Y] where tau_S = 0.3 + 0.2*X, tau_Y = 0.4 + 0.3*X
  # = E[(0.3 + 0.2*X)(0.4 + 0.3*X)]
  # = 0.12 + 0.09*E[X] + 0.08*E[X] + 0.06*E[X^2]
  # = 0.12 + 0 + 0 + 0.06*1 = 0.18
  psi_true <- 0.18

  cat("True E[tau_S * tau_Y]:", sprintf("%.6f", psi_true), "\n\n")

  # Simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI_concordance(data, K = 5)

    covered <- (psi_true >= ci$ci_lower && psi_true <= ci$ci_upper)

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
  cat("Bias:         ", sprintf("%.6f", mean_estimate - psi_true), "\n")
  cat("Mean SE:      ", sprintf("%.6f", mean_se), "\n")
  cat("Coverage rate:", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width:", sprintf("%.6f", mean(ci_widths)), "\n")
  cat("Target:       95.0%\n")

  passed <- abs(coverage_rate - 0.95) < 0.10
  cat("\n", ifelse(passed, "✓ PASS", "✗ FAIL"), "\n\n")

  list(coverage_rate = coverage_rate, mean_estimate = mean_estimate,
       psi_true = psi_true)
}

test_variance_consistency <- function(n_values = c(200, 300, 500), n_sims = 50) {
  cat("TEST 3: Variance consistency for E[tau_S * tau_Y]\n")
  cat(strrep("=", 70), "\n\n")

  psi_true <- 0.18

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      result <- estimate_concordance_crossfit(data, K = 5)
      result$psi_star
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI_concordance(data, K = 5)
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
  cat("TEST EIF FOR CONCORDANCE E[tau_S(X) * tau_Y(X)]\n")
  cat(strrep("=", 70), "\n\n")

  cat("Estimand: E[tau_S(X) * tau_Y(X)]\n")
  cat("where tau_S(X) = 0.3 + 0.2*X, tau_Y(X) = 0.4 + 0.3*X\n")
  cat("True value: 0.18\n\n")

  cat("Approach: K-fold cross-fitting (K=5) with linear regression\n")
  cat("IF: Product rule for tau_S * tau_Y\n\n")

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
  saveRDS(results, "concordance_EIF_results.rds")
  cat("\nResults saved to: concordance_EIF_results.rds\n")
}
