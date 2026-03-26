#!/usr/bin/env Rscript
#' Create summary report from array job results

library(tidyverse)
library(here)

cat("========================================\n")
cat("Creating Summary Report\n")
cat("========================================\n\n")

# Check which studies have results
study1_exists <- dir.exists(here("sims/results/study1_array"))
study2_exists <- dir.exists(here("sims/results/study2_array"))

report <- c(
  "# Simulation Studies Results Summary",
  "",
  paste("**Generated:**", Sys.time()),
  paste("**Host:**", Sys.info()["nodename"]),
  "",
  "---",
  ""
)

## Study 1 Summary
if (study1_exists) {
  cat("Processing Study 1...\n")

  task_files <- list.files(here("sims/results/study1_array"),
                           pattern = "^task_.*\\.rds$", full.names = TRUE)

  if (length(task_files) > 0) {
    all_results <- map_dfr(task_files, readRDS)

    summary_stats <- all_results %>%
      group_by(sample_size, scenario, lambda) %>%
      summarise(
        n_reps = n(),
        mean_estimate = mean(estimate, na.rm = TRUE),
        bias = mean(bias, na.rm = TRUE),
        rmse = sqrt(mean(bias^2, na.rm = TRUE)),
        coverage = mean(covered, na.rm = TRUE),
        mean_ci_width = mean(ci_width, na.rm = TRUE),
        success_rate = mean(success),
        .groups = "drop"
      )

    report <- c(report,
      "## Study 1: Finite Sample Performance",
      "",
      paste("- **Total replications:**", nrow(all_results)),
      paste("- **Settings:**", nrow(summary_stats)),
      paste("- **Overall success rate:**", sprintf("%.1f%%", 100 * mean(all_results$success))),
      "",
      "### Overall Performance",
      "",
      paste("- **Mean bias:**", sprintf("%.4f", mean(summary_stats$bias, na.rm = TRUE))),
      paste("- **Mean RMSE:**", sprintf("%.4f", mean(summary_stats$rmse, na.rm = TRUE))),
      paste("- **Mean coverage:**", sprintf("%.3f", mean(summary_stats$coverage, na.rm = TRUE))),
      "",
      "### Coverage by Sample Size",
      ""
    )

    coverage_by_n <- summary_stats %>%
      group_by(sample_size) %>%
      summarise(coverage = mean(coverage, na.rm = TRUE), .groups = "drop") %>%
      mutate(txt = sprintf("- n=%d: %.3f", sample_size, coverage))

    report <- c(report, coverage_by_n$txt, "")

    # Best/worst settings
    best <- summary_stats %>% arrange(desc(coverage)) %>% slice(1)
    worst <- summary_stats %>% arrange(coverage) %>% slice(1)

    report <- c(report,
      "### Best/Worst Settings",
      "",
      sprintf("- **Best:** n=%d, %s, λ=%.1f (coverage=%.3f)",
              best$sample_size, best$scenario, best$lambda, best$coverage),
      sprintf("- **Worst:** n=%d, %s, λ=%.1f (coverage=%.3f)",
              worst$sample_size, worst$scenario, worst$lambda, worst$coverage),
      ""
    )
  } else {
    report <- c(report, "## Study 1: No results found", "")
  }
} else {
  report <- c(report, "## Study 1: Not run", "")
}

## Study 2 Summary
if (study2_exists) {
  cat("Processing Study 2...\n")

  task_files <- list.files(here("sims/results/study2_array"),
                           pattern = "^task_.*\\.rds$", full.names = TRUE)

  if (length(task_files) > 0) {
    all_results <- map_dfr(task_files, readRDS)

    summary_stats <- all_results %>%
      group_by(stress_type, n, lambda, J, rho, cv) %>%
      summarise(
        n_reps = n(),
        mean_estimate = mean(estimate, na.rm = TRUE),
        bias = mean(bias, na.rm = TRUE),
        rmse = sqrt(mean(bias^2, na.rm = TRUE)),
        coverage = mean(covered, na.rm = TRUE),
        success_rate = mean(success),
        .groups = "drop"
      )

    report <- c(report,
      "## Study 2: Stress Testing",
      "",
      paste("- **Total replications:**", nrow(all_results)),
      paste("- **Conditions:**", nrow(summary_stats)),
      paste("- **Overall success rate:**", sprintf("%.1f%%", 100 * mean(all_results$success))),
      ""
    )

    # Summary by stress type
    stress_summary <- summary_stats %>%
      group_by(stress_type) %>%
      summarise(
        n_conditions = n(),
        mean_coverage = mean(coverage, na.rm = TRUE),
        min_coverage = min(coverage, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(txt = sprintf("- **%s:** %d conditions, coverage %.3f (min %.3f)",
                          stress_type, n_conditions, mean_coverage, min_coverage))

    report <- c(report,
      "### By Stress Type",
      "",
      stress_summary$txt,
      ""
    )

    # Stressed conditions (coverage < 93%)
    stressed <- summary_stats %>%
      filter(coverage < 0.93) %>%
      arrange(coverage)

    if (nrow(stressed) > 0) {
      report <- c(report,
        "### Conditions with Coverage < 93%",
        "",
        sprintf("Found %d stressed condition(s):", nrow(stressed)),
        ""
      )

      for (i in 1:min(5, nrow(stressed))) {
        row <- stressed[i,]
        report <- c(report,
          sprintf("- **%s:** n=%d, λ=%.1f, J=%d, ρ=%.2f, CV=%.1f → coverage=%.3f",
                  row$stress_type, row$n, row$lambda, row$J, row$rho, row$cv, row$coverage)
        )
      }
      report <- c(report, "")
    } else {
      report <- c(report, "### All conditions maintained coverage ≥ 93% ✓", "")
    }
  } else {
    report <- c(report, "## Study 2: No results found", "")
  }
} else {
  report <- c(report, "## Study 2: Not run", "")
}

# Write report
report <- c(report,
  "---",
  "",
  "## Files",
  ""
)

if (study1_exists) {
  report <- c(report, "- `sims/results/finite_sample_results.rds` (aggregated Study 1)")
}
if (study2_exists) {
  report <- c(report, "- `sims/results/stress_test_results.rds` (aggregated Study 2)")
}

report <- c(report, "")

# Save report
report_file <- here("SIMULATION_RESULTS_SUMMARY.md")
writeLines(report, report_file)

cat("\n")
cat("========================================\n")
cat("Report saved to:", report_file, "\n")
cat("========================================\n")
cat("\n")
cat(paste(report, collapse = "\n"))
