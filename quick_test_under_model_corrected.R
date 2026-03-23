#!/usr/bin/env Rscript
#' Corrected under-model validation
#'
#' Key fix: Both truth and method use REWEIGHTING, not resampling
#' We're measuring correlation of treatment effects across population mixtures,
#' net of sampling variability

library(devtools)
library(dplyr)
library(tibble)

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

N_BASELINE <- 1000
N_REPLICATIONS <- 50
N_INNOVATIONS <- 2000  # For computing true correlation
CONFIDENCE_LEVEL <- 0.95

cat("================================================================\n")
cat("CORRECTED UNDER-MODEL VALIDATION (50 reps)\n")
cat("================================================================\n\n")

cat("Key: Both truth AND method use REWEIGHTING (not resampling)\n")
cat("     Measuring correlation net of sampling variability\n\n")

lambda_scenarios <- list(
  moderate = list(name = "Moderate λ=0.3", lambda = 0.3),
  large = list(name = "Large λ=0.5", lambda = 0.5)
)

validation_results <- tibble::tibble(
  scenario = character(),
  replication = integer(),
  lambda = numeric(),
  true_correlation = numeric(),
  method_estimate = numeric(),
  method_se = numeric(),
  method_ci_lower = numeric(),
  method_ci_upper = numeric(),
  covered = logical()
)

start_time <- Sys.time()

for (scenario_name in names(lambda_scenarios)) {
  scenario <- lambda_scenarios[[scenario_name]]
  cat(sprintf("Scenario: %s\n", scenario$name))

  for (rep in 1:N_REPLICATIONS) {
    if (rep %% 10 == 0 || rep == 1) {
      cat(sprintf("  Rep %d/%d\n", rep, N_REPLICATIONS))
    }

    baseline <- generate_study_data(
      n = N_BASELINE,
      treatment_effect_surrogate = c(0.3, 0.9),
      treatment_effect_outcome = c(0.2, 0.8)
    )

    n <- nrow(baseline)

    # ============================================================
    # TRUTH: Compute φ(F_λ) via reweighting (NOT resampling)
    # ============================================================

    # Draw M Dirichlet innovations
    innovations <- MCMCpack::rdirichlet(N_INNOVATIONS, rep(1, n))

    # For each innovation, compute treatment effects via reweighting
    true_effects <- matrix(NA, nrow = N_INNOVATIONS, ncol = 2)

    for (m in 1:N_INNOVATIONS) {
      # Current study weights (uniform empirical)
      p0_weights <- rep(1/n, n)

      # Innovation weights
      p_tilde <- innovations[m, ]

      # Mixture: Q_m = (1-λ)P₀ + λP̃
      q_weights <- (1 - scenario$lambda) * p0_weights + scenario$lambda * p_tilde

      # Treatment effects via reweighting (same data, different weights)
      delta_s <- compute_treatment_effect_weighted(baseline, "S", q_weights)
      delta_y <- compute_treatment_effect_weighted(baseline, "Y", q_weights)

      true_effects[m, ] <- c(delta_s, delta_y)
    }

    # TRUE correlation (across population mixtures, net of sampling variability)
    true_correlation <- cor(true_effects[, 1], true_effects[, 2])

    # ============================================================
    # METHOD: Same approach (already correct!)
    # ============================================================

    method_result <- tryCatch({
      surrogate_inference_if(
        baseline,
        lambda = scenario$lambda,
        n_innovations = 1000,  # M for method
        functional_type = "correlation"
      )
    }, error = function(e) {
      warning(sprintf("Error: %s", e$message))
      return(NULL)
    })

    if (is.null(method_result)) next

    covered <- (true_correlation >= method_result$ci_lower) &&
               (true_correlation <= method_result$ci_upper)

    scenario_name_val <- scenario$name
    lambda_val <- scenario$lambda

    validation_results <- rbind(validation_results, tibble::tibble(
      scenario = scenario_name_val,
      replication = rep,
      lambda = lambda_val,
      true_correlation = true_correlation,
      method_estimate = method_result$estimate,
      method_se = method_result$se,
      method_ci_lower = method_result$ci_lower,
      method_ci_upper = method_result$ci_upper,
      covered = covered
    ))
  }
  cat("\n")
}

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

coverage_summary <- validation_results %>%
  group_by(scenario, lambda) %>%
  summarise(
    n_reps = n(),
    coverage_rate = mean(covered, na.rm = TRUE),
    mean_true = mean(true_correlation, na.rm = TRUE),
    mean_estimate = mean(method_estimate, na.rm = TRUE),
    mean_bias = mean(method_estimate - true_correlation, na.rm = TRUE),
    mean_se = mean(method_se, na.rm = TRUE),
    sd_estimate = sd(method_estimate, na.rm = TRUE),
    .groups = "drop"
  )

cat("Coverage Rates:\n\n")
for (i in 1:nrow(coverage_summary)) {
  row <- coverage_summary[i, ]
  cat(sprintf("%-20s\n", row$scenario))
  cat(sprintf("  Coverage: %.1f%% (%d/%d)\n",
              row$coverage_rate * 100,
              round(row$coverage_rate * row$n_reps),
              row$n_reps))
  cat(sprintf("  Mean true: %.4f, Mean estimate: %.4f\n",
              row$mean_true, row$mean_estimate))
  cat(sprintf("  Bias: %.4f, SE/SD ratio: %.2f\n\n",
              row$mean_bias, row$mean_se / row$sd_estimate))
}

overall_coverage <- mean(validation_results$covered, na.rm = TRUE)
overall_bias <- mean(validation_results$method_estimate -
                     validation_results$true_correlation, na.rm = TRUE)

cat(sprintf("Overall Coverage: %.1f%%\n", overall_coverage * 100))
cat(sprintf("Overall Bias: %.4f\n", overall_bias))
cat(sprintf("Target: %.0f%%\n", CONFIDENCE_LEVEL * 100))

if (overall_coverage >= CONFIDENCE_LEVEL - 0.05) {
  cat("✓ ACCEPTABLE (within 5pp of target)\n")
} else {
  cat("⚠ Below target\n")
}

cat(sprintf("\nElapsed time: %.1f seconds\n", elapsed))
cat(sprintf("Time per replication: %.2f seconds\n",
            elapsed / nrow(validation_results)))

cat("\n=== INTERPRETATION ===\n\n")

if (overall_coverage >= CONFIDENCE_LEVEL - 0.05 && abs(overall_bias) < 0.05) {
  cat("✓ Method achieves nominal coverage under its assumptions!\n")
  cat("  This validates the influence function implementation.\n")
  cat("  Ready to test robustness to model misspecification.\n")
} else if (overall_coverage < CONFIDENCE_LEVEL - 0.05) {
  cat("⚠ Coverage below target - investigate:\n")
  cat("  - Is M large enough? (currently ", N_INNOVATIONS, " for truth)\n")
  cat("  - Is epsilon appropriate? (currently 0.01)\n")
  cat("  - Is SE estimation correct?\n")
} else if (abs(overall_bias) >= 0.05) {
  cat("⚠ Bias detected - investigate point estimate calculation\n")
}

cat("\n✓ Corrected test complete!\n")
cat("\nTo run full validation (1000 reps):\n")
cat("  Rscript sims/scripts/07_under_model_validation.R\n")
cat("  (Estimated: 20-30 minutes with corrected approach)\n\n")
