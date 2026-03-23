#!/usr/bin/env Rscript

#' Under-Model Validation Study
#'
#' Tests whether the influence function method achieves nominal coverage
#' when the TRUE mechanism generating future studies is EXACTLY the same
#' as what the method assumes: μ = Dirichlet(1,...,1).
#'
#' This is the fundamental validity check before testing robustness.
#'
#' Research Question:
#' When both truth AND method use Dirichlet(1,...,1), does the method
#' provide correct 95% coverage?

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

# Load package
devtools::load_all("package/", quiet = TRUE)

# Set parameters
set.seed(20260323)

N_BASELINE <- 1000        # Baseline study sample size
N_REPLICATIONS <- 1000    # Number of replications (for reliable coverage)
N_TRUE_STUDIES <- 5000    # Studies for computing TRUE φ(F_λ) (large for accuracy)
N_INNOVATIONS <- 1000     # Innovations for method (M)
CONFIDENCE_LEVEL <- 0.95

cat("================================================================\n")
cat("UNDER-MODEL VALIDATION STUDY\n")
cat("================================================================\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat(sprintf("  Studies for TRUE φ(F_λ): %d\n", N_TRUE_STUDIES))
cat(sprintf("  Innovations (M) for method: %d\n", N_INNOVATIONS))
cat(sprintf("  Confidence level: %.2f\n", CONFIDENCE_LEVEL))

cat("\n")
cat("Research Design:\n")
cat("  1. Generate baseline study\n")
cat("  2. Compute TRUE φ(F_λ) by generating many Q ~ F_λ studies\n")
cat("     where Q = (1-λ)P̂ + λP̃, P̃ ~ Dirichlet(1,...,1)\n")
cat("  3. Apply METHOD with same μ = Dirichlet(1,...,1)\n")
cat("  4. Check if method CI contains TRUE φ(F_λ)\n")
cat("  5. Compute coverage rate across replications\n\n")

# Test multiple lambda values
lambda_scenarios <- list(
  small = list(name = "Small λ=0.1", lambda = 0.1),
  moderate = list(name = "Moderate λ=0.3", lambda = 0.3),
  large = list(name = "Large λ=0.5", lambda = 0.5)
)

# Storage for results
validation_results <- tibble::tibble(
  scenario = character(),
  replication = integer(),
  lambda = numeric(),
  true_correlation = numeric(),
  method_estimate = numeric(),
  method_se = numeric(),
  method_ci_lower = numeric(),
  method_ci_upper = numeric(),
  ci_width = numeric(),
  covered = logical()
)

cat("----------------------------------------------------------------\n")
cat("Running Validation Study\n")
cat("----------------------------------------------------------------\n\n")

# Track timing
start_time <- Sys.time()
cat(sprintf("Start time: %s\n\n", start_time))

for (scenario_name in names(lambda_scenarios)) {
  scenario <- lambda_scenarios[[scenario_name]]

  cat(sprintf("Scenario: %s\n", scenario$name))

  for (rep in 1:N_REPLICATIONS) {

    if (rep %% 100 == 0 || rep == 1) {
      elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
      rate <- elapsed / ((which(names(lambda_scenarios) == scenario_name) - 1) * N_REPLICATIONS + rep)
      remaining <- rate * (length(lambda_scenarios) * N_REPLICATIONS -
                          ((which(names(lambda_scenarios) == scenario_name) - 1) * N_REPLICATIONS + rep))
      cat(sprintf("  Replication %d/%d (%.2f min elapsed, %.3f min/rep, ~%.1f min remaining)\n",
                  rep, N_REPLICATIONS, elapsed, rate, remaining))
    }

    # Step 1: Generate baseline study
    baseline <- generate_study_data(
      n = N_BASELINE,
      treatment_effect_surrogate = c(0.3, 0.9),
      treatment_effect_outcome = c(0.2, 0.8),
      surrogate_type = "continuous",
      outcome_type = "continuous"
    )

    # Step 2: Compute TRUE φ(F_λ) using many Dirichlet innovations
    # This is the "oracle" - what φ(F_λ) actually equals under the model

    # Generate large number of future studies using Dirichlet innovations
    true_studies <- generate_future_study(
      baseline,
      lambda = scenario$lambda,
      n_future_studies = N_TRUE_STUDIES,
      alpha = 1  # Dirichlet(1,...,1) - same as method assumes
    )

    # Compute treatment effects in each future study
    delta_s_vec <- true_studies$treatment_effects[, "delta_s"]
    delta_y_vec <- true_studies$treatment_effects[, "delta_y"]

    # True correlation under F_λ (empirical from large sample)
    true_correlation <- cor(delta_s_vec, delta_y_vec)

    # Step 3: Apply METHOD with same assumptions
    method_result <- tryCatch({
      surrogate_inference_if(
        baseline,
        lambda = scenario$lambda,
        n_innovations = N_INNOVATIONS,
        functional_type = "correlation"
      )
    }, error = function(e) {
      warning(sprintf("Error in replication %d: %s", rep, e$message))
      return(NULL)
    })

    if (is.null(method_result)) next

    # Step 4: Check coverage
    covered <- (true_correlation >= method_result$ci_lower) &&
               (true_correlation <= method_result$ci_upper)

    # Store results
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
      ci_width = method_result$ci_upper - method_result$ci_lower,
      covered = covered
    ))

    # Save interim results every 100 reps
    if (rep %% 100 == 0) {
      if (!dir.exists("sims/results")) {
        dir.create("sims/results", recursive = TRUE)
      }
      safe_name <- gsub("[^a-zA-Z0-9_]", "_", tolower(scenario$name))
      saveRDS(validation_results,
              sprintf("sims/results/under_model_interim_%s_rep%04d.rds",
                      safe_name, rep))
    }
  }

  cat("\n")
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

# Compute coverage rates by scenario
coverage_summary <- validation_results %>%
  group_by(scenario, lambda) %>%
  summarise(
    n_reps = n(),
    coverage_rate = mean(covered, na.rm = TRUE),
    mean_true_correlation = mean(true_correlation, na.rm = TRUE),
    mean_method_estimate = mean(method_estimate, na.rm = TRUE),
    mean_bias = mean(method_estimate - true_correlation, na.rm = TRUE),
    mean_se = mean(method_se, na.rm = TRUE),
    sd_estimate = sd(method_estimate, na.rm = TRUE),
    se_sd_ratio = mean(method_se) / sd(method_estimate, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    .groups = "drop"
  )

cat("Coverage Rates by Lambda:\n\n")
cat(sprintf("%-20s %-6s %-10s %-10s %-10s %-10s %-10s\n",
            "Scenario", "λ", "Coverage", "Bias", "SE/SD", "CI Width", "Status"))
cat(strrep("-", 80), "\n")

for (i in 1:nrow(coverage_summary)) {
  row <- coverage_summary[i, ]
  status <- if (row$coverage_rate >= CONFIDENCE_LEVEL - 0.02) {
    "✓"
  } else if (row$coverage_rate >= CONFIDENCE_LEVEL - 0.05) {
    "~"
  } else {
    "✗"
  }

  cat(sprintf("%-20s %-6.2f %-10.3f %-10.4f %-10.2f %-10.3f %-10s\n",
              row$scenario,
              row$lambda,
              row$coverage_rate,
              row$mean_bias,
              row$se_sd_ratio,
              row$mean_ci_width,
              status))
}

cat("\n")
cat("Target Coverage: ", CONFIDENCE_LEVEL, "\n")
cat("✓ = within 2pp of target; ~ = within 5pp; ✗ = more than 5pp off\n\n")

# Assess overall validity
overall_coverage <- mean(validation_results$covered, na.rm = TRUE)
overall_bias <- mean(validation_results$method_estimate -
                     validation_results$true_correlation, na.rm = TRUE)

cat(sprintf("Overall Coverage: %.3f (%.1f%%)\n",
            overall_coverage, overall_coverage * 100))
cat(sprintf("Overall Bias: %.4f\n", overall_bias))

cat("\nInterpretation:\n")
if (overall_coverage >= CONFIDENCE_LEVEL - 0.02) {
  cat("✓ EXCELLENT: Coverage meets nominal level\n")
} else if (overall_coverage >= CONFIDENCE_LEVEL - 0.05) {
  cat("✓ ACCEPTABLE: Coverage within reasonable range\n")
} else {
  cat("⚠ CONCERNING: Coverage below acceptable range\n")
}

if (abs(overall_bias) < 0.01) {
  cat("✓ UNBIASED: Estimates centered on truth\n")
} else {
  cat("⚠ BIASED: Systematic error detected\n")
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Creating Visualizations\n")
cat("----------------------------------------------------------------\n\n")

# Ensure results directory exists
if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}

# Plot 1: Coverage rate by lambda
p1 <- ggplot(coverage_summary, aes(x = lambda, y = coverage_rate)) +
  geom_point(size = 3) +
  geom_line() +
  geom_hline(yintercept = CONFIDENCE_LEVEL, linetype = "dashed", color = "red") +
  geom_hline(yintercept = CONFIDENCE_LEVEL - 0.02,
             linetype = "dotted", color = "orange") +
  geom_hline(yintercept = CONFIDENCE_LEVEL + 0.02,
             linetype = "dotted", color = "orange") +
  ylim(0.88, 1.0) +
  labs(
    title = "Coverage Rate vs. Lambda (Under Model)",
    subtitle = sprintf("N=%d replications per scenario; Truth and Method both use μ = Dirichlet(1,...,1)",
                       N_REPLICATIONS),
    x = "Lambda (perturbation distance)",
    y = "Coverage Rate",
    caption = "Red line: nominal 95%; Orange lines: ±2pp acceptable range"
  ) +
  theme_minimal(base_size = 12)

ggsave("sims/results/under_model_coverage.png", p1,
       width = 8, height = 6, dpi = 300)

cat("  Saved: sims/results/under_model_coverage.png\n")

# Plot 2: True correlation vs. Method estimate
p2 <- ggplot(validation_results,
             aes(x = true_correlation, y = method_estimate)) +
  geom_point(alpha = 0.3, aes(color = scenario)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  facet_wrap(~scenario) +
  labs(
    title = "True φ(F_λ) vs. Method Estimate",
    subtitle = "Points should cluster tightly around diagonal",
    x = "True Correlation (from 5000 Dirichlet innovations)",
    y = "Method Estimate (from 1000 innovations)"
  ) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "none")

ggsave("sims/results/under_model_calibration.png", p2,
       width = 10, height = 8, dpi = 300)

cat("  Saved: sims/results/under_model_calibration.png\n")

# Plot 3: CI coverage visualization (sample)
validation_results_plot <- validation_results %>%
  arrange(scenario, true_correlation) %>%
  group_by(scenario) %>%
  mutate(obs_id = row_number()) %>%
  ungroup() %>%
  slice_sample(n = min(300, n()))

p3 <- ggplot(validation_results_plot,
             aes(x = obs_id, y = method_estimate)) +
  geom_pointrange(aes(ymin = method_ci_lower, ymax = method_ci_upper,
                      color = covered),
                  alpha = 0.6, size = 0.3) +
  geom_point(aes(y = true_correlation), color = "black", size = 1) +
  facet_wrap(~scenario, scales = "free_x") +
  scale_color_manual(values = c("TRUE" = "blue", "FALSE" = "red"),
                     labels = c("TRUE" = "Covered", "FALSE" = "Missed")) +
  labs(
    title = "Confidence Interval Coverage (Under Model)",
    subtitle = "Black dots: true φ(F_λ); Blue/Red: CIs that cover/miss",
    x = "Replication (sample)",
    y = "Correlation",
    color = "Coverage"
  ) +
  theme_minimal(base_size = 10)

ggsave("sims/results/under_model_ci_coverage.png", p3,
       width = 12, height = 8, dpi = 300)

cat("  Saved: sims/results/under_model_ci_coverage.png\n")

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Saving Results\n")
cat("----------------------------------------------------------------\n\n")

# Save detailed results
saveRDS(validation_results, "sims/results/under_model_validation_detailed.rds")
cat("  Saved: sims/results/under_model_validation_detailed.rds\n")

saveRDS(coverage_summary, "sims/results/under_model_validation_summary.rds")
cat("  Saved: sims/results/under_model_validation_summary.rds\n")

# Save as CSV
write.csv(coverage_summary,
          "sims/results/under_model_validation_summary.csv",
          row.names = FALSE)
cat("  Saved: sims/results/under_model_validation_summary.csv\n")

cat("\n")
cat("================================================================\n")
cat("INTERPRETATION FOR PAPER\n")
cat("================================================================\n\n")

cat("Key Findings:\n\n")

cat("1. Fundamental Validity:\n")
for (i in 1:nrow(coverage_summary)) {
  row <- coverage_summary[i, ]
  status <- if (row$coverage_rate >= CONFIDENCE_LEVEL - 0.02) {
    "✓ Valid"
  } else if (row$coverage_rate >= CONFIDENCE_LEVEL - 0.05) {
    "~ Acceptable"
  } else {
    "✗ Problem"
  }
  cat(sprintf("   %s: %.1f%% coverage %s\n",
              row$scenario, row$coverage_rate * 100, status))
}

cat("\n2. Calibration:\n")
cat(sprintf("   Overall bias: %.4f (%.2f%% relative)\n",
            overall_bias,
            overall_bias / mean(validation_results$true_correlation) * 100))
cat(sprintf("   SE/SD ratio: %.2f (1.0 = perfectly calibrated)\n",
            mean(coverage_summary$se_sd_ratio)))

cat("\n3. Paper Claims:\n")
if (overall_coverage >= CONFIDENCE_LEVEL - 0.02) {
  cat("   ✓ Method achieves nominal 95% coverage under its assumptions\n")
  cat("   ✓ Inference procedure (Proposition 1) is correctly implemented\n")
  cat("   ✓ Ready to test robustness to model misspecification\n")
} else {
  cat("   ⚠ Coverage deviates from nominal level\n")
  cat("   → Check: Is M large enough? Is n large enough?\n")
  cat("   → This is under-model validation; method should be valid here\n")
}

cat("\n4. Recommendation:\n")
if (overall_coverage >= CONFIDENCE_LEVEL - 0.02) {
  cat("   Add to Section 5 (Simulation Studies):\n")
  cat("   'To validate the inference procedure, we first verified\n")
  cat("    that the method achieves nominal coverage when its\n")
  cat("    assumptions hold exactly (μ = Dirichlet(1,...,1)).\n")
  cat(sprintf("    Across λ ∈ [%.1f, %.1f] and %d replications,\n",
              min(coverage_summary$lambda),
              max(coverage_summary$lambda),
              N_REPLICATIONS))
  cat(sprintf("    the method provided %.1f%% coverage (target: 95%%).\n",
              overall_coverage * 100))
  cat("    This confirms correct implementation of Proposition 1.'\n")
} else {
  cat("   ⚠ Investigate coverage shortfall before proceeding\n")
}

cat("\n")
cat("================================================================\n")
cat("Under-model validation complete!\n")
cat("================================================================\n")
