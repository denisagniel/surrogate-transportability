# Test: Sensitivity to Number of Bins K
#
# Check if correlation estimate changes with discretization fineness

library(tidyverse)
devtools::load_all(".")

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/method_comparison_continuous_x.R")

cat("=== DISCRETIZATION SENSITIVITY ANALYSIS ===\n\n")

# Generate one large dataset
set.seed(2026)
n <- 1000  # Large n to reduce sampling variance

dgp <- generate_continuous_x_data(n = n, scenario = 1, K = 50, seed = 2026)
data <- dgp$data

cat(sprintf("Generated n=%d observations\n", n))
cat("Scenario 1: τ_S(x) and τ_Y(x) both increase linearly with x\n\n")

# Test different K values
K_values <- c(5, 10, 15, 20, 30, 40)
M_samples <- 200  # Fixed number of Q samples

results <- map_dfr(K_values, function(K) {

  cat(sprintf("Testing K=%d bins...\n", K))

  # Re-discretize with this K
  data_k <- data %>%
    mutate(X_bin = cut(X_continuous, breaks = K, labels = FALSE, include.lowest = TRUE))

  # Estimate effects
  effects_hat <- estimate_bin_specific_effects(data_k, K)

  # Compute P0
  P0 <- as.numeric(table(factor(data_k$X_bin, levels = 1:K))) / nrow(data_k)

  # Sample from TV ball (same lambda across K)
  Q_samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = 0.3,
    n_samples = M_samples,
    burn_in = 1000,
    thin = 10,
    verbose = FALSE
  )

  # Compute treatment effects
  treatment_effects <- map_dfr(1:M_samples, function(i) {
    Q <- Q_samples[i, ]
    delta_s <- sum(Q * effects_hat$tau_S_hat)
    delta_y <- sum(Q * effects_hat$tau_Y_hat)
    tibble(delta_s = delta_s, delta_y = delta_y)
  })

  # Correlation
  correlation <- cor(treatment_effects$delta_s, treatment_effects$delta_y)

  cat(sprintf("  K=%d: ρ = %.3f\n", K, correlation))

  tibble(
    K = K,
    correlation = correlation,
    mean_delta_s = mean(treatment_effects$delta_s),
    sd_delta_s = sd(treatment_effects$delta_s),
    mean_delta_y = mean(treatment_effects$delta_y),
    sd_delta_y = sd(treatment_effects$delta_y)
  )
})

cat("\n=== RESULTS ===\n\n")
print(results)

# Plot
cat("\n=== VISUALIZATION ===\n")
cat("Correlation vs K:\n")
for (i in 1:nrow(results)) {
  cat(sprintf("  K=%2d: ρ = %.3f %s\n",
              results$K[i],
              results$correlation[i],
              strrep("*", round(results$correlation[i] * 20))))
}

# Stability assessment
cor_range <- max(results$correlation) - min(results$correlation)
cat(sprintf("\nRange of correlations: %.3f\n", cor_range))

if (cor_range < 0.05) {
  cat("✓ Stable across K (discretization bias small)\n")
} else if (cor_range < 0.10) {
  cat("⚠ Moderate sensitivity to K (some discretization bias)\n")
} else {
  cat("✗ High sensitivity to K (substantial discretization bias)\n")
}

# Check monotonicity
cor_increasing <- all(diff(results$correlation) > -0.02)  # Allow small fluctuations
if (cor_increasing) {
  cat("✓ Correlation increases (or stable) with K as expected\n")
} else {
  cat("? Non-monotonic pattern - may indicate instability\n")
}

cat("\n=== INTERPRETATION ===\n\n")

cat("Discretization bias:\n")
cat("  - With continuous X and smooth τ(x), fixed K has bias\n")
cat("  - Bias decreases as K increases (better approximation)\n")
cat("  - But K can't grow too large (computational limits)\n")
cat("  - Trade-off: bias vs computation\n\n")

cat("For this DGP (linear τ(x)):\n")
cat(sprintf("  K=5:  ρ = %.3f (coarse)\n", results$correlation[results$K == 5]))
cat(sprintf("  K=10: ρ = %.3f (moderate)\n", results$correlation[results$K == 10]))
if (20 %in% results$K) {
  cat(sprintf("  K=20: ρ = %.3f (fine)\n", results$correlation[results$K == 20]))
}
if (40 %in% results$K) {
  cat(sprintf("  K=40: ρ = %.3f (very fine)\n", results$correlation[results$K == 40]))
}

cat("\n=== RECOMMENDATION ===\n\n")

if (cor_range < 0.05) {
  cat("For this DGP, K=10 appears sufficient (low discretization bias).\n")
  cat("Linear τ(x) is well-approximated even with moderate K.\n")
} else {
  cat("Discretization matters for this DGP.\n")
  cat("Consider:\n")
  cat("  1. Using larger K (K=20 or K=30)\n")
  cat("  2. Parametric modeling of τ(x) instead of discretization\n")
  cat("  3. Reporting sensitivity across K values\n")
}

cat("\nFor general theory (growing n):\n")
cat("  - Would need K → ∞ as n → ∞ for consistency\n")
cat("  - But hit-and-run in high dimensions may be challenging\n")
cat("  - Alternative: parametric/semiparametric approach\n")
