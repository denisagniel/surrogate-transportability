# Test Scenario 3: Low Correlation, High PTE
# Verify unmeasured heterogeneity breaks correlation

library(tidyverse)
devtools::load_all(".")

set.seed(2026)

# Generate data
cat("=== TESTING SCENARIO 3: Low ρ, High PTE ===\n\n")

dgp <- generate_low_cor_high_pte(n = 1000, seed = 123)
data <- dgp$data

cat("DGP structure:\n")
cat("- A → S (constant effect)\n")
cat("- S → Y (strong effect, modified by unmeasured U)\n")
cat("- Original study: U = 0\n")
cat("- Future studies: U varies randomly\n\n")

# Within-study PTE (original study with U=0)
cat("1. Within-Study PTE:\n")

E_Y_A1 <- mean(data$Y[data$A == 1])
E_Y_A0 <- mean(data$Y[data$A == 0])
total_effect <- E_Y_A1 - E_Y_A0

adjusted_effect <- 0
for (s_val in 0:1) {
  p_s <- mean(data$S[data$A == 0] == s_val)
  y_a1_s <- data$Y[data$A == 1 & data$S == s_val]
  y_a0_s <- data$Y[data$A == 0 & data$S == s_val]

  if (length(y_a1_s) > 0 && length(y_a0_s) > 0) {
    effect_s <- mean(y_a1_s) - mean(y_a0_s)
    adjusted_effect <- adjusted_effect + p_s * effect_s
  }
}

pte <- 1 - adjusted_effect / total_effect

cat(sprintf("   Total effect: %.3f\n", total_effect))
cat(sprintf("   Adjusted effect: %.3f\n", adjusted_effect))
cat(sprintf("   PTE: %.3f (%.1f%% mediated)\n", pte, pte * 100))
cat(sprintf("   Expected: ~0.9\n"))

if (pte > 0.7) {
  cat("   ✓ High PTE confirmed\n\n")
} else {
  cat("   ✗ PTE lower than expected\n\n")
}

# Across-study correlation (with varying U)
cat("2. Across-Study Correlation:\n")

future_effects <- generate_future_effects_with_heterogeneity(
  data,
  M = 100,
  u_range = c(-1, 1),
  seed = 456
)

future_effects_clean <- future_effects %>%
  filter(!is.na(delta_s), !is.na(delta_y))

across_cor <- cor(future_effects_clean$delta_s, future_effects_clean$delta_y)

cat(sprintf("   Correlation: %.3f\n", across_cor))
cat(sprintf("   Expected: ~0.1\n"))
cat(sprintf("   N studies: %d\n", nrow(future_effects_clean)))

if (abs(across_cor) < 0.3) {
  cat("   ✓ Low correlation confirmed\n\n")
} else {
  cat("   ✗ Correlation higher than expected\n\n")
}

# Visualize
cat("3. Treatment Effect Variation:\n")

summary_stats <- future_effects_clean %>%
  summarize(
    mean_delta_s = mean(delta_s),
    sd_delta_s = sd(delta_s),
    mean_delta_y = mean(delta_y),
    sd_delta_y = sd(delta_y),
    cor_delta = cor(delta_s, delta_y)
  )

cat(sprintf("   ΔS: Mean = %.3f, SD = %.3f\n",
            summary_stats$mean_delta_s, summary_stats$sd_delta_s))
cat(sprintf("   ΔY: Mean = %.3f, SD = %.3f\n",
            summary_stats$mean_delta_y, summary_stats$sd_delta_y))
cat(sprintf("   cor(ΔS, ΔY) = %.3f\n\n", summary_stats$cor_delta))

# Mechanism check
cat("4. Mechanism Validation:\n")
cat("   How U affects the relationship:\n")

# Group by U ranges
future_effects_grouped <- future_effects_clean %>%
  mutate(u_group = cut(u_mean, breaks = c(-Inf, -0.5, 0, 0.5, Inf),
                       labels = c("Low U", "Mid-Low U", "Mid-High U", "High U"))) %>%
  group_by(u_group) %>%
  summarize(
    mean_u = mean(u_mean),
    mean_delta_y = mean(delta_y),
    n = n(),
    .groups = "drop"
  )

print(future_effects_grouped)

cat("\n   Interpretation:\n")
cat("   - ΔS is relatively constant (no A×X interaction)\n")
cat("   - ΔY varies with U (S×U interaction on Y)\n")
cat("   - Low correlation because ΔY variation is driven by unmeasured U\n\n")

# Summary
cat("=== SUMMARY ===\n")
cat(sprintf("Within-study PTE: %.2f (high mediation)\n", pte))
cat(sprintf("Across-study ρ: %.2f (low transportability)\n", across_cor))
cat(sprintf("Divergence: PTE - ρ = %.2f\n\n", pte - across_cor))

if (pte > 0.7 && abs(across_cor) < 0.3) {
  cat("✓ Scenario 3 validated: Low correlation + High PTE\n")
  cat("  → Strong mediation within-study\n")
  cat("  → Poor transportability across studies\n")
  cat("  → Unmeasured heterogeneity breaks prediction\n")
} else {
  cat("✗ Scenario 3 needs adjustment\n")
  cat(sprintf("  Current: PTE = %.2f, ρ = %.2f\n", pte, across_cor))
  cat(sprintf("  Target: PTE > 0.7, |ρ| < 0.3\n"))
}
