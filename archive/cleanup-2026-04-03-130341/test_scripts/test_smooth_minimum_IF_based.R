#!/usr/bin/env Rscript
# Smooth Minimum with IF-Based Inference
# Use analytical variance from influence function, not bootstrap

library(tidyverse)
source("test_smooth_minimum_oracle.R")

# ==============================================================================
# IF-Based Confidence Interval
# ==============================================================================

#' Compute confidence interval using influence function variance
#' @param data Data frame
#' @param tau Smoothing parameter
#' @param use_oracle Use oracle treatment effects (for testing)
#' @param alpha Significance level
IF_based_CI <- function(data, tau = 0.1, use_oracle = TRUE, alpha = 0.05) {
  n <- nrow(data)

  # Estimate smooth minimum
  est <- estimate_smooth_minimum(data, tau, use_oracle)

  # Compute influence function for each observation
  IF_vals <- compute_IF_smooth_min(data, est$h_j, tau)

  # Variance estimate
  sigma_sq <- mean(IF_vals^2)  # E[IF^2] since E[IF] = 0
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
    h_j = est$h_j
  ))
}

# ==============================================================================
# TEST 1: Coverage with IF-Based CIs
# ==============================================================================

test_IF_coverage <- function(n_sims = 200, n = 1000, tau = 0.1) {
  cat("Testing IF-based CI coverage\n")
  cat("n_sims:", n_sims, "| n:", n, "| tau:", tau, "\n\n")

  # True values
  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau)
  cat("True phi:", sprintf("%.4f", phi_true), "\n")

  # Run simulations
  results <- replicate(n_sims, {
    data <- generate_data_oracle(n, seed = NULL)

    # IF-based CI
    ci <- IF_based_CI(data, tau, use_oracle = FALSE)

    # Check coverage
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
  ci_lowers <- sapply(results, function(x) x$ci_lower)
  ci_uppers <- sapply(results, function(x) x$ci_upper)
  covered <- sapply(results, function(x) x$covered)
  ci_widths <- sapply(results, function(x) x$ci_width)

  # Summary
  coverage_rate <- mean(covered)
  mean_estimate <- mean(estimates)
  mean_se <- mean(ses)
  mean_ci_width <- mean(ci_widths)

  cat("\nResults:\n")
  cat("Mean estimate:  ", sprintf("%.4f", mean_estimate), "\n")
  cat("Bias:           ", sprintf("%.4f", mean_estimate - phi_true), "\n")
  cat("Mean SE:        ", sprintf("%.4f", mean_se), "\n")
  cat("Coverage rate:  ", sprintf("%.1f%%", coverage_rate * 100), "\n")
  cat("Mean CI width:  ", sprintf("%.4f", mean_ci_width), "\n")
  cat("Target:         95.0%\n")

  # Check if passed
  passed <- abs(coverage_rate - 0.95) < 0.03  # Within 3 percentage points

  cat("\nCoverage test: ", ifelse(passed, "PASS", "FAIL"), "\n\n")

  return(list(
    coverage_rate = coverage_rate,
    mean_estimate = mean_estimate,
    mean_se = mean_se,
    mean_ci_width = mean_ci_width,
    phi_true = phi_true,
    estimates = estimates,
    ses = ses,
    covered = covered
  ))
}

# ==============================================================================
# TEST 2: Sample Size Scaling
# ==============================================================================

test_sample_size_scaling <- function(n_sims = 100) {
  cat("Testing sample size scaling of IF-based CIs\n")
  cat("n_sims:", n_sims, "per sample size\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  tau <- 0.1
  phi_true <- smooth_minimum(h_true, tau)

  n_values <- c(500, 1000, 2000, 5000)

  results <- map_df(n_values, function(n) {
    cat("Testing n =", n, "...\n")

    coverage_vec <- numeric(n_sims)
    estimates <- numeric(n_sims)
    ses <- numeric(n_sims)

    for (i in 1:n_sims) {
      data <- generate_data_oracle(n, seed = NULL)
      ci <- IF_based_CI(data, tau, use_oracle = FALSE)

      coverage_vec[i] <- (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)
      estimates[i] <- ci$estimate
      ses[i] <- ci$se
    }

    data.frame(
      n = n,
      coverage = mean(coverage_vec),
      mean_estimate = mean(estimates),
      bias = mean(estimates) - phi_true,
      mean_se = mean(ses),
      rmse = sqrt(mean((estimates - phi_true)^2))
    )
  })

  print(results)

  cat("\nInterpretation:\n")
  cat("- Coverage should approach 95% as n increases\n")
  cat("- Bias should shrink as 1/sqrt(n)\n")
  cat("- SE should also shrink as 1/sqrt(n)\n\n")

  return(results)
}

# ==============================================================================
# TEST 3: Compare IF-Based vs Bootstrap
# ==============================================================================

compare_IF_vs_bootstrap <- function(n_sims = 100, n = 1000, tau = 0.1) {
  cat("Comparing IF-based vs Bootstrap CIs\n")
  cat("n_sims:", n_sims, "| n:", n, "\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau)

  results <- replicate(n_sims, {
    data <- generate_data_oracle(n, seed = NULL)

    # IF-based
    ci_IF <- IF_based_CI(data, tau, use_oracle = FALSE)
    covered_IF <- (phi_true >= ci_IF$ci_lower && phi_true <= ci_IF$ci_upper)

    # Bootstrap (fewer iterations for speed)
    ci_boot <- bootstrap_CI(data, tau, B = 500, use_oracle = FALSE)
    covered_boot <- (phi_true >= ci_boot$ci_lower && phi_true <= ci_boot$ci_upper)

    data.frame(
      estimate = ci_IF$estimate,
      covered_IF = covered_IF,
      covered_boot = covered_boot,
      width_IF = ci_IF$ci_upper - ci_IF$ci_lower,
      width_boot = ci_boot$ci_upper - ci_boot$ci_lower
    )
  }, simplify = FALSE) %>% bind_rows()

  cat("IF-based coverage:  ", sprintf("%.1f%%", mean(results$covered_IF) * 100), "\n")
  cat("Bootstrap coverage: ", sprintf("%.1f%%", mean(results$covered_boot) * 100), "\n")
  cat("Mean width IF:      ", sprintf("%.4f", mean(results$width_IF)), "\n")
  cat("Mean width boot:    ", sprintf("%.4f", mean(results$width_boot)), "\n")
  cat("Mean estimate:      ", sprintf("%.4f", mean(results$estimate)), "\n")
  cat("True value:         ", sprintf("%.4f", phi_true), "\n\n")

  cat("Interpretation:\n")
  cat("IF-based is theoretically correct and should match asymptotic theory\n")
  cat("Bootstrap is computationally expensive and may have finite-sample issues\n\n")

  return(results)
}

# ==============================================================================
# TEST 4: Verify IF Variance Estimate is Consistent
# ==============================================================================

test_IF_variance_consistency <- function(n_values = c(500, 1000, 2000, 5000),
                                        n_sims = 100) {
  cat("Testing consistency of IF variance estimate\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  tau <- 0.1
  phi_true <- smooth_minimum(h_true, tau)

  results <- map_df(n_values, function(n) {
    cat("n =", n, "...\n")

    # Compute empirical variance of estimates
    estimates <- replicate(n_sims, {
      data <- generate_data_oracle(n, seed = NULL)
      est <- estimate_smooth_minimum(data, tau, use_oracle = FALSE)
      est$phi_hat
    })

    empirical_var <- var(estimates)
    empirical_se <- sd(estimates)

    # Compute average IF-based variance estimate
    IF_ses <- replicate(n_sims, {
      data <- generate_data_oracle(n, seed = NULL)
      ci <- IF_based_CI(data, tau, use_oracle = FALSE)
      ci$se
    })

    mean_IF_se <- mean(IF_ses)

    data.frame(
      n = n,
      empirical_se = empirical_se,
      mean_IF_se = mean_IF_se,
      ratio = mean_IF_se / empirical_se,
      theoretical_se = mean_IF_se / sqrt(n)  # Approximate
    )
  })

  print(results)

  cat("\nInterpretation:\n")
  cat("- Ratio should be near 1.0 (IF estimate matches empirical)\n")
  cat("- Both should shrink as 1/sqrt(n)\n\n")

  return(results)
}

# ==============================================================================
# MAIN RUNNER
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("SMOOTH MINIMUM: IF-BASED INFERENCE\n")
  cat(strrep("=", 70), "\n\n")

  cat("Approach: Use analytical variance from influence function\n")
  cat("Benefit: Theoretically correct, no bootstrap needed\n\n")

  # Test 1: Coverage with larger samples
  cat(strrep("-", 70), "\n")
  cat("TEST 1: Coverage with n=1000\n")
  cat(strrep("-", 70), "\n")
  test1 <- test_IF_coverage(n_sims = 200, n = 1000, tau = 0.1)

  # Test 2: Sample size scaling
  cat(strrep("-", 70), "\n")
  cat("TEST 2: Sample size scaling\n")
  cat(strrep("-", 70), "\n")
  test2 <- test_sample_size_scaling(n_sims = 100)

  # Test 3: IF vs Bootstrap
  cat(strrep("-", 70), "\n")
  cat("TEST 3: IF-based vs Bootstrap\n")
  cat(strrep("-", 70), "\n")
  test3 <- compare_IF_vs_bootstrap(n_sims = 100, n = 1000, tau = 0.1)

  # Test 4: IF variance consistency
  cat(strrep("-", 70), "\n")
  cat("TEST 4: IF variance estimate consistency\n")
  cat(strrep("-", 70), "\n")
  test4 <- test_IF_variance_consistency(
    n_values = c(500, 1000, 2000, 5000),
    n_sims = 100
  )

  cat(strrep("=", 70), "\n")
  cat("ALL TESTS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  return(list(
    coverage_test = test1,
    sample_size_scaling = test2,
    IF_vs_bootstrap = test3,
    variance_consistency = test4
  ))
}

# Run if called as script
if (sys.nframe() == 0) {
  results <- main()

  # Save results
  saveRDS(results, "smooth_minimum_IF_based_results.rds")
  cat("\nResults saved to: smooth_minimum_IF_based_results.rds\n")
}
