#!/usr/bin/env Rscript

#' TEST: Innovation Distribution Mismatch (Observation-level vs Type-level)
#'
#' REAL ISSUE IDENTIFIED:
#'   - Ground truth: Dirichlet(1,1,1,1) over K=4 TYPES → high variation
#'   - Package method: Dirichlet(1,...,1) over n=1000 OBSERVATIONS → low variation
#'
#' For K=4, observation-level Dirichlet cannot create the type proportion
#' variation that type-level Dirichlet creates!

library(MCMCpack)
library(dplyr)
library(tibble)
library(ggplot2)

set.seed(20260324)

cat("================================================================\n")
cat("TEST: Innovation Distribution Mismatch\n")
cat("================================================================\n\n")

K <- 4
n <- 1000
M <- 500
lambda <- 0.3

# Generate baseline with uniform type distribution
types_baseline <- sample(1:K, size = n, replace = TRUE, prob = rep(1/K, K))
cat("Baseline type distribution:\n")
print(table(types_baseline) / n)
cat("\n")

# METHOD 1: TYPE-LEVEL innovations (ground truth approach)
cat("METHOD 1: Type-level Dirichlet(1,1,1,1) over K=4 types\n")
cat("--------------------------------------------------------\n")

type_props_method1 <- matrix(NA, nrow = M, ncol = K)

for (m in 1:M) {
  # Generate innovation over TYPES
  type_weights_m <- rdirichlet(1, rep(1, K))[1,]

  # Form mixture: Q = (1-λ)P₀ + λΠ̃
  p0_type_props <- rep(1/K, K)
  q_m_type_props <- (1 - lambda) * p0_type_props + lambda * type_weights_m

  type_props_method1[m, ] <- q_m_type_props
}

cat(sprintf("  Generated %d innovations\n", M))
cat("  Type proportion ranges:\n")
for (k in 1:K) {
  cat(sprintf("    Type %d: [%.3f, %.3f], SD=%.3f\n",
              k, min(type_props_method1[, k]), max(type_props_method1[, k]),
              sd(type_props_method1[, k])))
}
cat("\n")

# METHOD 2: OBSERVATION-LEVEL innovations (package approach)
cat("METHOD 2: Observation-level Dirichlet(1,...,1) over n=1000 observations\n")
cat("------------------------------------------------------------------------\n")

type_props_method2 <- matrix(NA, nrow = M, ncol = K)

for (m in 1:M) {
  # Generate innovation over OBSERVATIONS (THIS IS WHAT THE PACKAGE DOES)
  obs_weights_m <- rdirichlet(1, rep(1, n))[1,]

  # Form mixture over observations
  p0_obs_weights <- rep(1/n, n)
  q_m_obs_weights <- (1 - lambda) * p0_obs_weights + lambda * obs_weights_m

  # Compute implied type proportions
  # (sum weights of observations belonging to each type)
  q_m_type_props <- numeric(K)
  for (k in 1:K) {
    q_m_type_props[k] <- sum(q_m_obs_weights[types_baseline == k])
  }

  type_props_method2[m, ] <- q_m_type_props
}

cat(sprintf("  Generated %d innovations\n", M))
cat("  Type proportion ranges:\n")
for (k in 1:K) {
  cat(sprintf("    Type %d: [%.3f, %.3f], SD=%.3f\n",
              k, min(type_props_method2[, k]), max(type_props_method2[, k]),
              sd(type_props_method2[, k])))
}
cat("\n")

# COMPARISON
cat("================================================================\n")
cat("COMPARISON: Variation in Type Proportions\n")
cat("================================================================\n\n")

cat("Standard deviation of type proportions:\n")
sd_comparison <- tibble(
  Type = 1:K,
  `Type-level (Ground Truth)` = apply(type_props_method1, 2, sd),
  `Obs-level (Package)` = apply(type_props_method2, 2, sd),
  Ratio = apply(type_props_method1, 2, sd) / apply(type_props_method2, 2, sd)
)
print(sd_comparison)
cat("\n")

cat("Mean ratio: Type-level has %.1fx more variation than Obs-level\n\n",
    mean(sd_comparison$Ratio))

# IMPLICATION FOR CORRELATIONS
cat("================================================================\n")
cat("IMPLICATION: Treatment Effect Variation\n")
cat("================================================================\n\n")

cat("When type proportions vary more:\n")
cat("  • Treatment effects (weighted sums) vary more\n")
cat("  • SD(ΔS) and SD(ΔY) are larger\n")
cat("  • Correlation signal is stronger\n\n")

cat("When type proportions are constrained (obs-level):\n")
cat("  • Type proportions stay near baseline (25%, 25%, 25%, 25%)\n")
cat("  • Treatment effects change little across innovations\n")
cat("  • Correlation is dampened\n\n")

# VISUALIZATION
cat("Creating visualization...\n")

plot_data <- bind_rows(
  tibble(
    method = "Type-level\n(Ground Truth)",
    type = rep(1:K, each = M),
    proportion = as.vector(type_props_method1)
  ),
  tibble(
    method = "Obs-level\n(Package)",
    type = rep(1:K, each = M),
    proportion = as.vector(type_props_method2)
  )
)

p1 <- ggplot(plot_data, aes(x = factor(type), y = proportion, fill = method)) +
  geom_boxplot() +
  facet_wrap(~ method) +
  labs(
    title = "Type Proportion Variation: Type-level vs Obs-level Innovations",
    subtitle = sprintf("K=%d types, n=%d observations, M=%d innovations, λ=%.2f", K, n, M, lambda),
    x = "Type",
    y = "Proportion in Mixture"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("sims/results/innovation_mismatch_boxplot.png", p1, width = 10, height = 5, dpi = 300)

# Density plot
p2 <- ggplot(plot_data, aes(x = proportion, fill = method)) +
  geom_density(alpha = 0.5) +
  facet_wrap(~ factor(type), labeller = label_both) +
  labs(
    title = "Distribution of Type Proportions Across Innovations",
    subtitle = "Obs-level innovations constrain variation compared to Type-level",
    x = "Type Proportion",
    y = "Density"
  ) +
  theme_minimal()

ggsave("sims/results/innovation_mismatch_density.png", p2, width = 10, height = 6, dpi = 300)

cat("Plots saved to sims/results/\n\n")

# DEMONSTRATE THE IMPACT ON TREATMENT EFFECTS
cat("================================================================\n")
cat("IMPACT ON TREATMENT EFFECTS\n")
cat("================================================================\n\n")

# Population treatment effects by type
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)

cat(sprintf("Population effects: τ_S = (%s), τ_Y = (%s)\n",
            paste(tau_s, collapse=", "),
            paste(tau_y, collapse=", ")))
cat(sprintf("Population correlation: %.3f\n\n", cor(tau_s, tau_y)))

# Compute treatment effects under each method's type proportions
te_method1 <- matrix(NA, nrow = M, ncol = 2)
te_method2 <- matrix(NA, nrow = M, ncol = 2)

for (m in 1:M) {
  # Method 1: Type-level
  te_method1[m, 1] <- sum(type_props_method1[m, ] * tau_s)
  te_method1[m, 2] <- sum(type_props_method1[m, ] * tau_y)

  # Method 2: Obs-level
  te_method2[m, 1] <- sum(type_props_method2[m, ] * tau_s)
  te_method2[m, 2] <- sum(type_props_method2[m, ] * tau_y)
}

cat("Treatment effect variation:\n")
cat(sprintf("  Type-level:  SD(ΔS)=%.4f, SD(ΔY)=%.4f, cor=%.3f\n",
            sd(te_method1[, 1]), sd(te_method1[, 2]), cor(te_method1[, 1], te_method1[, 2])))
cat(sprintf("  Obs-level:   SD(ΔS)=%.4f, SD(ΔY)=%.4f, cor=%.3f\n",
            sd(te_method2[, 1]), sd(te_method2[, 2]), cor(te_method2[, 1], te_method2[, 2])))
cat(sprintf("  Ratio (Type/Obs): SD ratio=%.2fx, correlation ratio=%.2fx\n\n",
            sd(te_method1[, 1]) / sd(te_method2[, 1]),
            cor(te_method1[, 1], te_method1[, 2]) / cor(te_method2[, 1], te_method2[, 2])))

cat("================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

cat("The K=4 validation failure is caused by INNOVATION MISMATCH:\n\n")

cat("Ground truth uses:\n")
cat("  Dirichlet(1,1,1,1) over K=4 types\n")
cat("  → High variation in type proportions\n")
cat("  → High variation in treatment effects\n")
cat("  → Correlation ≈ %.3f\n\n", cor(te_method1[, 1], te_method1[, 2]))

cat("Package method uses:\n")
cat("  Dirichlet(1,...,1) over n=1000 observations\n")
cat("  → Type proportions constrained near baseline\n")
cat("  → Low variation in treatment effects\n")
cat("  → Correlation ≈ %.3f (%.0f%% of truth)\n\n",
    cor(te_method2[, 1], te_method2[, 2]),
    100 * cor(te_method2[, 1], te_method2[, 2]) / cor(te_method1[, 1], te_method1[, 2]))

cat("SOLUTION:\n")
cat("  Modify package to use TYPE-LEVEL innovations when types are observed:\n")
cat("    innovations <- rdirichlet(n_innovations, rep(alpha, K))  # Over K types\n")
cat("  Then map type innovations to observation-level weights\n\n")

cat("WHY K matters:\n")
cat("  • K=4: Obs-level gives %.0f%% of type-level variation\n",
    100 * sd(type_props_method2[, 1]) / sd(type_props_method1[, 1]))
cat("  • K=500: Obs-level and type-level become similar\n")
cat("    (each type has only ~2 observations, less distinction)\n\n")

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
