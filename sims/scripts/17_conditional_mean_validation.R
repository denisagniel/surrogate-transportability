#!/usr/bin/env Rscript

#' Conditional Mean Functional Validation
#'
#' Research Questions:
#' 1. Is E[ΔY | ΔS = δ] correctly estimated?
#' 2. Do CIs achieve nominal coverage?
#' 3. How does performance vary with δ_S value and bandwidth?
#'
#' Functional Definition:
#'   φ_cond(F_λ; δ) = E[ΔY | ΔS = δ]
#'
#' This tests whether the conditional mean functional correctly estimates
#' the expected outcome treatment effect for a given surrogate treatment effect.

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
N_TRUE_STUDIES <- 2000
N_INNOVATIONS <- 1000
CONFIDENCE_LEVEL <- 0.95

# Test scenarios
scenarios <- list(
  small = list(name = "Small λ=0.1", lambda = 0.1),
  moderate = list(name = "Moderate λ=0.3", lambda = 0.3),
  large = list(name = "Large λ=0.5", lambda = 0.5)
)

# Conditioning values for δ_S
delta_s_scenarios <- list(
  low = list(name = "Low δ_S=0.1", delta_s_value = 0.1),
  moderate_low = list(name = "Moderate-low δ_S=0.3", delta_s_value = 0.3),
  moderate_high = list(name = "Moderate-high δ_S=0.5", delta_s_value = 0.5),
  high = list(name = "High δ_S=0.7", delta_s_value = 0.7)
)

cat("================================================================\n")
cat("CONDITIONAL MEAN FUNCTIONAL VALIDATION\n")
cat("================================================================\n\n")

cat("Research Questions:\n")
cat("  1. Is E[ΔY | ΔS = δ] correctly estimated?\n")
cat("  2. Do 95% CIs achieve nominal coverage?\n")
cat("  3. How does performance vary with δ value?\n\n")

cat("Functional Definition:\n")
cat("  φ_cond(F_λ; δ) = E[ΔY | ΔS = δ]\n")
cat("  where (ΔS, ΔY) are treatment effects in future study Q ~ F_λ\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications: %d\n", N_REPLICATIONS))
cat(sprintf("  Studies for TRUE φ(F_λ): %d\n", N_TRUE_STUDIES))
cat(sprintf("  Innovations (M) for method: %d\n", N_INNOVATIONS))
cat(sprintf("  Confidence level: %.2f\n", CONFIDENCE_LEVEL))

cat("\n")
cat("Conditioning Values:\n")
for (delta_name in names(delta_s_scenarios)) {
  delta_scen <- delta_s_scenarios[[delta_name]]
  cat(sprintf("  %s: δ_S = %.2f\n", delta_scen$name, delta_scen$delta_s_value))
}

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Running Validation Study\n")
cat("----------------------------------------------------------------\n\n")

start_time <- Sys.time()

validation_results <- tibble::tibble(
  scenario = character(),
  delta_s_scenario = character(),
  replication = integer(),
  lambda = numeric(),
  delta_s_value = numeric(),
  true_conditional_mean = numeric(),
  method_estimate = numeric(),
  method_se = numeric(),
  method_ci_lower = numeric(),
  method_ci_upper = numeric(),
  ci_width = numeric(),
  covered = logical()
)

total_iterations <- length(scenarios) * length(delta_s_scenarios) * N_REPLICATIONS
iteration <- 0

for (scenario_name in names(scenarios)) {
  scenario <- scenarios[[scenario_name]]

  for (delta_name in names(delta_s_scenarios)) {
    delta_scen <- delta_s_scenarios[[delta_name]]

    cat(sprintf("Scenario: %s, Conditioning: %s\n", scenario$name, delta_scen$name))

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

      # Step 2: Compute TRUE E[ΔY | ΔS = δ] using kernel-weighted approach

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

      # TRUE conditional mean: E[ΔY | ΔS ≈ δ] using kernel weighting
      # Use Silverman's rule for bandwidth
      delta_s_all <- true_effects[, 1]
      delta_y_all <- true_effects[, 2]

      bandwidth <- 1.06 * sd(delta_s_all) * length(delta_s_all)^(-1/5)

      # Kernel weights
      kernel_weights <- dnorm((delta_s_all - delta_scen$delta_s_value) / bandwidth)

      if (sum(kernel_weights) == 0) {
        # No observations near this delta_s_value; skip
        next
      }

      true_conditional_mean <- sum(kernel_weights * delta_y_all) / sum(kernel_weights)

      # Step 3: Apply METHOD
      method_result <- tryCatch({
        surrogate_inference_if(
          baseline,
          lambda = scenario$lambda,
          n_innovations = N_INNOVATIONS,
          functional_type = "conditional_mean",
          delta_s_value = delta_scen$delta_s_value
        )
      }, error = function(e) {
        warning(sprintf("Error in replication %d: %s", rep, e$message))
        return(NULL)
      })

      if (is.null(method_result)) next

      # Step 4: Check coverage
      covered <- (true_conditional_mean >= method_result$ci_lower) &&
                 (true_conditional_mean <= method_result$ci_upper)

      # Store results (capture values to avoid scoping issues)
      scenario_name_val <- scenario$name
      delta_s_name_val <- delta_scen$name
      lambda_val <- scenario$lambda
      delta_s_value_val <- delta_scen$delta_s_value

      validation_results <- rbind(validation_results, tibble::tibble(
        scenario = scenario_name_val,
        delta_s_scenario = delta_s_name_val,
        replication = rep,
        lambda = lambda_val,
        delta_s_value = delta_s_value_val,
        true_conditional_mean = true_conditional_mean,
        method_estimate = method_result$estimate,
        method_se = method_result$se,
        method_ci_lower = method_result$ci_lower,
        method_ci_upper = method_result$ci_upper,
        ci_width = method_result$ci_upper - method_result$ci_lower,
        covered = covered
      ))

      # Save interim results every 100 iterations
      if (iteration %% 100 == 0) {
        if (!dir.exists("sims/results")) {
          dir.create("sims/results", recursive = TRUE)
        }
        saveRDS(validation_results,
                sprintf("sims/results/conditional_mean_validation_interim_iter%04d.rds", iteration))
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
  group_by(scenario, delta_s_scenario, lambda, delta_s_value) %>%
  summarise(
    n_reps = n(),
    coverage_rate = mean(covered, na.rm = TRUE),
    mean_true_conditional_mean = mean(true_conditional_mean, na.rm = TRUE),
    mean_method_estimate = mean(method_estimate, na.rm = TRUE),
    mean_bias = mean(method_estimate - true_conditional_mean, na.rm = TRUE),
    rmse = sqrt(mean((method_estimate - true_conditional_mean)^2, na.rm = TRUE)),
    mean_se = mean(method_se, na.rm = TRUE),
    sd_estimate = sd(method_estimate, na.rm = TRUE),
    se_sd_ratio = mean(method_se) / sd(method_estimate, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    .groups = "drop"
  )

cat("Coverage Rates by Lambda and δ_S Value:\n\n")
cat(sprintf("%-20s %-25s %-6s %-10s %-10s %-10s %-10s %-10s\n",
            "Scenario", "δ_S Value", "λ", "Coverage", "Bias", "RMSE", "SE/SD", "Status"))
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

  cat(sprintf("%-20s %-25s %-6.2f %-10.3f %-10.4f %-10.4f %-10.2f %-10s\n",
              row$scenario,
              row$delta_s_scenario,
              row$lambda,
              row$coverage_rate,
              row$mean_bias,
              row$rmse,
              row$se_sd_ratio,
              status))
}

cat("\n")
cat("Target Coverage: ", CONFIDENCE_LEVEL, "\n")
cat("✓ = within 2pp of target; ~ = within 5pp; ✗ = more than 5pp off\n\n")

# Assess overall validity
overall_coverage <- mean(validation_results$covered, na.rm = TRUE)
overall_bias <- mean(validation_results$method_estimate -
                     validation_results$true_conditional_mean, na.rm = TRUE)
overall_rmse <- sqrt(mean((validation_results$method_estimate -
                           validation_results$true_conditional_mean)^2, na.rm = TRUE))

cat(sprintf("Overall Coverage: %.3f (%.1f%%)\n",
            overall_coverage, overall_coverage * 100))
cat(sprintf("Overall Bias: %.4f\n", overall_bias))
cat(sprintf("Overall RMSE: %.4f\n", overall_rmse))

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

# Plot 1: Coverage rate by lambda and delta_s_value
p1 <- ggplot(coverage_summary, aes(x = lambda, y = coverage_rate,
                                   color = delta_s_scenario, shape = delta_s_scenario)) +
  geom_point(size = 3) +
  geom_line() +
  geom_hline(yintercept = CONFIDENCE_LEVEL, linetype = "dashed", color = "red") +
  geom_hline(yintercept = CONFIDENCE_LEVEL - 0.02,
             linetype = "dotted", color = "orange") +
  geom_hline(yintercept = CONFIDENCE_LEVEL + 0.02,
             linetype = "dotted", color = "orange") +
  ylim(0.88, 1.0) +
  labs(
    title = "Conditional Mean Functional: Coverage Rate vs. Lambda and δ_S",
    subtitle = sprintf("N=%d replications per scenario; Truth and Method both use μ = Dirichlet(1,...,1)",
                       N_REPLICATIONS),
    x = "Lambda (perturbation distance)",
    y = "Coverage Rate",
    color = "δ_S Value",
    shape = "δ_S Value",
    caption = "Red line: nominal 95%; Orange lines: ±2pp acceptable range"
  ) +
  theme_minimal(base_size = 12)

ggsave("sims/results/conditional_mean_coverage.png", p1,
       width = 10, height = 6, dpi = 300)

cat("  Saved: sims/results/conditional_mean_coverage.png\n")

# Plot 2: True conditional mean vs. Method estimate
p2 <- ggplot(validation_results,
             aes(x = true_conditional_mean, y = method_estimate,
                 color = delta_s_scenario)) +
  geom_point(alpha = 0.3, size = 1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  facet_grid(delta_s_scenario ~ scenario) +
  labs(
    title = "True E[ΔY | ΔS = δ] vs. Method Estimate",
    subtitle = "Points should cluster tightly around diagonal",
    x = "True Conditional Mean (kernel-weighted)",
    y = "Method Estimate"
  ) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "none")

ggsave("sims/results/conditional_mean_calibration.png", p2,
       width = 12, height = 10, dpi = 300)

cat("  Saved: sims/results/conditional_mean_calibration.png\n")

# Plot 3: CI coverage visualization (sample)
validation_results_plot <- validation_results %>%
  arrange(scenario, delta_s_scenario, true_conditional_mean) %>%
  group_by(scenario, delta_s_scenario) %>%
  mutate(obs_id = row_number()) %>%
  ungroup() %>%
  filter(scenario == "Moderate λ=0.3") %>%
  slice_sample(n = min(200, n()))

p3 <- ggplot(validation_results_plot,
             aes(x = obs_id, y = method_estimate)) +
  geom_pointrange(aes(ymin = method_ci_lower, ymax = method_ci_upper,
                      color = covered),
                  alpha = 0.6, size = 0.3) +
  geom_point(aes(y = true_conditional_mean), color = "black", size = 1) +
  facet_wrap(~delta_s_scenario, scales = "free_x") +
  scale_color_manual(values = c("TRUE" = "blue", "FALSE" = "red"),
                     labels = c("TRUE" = "Covered", "FALSE" = "Missed")) +
  labs(
    title = "Conditional Mean: CI Coverage (λ=0.3)",
    subtitle = "Black dots: true E[ΔY | ΔS = δ]; Blue/Red: CIs that cover/miss",
    x = "Replication (sample)",
    y = "Conditional Mean",
    color = "Coverage"
  ) +
  theme_minimal(base_size = 10)

ggsave("sims/results/conditional_mean_ci_coverage.png", p3,
       width = 12, height = 8, dpi = 300)

cat("  Saved: sims/results/conditional_mean_ci_coverage.png\n")

# Plot 4: Conditional mean by δ_S value
conditional_mean_by_delta <- coverage_summary %>%
  select(scenario, delta_s_value, mean_true_conditional_mean, mean_method_estimate) %>%
  tidyr::pivot_longer(cols = c(mean_true_conditional_mean, mean_method_estimate),
                      names_to = "type", values_to = "value") %>%
  mutate(type = ifelse(type == "mean_true_conditional_mean", "True", "Method Estimate"))

p4 <- ggplot(conditional_mean_by_delta, aes(x = delta_s_value, y = value,
                                             color = type, linetype = type)) +
  geom_point(size = 2) +
  geom_line() +
  facet_wrap(~scenario) +
  labs(
    title = "Conditional Mean Function: E[ΔY | ΔS = δ]",
    subtitle = "True vs. Method Estimate across δ_S values",
    x = "δ_S (surrogate treatment effect)",
    y = "E[ΔY | ΔS = δ] (outcome treatment effect)",
    color = "Type",
    linetype = "Type"
  ) +
  theme_minimal(base_size = 12)

ggsave("sims/results/conditional_mean_function.png", p4,
       width = 10, height = 6, dpi = 300)

cat("  Saved: sims/results/conditional_mean_function.png\n")

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Saving Results\n")
cat("----------------------------------------------------------------\n\n")

# Save detailed results
saveRDS(validation_results, "sims/results/conditional_mean_validation_detailed.rds")
cat("  Saved: sims/results/conditional_mean_validation_detailed.rds\n")

saveRDS(coverage_summary, "sims/results/conditional_mean_validation_summary.rds")
cat("  Saved: sims/results/conditional_mean_validation_summary.rds\n")

# Save as CSV
write.csv(coverage_summary,
          "sims/results/conditional_mean_validation_summary.csv",
          row.names = FALSE)
cat("  Saved: sims/results/conditional_mean_validation_summary.csv\n")

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

cat("\n2. Estimation Accuracy by δ_S:\n")
by_delta <- coverage_summary %>%
  group_by(delta_s_scenario, delta_s_value) %>%
  summarise(mean_bias = mean(mean_bias),
            mean_rmse = mean(rmse),
            .groups = "drop")

for (i in 1:nrow(by_delta)) {
  row <- by_delta[i, ]
  cat(sprintf("   %s (δ=%.1f): bias=%.4f, RMSE=%.4f\n",
              row$delta_s_scenario, row$delta_s_value,
              row$mean_bias, row$mean_rmse))
}

cat("\n3. Calibration:\n")
cat(sprintf("   Overall bias: %.4f\n", overall_bias))
cat(sprintf("   Overall RMSE: %.4f\n", overall_rmse))
cat(sprintf("   SE/SD ratio: %.2f (1.0 = perfectly calibrated)\n",
            mean(coverage_summary$se_sd_ratio)))

cat("\n4. Paper Claims:\n")
if (overall_coverage >= CONFIDENCE_LEVEL - 0.02) {
  cat("   ✓ Conditional mean functional achieves nominal 95% coverage\n")
  cat("   ✓ Method correctly estimates E[ΔY | ΔS = δ]\n")
  cat("   ✓ Robust across δ_S values\n")
} else {
  cat("   ⚠ Coverage deviates from nominal level\n")
  cat("   → Check: Bandwidth selection? M large enough?\n")
}

cat("\n5. Recommendation:\n")
if (overall_coverage >= CONFIDENCE_LEVEL - 0.02) {
  cat("   Add to Section 5 (Simulation Studies):\n")
  cat("   'The conditional mean functional φ_cond(F_λ; δ) = E[ΔY | ΔS = δ]\n")
  cat("    estimates the expected outcome effect for a given surrogate effect.\n")
  cat(sprintf("    Across λ ∈ [0.1, 0.5] and δ ∈ [0.1, 0.7], coverage was %.1f%%\n",
              overall_coverage * 100))
  cat(sprintf("    (target: 95%) with RMSE = %.3f, validating the inference procedure.'\n",
              overall_rmse))
} else {
  cat("   ⚠ Investigate coverage shortfall\n")
  cat("   → Consider: adaptive bandwidth selection, larger M\n")
}

cat("\n")
cat("================================================================\n")
cat("Conditional mean functional validation complete!\n")
cat("================================================================\n")
