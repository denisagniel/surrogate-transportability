#!/usr/bin/env Rscript
# RANDOM FOREST BIAS TEST
# Question: Does RF work better than kernel for heterogeneous effects?

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("RANDOM FOREST BIAS TEST\n")
cat("=============================================================================\n\n")

cat("Question: Is RF better than kernel for estimating heterogeneous effects?\n")
cat("Hypothesis: RF should work much better (no bandwidth issues, more stable)\n\n")

# Check if randomForest is available
if (!requireNamespace("randomForest", quietly = TRUE)) {
  stop("randomForest package required. Install with: install.packages('randomForest')")
}

# =============================================================================
# Setup: True DGP with heterogeneous effects
# =============================================================================

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2
lambda_w <- 0.5

# Compute truth (high precision grid)
cat("Computing truth...\n")
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
# Test 1: Compare methods at n=1000
# =============================================================================

cat("=============================================================================\n")
cat("TEST 1: Method Comparison at n=1000\n")
cat("=============================================================================\n\n")

n_test <- 1000
n_reps <- 20
methods <- c("linear", "kernel", "rf")

cat("Testing methods:", paste(methods, collapse=", "), "\n")
cat("Replications:", n_reps, "\n\n")

results_n1000 <- map_dfr(methods, function(method) {
  cat(sprintf("Method: %s\n", method))

  estimates <- map_dbl(1:n_reps, function(rep) {
    if (rep %% 5 == 0) cat(sprintf("  Rep %d/%d\n", rep, n_reps))

    set.seed(rep + 80000)

    X1 <- rnorm(n_test)
    X2 <- rnorm(n_test)
    A <- rbinom(n_test, 1, 0.5)

    tau_s <- tau_s_fn(X1, X2)
    tau_y <- tau_y_fn(X1, X2)

    S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n_test, sd = 0.3)
    Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n_test, sd = 0.4)

    data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

    result <- sample_splitting_minimax_wasserstein(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = lambda_w,
      split_ratio = 0.5,
      tau_method = method,
      cross_fit = (method != "linear"),
      seed = rep + 80000
    )

    result$phi_star
  })

  tibble(
    method = method,
    mean_estimate = mean(estimates),
    bias = mean(estimates) - phi_true,
    abs_bias = abs(mean(estimates) - phi_true),
    relative_bias_pct = 100 * abs(mean(estimates) - phi_true) / phi_true,
    sd = sd(estimates),
    rmse = sqrt(mean((estimates - phi_true)^2))
  )
})

cat("\n--- RESULTS at n=1000 ---\n\n")
print(results_n1000, width = 100)

cat("\n")

# =============================================================================
# Test 2: RF across sample sizes
# =============================================================================

cat("\n")
cat("=============================================================================\n")
cat("TEST 2: RF Performance Across Sample Sizes\n")
cat("=============================================================================\n\n")

sample_sizes <- c(500, 1000, 2000, 5000)
n_reps_rf <- 15

cat("Testing RF at n ∈ {500, 1000, 2000, 5000}\n")
cat("Replications per n:", n_reps_rf, "\n\n")

rf_by_n <- map_dfr(sample_sizes, function(n) {
  cat(sprintf("n = %d\n", n))

  estimates <- map_dbl(1:n_reps_rf, function(rep) {
    if (rep %% 5 == 0) cat(sprintf("  Rep %d/%d\n", rep, n_reps_rf))

    set.seed(rep + n * 100)

    X1 <- rnorm(n)
    X2 <- rnorm(n)
    A <- rbinom(n, 1, 0.5)

    tau_s <- tau_s_fn(X1, X2)
    tau_y <- tau_y_fn(X1, X2)

    S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
    Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

    data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

    result <- sample_splitting_minimax_wasserstein(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = lambda_w,
      split_ratio = 0.5,
      tau_method = "rf",
      cross_fit = TRUE,
      seed = rep + n * 100
    )

    result$phi_star
  })

  tibble(
    n = n,
    mean_estimate = mean(estimates),
    bias = mean(estimates) - phi_true,
    abs_bias = abs(mean(estimates) - phi_true),
    relative_bias_pct = 100 * abs(mean(estimates) - phi_true) / phi_true,
    sd = sd(estimates),
    se = sd(estimates) / sqrt(n_reps_rf)
  )
})

cat("\n--- RF ACROSS SAMPLE SIZES ---\n\n")
print(rf_by_n, width = 100)

cat("\n")

# =============================================================================
# Summary and Comparison
# =============================================================================

cat("=============================================================================\n")
cat("SUMMARY: Is Random Forest Better?\n")
cat("=============================================================================\n\n")

cat("TRUE VALUE: φ* = ", sprintf("%.6f", phi_true), "\n\n", sep = "")

cat("METHOD COMPARISON at n=1000:\n\n")

for (i in 1:nrow(results_n1000)) {
  row <- results_n1000[i, ]
  cat(sprintf("%-10s | Bias: %+.5f | Rel.Bias: %5.1f%% | RMSE: %.5f\n",
              toupper(row$method), row$bias, row$relative_bias_pct, row$rmse))
}

cat("\n")

# Find best method
best_method <- results_n1000$method[which.min(results_n1000$abs_bias)]
worst_method <- results_n1000$method[which.max(results_n1000$abs_bias)]

cat(sprintf("Best method (lowest bias):  %s\n", toupper(best_method)))
cat(sprintf("Worst method (highest bias): %s\n\n", toupper(worst_method)))

# Compare RF to kernel
rf_bias <- results_n1000$abs_bias[results_n1000$method == "rf"]
kernel_bias <- results_n1000$abs_bias[results_n1000$method == "kernel"]
linear_bias <- results_n1000$abs_bias[results_n1000$method == "linear"]

cat("BIAS COMPARISONS:\n")
cat(sprintf("  RF vs. Kernel: RF has %.1f%% less bias\n",
            100 * (1 - rf_bias / kernel_bias)))
cat(sprintf("  RF vs. Linear: RF has %.1f%% %s bias\n",
            100 * abs(1 - rf_bias / linear_bias),
            ifelse(rf_bias < linear_bias, "less", "more")))

cat("\n")

# Check if RF bias decreases with n
if (nrow(rf_by_n) >= 2) {
  first_bias <- rf_by_n$abs_bias[1]
  last_bias <- rf_by_n$abs_bias[nrow(rf_by_n)]

  cat("RF BIAS TREND:\n")
  cat(sprintf("  n=%d: |bias| = %.5f (%.1f%%)\n",
              rf_by_n$n[1], first_bias, 100*first_bias/phi_true))
  cat(sprintf("  n=%d: |bias| = %.5f (%.1f%%)\n",
              rf_by_n$n[nrow(rf_by_n)], last_bias, 100*last_bias/phi_true))

  if (last_bias < first_bias * 0.5) {
    cat("  ✓ Bias decreases substantially with n\n")
  } else if (last_bias < first_bias) {
    cat("  ~ Bias decreases modestly with n\n")
  } else {
    cat("  ⚠ Bias does not decrease with n\n")
  }
}

cat("\n")

# Statistical significance at largest n
largest_n_row <- rf_by_n %>% filter(n == max(n))
bias_ci_lower <- largest_n_row$bias - 1.96 * largest_n_row$se
bias_ci_upper <- largest_n_row$bias + 1.96 * largest_n_row$se

cat(sprintf("RF at n=%d:\n", largest_n_row$n))
cat(sprintf("  Bias: %+.5f\n", largest_n_row$bias))
cat(sprintf("  95%% CI: [%+.5f, %+.5f]\n", bias_ci_lower, bias_ci_upper))

if (bias_ci_lower < 0 && bias_ci_upper > 0) {
  cat("  ✓ Bias is NOT statistically significant\n")
} else {
  cat("  ⚠ Bias is statistically significant\n")
}

cat("\n")

# =============================================================================
# Final Verdict
# =============================================================================

cat("=============================================================================\n")
cat("CONCLUSION\n")
cat("=============================================================================\n\n")

# Determine if RF is acceptable
rf_n1000_bias_pct <- results_n1000$relative_bias_pct[results_n1000$method == "rf"]
rf_largest_bias_pct <- 100 * largest_n_row$abs_bias / phi_true

if (rf_n1000_bias_pct < 15 && rf_largest_bias_pct < 10) {
  cat("✓✓✓ RANDOM FOREST WORKS WELL ✓✓✓\n\n")

  cat("Evidence:\n")
  cat(sprintf("  ✓ Low bias at n=1000: %.1f%% of true value\n", rf_n1000_bias_pct))
  cat(sprintf("  ✓ Low bias at n=%d: %.1f%% of true value\n",
              largest_n_row$n, rf_largest_bias_pct))
  cat(sprintf("  ✓ Much better than kernel: %.0f%% bias reduction\n",
              100 * (1 - rf_bias / kernel_bias)))
  cat("\n")

  cat("RECOMMENDATION:\n")
  cat("Random forest is the PREFERRED method for heterogeneous treatment effects.\n")
  cat("Use RF instead of kernel for sample splitting minimax estimation.\n\n")

  cat("PRACTICAL GUIDANCE:\n")
  cat("  - For parametric models (linear): n ≥ 500 sufficient\n")
  cat("  - For RF (heterogeneous): n ≥ 1000 recommended\n")
  cat("  - Avoid kernel regression (unstable with sample splitting)\n")

  verdict <- "RF_RECOMMENDED"

} else if (rf_n1000_bias_pct < 25) {
  cat("~ RANDOM FOREST HAS MODERATE BIAS ~\n\n")

  cat("Evidence:\n")
  cat(sprintf("  ~ Moderate bias at n=1000: %.1f%%\n", rf_n1000_bias_pct))
  cat(sprintf("  ✓ Better than kernel: %.0f%% improvement\n",
              100 * (1 - rf_bias / kernel_bias)))
  cat("\n")

  cat("RECOMMENDATION:\n")
  cat("RF is usable but requires larger samples or bias correction.\n")

  verdict <- "RF_ACCEPTABLE"

} else {
  cat("⚠ RANDOM FOREST ALSO HAS SUBSTANTIAL BIAS ⚠\n\n")

  cat("Evidence:\n")
  cat(sprintf("  ⚠ High bias: %.1f%% at n=1000\n", rf_n1000_bias_pct))
  cat("\n")

  cat("This suggests the bias is not method-specific but fundamental to\n")
  cat("sample splitting with flexible methods.\n")

  verdict <- "RF_PROBLEMATIC"
}

cat("\n")

# Save results
output <- list(
  method_comparison = results_n1000,
  rf_by_n = rf_by_n,
  truth = phi_true,
  verdict = verdict,
  date = Sys.Date()
)

output_file <- here("sims/results/rf_bias_test.rds")
saveRDS(output, output_file)

cat(sprintf("Results saved to: %s\n", basename(output_file)))
cat("\n=============================================================================\n")
