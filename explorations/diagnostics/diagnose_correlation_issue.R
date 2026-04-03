#!/usr/bin/env Rscript

#' Diagnose Correlation Issue
#'
#' Tests whether reweighting approach picks up artifacts

library(devtools)
library(dplyr)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("DIAGNOSING CORRELATION ISSUE\n")
cat("================================================================\n\n")

# Test: Good surrogate DGP
cat("Good Surrogate DGP: TE_S = (0.3, 0.9), TE_Y = (0.2, 0.8)\n\n")

baseline <- generate_study_data_no_mediation(
  n = 2000,
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

# 1. Within-study correlation (should NOT matter for cross-study)
within_corr <- cor(baseline$S, baseline$Y)
cat(sprintf("Within-study correlation S-Y: %.3f\n\n", within_corr))

# 2. Compute cross-study correlation TWO WAYS:

cat("METHOD 1: REWEIGHTING (current approach)\n")
cat("------------------------------------------\n")

lambda <- 0.3
n_studies <- 500
n <- nrow(baseline)

# Reweighting approach
effects_reweight <- matrix(NA, n_studies, 2)
for (m in 1:n_studies) {
  p_tilde <- MCMCpack::rdirichlet(1, rep(1, n))
  p0 <- rep(1/n, n)
  q_weights <- (1 - lambda) * p0 + lambda * p_tilde[1,]

  effects_reweight[m, 1] <- sum(q_weights * baseline$S * baseline$A) / sum(q_weights * baseline$A) -
                            sum(q_weights * baseline$S * (1 - baseline$A)) / sum(q_weights * (1 - baseline$A))
  effects_reweight[m, 2] <- sum(q_weights * baseline$Y * baseline$A) / sum(q_weights * baseline$A) -
                            sum(q_weights * baseline$Y * (1 - baseline$A)) / sum(q_weights * (1 - baseline$A))
}

corr_reweight <- cor(effects_reweight[, 1], effects_reweight[, 2])
cat(sprintf("Cross-study correlation (reweighting): %.3f\n", corr_reweight))
cat(sprintf("SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            sd(effects_reweight[, 1]), sd(effects_reweight[, 2])))

cat("METHOD 2: INDEPENDENT SAMPLES (true cross-study)\n")
cat("--------------------------------------------------\n")

# Generate truly independent studies
effects_independent <- matrix(NA, n_studies, 2)
for (m in 1:n_studies) {
  # Draw new class mixture (like reweighting does)
  class_probs_m <- MCMCpack::rdirichlet(1, c(1, 1))[1,]

  # Generate NEW sample with these class probabilities
  new_study <- generate_study_data_no_mediation(
    n = 2000,
    n_classes = 2,
    class_probs = class_probs_m,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  # Compute treatment effect on NEW sample
  effects_independent[m, 1] <- mean(new_study$S[new_study$A == 1]) -
                               mean(new_study$S[new_study$A == 0])
  effects_independent[m, 2] <- mean(new_study$Y[new_study$A == 1]) -
                               mean(new_study$Y[new_study$A == 0])
}

corr_independent <- cor(effects_independent[, 1], effects_independent[, 2])
cat(sprintf("Cross-study correlation (independent samples): %.3f\n", corr_independent))
cat(sprintf("SD(TE_S): %.3f, SD(TE_Y): %.3f\n\n",
            sd(effects_independent[, 1]), sd(effects_independent[, 2])))

cat("================================================================\n")
cat("COMPARISON\n")
cat("================================================================\n\n")

cat(sprintf("Within-study correlation:    %.3f\n", within_corr))
cat(sprintf("Reweighting correlation:     %.3f\n", corr_reweight))
cat(sprintf("Independent samples corr:    %.3f\n\n", corr_independent))

if (abs(corr_reweight - within_corr) < abs(corr_independent - within_corr)) {
  cat("⚠ WARNING: Reweighting correlation closer to within-study correlation!\n")
  cat("  → Reweighting might be picking up within-study artifacts\n\n")
}

if (corr_independent > corr_reweight + 0.1) {
  cat("⚠ CRITICAL: Independent samples show HIGHER correlation\n")
  cat("  → Reweighting is UNDERESTIMATING true cross-study correlation\n\n")
}

cat("Interpretation:\n")
cat("---------------\n")
cat("If reweighting ≈ within-study: Picking up noise/within-study artifacts\n")
cat("If independent >> reweighting: Reweighting underestimates (good surrogate looks bad)\n")
cat("If independent ≈ reweighting: Method is working correctly\n\n")

cat("================================================================\n")
cat("NOW TEST BAD SURROGATE\n")
cat("================================================================\n\n")

cat("Bad Surrogate DGP: TE_S = (0.3, 0.9), TE_Y = (-0.8, -0.2)\n\n")

baseline_bad <- generate_study_data_no_mediation(
  n = 2000,
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(-0.8, -0.2),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

within_corr_bad <- cor(baseline_bad$S, baseline_bad$Y)
cat(sprintf("Within-study correlation S-Y: %.3f\n\n", within_corr_bad))

# Reweighting
effects_reweight_bad <- matrix(NA, n_studies, 2)
for (m in 1:n_studies) {
  p_tilde <- MCMCpack::rdirichlet(1, rep(1, nrow(baseline_bad)))
  p0 <- rep(1/nrow(baseline_bad), nrow(baseline_bad))
  q_weights <- (1 - lambda) * p0 + lambda * p_tilde[1,]

  effects_reweight_bad[m, 1] <- sum(q_weights * baseline_bad$S * baseline_bad$A) / sum(q_weights * baseline_bad$A) -
                                sum(q_weights * baseline_bad$S * (1 - baseline_bad$A)) / sum(q_weights * (1 - baseline_bad$A))
  effects_reweight_bad[m, 2] <- sum(q_weights * baseline_bad$Y * baseline_bad$A) / sum(q_weights * baseline_bad$A) -
                                sum(q_weights * baseline_bad$Y * (1 - baseline_bad$A)) / sum(q_weights * (1 - baseline_bad$A))
}

corr_reweight_bad <- cor(effects_reweight_bad[, 1], effects_reweight_bad[, 2])
cat(sprintf("Reweighting correlation: %.3f\n\n", corr_reweight_bad))

# Independent samples
effects_independent_bad <- matrix(NA, n_studies, 2)
for (m in 1:n_studies) {
  class_probs_m <- MCMCpack::rdirichlet(1, c(1, 1))[1,]

  new_study <- generate_study_data_no_mediation(
    n = 2000,
    n_classes = 2,
    class_probs = class_probs_m,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(-0.8, -0.2),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )

  effects_independent_bad[m, 1] <- mean(new_study$S[new_study$A == 1]) -
                                   mean(new_study$S[new_study$A == 0])
  effects_independent_bad[m, 2] <- mean(new_study$Y[new_study$A == 1]) -
                                   mean(new_study$Y[new_study$A == 0])
}

corr_independent_bad <- cor(effects_independent_bad[, 1], effects_independent_bad[, 2])
cat(sprintf("Independent samples correlation: %.3f\n\n", corr_independent_bad))

cat("================================================================\n")
cat("BAD SURROGATE COMPARISON\n")
cat("================================================================\n\n")

cat(sprintf("Within-study correlation:    %.3f\n", within_corr_bad))
cat(sprintf("Reweighting correlation:     %.3f\n", corr_reweight_bad))
cat(sprintf("Independent samples corr:    %.3f\n\n", corr_independent_bad))

cat("================================================================\n")
cat("FINAL VERDICT\n")
cat("================================================================\n\n")

cat("GOOD SURROGATE:\n")
cat(sprintf("  Reweighting:   %.3f\n", corr_reweight))
cat(sprintf("  Independent:   %.3f\n", corr_independent))
cat(sprintf("  Difference:    %.3f\n\n", corr_independent - corr_reweight))

cat("BAD SURROGATE:\n")
cat(sprintf("  Reweighting:   %.3f\n", corr_reweight_bad))
cat(sprintf("  Independent:   %.3f\n", corr_independent_bad))
cat(sprintf("  Difference:    %.3f\n\n", corr_independent_bad - corr_reweight_bad))

if (abs(corr_reweight - corr_independent) > 0.1 ||
    abs(corr_reweight_bad - corr_independent_bad) > 0.1) {
  cat("⚠ CRITICAL PROBLEM IDENTIFIED:\n")
  cat("  Reweighting approach does NOT match independent samples!\n")
  cat("  → Our method for computing 'true' functionals may be wrong\n")
  cat("  → Need to rethink validation approach\n\n")
} else {
  cat("✓ Reweighting approach matches independent samples\n")
  cat("  → Method is correctly computing cross-study correlations\n\n")
}

cat("================================================================\n")
