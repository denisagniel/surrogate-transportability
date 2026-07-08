#!/usr/bin/env Rscript
#
# Theoretical PTE Calculation: Effect Modification V2
#
# Modified DGP: Treatment effects on BOTH S and Y depend on X
#
# Goal: Create scenario where:
# - High PTE in current study
# - Low cor(Δ_S, Δ_Y) across studies with different X distributions

cat(strrep("=", 70), "\n")
cat("THEORETICAL PTE V2: Both Treatment Effects Depend on Covariates\n")
cat(strrep("=", 70), "\n\n")

# ============================================================================
# DGP Structure
# ============================================================================

cat("DGP STRUCTURE:\n")
cat("--------------\n")
cat("S = γ₀ + (γ_A + γ_AX·X)·A + ε_S\n")
cat("Y = β₀ + (β_A + β_AX·X)·A + β_S·S + β_SX·S×X + ε_Y\n")
cat("\n")
cat("Key features:\n")
cat("  → Treatment effect on S depends on X: Δ_S(X̄) = γ_A + γ_AX·X̄\n")
cat("  → Treatment effect on Y depends on X: includes β_AX·X̄ term\n")
cat("  → S→Y relationship also depends on X: β_SX interaction\n")
cat("\n")
cat("This creates:\n")
cat("  - Both Δ_S and Δ_Y vary across studies (different X̄)\n")
cat("  - Can control cor(Δ_S, Δ_Y) by choosing coefficients\n")
cat("\n\n")

# ============================================================================
# Parameters
# ============================================================================

cat("PARAMETERS:\n")
cat("-----------\n")

# S model
gamma_0 <- 0
gamma_A <- 1.0      # Baseline treatment effect on S
gamma_AX <- 0.8     # A×X interaction (makes Δ_S vary with X̄)

# Y model
beta_0 <- 0
beta_A <- 0.3       # Baseline direct treatment effect
beta_AX <- -0.5     # A×X interaction (OPPOSITE sign to γ_AX!)
beta_S <- 0.9       # Main effect of S on Y
beta_SX <- 0.4      # S×X interaction

# Noise
sigma_S <- 0.5
sigma_Y <- 0.5

cat(sprintf("S model: γ_A = %.1f, γ_AX = %.1f (A×X interaction)\n", gamma_A, gamma_AX))
cat(sprintf("Y model: β_A = %.1f, β_AX = %.1f (A×X interaction)\n", beta_A, beta_AX))
cat(sprintf("         β_S = %.1f, β_SX = %.1f (S×X interaction)\n", beta_S, beta_SX))
cat("\n")
cat("KEY DESIGN CHOICE: γ_AX and β_AX have OPPOSITE signs\n")
cat("  → When X̄ increases: Δ_S increases, but Δ_Y decreases (direct effect)\n")
cat("  → Can create low cor(Δ_S, Δ_Y) across studies\n")
cat("\n\n")

# ============================================================================
# Theoretical Treatment Effects
# ============================================================================

cat("THEORETICAL TREATMENT EFFECTS:\n")
cat("------------------------------\n\n")

compute_effects <- function(X_mean) {
  # Treatment effect on S
  Delta_S <- gamma_A + gamma_AX * X_mean

  # Treatment effect on Y (complex due to mediation)
  # ΔY = E[Y|A=1] - E[Y|A=0]
  # Need to account for:
  # 1. Direct: β_A + β_AX·X̄
  # 2. Mediation through S: β_S·Δ_S + β_SX·Δ_S·X̄

  direct_component <- beta_A + beta_AX * X_mean
  mediation_main <- beta_S * Delta_S
  mediation_interaction <- beta_SX * Delta_S * X_mean

  Delta_Y <- direct_component + mediation_main + mediation_interaction

  list(Delta_S = Delta_S, Delta_Y = Delta_Y,
       direct = direct_component,
       mediation = mediation_main + mediation_interaction)
}

# Three example studies
X_means_example <- c(1, 0, -1)

cat("Three example studies:\n\n")
for (i in 1:3) {
  X_mean <- X_means_example[i]
  eff <- compute_effects(X_mean)

  cat(sprintf("Study %d (X̄ = %.1f):\n", i, X_mean))
  cat(sprintf("  Δ_S = %.2f\n", eff$Delta_S))
  cat(sprintf("  Δ_Y = %.2f (direct: %.2f, mediation: %.2f)\n\n",
             eff$Delta_Y, eff$direct, eff$mediation))
}

# ============================================================================
# Simulate 20 Studies with Varying X̄
# ============================================================================

cat("SIMULATION: 20 Studies with varying X̄\n")
cat("---------------------------------------\n\n")

X_means <- seq(-1.5, 1.5, length.out = 20)
n_sim <- 3000

Delta_S_all <- numeric(20)
Delta_Y_all <- numeric(20)
PTE_all <- numeric(20)

set.seed(123)

for (i in 1:20) {
  X_mean_i <- X_means[i]

  # Generate study data
  X <- rnorm(n_sim, mean = X_mean_i, sd = 1)
  A <- rbinom(n_sim, 1, 0.5)

  S <- gamma_0 + (gamma_A + gamma_AX * X) * A + rnorm(n_sim, sd = sigma_S)
  Y <- beta_0 + (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X +
    rnorm(n_sim, sd = sigma_Y)

  # True treatment effects
  Delta_S_all[i] <- mean(S[A == 1]) - mean(S[A == 0])
  Delta_Y_all[i] <- mean(Y[A == 1]) - mean(Y[A == 0])

  # PTE from regression Y ~ A + S (ignoring X and interactions)
  model_i <- lm(Y ~ A + S)
  total <- Delta_Y_all[i]
  direct <- coef(model_i)["A"]
  indirect <- total - direct
  PTE_all[i] <- indirect / total
}

# Correlation across studies
cor_transport <- cor(Delta_S_all, Delta_Y_all)

cat(sprintf("cor(Δ_S, Δ_Y) across 20 studies: %.3f\n\n", cor_transport))

# Summary statistics
cat("Treatment effect ranges:\n")
cat(sprintf("  Δ_S: [%.2f, %.2f] (range: %.2f)\n",
           min(Delta_S_all), max(Delta_S_all),
           max(Delta_S_all) - min(Delta_S_all)))
cat(sprintf("  Δ_Y: [%.2f, %.2f] (range: %.2f)\n\n",
           min(Delta_Y_all), max(Delta_Y_all),
           max(Delta_Y_all) - min(Delta_Y_all)))

# PTE in different studies
idx_high_X <- which.max(X_means)
idx_mid_X <- which.min(abs(X_means))
idx_low_X <- which.min(X_means)

cat("PTE in three representative studies:\n")
cat(sprintf("  High X̄ (%.1f):  PTE = %.3f\n", X_means[idx_high_X], PTE_all[idx_high_X]))
cat(sprintf("  Mid X̄  (%.1f):  PTE = %.3f\n", X_means[idx_mid_X], PTE_all[idx_mid_X]))
cat(sprintf("  Low X̄  (%.1f): PTE = %.3f\n\n", X_means[idx_low_X], PTE_all[idx_low_X]))

# ============================================================================
# Focus on Current Study (X̄ = 1)
# ============================================================================

cat("CURRENT STUDY ANALYSIS (X̄ = 1):\n")
cat("----------------------------------\n\n")

idx_current <- which.min(abs(X_means - 1))
X_mean_current <- X_means[idx_current]

cat(sprintf("X̄ = %.2f\n", X_mean_current))
cat(sprintf("Δ_S = %.3f\n", Delta_S_all[idx_current]))
cat(sprintf("Δ_Y = %.3f\n", Delta_Y_all[idx_current]))
cat(sprintf("PTE = %.3f\n\n", PTE_all[idx_current]))

if (PTE_all[idx_current] > 0.6) {
  cat("✓ PTE > 0.6 → Traditional methods say GOOD SURROGATE\n\n")
  pte_success <- TRUE
} else {
  cat(sprintf("✗ PTE = %.3f (< 0.6) → Not high enough\n\n", PTE_all[idx_current]))
  pte_success <- FALSE
}

# ============================================================================
# Visualizations
# ============================================================================

if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)

  plot_data <- data.frame(
    X_mean = X_means,
    Delta_S = Delta_S_all,
    Delta_Y = Delta_Y_all,
    PTE = PTE_all
  )

  # Plot 1: Treatment effects vs X̄
  p1 <- ggplot(plot_data) +
    geom_line(aes(x = X_mean, y = Delta_S, color = "Δ_S"), linewidth = 1.2) +
    geom_line(aes(x = X_mean, y = Delta_Y, color = "Δ_Y"), linewidth = 1.2) +
    geom_point(aes(x = X_mean, y = Delta_S, color = "Δ_S"), size = 2) +
    geom_point(aes(x = X_mean, y = Delta_Y, color = "Δ_Y"), size = 2) +
    geom_vline(xintercept = X_mean_current, linetype = "dashed", alpha = 0.5) +
    scale_color_manual(values = c("Δ_S" = "blue", "Δ_Y" = "red")) +
    labs(
      title = "Treatment Effects Across Studies",
      subtitle = sprintf("Both vary with X̄; cor(Δ_S, Δ_Y) = %.3f", cor_transport),
      x = "Mean Covariate (X̄)",
      y = "Treatment Effect",
      color = "Effect"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  # Plot 2: Scatter of Δ_S vs Δ_Y
  p2 <- ggplot(plot_data, aes(x = Delta_S, y = Delta_Y)) +
    geom_point(size = 3, alpha = 0.7) +
    geom_smooth(method = "lm", se = TRUE, color = "blue") +
    annotate("text", x = min(Delta_S_all), y = max(Delta_Y_all),
            label = sprintf("cor = %.3f", cor_transport),
            hjust = 0, vjust = 1, size = 5) +
    labs(
      title = "Treatment Effect Transportability",
      subtitle = "Δ_S vs Δ_Y across 20 studies with different X̄",
      x = "Treatment Effect on S (Δ_S)",
      y = "Treatment Effect on Y (Δ_Y)"
    ) +
    theme_minimal()

  # Plot 3: PTE across studies
  p3 <- ggplot(plot_data, aes(x = X_mean, y = PTE)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2.5) +
    geom_hline(yintercept = 0.6, linetype = "dashed", color = "red") +
    geom_vline(xintercept = X_mean_current, linetype = "dashed", alpha = 0.5) +
    labs(
      title = "PTE Varies Across Studies",
      subtitle = "Traditional methods see different PTE in different populations",
      x = "Mean Covariate (X̄)",
      y = "PTE"
    ) +
    theme_minimal()

  dir.create("explorations/figures", showWarnings = FALSE, recursive = TRUE)
  ggsave("explorations/figures/effect_mod_v2_effects.png", p1, width = 8, height = 6)
  ggsave("explorations/figures/effect_mod_v2_scatter.png", p2, width = 8, height = 6)
  ggsave("explorations/figures/effect_mod_v2_pte.png", p3, width = 8, height = 6)

  cat("\nPlots saved to explorations/figures/\n\n")
}

# ============================================================================
# Conclusion
# ============================================================================

cat(strrep("=", 70), "\n")
cat("CONCLUSION\n")
cat(strrep("=", 70), "\n\n")

cat("DGP V2: Both Treatment Effects Depend on Covariates\n\n")

cat("Results:\n")
cat(sprintf("  1. Current study (X̄≈1): PTE = %.3f %s\n",
           PTE_all[idx_current],
           ifelse(PTE_all[idx_current] > 0.6, "✓", "✗")))
cat(sprintf("  2. Transportability: cor(Δ_S, Δ_Y) = %.3f\n", cor_transport))
cat("\n")

if (pte_success && abs(cor_transport) < 0.3) {
  cat("✓✓✓ SUCCESS! This DGP achieves the goal:\n")
  cat("  ✓ High PTE in current study (traditional methods: GOOD SURROGATE)\n")
  cat("  ✓ Low cor(Δ_S, Δ_Y) across studies (TV ball: POOR TRANSPORTABILITY)\n\n")

  cat("This creates the desired failure scenario where:\n")
  cat("  - Traditional PTE/mediation say surrogate is good (within one study)\n")
  cat("  - TV ball method correctly identifies poor transportability\n\n")

  success <- TRUE

} else if (pte_success && abs(cor_transport) < 0.5) {
  cat("≈ PARTIAL SUCCESS:\n")
  cat("  ✓ High PTE in current study\n")
  cat(sprintf("  ≈ Moderate correlation (%.3f) - could tune parameters\n", cor_transport))
  cat("\n")

  success <- TRUE

} else {
  cat("✗ DGP needs adjustment:\n")
  if (!pte_success) {
    cat(sprintf("  ✗ PTE too low (%.3f, want > 0.6)\n", PTE_all[idx_current]))
  }
  if (abs(cor_transport) >= 0.5) {
    cat(sprintf("  ✗ Correlation too high (%.3f, want < 0.3)\n", cor_transport))
  }
  cat("\n")

  success <- FALSE
}

cat("KEY MECHANISM:\n")
cat("--------------\n")
cat("By making treatment effects on S and Y depend on X in DIFFERENT ways:\n")
cat(sprintf("  - γ_AX = %.1f (positive): Δ_S increases with X̄\n", gamma_AX))
cat(sprintf("  - β_AX = %.1f (negative): Direct effect on Y decreases with X̄\n", beta_AX))
cat("\n")
cat("This creates:\n")
cat("  → Both Δ_S and Δ_Y vary across studies (enables cor calculation)\n")
cat("  → But correlation is LOW (opposite-signed coefficients)\n")
cat("  → In specific study with favorable X̄: PTE can be high\n\n")

if (success) {
  cat("RECOMMENDATION: Use this DGP concept for DGP 1!\n")
  cat("\nMay need to fine-tune parameters to ensure:\n")
  cat("  1. PTE reliably > 0.6 in current study\n")
  cat("  2. cor(Δ_S, Δ_Y) reliably < 0.3 across studies\n")
}
