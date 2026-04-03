#!/usr/bin/env Rscript
# Test approaches to correct selection bias in DRO

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("TESTING DEBIASING APPROACHES FOR DRO\n")
cat("=============================================================================\n\n")

cat("The problem: Taking minimum over noisy estimates creates downward bias\n")
cat("Goal: Find an approach that corrects this bias\n\n")

# =============================================================================
# Setup: Generate one test case
# =============================================================================

set.seed(123)

n <- 250
X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

tau_s_true <- tau_s_fn(X1, X2)
tau_y_true <- tau_y_fn(X1, X2)

S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

lambda_w <- 0.5

# Truth
h_true <- tau_s_true * tau_y_true
X <- scale(cbind(X1, X2))
cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

dual_obj_truth <- function(gamma) {
  obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                gamma * cost_matrix
  inner_mins <- apply(obj_matrix, 1, min)
  -gamma * lambda_w^2 + mean(inner_mins)
}

truth <- optimize(dual_obj_truth, interval = c(0, 100), maximum = TRUE)$objective

cat("TRUE MINIMAX:", round(truth, 4), "\n")
cat("Mean h_true:", round(mean(h_true), 4), "\n\n")

# Estimate treatment effects
tau_s_est <- estimate_treatment_effect_function(
  data, "S", c("X1", "X2"), method = "kernel", cross_fit = TRUE
)$tau_hat

tau_y_est <- estimate_treatment_effect_function(
  data, "Y", c("X1", "X2"), method = "kernel", cross_fit = TRUE
)$tau_hat

h_est <- tau_s_est * tau_y_est

cat("ESTIMATED CONCORDANCES:\n")
cat("  Mean:", round(mean(h_est), 4), "\n")
cat("  SD:", round(sd(h_est), 4), "\n")
cat("  Bias:", round(mean(h_est - h_true), 4), "\n")
cat("  RMSE:", round(sqrt(mean((h_est - h_true)^2)), 4), "\n\n")

# Helper function to solve DRO with given concordances
solve_dro <- function(h, cost_matrix, lambda_w) {
  dual_obj <- function(gamma) {
    obj_matrix <- matrix(h, nrow = length(h), ncol = length(h), byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  optimize(dual_obj, interval = c(0, 100), maximum = TRUE)$objective
}

# =============================================================================
# APPROACH 0: Naive (baseline)
# =============================================================================

cat("=============================================================================\n")
cat("APPROACH 0: Naive (use raw estimates)\n")
cat("=============================================================================\n\n")

phi_naive <- solve_dro(h_est, cost_matrix, lambda_w)

cat("Result:", round(phi_naive, 4), "\n")
cat("Error:", round(phi_naive - truth, 4), "\n\n")

# =============================================================================
# APPROACH 1: Shrinkage toward mean
# =============================================================================

cat("=============================================================================\n")
cat("APPROACH 1: Shrinkage (James-Stein style)\n")
cat("=============================================================================\n\n")

test_shrinkage <- function(shrinkage_factor) {
  # Shrink toward grand mean
  h_mean <- mean(h_est)
  h_shrunk <- shrinkage_factor * h_est + (1 - shrinkage_factor) * h_mean

  phi <- solve_dro(h_shrunk, cost_matrix, lambda_w)

  list(
    shrinkage = shrinkage_factor,
    phi = phi,
    error = phi - truth
  )
}

shrinkage_factors <- seq(0.5, 1.0, by = 0.1)
shrinkage_results <- map_dfr(shrinkage_factors, test_shrinkage)

cat("Results:\n")
print(shrinkage_results)
cat("\n")

best_shrinkage <- shrinkage_results %>%
  filter(abs(error) == min(abs(error))) %>%
  slice(1)

cat("Best shrinkage factor:", best_shrinkage$shrinkage, "\n")
cat("  Result:", round(best_shrinkage$phi, 4), "\n")
cat("  Error:", round(best_shrinkage$error, 4), "\n\n")

# =============================================================================
# APPROACH 2: Bootstrap bias correction
# =============================================================================

cat("=============================================================================\n")
cat("APPROACH 2: Bootstrap bias correction\n")
cat("=============================================================================\n\n")

cat("Estimate E[phi_hat - phi_true] via bootstrap, then subtract\n\n")

# We need to bootstrap to estimate the bias
# But we don't know phi_true for each bootstrap sample...
# Alternative: estimate the bias of the ESTIMATOR (not the estimate)

cat("Computing bootstrap bias estimate...\n")

n_boot <- 50  # Use fewer for speed
bootstrap_phis <- numeric(n_boot)

for (b in 1:n_boot) {
  boot_idx <- sample(1:n, replace = TRUE)
  boot_data <- data[boot_idx, ]

  # Re-estimate
  tau_s_boot <- estimate_treatment_effect_function(
    boot_data, "S", c("X1", "X2"), method = "kernel", cross_fit = FALSE
  )$tau_hat

  tau_y_boot <- estimate_treatment_effect_function(
    boot_data, "Y", c("X1", "X2"), method = "kernel", cross_fit = FALSE
  )$tau_hat

  h_boot <- tau_s_boot * tau_y_boot

  # Cost matrix for bootstrap sample
  X_boot <- scale(cbind(boot_data$X1, boot_data$X2))
  cost_boot <- as.matrix(dist(X_boot, method = "euclidean"))^2

  bootstrap_phis[b] <- solve_dro(h_boot, cost_boot, lambda_w)
}

# Bias of estimator ≈ E[phi_hat] - phi (on original data)
# But this is circular...

# Alternative: Use the fact that mean(bootstrap_phis) ≈ phi_hat
# And phi_hat is biased low
# So: phi_corrected = phi_hat + (phi_hat - mean(bootstrap_phis))
# This is the "bootstrap bias correction"

bias_estimate <- phi_naive - mean(bootstrap_phis)
phi_bc <- phi_naive + bias_estimate

cat("  Naive estimate:", round(phi_naive, 4), "\n")
cat("  Mean bootstrap:", round(mean(bootstrap_phis), 4), "\n")
cat("  Estimated bias:", round(bias_estimate, 4), "\n")
cat("  Bias-corrected:", round(phi_bc, 4), "\n")
cat("  Error:", round(phi_bc - truth, 4), "\n\n")

# =============================================================================
# APPROACH 3: Conservative plug-in (add penalty for variance)
# =============================================================================

cat("=============================================================================\n")
cat("APPROACH 3: Conservative plug-in\n")
cat("=============================================================================\n\n")

cat("Add penalty: phi_conservative = phi_hat + k * se_hat\n")
cat("Where se_hat estimates standard error of concordances\n\n")

# Estimate SE via bootstrap
se_concordances <- apply(matrix(bootstrap_phis, nrow = n_boot), 2, function(x) sd(x, na.rm = TRUE))
# Actually we don't have concordances per bootstrap...

# Simpler: use empirical SD of h_est as proxy for SE
se_estimate <- sd(h_est) / sqrt(n)

test_conservative <- function(k) {
  phi <- phi_naive + k * se_estimate
  list(k = k, phi = phi, error = phi - truth)
}

k_values <- seq(0, 3, by = 0.5)
conservative_results <- map_dfr(k_values, test_conservative)

cat("Results:\n")
print(conservative_results)
cat("\n")

best_k <- conservative_results %>%
  filter(abs(error) == min(abs(error))) %>%
  slice(1)

cat("Best k:", best_k$k, "\n")
cat("  Result:", round(best_k$phi, 4), "\n")
cat("  Error:", round(best_k$error, 4), "\n\n")

# =============================================================================
# APPROACH 4: Sample splitting
# =============================================================================

cat("=============================================================================\n")
cat("APPROACH 4: Sample splitting\n")
cat("=============================================================================\n\n")

cat("Split data: estimate tau on half, solve DRO on other half\n")
cat("This avoids using same data for estimation and selection\n\n")

# Split sample
n_half <- floor(n/2)
idx_train <- sample(1:n, n_half)
idx_test <- setdiff(1:n, idx_train)

data_train <- data[idx_train, ]
data_test <- data[idx_test, ]

# Estimate on train
tau_s_train <- estimate_treatment_effect_function(
  data_train, "S", c("X1", "X2"), method = "kernel", cross_fit = FALSE
)$tau_hat

tau_y_train <- estimate_treatment_effect_function(
  data_train, "Y", c("X1", "X2"), method = "kernel", cross_fit = FALSE
)$tau_hat

# Use train estimates to predict on test
# Actually, we need to predict tau(x) at test points...
# This is more complex. Skip for now.

cat("(Sample splitting requires predicting tau at new points - deferred)\n\n")

# =============================================================================
# APPROACH 5: Winsorize concordances
# =============================================================================

cat("=============================================================================\n")
cat("APPROACH 5: Winsorize extreme values\n")
cat("=============================================================================\n\n")

test_winsorize <- function(quantile_cutoff) {
  lower_bound <- quantile(h_est, quantile_cutoff)
  upper_bound <- quantile(h_est, 1 - quantile_cutoff)

  h_wins <- pmin(pmax(h_est, lower_bound), upper_bound)

  phi <- solve_dro(h_wins, cost_matrix, lambda_w)

  list(
    cutoff = quantile_cutoff,
    phi = phi,
    error = phi - truth
  )
}

cutoffs <- c(0.05, 0.10, 0.15, 0.20)
winsorize_results <- map_dfr(cutoffs, test_winsorize)

cat("Results:\n")
print(winsorize_results)
cat("\n")

best_wins <- winsorize_results %>%
  filter(abs(error) == min(abs(error))) %>%
  slice(1)

cat("Best cutoff:", best_wins$cutoff, "\n")
cat("  Result:", round(best_wins$phi, 4), "\n")
cat("  Error:", round(best_wins$error, 4), "\n\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("=============================================================================\n")
cat("SUMMARY OF APPROACHES\n")
cat("=============================================================================\n\n")

results_summary <- tibble(
  Approach = c("0. Naive",
               "1. Shrinkage",
               "2. Bootstrap BC",
               "3. Conservative",
               "4. Sample split",
               "5. Winsorize"),
  Result = c(phi_naive,
             best_shrinkage$phi,
             phi_bc,
             best_k$phi,
             NA,
             best_wins$phi),
  Error = c(phi_naive - truth,
            best_shrinkage$error,
            phi_bc - truth,
            best_k$error,
            NA,
            best_wins$error),
  AbsError = abs(c(phi_naive - truth,
                   best_shrinkage$error,
                   phi_bc - truth,
                   best_k$error,
                   NA,
                   best_wins$error))
)

print(results_summary %>% arrange(AbsError))

cat("\nTruth:", round(truth, 4), "\n\n")

best_approach <- results_summary %>%
  filter(!is.na(AbsError)) %>%
  filter(AbsError == min(AbsError)) %>%
  slice(1)

cat("BEST APPROACH:", best_approach$Approach, "\n")
cat("  Error:", round(best_approach$Error, 4), "\n")
cat("  Improvement over naive:",
    round(100 * (abs(phi_naive - truth) - best_approach$AbsError) / abs(phi_naive - truth), 1), "%\n\n")

if (best_approach$AbsError < 0.01) {
  cat("✓ This approach nearly eliminates the bias!\n")
} else if (best_approach$AbsError < abs(phi_naive - truth) / 2) {
  cat("~ This approach reduces bias by >50%\n")
  cat("  May be worth pursuing further\n")
} else {
  cat("✗ None of these approaches fully solve the problem\n")
  cat("  Need more sophisticated methods\n")
}
