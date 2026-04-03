#!/usr/bin/env Rscript

#' Quick Test: PPV Functional Validation (10 replications)
#'
#' This is a minimal test to verify script 18 works correctly

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

# Ensure we're in project root
while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

if (!dir.exists("package")) {
  stop("Cannot find package/ directory. Please run from project root or sims/scripts/")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

# REDUCED Parameters for quick test
N_BASELINE <- 500  # Reduced from 1000
N_REPLICATIONS <- 10  # REDUCED for quick test
N_TRUE_STUDIES <- 500  # Reduced from 2000
N_INNOVATIONS <- 500  # Reduced from 1000
CONFIDENCE_LEVEL <- 0.95

# Test only 2 scenarios (not all 3)
scenarios <- list(
  moderate = list(name = "Moderate λ=0.3", lambda = 0.3)
)

# Test only 2 threshold scenarios (not all 4)
threshold_scenarios <- list(
  zero = list(name = "Zero thresholds", epsilon_s = 0, epsilon_y = 0),
  moderate = list(name = "Moderate thresholds", epsilon_s = 0.1, epsilon_y = 0.1)
)

cat("================================================================\n")
cat("QUICK TEST: PPV FUNCTIONAL VALIDATION (10 REPS)\n")
cat("================================================================\n\n")

cat("Parameters (REDUCED for quick test):\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat(sprintf("  Studies for TRUE φ(F_λ): %d\n", N_TRUE_STUDIES))
cat(sprintf("  Innovations (M) for method: %d\n", N_INNOVATIONS))
cat(sprintf("  Scenarios: %d (reduced from 3)\n", length(scenarios)))
cat(sprintf("  Thresholds: %d (reduced from 4)\n", length(threshold_scenarios)))

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Running Quick Validation\n")
cat("----------------------------------------------------------------\n\n")

start_time <- Sys.time()

validation_results <- tibble::tibble(
  scenario = character(),
  threshold_scenario = character(),
  replication = integer(),
  lambda = numeric(),
  epsilon_s = numeric(),
  epsilon_y = numeric(),
  true_ppv = numeric(),
  method_estimate = numeric(),
  method_se = numeric(),
  method_ci_lower = numeric(),
  method_ci_upper = numeric(),
  ci_width = numeric(),
  covered = logical()
)

total_iterations <- length(scenarios) * length(threshold_scenarios) * N_REPLICATIONS
iteration <- 0

for (scenario_name in names(scenarios)) {
  scenario <- scenarios[[scenario_name]]

  for (thresh_name in names(threshold_scenarios)) {
    thresh <- threshold_scenarios[[thresh_name]]

    cat(sprintf("Scenario: %s, Thresholds: %s\n", scenario$name, thresh$name))

    for (rep in 1:N_REPLICATIONS) {
      iteration <- iteration + 1

      cat(sprintf("  Replication %d/%d\n", rep, N_REPLICATIONS))

      # Step 1: Generate baseline study
      baseline <- generate_study_data(
        n = N_BASELINE,
        treatment_effect_surrogate = c(0.3, 0.9),
        treatment_effect_outcome = c(0.2, 0.8),
        surrogate_type = "continuous",
        outcome_type = "continuous"
      )

      # Step 2: Compute TRUE φ_PPV(F_λ) using reweighting
      n <- nrow(baseline)

      # Draw M Dirichlet innovations
      innovations <- MCMCpack::rdirichlet(N_TRUE_STUDIES, rep(1, n))

      # For each innovation, compute treatment effects via reweighting
      true_effects <- matrix(NA, nrow = N_TRUE_STUDIES, ncol = 2)

      for (m in 1:N_TRUE_STUDIES) {
        # Current study weights (uniform empirical)
        p0_weights <- rep(1/n, n)

        # Innovation weights
        p_tilde <- innovations[m, ]

        # Mixture: Q_m = (1-λ)P₀ + λP̃
        q_weights <- (1 - scenario$lambda) * p0_weights + scenario$lambda * p_tilde

        # Treatment effects via reweighting
        delta_s <- compute_treatment_effect_weighted(baseline, "S", q_weights)
        delta_y <- compute_treatment_effect_weighted(baseline, "Y", q_weights)

        true_effects[m, ] <- c(delta_s, delta_y)
      }

      # TRUE PPV: P(ΔY > ε_Y | ΔS > ε_S)
      exceed_s <- true_effects[, 1] > thresh$epsilon_s

      if (sum(exceed_s) == 0) {
        cat("    Warning: No studies with delta_s > epsilon_s; skipping\n")
        next
      }

      true_ppv <- sum(true_effects[, 1] > thresh$epsilon_s &
                      true_effects[, 2] > thresh$epsilon_y) / sum(exceed_s)

      # Step 3: Apply METHOD with threshold-based PPV
      method_result <- tryCatch({
        surrogate_inference_if(
          baseline,
          lambda = scenario$lambda,
          n_innovations = N_INNOVATIONS,
          functional_type = "ppv",
          epsilon_s = thresh$epsilon_s,
          epsilon_y = thresh$epsilon_y
        )
      }, error = function(e) {
        cat(sprintf("    Error: %s\n", e$message))
        return(NULL)
      })

      if (is.null(method_result)) next

      # Step 4: Check coverage
      covered <- (true_ppv >= method_result$ci_lower) &&
                 (true_ppv <= method_result$ci_upper)

      cat(sprintf("    True PPV: %.3f, Estimate: %.3f [%.3f, %.3f], Covered: %s\n",
                  true_ppv, method_result$estimate,
                  method_result$ci_lower, method_result$ci_upper,
                  ifelse(covered, "YES", "NO")))

      # Store results (capture values as variables to avoid scoping issues)
      scenario_name_val <- scenario$name
      threshold_name_val <- thresh$name
      lambda_val <- scenario$lambda
      epsilon_s_val <- thresh$epsilon_s
      epsilon_y_val <- thresh$epsilon_y

      validation_results <- rbind(validation_results, tibble::tibble(
        scenario = scenario_name_val,
        threshold_scenario = threshold_name_val,
        replication = rep,
        lambda = lambda_val,
        epsilon_s = epsilon_s_val,
        epsilon_y = epsilon_y_val,
        true_ppv = true_ppv,
        method_estimate = method_result$estimate,
        method_se = method_result$se,
        method_ci_lower = method_result$ci_lower,
        method_ci_upper = method_result$ci_upper,
        ci_width = method_result$ci_upper - method_result$ci_lower,
        covered = covered
      ))
    }
    cat("\n")
  }
}

elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))

cat("================================================================\n")
cat("QUICK TEST RESULTS\n")
cat("================================================================\n\n")

cat(sprintf("Total time: %.2f minutes\n\n", elapsed))

# Compute coverage rates
coverage_summary <- validation_results %>%
  group_by(scenario, threshold_scenario, lambda, epsilon_s, epsilon_y) %>%
  summarise(
    n_reps = n(),
    coverage_rate = mean(covered, na.rm = TRUE),
    mean_true_ppv = mean(true_ppv, na.rm = TRUE),
    mean_method_estimate = mean(method_estimate, na.rm = TRUE),
    mean_bias = mean(method_estimate - true_ppv, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    .groups = "drop"
  )

cat("Coverage Summary:\n\n")
print(coverage_summary, n = 100)

cat("\n")
cat("Overall Statistics:\n")
cat(sprintf("  Overall Coverage: %.1f%% (%d/%d)\n",
            mean(validation_results$covered) * 100,
            sum(validation_results$covered),
            nrow(validation_results)))
cat(sprintf("  Overall Bias: %.4f\n",
            mean(validation_results$method_estimate - validation_results$true_ppv)))
cat(sprintf("  Mean CI Width: %.3f\n",
            mean(validation_results$ci_width)))

cat("\n")
cat("Interpretation:\n")
overall_coverage <- mean(validation_results$covered)
if (overall_coverage >= 0.85) {
  cat("✓ Quick test PASSED: Coverage reasonable for 10 reps\n")
  cat("  → Script appears to be working correctly\n")
  cat("  → Ready for full 1000-rep validation\n")
} else {
  cat("⚠ Quick test shows lower coverage\n")
  cat("  → May need investigation\n")
  cat(sprintf("  → Coverage: %.1f%% (10 reps, so high variance expected)\n",
              overall_coverage * 100))
}

cat("\n")
cat("================================================================\n")
cat("Quick test complete!\n")
cat("================================================================\n")
