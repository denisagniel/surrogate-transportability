#!/usr/bin/env Rscript
# Combine AIPW Robustness Study Results
#
# Aggregates all batch result files into a single dataset
# Computes summary statistics by setting
# Saves combined results and summary tables
#
# Usage: Rscript combine_results.R

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(yaml)
})

cat("\n")
cat(strrep("=", 70), "\n")
cat("AIPW Robustness Study: Combine Results\n")
cat(strrep("=", 70), "\n\n")

# ==============================================================================
# Configuration
# ==============================================================================

RESULTS_DIR <- "../results"
CONFIG_FILE <- "../config/aipw_grid.yaml"
OUTPUT_COMBINED <- "../results/aipw_robustness_combined.rds"
OUTPUT_SUMMARY <- "../results/aipw_robustness_summary.csv"

# Load config
config <- yaml::read_yaml(CONFIG_FILE)
rho_true <- config$dgp$rho_true

# ==============================================================================
# Find All Result Files
# ==============================================================================

cat("Step 1: Finding result files...\n")

result_files <- list.files(
  path = RESULTS_DIR,
  pattern = "batch_.*\\.rds$",
  recursive = TRUE,
  full.names = TRUE
)

cat(sprintf("  Found %d batch files\n", length(result_files)))

if (length(result_files) == 0) {
  stop("No result files found in ", RESULTS_DIR)
}

# ==============================================================================
# Load and Combine Results
# ==============================================================================

cat("\nStep 2: Loading and combining results...\n")

results <- map_dfr(result_files, function(file) {
  tryCatch({
    readRDS(file)
  }, error = function(e) {
    warning(sprintf("Failed to read %s: %s", file, e$message))
    NULL
  })
})

cat(sprintf("  Combined %d replications\n", nrow(results)))
cat(sprintf("  Columns: %s\n", paste(names(results), collapse = ", ")))

# Count by scenario
scenario_counts <- results %>%
  count(scenario, name = "n_reps") %>%
  arrange(scenario)

cat("\n  Replications by scenario:\n")
print(scenario_counts, n = Inf)

# ==============================================================================
# Compute Summary Statistics
# ==============================================================================

cat("\nStep 3: Computing summary statistics...\n")

# Define grouping variables
group_vars <- c("scenario", "n", "alpha_1")

# Add noise parameters based on scenario
results_grouped <- results %>%
  mutate(
    # For grouping, use NA for parameters not relevant to scenario
    alpha_e_group = ifelse(scenario %in% c(1, 3), alpha_e, NA),
    alpha_mu_group = ifelse(scenario %in% c(2, 3), alpha_mu, NA),
    c_e_group = ifelse(scenario == 1, c_e, NA),
    c_mu_group = ifelse(scenario == 2, c_mu, NA)
  )

summary_stats <- results_grouped %>%
  group_by(scenario, n, alpha_1, alpha_e_group, alpha_mu_group, c_e_group, c_mu_group) %>%
  summarise(
    n_reps = n(),

    # Point estimate
    mean_rho_hat = mean(rho_hat, na.rm = TRUE),
    median_rho_hat = median(rho_hat, na.rm = TRUE),
    sd_rho_hat = sd(rho_hat, na.rm = TRUE),

    # Bias
    mean_bias = mean(bias, na.rm = TRUE),
    median_bias = median(bias, na.rm = TRUE),
    rmse = sqrt(mean(bias^2, na.rm = TRUE)),

    # Standard error
    mean_se = mean(se, na.rm = TRUE),
    median_se = median(se, na.rm = TRUE),

    # Coverage
    coverage = mean(covers, na.rm = TRUE),

    # Convergence
    converged_pct = mean(converged, na.rm = TRUE),
    mean_M_final = mean(M_final, na.rm = TRUE),

    # Nuisance quality
    mean_e_mae = mean(e_mae, na.rm = TRUE),
    mean_e_rmse = mean(e_rmse, na.rm = TRUE),
    mean_mu_S_mae = mean(mu_1_S_mae, na.rm = TRUE),
    mean_mu_Y_mae = mean(mu_1_Y_mae, na.rm = TRUE),

    # Computation
    mean_time_sec = mean(time_sec, na.rm = TRUE),
    total_time_hours = sum(time_sec, na.rm = TRUE) / 3600,

    # Errors
    n_errors = sum(error, na.rm = TRUE),

    .groups = "drop"
  ) %>%
  rename(
    alpha_e = alpha_e_group,
    alpha_mu = alpha_mu_group,
    c_e = c_e_group,
    c_mu = c_mu_group
  )

cat(sprintf("  Computed summaries for %d settings\n", nrow(summary_stats)))

# ==============================================================================
# Save Results
# ==============================================================================

cat("\nStep 4: Saving results...\n")

# Save combined data
saveRDS(results, OUTPUT_COMBINED)
cat(sprintf("  Combined data: %s (%d rows)\n", OUTPUT_COMBINED, nrow(results)))

# Save summary table
write_csv(summary_stats, OUTPUT_SUMMARY)
cat(sprintf("  Summary table: %s (%d settings)\n", OUTPUT_SUMMARY, nrow(summary_stats)))

# ==============================================================================
# Print Summary Report
# ==============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("SUMMARY REPORT\n")
cat(strrep("=", 70), "\n\n")

# Scenario 0: Oracle (should have ~0 bias, ~95% coverage)
cat("Scenario 0: Oracle (true nuisances)\n")
cat(strrep("-", 70), "\n")

oracle_summary <- summary_stats %>%
  filter(scenario == 0) %>%
  select(n, alpha_1, mean_bias, rmse, coverage, converged_pct)

if (nrow(oracle_summary) > 0) {
  print(oracle_summary, n = Inf)

  # Validation checks
  max_bias <- max(abs(oracle_summary$mean_bias), na.rm = TRUE)
  min_coverage <- min(oracle_summary$coverage, na.rm = TRUE)

  cat("\n  Validation:\n")
  cat(sprintf("    Max |bias|: %.4f %s\n", max_bias,
              ifelse(max_bias < 0.05, "✓ PASS", "✗ FAIL (should be < 0.05)")))
  cat(sprintf("    Min coverage: %.1f%% %s\n", min_coverage * 100,
              ifelse(min_coverage > 0.90, "✓ PASS", "✗ FAIL (should be > 90%)")))
} else {
  cat("  No results found\n")
}

cat("\n")

# Scenarios 1-3: Check convergence rate patterns
for (s in 1:3) {
  scenario_name <- c(
    "1: Propensity noise only",
    "2: Outcome noise only",
    "3: Both noisy"
  )[s]

  cat(sprintf("Scenario %s\n", scenario_name))
  cat(strrep("-", 70), "\n")

  scenario_summary <- summary_stats %>%
    filter(scenario == s)

  if (nrow(scenario_summary) > 0) {
    cat(sprintf("  Settings: %d\n", nrow(scenario_summary)))
    cat(sprintf("  Mean bias range: [%.4f, %.4f]\n",
                min(scenario_summary$mean_bias, na.rm = TRUE),
                max(scenario_summary$mean_bias, na.rm = TRUE)))
    cat(sprintf("  Coverage range: [%.1f%%, %.1f%%]\n",
                min(scenario_summary$coverage, na.rm = TRUE) * 100,
                max(scenario_summary$coverage, na.rm = TRUE) * 100))
    cat(sprintf("  Convergence: %.1f%% of reps\n",
                mean(scenario_summary$converged_pct, na.rm = TRUE) * 100))

    # Show sample of settings
    cat("\n  Sample settings (first 5):\n")
    sample_cols <- c("n", "alpha_1", "alpha_e", "alpha_mu", "mean_bias", "coverage")
    sample_cols_present <- sample_cols[sample_cols %in% names(scenario_summary)]
    print(head(scenario_summary[, sample_cols_present], 5))
  } else {
    cat("  No results found\n")
  }

  cat("\n")
}

# Overall statistics
cat("Overall Statistics\n")
cat(strrep("-", 70), "\n")
cat(sprintf("Total replications: %d\n", nrow(results)))
cat(sprintf("Total settings: %d\n", nrow(summary_stats)))
cat(sprintf("Total computation time: %.1f hours\n", sum(results$time_sec, na.rm = TRUE) / 3600))
cat(sprintf("Mean time per replication: %.1f seconds\n", mean(results$time_sec, na.rm = TRUE)))
cat(sprintf("Total errors: %d (%.1f%%)\n",
            sum(results$error, na.rm = TRUE),
            100 * sum(results$error, na.rm = TRUE) / nrow(results)))

cat("\n")
cat(strrep("=", 70), "\n")
cat("Combination complete!\n")
cat(strrep("=", 70), "\n\n")

cat("Next steps:\n")
cat("  1. Analyze results in R:\n")
cat(sprintf("       results <- readRDS('%s')\n", OUTPUT_COMBINED))
cat(sprintf("       summary <- read_csv('%s')\n", OUTPUT_SUMMARY))
cat("  2. Create plots and tables for paper\n")
cat("  3. Investigate any failed settings or anomalies\n\n")
