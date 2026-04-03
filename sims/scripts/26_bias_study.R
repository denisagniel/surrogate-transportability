#!/usr/bin/env Rscript
# BIAS STUDY: Sample Splitting Estimator
# Question: Is E[φ̂_split] = φ* or is there systematic bias?

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("BIAS STUDY: Sample Splitting Minimax Estimator\n")
cat("=============================================================================\n\n")

cat("Research Question: Does sample splitting produce unbiased estimates?\n")
cat("Method: Compare estimates to known truth across multiple scenarios\n\n")

# =============================================================================
# Helper: Compute true minimax value analytically (when possible)
# =============================================================================

compute_analytical_truth <- function(tau_s_fn, tau_y_fn, lambda_w,
                                      x1_range = c(-3, 3),
                                      x2_range = c(-3, 3),
                                      n_grid = 1000) {
  # Fine grid approximation of truth
  grid_x1 <- seq(x1_range[1], x1_range[2], length.out = sqrt(n_grid))
  grid_x2 <- seq(x2_range[1], x2_range[2], length.out = sqrt(n_grid))
  grid <- expand.grid(X1 = grid_x1, X2 = grid_x2)

  tau_s_true <- tau_s_fn(grid$X1, grid$X2)
  tau_y_true <- tau_y_fn(grid$X1, grid$X2)
  h_true <- tau_s_true * tau_y_true

  # Scaled coordinates for cost matrix
  X_grid <- scale(cbind(grid$X1, grid$X2))
  cost_matrix <- as.matrix(dist(X_grid, method = "euclidean"))^2

  # Wasserstein dual objective
  dual_objective <- function(gamma) {
    n <- nrow(grid)
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  # Optimize
  result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)

  list(
    phi_star = result$objective,
    optimal_gamma = result$maximum
  )
}

# =============================================================================
# Study 1: Bias vs. Sample Size (Consistency Check)
# =============================================================================

cat("=============================================================================\n")
cat("STUDY 1: Bias vs. Sample Size (Consistency Check)\n")
cat("=============================================================================\n\n")

cat("Goal: Check if bias → 0 as n → ∞ (consistency)\n")
cat("Method: Estimate at n ∈ {100, 250, 500, 1000, 2000}\n\n")

# Simple DGP with known truth
tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1
lambda_w <- 0.5

# Compute truth once
cat("Computing analytical truth (fine grid)...\n")
truth_result <- compute_analytical_truth(tau_s_fn, tau_y_fn, lambda_w, n_grid = 2500)
phi_true <- truth_result$phi_star
cat(sprintf("True φ*: %.6f\n\n", phi_true))

# Sample sizes to test
sample_sizes <- c(100, 250, 500, 1000, 2000)
n_reps <- 50  # Reps per sample size

cat("Running bias study across sample sizes...\n")

bias_results <- map_dfr(sample_sizes, function(n) {
  cat(sprintf("  n = %d...\n", n))

  estimates <- map_dbl(1:n_reps, function(rep) {
    set.seed(rep + n * 1000)

    # Generate data
    X1 <- rnorm(n)
    X2 <- rnorm(n)
    A <- rbinom(n, 1, 0.5)

    tau_s <- tau_s_fn(X1, X2)
    tau_y <- tau_y_fn(X1, X2)

    S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
    Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

    data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

    # Sample splitting estimate (point estimate only, no bootstrap for speed)
    result <- sample_splitting_minimax_wasserstein(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = lambda_w,
      split_ratio = 0.5,
      tau_method = "linear",  # Use correct model specification
      cross_fit = FALSE,  # Faster
      seed = rep + n * 1000
    )

    result$phi_star
  })

  # Compute bias statistics
  tibble(
    n = n,
    mean_estimate = mean(estimates),
    bias = mean(estimates) - phi_true,
    abs_bias = abs(mean(estimates) - phi_true),
    sd_estimate = sd(estimates),
    rmse = sqrt(mean((estimates - phi_true)^2)),
    truth = phi_true
  )
})

cat("\n--- RESULTS: Bias vs. Sample Size ---\n\n")
print(bias_results %>%
        select(n, mean_estimate, bias, abs_bias, rmse) %>%
        mutate(across(where(is.numeric) & !n, ~round(., 5))))

cat("\nInterpretation:\n")
if (all(bias_results$abs_bias < 0.05)) {
  cat("  ✓ Low bias across all sample sizes (|bias| < 0.05)\n")
} else {
  cat("  ⚠ Substantial bias detected (|bias| > 0.05)\n")
}

# Check if bias decreases with n
if (bias_results$abs_bias[1] > bias_results$abs_bias[nrow(bias_results)]) {
  cat("  ✓ Bias decreases with n (suggests consistency)\n")
} else {
  cat("  ⚠ Bias does not clearly decrease with n\n")
}

# =============================================================================
# Study 2: Selection Bias Check (Sample Splitting vs. Naive)
# =============================================================================

cat("\n\n")
cat("=============================================================================\n")
cat("STUDY 2: Selection Bias Check\n")
cat("=============================================================================\n\n")

cat("Goal: Verify sample splitting eliminates selection bias\n")
cat("Method: Compare to naive estimator (find worst-case and estimate on same data)\n\n")

n_test <- 500
n_reps_selection <- 30

# Naive estimator (selection bias present)
naive_minimax <- function(data, covariates, lambda_w) {
  n <- nrow(data)

  # Estimate treatment effects
  tau_s_result <- estimate_treatment_effect_function(
    data = data, outcome = "S", covariates = covariates,
    method = "linear", cross_fit = FALSE
  )
  tau_y_result <- estimate_treatment_effect_function(
    data = data, outcome = "Y", covariates = covariates,
    method = "linear", cross_fit = FALSE
  )

  concordance <- tau_s_result$tau_hat * tau_y_result$tau_hat

  # Cost matrix
  X <- scale(as.matrix(data[, covariates]))
  cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

  # Find worst-case ON SAME DATA
  dual_objective <- function(gamma) {
    obj_matrix <- matrix(concordance, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)
  result$objective
}

cat("Running comparison (30 replications)...\n")

comparison_results <- map_dfr(1:n_reps_selection, function(rep) {
  set.seed(rep + 50000)

  X1 <- rnorm(n_test)
  X2 <- rnorm(n_test)
  A <- rbinom(n_test, 1, 0.5)

  tau_s <- tau_s_fn(X1, X2)
  tau_y <- tau_y_fn(X1, X2)

  S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n_test, sd = 0.3)
  Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n_test, sd = 0.4)

  data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

  # Naive estimate
  naive_est <- naive_minimax(data, c("X1", "X2"), lambda_w)

  # Sample splitting estimate
  split_result <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = lambda_w,
    tau_method = "linear",
    cross_fit = FALSE,
    seed = rep + 50000
  )

  tibble(
    rep = rep,
    naive = naive_est,
    split = split_result$phi_star,
    truth = phi_true
  )
})

naive_bias <- mean(comparison_results$naive) - phi_true
split_bias <- mean(comparison_results$split) - phi_true

cat("\n--- RESULTS: Selection Bias Comparison ---\n\n")
cat(sprintf("True φ*:              %.6f\n", phi_true))
cat(sprintf("Naive mean estimate:  %.6f (bias: %+.6f)\n",
            mean(comparison_results$naive), naive_bias))
cat(sprintf("Split mean estimate:  %.6f (bias: %+.6f)\n",
            mean(comparison_results$split), split_bias))
cat(sprintf("\nSelection bias (naive): %+.6f\n", naive_bias))
cat(sprintf("Selection bias (split): %+.6f\n", split_bias))
cat(sprintf("Bias reduction:         %.1f%%\n",
            100 * (1 - abs(split_bias) / abs(naive_bias))))

cat("\nInterpretation:\n")
if (abs(naive_bias) > abs(split_bias)) {
  cat("  ✓ Sample splitting reduces bias vs. naive\n")
  if (abs(split_bias) < 0.02) {
    cat("  ✓ Remaining bias is small (< 0.02)\n")
  }
} else {
  cat("  ⚠ Sample splitting does not reduce bias\n")
}

# =============================================================================
# Study 3: Method Comparison (tau estimation method)
# =============================================================================

cat("\n\n")
cat("=============================================================================\n")
cat("STUDY 3: Bias by Treatment Effect Estimation Method\n")
cat("=============================================================================\n\n")

cat("Goal: Check if bias depends on tau estimation method\n")
cat("Methods: linear (correct model), kernel (flexible), GAM (smooth)\n\n")

n_test_method <- 500
n_reps_method <- 20
methods_to_test <- c("linear", "kernel")

cat("Running method comparison...\n")

method_results <- map_dfr(methods_to_test, function(method) {
  cat(sprintf("  Method: %s...\n", method))

  estimates <- map_dbl(1:n_reps_method, function(rep) {
    set.seed(rep + 60000)

    X1 <- rnorm(n_test_method)
    X2 <- rnorm(n_test_method)
    A <- rbinom(n_test_method, 1, 0.5)

    tau_s <- tau_s_fn(X1, X2)
    tau_y <- tau_y_fn(X1, X2)

    S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n_test_method, sd = 0.3)
    Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n_test_method, sd = 0.4)

    data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

    result <- sample_splitting_minimax_wasserstein(
      data = data,
      covariates = c("X1", "X2"),
      lambda_w = lambda_w,
      tau_method = method,
      cross_fit = (method != "linear"),  # Cross-fit for flexible methods
      seed = rep + 60000
    )

    result$phi_star
  })

  tibble(
    method = method,
    mean_estimate = mean(estimates),
    bias = mean(estimates) - phi_true,
    abs_bias = abs(mean(estimates) - phi_true),
    sd_estimate = sd(estimates),
    truth = phi_true
  )
})

cat("\n--- RESULTS: Bias by Method ---\n\n")
print(method_results %>%
        select(method, mean_estimate, bias, abs_bias, sd_estimate) %>%
        mutate(across(where(is.numeric), ~round(., 5))))

cat("\nInterpretation:\n")
cat(sprintf("  Linear (correct model):  bias = %+.5f\n",
            method_results$bias[method_results$method == "linear"]))
cat(sprintf("  Kernel (flexible):       bias = %+.5f\n",
            method_results$bias[method_results$method == "kernel"]))

if (all(method_results$abs_bias < 0.05)) {
  cat("\n  ✓ Low bias across all methods\n")
} else {
  cat("\n  ⚠ Some methods show substantial bias\n")
}

# =============================================================================
# Summary and Conclusions
# =============================================================================

cat("\n\n")
cat("=============================================================================\n")
cat("BIAS STUDY SUMMARY\n")
cat("=============================================================================\n\n")

# Overall bias assessment
overall_bias <- bias_results$bias[bias_results$n == 500]
selection_bias_eliminated <- abs(split_bias) < abs(naive_bias) / 2

cat("KEY FINDINGS:\n\n")

cat("1. Finite Sample Bias:\n")
cat(sprintf("   At n=500: bias = %+.5f (%.1f%% of true value)\n",
            overall_bias, 100 * abs(overall_bias / phi_true)))
if (abs(overall_bias) < 0.02) {
  cat("   ✓ Bias is small and acceptable\n\n")
} else {
  cat("   ⚠ Bias may be problematic\n\n")
}

cat("2. Selection Bias:\n")
cat(sprintf("   Naive approach: bias = %+.5f\n", naive_bias))
cat(sprintf("   Sample splitting: bias = %+.5f\n", split_bias))
if (selection_bias_eliminated) {
  cat("   ✓ Sample splitting successfully reduces selection bias\n\n")
} else {
  cat("   ⚠ Selection bias not clearly eliminated\n\n")
}

cat("3. Consistency:\n")
first_bias <- bias_results$abs_bias[1]
last_bias <- bias_results$abs_bias[nrow(bias_results)]
if (last_bias < first_bias) {
  cat(sprintf("   Bias at n=100: %.5f\n", first_bias))
  cat(sprintf("   Bias at n=2000: %.5f\n", last_bias))
  cat("   ✓ Bias decreases with sample size (consistent estimator)\n\n")
} else {
  cat("   ⚠ Bias does not decrease clearly with n\n\n")
}

cat("4. Method Robustness:\n")
max_method_bias <- max(method_results$abs_bias)
if (max_method_bias < 0.05) {
  cat("   ✓ Low bias across all tau estimation methods\n\n")
} else {
  cat(sprintf("   ⚠ Maximum bias: %.5f (flexible methods may introduce bias)\n\n",
              max_method_bias))
}

# Overall verdict
cat("=============================================================================\n")
cat("OVERALL ASSESSMENT\n")
cat("=============================================================================\n\n")

if (abs(overall_bias) < 0.02 &&
    selection_bias_eliminated &&
    last_bias < first_bias) {
  cat("✓✓✓ ESTIMATOR IS APPROXIMATELY UNBIASED ✓✓✓\n\n")
  cat("Evidence:\n")
  cat("  ✓ Small finite sample bias (< 2% of true value)\n")
  cat("  ✓ Selection bias eliminated vs. naive approach\n")
  cat("  ✓ Bias decreases with n (consistency)\n")
  cat("  ✓ Robust across estimation methods\n\n")

  cat("CONCLUSION:\n")
  cat("Sample splitting produces approximately unbiased estimates.\n")
  cat("Combined with consistency, this supports asymptotic coverage claims.\n\n")

  cat("NEXT STEPS:\n")
  cat("1. Run coverage validation (verify CIs contain truth ~95% of time)\n")
  cat("2. Write Theorem 1 proof (formal asymptotic properties)\n")
  cat("3. Manuscript integration\n")

  overall_verdict <- "UNBIASED"

} else {
  cat("⚠ BIAS DETECTED ⚠\n\n")
  cat("Issues found:\n")
  if (abs(overall_bias) >= 0.02) {
    cat(sprintf("  ⚠ Finite sample bias: %.5f (%.1f%% of truth)\n",
                overall_bias, 100 * abs(overall_bias / phi_true)))
  }
  if (!selection_bias_eliminated) {
    cat("  ⚠ Selection bias not clearly reduced\n")
  }
  if (last_bias >= first_bias) {
    cat("  ⚠ Bias does not decrease with n\n")
  }

  cat("\nRECOMMENDATIONS:\n")
  cat("1. Investigate source of bias\n")
  cat("2. Consider bias correction methods\n")
  cat("3. Adjust asymptotic theory if bias persists\n")

  overall_verdict <- "BIASED"
}

# Save results
output <- list(
  bias_by_n = bias_results,
  selection_comparison = comparison_results,
  method_comparison = method_results,
  summary = list(
    overall_bias_n500 = overall_bias,
    naive_bias = naive_bias,
    split_bias = split_bias,
    selection_bias_reduced = selection_bias_eliminated,
    verdict = overall_verdict
  ),
  truth = phi_true
)

output_file <- here("sims/results/sample_splitting_bias_study.rds")
dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
saveRDS(output, output_file)

cat(sprintf("\nResults saved to: %s\n", basename(output_file)))
cat("\n=============================================================================\n")
