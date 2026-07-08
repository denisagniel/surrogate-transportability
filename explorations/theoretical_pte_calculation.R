#!/usr/bin/env Rscript
#
# Theoretical PTE Calculation for Non-Mediated Heterogeneity DGP
#
# Question: Can we create a scenario where:
# - cor(τ_S, τ_Y) ≈ 0 (effects uncorrelated across types)
# - BUT PTE is HIGH (> 0.6)?
#
# This script derives the theoretical PTE formula to answer this.

cat("=" , rep("=", 69), "\n", sep="")
cat("THEORETICAL PTE CALCULATION: Non-Mediated Heterogeneity\n")
cat("=", rep("=", 69), "\n\n", sep="")

# ============================================================================
# Setup: DGP Structure
# ============================================================================

cat("DGP STRUCTURE:\n")
cat("--------------\n")
cat("S = S₀ + A·τ_S[type] + α·U + ε_S\n")
cat("Y = Y₀ + A·τ_Y[type] + α·U + ε_Y\n")
cat("\n")
cat("Key properties:\n")
cat("- τ_S, τ_Y vary across types\n")
cat("- cor(τ_S, τ_Y) ≈ 0 (uncorrelated effects)\n")
cat("- U is unmeasured confounder (creates within-study correlation)\n")
cat("- NO S→Y causal pathway\n")
cat("\n\n")

# ============================================================================
# Example: 4 Types with Uncorrelated Effects
# ============================================================================

cat("EXAMPLE: 4 Types with cor(τ_S, τ_Y) = 0\n")
cat("----------------------------------------\n\n")

# Design types to have cor = 0 but non-zero means
tau_S <- c(2, 0, 2, 0)  # Varies: high/low/high/low
tau_Y <- c(1, 1, 0, 0)  # Varies: high/high/low/low
P0 <- rep(0.25, 4)      # Equal probabilities

cat("Type effects:\n")
type_table <- data.frame(
  Type = 1:4,
  Probability = P0,
  tau_S = tau_S,
  tau_Y = tau_Y
)
print(type_table)
cat("\n")

# Verify correlation
cor_effects <- cor(tau_S, tau_Y)
cat(sprintf("cor(τ_S, τ_Y) = %.3f ✓ (target: 0)\n\n", cor_effects))

# Average effects
Delta_S <- sum(P0 * tau_S)
Delta_Y <- sum(P0 * tau_Y)

cat(sprintf("Average treatment effects:\n"))
cat(sprintf("  Δ_S = %.2f\n", Delta_S))
cat(sprintf("  Δ_Y = %.2f\n\n", Delta_Y))

# ============================================================================
# Theoretical Calculation: What Predicts Y in Regression Y ~ A + S?
# ============================================================================

cat("KEY INSIGHT: In Regression Y ~ A + S\n")
cat("-------------------------------------\n\n")

cat("In the TREATED arm (A=1):\n")
cat("  - Type 1: S ≈ 2, Y ≈ 1\n")
cat("  - Type 2: S ≈ 0, Y ≈ 1\n")
cat("  - Type 3: S ≈ 2, Y ≈ 0\n")
cat("  - Type 4: S ≈ 0, Y ≈ 0\n")
cat("\n")

cat("Pattern:\n")
cat("  - High S (≈2): 50% have high Y (Type 1), 50% have low Y (Type 3)\n")
cat("  - Low S (≈0):  50% have high Y (Type 2), 50% have low Y (Type 4)\n")
cat("\n")
cat("→ Within treated arm, S does NOT predict Y!\n")
cat("  (Beyond confounding through U)\n\n")

cat("In the CONTROL arm (A=0):\n")
cat("  - All types: S ≈ S₀, Y ≈ Y₀\n")
cat("  - S and Y only correlated through U\n\n")

# ============================================================================
# Approximate β_S (coefficient on S in Y ~ A + S)
# ============================================================================

cat("APPROXIMATION: Coefficient β_S on S\n")
cat("------------------------------------\n\n")

# Parameters
alpha <- 0.5        # Confounding strength
sigma_S <- 0.8      # Noise in S
sigma_Y <- 0.8      # Noise in Y

cat(sprintf("Parameters: α = %.1f, σ_S = %.1f, σ_Y = %.1f\n\n", alpha, sigma_S, sigma_Y))

# Variance components
var_treatment_S <- 0.5 * var(tau_S)  # 0.5 because P(A=1)=0.5
var_confound <- alpha^2
var_noise_S <- sigma_S^2

var_S_total <- var_treatment_S + var_confound + var_noise_S

cat("Variance decomposition for S:\n")
cat(sprintf("  From treatment effects: %.3f\n", var_treatment_S))
cat(sprintf("  From confounding U:     %.3f\n", var_confound))
cat(sprintf("  From noise:             %.3f\n", var_noise_S))
cat(sprintf("  Total Var(S):          %.3f\n\n", var_S_total))

# Covariance between S and Y
# Since cor(τ_S, τ_Y) = 0, no contribution from treatment effect correlation
# Only contribution is from confounding U
cov_SY_confound <- alpha^2

cat("Covariance Cov(S, Y):\n")
cat(sprintf("  From confounding U: %.3f\n", cov_SY_confound))
cat(sprintf("  From treatment effects: %.3f (cor = 0!)\n", 0))
cat(sprintf("  Total Cov(S, Y):   %.3f\n\n", cov_SY_confound))

# Approximate β_S
beta_S_approx <- cov_SY_confound / var_S_total

cat(sprintf("Approximate β_S ≈ Cov(S,Y) / Var(S) = %.3f / %.3f = %.3f\n\n",
           cov_SY_confound, var_S_total, beta_S_approx))

# ============================================================================
# Calculate PTE
# ============================================================================

cat("PTE CALCULATION\n")
cat("---------------\n\n")

indirect_effect <- Delta_S * beta_S_approx
total_effect <- Delta_Y

PTE_theoretical <- indirect_effect / total_effect

cat(sprintf("Indirect effect = Δ_S × β_S = %.2f × %.3f = %.3f\n",
           Delta_S, beta_S_approx, indirect_effect))
cat(sprintf("Total effect    = Δ_Y        = %.2f\n", total_effect))
cat(sprintf("\nPTE = Indirect / Total = %.3f / %.2f = %.3f\n\n",
           indirect_effect, total_effect, PTE_theoretical))

# ============================================================================
# Verify with Simulation
# ============================================================================

cat("VERIFICATION VIA SIMULATION\n")
cat("---------------------------\n\n")

set.seed(123)
n <- 5000

# Generate data
type <- sample(1:4, n, replace = TRUE, prob = P0)
A <- rbinom(n, 1, 0.5)
U <- rnorm(n)

S <- 2 + A * tau_S[type] + alpha * U + rnorm(n, sd = sigma_S)
Y <- 1 + A * tau_Y[type] + alpha * U + rnorm(n, sd = sigma_Y)

data <- data.frame(A = A, S = S, Y = Y)

# Compute PTE via simulation
# Total effect
total_sim <- mean(Y[A==1]) - mean(Y[A==0])

# Direct effect (regression Y ~ A + S)
model_direct <- lm(Y ~ A + S, data = data)
direct_sim <- coef(model_direct)["A"]

# Indirect effect
indirect_sim <- total_sim - direct_sim

# PTE
PTE_sim <- indirect_sim / total_sim

cat(sprintf("Simulated results (n=%d):\n", n))
cat(sprintf("  Total effect:    %.3f (theory: %.2f)\n", total_sim, total_effect))
cat(sprintf("  Indirect effect: %.3f (theory: %.3f)\n", indirect_sim, indirect_effect))
cat(sprintf("  PTE:            %.3f (theory: %.3f)\n\n", PTE_sim, PTE_theoretical))

# Also check β_S from regression
beta_S_sim <- coef(model_direct)["S"]
cat(sprintf("  β_S from regression: %.3f (theory: %.3f)\n\n", beta_S_sim, beta_S_approx))

# ============================================================================
# Conclusion
# ============================================================================

cat("=" , rep("=", 69), "\n", sep="")
cat("CONCLUSION\n")
cat("=", rep("=", 69), "\n\n", sep="")

cat("For DGP with cor(τ_S, τ_Y) = 0:\n\n")

cat(sprintf("  Theoretical PTE: %.3f\n", PTE_sim))
cat(sprintf("  Simulated PTE:   %.3f\n\n", PTE_sim))

if (PTE_sim < 0.4) {
  cat("✗ PTE is LOW (< 0.4)\n")
  cat("✗ Traditional methods would correctly identify POOR surrogate\n\n")
} else if (PTE_sim < 0.6) {
  cat("≈ PTE is MODERATE (0.4 - 0.6)\n")
  cat("≈ Traditional methods ambiguous\n\n")
} else {
  cat("✓ PTE is HIGH (> 0.6)\n")
  cat("✓ Traditional methods would incorrectly identify GOOD surrogate\n\n")
}

cat("FUNDAMENTAL ISSUE:\n")
cat("------------------\n")
cat("If cor(τ_S, τ_Y) = 0, then:\n")
cat("  - High S does NOT predict high Y (within treated arm)\n")
cat("  - β_S only captures confounding, not treatment structure\n")
cat("  - Indirect effect = Δ_S × β_S is SMALL\n")
cat("  - Therefore PTE is LOW\n\n")

cat("For PTE to be HIGH, we need β_S to be large.\n")
cat("For β_S to be large, S must predict Y.\n")
cat("For S to predict Y, we need cor(τ_S, τ_Y) > 0!\n\n")

cat("→ Non-mediated heterogeneity (cor ≈ 0) CANNOT produce high PTE.\n")
cat("→ This DGP will NOT demonstrate the desired failure mode.\n\n")

cat("RECOMMENDATION:\n")
cat("---------------\n")
cat("Need a different DGP concept that can create:\n")
cat("  - High PTE/mediation in observed study\n")
cat("  - But low transportability (low cor(ΔS, ΔY) across Q)\n\n")

cat("Possible alternatives:\n")
cat("1. S causes Y in current study, but mechanism breaks in future studies\n")
cat("2. S mediates through unmeasured M that varies across studies\n")
cat("3. Confounding by measured X that PTE ignores but affects transportability\n")
cat("4. Selection effects where current study is atypical\n")
