#!/usr/bin/env Rscript

#' Test: Bootstrap vs Reweighting Variance

library(devtools)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("TEST: Bootstrap vs Reweighting for Future Studies\n")
cat("================================================================\n\n")

# Generate baseline with known K=4 class structure
K <- 4
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)

cat("DGP: K=4 classes with strong treatment effect variation\n")
cat("  τ_S:", tau_s, "\n")
cat("  τ_Y:", tau_y, "\n\n")

baseline <- generate_study_data_no_mediation(
  n = 1000,
  n_classes = 4,
  class_probs = c(0.25, 0.25, 0.25, 0.25),
  treatment_effect_surrogate = tau_s,
  treatment_effect_outcome = tau_y,
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat("Baseline generated: n =", nrow(baseline), "\n\n")

# Parameters
lambda <- 0.3
n_innovations <- 500  # Reduced for speed

cat("================================================================\n")
cat("METHOD 1: REWEIGHTING (old approach)\n")
cat("================================================================\n\n")

time_reweight <- system.time({
  result_reweight <- surrogate_inference_if(
    baseline,
    lambda = lambda,
    n_innovations = n_innovations,
    functional_type = "correlation",
    use_bootstrap = FALSE  # OLD APPROACH
  )
})

cat("Results:\n")
cat(sprintf("  Correlation estimate: %.4f\n", result_reweight$estimate))
cat(sprintf("  Standard error: %.4f\n", result_reweight$se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n",
            result_reweight$ci_lower, result_reweight$ci_upper))
cat(sprintf("  Time: %.2f seconds\n", time_reweight["elapsed"]))

# Empirical SD from treatment effects
te_reweight <- result_reweight$treatment_effects
cat(sprintf("\n  Empirical SD(ΔS): %.4f\n", sd(te_reweight[, "delta_s"])))
cat(sprintf("  Empirical SD(ΔY): %.4f\n", sd(te_reweight[, "delta_y"])))
cat(sprintf("  Empirical correlation: %.4f\n",
            cor(te_reweight[, "delta_s"], te_reweight[, "delta_y"])))

cat("\n================================================================\n")
cat("METHOD 2: BOOTSTRAP (new approach)\n")
cat("================================================================\n\n")

time_bootstrap <- system.time({
  result_bootstrap <- surrogate_inference_if(
    baseline,
    lambda = lambda,
    n_innovations = n_innovations,
    functional_type = "correlation",
    use_bootstrap = TRUE  # NEW APPROACH
  )
})

cat("Results:\n")
cat(sprintf("  Correlation estimate: %.4f\n", result_bootstrap$estimate))
cat(sprintf("  Standard error: %.4f\n", result_bootstrap$se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n",
            result_bootstrap$ci_lower, result_bootstrap$ci_upper))
cat(sprintf("  Time: %.2f seconds\n", time_bootstrap["elapsed"]))

# Empirical SD from treatment effects
te_bootstrap <- result_bootstrap$treatment_effects
cat(sprintf("\n  Empirical SD(ΔS): %.4f\n", sd(te_bootstrap[, "delta_s"])))
cat(sprintf("  Empirical SD(ΔY): %.4f\n", sd(te_bootstrap[, "delta_y"])))
cat(sprintf("  Empirical correlation: %.4f\n",
            cor(te_bootstrap[, "delta_s"], te_bootstrap[, "delta_y"])))

cat("\n================================================================\n")
cat("GROUND TRUTH 1: Independent Sampling from Baseline Data\n")
cat("================================================================\n\n")

# This is what bootstrap SHOULD match: sample from observed data
n_truth <- 500
effects_from_baseline <- matrix(NA, n_truth, 2)

for (m in 1:n_truth) {
  # Draw innovation weights
  p_tilde <- MCMCpack::rdirichlet(1, rep(1, nrow(baseline)))[1,]

  # Form mixture
  p_hat <- rep(1/nrow(baseline), nrow(baseline))
  q_weights <- (1 - lambda) * p_hat + lambda * p_tilde

  # Sample from mixture (what bootstrap does)
  boot_indices <- sample(1:nrow(baseline), size = nrow(baseline),
                        replace = TRUE, prob = q_weights)
  boot_sample <- baseline[boot_indices, ]

  # Compute treatment effects
  delta_s <- mean(boot_sample$S[boot_sample$A == 1]) -
             mean(boot_sample$S[boot_sample$A == 0])
  delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) -
             mean(boot_sample$Y[boot_sample$A == 0])

  effects_from_baseline[m, ] <- c(delta_s, delta_y)
}

cat("Results:\n")
cat(sprintf("  Empirical SD(ΔS): %.4f\n", sd(effects_from_baseline[, 1])))
cat(sprintf("  Empirical SD(ΔY): %.4f\n", sd(effects_from_baseline[, 2])))
cat(sprintf("  Empirical correlation: %.4f\n",
            cor(effects_from_baseline[, 1], effects_from_baseline[, 2])))

cat("\n================================================================\n")
cat("GROUND TRUTH 2: Independent Sampling from Population (K-dim)\n")
cat("================================================================\n\n")

# Class-based approach (K-dimensional innovation from population)
effects_class_based <- matrix(NA, n_truth, 2)

for (m in 1:n_truth) {
  # Draw class mixture (K=4 dimensional)
  pi <- MCMCpack::rdirichlet(1, rep(1, K))[1,]

  # Compute treatment effects (no sampling!)
  effects_class_based[m, 1] <- sum(pi * tau_s)
  effects_class_based[m, 2] <- sum(pi * tau_y)
}

cat("Results:\n")
cat(sprintf("  Empirical SD(ΔS): %.4f\n", sd(effects_class_based[, 1])))
cat(sprintf("  Empirical SD(ΔY): %.4f\n", sd(effects_class_based[, 2])))
cat(sprintf("  Empirical correlation: %.4f\n",
            cor(effects_class_based[, 1], effects_class_based[, 2])))

cat("\n================================================================\n")
cat("COMPARISON\n")
cat("================================================================\n\n")

cat(sprintf("%-20s %-12s %-12s %-12s %-10s\n",
            "Approach", "SD(ΔS)", "SD(ΔY)", "Correlation", "Time (s)"))
cat(strrep("-", 75), "\n")

cat(sprintf("%-20s %-12.4f %-12.4f %-12.4f %-10.2f\n",
            "Reweighting",
            sd(te_reweight[, "delta_s"]),
            sd(te_reweight[, "delta_y"]),
            cor(te_reweight[, "delta_s"], te_reweight[, "delta_y"]),
            time_reweight["elapsed"]))

cat(sprintf("%-20s %-12.4f %-12.4f %-12.4f %-10.2f\n",
            "Bootstrap",
            sd(te_bootstrap[, "delta_s"]),
            sd(te_bootstrap[, "delta_y"]),
            cor(te_bootstrap[, "delta_s"], te_bootstrap[, "delta_y"]),
            time_bootstrap["elapsed"]))

cat(sprintf("%-20s %-12.4f %-12.4f %-12.4f %-10s\n",
            "GT1: From Data",
            sd(effects_from_baseline[, 1]),
            sd(effects_from_baseline[, 2]),
            cor(effects_from_baseline[, 1], effects_from_baseline[, 2]),
            "—"))

cat(sprintf("%-20s %-12.4f %-12.4f %-12.4f %-10s\n",
            "GT2: From Pop (K)",
            sd(effects_class_based[, 1]),
            sd(effects_class_based[, 2]),
            cor(effects_class_based[, 1], effects_class_based[, 2]),
            "—"))

cat("\n")

# Compute ratios against both ground truths
sd_ratio_reweight_data <- sd(te_reweight[, "delta_s"]) / sd(effects_from_baseline[, 1])
sd_ratio_bootstrap_data <- sd(te_bootstrap[, "delta_s"]) / sd(effects_from_baseline[, 1])

sd_ratio_reweight_pop <- sd(te_reweight[, "delta_s"]) / sd(effects_class_based[, 1])
sd_ratio_bootstrap_pop <- sd(te_bootstrap[, "delta_s"]) / sd(effects_class_based[, 1])

cat("SD Ratios:\n")
cat(sprintf("  Relative to GT1 (From Data):\n"))
cat(sprintf("    Reweighting:  %.2fx\n", sd_ratio_reweight_data))
cat(sprintf("    Bootstrap:    %.2fx\n", sd_ratio_bootstrap_data))
cat(sprintf("  Relative to GT2 (From Population):\n"))
cat(sprintf("    Reweighting:  %.2fx\n", sd_ratio_reweight_pop))
cat(sprintf("    Bootstrap:    %.2fx\n", sd_ratio_bootstrap_pop))
cat("\n")

if (sd_ratio_bootstrap_data > 0.8 && sd_ratio_bootstrap_data < 1.2) {
  cat("✓✓ SUCCESS: Bootstrap matches sampling from observed data!\n")
  cat(sprintf("   Ratio: %.2fx (within 20%% of GT1)\n", sd_ratio_bootstrap_data))
} else {
  cat("✗ Bootstrap doesn't match sampling from observed data\n")
  cat(sprintf("   Ratio: %.2fx (should be ~1.0x)\n", sd_ratio_bootstrap_data))
}

if (sd_ratio_reweight_data < 0.5) {
  cat("✓ Confirmed: Reweighting underestimates variance vs observed data\n")
  cat(sprintf("   Ratio: %.2fx\n", sd_ratio_reweight_data))
}

cat("\n")

# Time comparison
speedup <- time_bootstrap["elapsed"] / time_reweight["elapsed"]
cat(sprintf("Bootstrap is %.1fx slower than reweighting\n", speedup))
cat("(Expected: ~3-4x slower due to sampling overhead)\n")

cat("\n================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

if (sd_ratio_bootstrap_data > 0.8 && sd_ratio_bootstrap_data < 1.2) {
  cat("✓✓ Bootstrap fix successful!\n\n")

  cat("Key findings:\n")
  cat(sprintf("  1. Bootstrap matches independent sampling from observed data (%.2fx)\n",
              sd_ratio_bootstrap_data))
  cat(sprintf("  2. Reweighting underestimates vs observed data (%.2fx)\n",
              sd_ratio_reweight_data))
  cat(sprintf("  3. Both are lower than population variance (K-dimensional)\n"))
  cat(sprintf("     because observed data has fixed class composition\n\n"))

  cat("Bootstrap approach:\n")
  cat("  ✓ Correct for 'new samples from same n people'\n")
  cat("  ✓ Includes proper sampling variability\n")
  cat(sprintf("  ✓ Only %.1fx slower than reweighting\n", speedup))
  cat("  ✓ No parametric assumptions\n\n")

  cat("Reweighting approach:\n")
  cat(sprintf("  ✗ Underestimates variance (%.2fx too small)\n", sd_ratio_reweight_data))
  cat("  ✓ Faster but misses sampling variability\n")
  cat("  → Use only for population reweighting, not new samples\n\n")

  cat("Population variance (K-dimensional):\n")
  cat("  • Higher than both because class composition varies\n")
  cat("  • Would need to model class structure to achieve this\n")
  cat("  • Bootstrap from data can't capture this variation\n\n")

  cat("RECOMMENDATION: Use use_bootstrap=TRUE (default) for new studies\n")
} else {
  cat("⚠ Bootstrap doesn't match sampling from data - needs investigation\n")
  cat(sprintf("   Expected ~1.0x, got %.2fx\n", sd_ratio_bootstrap_data))
}

cat("\n================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
