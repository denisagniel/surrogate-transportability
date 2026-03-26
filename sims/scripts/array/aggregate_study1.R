#!/usr/bin/env Rscript
#' Aggregate Study 1 Results from Array Jobs
#'
#' Combines individual task results into single dataset

library(tidyverse)
library(here)

cat("========================================\n")
cat("Aggregating Study 1 Results\n")
cat("========================================\n\n")

# Find all task result files
result_dir <- here("sims/results/study1_array")
task_files <- list.files(result_dir, pattern = "^task_.*\\.rds$", full.names = TRUE)

cat("Found", length(task_files), "task result files\n\n")

if (length(task_files) == 0) {
  stop("No task results found in ", result_dir)
}

# Read and combine all results
cat("Reading results...\n")
all_results <- map_dfr(task_files, readRDS)

cat("Total replications:", nrow(all_results), "\n")
cat("Unique settings:", n_distinct(all_results$task_id), "\n\n")

# Calculate summary statistics by setting
summary_stats <- all_results %>%
  group_by(task_id, sample_size, scenario, lambda) %>%
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

# Overall summary
cat("========================================\n")
cat("Summary Statistics\n")
cat("========================================\n\n")

cat("Overall Performance:\n")
cat("  Mean bias:", round(mean(summary_stats$bias, na.rm = TRUE), 4), "\n")
cat("  Mean RMSE:", round(mean(summary_stats$rmse, na.rm = TRUE), 4), "\n")
cat("  Mean coverage:", round(mean(summary_stats$coverage, na.rm = TRUE), 3), "\n")
cat("  Success rate:", round(mean(all_results$success), 3), "\n\n")

# Coverage by sample size
cat("Coverage by Sample Size:\n")
summary_stats %>%
  group_by(sample_size) %>%
  summarise(coverage = mean(coverage, na.rm = TRUE)) %>%
  mutate(coverage = round(coverage, 3)) %>%
  print()

cat("\n")

# Save combined results
output_file <- here("sims/results/finite_sample_results.rds")
saveRDS(
  list(
    results = all_results,
    summary = summary_stats
  ),
  output_file
)

cat("Combined results saved to:", output_file, "\n")
cat("========================================\n")
