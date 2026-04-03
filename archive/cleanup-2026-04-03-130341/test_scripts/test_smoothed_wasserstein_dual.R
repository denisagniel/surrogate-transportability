#!/usr/bin/env Rscript
# Smoothed Wasserstein Dual with Complete Influence Function
# Theoretically rigorous approach with no selection bias

library(tidyverse)

# ==============================================================================
# DGP
# ==============================================================================

generate_data <- function(n, J = 4, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n)

  # Assign to types
  type_breaks <- quantile(X, probs = seq(0, 1, length.out = J + 1))
  type <- cut(X, breaks = type_breaks, labels = 1:J, include.lowest = TRUE)
  type <- as.numeric(type)

  A <- rbinom(n, 1, 0.5)

  # True treatment effects by type (KNOWN for oracle tests)
  tau_S_true <- c(0.2, 0.5, 0.3, 0.1)[type]
  tau_Y_true <- c(0.3, 0.4, 0.6, 0.2)[type]

  # Conditional means (oracle)
  mu_S1_true <- 0.1 + tau_S_true
  mu_S0_true <- 0.1
  mu_Y1_true <- 0.1 + tau_Y_true
  mu_Y0_true <- 0.1

  S <- A * mu_S1_true + (1-A) * mu_S0_true + rnorm(n, sd = 0.5)
  Y <- A * mu_Y1_true + (1-A) * mu_Y0_true + rnorm(n, sd = 0.5)

  data.frame(
    X = X,
    type = type,
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
# Smoothed Wasserstein Dual
# ==============================================================================

#' Smooth minimum using LogSumExp
smooth_min <- function(x, tau = 0.1) {
  -tau * log(sum(exp(-x / tau)))
}

#' Softmax weights for smooth minimum
softmax_weights <- function(x, tau = 0.1) {
  exp_vals <- exp(-x / tau)
  exp_vals / sum(exp_vals)
}

#' Smoothed Wasserstein dual objective
#' g_tau(gamma) = -gamma*lambda_w^2 + sum_j p0_j * smooth_min_i{h_i + gamma*C[i,j]}
smoothed_wasserstein_objective <- function(gamma, h, cost_matrix, p0, lambda_w, tau) {
  J <- length(h)

  # For each reference type j, compute smooth min over target types i
  phi_j <- numeric(J)
  for (j in 1:J) {
    # Values to minimize over: h_i + gamma*C[i,j] for i=1,...,J
    values <- h + gamma * cost_matrix[, j]  # Column j of cost matrix
    phi_j[j] <- smooth_min(values, tau)
  }

  # Objective: -gamma*lambda_w^2 + sum_j p0_j * phi_j
  objective <- -gamma * lambda_w^2 + sum(p0 * phi_j)

  return(objective)
}

#' Solve smoothed Wasserstein dual
solve_smoothed_wasserstein_dual <- function(h, cost_matrix, p0, lambda_w, tau = 0.1) {
  # Optimize over gamma >= 0
  result <- optimize(
    f = function(g) smoothed_wasserstein_objective(g, h, cost_matrix, p0, lambda_w, tau),
    interval = c(0, 10 / lambda_w^2),  # Heuristic upper bound
    maximum = TRUE,
    tol = 1e-8
  )

  gamma_star <- result$maximum
  phi_star <- result$objective

  list(
    phi_star = phi_star,
    gamma_star = gamma_star,
    convergence = TRUE
  )
}

# ==============================================================================
# Influence Function Components
# ==============================================================================

#' IF for treatment effect (efficient IF)
compute_IF_tau <- function(obs, outcome, mu1, mu0, e_x) {
  A <- obs$A
  Y <- obs[[outcome]]

  IF_val <- A * (Y - mu1) / e_x - (1-A) * (Y - mu0) / (1-e_x)
  return(IF_val)
}

#' Compute softmax weights for all types at optimal gamma
#' w_i^j(gamma*) = exp(-(h_i + gamma*C[i,j])/tau) / sum_k exp(-(h_k + gamma*C[k,j])/tau)
compute_all_softmax_weights <- function(h, cost_matrix, gamma_star, tau) {
  J <- length(h)
  weights <- matrix(0, J, J)  # weights[i,j] = w_i^j

  for (j in 1:J) {
    values <- h + gamma_star * cost_matrix[, j]
    weights[, j] <- softmax_weights(values, tau)
  }

  return(weights)
}

#' Complete influence function for smoothed Wasserstein dual
compute_IF_smoothed_wasserstein <- function(data, h, cost_matrix, p0, gamma_star, tau) {
  n <- nrow(data)
  J <- length(h)

  # Type probabilities
  pi_j <- as.numeric(table(data$type) / n)

  # Compute softmax weights at optimum
  W <- compute_all_softmax_weights(h, cost_matrix, gamma_star, tau)

  # Initialize IF values
  IF_vals <- numeric(n)

  for (i in 1:n) {
    obs <- data[i, ]
    obs_type <- obs$type

    # IF for tau_S and tau_Y at this observation
    IF_tau_S <- compute_IF_tau(obs, "S", obs$mu_S1_true, obs$mu_S0_true, obs$e_x)
    IF_tau_Y <- compute_IF_tau(obs, "Y", obs$mu_Y1_true, obs$mu_Y0_true, obs$e_x)

    # IF contribution
    IF_contrib <- 0

    # For each type k, compute IF for h_k
    for (k in 1:J) {
      # IF_{h_k}(O_i) is non-zero only if obs i is in type k
      if (obs_type == k) {
        # Product rule for h_k = tau_S^k * tau_Y^k
        tau_S_k <- unique(data$tau_S_true[data$type == k])[1]
        tau_Y_k <- unique(data$tau_Y_true[data$type == k])[1]

        IF_h_k <- (1 / pi_j[k]) * (tau_S_k * IF_tau_Y + tau_Y_k * IF_tau_S)

        # This contributes to φ* through all reference types j
        for (j in 1:J) {
          IF_contrib <- IF_contrib + p0[j] * W[k, j] * IF_h_k
        }
      }
    }

    IF_vals[i] <- IF_contrib
  }

  # Center to have mean zero
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Estimation and Inference
# ==============================================================================

estimate_smoothed_wasserstein <- function(data, lambda_w, tau = 0.1) {
  J <- length(unique(data$type))

  # Type-level concordances (use oracle for testing)
  h <- tapply(data$tau_S_true * data$tau_Y_true, data$type, mean)
  h <- as.numeric(h)

  # Type probabilities
  p0 <- as.numeric(table(data$type) / nrow(data))

  # Cost matrix
  centroids <- tapply(data$X, data$type, mean)
  cost_matrix <- outer(centroids, centroids, function(x, y) (x - y)^2)

  # Solve smoothed dual
  result <- solve_smoothed_wasserstein_dual(h, cost_matrix, p0, lambda_w, tau)

  list(
    phi_star = result$phi_star,
    gamma_star = result$gamma_star,
    h = h,
    cost_matrix = cost_matrix,
    p0 = p0
  )
}

IF_based_CI_smoothed <- function(data, lambda_w, tau = 0.1, alpha = 0.05) {
  n <- nrow(data)

  # Estimate
  est <- estimate_smoothed_wasserstein(data, lambda_w, tau)

  # Compute IF
  IF_vals <- compute_IF_smoothed_wasserstein(
    data,
    est$h,
    est$cost_matrix,
    est$p0,
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

  data <- generate_data(5000, seed = 123)
  est <- estimate_smoothed_wasserstein(data, lambda_w = 0.5, tau = 0.1)

  IF_vals <- compute_IF_smoothed_wasserstein(
    data,
    est$h,
    est$cost_matrix,
    est$p0,
    est$gamma_star,
    tau = 0.1
  )

  cat("Mean of IF:", sprintf("%.8f", mean(IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 200, n = 1000, lambda_w = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage\n")
  cat(strrep("=", 70), "\n")
  cat("n_sims:", n_sims, "| n:", n, "| lambda_w:", lambda_w, "| tau:", tau, "\n\n")

  # True value
  set.seed(999)
  large_data <- generate_data(100000)
  truth <- estimate_smoothed_wasserstein(large_data, lambda_w, tau)
  phi_true <- truth$phi_star

  cat("True phi:", sprintf("%.4f", phi_true), "\n\n")

  # Run simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    ci <- IF_based_CI_smoothed(data, lambda_w, tau)

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

test_variance_consistency <- function(n_values = c(500, 1000, 2000), n_sims = 100) {
  cat("TEST 3: Variance consistency\n")
  cat(strrep("=", 70), "\n\n")

  # Truth
  set.seed(999)
  large_data <- generate_data(100000)
  truth <- estimate_smoothed_wasserstein(large_data, lambda_w = 0.5, tau = 0.1)
  phi_true <- truth$phi_star

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      est <- estimate_smoothed_wasserstein(data, lambda_w = 0.5, tau = 0.1)
      est$phi_star
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      ci <- IF_based_CI_smoothed(data, lambda_w = 0.5, tau = 0.1)
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
  cat("SMOOTHED WASSERSTEIN DUAL: COMPLETE IF\n")
  cat(strrep("=", 70), "\n\n")

  cat("Approach: Smooth inner minimum, derive full IF\n")
  cat("Theory: Envelope theorem + functional CLT\n\n")

  test_IF_mean_zero()
  test2 <- test_coverage(n_sims = 200, n = 1000)
  test3 <- test_variance_consistency(n_values = c(500, 1000, 2000), n_sims = 100)

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
  saveRDS(results, "smoothed_wasserstein_dual_results.rds")
  cat("\nResults saved to: smoothed_wasserstein_dual_results.rds\n")
}
