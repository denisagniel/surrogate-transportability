#!/usr/bin/env Rscript
# Quick test of sample splitting implementation

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("QUICK TEST: Sample Splitting Implementation\n")
cat("=============================================================================\n\n")

# Generate simple data
set.seed(123)
n <- 200

X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)

tau_s <- 0.3 + 0.2 * X1
tau_y <- 0.4 + 0.3 * X1

S <- tau_s * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
Y <- tau_y * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

cat("Data generated: n =", n, "\n")
cat("True treatment effects: tau_S = 0.3 + 0.2*X1, tau_Y = 0.4 + 0.3*X1\n\n")

# Test 1: Basic sample splitting
cat("TEST 1: Basic sample splitting\n")
cat("--------------------------------\n")

result1 <- sample_splitting_minimax_wasserstein(
  data = data,
  covariates = c("X1", "X2"),
  lambda_w = 0.5,
  split_ratio = 0.5,
  tau_method = "linear",
  cross_fit = FALSE,
  seed = 123
)

cat(sprintf("Point estimate: %.4f\n", result1$phi_star))
cat(sprintf("Optimal gamma (D1): %.4f\n", result1$optimal_gamma_d1))
cat(sprintf("Optimal gamma (D2): %.4f\n", result1$optimal_gamma_d2))
cat(sprintf("Sample sizes: n1=%d, n2=%d\n", result1$n_d1, result1$n_d2))
cat("✓ Basic function works\n\n")

# Test 2: Bootstrap CI
cat("TEST 2: Bootstrap CI (100 samples)\n")
cat("------------------------------------\n")

result2 <- bootstrap_ci_sample_splitting(
  data = data,
  covariates = c("X1", "X2"),
  lambda_w = 0.5,
  split_ratio = 0.5,
  tau_method = "linear",
  n_bootstrap = 100,
  confidence_level = 0.95,
  seed = 123,
  verbose = FALSE
)

cat(sprintf("Point estimate: %.4f\n", result2$phi_star))
cat(sprintf("95%% CI: [%.4f, %.4f]\n", result2$ci_lower, result2$ci_upper))
cat(sprintf("CI width: %.4f\n", result2$ci_width))
cat(sprintf("Bootstrap samples: %d/%d successful\n",
            result2$n_successful, result2$n_bootstrap))
cat("✓ Bootstrap CI works\n\n")

# Test 3: Different split ratios
cat("TEST 3: Different split ratios\n")
cat("--------------------------------\n")

for (ratio in c(0.3, 0.5, 0.7)) {
  result <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    split_ratio = ratio,
    tau_method = "linear",
    cross_fit = FALSE,
    seed = 456
  )

  cat(sprintf("Ratio %.1f: n1=%d, n2=%d, phi*=%.4f\n",
              ratio, result$n_d1, result$n_d2, result$phi_star))
}
cat("✓ Different split ratios work\n\n")

# Test 4: Different tau methods
cat("TEST 4: Different tau methods\n")
cat("-------------------------------\n")

methods <- c("linear", "kernel")

for (method in methods) {
  result <- sample_splitting_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = 0.5,
    tau_method = method,
    cross_fit = FALSE,
    seed = 789
  )

  cat(sprintf("%s: phi* = %.4f\n", method, result$phi_star))
}
cat("✓ Different tau methods work\n\n")

# Test 5: Cross-fitting
cat("TEST 5: Cross-fitting\n")
cat("----------------------\n")

result_no_cf <- sample_splitting_minimax_wasserstein(
  data = data,
  covariates = c("X1", "X2"),
  lambda_w = 0.5,
  tau_method = "kernel",
  cross_fit = FALSE,
  seed = 101
)

result_cf <- sample_splitting_minimax_wasserstein(
  data = data,
  covariates = c("X1", "X2"),
  lambda_w = 0.5,
  tau_method = "kernel",
  cross_fit = TRUE,
  seed = 101
)

cat(sprintf("No cross-fit: phi* = %.4f\n", result_no_cf$phi_star))
cat(sprintf("Cross-fit:    phi* = %.4f\n", result_cf$phi_star))
cat("✓ Cross-fitting works\n\n")

cat("=============================================================================\n")
cat("✓✓✓ ALL QUICK TESTS PASSED ✓✓✓\n")
cat("=============================================================================\n\n")

cat("Implementation ready for full coverage validation.\n")
cat("Next: Run sims/scripts/25_sample_splitting_coverage.R\n\n")
