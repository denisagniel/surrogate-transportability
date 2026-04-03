#!/usr/bin/env Rscript

#' Create comprehensive validation report combining all three studies
#' Run after aggregating individual study results

library(dplyr)
library(tibble)
library(ggplot2)
library(patchwork)

cat("================================================================\n")
cat("COMPREHENSIVE VALIDATION REPORT\n")
cat("================================================================\n\n")

# Load aggregated results
covariate_shift <- tryCatch({
  readRDS("sims/results/covariate_shift_validation_summary.rds")
}, error = function(e) NULL)

selection_bias <- tryCatch({
  readRDS("sims/results/selection_bias_validation_summary.rds")
}, error = function(e) NULL)

dirichlet_misspec <- tryCatch({
  readRDS("sims/results/dirichlet_misspecification_summary.rds")
}, error = function(e) NULL)

# Check what's available
studies_available <- c(
  covariate_shift = !is.null(covariate_shift),
  selection_bias = !is.null(selection_bias),
  dirichlet_misspec = !is.null(dirichlet_misspec)
)

cat("Studies available:\n")
for (study in names(studies_available)) {
  status <- if (studies_available[study]) "✓" else "✗"
  cat(sprintf("  %s %s\n", status, study))
}
cat("\n")

if (!any(studies_available)) {
  stop("No aggregated results found. Run aggregate_results.R first.")
}

# Combine results
all_results <- bind_rows(
  if (studies_available["covariate_shift"])
    mutate(covariate_shift, study = "Covariate Shift") else NULL,
  if (studies_available["selection_bias"])
    mutate(selection_bias, study = "Selection Bias") else NULL,
  if (studies_available["dirichlet_misspec"])
    mutate(dirichlet_misspec, study = "Dirichlet Misspec") else NULL
)

cat("================================================================\n")
cat("OVERALL SUMMARY\n")
cat("================================================================\n\n")

cat(sprintf("Total scenarios: %d\n", nrow(all_results)))
cat(sprintf("Total replications: %d\n", sum(all_results$n_reps)))
cat(sprintf("Overall CI coverage: %.3f (%.1f%%)\n",
            weighted.mean(all_results$coverage_ci, all_results$n_reps),
            weighted.mean(all_results$coverage_ci, all_results$n_reps) * 100))
cat(sprintf("Overall quantile coverage: %.3f (%.1f%%)\n",
            weighted.mean(all_results$coverage_quantile, all_results$n_reps),
            weighted.mean(all_results$coverage_quantile, all_results$n_reps) * 100))

cat("\n")
cat("By study type:\n")
study_summary <- all_results %>%
  group_by(study) %>%
  summarise(
    n_scenarios = n(),
    n_reps = sum(n_reps),
    coverage_ci = weighted.mean(coverage_ci, n_reps),
    coverage_quantile = weighted.mean(coverage_quantile, n_reps),
    .groups = "drop"
  )

print(study_summary)

cat("\n================================================================\n")
cat("VALIDATION STATUS BY SCENARIO\n")
cat("================================================================\n\n")

all_results_status <- all_results %>%
  mutate(
    status_ci = case_when(
      coverage_ci >= 0.93 ~ "✓ Valid",
      coverage_ci >= 0.90 ~ "~ Marginal",
      TRUE ~ "✗ Invalid"
    ),
    status_quantile = case_when(
      coverage_quantile >= 0.93 ~ "✓ Valid",
      coverage_quantile >= 0.90 ~ "~ Marginal",
      TRUE ~ "✗ Invalid"
    )
  )

cat(sprintf("%-20s %-30s %6s %6s %8s %10s\n",
            "Study", "Scenario", "N", "Cov_CI", "Cov_Q", "Status"))
cat(strrep("-", 90), "\n")

for (i in 1:nrow(all_results_status)) {
  row <- all_results_status[i, ]
  cat(sprintf("%-20s %-30s %6d %6.3f %8.3f %10s\n",
              row$study, row$scenario_name, row$n_reps,
              row$coverage_ci, row$coverage_quantile, row$status_ci))
}

cat("\n================================================================\n")
cat("KEY FINDINGS FOR PAPER\n")
cat("================================================================\n\n")

# Count valid scenarios
n_valid_ci <- sum(all_results$coverage_ci >= 0.90)
n_total <- nrow(all_results)
pct_valid <- round(100 * n_valid_ci / n_total)

cat("1. Overall Robustness:\n")
cat(sprintf("   %d/%d scenarios (%.0f%%) achieved ≥90%% CI coverage\n",
            n_valid_ci, n_total, pct_valid))

if (studies_available["covariate_shift"]) {
  cat("\n2. Covariate Shift:\n")
  max_valid_lambda <- max(covariate_shift$mean_lambda[covariate_shift$coverage_ci >= 0.90])
  cat(sprintf("   Valid for TV distance λ ≤ %.2f\n", max_valid_lambda))
  cat(sprintf("   Corresponds to class proportion shifts of ±%.0f%%\n",
              max_valid_lambda * 100))
}

if (studies_available["selection_bias"]) {
  cat("\n3. Selection Bias:\n")
  min_valid_ess <- min(selection_bias$mean_ess[selection_bias$coverage_ci >= 0.90])
  cat(sprintf("   Valid for ESS ≥ %.0f (%.0f%% efficiency)\n",
              min_valid_ess, 100 * min_valid_ess / 1000))
}

if (studies_available["dirichlet_misspec"]) {
  cat("\n4. Dirichlet Misspecification:\n")
  alpha_range <- range(dirichlet_misspec$alpha[dirichlet_misspec$coverage_ci >= 0.90])
  cat(sprintf("   Robust for α ∈ [%.1f, %.1f]\n", alpha_range[1], alpha_range[2]))
}

cat("\n================================================================\n")
cat("CREATING COMBINED FIGURE\n")
cat("================================================================\n\n")

# Combined coverage plot
p <- ggplot(all_results, aes(x = scenario_name, y = coverage_ci, fill = study)) +
  geom_col() +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.90, linetype = "dotted", color = "orange") +
  facet_wrap(~study, scales = "free_x") +
  coord_flip() +
  ylim(0.8, 1.0) +
  labs(
    title = "Method Validation Across Structured Shift Mechanisms",
    subtitle = sprintf("Total: %d replications across %d scenarios",
                      sum(all_results$n_reps), nrow(all_results)),
    y = "95% CI Coverage Rate",
    x = "Scenario",
    caption = "Red: nominal 95%; Orange: acceptable 90%"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none")

ggsave("sims/results/validation_combined_coverage.png", p,
       width = 12, height = 8, dpi = 300)
cat("Saved: sims/results/validation_combined_coverage.png\n")

# Summary statistics
summary_stats <- all_results %>%
  summarise(
    n_scenarios = n(),
    n_reps = sum(n_reps),
    min_ci_coverage = min(coverage_ci),
    median_ci_coverage = median(coverage_ci),
    max_ci_coverage = max(coverage_ci),
    min_quantile_coverage = min(coverage_quantile),
    median_quantile_coverage = median(coverage_quantile),
    max_quantile_coverage = max(coverage_quantile)
  )

saveRDS(summary_stats, "sims/results/validation_summary_statistics.rds")
cat("Saved: sims/results/validation_summary_statistics.rds\n")

cat("\n================================================================\n")
cat("PAPER TEXT SUGGESTIONS\n")
cat("================================================================\n\n")

cat("Section 5: Simulation Studies\n\n")
cat("Add subsection:\n\n")
cat("### 5.X Validation Under Structured Shift Mechanisms\n\n")
cat("To assess robustness when future studies arise from specific mechanisms\n")
cat("rather than uniform Dirichlet perturbations, we conducted comprehensive\n")
cat("validation studies across three classes of structured shifts:\n\n")

if (studies_available["covariate_shift"]) {
  cat(sprintf("1. **Covariate shift** (%d scenarios, %d replications):\n",
              nrow(covariate_shift), sum(covariate_shift$n_reps)))
  cat(sprintf("   Coverage: %.0f%% (target: 95%%)\n\n",
              weighted.mean(covariate_shift$coverage_ci, covariate_shift$n_reps) * 100))
}

if (studies_available["selection_bias"]) {
  cat(sprintf("2. **Selection bias** (%d scenarios, %d replications):\n",
              nrow(selection_bias), sum(selection_bias$n_reps)))
  cat(sprintf("   Coverage: %.0f%% (target: 95%%)\n\n",
              weighted.mean(selection_bias$coverage_ci, selection_bias$n_reps) * 100))
}

if (studies_available["dirichlet_misspec"]) {
  cat(sprintf("3. **Innovation distribution misspecification** (%d scenarios, %d replications):\n",
              nrow(dirichlet_misspec), sum(dirichlet_misspec$n_reps)))
  cat(sprintf("   Coverage: %.0f%% (target: 95%%)\n\n",
              weighted.mean(dirichlet_misspec$coverage_ci, dirichlet_misspec$n_reps) * 100))
}

cat("See Figure X for coverage rates by scenario and Table X for detailed results.\n")

cat("\n================================================================\n")
cat("REPORT COMPLETE\n")
cat("================================================================\n")
