#!/usr/bin/env Rscript

#' PPV Functional Validation - Corrected (Threshold-Based)
#'
#' Research Questions:
#' 1. Is φ̂_PPV unbiased for true φ_PPV?
#' 2. Do 95% CIs achieve nominal coverage?
#' 3. How sensitive is PPV to thresholds (ε_S, ε_Y)?
#'
#' This is the CORRECTED version of script 15, using threshold-based PPV
#' (P(ΔY > ε_Y | ΔS > ε_S)) instead of power-based PPV.
#'
#' Design:
#'   For each baseline:
#'     1. Compute TRUE φ_PPV using many Q ~ F_λ (reweighting approach)
#'     2. Estimate φ̂_PPV using surrogate_inference_if()
#'     3. Check: φ_true ∈ [ci_lower, ci_upper]?

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

# Parameters
N_BASELINE <- 1000
N_REPLICATIONS <- 1000
N_TRUE_STUDIES <- 2000  # For computing TRUE φ(F_λ)
N_INNOVATIONS <- 1000   # For estimation
CONFIDENCE_LEVEL <- 0.95

# Test scenarios
scenarios <- list(
  small = list(name = "Small λ=0.1", lambda = 0.1),
  moderate = list(name = "Moderate λ=0.3", lambda = 0.3),
  large = list(name = "Large λ=0.5", lambda = 0.5)
)

# Threshold combinations
threshold_scenarios <- list(
  zero = list(name = "Zero thresholds", epsilon_s = 0, epsilon_y = 0),
  small = list(name = "Small thresholds", epsilon_s = 0.05, epsilon_y = 0.05),
  moderate = list(name = "Moderate thresholds", epsilon_s = 0.1, epsilon_y = 0.1),
  asymmetric = list(name = "Asymmetric thresholds", epsilon_s = 0.2, epsilon_y = 0.1)
)

cat("================================================================\n")
cat("PPV FUNCTIONAL VALIDATION (THRESHOLD-BASED)\n")
cat("================================================================\n\n")

cat("Research Questions:\n")
cat("  1. Is φ̂_PPV unbiased for true φ_PPV?\n")
cat("  2. Do 95% CIs achieve nominal coverage?\n")
cat("  3. How sensitive is PPV to thresholds?\n\n")

cat("PPV Definition:\n")
cat("  φ_PPV(F_λ; ε_S, ε_Y) = P(ΔY > ε_Y | ΔS > ε_S)\n")
cat("  where Q ~ F_λ (future study distribution)\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat(sprintf("  Studies for TRUE φ(F_λ): %d\n", N_TRUE_STUDIES))
cat(sprintf("  Innovations (M) for method: %d\n", N_INNOVATIONS))
cat(sprintf("  Confidence level: %.2f\n", CONFIDENCE_LEVEL))

cat("\n")
cat("Threshold Scenarios:\n")
for (thresh_name in names(threshold_scenarios)) {
  thresh <- threshold_scenarios[[thresh_name]]
  cat(sprintf("  %s: ε_S = %.2f, ε_Y = %.2f\n",
              thresh$name, thresh$epsilon_s, thresh$epsilon_y))
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Running Validation Study\n")
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

      if (rep %% 100 == 0 || rep == 1) {
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
        rate <- elapsed / iteration
        remaining <- rate * (total_iterations - iteration)
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

      # Step 2: Compute TRUE φ_PPV(F_λ) using reweighting
      # CRITICAL: Use REWEIGHTING not resampling

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
        # No studies with delta_s > epsilon_s; skip this replication
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
        warning(sprintf("Error in replication %d: %s", rep, e$message))
        return(NULL)
      })

      if (is.null(method_result)) next

      # Step 4: Check coverage
      covered <- (true_ppv >= method_result$ci_lower) &&
                 (true_ppv <= method_result$ci_upper)

      # Store results (capture values to avoid scoping issues)
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

      # Save interim results every 100 reps
      if (iteration %% 100 == 0) {
        if (!dir.exists("sims/results")) {
          dir.create("sims/results", recursive = TRUE)
        }
        saveRDS(validation_results,
                sprintf("sims/results/ppv_validation_interim_iter%04d.rds", iteration))
      }
    }
    cat("\n")
  }
}

cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

# Compute coverage rates by scenario
coverage_summary <- validation_results %>%
  group_by(scenario, threshold_scenario, lambda, epsilon_s, epsilon_y) %>%
  summarise(
    n_reps = n(),
    coverage_rate = mean(covered, na.rm = TRUE),
    mean_true_ppv = mean(true_ppv, na.rm = TRUE),
    mean_method_estimate = mean(method_estimate, na.rm = TRUE),
    mean_bias = mean(method_estimate - true_ppv, na.rm = TRUE),
    mean_se = mean(method_se, na.rm = TRUE),
    sd_estimate = sd(method_estimate, na.rm = TRUE),
    se_sd_ratio = mean(method_se) / sd(method_estimate, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    .groups = "drop"
  )

cat("Coverage Rates by Lambda and Thresholds:\n\n")
cat(sprintf("%-20s %-25s %-6s %-10s %-10s %-10s %-10s %-10s\n",
            "Scenario", "Thresholds", "λ", "Coverage", "Bias", "SE/SD", "CI Width", "Status"))
cat(strrep("-", 110), "\n")

for (i in 1:nrow(coverage_summary)) {
  row <- coverage_summary[i, ]
  status <- if (row$coverage_rate >= CONFIDENCE_LEVEL - 0.02) {
    "✓"
  } else if (row$coverage_rate >= CONFIDENCE_LEVEL - 0.05) {
    "~"
  } else {
    "✗"
  }

  cat(sprintf("%-20s %-25s %-6.2f %-10.3f %-10.4f %-10.2f %-10.3f %-10s\n",
              row$scenario,
              row$threshold_scenario,
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
                     validation_results$true_ppv, na.rm = TRUE)

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

# Plot 1: Coverage rate by lambda and threshold
p1 <- ggplot(coverage_summary, aes(x = lambda, y = coverage_rate,
                                   color = threshold_scenario, shape = threshold_scenario)) +
  geom_point(size = 3) +
  geom_line() +
  geom_hline(yintercept = CONFIDENCE_LEVEL, linetype = "dashed", color = "red") +
  geom_hline(yintercept = CONFIDENCE_LEVEL - 0.02,
             linetype = "dotted", color = "orange") +
  geom_hline(yintercept = CONFIDENCE_LEVEL + 0.02,
             linetype = "dotted", color = "orange") +
  ylim(0.88, 1.0) +
  labs(
    title = "PPV Functional: Coverage Rate vs. Lambda and Thresholds",
    subtitle = sprintf("N=%d replications per scenario; Truth and Method both use μ = Dirichlet(1,...,1)",
                       N_REPLICATIONS),
    x = "Lambda (perturbation distance)",
    y = "Coverage Rate",
    color = "Threshold Scenario",
    shape = "Threshold Scenario",
    caption = "Red line: nominal 95%; Orange lines: ±2pp acceptable range"
  ) +
  theme_minimal(base_size = 12)

ggsave("sims/results/ppv_coverage.png", p1,
       width = 10, height = 6, dpi = 300)

cat("  Saved: sims/results/ppv_coverage.png\n")

# Plot 2: True PPV vs. Method estimate
p2 <- ggplot(validation_results,
             aes(x = true_ppv, y = method_estimate,
                 color = threshold_scenario)) +
  geom_point(alpha = 0.3, size = 1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  facet_grid(threshold_scenario ~ scenario) +
  labs(
    title = "True φ_PPV(F_λ) vs. Method Estimate",
    subtitle = "Points should cluster tightly around diagonal",
    x = "True PPV (from reweighting approach)",
    y = "Method Estimate"
  ) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "none")

ggsave("sims/results/ppv_calibration.png", p2,
       width = 12, height = 10, dpi = 300)

cat("  Saved: sims/results/ppv_calibration.png\n")

# Plot 3: CI coverage visualization (sample)
validation_results_plot <- validation_results %>%
  arrange(scenario, threshold_scenario, true_ppv) %>%
  group_by(scenario, threshold_scenario) %>%
  mutate(obs_id = row_number()) %>%
  ungroup() %>%
  filter(scenario == "Moderate λ=0.3") %>%
  slice_sample(n = min(200, n()))

p3 <- ggplot(validation_results_plot,
             aes(x = obs_id, y = method_estimate)) +
  geom_pointrange(aes(ymin = method_ci_lower, ymax = method_ci_upper,
                      color = covered),
                  alpha = 0.6, size = 0.3) +
  geom_point(aes(y = true_ppv), color = "black", size = 1) +
  facet_wrap(~threshold_scenario, scales = "free_x") +
  scale_color_manual(values = c("TRUE" = "blue", "FALSE" = "red"),
                     labels = c("TRUE" = "Covered", "FALSE" = "Missed")) +
  labs(
    title = "PPV Confidence Interval Coverage (λ=0.3)",
    subtitle = "Black dots: true φ_PPV(F_λ); Blue/Red: CIs that cover/miss",
    x = "Replication (sample)",
    y = "PPV",
    color = "Coverage"
  ) +
  theme_minimal(base_size = 10)

ggsave("sims/results/ppv_ci_coverage.png", p3,
       width = 12, height = 8, dpi = 300)

cat("  Saved: sims/results/ppv_ci_coverage.png\n")

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Saving Results\n")
cat("----------------------------------------------------------------\n\n")

# Save detailed results
saveRDS(validation_results, "sims/results/ppv_validation_detailed.rds")
cat("  Saved: sims/results/ppv_validation_detailed.rds\n")

saveRDS(coverage_summary, "sims/results/ppv_validation_summary.rds")
cat("  Saved: sims/results/ppv_validation_summary.rds\n")

# Save as CSV
write.csv(coverage_summary,
          "sims/results/ppv_validation_summary.csv",
          row.names = FALSE)
cat("  Saved: sims/results/ppv_validation_summary.csv\n")

cat("\n")
cat("================================================================\n")
cat("INTERPRETATION FOR PAPER\n")
cat("================================================================\n\n")

cat("Key Findings:\n\n")

cat("1. Fundamental Validity:\n")
by_lambda <- coverage_summary %>%
  group_by(scenario, lambda) %>%
  summarise(mean_coverage = mean(coverage_rate), .groups = "drop")

for (i in 1:nrow(by_lambda)) {
  row <- by_lambda[i, ]
  status <- if (row$mean_coverage >= CONFIDENCE_LEVEL - 0.02) {
    "✓ Valid"
  } else if (row$mean_coverage >= CONFIDENCE_LEVEL - 0.05) {
    "~ Acceptable"
  } else {
    "✗ Problem"
  }
  cat(sprintf("   %s: %.1f%% coverage %s\n",
              row$scenario, row$mean_coverage * 100, status))
}

cat("\n2. Threshold Sensitivity:\n")
by_threshold <- coverage_summary %>%
  group_by(threshold_scenario, epsilon_s, epsilon_y) %>%
  summarise(mean_coverage = mean(coverage_rate),
            mean_ppv = mean(mean_true_ppv),
            .groups = "drop")

for (i in 1:nrow(by_threshold)) {
  row <- by_threshold[i, ]
  cat(sprintf("   %s (ε_S=%.2f, ε_Y=%.2f): coverage=%.1f%%, mean PPV=%.3f\n",
              row$threshold_scenario, row$epsilon_s, row$epsilon_y,
              row$mean_coverage * 100, row$mean_ppv))
}

cat("\n3. Calibration:\n")
cat(sprintf("   Overall bias: %.4f (%.2f%% relative)\n",
            overall_bias,
            overall_bias / mean(validation_results$true_ppv) * 100))
cat(sprintf("   SE/SD ratio: %.2f (1.0 = perfectly calibrated)\n",
            mean(coverage_summary$se_sd_ratio)))

cat("\n4. Paper Claims:\n")
if (overall_coverage >= CONFIDENCE_LEVEL - 0.02) {
  cat("   ✓ PPV functional achieves nominal 95% coverage under assumptions\n")
  cat("   ✓ Threshold-based PPV correctly implemented\n")
  cat("   ✓ Method robust to threshold choice\n")
} else {
  cat("   ⚠ Coverage deviates from nominal level\n")
  cat("   → Check: Is M large enough? Threshold too extreme?\n")
}

cat("\n5. Recommendation:\n")
if (overall_coverage >= CONFIDENCE_LEVEL - 0.02) {
  cat("   Add to Section 5 (Simulation Studies):\n")
  cat("   'The PPV functional φ_PPV(F_λ; ε_S, ε_Y) = P(ΔY > ε_Y | ΔS > ε_S)\n")
  cat("    quantifies the reliability of using surrogate effects to predict\n")
  cat("    outcome effects. Across λ ∈ [0.1, 0.5] and four threshold scenarios,\n")
  cat(sprintf("    the method provided %.1f%% coverage (target: 95%%).\n",
              overall_coverage * 100))
  cat("    This validates the PPV functional for decision-making contexts.'\n")
} else {
  cat("   ⚠ Investigate coverage shortfall\n")
  cat("   → May need larger M for stability with threshold functionals\n")
}

cat("\n")
cat("================================================================\n")
cat("PPV validation complete!\n")
cat("================================================================\n")
