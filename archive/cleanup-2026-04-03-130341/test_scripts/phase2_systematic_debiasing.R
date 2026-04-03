#!/usr/bin/env Rscript
# PHASE 2: Systematic Debiasing Comparison
# Test 5 correction approaches to achieve nominal coverage

library(tidyverse)
library(here)

devtools::load_all(here("package"))

cat("=============================================================================\n")
cat("PHASE 2: SYSTEMATIC DEBIASING COMPARISON\n")
cat("=============================================================================\n\n")

cat("GOAL: Find correction that achieves coverage ≥93%\n\n")

cat("APPROACHES:\n")
cat("  1. Conservative penalty (k ∈ {3, 4, 5, 6, 8, 10})\n")
cat("  2. Shrinkage + DRO (shrink concordances toward mean)\n")
cat("  3. Empirical Bayes (posterior mean estimates)\n")
cat("  4. Percentile shift (shift distribution up)\n")
cat("  5. Hybrid (combine multiple corrections)\n\n")

# =============================================================================
# Helper: Compute truth
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

# =============================================================================
# Correction Methods
# =============================================================================

#' Approach 1: Conservative Penalty
#' phi_corrected = phi_naive + k * SE
apply_conservative_penalty <- function(phi_naive, concordances, n, k) {
  se_estimate <- sd(concordances) / sqrt(n)
  phi_naive + k * se_estimate
}

#' Approach 2: Shrinkage + DRO
#' Shrink concordance estimates toward mean before applying DRO
#' h_shrunk[i] = mean(h) + shrink_factor * (h[i] - mean(h))
apply_shrinkage_dro <- function(data, covariates, lambda_w, shrink_factor) {
  # Estimate treatment effects
  tau_s <- estimate_treatment_effect_function(
    data = data,
    outcome = "S",
    covariates = covariates,
    method = "kernel",
    cross_fit = TRUE
  )

  tau_y <- estimate_treatment_effect_function(
    data = data,
    outcome = "Y",
    covariates = covariates,
    method = "kernel",
    cross_fit = TRUE
  )

  # Concordances
  h_est <- tau_s$tau_hat * tau_y$tau_hat

  # Shrink toward mean
  h_mean <- mean(h_est)
  h_shrunk <- h_mean + shrink_factor * (h_est - h_mean)

  # Apply DRO with shrunk concordances
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

#' Approach 3: Empirical Bayes Shrinkage
#' Model h_i ~ N(mu, sigma^2), use posterior mean
apply_empirical_bayes <- function(phi_naive, concordances, n) {
  # Assume h_i ~ N(mu, tau^2) with mu ~ N(mu_0, sigma_0^2)
  # Posterior mean: (sigma_0^2 * mean(h) + tau^2 * mu_0) / (sigma_0^2 + tau^2)

  h_mean <- mean(concordances)
  h_var <- var(concordances)

  # Empirical Bayes: estimate hyperparameters from data
  # Use method of moments: E[h_i] = mu, Var[h_i] = tau^2 + sigma^2/n

  # Simple approach: shrink toward grand mean with empirical shrinkage factor
  # Shrinkage factor based on ratio of within to total variance
  shrinkage_factor <- max(0, 1 - 1/h_var)  # James-Stein type

  h_eb <- h_mean + shrinkage_factor * (concordances - h_mean)

  # Re-compute DRO with EB-adjusted concordances
  # For now, just return adjusted mean as conservative estimate
  mean(h_eb)
}

#' Approach 4: Percentile Shift
#' Shift entire concordance distribution upward to correct bias
apply_percentile_shift <- function(phi_naive, concordances, shift_percentile = 0.25) {
  # Estimate bias as difference between naive and shifted distribution
  # Shift: use (1-shift_percentile) quantile instead of minimum

  sorted_h <- sort(concordances)
  shift_value <- quantile(sorted_h, shift_percentile)

  # Add shift to naive estimate
  phi_naive + (shift_value - min(concordances))
}

#' Approach 5: Hybrid
#' Combine conservative penalty with shrinkage
apply_hybrid <- function(phi_naive, concordances, n, k = 2, shrink_factor = 0.7) {
  se_estimate <- sd(concordances) / sqrt(n)

  # First shrink concordances
  h_mean <- mean(concordances)
  h_shrunk <- h_mean + shrink_factor * (concordances - h_mean)

  # Then apply conservative penalty on shrunk distribution
  se_shrunk <- sd(h_shrunk) / sqrt(n)
  phi_naive + k * se_shrunk
}

# =============================================================================
# Run single replication with all methods
# =============================================================================

run_one_replication <- function(rep, n, lambda_w, tau_s_fn, tau_y_fn) {
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

  # Naive estimate
  result_naive <- observation_level_minimax_wasserstein(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = lambda_w,
    tau_method = "kernel",
    cross_fit = TRUE,
    scale_covariates = TRUE
  )

  phi_naive <- result_naive$phi_star
  concordances <- result_naive$concordance_i

  # Apply all correction methods
  results_list <- list()

  # 0. Naive (baseline)
  results_list[[1]] <- tibble(
    method = "Naive",
    parameter = NA_character_,
    estimate = phi_naive
  )

  # 1. Conservative penalty (multiple k values)
  k_values <- c(3, 4, 5, 6, 8, 10)
  for (k in k_values) {
    phi_corrected <- apply_conservative_penalty(phi_naive, concordances, n, k)
    results_list[[length(results_list) + 1]] <- tibble(
      method = "Conservative",
      parameter = as.character(k),
      estimate = phi_corrected
    )
  }

  # 2. Shrinkage + DRO (multiple shrinkage factors)
  shrink_factors <- c(0.5, 0.6, 0.7, 0.8)
  for (sf in shrink_factors) {
    phi_shrink <- tryCatch({
      apply_shrinkage_dro(data, c("X1", "X2"), lambda_w, sf)
    }, error = function(e) NA)

    results_list[[length(results_list) + 1]] <- tibble(
      method = "Shrinkage",
      parameter = as.character(sf),
      estimate = phi_shrink
    )
  }

  # 3. Empirical Bayes
  phi_eb <- tryCatch({
    apply_empirical_bayes(phi_naive, concordances, n)
  }, error = function(e) NA)

  results_list[[length(results_list) + 1]] <- tibble(
    method = "EmpiricalBayes",
    parameter = NA_character_,
    estimate = phi_eb
  )

  # 4. Percentile shift (multiple shift levels)
  shift_percentiles <- c(0.1, 0.2, 0.25, 0.3)
  for (sp in shift_percentiles) {
    phi_shift <- apply_percentile_shift(phi_naive, concordances, sp)
    results_list[[length(results_list) + 1]] <- tibble(
      method = "PercentileShift",
      parameter = as.character(sp),
      estimate = phi_shift
    )
  }

  # 5. Hybrid (multiple combinations)
  hybrid_params <- expand.grid(k = c(2, 3), shrink = c(0.6, 0.7))
  for (i in 1:nrow(hybrid_params)) {
    phi_hybrid <- apply_hybrid(phi_naive, concordances, n,
                                k = hybrid_params$k[i],
                                shrink_factor = hybrid_params$shrink[i])
    results_list[[length(results_list) + 1]] <- tibble(
      method = "Hybrid",
      parameter = paste0("k=", hybrid_params$k[i], ",s=", hybrid_params$shrink[i]),
      estimate = phi_hybrid
    )
  }

  # Combine all results
  bind_rows(results_list) %>%
    mutate(
      rep = rep,
      truth = truth,
      bias = estimate - truth,
      abs_bias = abs(bias)
    )
}

# =============================================================================
# Run comparison across replications
# =============================================================================

cat("=============================================================================\n")
cat("RUNNING COMPARISON\n")
cat("=============================================================================\n\n")

n_reps <- 50
n <- 250
lambda_w <- 0.5

tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

cat("n_reps:", n_reps, "\n")
cat("n:", n, "\n")
cat("lambda_w:", lambda_w, "\n\n")

results <- map_dfr(1:n_reps, function(rep) {
  if (rep %% 10 == 0) cat("Replication", rep, "/", n_reps, "\n")
  run_one_replication(rep, n, lambda_w, tau_s_fn, tau_y_fn)
})

cat("\n")

# =============================================================================
# Analyze results
# =============================================================================

cat("=============================================================================\n")
cat("COMPARATIVE ANALYSIS\n")
cat("=============================================================================\n\n")

# Summary by method
summary_stats <- results %>%
  group_by(method, parameter) %>%
  summarise(
    n_reps = n(),
    mean_bias = mean(bias, na.rm = TRUE),
    median_bias = median(bias, na.rm = TRUE),
    rmse = sqrt(mean(bias^2, na.rm = TRUE)),
    mae = mean(abs_bias, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(abs(mean_bias))

cat("SUMMARY BY METHOD:\n\n")
print(summary_stats, n = Inf)
cat("\n")

# Identify best methods
cat("=============================================================================\n")
cat("TOP PERFORMERS\n")
cat("=============================================================================\n\n")

top_methods <- summary_stats %>%
  filter(!is.na(mean_bias)) %>%
  arrange(rmse) %>%
  head(10)

cat("TOP 10 BY RMSE:\n\n")
print(top_methods, n = Inf)
cat("\n")

# Bias-variance tradeoff
cat("=============================================================================\n")
cat("BIAS-VARIANCE ANALYSIS\n")
cat("=============================================================================\n\n")

naive_bias <- summary_stats %>% filter(method == "Naive") %>% pull(mean_bias)
naive_rmse <- summary_stats %>% filter(method == "Naive") %>% pull(rmse)

improvement_table <- summary_stats %>%
  filter(method != "Naive", !is.na(mean_bias)) %>%
  mutate(
    bias_reduction = (naive_bias - mean_bias) / abs(naive_bias) * 100,
    rmse_reduction = (naive_rmse - rmse) / naive_rmse * 100
  ) %>%
  select(method, parameter, mean_bias, rmse, bias_reduction, rmse_reduction) %>%
  arrange(desc(rmse_reduction))

cat("IMPROVEMENT OVER NAIVE:\n\n")
print(improvement_table %>% head(10), n = Inf)
cat("\n")

# =============================================================================
# Visualization
# =============================================================================

cat("=============================================================================\n")
cat("CREATING VISUALIZATIONS\n")
cat("=============================================================================\n\n")

library(ggplot2)

# 1. Bias distribution by method (top methods only)
top_method_names <- top_methods %>%
  unite("method_id", method, parameter, sep = "_", remove = FALSE, na.rm = TRUE) %>%
  pull(method_id)

results_top <- results %>%
  unite("method_id", method, parameter, sep = "_", remove = FALSE, na.rm = TRUE) %>%
  filter(method_id %in% top_method_names[1:5] | method == "Naive")

p1 <- ggplot(results_top, aes(x = method_id, y = bias)) +
  geom_boxplot() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  coord_flip() +
  labs(
    title = "Bias Distribution: Top 5 Methods vs Naive",
    x = "Method",
    y = "Bias (Estimate - Truth)"
  ) +
  theme_minimal(base_size = 10)

# 2. RMSE comparison
p2 <- ggplot(top_methods, aes(x = reorder(paste(method, parameter, sep = "_"), rmse), y = rmse)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "RMSE: Top 10 Methods",
    x = "Method",
    y = "RMSE"
  ) +
  theme_minimal(base_size = 10)

# 3. Bias vs RMSE tradeoff
p3 <- ggplot(summary_stats %>% filter(!is.na(mean_bias)),
             aes(x = abs(mean_bias), y = rmse, color = method)) +
  geom_point(size = 2) +
  labs(
    title = "Bias-RMSE Tradeoff",
    x = "|Mean Bias|",
    y = "RMSE",
    color = "Method"
  ) +
  theme_minimal(base_size = 10)

ggsave(here("phase2_bias_distribution.png"), p1, width = 8, height = 6)
ggsave(here("phase2_rmse_comparison.png"), p2, width = 8, height = 6)
ggsave(here("phase2_bias_rmse_tradeoff.png"), p3, width = 8, height = 6)

cat("Plots saved:\n")
cat("  - phase2_bias_distribution.png\n")
cat("  - phase2_rmse_comparison.png\n")
cat("  - phase2_bias_rmse_tradeoff.png\n\n")

# =============================================================================
# Save results
# =============================================================================

results_list <- list(
  all_results = results,
  summary = summary_stats,
  top_methods = top_methods,
  improvement = improvement_table
)

saveRDS(results_list, here("phase2_debiasing_results.rds"))
cat("Results saved to: phase2_debiasing_results.rds\n\n")

# =============================================================================
# Recommendation
# =============================================================================

cat("=============================================================================\n")
cat("RECOMMENDATION\n")
cat("=============================================================================\n\n")

best_method <- top_methods[1, ]

cat("BEST PERFORMING METHOD:\n")
cat("  Method:", best_method$method, "\n")
cat("  Parameter:", ifelse(is.na(best_method$parameter), "N/A", best_method$parameter), "\n")
cat("  Mean bias:", round(best_method$mean_bias, 4), "\n")
cat("  RMSE:", round(best_method$rmse, 4), "\n\n")

if (abs(best_method$mean_bias) < 0.01 && best_method$rmse < 0.04) {
  cat("✓ EXCELLENT: This method achieves low bias and RMSE\n")
  cat("  Recommend proceeding to coverage validation\n\n")
} else if (abs(best_method$mean_bias) < 0.02 && best_method$rmse < 0.06) {
  cat("~ GOOD: This method shows substantial improvement\n")
  cat("  Recommend coverage validation to verify nominal coverage\n\n")
} else {
  cat("⚠ INSUFFICIENT: No method achieves target performance\n")
  cat("  May need to consider alternative approaches:\n")
  cat("    - Bayesian DRO\n")
  cat("    - Mean performance (not minimax)\n")
  cat("    - Larger sample sizes\n\n")
}

cat("=============================================================================\n")
cat("PHASE 2 COMPLETE\n")
cat("=============================================================================\n")
