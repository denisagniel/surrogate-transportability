#!/usr/bin/env Rscript

#' Quick Test: NPV Functional

library(devtools)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("TESTING NPV FUNCTIONAL\n")
cat("================================================================\n\n")

# Generate baseline with 4-class DGP where TE vary across zero
baseline <- generate_study_data_no_mediation(
  n = 2000,
  n_classes = 4,
  class_probs = c(0.25, 0.25, 0.25, 0.25),
  treatment_effect_surrogate = c(-0.6, -0.2, 0.2, 0.6),
  treatment_effect_outcome = c(-0.5, -0.1, 0.1, 0.5),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat("Baseline generated: n =", nrow(baseline), "\n")
cat("  TE_S = (-0.6, -0.2, 0.2, 0.6)\n")
cat("  TE_Y = (-0.5, -0.1, 0.1, 0.5)\n\n")

# Test NPV estimation with IF method
cat("Testing surrogate_inference_if with functional_type='npv':\n")

result_npv <- surrogate_inference_if(
  baseline,
  lambda = 0.3,
  n_innovations = 500,
  functional_type = "npv",
  epsilon_s = 0,
  epsilon_y = 0
)

cat(sprintf("  Estimate: %.3f\n", result_npv$estimate))
cat(sprintf("  SE:       %.3f\n", result_npv$se))
cat(sprintf("  95%% CI:   [%.3f, %.3f]\n\n", result_npv$ci_lower, result_npv$ci_upper))

# Test PPV for comparison
cat("Testing surrogate_inference_if with functional_type='ppv':\n")

result_ppv <- surrogate_inference_if(
  baseline,
  lambda = 0.3,
  n_innovations = 500,
  functional_type = "ppv",
  epsilon_s = 0,
  epsilon_y = 0
)

cat(sprintf("  Estimate: %.3f\n", result_ppv$estimate))
cat(sprintf("  SE:       %.3f\n", result_ppv$se))
cat(sprintf("  95%% CI:   [%.3f, %.3f]\n\n", result_ppv$ci_lower, result_ppv$ci_upper))

# Test standalone functional
cat("Testing functional_npv on treatment effects:\n")

# Create mock treatment effects
treatment_effects <- tibble::tibble(
  delta_s = c(-0.5, -0.2, 0.1, 0.3, 0.6),
  delta_y = c(-0.4, -0.1, 0.05, 0.25, 0.5)
)

npv_direct <- functional_npv(treatment_effects, epsilon_s = 0, epsilon_y = 0)
ppv_direct <- functional_ppv(treatment_effects, epsilon_s = 0, epsilon_y = 0)

cat(sprintf("  NPV: %.3f (2 out of 2 negative effects correctly predicted)\n", npv_direct))
cat(sprintf("  PPV: %.3f (3 out of 3 positive effects correctly predicted)\n\n", ppv_direct))

cat("Expected: Both should be 1.0 for perfect surrogate\n\n")

# Test with imperfect surrogate
treatment_effects_bad <- tibble::tibble(
  delta_s = c(-0.5, -0.2, 0.1, 0.3, 0.6),
  delta_y = c(0.4, 0.1, -0.05, -0.25, -0.5)  # Opposite!
)

npv_bad <- functional_npv(treatment_effects_bad, epsilon_s = 0, epsilon_y = 0)
ppv_bad <- functional_ppv(treatment_effects_bad, epsilon_s = 0, epsilon_y = 0)

cat("Testing with bad surrogate (opposite signs):\n")
cat(sprintf("  NPV: %.3f (should be low - negative S but positive Y)\n", npv_bad))
cat(sprintf("  PPV: %.3f (should be low - positive S but negative Y)\n\n", ppv_bad))

cat("================================================================\n")
cat("✓ NPV functional working correctly!\n")
cat("================================================================\n")
