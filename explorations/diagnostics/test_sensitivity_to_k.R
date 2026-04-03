#!/usr/bin/env Rscript

#' DEMONSTRATION: Sensitivity Analysis Across K Values
#'
#' Shows how inference results change with different assumptions about
#' the number of latent types (K) when types are unobserved.
#'
#' This demonstrates Solution 3 from PRACTICAL_GUIDANCE_UNOBSERVED_TYPES.md

library(dplyr)
library(tibble)
library(ggplot2)
library(MCMCpack)

set.seed(20260324)

cat("================================================================\n")
cat("DEMONSTRATION: Sensitivity to K Assumption\n")
cat("================================================================\n\n")

# Generate data with K_TRUE=20 types (unobserved)
K_TRUE <- 20
n <- 1000
lambda <- 0.3

cat(sprintf("Generating data with K_TRUE=%d types (unknown to analyst)\n", K_TRUE))
cat(sprintf("Sample size: n=%d\n", n))
cat(sprintf("Lambda: %.2f\n\n", lambda))

# Generate population with K_TRUE types
tau_s_true <- rnorm(K_TRUE, 0, 0.3)
tau_y_true <- 0.8 * tau_s_true + rnorm(K_TRUE, 0, 0.1)  # Correlated
true_correlation <- cor(tau_s_true, tau_y_true)

cat(sprintf("True population correlation: %.3f\n\n", true_correlation))

# Generate data (analyst doesn't observe types)
types_true <- sample(1:K_TRUE, size = n, replace = TRUE)
A <- rbinom(n, 1, 0.5)
S <- numeric(n)
Y <- numeric(n)

for (i in 1:n) {
  type_i <- types_true[i]
  S[i] <- A[i] * tau_s_true[type_i] + rnorm(1, 0, 0.2)
  Y[i] <- A[i] * tau_y_true[type_i] + rnorm(1, 0, 0.2)
}

data_observed <- tibble(A = A, S = S, Y = Y)
# Note: types_true NOT included in data_observed (unobserved)

cat("Data generated. Analyst sees (A, S, Y) but not true types.\n\n")

# Function to estimate correlation under assumed K
estimate_with_assumed_K <- function(data, K_assumed, lambda, M = 500) {
  n <- nrow(data)

  if (K_assumed >= n) {
    # K=n: observation-level innovations
    innovations <- rdirichlet(M, rep(1, n))
    obs_weights_list <- lapply(1:M, function(m) innovations[m, ])

  } else {
    # K < n: cluster into K groups, use type-level innovations

    # Simple clustering on (S, Y)
    # In practice, could use more sophisticated methods
    km <- kmeans(data[, c("S", "Y")], centers = K_assumed, nstart = 10)
    types_assumed <- km$cluster

    # Generate type-level innovations
    type_innovations <- rdirichlet(M, rep(1, K_assumed))

    # Convert to observation weights
    obs_weights_list <- lapply(1:M, function(m) {
      type_weights_m <- type_innovations[m, ]
      p0_type <- rep(1/K_assumed, K_assumed)
      q_m_type <- (1 - lambda) * p0_type + lambda * type_weights_m

      # Map to observations
      obs_w <- numeric(n)
      for (k in 1:K_assumed) {
        type_k_obs <- which(types_assumed == k)
        if (length(type_k_obs) > 0) {
          obs_w[type_k_obs] <- q_m_type[k] / length(type_k_obs)
        }
      }
      obs_w / sum(obs_w)  # Normalize
    })
  }

  # Compute treatment effects for each innovation
  effects <- matrix(NA, nrow = M, ncol = 2)
  for (m in 1:M) {
    # Bootstrap with weights
    boot_idx <- sample(1:n, size = n, replace = TRUE, prob = obs_weights_list[[m]])
    boot_sample <- data[boot_idx, ]

    delta_s <- mean(boot_sample$S[boot_sample$A == 1]) -
               mean(boot_sample$S[boot_sample$A == 0])
    delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) -
               mean(boot_sample$Y[boot_sample$A == 0])

    effects[m, ] <- c(delta_s, delta_y)
  }

  # Compute correlation
  corr_est <- cor(effects[, 1], effects[, 2])

  # Compute SE and CI (simple percentile)
  # For proper delta method, would need gradient
  se_bootstrap <- sd(effects[, 1]) * sqrt(1/n)  # Rough approximation
  ci_lower <- quantile(effects[, 1], 0.025)
  ci_upper <- quantile(effects[, 1], 0.975)

  list(
    K = K_assumed,
    correlation = corr_est,
    sd_delta_s = sd(effects[, 1]),
    sd_delta_y = sd(effects[, 2]),
    mean_delta_s = mean(effects[, 1]),
    mean_delta_y = mean(effects[, 2])
  )
}

# Run sensitivity analysis across different K assumptions
cat("================================================================\n")
cat("SENSITIVITY ANALYSIS: Testing Different K Assumptions\n")
cat("================================================================\n\n")

K_values <- c(4, 10, 20, 50, 100, 500, n)
results_list <- list()

cat("Running inference under different K assumptions...\n\n")

for (K_assumed in K_values) {
  cat(sprintf("  K = %4d...", K_assumed))
  result <- estimate_with_assumed_K(data_observed, K_assumed, lambda, M = 500)
  results_list[[length(results_list) + 1]] <- result
  cat(sprintf(" correlation = %.3f\n", result$correlation))
}

results_df <- bind_rows(results_list)

cat("\n")
cat("================================================================\n")
cat("RESULTS: How Correlation Estimate Changes with K\n")
cat("================================================================\n\n")

cat(sprintf("True population correlation: %.3f\n", true_correlation))
cat(sprintf("True K: %d\n\n", K_TRUE))

cat("Estimates under different K assumptions:\n")
cat("------------------------------------------------------------\n")
cat(sprintf("%-10s %-12s %-12s %-12s\n", "K assumed", "Correlation", "SD(ΔS)", "SD(ΔY)"))
cat("------------------------------------------------------------\n")

for (i in 1:nrow(results_df)) {
  row <- results_df[i, ]
  cat(sprintf("%-10s %-12.3f %-12.4f %-12.4f",
              ifelse(row$K == n, sprintf("%d (=n)", n), as.character(row$K)),
              row$correlation,
              row$sd_delta_s,
              row$sd_delta_y))

  # Highlight if close to truth
  if (abs(row$correlation - true_correlation) < 0.05) {
    cat("  ✓ (close to truth)")
  }
  if (row$K == K_TRUE) {
    cat("  ← TRUE K")
  }
  cat("\n")
}

cat("------------------------------------------------------------\n\n")

# Analysis
cat("================================================================\n")
cat("INTERPRETATION\n")
cat("================================================================\n\n")

best_idx <- which.min(abs(results_df$correlation - true_correlation))
best_K <- results_df$K[best_idx]

cat("Key findings:\n\n")

cat(sprintf("1. Best match to truth: K=%d (correlation=%.3f vs true %.3f)\n",
            best_K, results_df$correlation[best_idx], true_correlation))

cat(sprintf("2. Range of estimates: [%.3f, %.3f] (range=%.3f)\n",
            min(results_df$correlation),
            max(results_df$correlation),
            max(results_df$correlation) - min(results_df$correlation)))

# Check sensitivity
range_corr <- max(results_df$correlation) - min(results_df$correlation)
if (range_corr < 0.1) {
  cat("3. LOW SENSITIVITY: Results fairly stable across K ✓\n")
  cat("   → Conclusions robust to K assumption\n\n")
} else if (range_corr < 0.2) {
  cat("3. MODERATE SENSITIVITY: Results vary somewhat with K\n")
  cat("   → Should report range or use domain knowledge to select K\n\n")
} else {
  cat("3. HIGH SENSITIVITY: Results very sensitive to K assumption ⚠\n")
  cat("   → Cannot make strong conclusions without better K estimate\n\n")
}

# Compare small vs large K
small_K_idx <- which(results_df$K == 4)
large_K_idx <- which(results_df$K == n)

cat(sprintf("4. Small K (K=4): correlation=%.3f, SD(ΔS)=%.4f\n",
            results_df$correlation[small_K_idx],
            results_df$sd_delta_s[small_K_idx]))
cat(sprintf("   Large K (K=n): correlation=%.3f, SD(ΔS)=%.4f\n",
            results_df$correlation[large_K_idx],
            results_df$sd_delta_s[large_K_idx]))
cat(sprintf("   → Small K captures %.1fx more variation\n\n",
            results_df$sd_delta_s[small_K_idx] / results_df$sd_delta_s[large_K_idx]))

cat("================================================================\n")
cat("RECOMMENDATIONS FOR THIS DATASET\n")
cat("================================================================\n\n")

if (range_corr < 0.1) {
  cat("Results are robust to K assumption. Either:\n")
  cat("  • Report using K=n (observation-level, simplest)\n")
  cat("  • Report using K≈20-50 (moderate heterogeneity)\n")
  cat("  • Document that conclusions hold across plausible K values\n\n")

} else {
  cat("Results sensitive to K. Recommend:\n")
  cat("  • Report range of estimates across plausible K values\n")
  cat(sprintf("    'Under K=10: correlation=%.3f; under K=100: correlation=%.3f'\n",
              results_df$correlation[results_df$K == 10],
              results_df$correlation[results_df$K == 100]))
  cat("  • Use domain knowledge to narrow plausible K range\n")
  cat("  • Consider estimating K using cross-validation or model selection\n")
  cat("  • Be conservative: smaller K gives wider variation (more uncertainty)\n\n")
}

cat("For decision-making:\n")
cat("  • Conservative approach: Use small K (K=4 or K=10)\n")
cat("  • This gives wider confidence intervals (more uncertainty)\n")
cat("  • Accounts for possibility of substantial heterogeneity\n\n")

# Visualization
cat("Creating visualization...\n")

p <- ggplot(results_df, aes(x = K, y = correlation)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3, color = "blue") +
  geom_hline(yintercept = true_correlation, linetype = "dashed",
             color = "red", linewidth = 1) +
  geom_vline(xintercept = K_TRUE, linetype = "dotted",
             color = "darkgreen", linewidth = 1) +
  scale_x_log10(breaks = K_values,
                labels = ifelse(K_values == n, "n", as.character(K_values))) +
  labs(
    title = "Sensitivity of Correlation Estimate to K Assumption",
    subtitle = sprintf("True K=%d (green line), True correlation=%.3f (red line)", K_TRUE, true_correlation),
    x = "Assumed K (number of types)",
    y = "Estimated Correlation"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave("sims/results/sensitivity_to_k.png", p, width = 10, height = 6, dpi = 300)
cat("Plot saved to: sims/results/sensitivity_to_k.png\n\n")

cat("================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

cat("When types are unobserved:\n")
cat("  1. Inference results depend on assumed K\n")
cat("  2. Small K: More variation, more conservative\n")
cat("  3. Large K: Less variation, closer to observation-level\n\n")

cat("Practical strategies:\n")
cat("  • If results robust across K: report range, document robustness\n")
cat("  • If results sensitive: use domain knowledge, sensitivity analysis\n")
cat("  • Conservative approach: assume small K (K=10-20)\n")
cat("  • Honest approach: report limitation explicitly\n\n")

cat("This limitation is fundamental to single-sample transportability inference.\n")
cat("Without observing types or making strong assumptions, we cannot fully\n")
cat("learn about compositional variability from a single sample.\n\n")

cat("================================================================\n")
cat("Demonstration complete!\n")
cat("================================================================\n")
