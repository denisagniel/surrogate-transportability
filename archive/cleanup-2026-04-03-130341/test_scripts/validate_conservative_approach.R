#!/usr/bin/env Rscript
# Validate conservative plug-in approach across replications

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("VALIDATING CONSERVATIVE PLUG-IN APPROACH\n")
cat("=============================================================================\n\n")

# =============================================================================
# Run multiple replications
# =============================================================================

n_reps <- 50  # Test on 50 replications
n <- 250
lambda_w <- 0.5

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

cat("Testing with", n_reps, "replications\n")
cat("  n =", n, "\n")
cat("  lambda_w =", lambda_w, "\n\n")

results <- map_dfr(1:n_reps, function(rep) {
  if (rep %% 10 == 0) cat("Rep", rep, "/", n_reps, "\n")

  set.seed(rep + 5000)

  # Generate data
  X1 <- rnorm(n)
  X2 <- rnorm(n)
  A <- rbinom(n, 1, 0.5)

  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)

  S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
  Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

  data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

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

  # Estimate
  result <- observation_level_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = lambda_w,
    tau_method = "kernel",
    cross_fit = TRUE,
    scale_covariates = TRUE
  )

  phi_naive <- result$phi_star

  # Conservative correction
  h_est <- result$concordance_i
  se_estimate <- sd(h_est) / sqrt(n)

  # Test multiple k values
  k_values <- c(0, 1, 2, 2.5, 3)
  corrections <- map_dfr(k_values, function(k) {
    phi_corrected <- phi_naive + k * se_estimate

    tibble(
      k = k,
      phi = phi_corrected,
      error = phi_corrected - truth,
      abs_error = abs(phi_corrected - truth)
    )
  })

  corrections %>%
    mutate(rep = rep, truth = truth, phi_naive = phi_naive, se_estimate = se_estimate)
})

cat("\n")

# =============================================================================
# Analyze results
# =============================================================================

cat("=============================================================================\n")
cat("RESULTS ACROSS REPLICATIONS\n")
cat("=============================================================================\n\n")

# For each k, compute mean error and RMSE
summary_by_k <- results %>%
  group_by(k) %>%
  summarize(
    mean_error = mean(error),
    median_error = median(error),
    rmse = sqrt(mean(error^2)),
    mean_abs_error = mean(abs_error),
    .groups = "drop"
  ) %>%
  arrange(mean_abs_error)

cat("Performance by k value:\n")
print(summary_by_k)
cat("\n")

best_k <- summary_by_k$k[1]

cat("Best k:", best_k, "\n")
cat("  Mean error:", round(summary_by_k$mean_error[1], 4), "\n")
cat("  RMSE:", round(summary_by_k$rmse[1], 4), "\n")
cat("  Mean abs error:", round(summary_by_k$mean_abs_error[1], 4), "\n\n")

# Compare naive vs corrected
naive_performance <- results %>%
  filter(k == 0) %>%
  summarize(
    mean_error = mean(error),
    rmse = sqrt(mean(error^2))
  )

corrected_performance <- results %>%
  filter(k == best_k) %>%
  summarize(
    mean_error = mean(error),
    rmse = sqrt(mean(error^2))
  )

cat("COMPARISON:\n")
cat("  Naive:     mean error =", round(naive_performance$mean_error, 4),
    ", RMSE =", round(naive_performance$rmse, 4), "\n")
cat("  Corrected: mean error =", round(corrected_performance$mean_error, 4),
    ", RMSE =", round(corrected_performance$rmse, 4), "\n\n")

improvement_bias <- 100 * (1 - abs(corrected_performance$mean_error) / abs(naive_performance$mean_error))
improvement_rmse <- 100 * (1 - corrected_performance$rmse / naive_performance$rmse)

cat("Improvement:\n")
cat("  Bias reduction:", round(improvement_bias, 1), "%\n")
cat("  RMSE reduction:", round(improvement_rmse, 1), "%\n\n")

# =============================================================================
# Check if k is stable
# =============================================================================

cat("=============================================================================\n")
cat("STABILITY OF k\n")
cat("=============================================================================\n\n")

cat("Does the same k work well across different replications?\n\n")

# For each rep, find which k gives smallest abs error
best_k_per_rep <- results %>%
  group_by(rep) %>%
  slice_min(abs_error, n = 1) %>%
  ungroup()

cat("Distribution of best k across reps:\n")
print(table(best_k_per_rep$k))
cat("\n")

mode_k <- as.numeric(names(sort(table(best_k_per_rep$k), decreasing = TRUE)[1]))

cat("Most common best k:", mode_k, "\n\n")

if (mode_k == best_k) {
  cat("✓ The globally optimal k matches the most common per-rep optimal k\n")
  cat("  This suggests k is stable and can be used as a fixed constant\n\n")
} else {
  cat("⚠ Discrepancy between global and per-rep optimal k\n")
  cat("  May need adaptive k selection\n\n")
}

# =============================================================================
# Estimate coverage with corrected estimates
# =============================================================================

cat("=============================================================================\n")
cat("ESTIMATED COVERAGE WITH CORRECTION\n")
cat("=============================================================================\n\n")

cat("Note: This is approximate - proper coverage needs bootstrap CIs\n")
cat("      But we can check if correction eliminates the bias issue\n\n")

# Approximate: assume CI is symmetric around estimate with fixed width
# Use average CI width from validation (was ~0.10)
approx_ci_width <- 0.10
approx_ci_half_width <- approx_ci_width / 2

coverage_corrected <- results %>%
  filter(k == best_k) %>%
  mutate(
    ci_lower_approx = phi - approx_ci_half_width,
    ci_upper_approx = phi + approx_ci_half_width,
    covered_approx = (truth >= ci_lower_approx & truth <= ci_upper_approx)
  ) %>%
  summarize(coverage = mean(covered_approx))

cat("Approximate coverage with k =", best_k, ":", round(coverage_corrected$coverage, 3), "\n\n")

if (coverage_corrected$coverage >= 0.90) {
  cat("✓ Correction may restore nominal coverage!\n")
  cat("  Need to validate with proper bootstrap CIs\n\n")
} else {
  cat("⚠ Coverage still below nominal\n")
  cat("  May need different approach or larger k\n\n")
}

# =============================================================================
# Recommendation
# =============================================================================

cat("=============================================================================\n")
cat("RECOMMENDATION\n")
cat("=============================================================================\n\n")

if (abs(corrected_performance$mean_error) < 0.01 && improvement_bias > 80) {
  cat("✓✓✓ CONSERVATIVE PLUG-IN APPROACH WORKS ✓✓✓\n\n")
  cat("Use correction: phi_corrected = phi_naive + k * SE\n")
  cat("  Where: SE = sd(concordances) / sqrt(n)\n")
  cat("         k =", best_k, "\n\n")

  cat("Performance:\n")
  cat("  - Reduces bias by", round(improvement_bias, 1), "%\n")
  cat("  - Reduces RMSE by", round(improvement_rmse, 1), "%\n")
  cat("  - Mean error:", round(corrected_performance$mean_error, 4), "(nearly unbiased)\n\n")

  cat("Next steps:\n")
  cat("  1. Implement corrected_observation_level_minimax_wasserstein()\n")
  cat("  2. Run full coverage validation with bootstrap CIs\n")
  cat("  3. If coverage ≥ 93%, solution is complete\n")

} else {
  cat("⚠ PARTIAL IMPROVEMENT\n\n")
  cat("Conservative approach helps but doesn't fully solve the problem\n")
  cat("Need to explore other methods\n")
}
