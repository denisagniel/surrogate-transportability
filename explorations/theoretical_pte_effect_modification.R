#!/usr/bin/env Rscript
#
# Theoretical PTE Calculation: Effect Modification by Covariates
#
# DGP Concept: S mediates Y, but S→Y relationship depends on X (S×X interaction)
#
# Question: Can this create:
# - High PTE in current study with specific X distribution?
# - Low cor(ΔS, ΔY) across future studies with different X distributions?

cat(strrep("=", 70), "\n")
cat("THEORETICAL PTE: Effect Modification by Covariates\n")
cat(strrep("=", 70), "\n\n")

# ============================================================================
# DGP Structure
# ============================================================================

cat("DGP STRUCTURE:\n")
cat("--------------\n")
cat("S = γ₀ + γ_A·A + γ_X·X + ε_S\n")
cat("Y = β₀ + β_A·A + β_S·S + β_X·X + β_SX·(S×X) + ε_Y\n")
cat("\n")
cat("Key feature: S×X interaction in Y model\n")
cat("  → Effect of S on Y depends on X\n")
cat("  → Mediation strength varies with covariate distribution\n")
cat("\n\n")

# ============================================================================
# Parameters
# ============================================================================

cat("PARAMETERS:\n")
cat("-----------\n")

# S model
gamma_0 <- 0
gamma_A <- 1.0    # Treatment effect on S
gamma_X <- 0.5    # Covariate effect on S

# Y model
beta_0 <- 0
beta_A <- 0.3     # Direct treatment effect
beta_S <- 0.8     # Main effect of S on Y
beta_X <- 0.2     # Main effect of X on Y
beta_SX <- 0.6    # S×X INTERACTION (this is key!)

# Noise
sigma_S <- 0.5
sigma_Y <- 0.5

cat(sprintf("S model: γ_A = %.1f, γ_X = %.1f\n", gamma_A, gamma_X))
cat(sprintf("Y model: β_A = %.1f, β_S = %.1f, β_X = %.1f, β_SX = %.1f\n",
           beta_A, beta_S, beta_X, beta_SX))
cat(sprintf("Interaction β_SX = %.1f (LARGE!)\n\n", beta_SX))

# ============================================================================
# Study 1: Current Study with X̄ = 1 (favorable for mediation)
# ============================================================================

cat("STUDY 1: Current Study (X̄ = 1)\n")
cat("--------------------------------\n\n")

X_mean_1 <- 1.0
X_var <- 1.0

cat(sprintf("X distribution: X ~ N(%.1f, %.1f)\n\n", X_mean_1, X_var))

# Treatment effects
Delta_S_1 <- gamma_A
cat(sprintf("Treatment effect on S: Δ_S = %.1f\n\n", Delta_S_1))

# Treatment effect on Y
# ΔY = E[Y|A=1] - E[Y|A=0]
#    = β_A + β_S·E[S|A=1] - β_S·E[S|A=0] + β_SX·(E[S×X|A=1] - E[S×X|A=0])
#    = β_A + β_S·Δ_S + β_SX·Δ_S·E[X]

Delta_Y_1 <- beta_A + beta_S * Delta_S_1 + beta_SX * Delta_S_1 * X_mean_1

cat("Treatment effect on Y:\n")
cat(sprintf("  Direct:           β_A = %.1f\n", beta_A))
cat(sprintf("  Via S (main):     β_S·Δ_S = %.1f × %.1f = %.1f\n",
           beta_S, Delta_S_1, beta_S * Delta_S_1))
cat(sprintf("  Via S×X:          β_SX·Δ_S·X̄ = %.1f × %.1f × %.1f = %.1f\n",
           beta_SX, Delta_S_1, X_mean_1, beta_SX * Delta_S_1 * X_mean_1))
cat(sprintf("  Total Δ_Y:        %.1f\n\n", Delta_Y_1))

# Now compute PTE via simulation (because regression Y ~ A + S is complex with interaction)
set.seed(123)
n <- 5000

X <- rnorm(n, mean = X_mean_1, sd = sqrt(X_var))
A <- rbinom(n, 1, 0.5)

S <- gamma_0 + gamma_A * A + gamma_X * X + rnorm(n, sd = sigma_S)
Y <- beta_0 + beta_A * A + beta_S * S + beta_X * X + beta_SX * S * X + rnorm(n, sd = sigma_Y)

data_1 <- data.frame(A = A, S = S, Y = Y, X = X)

# Total effect (simulation)
total_effect_1 <- mean(Y[A == 1]) - mean(Y[A == 0])

# PTE via regression Y ~ A + S (ignoring X and S×X!)
model_1 <- lm(Y ~ A + S, data = data_1)
direct_effect_1 <- coef(model_1)["A"]
indirect_effect_1 <- total_effect_1 - direct_effect_1
PTE_1 <- indirect_effect_1 / total_effect_1

cat("Simulated PTE in Study 1:\n")
cat(sprintf("  Total effect:     %.3f (theory: %.1f)\n", total_effect_1, Delta_Y_1))
cat(sprintf("  Direct (Y~A+S):   %.3f\n", direct_effect_1))
cat(sprintf("  Indirect:         %.3f\n", indirect_effect_1))
cat(sprintf("  PTE:              %.3f\n\n", PTE_1))

if (PTE_1 > 0.6) {
  cat("✓ PTE > 0.6 → Traditional methods say GOOD SURROGATE\n\n")
} else if (PTE_1 > 0.4) {
  cat("≈ PTE 0.4-0.6 → Traditional methods say MODERATE SURROGATE\n\n")
} else {
  cat("✗ PTE < 0.4 → Traditional methods say POOR SURROGATE\n\n")
}

# ============================================================================
# Study 2: Future Study with X̄ = 0 (neutral for mediation)
# ============================================================================

cat("STUDY 2: Future Study (X̄ = 0)\n")
cat("-------------------------------\n\n")

X_mean_2 <- 0.0

cat(sprintf("X distribution: X ~ N(%.1f, %.1f)\n\n", X_mean_2, X_var))

# Treatment effects
Delta_S_2 <- gamma_A  # Same (doesn't depend on X mean)
Delta_Y_2 <- beta_A + beta_S * Delta_S_2 + beta_SX * Delta_S_2 * X_mean_2

cat(sprintf("Treatment effect on S: Δ_S = %.1f\n", Delta_S_2))
cat(sprintf("Treatment effect on Y: Δ_Y = %.1f\n\n", Delta_Y_2))

cat("Note: Δ_Y decreased! (X̄ shifted from 1 to 0)\n")
cat("  Via S×X term: %.1f × %.1f × %.1f = %.1f\n\n",
   beta_SX, Delta_S_2, X_mean_2, beta_SX * Delta_S_2 * X_mean_2)

# Simulate
X <- rnorm(n, mean = X_mean_2, sd = sqrt(X_var))
A <- rbinom(n, 1, 0.5)

S <- gamma_0 + gamma_A * A + gamma_X * X + rnorm(n, sd = sigma_S)
Y <- beta_0 + beta_A * A + beta_S * S + beta_X * X + beta_SX * S * X + rnorm(n, sd = sigma_Y)

data_2 <- data.frame(A = A, S = S, Y = Y, X = X)

total_effect_2 <- mean(Y[A == 1]) - mean(Y[A == 0])

model_2 <- lm(Y ~ A + S, data = data_2)
direct_effect_2 <- coef(model_2)["A"]
indirect_effect_2 <- total_effect_2 - direct_effect_2
PTE_2 <- indirect_effect_2 / total_effect_2

cat("Simulated PTE in Study 2:\n")
cat(sprintf("  Total effect:     %.3f (theory: %.1f)\n", total_effect_2, Delta_Y_2))
cat(sprintf("  PTE:              %.3f\n\n", PTE_2))

# ============================================================================
# Study 3: Future Study with X̄ = -1 (unfavorable for mediation)
# ============================================================================

cat("STUDY 3: Future Study (X̄ = -1)\n")
cat("--------------------------------\n\n")

X_mean_3 <- -1.0

cat(sprintf("X distribution: X ~ N(%.1f, %.1f)\n\n", X_mean_3, X_var))

Delta_S_3 <- gamma_A
Delta_Y_3 <- beta_A + beta_S * Delta_S_3 + beta_SX * Delta_S_3 * X_mean_3

cat(sprintf("Treatment effect on S: Δ_S = %.1f\n", Delta_S_3))
cat(sprintf("Treatment effect on Y: Δ_Y = %.1f\n\n", Delta_Y_3))

# Simulate
X <- rnorm(n, mean = X_mean_3, sd = sqrt(X_var))
A <- rbinom(n, 1, 0.5)

S <- gamma_0 + gamma_A * A + gamma_X * X + rnorm(n, sd = sigma_S)
Y <- beta_0 + beta_A * A + beta_S * S + beta_X * X + beta_SX * S * X + rnorm(n, sd = sigma_Y)

data_3 <- data.frame(A = A, S = S, Y = Y, X = X)

total_effect_3 <- mean(Y[A == 1]) - mean(Y[A == 0])

model_3 <- lm(Y ~ A + S, data = data_3)
direct_effect_3 <- coef(model_3)["A"]
indirect_effect_3 <- total_effect_3 - direct_effect_3
PTE_3 <- indirect_effect_3 / total_effect_3

cat("Simulated PTE in Study 3:\n")
cat(sprintf("  Total effect:     %.3f (theory: %.1f)\n", total_effect_3, Delta_Y_3))
cat(sprintf("  PTE:              %.3f\n\n", PTE_3))

# ============================================================================
# Compute Transportability: cor(ΔS, ΔY) across studies
# ============================================================================

cat(strrep("=", 70), "\n")
cat("TRANSPORTABILITY ANALYSIS\n")
cat(strrep("=", 70), "\n\n")

# Treatment effects across studies
Delta_S_vec <- c(Delta_S_1, Delta_S_2, Delta_S_3)
Delta_Y_vec <- c(Delta_Y_1, Delta_Y_2, Delta_Y_3)

cat("Treatment effects across 3 studies:\n")
study_effects <- data.frame(
  Study = c("X̄=1", "X̄=0", "X̄=-1"),
  X_mean = c(X_mean_1, X_mean_2, X_mean_3),
  Delta_S = Delta_S_vec,
  Delta_Y = Delta_Y_vec
)
print(study_effects, digits = 2)
cat("\n")

# Correlation
cor_transport <- cor(Delta_S_vec, Delta_Y_vec)

cat(sprintf("cor(Δ_S, Δ_Y) across studies = %.3f\n\n", cor_transport))

if (abs(cor_transport) < 0.3) {
  cat("✓ LOW correlation across studies\n")
  cat("✓ TV ball method would identify POOR TRANSPORTABILITY\n\n")
} else if (abs(cor_transport) < 0.7) {
  cat("≈ MODERATE correlation across studies\n\n")
} else {
  cat("✗ HIGH correlation across studies\n")
  cat("✗ TV ball method would identify GOOD TRANSPORTABILITY\n\n")
}

# ============================================================================
# Generate more studies to verify pattern
# ============================================================================

cat("VERIFICATION: 20 studies with varying X̄\n")
cat("-----------------------------------------\n\n")

X_means <- seq(-2, 2, length.out = 20)
n_verify <- 2000

Delta_S_all <- numeric(20)
Delta_Y_all <- numeric(20)
PTE_all <- numeric(20)

for (i in 1:20) {
  X <- rnorm(n_verify, mean = X_means[i], sd = sqrt(X_var))
  A <- rbinom(n_verify, 1, 0.5)

  S <- gamma_0 + gamma_A * A + gamma_X * X + rnorm(n_verify, sd = sigma_S)
  Y <- beta_0 + beta_A * A + beta_S * S + beta_X * X + beta_SX * S * X +
    rnorm(n_verify, sd = sigma_Y)

  # Treatment effects
  Delta_S_all[i] <- gamma_A  # Constant
  Delta_Y_all[i] <- mean(Y[A == 1]) - mean(Y[A == 0])

  # PTE
  total <- Delta_Y_all[i]
  model_i <- lm(Y ~ A + S)
  direct <- coef(model_i)["A"]
  indirect <- total - direct
  PTE_all[i] <- indirect / total
}

cor_verify <- cor(Delta_S_all, Delta_Y_all)

cat(sprintf("Correlation cor(Δ_S, Δ_Y) across 20 studies: %.3f\n\n", cor_verify))

# Plot relationship
if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)

  plot_data <- data.frame(
    X_mean = X_means,
    Delta_S = Delta_S_all,
    Delta_Y = Delta_Y_all,
    PTE = PTE_all
  )

  p1 <- ggplot(plot_data, aes(x = X_mean, y = Delta_Y)) +
    geom_line(linewidth = 1) +
    geom_point(size = 3) +
    geom_hline(yintercept = beta_A, linetype = "dashed", color = "red") +
    labs(
      title = "Treatment Effect on Y vs Covariate Mean",
      subtitle = "Δ_Y varies with X̄ due to S×X interaction",
      x = "Mean Covariate (X̄)",
      y = "Treatment Effect Δ_Y"
    ) +
    theme_minimal()

  p2 <- ggplot(plot_data, aes(x = X_mean, y = PTE)) +
    geom_line(linewidth = 1) +
    geom_point(size = 3) +
    geom_hline(yintercept = 0.6, linetype = "dashed", color = "blue") +
    labs(
      title = "PTE vs Covariate Mean",
      subtitle = "PTE varies across studies with different X distributions",
      x = "Mean Covariate (X̄)",
      y = "PTE"
    ) +
    theme_minimal()

  dir.create("explorations/figures", showWarnings = FALSE, recursive = TRUE)
  ggsave("explorations/figures/effect_modification_deltaY.png", p1, width = 8, height = 6)
  ggsave("explorations/figures/effect_modification_pte.png", p2, width = 8, height = 6)

  cat("Plots saved:\n")
  cat("  - explorations/figures/effect_modification_deltaY.png\n")
  cat("  - explorations/figures/effect_modification_pte.png\n\n")
}

# ============================================================================
# Conclusion
# ============================================================================

cat(strrep("=", 70), "\n")
cat("CONCLUSION\n")
cat(strrep("=", 70), "\n\n")

cat("DGP: Effect Modification by Covariates (S×X interaction)\n\n")

cat(sprintf("Study 1 (X̄=1):  PTE = %.3f → %s\n", PTE_1,
           ifelse(PTE_1 > 0.6, "GOOD SURROGATE",
                  ifelse(PTE_1 > 0.4, "MODERATE", "POOR"))))
cat(sprintf("Study 2 (X̄=0):  PTE = %.3f → %s\n", PTE_2,
           ifelse(PTE_2 > 0.6, "GOOD SURROGATE",
                  ifelse(PTE_2 > 0.4, "MODERATE", "POOR"))))
cat(sprintf("Study 3 (X̄=-1): PTE = %.3f → %s\n\n", PTE_3,
           ifelse(PTE_3 > 0.6, "GOOD SURROGATE",
                  ifelse(PTE_3 > 0.4, "MODERATE", "POOR"))))

cat(sprintf("Transportability: cor(Δ_S, Δ_Y) = %.3f\n\n", cor_verify))

if (PTE_1 > 0.6 && abs(cor_verify) < 0.3) {
  cat("✓✓✓ SUCCESS! This DGP creates the desired failure pattern:\n")
  cat("  - Traditional PTE is HIGH in current study (X̄=1)\n")
  cat("  - But cor(Δ_S, Δ_Y) is LOW across future studies\n")
  cat("  - TV ball method would correctly identify POOR TRANSPORTABILITY\n\n")
} else {
  cat("Issue with this DGP:\n")
  if (PTE_1 <= 0.6) {
    cat("  - PTE not high enough in current study\n")
    cat(sprintf("    (%.3f, want > 0.6)\n", PTE_1))
  }
  if (abs(cor_verify) >= 0.3) {
    cat("  - Correlation not low enough across studies\n")
    cat(sprintf("    (%.3f, want < 0.3)\n", abs(cor_verify)))
  }
  cat("\n")
}

cat("KEY INSIGHT:\n")
cat("------------\n")
cat("Problem: Δ_S is CONSTANT across studies (doesn't depend on X̄)\n")
cat("         Δ_Y VARIES with X̄ (due to S×X interaction)\n")
cat("         → cor(Δ_S, Δ_Y) is not well-defined (Δ_S has zero variance!)\n\n")

cat("This DGP shows PTE varies across studies, but doesn't create\n")
cat("the right pattern for cor(Δ_S, Δ_Y) analysis.\n\n")

cat("Need: Both Δ_S and Δ_Y to vary across studies in a way that creates\n")
cat("      - High PTE in current study\n")
cat("      - Low cor(Δ_S, Δ_Y) across studies\n")
