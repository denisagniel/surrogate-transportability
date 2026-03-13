#!/usr/bin/env Rscript
#' Examples: Structured Shift DGPs for Simulation Validation
#'
#' This script demonstrates how to use the new covariate shift and selection
#' mechanism DGPs to test whether the innovation approach (which assumes
#' μ = Dirichlet(1,...,1)) provides valid inference when the true mechanism
#' generating future studies is structured rather than uniform.

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

# Load package
devtools::load_all("package/")

set.seed(42)

cat("==================================================\n")
cat("Example 1: Covariate Shift Validation\n")
cat("==================================================\n\n")

# Generate baseline study with balanced classes
baseline <- generate_study_data(
  n = 500,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat("Baseline study class distribution:\n")
print(table(baseline$class) / nrow(baseline))

# Generate future studies with varying covariate shifts
shift_scenarios <- list(
  moderate_to_class1 = c(0.6, 0.4),
  strong_to_class1 = c(0.7, 0.3),
  extreme_to_class1 = c(0.8, 0.2),
  moderate_to_class2 = c(0.4, 0.6),
  strong_to_class2 = c(0.3, 0.7)
)

cat("\nGenerating covariate-shifted future studies:\n")
shifted_studies <- list()

for (scenario_name in names(shift_scenarios)) {
  target_probs <- shift_scenarios[[scenario_name]]

  shifted <- generate_covariate_shift_study(
    baseline,
    target_class_probs = target_probs,
    n = 500
  )

  shifted_studies[[scenario_name]] <- shifted

  cat(sprintf("  %s: TV distance = %.3f, shift magnitude = %.3f\n",
              scenario_name, shifted$tv_distance, shifted$shift_magnitude))
}

# For each shifted study, compute TRUE correlation of treatment effects
cat("\nComputing true correlations in shifted studies:\n")
true_correlations <- sapply(shifted_studies, function(study) {
  effects <- compute_multiple_treatment_effects(study$future_study, c("S", "Y"))
  # Would need multiple instances to compute correlation properly
  # This is a placeholder - in real simulation, generate many shifted studies
  NA  # Placeholder
})

cat("  (Note: In real simulation, generate many studies per shift scenario)\n")

cat("\n==================================================\n")
cat("Example 2: Selection Mechanism Validation\n")
cat("==================================================\n\n")

# Generate baseline with heterogeneous outcomes
baseline2 <- generate_study_data(
  n = 500,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.4, 0.8),
  treatment_effect_outcome = c(0.1, 0.9),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat("Baseline study summary:\n")
cat(sprintf("  Mean Y: %.3f\n", mean(baseline2$Y)))
cat(sprintf("  Mean S: %.3f\n", mean(baseline2$S)))

# Generate future studies with different selection mechanisms
selection_scenarios <- list(
  weak_outcome_favorable = list(type = "outcome_favorable", strength = 0.3),
  moderate_outcome_favorable = list(type = "outcome_favorable", strength = 0.6),
  strong_treatment_responders = list(type = "treatment_responders", strength = 0.8),
  moderate_covariate_extreme = list(type = "covariate_extreme", strength = 0.5)
)

cat("\nGenerating selection-biased future studies:\n")
selected_studies <- list()

for (scenario_name in names(selection_scenarios)) {
  scenario <- selection_scenarios[[scenario_name]]

  selected <- generate_selection_study(
    baseline2,
    selection_type = scenario$type,
    selection_strength = scenario$strength,
    n = 500
  )

  selected_studies[[scenario_name]] <- selected

  cat(sprintf("  %s:\n", scenario_name))
  cat(sprintf("    TV distance (est): %.3f\n", selected$tv_distance_estimate))
  cat(sprintf("    Effective sample size: %.1f\n", selected$effective_sample_size))
  cat(sprintf("    Future Mean Y: %.3f (baseline: %.3f)\n",
              mean(selected$future_study$Y), mean(baseline2$Y)))
}

cat("\n==================================================\n")
cat("Example 3: TV Distance Computation\n")
cat("==================================================\n\n")

# Compare TV distances between different scenarios
study1 <- generate_study_data(
  n = 500,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  seed = 100
)

study2_moderate <- generate_study_data(
  n = 500,
  class_probs = c(0.6, 0.4),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  seed = 101
)

study3_strong <- generate_study_data(
  n = 500,
  class_probs = c(0.7, 0.3),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  seed = 102
)

tv_moderate <- tv_distance_empirical(study1, study2_moderate)
tv_strong <- tv_distance_empirical(study1, study3_strong)

cat("TV distances from baseline:\n")
cat(sprintf("  Moderate shift (0.6, 0.4): %.3f\n", tv_moderate))
cat(sprintf("  Strong shift (0.7, 0.3): %.3f\n", tv_strong))

cat("\n==================================================\n")
cat("Key Insights for Paper\n")
cat("==================================================\n\n")

cat("These DGPs allow us to test:\n\n")
cat("1. Covariate Shift Robustness:\n")
cat("   - Generate 'true' future studies via covariate shift\n")
cat("   - Compare true φ(Q) to method's φ(F_λ) under Dirichlet(1,...,1)\n")
cat("   - Check if confidence intervals have correct coverage\n")
cat("   - Claim: 'Method is robust to covariate shifts up to λ = X'\n\n")

cat("2. Selection Bias Robustness:\n")
cat("   - Generate 'true' futures via selection mechanisms\n")
cat("   - Test if uniform Dirichlet still provides valid inference\n")
cat("   - Quantify effective sample size impact\n")
cat("   - Claim: 'Method handles selection bias with ESS > Y'\n\n")

cat("3. Characterization of Generalization Space:\n")
cat("   - Map structured shifts to TV distances\n")
cat("   - Relate λ to substantive population differences\n")
cat("   - Example: 'λ = 0.2 accommodates class proportion changes of ±15%'\n\n")

cat("4. Comparison to Dirichlet Assumption:\n")
cat("   - When truth = covariate shift, is Dirichlet conservative?\n")
cat("   - When truth = selection, where does Dirichlet fail?\n")
cat("   - Sensitivity analysis: vary μ parameters\n\n")

cat("Done! Next steps:\n")
cat("  1. Create simulation scripts in sims/scripts/\n")
cat("  2. Run structured shift validation studies\n")
cat("  3. Add results to paper Section 5\n")
cat("  4. Extend theory to characterize robustness conditions\n")
