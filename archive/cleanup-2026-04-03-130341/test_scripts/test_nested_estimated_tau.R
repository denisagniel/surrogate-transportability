#!/usr/bin/env Rscript
# Test EIF with ESTIMATED treatment effects tau_S(X), tau_Y(X)
# Complete IF includes: outer + inner + nuisance estimation terms

library(tidyverse)

# ==============================================================================
# DGP with Estimation of Treatment Effects
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Covariates
  X <- rnorm(n, mean = 0, sd = 1)

  # Randomized treatment
  A <- rbinom(n, 1, 0.5)

  # True treatment effects (linear for simplicity)
  tau_S_true <- 0.3 + 0.2 * X
  tau_Y_true <- 0.4 + 0.3 * X

  # Outcomes
  S <- A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- A * tau_Y_true + rnorm(n, sd = 0.5)

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
# Estimate Treatment Effects via Linear Regression
# ==============================================================================

estimate_treatment_effects <- function(data) {
  # Estimate E[S | A=1, X] and E[S | A=0, X]
  fit_S1 <- lm(S ~ X, data = data[data$A == 1, ])
  fit_S0 <- lm(S ~ X, data = data[data$A == 0, ])

  # Estimate E[Y | A=1, X] and E[Y | A=0, X]
  fit_Y1 <- lm(Y ~ X, data = data[data$A == 1, ])
  fit_Y0 <- lm(Y ~ X, data = data[data$A == 0, ])

  # Predict for all observations
  mu_S1_hat <- predict(fit_S1, newdata = data)
  mu_S0_hat <- predict(fit_S0, newdata = data)
  mu_Y1_hat <- predict(fit_Y1, newdata = data)
  mu_Y0_hat <- predict(fit_Y0, newdata = data)

  # Treatment effects
  tau_S_hat <- mu_S1_hat - mu_S0_hat
  tau_Y_hat <- mu_Y1_hat - mu_Y0_hat

  # Concordance
  h_hat <- tau_S_hat * tau_Y_hat

  list(
    tau_S_hat = tau_S_hat,
    tau_Y_hat = tau_Y_hat,
    h_hat = h_hat,
    mu_S1_hat = mu_S1_hat,
    mu_S0_hat = mu_S0_hat,
    mu_Y1_hat = mu_Y1_hat,
    mu_Y0_hat = mu_Y0_hat
  )
}

# ==============================================================================
# Estimator
# ==============================================================================

estimate_nested_estimated_tau <- function(data, gamma = 0.5, tau = 0.1) {
  X <- data$X
  n <- length(X)

  # Estimate treatment effects
  ests <- estimate_treatment_effects(data)
  h <- ests$h_hat

  # For each reference point j, compute inner expectation
  phi_j <- numeric(n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  estimate <- mean(phi_j)

  return(estimate)
}

# ==============================================================================
# Influence Functions for Nuisances
# ==============================================================================

#' IF for treatment effect tau(X) = E[Y|A=1,X] - E[Y|A=0,X]
#' Under randomization with e(X) = 0.5:
#' IF_tau(O) = 2*A*(Y - mu1(X)) - 2*(1-A)*(Y - mu0(X))
compute_IF_tau <- function(data, outcome, mu1_hat, mu0_hat) {
  A <- data$A
  Y <- data[[outcome]]
  e <- 0.5  # Randomized treatment

  IF_val <- A * (Y - mu1_hat) / e - (1 - A) * (Y - mu0_hat) / (1 - e)

  return(IF_val)
}

# ==============================================================================
# Complete Influence Function (Three Terms)
# ==============================================================================

compute_IF_nested_estimated_tau <- function(data, gamma = 0.5, tau = 0.1) {
  X <- data$X
  n <- length(X)

  # Estimate treatment effects
  ests <- estimate_treatment_effects(data)
  h <- ests$h_hat
  tau_S_hat <- ests$tau_S_hat
  tau_Y_hat <- ests$tau_Y_hat

  # Compute m(X_j) for all j
  m_vals <- numeric(n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h + gamma * costs) / tau)
    m_vals[j] <- mean(values)
  }

  # Compute Psi_hat
  psi_hat <- mean(-tau * log(m_vals))

  # Compute softmax weights
  W <- matrix(0, n, n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h + gamma * costs) / tau)
    W[, j] <- values / sum(values)
  }

  # IF for each observation k
  IF_vals <- numeric(n)

  for (k in 1:n) {
    obs <- data[k, ]

    # TERM 1 (OUTER): k as reference point
    term1 <- -tau * log(m_vals[k]) - psi_hat

    # TERM 2 (INNER): k appearing in all other reference points' expectations
    inner_contrib <- numeric(n)
    for (j in 1:n) {
      cost_kj <- (X[k] - X[j])^2
      g_kj <- exp(-(h[k] + gamma * cost_kj) / tau)
      inner_contrib[j] <- -tau * g_kj / m_vals[j]
    }
    term2 <- mean(inner_contrib) + tau

    # TERM 3 (NUISANCE): contribution from estimating h(X_k)
    # IF for h_k = tau_S(X_k) * tau_Y(X_k)
    IF_tau_S_k <- compute_IF_tau(obs, "S", ests$mu_S1_hat[k], ests$mu_S0_hat[k])
    IF_tau_Y_k <- compute_IF_tau(obs, "Y", ests$mu_Y1_hat[k], ests$mu_Y0_hat[k])

    IF_h_k <- tau_S_hat[k] * IF_tau_Y_k + tau_Y_hat[k] * IF_tau_S_k

    # How much does h_k contribute to the overall estimand?
    # Via softmax weights: sum_j W[k,j]
    term3 <- sum(W[k, ]) * IF_h_k

    # Total IF
    IF_vals[k] <- term1 + term2 + term3
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

  estimate <- estimate_nested_estimated_tau(data, gamma, tau)
  IF_vals <- compute_IF_nested_estimated_tau(data, gamma, tau)

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

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero (estimated tau_S, tau_Y)\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  IF_vals <- compute_IF_nested_estimated_tau(data, gamma = 0.5, tau = 0.1)

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500, gamma = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage (estimated tau_S, tau_Y)\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| gamma:", gamma, "| tau:", tau, "\n\n")

  # True value (large sample with oracle)
  set.seed(999)
  large_data <- generate_data(10000)
  large_data$h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  X <- large_data$X
  h <- large_data$h_oracle
  n_large <- length(X)

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- (X - X[j])^2
    values <- exp(-(h + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }
  phi_true <- mean(phi_j)

  cat("True value (n=10000, oracle):", sprintf("%.6f", phi_true), "\n\n")

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
  cat("TEST 3: Variance consistency (estimated tau_S, tau_Y)\n")
  cat(strrep("=", 70), "\n\n")

  gamma <- 0.5
  tau <- 0.1

  # Truth
  set.seed(999)
  large_data <- generate_data(10000)
  large_data$h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  X <- large_data$X
  h <- large_data$h_oracle
  n_large <- length(X)

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- (X - X[j])^2
    values <- exp(-(h + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }
  phi_true <- mean(phi_j)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      estimate_nested_estimated_tau(data, gamma, tau)
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
  cat("TEST WITH ESTIMATED TREATMENT EFFECTS\n")
  cat(strrep("=", 70), "\n\n")

  cat("DGP:\n")
  cat("  tau_S(X) = 0.3 + 0.2*X (linear)\n")
  cat("  tau_Y(X) = 0.4 + 0.3*X (linear)\n")
  cat("  Estimated via linear regression\n\n")

  cat("Complete IF has THREE terms:\n")
  cat("  1. Outer: observation as reference point\n")
  cat("  2. Inner: observation in all inner expectations\n")
  cat("  3. Nuisance: contribution from estimating h(X)\n\n")

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
  saveRDS(results, "nested_estimated_tau_results.rds")
  cat("\nResults saved to: nested_estimated_tau_results.rds\n")
}
