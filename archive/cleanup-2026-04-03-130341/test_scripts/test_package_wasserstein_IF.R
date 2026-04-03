#!/usr/bin/env Rscript
# Test the package function for Wasserstein minimax with IF-based inference

# Source the package function
source("package/R/wasserstein_minimax_IF_inference.R")

# ==============================================================================
# DGP (same as test_nested_crossfit_linear.R)
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)

  tau_S_true <- 0.3 + 0.2 * X
  tau_Y_true <- 0.4 + 0.3 * X

  S <- A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- A * tau_Y_true + rnorm(n, sd = 0.5)

  data.frame(X = X, A = A, S = S, Y = Y,
             tau_S_true = tau_S_true, tau_Y_true = tau_Y_true)
}

# ==============================================================================
# TESTS
# ==============================================================================

test_IF_mean_zero <- function() {
  cat("TEST 1: IF has mean zero\n")
  cat(strrep("=", 70), "\n\n")

  data <- generate_data(1000, seed = 123)
  result <- wasserstein_minimax_IF_inference(
    data = data,
    covariates = "X",
    gamma = 0.5,
    tau = 0.1,
    K = 5
  )

  cat("Mean of IF:", sprintf("%.8f", mean(result$IF_vals)), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd(result$IF_vals)), "\n")
  cat("Should be near 0:", abs(mean(result$IF_vals)) < 1e-6, "\n\n")

  stopifnot(abs(mean(result$IF_vals)) < 1e-6)
  cat("✓ PASS\n\n")
}

test_coverage <- function(n_sims = 100, n = 500, gamma = 0.5, tau = 0.1) {
  cat("TEST 2: Coverage\n")
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
    result <- wasserstein_minimax_IF_inference(
      data = data,
      covariates = "X",
      gamma = gamma,
      tau = tau,
      K = 5
    )

    covered <- (phi_true >= result$ci_lower && phi_true <= result$ci_upper)

    list(estimate = result$phi_star, se = result$se, covered = covered,
         ci_width = result$ci_upper - result$ci_lower)
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
  cat("TEST 3: Variance consistency\n")
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

  results <- lapply(n_values, function(n) {
    cat("n =", n, "...\n")

    # Empirical variance
    estimates <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      result <- wasserstein_minimax_IF_inference(
        data = data,
        covariates = "X",
        gamma = gamma,
        tau = tau,
        K = 5
      )
      result$phi_star
    })

    empirical_se <- sd(estimates)

    # IF-based SE
    IF_ses <- replicate(n_sims, {
      data <- generate_data(n, seed = NULL)
      result <- wasserstein_minimax_IF_inference(
        data = data,
        covariates = "X",
        gamma = gamma,
        tau = tau,
        K = 5
      )
      result$se
    })

    mean_IF_se <- mean(IF_ses)

    data.frame(n = n, empirical_se = empirical_se,
               mean_IF_se = mean_IF_se,
               ratio = mean_IF_se / empirical_se)
  })

  results_df <- do.call(rbind, results)
  print(results_df)
  cat("\nInterpretation: Ratio should be near 1.0\n\n")

  results_df
}

# ==============================================================================
# MAIN
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("TEST PACKAGE FUNCTION: wasserstein_minimax_IF_inference\n")
  cat(strrep("=", 70), "\n\n")

  cat("Estimand: min_{Q: W_2(Q,P0)<=lambda_w} E_Q[tau_S(X) * tau_Y(X)]\n")
  cat("Method: Cross-fitting + IF-based inference\n\n")

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
  saveRDS(results, "package_wasserstein_IF_test_results.rds")
  cat("\nResults saved to: package_wasserstein_IF_test_results.rds\n")
}
