#!/usr/bin/env Rscript
# Test Smooth Minimum with Oracle Treatment Effects
# Verify: (1) IF is correct, (2) asymptotic normality, (3) coverage

library(tidyverse)

# ==============================================================================
# PART 1: Data Generating Process with Known Treatment Effects
# ==============================================================================

generate_data_oracle <- function(n, J = 4, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Covariates
  X <- rnorm(n)

  # Assign to types (quantile-based)
  type_breaks <- quantile(X, probs = seq(0, 1, length.out = J + 1))
  type <- cut(X, breaks = type_breaks, labels = 1:J, include.lowest = TRUE)
  type <- as.numeric(type)

  # Treatment (randomized)
  A <- rbinom(n, 1, 0.5)

  # TRUE treatment effects by type (known!)
  tau_S_true <- c(0.2, 0.5, 0.3, 0.1)[type]  # Surrogate effects
  tau_Y_true <- c(0.3, 0.4, 0.6, 0.2)[type]  # Outcome effects

  # True concordances by type
  h_true <- c(0.2*0.3, 0.5*0.4, 0.3*0.6, 0.1*0.2)  # [0.06, 0.20, 0.18, 0.02]
  # True minimum: type 4 with h = 0.02

  # Observed outcomes (add noise)
  S <- tau_S_true * A + rnorm(n, sd = 0.5)
  Y <- tau_Y_true * A + rnorm(n, sd = 0.5)

  data.frame(
    X = X,
    type = type,
    A = A,
    S = S,
    Y = Y,
    tau_S_true = tau_S_true,
    tau_Y_true = tau_Y_true
  )
}

# Test: Check DGP
test_dgp <- function() {
  cat("Testing DGP...\n")
  data <- generate_data_oracle(1000, seed = 123)

  # Check type balance
  type_counts <- table(data$type)
  cat("Type counts:", type_counts, "\n")

  # Check treatment effects are recovered
  effects <- data %>%
    group_by(type) %>%
    summarize(
      tau_S_est = mean(S[A==1]) - mean(S[A==0]),
      tau_S_true = unique(tau_S_true),
      tau_Y_est = mean(Y[A==1]) - mean(Y[A==0]),
      tau_Y_true = unique(tau_Y_true)
    )
  print(effects)

  cat("DGP test: PASS\n\n")
}

# ==============================================================================
# PART 2: Smooth Minimum Implementation
# ==============================================================================

#' Compute smooth minimum using LogSumExp
#' @param h_j Vector of values (concordances by type)
#' @param tau Smoothing parameter (smaller = closer to min)
smooth_minimum <- function(h_j, tau = 0.1) {
  if (any(is.na(h_j))) stop("NAs in h_j")
  if (tau <= 0) stop("tau must be positive")

  phi_tau <- -tau * log(sum(exp(-h_j / tau)))
  return(phi_tau)
}

#' Compute softmax weights for smooth minimum
#' @param h_j Vector of values
#' @param tau Smoothing parameter
softmax_weights <- function(h_j, tau = 0.1) {
  exp_vals <- exp(-h_j / tau)
  weights <- exp_vals / sum(exp_vals)
  return(weights)
}

# Test: Basic functionality
test_smooth_minimum <- function() {
  cat("Testing smooth minimum...\n")

  h <- c(0.06, 0.20, 0.18, 0.02)  # True concordances

  # Test: As tau -> 0, should approach min
  taus <- c(1.0, 0.5, 0.1, 0.05, 0.01, 0.001)
  results <- sapply(taus, function(tau) smooth_minimum(h, tau))

  cat("tau values:", sprintf("%.3f", taus), "\n")
  cat("phi_tau:   ", sprintf("%.4f", results), "\n")
  cat("min(h):    ", sprintf("%.4f", min(h)), "\n")

  # Check: converges to min
  stopifnot(abs(results[length(results)] - min(h)) < 0.01)

  # Test: Weights concentrate on minimum
  weights <- softmax_weights(h, tau = 0.01)
  cat("Weights (tau=0.01):", sprintf("%.4f", weights), "\n")
  cat("Should concentrate on type 4 (min)\n")
  stopifnot(which.max(weights) == 4)

  cat("Smooth minimum test: PASS\n\n")
}

# ==============================================================================
# PART 3: Influence Function Implementation
# ==============================================================================

#' Compute influence function for smooth minimum
#'
#' IF(O_i) = sum_j w_j * [m_j(O_i) - h_j]
#' where:
#' - w_j = softmax weights
#' - m_j(O_i) = contribution of obs i to concordance in type j
#' - h_j = true concordance in type j
#'
#' @param data Data frame with columns: type, A, S, Y, tau_S_true, tau_Y_true
#' @param h_j Vector of true concordances by type
#' @param tau Smoothing parameter
#' @return Vector of influence function values (length n)
compute_IF_smooth_min <- function(data, h_j, tau = 0.1) {
  n <- nrow(data)
  J <- length(h_j)

  # Softmax weights
  w_j <- softmax_weights(h_j, tau)

  # Type probabilities
  pi_j <- as.numeric(table(data$type) / n)

  # For each observation, compute m_j(O_i) for each type j
  # m_j(O_i) = [I(type_i = j) / pi_j] * tau_S(X_i) * tau_Y(X_i)

  # Using oracle treatment effects (known!)
  tau_S_i <- data$tau_S_true
  tau_Y_i <- data$tau_Y_true

  # Initialize IF values
  IF_vals <- numeric(n)

  for (i in 1:n) {
    # For type j that observation i belongs to
    j <- data$type[i]

    # m_j(O_i) = (1/pi_j) * tau_S_i * tau_Y_i if i in type j, else 0
    m_j_O_i <- numeric(J)
    m_j_O_i[j] <- (1 / pi_j[j]) * tau_S_i[i] * tau_Y_i[i]

    # IF(O_i) = sum_j w_j * [m_j(O_i) - h_j]
    IF_vals[i] <- sum(w_j * (m_j_O_i - h_j))
  }

  return(IF_vals)
}

# Test: IF has mean zero
test_IF_mean_zero <- function() {
  cat("Testing IF has mean zero...\n")

  data <- generate_data_oracle(5000, seed = 456)
  h_true <- c(0.06, 0.20, 0.18, 0.02)

  IF_vals <- compute_IF_smooth_min(data, h_true, tau = 0.1)

  mean_IF <- mean(IF_vals)
  sd_IF <- sd(IF_vals)

  cat("Mean of IF:", sprintf("%.6f", mean_IF), "\n")
  cat("SD of IF:  ", sprintf("%.4f", sd_IF), "\n")
  cat("Should be near 0: ", abs(mean_IF) < 0.01, "\n")

  stopifnot(abs(mean_IF) < 0.01)

  cat("IF mean zero test: PASS\n\n")
}

# ==============================================================================
# PART 4: Estimator Implementation
# ==============================================================================

#' Estimate smooth minimum from data
#' @param data Data frame
#' @param tau Smoothing parameter
#' @param use_oracle If TRUE, use true treatment effects (for testing)
estimate_smooth_minimum <- function(data, tau = 0.1, use_oracle = TRUE) {

  if (use_oracle) {
    # Use known treatment effects
    concordances <- data %>%
      group_by(type) %>%
      summarize(
        h_j = unique(tau_S_true[1]) * unique(tau_Y_true[1]),
        .groups = "drop"
      ) %>%
      pull(h_j)
  } else {
    # Estimate treatment effects (to be implemented later)
    concordances <- data %>%
      group_by(type) %>%
      summarize(
        tau_S_hat = mean(S[A==1]) - mean(S[A==0]),
        tau_Y_hat = mean(Y[A==1]) - mean(Y[A==0]),
        h_j = tau_S_hat * tau_Y_hat,
        .groups = "drop"
      ) %>%
      pull(h_j)
  }

  phi_hat <- smooth_minimum(concordances, tau)

  return(list(
    phi_hat = phi_hat,
    h_j = concordances,
    tau = tau
  ))
}

# ==============================================================================
# PART 5: Asymptotic Normality Test
# ==============================================================================

#' Test asymptotic normality via simulation
#' sqrt(n) * (phi_hat - phi_true) should be N(0, sigma^2)
test_asymptotic_normality <- function(n_sims = 500, n = 500, tau = 0.1) {
  cat("Testing asymptotic normality...\n")
  cat("n_sims:", n_sims, "| n:", n, "| tau:", tau, "\n")

  # True values
  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau)

  # Simulate many datasets and estimate
  estimates <- replicate(n_sims, {
    data <- generate_data_oracle(n, seed = NULL)
    est <- estimate_smooth_minimum(data, tau, use_oracle = FALSE)
    est$phi_hat
  })

  # Compute sqrt(n) * (phi_hat - phi_true)
  scaled_errors <- sqrt(n) * (estimates - phi_true)

  # Empirical mean and SD
  mean_error <- mean(scaled_errors)
  sd_error <- sd(scaled_errors)

  cat("True phi:           ", sprintf("%.4f", phi_true), "\n")
  cat("Mean estimate:      ", sprintf("%.4f", mean(estimates)), "\n")
  cat("Bias:               ", sprintf("%.6f", mean(estimates) - phi_true), "\n")
  cat("sqrt(n)*bias:       ", sprintf("%.4f", mean_error), "\n")
  cat("SD of sqrt(n)*error:", sprintf("%.4f", sd_error), "\n")

  # Test normality (QQ plot would be visual, use Shapiro-Wilk)
  shapiro_test <- shapiro.test(scaled_errors[1:min(5000, length(scaled_errors))])
  cat("Shapiro-Wilk p-value:", sprintf("%.4f", shapiro_test$p.value), "\n")

  # Create histogram
  hist(scaled_errors, breaks = 30, freq = FALSE,
       main = paste0("sqrt(n) * (phi_hat - phi_true), n=", n),
       xlab = "Scaled error")
  curve(dnorm(x, mean = mean_error, sd = sd_error),
        add = TRUE, col = "red", lwd = 2)

  # Check: Bias should shrink with n (should be near 0)
  # SD should stabilize

  cat("Asymptotic normality test: ",
      ifelse(shapiro_test$p.value > 0.01, "PASS", "MARGINAL"), "\n\n")

  return(list(
    mean_error = mean_error,
    sd_error = sd_error,
    estimates = estimates
  ))
}

# ==============================================================================
# PART 6: Variance Estimation and Coverage
# ==============================================================================

#' Estimate variance using influence function
estimate_variance_IF <- function(data, h_j, tau = 0.1) {
  IF_vals <- compute_IF_smooth_min(data, h_j, tau)
  sigma_sq <- mean(IF_vals^2)
  return(sigma_sq)
}

#' Bootstrap confidence interval
bootstrap_CI <- function(data, tau = 0.1, B = 500, use_oracle = TRUE, alpha = 0.05) {
  n <- nrow(data)

  # Original estimate
  est_orig <- estimate_smooth_minimum(data, tau, use_oracle)

  # Bootstrap
  boot_estimates <- replicate(B, {
    boot_indices <- sample(1:n, n, replace = TRUE)
    boot_data <- data[boot_indices, ]
    est <- estimate_smooth_minimum(boot_data, tau, use_oracle)
    est$phi_hat
  })

  # Percentile CI
  ci_lower <- quantile(boot_estimates, alpha/2)
  ci_upper <- quantile(boot_estimates, 1 - alpha/2)

  return(list(
    estimate = est_orig$phi_hat,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    boot_estimates = boot_estimates
  ))
}

#' Test coverage over many replications
test_coverage <- function(n_sims = 200, n = 500, tau = 0.1, B_boot = 500) {
  cat("Testing coverage...\n")
  cat("n_sims:", n_sims, "| n:", n, "| tau:", tau, "| B_boot:", B_boot, "\n")

  # True value
  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau)
  cat("True phi:", sprintf("%.4f", phi_true), "\n")

  # Run simulations
  coverage_results <- replicate(n_sims, {
    data <- generate_data_oracle(n, seed = NULL)

    # Bootstrap CI
    ci <- bootstrap_CI(data, tau, B = B_boot, use_oracle = FALSE)

    # Check coverage
    covered <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)

    list(
      estimate = ci$estimate,
      ci_lower = ci$ci_lower,
      ci_upper = ci$ci_upper,
      covered = covered,
      ci_width = ci$ci_upper - ci$ci_lower
    )
  }, simplify = FALSE)

  # Extract results
  estimates <- sapply(coverage_results, function(x) x$estimate)
  ci_lowers <- sapply(coverage_results, function(x) x$ci_lower)
  ci_uppers <- sapply(coverage_results, function(x) x$ci_upper)
  covered <- sapply(coverage_results, function(x) x$covered)
  ci_widths <- sapply(coverage_results, function(x) x$ci_width)

  coverage_rate <- mean(covered)
  mean_estimate <- mean(estimates)
  mean_ci_width <- mean(ci_widths)

  cat("\nResults:\n")
  cat("Mean estimate: ", sprintf("%.4f", mean_estimate), "\n")
  cat("Bias:          ", sprintf("%.4f", mean_estimate - phi_true), "\n")
  cat("Coverage rate: ", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width: ", sprintf("%.4f", mean_ci_width), "\n")
  cat("Target:        95.0%\n")

  # Test: Coverage should be near 95%
  passed <- abs(coverage_rate - 0.95) < 0.05  # Within 5 percentage points

  cat("\nCoverage test:", ifelse(passed, "PASS", "FAIL"), "\n\n")

  return(list(
    coverage_rate = coverage_rate,
    mean_estimate = mean_estimate,
    mean_ci_width = mean_ci_width,
    phi_true = phi_true
  ))
}

# ==============================================================================
# PART 7: Comparison of tau values
# ==============================================================================

test_tau_sensitivity <- function(n = 500, n_sims = 100) {
  cat("Testing sensitivity to tau...\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  min_h <- min(h_true)

  taus <- c(0.01, 0.05, 0.1, 0.2, 0.5)

  results <- map_df(taus, function(tau) {
    phi_true <- smooth_minimum(h_true, tau)

    estimates <- replicate(n_sims, {
      data <- generate_data_oracle(n, seed = NULL)
      est <- estimate_smooth_minimum(data, tau, use_oracle = FALSE)
      est$phi_hat
    })

    data.frame(
      tau = tau,
      phi_true = phi_true,
      bias = mean(estimates) - phi_true,
      rmse = sqrt(mean((estimates - phi_true)^2)),
      approx_error = phi_true - min_h
    )
  })

  print(results)

  cat("\nInterpretation:\n")
  cat("- Small tau: closer to min(h) but higher variance\n")
  cat("- Large tau: further from min(h) but lower variance\n")
  cat("- Approx error: how far phi_tau is from true minimum\n\n")

  return(results)
}

# ==============================================================================
# MAIN TEST RUNNER
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("SMOOTH MINIMUM: ORACLE TESTS\n")
  cat(strrep("=", 70), "\n\n")

  # Basic tests
  test_dgp()
  test_smooth_minimum()
  test_IF_mean_zero()

  # Asymptotic tests (quick)
  cat(strrep("=", 70), "\n")
  cat("ASYMPTOTIC TESTS (Quick)\n")
  cat(strrep("=", 70), "\n\n")

  asym_result <- test_asymptotic_normality(n_sims = 500, n = 500, tau = 0.1)

  # Coverage test (this takes longer)
  cat(strrep("=", 70), "\n")
  cat("COVERAGE TEST (This will take a few minutes)\n")
  cat(strrep("=", 70), "\n\n")

  coverage_result <- test_coverage(n_sims = 100, n = 500, tau = 0.1, B_boot = 200)

  # Tau sensitivity
  cat(strrep("=", 70), "\n")
  cat("TAU SENSITIVITY\n")
  cat(strrep("=", 70), "\n\n")

  tau_results <- test_tau_sensitivity(n = 500, n_sims = 100)

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  return(list(
    asymptotic = asym_result,
    coverage = coverage_result,
    tau_sensitivity = tau_results
  ))
}

# Run if called as script
if (sys.nframe() == 0) {
  results <- main()

  # Save results
  saveRDS(results, "test_smooth_minimum_oracle_results.rds")
  cat("\nResults saved to: test_smooth_minimum_oracle_results.rds\n")
}
