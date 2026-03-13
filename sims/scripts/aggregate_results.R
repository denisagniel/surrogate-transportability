#!/usr/bin/env Rscript

#' Aggregate individual replication results into summary tables and plots
#'
#' Usage: Rscript sims/scripts/aggregate_results.R \
#'          --study-type covariate_shift \
#'          --input-dir sims/results/reps/covariate_shift \
#'          --output-dir sims/results

library(dplyr)
library(tibble)
library(purrr)
library(ggplot2)
library(optparse)

# Parse command-line arguments
option_list <- list(
  make_option(c("-t", "--study-type"), type = "character", default = "covariate_shift",
              help = "Study type: covariate_shift, selection_bias, or dirichlet_misspec", metavar = "character"),
  make_option(c("-i", "--input-dir"), type = "character", default = "sims/results/reps",
              help = "Directory containing individual replication .rds files", metavar = "path"),
  make_option(c("-o", "--output-dir"), type = "character", default = "sims/results",
              help = "Output directory for aggregated results", metavar = "path")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

cat("================================================================\n")
cat("AGGREGATING VALIDATION RESULTS\n")
cat("================================================================\n\n")

cat(sprintf("Study type: %s\n", opt$`study-type`))
cat(sprintf("Input directory: %s\n", opt$`input-dir`))
cat(sprintf("Output directory: %s\n", opt$`output-dir`))

# Find all replication files
pattern <- sprintf("%s_.*_rep[0-9]+\\.rds$", opt$`study-type`)
rep_files <- list.files(opt$`input-dir`, pattern = pattern, full.names = TRUE)

if (length(rep_files) == 0) {
  stop("No replication files found matching pattern: ", pattern)
}

cat(sprintf("\nFound %d replication files\n", length(rep_files)))

# Read all results
cat("Reading results...\n")
results_list <- lapply(rep_files, function(f) {
  tryCatch({
    readRDS(f)
  }, error = function(e) {
    warning(sprintf("Failed to read %s: %s", f, e$message))
    NULL
  })
})

# Remove failed reads
results_list <- results_list[!sapply(results_list, is.null)]
cat(sprintf("Successfully read %d files\n\n", length(results_list)))

# Convert to tibble
results_df <- map_dfr(results_list, function(r) {
  tibble(
    replication = r$replication,
    scenario = r$scenario,
    scenario_name = r$scenario_name,
    lambda = r$lambda,
    true_correlation = r$true_correlation,
    method_estimate = r$method_estimate,
    method_se = r$method_se,
    method_ci_lower = r$method_ci_lower,
    method_ci_upper = r$method_ci_upper,
    method_q025 = r$method_q025,
    method_q975 = r$method_q975,
    covered_ci = r$covered_ci,
    covered_quantile = r$covered_quantile
  )
})

cat("================================================================\n")
cat("SUMMARY STATISTICS\n")
cat("================================================================\n\n")

# Compute coverage by scenario
coverage_summary <- results_df %>%
  group_by(scenario, scenario_name) %>%
  summarise(
    n_reps = n(),
    coverage_ci = mean(covered_ci, na.rm = TRUE),
    coverage_quantile = mean(covered_quantile, na.rm = TRUE),
    mean_lambda = mean(lambda, na.rm = TRUE),
    mean_true_phi = mean(true_correlation, na.rm = TRUE),
    mean_method_phi = mean(method_estimate, na.rm = TRUE),
    mean_se = mean(method_se, na.rm = TRUE),
    mean_ci_width = mean(method_ci_upper - method_ci_lower, na.rm = TRUE),
    mean_quantile_width = mean(method_q975 - method_q025, na.rm = TRUE),
    .groups = "drop"
  )

print(coverage_summary)

cat("\n")
cat("Overall Statistics:\n")
cat(sprintf("  Total replications: %d\n", nrow(results_df)))
cat(sprintf("  Overall CI coverage: %.3f (%.1f%%)\n",
            mean(results_df$covered_ci), mean(results_df$covered_ci) * 100))
cat(sprintf("  Overall quantile coverage: %.3f (%.1f%%)\n",
            mean(results_df$covered_quantile), mean(results_df$covered_quantile) * 100))

# Save aggregated data
cat("\n================================================================\n")
cat("SAVING RESULTS\n")
cat("================================================================\n\n")

if (!dir.exists(opt$`output-dir`)) {
  dir.create(opt$`output-dir`, recursive = TRUE)
}

# Save detailed results
detailed_file <- file.path(opt$`output-dir`,
                          sprintf("%s_validation_detailed.rds", opt$`study-type`))
saveRDS(results_df, detailed_file)
cat(sprintf("Saved detailed results: %s\n", detailed_file))

# Save summary
summary_file <- file.path(opt$`output-dir`,
                         sprintf("%s_validation_summary.rds", opt$`study-type`))
saveRDS(coverage_summary, summary_file)
cat(sprintf("Saved summary: %s\n", summary_file))

# Save as CSV
csv_file <- file.path(opt$`output-dir`,
                     sprintf("%s_validation_summary.csv", opt$`study-type`))
write.csv(coverage_summary, csv_file, row.names = FALSE)
cat(sprintf("Saved CSV: %s\n", csv_file))

# Create plots
cat("\n================================================================\n")
cat("CREATING VISUALIZATIONS\n")
cat("================================================================\n\n")

# Plot 1: Coverage by scenario
p1 <- ggplot(coverage_summary, aes(x = scenario, y = coverage_ci)) +
  geom_col(fill = "steelblue") +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.90, linetype = "dotted", color = "orange") +
  ylim(0.8, 1.0) +
  labs(
    title = sprintf("%s: CI Coverage by Scenario", tools::toTitleCase(gsub("_", " ", opt$`study-type`))),
    x = "Scenario",
    y = "Coverage Rate",
    caption = "Red line: nominal 95%; Orange line: acceptable 90%"
  ) +
  theme_minimal(base_size = 12)

plot_file_1 <- file.path(opt$`output-dir`,
                         sprintf("%s_coverage_by_scenario.png", opt$`study-type`))
ggsave(plot_file_1, p1, width = 8, height = 6, dpi = 300)
cat(sprintf("Saved: %s\n", plot_file_1))

# Plot 2: CI coverage visualization (sample)
# Take up to 50 observations per scenario
results_sample <- results_df %>%
  arrange(scenario, true_correlation) %>%
  group_by(scenario) %>%
  mutate(obs_id = row_number()) %>%
  filter(obs_id <= 50) %>%
  ungroup()

p2 <- ggplot(results_sample, aes(x = obs_id, y = method_estimate)) +
  geom_pointrange(aes(ymin = method_ci_lower, ymax = method_ci_upper,
                      color = covered_ci),
                  alpha = 0.6, size = 0.3) +
  geom_point(aes(y = true_correlation), color = "black", size = 1) +
  facet_wrap(~scenario_name, scales = "free_x") +
  scale_color_manual(values = c("TRUE" = "blue", "FALSE" = "red"),
                     labels = c("TRUE" = "Covered", "FALSE" = "Missed")) +
  labs(
    title = "Confidence Interval Coverage (Sample)",
    subtitle = "Black dots: true φ(Q); Blue/Red: CIs that cover/miss",
    x = "Replication (sample)",
    y = "Correlation",
    color = "Coverage"
  ) +
  theme_minimal(base_size = 10)

plot_file_2 <- file.path(opt$`output-dir`,
                         sprintf("%s_ci_coverage_sample.png", opt$`study-type`))
ggsave(plot_file_2, p2, width = 12, height = 8, dpi = 300)
cat(sprintf("Saved: %s\n", plot_file_2))

# Plot 3: Calibration (true vs estimated)
p3 <- ggplot(results_df, aes(x = true_correlation, y = method_estimate)) +
  geom_point(alpha = 0.2, aes(color = scenario)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  facet_wrap(~scenario_name) +
  labs(
    title = "Calibration: True φ(Q) vs Method Estimate",
    subtitle = "Points should cluster around diagonal",
    x = "True Correlation",
    y = "Method Estimate"
  ) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "none")

plot_file_3 <- file.path(opt$`output-dir`,
                         sprintf("%s_calibration.png", opt$`study-type`))
ggsave(plot_file_3, p3, width = 10, height = 8, dpi = 300)
cat(sprintf("Saved: %s\n", plot_file_3))

cat("\n================================================================\n")
cat("AGGREGATION COMPLETE\n")
cat("================================================================\n")
