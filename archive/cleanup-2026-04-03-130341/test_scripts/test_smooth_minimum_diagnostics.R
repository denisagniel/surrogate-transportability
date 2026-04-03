#!/usr/bin/env Rscript
# Diagnostic Tests for Smooth Minimum Undercoverage
# Goal: Identify why coverage is 89% instead of 95%

library(tidyverse)
source("test_smooth_minimum_oracle.R")

# ==============================================================================
# DIAGNOSTIC 1: Bootstrap Sample Size
# ==============================================================================

diagnostic_1_bootstrap_size <- function() {
  cat("DIAGNOSTIC 1: Does B_boot matter?\n")
  cat("Testing B ∈ {200, 500, 1000, 2000}\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau = 0.1)

  B_values <- c(200, 500, 1000, 2000)
  n_sims <- 50

  results <- map_df(B_values, function(B) {
    cat("Testing B =", B, "...\n")

    coverage_vec <- replicate(n_sims, {
      data <- generate_data_oracle(500, seed = NULL)
      ci <- bootstrap_CI(data, tau = 0.1, B = B, use_oracle = FALSE)
      (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)
    })

    data.frame(
      B = B,
      coverage = mean(coverage_vec),
      n_sims = n_sims
    )
  })

  print(results)

  cat("\nInterpretation:\n")
  cat("If coverage increases with B, bootstrap is undersampled\n")
  cat("If coverage stable, issue is elsewhere\n\n")

  return(results)
}

# ==============================================================================
# DIAGNOSTIC 2: Sample Size Effect
# ==============================================================================

diagnostic_2_sample_size <- function() {
  cat("DIAGNOSTIC 2: Does n matter?\n")
  cat("Testing n ∈ {250, 500, 1000, 2000}\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau = 0.1)

  n_values <- c(250, 500, 1000, 2000)
  n_sims <- 30  # Fewer reps for large n

  results <- map_df(n_values, function(n) {
    cat("Testing n =", n, "...\n")

    coverage_vec <- replicate(n_sims, {
      data <- generate_data_oracle(n, seed = NULL)
      ci <- bootstrap_CI(data, tau = 0.1, B = 500, use_oracle = FALSE)
      (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)
    })

    data.frame(
      n = n,
      coverage = mean(coverage_vec),
      n_sims = n_sims
    )
  })

  print(results)

  cat("\nInterpretation:\n")
  cat("If coverage increases with n, asymptotic approximation improves\n")
  cat("If coverage stable <95%, systematic bias issue\n\n")

  return(results)
}

# ==============================================================================
# DIAGNOSTIC 3: Tau Value Effect
# ==============================================================================

diagnostic_3_tau_values <- function() {
  cat("DIAGNOSTIC 3: Does tau matter for coverage?\n")
  cat("Testing tau ∈ {0.05, 0.1, 0.2, 0.5}\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)

  tau_values <- c(0.05, 0.1, 0.2, 0.5)
  n_sims <- 50

  results <- map_df(tau_values, function(tau) {
    cat("Testing tau =", tau, "...\n")

    phi_true <- smooth_minimum(h_true, tau)

    coverage_vec <- replicate(n_sims, {
      data <- generate_data_oracle(500, seed = NULL)
      ci <- bootstrap_CI(data, tau = tau, B = 500, use_oracle = FALSE)
      (phi_true >= ci$ci_lower && phi_true <= ci$ci_upper)
    })

    data.frame(
      tau = tau,
      phi_true = phi_true,
      coverage = mean(coverage_vec),
      n_sims = n_sims
    )
  })

  print(results)

  cat("\nInterpretation:\n")
  cat("If coverage varies with tau, smoothing parameter affects inference\n")
  cat("Look for tau with best coverage\n\n")

  return(results)
}

# ==============================================================================
# DIAGNOSTIC 4: Analytical CI vs Bootstrap
# ==============================================================================

diagnostic_4_analytical_ci <- function() {
  cat("DIAGNOSTIC 4: Analytical CI using IF variance\n")
  cat("Compare to bootstrap CI\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau = 0.1)

  n_sims <- 50
  n <- 500

  results <- replicate(n_sims, {
    data <- generate_data_oracle(n, seed = NULL)

    # Estimate
    est <- estimate_smooth_minimum(data, tau = 0.1, use_oracle = FALSE)

    # IF-based variance
    IF_vals <- compute_IF_smooth_min(data, est$h_j, tau = 0.1)
    sigma_sq <- mean(IF_vals^2)
    se <- sqrt(sigma_sq / n)

    # Analytical CI
    ci_lower_analytical <- est$phi_hat - 1.96 * se
    ci_upper_analytical <- est$phi_hat + 1.96 * se
    covered_analytical <- (phi_true >= ci_lower_analytical &&
                          phi_true <= ci_upper_analytical)

    # Bootstrap CI
    ci_boot <- bootstrap_CI(data, tau = 0.1, B = 500, use_oracle = FALSE)
    covered_bootstrap <- (phi_true >= ci_boot$ci_lower &&
                         phi_true <= ci_boot$ci_upper)

    data.frame(
      estimate = est$phi_hat,
      covered_analytical = covered_analytical,
      covered_bootstrap = covered_bootstrap,
      width_analytical = ci_upper_analytical - ci_lower_analytical,
      width_bootstrap = ci_boot$ci_upper - ci_boot$ci_lower
    )
  }, simplify = FALSE) %>% bind_rows()

  cat("Analytical CI coverage: ", sprintf("%.1f%%", mean(results$covered_analytical) * 100), "\n")
  cat("Bootstrap CI coverage:  ", sprintf("%.1f%%", mean(results$covered_bootstrap) * 100), "\n")
  cat("Mean width analytical:  ", sprintf("%.4f", mean(results$width_analytical)), "\n")
  cat("Mean width bootstrap:   ", sprintf("%.4f", mean(results$width_bootstrap)), "\n\n")

  cat("Interpretation:\n")
  cat("If analytical > bootstrap: Bootstrap is anti-conservative\n")
  cat("If analytical ≈ bootstrap: Both have same issue\n")
  cat("If analytical < bootstrap: IF variance estimate may be wrong\n\n")

  return(results)
}

# ==============================================================================
# DIAGNOSTIC 5: Check for Bias in Bootstrap Distribution
# ==============================================================================

diagnostic_5_bootstrap_bias <- function() {
  cat("DIAGNOSTIC 5: Is bootstrap distribution centered correctly?\n\n")

  h_true <- c(0.06, 0.20, 0.18, 0.02)
  phi_true <- smooth_minimum(h_true, tau = 0.1)

  # Single dataset, many bootstrap samples
  data <- generate_data_oracle(500, seed = 123)
  est_orig <- estimate_smooth_minimum(data, tau = 0.1, use_oracle = FALSE)

  cat("Original estimate:", sprintf("%.4f", est_orig$phi_hat), "\n")
  cat("True value:       ", sprintf("%.4f", phi_true), "\n")
  cat("Bias:             ", sprintf("%.4f", est_orig$phi_hat - phi_true), "\n\n")

  # Generate many bootstrap samples
  B <- 2000
  boot_estimates <- replicate(B, {
    boot_indices <- sample(1:nrow(data), nrow(data), replace = TRUE)
    boot_data <- data[boot_indices, ]
    est <- estimate_smooth_minimum(boot_data, tau = 0.1, use_oracle = FALSE)
    est$phi_hat
  })

  mean_boot <- mean(boot_estimates)
  sd_boot <- sd(boot_estimates)

  cat("Bootstrap distribution:\n")
  cat("  Mean:        ", sprintf("%.4f", mean_boot), "\n")
  cat("  SD:          ", sprintf("%.4f", sd_boot), "\n")
  cat("  Centered at: ", sprintf("%.4f", est_orig$phi_hat), "\n")
  cat("  Bias in boot:", sprintf("%.4f", mean_boot - est_orig$phi_hat), "\n\n")

  # Percentile CI
  ci_lower <- quantile(boot_estimates, 0.025)
  ci_upper <- quantile(boot_estimates, 0.975)

  cat("Percentile CI:  [", sprintf("%.4f", ci_lower), ",", sprintf("%.4f", ci_upper), "]\n")
  cat("Contains truth: ", (phi_true >= ci_lower && phi_true <= ci_upper), "\n\n")

  # Plot
  hist(boot_estimates, breaks = 50, freq = FALSE,
       main = "Bootstrap Distribution",
       xlab = "phi_tau")
  abline(v = est_orig$phi_hat, col = "blue", lwd = 2)
  abline(v = phi_true, col = "red", lwd = 2, lty = 2)
  abline(v = c(ci_lower, ci_upper), col = "green", lwd = 2, lty = 3)
  legend("topright",
         legend = c("Estimate", "Truth", "95% CI"),
         col = c("blue", "red", "green"),
         lwd = 2, lty = c(1, 2, 3))

  cat("Interpretation:\n")
  cat("If bootstrap mean ≠ original estimate: Bootstrap not centered\n")
  cat("If CI doesn't contain truth: Systematic issue\n\n")

  return(list(
    boot_estimates = boot_estimates,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    truth = phi_true,
    estimate = est_orig$phi_hat
  ))
}

# ==============================================================================
# MAIN RUNNER
# ==============================================================================

run_all_diagnostics <- function() {
  cat(strrep("=", 70), "\n")
  cat("SMOOTH MINIMUM COVERAGE DIAGNOSTICS\n")
  cat(strrep("=", 70), "\n\n")

  cat("Goal: Understand why coverage is 89% instead of 95%\n\n")

  # Run diagnostics
  cat(strrep("-", 70), "\n")
  diag1 <- diagnostic_1_bootstrap_size()

  cat(strrep("-", 70), "\n")
  diag2 <- diagnostic_2_sample_size()

  cat(strrep("-", 70), "\n")
  diag3 <- diagnostic_3_tau_values()

  cat(strrep("-", 70), "\n")
  diag4 <- diagnostic_4_analytical_ci()

  cat(strrep("-", 70), "\n")
  diag5 <- diagnostic_5_bootstrap_bias()

  cat(strrep("=", 70), "\n")
  cat("DIAGNOSTICS COMPLETE\n")
  cat(strrep("=", 70), "\n")

  results <- list(
    bootstrap_size = diag1,
    sample_size = diag2,
    tau_values = diag3,
    analytical_ci = diag4,
    bootstrap_bias = diag5
  )

  return(results)
}

# Run if called as script
if (sys.nframe() == 0) {
  results <- run_all_diagnostics()

  # Save results
  saveRDS(results, "smooth_minimum_diagnostics_results.rds")
  cat("\nResults saved to: smooth_minimum_diagnostics_results.rds\n")
}
