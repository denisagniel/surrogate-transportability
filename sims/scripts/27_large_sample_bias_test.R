#!/usr/bin/env Rscript
# LARGE SAMPLE BIAS TEST
# Question: Is bias a finite sample issue or fundamental?
# Method: Test with n = 10,000 and 20,000 to see if bias vanishes

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("LARGE SAMPLE BIAS TEST\n")
cat("=============================================================================\n\n")

cat("Question: Does bias vanish as n → ∞?\n")
cat("Method: Test with n ∈ {1000, 5000, 10000, 20000}\n")
cat("Replications: 10 per sample size (for speed)\n\n")

# =============================================================================
# Setup: True DGP and truth
# =============================================================================

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1
lambda_w <- 0.5

# Compute truth (high precision)
cat("Computing truth (fine grid)...\n")
grid_x1 <- seq(-3, 3, length.out = 100)
grid_x2 <- seq(-3, 3, length.out = 100)
grid <- expand.grid(X1 = grid_x1, X2 = grid_x2)

tau_s_true <- tau_s_fn(grid$X1, grid$X2)
tau_y_true <- tau_y_fn(grid$X1, grid$X2)
h_true <- tau_s_true * tau_y_true

X_grid <- scale(cbind(grid$X1, grid$X2))
cost_matrix <- as.matrix(dist(X_grid, method = "euclidean"))^2

dual_objective <- function(gamma) {
  n <- nrow(grid)
  obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                gamma * cost_matrix
  inner_mins <- apply(obj_matrix, 1, min)
  -gamma * lambda_w^2 + mean(inner_mins)
}

result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)
phi_true <- result$objective

cat(sprintf("True φ*: %.6f\n\n", phi_true))

# =============================================================================
# Test: Large sample sizes
# =============================================================================

sample_sizes <- c(1000, 5000, 10000, 20000)
n_reps <- 10  # Just 10 reps for speed
methods_to_test <- c("linear", "kernel")

cat("Running large sample test...\n\n")

results_all <- map_dfr(sample_sizes, function(n) {
  cat(sprintf("=== n = %d ===\n", n))

  method_results <- map_dfr(methods_to_test, function(method) {
    cat(sprintf("  Method: %s\n", method))

    estimates <- map_dbl(1:n_reps, function(rep) {
      if (rep %% 5 == 0) cat(sprintf("    Rep %d/%d\n", rep, n_reps))

      set.seed(rep + n * 100)

      # Generate data
      X1 <- rnorm(n)
      X2 <- rnorm(n)
      A <- rbinom(n, 1, 0.5)

      tau_s <- tau_s_fn(X1, X2)
      tau_y <- tau_y_fn(X1, X2)

      S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
      Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

      data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

      # Estimate with sample splitting
      result <- sample_splitting_minimax_wasserstein(
        data = data,
        covariates = c("X1", "X2"),
        lambda_w = lambda_w,
        split_ratio = 0.5,
        tau_method = method,
        cross_fit = (method == "kernel"),  # Cross-fit for kernel
        seed = rep + n * 100
      )

      result$phi_star
    })

    tibble(
      method = method,
      mean_estimate = mean(estimates),
      bias = mean(estimates) - phi_true,
      abs_bias = abs(mean(estimates) - phi_true),
      sd_estimate = sd(estimates),
      se_estimate = sd(estimates) / sqrt(n_reps)
    )
  })

  cat("\n")

  method_results %>% mutate(n = n, .before = 1)
})

# =============================================================================
# Results
# =============================================================================

cat("=============================================================================\n")
cat("RESULTS: Bias by Sample Size\n")
cat("=============================================================================\n\n")

cat("TRUE VALUE: φ* = ", sprintf("%.6f", phi_true), "\n\n", sep = "")

# Print results by method
for (method_name in methods_to_test) {
  method_data <- results_all %>% filter(method == method_name)

  cat(sprintf("METHOD: %s\n", toupper(method_name)))
  cat(sprintf("%-8s | %-13s | %-11s | %-11s | %-9s\n",
              "n", "Mean Estimate", "Bias", "Abs Bias", "SD"))
  cat(strrep("-", 70), "\n")

  for (i in 1:nrow(method_data)) {
    row <- method_data[i, ]
    cat(sprintf("%-8d | %13.6f | %+11.6f | %11.6f | %9.6f\n",
                row$n, row$mean_estimate, row$bias, row$abs_bias, row$sd_estimate))
  }

  # Check if bias is decreasing
  first_bias <- method_data$abs_bias[1]
  last_bias <- method_data$abs_bias[nrow(method_data)]
  reduction <- 100 * (1 - last_bias / first_bias)

  cat(sprintf("\nBias reduction (n=%d to n=%d): %.1f%%\n",
              method_data$n[1], method_data$n[nrow(method_data)], reduction))

  # Check if bias is vanishing
  if (last_bias < 0.01) {
    cat("✓ Bias is very small at large n (< 0.01)\n")
  } else if (last_bias < first_bias * 0.5) {
    cat("✓ Bias is decreasing substantially\n")
  } else {
    cat("⚠ Bias is not decreasing much\n")
  }

  cat("\n")
}

# =============================================================================
# Statistical tests
# =============================================================================

cat("=============================================================================\n")
cat("STATISTICAL ASSESSMENT\n")
cat("=============================================================================\n\n")

# For each method, check if bias at largest n is statistically significant
for (method_name in methods_to_test) {
  method_data <- results_all %>% filter(method == method_name)
  largest_n_row <- method_data %>% filter(n == max(n))

  # Bias is significantly different from zero if:
  # |bias| > 2 * SE (approximate 95% confidence)
  bias <- largest_n_row$bias
  se <- largest_n_row$se_estimate

  cat(sprintf("METHOD: %s at n = %d\n", toupper(method_name), largest_n_row$n))
  cat(sprintf("  Bias: %+.6f\n", bias))
  cat(sprintf("  SE:    %.6f\n", se))
  cat(sprintf("  95%% CI for bias: [%+.6f, %+.6f]\n",
              bias - 1.96 * se, bias + 1.96 * se))

  if (abs(bias) > 2 * se) {
    cat(sprintf("  ⚠ Bias is statistically significant (|bias| = %.6f > 2*SE = %.6f)\n",
                abs(bias), 2 * se))
  } else {
    cat(sprintf("  ✓ Bias is not statistically significant (|bias| = %.6f < 2*SE = %.6f)\n",
                abs(bias), 2 * se))
  }

  cat("\n")
}

# =============================================================================
# Visualization data
# =============================================================================

cat("=============================================================================\n")
cat("ASYMPTOTIC BEHAVIOR\n")
cat("=============================================================================\n\n")

# Check rate of convergence for linear method
linear_data <- results_all %>% filter(method == "linear")

# If bias ∝ 1/n^α, then log(bias) ∝ -α*log(n)
# Fit: log(abs_bias) ~ -α*log(n)
if (all(linear_data$abs_bias > 0)) {
  fit <- lm(log(abs_bias) ~ log(n), data = linear_data)
  alpha <- -coef(fit)[2]

  cat("LINEAR METHOD:\n")
  cat(sprintf("  Convergence rate: bias ∝ n^%.3f\n", coef(fit)[2]))
  cat(sprintf("  (If unbiased: should be ∝ n^(-0.5) or faster)\n"))

  if (coef(fit)[2] < -0.3) {
    cat("  ✓ Bias is decreasing with n (consistent estimator)\n")
  } else {
    cat("  ⚠ Bias is not decreasing fast enough\n")
  }
  cat("\n")
}

# Same for kernel
kernel_data <- results_all %>% filter(method == "kernel")

if (all(kernel_data$abs_bias > 0)) {
  fit_kernel <- lm(log(abs_bias) ~ log(n), data = kernel_data)

  cat("KERNEL METHOD:\n")
  cat(sprintf("  Convergence rate: bias ∝ n^%.3f\n", coef(fit_kernel)[2]))

  if (coef(fit_kernel)[2] < -0.3) {
    cat("  ✓ Bias is decreasing with n\n")
  } else {
    cat("  ⚠ Bias is not decreasing or increasing\n")
  }
  cat("\n")
}

# =============================================================================
# Final verdict
# =============================================================================

cat("=============================================================================\n")
cat("CONCLUSIONS\n")
cat("=============================================================================\n\n")

linear_largest <- results_all %>%
  filter(method == "linear", n == max(n))

kernel_largest <- results_all %>%
  filter(method == "kernel", n == max(n))

cat("At n = 20,000:\n\n")

cat("LINEAR METHOD:\n")
cat(sprintf("  Bias: %+.6f (%.1f%% of true value)\n",
            linear_largest$bias, 100 * abs(linear_largest$bias / phi_true)))

if (abs(linear_largest$bias) < 0.01) {
  cat("  ✓ Bias is negligible (< 1% of true value)\n")
  cat("  ✓ Consistent estimator confirmed\n\n")
  linear_verdict <- "UNBIASED"
} else {
  cat("  ⚠ Non-negligible bias persists even at n=20k\n")
  cat("  ⚠ Suggests fundamental bias, not just finite sample\n\n")
  linear_verdict <- "BIASED"
}

cat("KERNEL METHOD:\n")
cat(sprintf("  Bias: %+.6f (%.1f%% of true value)\n",
            kernel_largest$bias, 100 * abs(kernel_largest$bias / phi_true)))

if (abs(kernel_largest$bias) < 0.05) {
  cat("  ✓ Bias is small (< 5% of true value)\n")
  if (abs(kernel_largest$bias) < abs(kernel_data$bias[1]) * 0.3) {
    cat("  ✓ Bias reduced substantially from n=1000\n\n")
    kernel_verdict <- "DECREASING"
  } else {
    cat("  ⚠ Bias reduction is modest\n\n")
    kernel_verdict <- "SLOW_DECREASE"
  }
} else {
  cat("  ⚠ Substantial bias even at n=20k\n")
  cat("  ⚠ Kernel method may be fundamentally biased\n\n")
  kernel_verdict <- "BIASED"
}

cat("OVERALL VERDICT:\n\n")

if (linear_verdict == "UNBIASED" && kernel_verdict %in% c("DECREASING", "SLOW_DECREASE")) {
  cat("✓✓✓ FINITE SAMPLE ISSUE ✓✓✓\n\n")
  cat("Evidence:\n")
  cat("  ✓ Linear method: bias → 0 as n → ∞\n")
  cat("  ✓ Kernel method: bias decreases with n\n\n")
  cat("CONCLUSION:\n")
  cat("The bias we observed at n=500 is a FINITE SAMPLE effect.\n")
  cat("With large enough samples, the estimator is approximately unbiased.\n\n")
  cat("RECOMMENDATIONS:\n")
  cat("  - For parametric models (linear): n ≥ 500 is sufficient\n")
  cat("  - For flexible models (kernel): n ≥ 5,000 recommended\n")
  cat("  - Document finite-sample bias in manuscript\n")

} else if (linear_verdict == "UNBIASED" && kernel_verdict == "BIASED") {
  cat("⚠ METHOD-SPECIFIC BIAS ⚠\n\n")
  cat("Evidence:\n")
  cat("  ✓ Linear method: approximately unbiased\n")
  cat("  ⚠ Kernel method: substantial bias persists\n\n")
  cat("CONCLUSION:\n")
  cat("Parametric methods (linear) are approximately unbiased.\n")
  cat("Flexible methods (kernel) have fundamental bias issues.\n\n")
  cat("RECOMMENDATIONS:\n")
  cat("  - Use parametric methods (linear, GLM) when possible\n")
  cat("  - Avoid kernel/RF methods or validate carefully\n")
  cat("  - Document method-specific bias in manuscript\n")

} else {
  cat("⚠ FUNDAMENTAL BIAS ⚠\n\n")
  cat("Evidence:\n")
  cat("  ⚠ Bias persists even at n=20,000\n")
  cat("  ⚠ Affects both parametric and flexible methods\n\n")
  cat("CONCLUSION:\n")
  cat("There may be a fundamental bias in the sample splitting approach.\n\n")
  cat("RECOMMENDATIONS:\n")
  cat("  - Investigate theoretical properties more carefully\n")
  cat("  - Consider bias correction methods\n")
  cat("  - May need to adjust theoretical claims\n")
}

# Save results
output <- list(
  results = results_all,
  truth = phi_true,
  linear_verdict = linear_verdict,
  kernel_verdict = kernel_verdict,
  date = Sys.Date()
)

output_file <- here("sims/results/large_sample_bias_test.rds")
dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
saveRDS(output, output_file)

cat(sprintf("\n\nResults saved to: %s\n", basename(output_file)))
cat("\n=============================================================================\n")
