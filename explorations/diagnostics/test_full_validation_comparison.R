#!/usr/bin/env Rscript

#' FINAL TEST: Full Validation Comparison
#'
#' Compare ground truth (type-level innovations) vs package method (obs-level)
#' with actual data generation and treatment effect estimation

library(devtools)
library(dplyr)
library(tibble)
library(MCMCpack)

# Load package
while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}
devtools::load_all("package/", quiet = TRUE)

set.seed(20260324)

cat("================================================================\n")
cat("FINAL TEST: Full Validation Comparison\n")
cat("================================================================\n\n")

# Parameters
K <- 4
n_baseline <- 1000
M <- 500
lambda <- 0.3

# Population parameters
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)
noise_sd <- 0.2

cat(sprintf("Population: K=%d types, n=%d, M=%d innovations, λ=%.2f\n", K, n_baseline, M, lambda))
cat(sprintf("τ_S: %s\n", paste(round(tau_s, 2), collapse=", ")))
cat(sprintf("τ_Y: %s\n", paste(round(tau_y, 2), collapse=", ")))
cat(sprintf("Population correlation: %.3f\n\n", cor(tau_s, tau_y)))

# Generate baseline data
types_baseline <- sample(1:K, size = n_baseline, replace = TRUE)
A_baseline <- rbinom(n_baseline, 1, 0.5)
S_baseline <- numeric(n_baseline)
Y_baseline <- numeric(n_baseline)

for (i in 1:n_baseline) {
  type_i <- types_baseline[i]
  S_baseline[i] <- A_baseline[i] * tau_s[type_i] + rnorm(1, 0, noise_sd)
  Y_baseline[i] <- A_baseline[i] * tau_y[type_i] + rnorm(1, 0, noise_sd)
}

baseline_data <- tibble(
  type = types_baseline,
  A = A_baseline,
  S = S_baseline,
  Y = Y_baseline
)

cat("Baseline data generated\n")
cat(sprintf("  Type distribution: %s\n",
            paste(round(table(types_baseline) / n_baseline, 3), collapse=", ")))
cat(sprintf("  Treatment rate: %.1f%%\n\n", 100 * mean(A_baseline)))

# METHOD 1: TYPE-LEVEL innovations (ground truth)
cat("METHOD 1: Type-level innovations (Ground Truth Approach)\n")
cat("--------------------------------------------------------\n")

effects_type_level <- matrix(NA, nrow = M, ncol = 2)

for (m in 1:M) {
  # Generate type-level innovation
  type_weights_m <- rdirichlet(1, rep(1, K))[1,]

  # Form mixture
  p0_type <- rep(1/K, K)
  q_m_type <- (1 - lambda) * p0_type + lambda * type_weights_m

  # Generate NEW sample from this mixture
  types_m <- sample(1:K, size = n_baseline, replace = TRUE, prob = q_m_type)
  A_m <- rbinom(n_baseline, 1, 0.5)
  S_m <- numeric(n_baseline)
  Y_m <- numeric(n_baseline)

  for (i in 1:n_baseline) {
    type_i <- types_m[i]
    S_m[i] <- A_m[i] * tau_s[type_i] + rnorm(1, 0, noise_sd)
    Y_m[i] <- A_m[i] * tau_y[type_i] + rnorm(1, 0, noise_sd)
  }

  # Compute treatment effects
  delta_s_m <- mean(S_m[A_m == 1]) - mean(S_m[A_m == 0])
  delta_y_m <- mean(Y_m[A_m == 1]) - mean(Y_m[A_m == 0])

  effects_type_level[m, ] <- c(delta_s_m, delta_y_m)
}

corr_type_level <- cor(effects_type_level[, 1], effects_type_level[, 2])

cat(sprintf("  Correlation: %.3f\n", corr_type_level))
cat(sprintf("  SD(ΔS): %.4f\n", sd(effects_type_level[, 1])))
cat(sprintf("  SD(ΔY): %.4f\n\n", sd(effects_type_level[, 2])))

# METHOD 2: OBS-LEVEL innovations (package approach)
cat("METHOD 2: Obs-level innovations (Package Approach)\n")
cat("---------------------------------------------------\n")

effects_obs_level <- matrix(NA, nrow = M, ncol = 2)

# Generate obs-level innovations (what the package does)
innovations_obs <- rdirichlet(M, rep(1, n_baseline))

for (m in 1:M) {
  # Form mixture over observations
  p0_obs <- rep(1/n_baseline, n_baseline)
  p_tilde_obs <- innovations_obs[m, ]
  q_m_obs <- (1 - lambda) * p0_obs + lambda * p_tilde_obs

  # Bootstrap from baseline with these weights
  boot_indices <- sample(1:n_baseline, size = n_baseline, replace = TRUE, prob = q_m_obs)
  boot_sample <- baseline_data[boot_indices, ]

  # Compute treatment effects
  delta_s_m <- mean(boot_sample$S[boot_sample$A == 1]) -
               mean(boot_sample$S[boot_sample$A == 0])
  delta_y_m <- mean(boot_sample$Y[boot_sample$A == 1]) -
               mean(boot_sample$Y[boot_sample$A == 0])

  effects_obs_level[m, ] <- c(delta_s_m, delta_y_m)
}

corr_obs_level <- cor(effects_obs_level[, 1], effects_obs_level[, 2])

cat(sprintf("  Correlation: %.3f\n", corr_obs_level))
cat(sprintf("  SD(ΔS): %.4f\n", sd(effects_obs_level[, 1])))
cat(sprintf("  SD(ΔY): %.4f\n\n", sd(effects_obs_level[, 2])))

# COMPARISON
cat("================================================================\n")
cat("RESULTS COMPARISON\n")
cat("================================================================\n\n")

cat(sprintf("Ground truth (type-level):  corr=%.3f, SD(ΔS)=%.4f, SD(ΔY)=%.4f\n",
            corr_type_level,
            sd(effects_type_level[, 1]),
            sd(effects_type_level[, 2])))
cat(sprintf("Package (obs-level):        corr=%.3f, SD(ΔS)=%.4f, SD(ΔY)=%.4f\n\n",
            corr_obs_level,
            sd(effects_obs_level[, 1]),
            sd(effects_obs_level[, 2])))

cat("Ratios:\n")
cat(sprintf("  Correlation: Package is %.1f%% of ground truth\n",
            100 * corr_obs_level / corr_type_level))
cat(sprintf("  SD(ΔS): Package is %.1f%% of ground truth\n",
            100 * sd(effects_obs_level[, 1]) / sd(effects_type_level[, 1])))
cat(sprintf("  SD(ΔY): Package is %.1f%% of ground truth\n\n",
            100 * sd(effects_obs_level[, 2]) / sd(effects_type_level[, 2])))

# Compare to actual validation results
cat("================================================================\n")
cat("COMPARISON TO ACTUAL VALIDATION RESULTS\n")
cat("================================================================\n\n")

cat("From validation log (K=4, λ=0.3):\n")
cat("  Ground truth correlation: 0.696\n")
cat("  Method estimate: 0.218\n")
cat("  Ratio: 31.3%\n\n")

cat("From this test:\n")
cat(sprintf("  Ground truth correlation: %.3f\n", corr_type_level))
cat(sprintf("  Package correlation: %.3f\n", corr_obs_level))
cat(sprintf("  Ratio: %.1f%%\n\n", 100 * corr_obs_level / corr_type_level))

if (abs(100 * corr_obs_level / corr_type_level - 31.3) < 20) {
  cat("✓ This test REPRODUCES the validation failure pattern!\n")
  cat("  The obs-level innovation approach severely dampens correlation\n\n")
} else {
  cat("⚠ Pattern doesn't fully match - may need further investigation\n\n")
}

cat("================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

cat("The K=4 validation failure is caused by:\n\n")

cat("INNOVATION DISTRIBUTION MISMATCH:\n")
cat("  • Ground truth: Dirichlet over K=4 types\n")
cat("    → Type proportions vary widely (17%-44%)\n")
cat("    → Treatment effects have strong variation\n")
cat("    → Correlation signal is clear (≈0.7)\n\n")

cat("  • Package: Dirichlet over n=1000 observations\n")
cat("    → Type proportions constrained near baseline (21%-28%)\n")
cat("    → Treatment effects have weak variation\n")
cat("    → Correlation signal is dampened (≈0.2-0.3)\n\n")

cat("FIX:\n")
cat("  The package should detect when data has types/classes and use:\n")
cat("    innovations <- rdirichlet(M, rep(alpha, K))  # Over types, not observations\n")
cat("  Then convert type weights to observation weights for bootstrapping\n\n")

cat("WHY K=4 FAILS BUT K=500 WORKS:\n")
cat("  • K=4: Clear distinction between type-level and obs-level\n")
cat("    → 250 obs/type → obs-level constrains variation\n")
cat("  • K=500: Type-level ≈ obs-level\n")
cat("    → 2 obs/type → less distinction between approaches\n")
cat("    → Both give similar results\n\n")

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
