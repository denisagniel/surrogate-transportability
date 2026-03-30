#!/usr/bin/env Rscript
#' Examine failed coverage cases in detail

library(tidyverse)
library(here)

cat("========================================\n")
cat("Examining Failed Coverage Cases\n")
cat("========================================\n\n")

# Load results
results <- readRDS(here("sims/results/finite_sample_results.rds"))$results

# Find worst settings
worst_settings <- results %>%
  group_by(sample_size, scenario, lambda) %>%
  summarise(
    coverage = mean(covered, na.rm = TRUE),
    mean_estimate = mean(estimate, na.rm = TRUE),
    mean_truth = mean(truth, na.rm = TRUE),
    mean_ci_lower = mean(ci_lower, na.rm = TRUE),
    mean_ci_upper = mean(ci_upper, na.rm = TRUE),
    mean_ci_width = mean(ci_width, na.rm = TRUE),
    n_reps = n(),
    .groups = "drop"
  ) %>%
  arrange(coverage)

cat("=== WORST 5 SETTINGS ===\n\n")
print(worst_settings %>% head(5), n = 5)

cat("\n\n=== EXAMINING WORST SETTING IN DETAIL ===\n\n")

# Get worst setting details
worst <- worst_settings %>% slice(1)
cat("Setting:", worst$sample_size, worst$scenario, "λ=", worst$lambda, "\n")
cat("Coverage:", worst$coverage, "\n")
cat("Mean estimate:", worst$mean_estimate, "\n")
cat("Mean truth:", worst$mean_truth, "\n")
cat("Mean CI: [", worst$mean_ci_lower, ",", worst$mean_ci_upper, "]\n")
cat("Mean CI width:", worst$mean_ci_width, "\n\n")

# Get individual replications for this setting
worst_reps <- results %>%
  filter(sample_size == worst$sample_size,
         scenario == worst$scenario,
         lambda == worst$lambda)

# Check pattern of failures
cat("=== PATTERN OF CI FAILURES ===\n\n")

failure_pattern <- worst_reps %>%
  mutate(
    truth_vs_ci = case_when(
      truth < ci_lower ~ "truth below CI (too high)",
      truth > ci_upper ~ "truth above CI (too low)",
      TRUE ~ "covered"
    )
  ) %>%
  count(truth_vs_ci) %>%
  mutate(pct = n / sum(n))

print(failure_pattern)

cat("\n=== FIRST 10 FAILED CASES ===\n\n")

failed_cases <- worst_reps %>%
  filter(!covered) %>%
  head(10) %>%
  select(rep, estimate, ci_lower, ci_upper, truth, truth_p0) %>%
  mutate(
    truth_below = truth < ci_lower,
    truth_above = truth > ci_upper,
    diff_truth_est = truth - estimate,
    diff_truth_p0 = truth - truth_p0
  )

print(failed_cases)

cat("\n=== DISTRIBUTION OF KEY QUANTITIES ===\n\n")

quantiles <- worst_reps %>%
  summarise(
    estimate_q05 = quantile(estimate, 0.05),
    estimate_q50 = quantile(estimate, 0.50),
    estimate_q95 = quantile(estimate, 0.95),
    truth_q05 = quantile(truth, 0.05),
    truth_q50 = quantile(truth, 0.50),
    truth_q95 = quantile(truth, 0.95),
    ci_width_q05 = quantile(ci_width, 0.05),
    ci_width_q50 = quantile(ci_width, 0.50),
    ci_width_q95 = quantile(ci_width, 0.95)
  )

cat("Estimate quantiles (5%, 50%, 95%):", quantiles$estimate_q05, quantiles$estimate_q50, quantiles$estimate_q95, "\n")
cat("Truth quantiles (5%, 50%, 95%):", quantiles$truth_q05, quantiles$truth_q50, quantiles$truth_q95, "\n")
cat("CI width quantiles (5%, 50%, 95%):", quantiles$ci_width_q05, quantiles$ci_width_q50, quantiles$ci_width_q95, "\n")

cat("\n=== CHECK: Is truth varying across reps? ===\n")
cat("Truth SD:", sd(worst_reps$truth), "\n")
cat("Truth range:", range(worst_reps$truth), "\n")
cat("\nNote: Truth should be constant if using true parameters!\n")

cat("\n=== DIAGNOSIS ===\n\n")

cat("Key questions:\n")
cat("1. Are CIs systematically too high or too low?\n")
cat("2. Is truth varying (suggesting computation error)?\n")
cat("3. Is CI width appropriate for the variability?\n")
cat("4. How does estimated minimax compare to P0 concordance?\n\n")

# Compare estimate to P0 concordance
if ("truth_p0" %in% names(worst_reps)) {
  cat("=== MINIMAX vs P0 CONCORDANCE ===\n\n")
  cat("Mean P0 concordance (truth_p0):", mean(worst_reps$truth_p0, na.rm = TRUE), "\n")
  cat("Mean minimax truth:", mean(worst_reps$truth, na.rm = TRUE), "\n")
  cat("Mean minimax estimate:", mean(worst_reps$estimate, na.rm = TRUE), "\n")
  cat("Difference (P0 - minimax):", mean(worst_reps$truth_p0 - worst_reps$truth, na.rm = TRUE), "\n")
  cat("This should be positive (minimax is worst-case, lower than P0)\n")
}

cat("\n========================================\n")
