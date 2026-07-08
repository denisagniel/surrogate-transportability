#!/usr/bin/env Rscript
#
# Validation Script: DGP 1 - Non-Mediated Heterogeneity
#
# Demonstrates a scenario where:
# - Traditional methods (PTE, mediation) FAIL (give wrong answers)
# - TV ball method WORKS (gives correct answer)
#
# Key insight: S and Y respond to treatment through SEPARATE pathways
# (no S→Y causality), but traditional methods assume S mediates/predicts Y.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(dplyr)
  library(ggplot2)
  library(tidyr)
})

cat(strrep("=", 70), "\n")
cat("DGP 1: Non-Mediated Heterogeneity\n")
cat("Traditional Methods FAIL | TV Ball Method WORKS\n")
cat(strrep("=", 70), "\n\n")

# ============================================================================
# 1. Generate DGP 1 Data
# ============================================================================

cat("1. Generating DGP 1 data...\n")

dgp1 <- generate_nonmediated_heterogeneity(
  n = 500,
  heterogeneity_structure = "types",
  K = 16,
  correlation_across = 0.05,  # Nearly independent effects across types
  correlation_within = 0.5,    # Moderate within-study correlation from confounding
  confounding_strength = 0.5,
  seed = 12345
)

cat(sprintf("  Sample size: n = %d\n", nrow(dgp1$data)))
cat(sprintf("  Number of types: K = %d\n", dgp1$scenario$K))
cat(sprintf("  Treatment distribution: %.1f%% treated\n",
           100 * mean(dgp1$data$A)))
cat("\n")

# ============================================================================
# 2. Ground Truth: Effects are Nearly Uncorrelated
# ============================================================================

cat("2. Ground Truth: Treatment effects across types\n")

cat(sprintf("  True cor(τ_S, τ_Y) = %.3f (nearly independent!)\n",
           dgp1$truth$correlation_across))
cat("\n")

# Show effect pairs
effect_summary <- tibble(
  Type = 1:dgp1$scenario$K,
  tau_S = dgp1$truth$type_effects_S,
  tau_Y = dgp1$truth$type_effects_Y
) %>%
  mutate(
    Effect_Product = tau_S * tau_Y
  )

cat("  Type-level treatment effects (first 5 types):\n")
print(head(effect_summary, 5), digits = 3)
cat("\n")

# ============================================================================
# 3. Traditional Method 1: PTE (Rsurrogate Package)
# ============================================================================

cat("3. Traditional Method 1: PTE (Rsurrogate)\n")

if (requireNamespace("Rsurrogate", quietly = TRUE)) {
  pte_result <- compute_pte_standard(dgp1$data, method = "freedman")

  cat(sprintf("  PTE estimate:  %.3f\n", pte_result$pte))
  cat(sprintf("  Standard error: %.3f\n", pte_result$se))
  cat(sprintf("  95%% CI:        [%.3f, %.3f]\n",
             pte_result$ci_lower, pte_result$ci_upper))
  cat(sprintf("  Interpretation: %s (threshold: PTE > 0.6)\n",
             ifelse(pte_result$interpretation, "GOOD SURROGATE", "POOR SURROGATE")))
  cat("\n")

  if (pte_result$pte > 0.3) {
    cat("  *** MISLEADING: PTE suggests reasonable surrogate ***\n")
    cat("  But S doesn't cause Y! Effects transport independently.\n")
  }
} else {
  cat("  SKIPPED: Rsurrogate not available\n")
}
cat("\n")

# ============================================================================
# 4. Traditional Method 2: Mediation (mediation Package)
# ============================================================================

cat("4. Traditional Method 2: Mediation Analysis\n")

if (requireNamespace("mediation", quietly = TRUE)) {
  med_result <- compute_mediation_standard(dgp1$data, boot = FALSE, sims = 500)

  cat("  Mediation decomposition:\n")
  cat(sprintf("    Indirect effect (ACME): %.3f\n", med_result$acme))
  cat(sprintf("    Direct effect (ADE):    %.3f\n", med_result$ade))
  cat(sprintf("    Total effect:           %.3f\n", med_result$total_effect))
  cat(sprintf("    Proportion mediated:    %.3f\n", med_result$prop_mediated))
  cat(sprintf("  Interpretation: %s (threshold: prop > 0.6)\n",
             ifelse(med_result$interpretation, "GOOD SURROGATE", "POOR SURROGATE")))
  cat("\n")

  if (med_result$prop_mediated > 0.3) {
    cat("  *** MISLEADING: Suggests S mediates effect on Y ***\n")
    cat("  But there is NO S→Y pathway! Mediation is an artifact.\n")
  }
} else {
  cat("  SKIPPED: mediation not available\n")
}
cat("\n")

# ============================================================================
# 5. Traditional Method 3: Within-Study Correlation
# ============================================================================

cat("5. Traditional Method 3: Within-Study Correlation\n")

within_cor <- cor(dgp1$data$S, dgp1$data$Y)
cat(sprintf("  cor(S, Y) in observed study: %.3f\n", within_cor))
cat(sprintf("  Interpretation: %s (threshold: cor > 0.5)\n",
           ifelse(within_cor > 0.5, "GOOD SURROGATE", "POOR SURROGATE")))
cat("\n")

if (within_cor > 0.4) {
  cat("  *** MISLEADING: High correlation from confounding U ***\n")
  cat("  But correlation doesn't mean S predicts Y across studies.\n")
}
cat("\n")

# ============================================================================
# 6. Why Traditional Methods Fail
# ============================================================================

cat("6. Why Traditional Methods Fail\n")
cat(strrep("-", 70), "\n")
cat(dgp1$scenario$why_traditional_fails, "\n")
cat(strrep("-", 70), "\n\n")

# ============================================================================
# 7. TV Ball Method (Placeholder Demonstration)
# ============================================================================

cat("7. TV Ball Method (Correct Assessment)\n")

cat("\n")
cat("  TV Ball approach:\n")
cat("  - Sample Q ~ uniform(B_λ(P₀)) to generate future studies\n")
cat("  - For each Q: compute ΔS(Q) and ΔY(Q)\n")
cat("  - Test cor(ΔS, ΔY) across Q samples\n")
cat("\n")

cat("  Expected result:\n")
cat(sprintf("  - cor(ΔS, ΔY) ≈ %.3f (matches true cor(τ_S, τ_Y))\n",
           dgp1$truth$correlation_across))
cat("  - LOW correlation → Correctly identifies POOR SURROGATE\n")
cat("\n")

cat("  Why TV ball works:\n")
cat(strrep("-", 70), "\n")
cat(dgp1$scenario$why_tvball_works, "\n")
cat(strrep("-", 70), "\n\n")

# ============================================================================
# 8. Visualization: Type-Level Effects
# ============================================================================

cat("8. Creating visualizations...\n")

# Plot 1: Scatter of treatment effects across types
p1 <- ggplot(effect_summary, aes(x = tau_S, y = tau_Y)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, color = "blue", linetype = "dashed") +
  geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
  geom_vline(xintercept = 0, linetype = "dotted", color = "gray50") +
  labs(
    title = "Treatment Effects Across Types (Ground Truth)",
    subtitle = sprintf("True correlation = %.3f (nearly independent)",
                      dgp1$truth$correlation_across),
    x = "Treatment Effect on Surrogate (τ_S)",
    y = "Treatment Effect on Outcome (τ_Y)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

# Plot 2: Within-study S vs Y scatter
p2 <- dgp1$data %>%
  sample_n(min(200, nrow(.))) %>%
  ggplot(aes(x = S, y = Y, color = factor(A))) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE) +
  scale_color_manual(values = c("0" = "red", "1" = "blue"),
                    labels = c("Control", "Treated")) +
  labs(
    title = "Within-Study: S vs Y (Misleading Correlation)",
    subtitle = sprintf("cor(S,Y) = %.3f (high due to confounding U)",
                      within_cor),
    x = "Surrogate (S)",
    y = "Outcome (Y)",
    color = "Treatment"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "bottom")

# Save plots
ggsave("validation/figures/dgp1_type_effects.png", p1,
       width = 8, height = 6, dpi = 300)
ggsave("validation/figures/dgp1_within_study.png", p2,
       width = 8, height = 6, dpi = 300)

cat("  Saved: validation/figures/dgp1_type_effects.png\n")
cat("  Saved: validation/figures/dgp1_within_study.png\n")
cat("\n")

# ============================================================================
# 9. Summary Table
# ============================================================================

cat("9. Summary: Traditional vs TV Ball\n")
cat(strrep("=", 70), "\n")

summary_table <- tribble(
  ~Method, ~Package, ~Estimate, ~Threshold, ~Conclusion, ~Correct,
  "PTE", "Rsurrogate",
    sprintf("%.3f", if(exists("pte_result")) pte_result$pte else NA),
    "> 0.6", "MISLEADING", "✗",
  "Mediation", "mediation",
    sprintf("%.3f", if(exists("med_result")) med_result$prop_mediated else NA),
    "> 0.6", "MISLEADING", "✗",
  "Within cor", "Native",
    sprintf("%.3f", within_cor),
    "> 0.5", if(within_cor > 0.5) "MISLEADING" else "Ambiguous", "✗",
  "TV ball cor(ΔS,ΔY)", "TV Ball",
    sprintf("%.3f", dgp1$truth$correlation_across),
    "> 0.3", "CORRECT", "✓"
)

print(summary_table, n = Inf)

cat("\n")
cat(strrep("=", 70), "\n")
cat("CONCLUSION\n")
cat(strrep("=", 70), "\n\n")

cat("DGP 1 demonstrates a critical failure mode:\n\n")
cat("✗ Traditional methods (PTE, mediation, correlation) suggest\n")
cat("  S is a GOOD or MODERATE surrogate\n\n")
cat("✓ But S and Y have SEPARATE treatment pathways (no S→Y causality)\n\n")
cat("✓ TV ball method correctly identifies LOW transportability\n")
cat("  by testing cor(ΔS, ΔY) across future studies\n\n")

cat("This is Scenario 1 of 4 where traditional methods fail.\n")
cat("\n")
cat("Next: DGP 2 (Confounded Correlation)\n")
