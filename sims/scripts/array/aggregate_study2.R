#!/usr/bin/env Rscript
#' Aggregate Study 2 Results from Array Jobs

library(tidyverse)
library(here)

cat("========================================\n")
cat("Aggregating Study 2 Results\n")
cat("========================================\n\n")

# Find all task result files
result_dir <- here("sims/results/study2_array")
task_files <- list.files(result_dir, pattern = "^task_.*\\.rds$", full.names = TRUE)

cat("Found", length(task_files), "task result files\n\n")

if (length(task_files) == 0) {
  stop("No task results found in ", result_dir)
}

# Read and combine
cat("Reading results...\n")
all_results <- map_dfr(task_files, readRDS)

cat("Total replications:", nrow(all_results), "\n")
cat("Unique conditions:", n_distinct(all_results$task_id), "\n\n")

# Summary by stress condition
summary_stats <- all_results %>%
  group_by(task_id, stress_type, n, lambda, J, rho, cv) %>%
  summarise(
    n_reps = n(),
    mean_estimate = mean(estimate, na.rm = TRUE),
    mean_truth = mean(truth, na.rm = TRUE),
    bias = mean(bias, na.rm = TRUE),
    rmse = sqrt(mean(bias^2, na.rm = TRUE)),
    coverage = mean(covered, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    success_rate = mean(success),
    .groups = "drop"
  )

# Print summary
cat("========================================\n")
cat("Summary by Stress Type\n")
cat("========================================\n\n")

summary_stats %>%
  group_by(stress_type) %>%
  summarise(
    n_conditions = n(),
    mean_coverage = mean(coverage, na.rm = TRUE),
    min_coverage = min(coverage, na.rm = TRUE),
    mean_bias = mean(bias, na.rm = TRUE),
    success_rate = mean(success_rate)
  ) %>%
  mutate(across(where(is.numeric), ~round(., 3))) %>%
  print()

cat("\n")

# Identify stressed conditions (coverage < 0.93)
stressed <- summary_stats %>%
  filter(coverage < 0.93) %>%
  arrange(coverage)

if (nrow(stressed) > 0) {
  cat("Conditions with Coverage < 93%:\n")
  stressed %>%
    select(stress_type, n, lambda, J, rho, cv, coverage, bias) %>%
    mutate(across(where(is.numeric), ~round(., 3))) %>%
    print()
} else {
  cat("All conditions achieved >= 93% coverage\n")
}

cat("\n")

# Save combined results
output_file <- here("sims/results/stress_test_results.rds")
saveRDS(
  list(
    results = all_results,
    summary = summary_stats
  ),
  output_file
)

cat("Combined results saved to:", output_file, "\n")
cat("========================================\n")
