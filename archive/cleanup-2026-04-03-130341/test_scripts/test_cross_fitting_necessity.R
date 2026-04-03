#!/usr/bin/env Rscript
# TEST: Is cross-fitting necessary for shrinkage method?
# Quick comparison: cross-fit vs no cross-fit

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("CROSS-FITTING NECESSITY TEST\n")
cat("=============================================================================\n\n")

cat("QUESTION: Does shrinkage method require cross-fitting?\n\n")

# =============================================================================
# Helper functions
# =============================================================================

compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w) {
  n <- length(X1)
  tau_s_true <- tau_s_fn(X1, X2)
  tau_y_true <- tau_y_fn(X1, X2)
  h_true <- tau_s_true * tau_y_true
  X <- scale(cbind(X1, X2))
  cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  optimize(dual_objective, interval = c(0, 100), maximum = TRUE)$objective
}

estimate_with_shrinkage <- function(data, covariates, lambda_w, shrink_factor, cross_fit) {
  tau_s <- estimate_treatment_effect_function(
    data = data, outcome = "S", covariates = covariates,
    method = "kernel", cross_fit = cross_fit  # <-- Varies
  )
  tau_y <- estimate_treatment_effect_function(
    data = data, outcome = "Y", covariates = covariates,
    method = "kernel", cross_fit = cross_fit  # <-- Varies
  )

  h_est <- tau_s$tau_hat * tau_y$tau_hat
  h_mean <- mean(h_est)
  h_shrunk <- h_mean + shrink_factor * (h_est - h_mean)

  n <- nrow(data)
  X_scaled <- scale(data[, covariates])
  cost_matrix <- as.matrix(dist(X_scaled, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    obj_matrix <- matrix(h_shrunk, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  optimize(dual_objective, interval = c(0, 100), maximum = TRUE)$objective
}

# =============================================================================
# Run comparison
# =============================================================================

n_reps <- 50
n <- 250
lambda_w <- 0.5
shrink_factors <- c(0.4, 0.5, 0.6)

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

cat("Testing with", n_reps, "replications\n")
cat("  n =", n, "\n")
cat("  lambda_w =", lambda_w, "\n")
cat("  Shrinkage factors:", paste(shrink_factors, collapse = ", "), "\n\n")

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
  truth <- compute_true_minimax(X1, X2, tau_s_fn, tau_y_fn, lambda_w)

  # Test: cross-fit TRUE vs FALSE, multiple shrinkage factors
  test_grid <- expand.grid(
    cross_fit = c(TRUE, FALSE),
    shrink_factor = shrink_factors
  )

  results_rep <- map_dfr(1:nrow(test_grid), function(i) {
    cf <- test_grid$cross_fit[i]
    sf <- test_grid$shrink_factor[i]

    est <- tryCatch({
      estimate_with_shrinkage(data, c("X1", "X2"), lambda_w, sf, cf)
    }, error = function(e) NA)

    tibble(
      cross_fit = cf,
      shrink_factor = sf,
      estimate = est
    )
  })

  results_rep %>%
    mutate(
      rep = rep,
      truth = truth,
      bias = estimate - truth
    )
})

cat("\n")

# =============================================================================
# Analyze results
# =============================================================================

cat("=============================================================================\n")
cat("RESULTS\n")
cat("=============================================================================\n\n")

# Overall comparison
summary_stats <- results %>%
  filter(!is.na(bias)) %>%
  group_by(cross_fit, shrink_factor) %>%
  summarise(
    n_reps = n(),
    mean_bias = mean(bias),
    median_bias = median(bias),
    rmse = sqrt(mean(bias^2)),
    mae = mean(abs(bias)),
    .groups = "drop"
  ) %>%
  arrange(shrink_factor, cross_fit)

cat("PERFORMANCE BY CROSS-FITTING AND SHRINKAGE:\n\n")
print(summary_stats, n = Inf)
cat("\n")

# Direct comparison
comparison <- summary_stats %>%
  select(cross_fit, shrink_factor, mean_bias, rmse) %>%
  pivot_wider(
    names_from = cross_fit,
    values_from = c(mean_bias, rmse),
    names_sep = "_"
  ) %>%
  mutate(
    bias_diff = mean_bias_FALSE - mean_bias_TRUE,
    rmse_diff = rmse_FALSE - rmse_TRUE
  )

cat("DIFFERENCE (No Cross-Fit - Cross-Fit):\n\n")
print(comparison, n = Inf)
cat("\n")

# Statistical test
cat("DOES CROSS-FITTING MATTER?\n\n")

for (sf in shrink_factors) {
  results_sf <- results %>% filter(shrink_factor == sf, !is.na(bias))

  bias_cf_true <- results_sf %>% filter(cross_fit == TRUE) %>% pull(bias)
  bias_cf_false <- results_sf %>% filter(cross_fit == FALSE) %>% pull(bias)

  test_result <- t.test(abs(bias_cf_true), abs(bias_cf_false), paired = TRUE)

  cat(sprintf("Shrinkage %.1f:\n", sf))
  cat(sprintf("  Mean |bias| with cross-fit:    %.4f\n", mean(abs(bias_cf_true))))
  cat(sprintf("  Mean |bias| without cross-fit: %.4f\n", mean(abs(bias_cf_false))))
  cat(sprintf("  Difference: %.4f (p = %.4f)\n", test_result$estimate, test_result$p.value))

  if (test_result$p.value < 0.05) {
    if (mean(abs(bias_cf_true)) < mean(abs(bias_cf_false))) {
      cat("  → Cross-fitting HELPS (statistically significant)\n")
    } else {
      cat("  → Cross-fitting HURTS (statistically significant)\n")
    }
  } else {
    cat("  → No significant difference\n")
  }
  cat("\n")
}

# =============================================================================
# Visualization
# =============================================================================

library(ggplot2)

# Bias distribution
p1 <- ggplot(results %>% filter(!is.na(bias)),
             aes(x = factor(shrink_factor), y = bias, fill = cross_fit)) +
  geom_boxplot() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  labs(
    title = "Bias: With vs Without Cross-Fitting",
    x = "Shrinkage Factor",
    y = "Bias",
    fill = "Cross-Fit"
  ) +
  theme_minimal(base_size = 12)

# RMSE comparison
p2 <- ggplot(summary_stats, aes(x = shrink_factor, y = rmse, color = cross_fit, group = cross_fit)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  labs(
    title = "RMSE: With vs Without Cross-Fitting",
    x = "Shrinkage Factor",
    y = "RMSE",
    color = "Cross-Fit"
  ) +
  theme_minimal(base_size = 12)

ggsave(here("test_cross_fitting_bias.png"), p1, width = 8, height = 6)
ggsave(here("test_cross_fitting_rmse.png"), p2, width = 8, height = 6)

cat("Plots saved:\n")
cat("  - test_cross_fitting_bias.png\n")
cat("  - test_cross_fitting_rmse.png\n\n")

# =============================================================================
# Save and conclude
# =============================================================================

saveRDS(results, here("test_cross_fitting_results.rds"))
cat("Results saved to: test_cross_fitting_results.rds\n\n")

cat("=============================================================================\n")
cat("CONCLUSION\n")
cat("=============================================================================\n\n")

# Determine if cross-fitting is necessary
best_with_cf <- summary_stats %>% filter(cross_fit == TRUE) %>% slice_min(rmse, n = 1)
best_without_cf <- summary_stats %>% filter(cross_fit == FALSE) %>% slice_min(rmse, n = 1)

rmse_improvement <- (best_without_cf$rmse - best_with_cf$rmse) / best_without_cf$rmse * 100

if (abs(rmse_improvement) > 10) {
  if (rmse_improvement > 0) {
    cat("✓ CROSS-FITTING IS IMPORTANT\n\n")
    cat(sprintf("Cross-fitting reduces RMSE by %.1f%%\n", rmse_improvement))
    cat(sprintf("  Best with cross-fit: shrink=%.1f, RMSE=%.4f\n",
                best_with_cf$shrink_factor, best_with_cf$rmse))
    cat(sprintf("  Best without: shrink=%.1f, RMSE=%.4f\n",
                best_without_cf$shrink_factor, best_without_cf$rmse))
    cat("\nRECOMMENDATION: Always use cross_fit=TRUE\n")
  } else {
    cat("⚠ CROSS-FITTING HURTS PERFORMANCE\n\n")
    cat(sprintf("Cross-fitting increases RMSE by %.1f%%\n", abs(rmse_improvement)))
    cat("\nRECOMMENDATION: Use cross_fit=FALSE\n")
  }
} else {
  cat("~ CROSS-FITTING HAS MINIMAL EFFECT\n\n")
  cat(sprintf("RMSE difference: %.1f%% (negligible)\n", abs(rmse_improvement)))
  cat("\nRECOMMENDATION: Either setting works; use cross_fit=TRUE as conservative default\n")
  cat("  (Prevents overfitting in case of small sample sizes)\n")
}

cat("\n=============================================================================\n")
