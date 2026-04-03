#!/usr/bin/env Rscript

#' Test: Percentile CI for PPV/NPV

library(devtools)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)
source("package/R/data_generators_corrected.R")

set.seed(20260323)

cat("================================================================\n")
cat("TEST: Percentile CI for Threshold Functionals\n")
cat("================================================================\n\n")

# Generate baseline
baseline <- generate_study_data_no_mediation(
  n = 1000,
  n_classes = 4,
  class_probs = c(0.25, 0.25, 0.25, 0.25),
  treatment_effect_surrogate = c(-0.6, -0.2, 0.2, 0.6),
  treatment_effect_outcome = c(-0.5, -0.1, 0.1, 0.5),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat("Testing PPV with delta method (should fail at boundaries):\n")
result_delta <- tryCatch({
  surrogate_inference_if(
    baseline,
    lambda = 0.3,
    n_innovations = 1000,
    functional_type = "ppv",
    epsilon_s = 0,
    epsilon_y = 0,
    use_bootstrap = TRUE,
    ci_method = "delta"
  )
}, error = function(e) {
  list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = e$message)
})

cat(sprintf("  Estimate: %.3f\n", result_delta$estimate))
cat(sprintf("  SE: %.3f\n", result_delta$se))
cat(sprintf("  95%% CI: [%.3f, %.3f]\n", result_delta$ci_lower, result_delta$ci_upper))
if (result_delta$se == 0 || is.na(result_delta$se)) {
  cat("  ⚠ Delta method failed (SE = 0 or NA)\n\n")
}

cat("\nTesting PPV with percentile method:\n")
result_percentile <- tryCatch({
  surrogate_inference_if(
    baseline,
    lambda = 0.3,
    n_innovations = 2000,  # More for stable percentiles
    functional_type = "ppv",
    epsilon_s = 0,
    epsilon_y = 0,
    use_bootstrap = TRUE,
    ci_method = "percentile"
  )
}, error = function(e) {
  list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = e$message)
})

cat(sprintf("  Estimate: %.3f\n", result_percentile$estimate))
cat(sprintf("  SE (bootstrap SD): %.3f\n", result_percentile$se))
cat(sprintf("  95%% CI: [%.3f, %.3f]\n", result_percentile$ci_lower, result_percentile$ci_upper))

if (!is.na(result_percentile$se) && result_percentile$se > 0) {
  cat("  ✓ Percentile method succeeded\n\n")

  cat(sprintf("CI width comparison:\n"))
  if (!is.na(result_delta$ci_upper)) {
    cat(sprintf("  Delta method: %.3f\n", result_delta$ci_upper - result_delta$ci_lower))
  } else {
    cat(sprintf("  Delta method: NA\n"))
  }
  cat(sprintf("  Percentile: %.3f\n\n", result_percentile$ci_upper - result_percentile$ci_lower))

  cat("✓✓ Percentile CI implementation working!\n")
} else {
  cat("  ✗ Percentile method also failed\n")
}

cat("\n================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
