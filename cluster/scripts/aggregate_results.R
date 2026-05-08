#!/usr/bin/env Rscript
# Aggregate Cluster Simulation Results
#
# Usage: Rscript aggregate_results.R <config_file> [dgp_id]
#
# If dgp_id not specified, aggregates all DGPs

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  stop("Usage: Rscript aggregate_results.R <config_file> [dgp_id]")
}

config_file <- args[1]
dgp_filter <- if (length(args) >= 2) args[2] else NULL

cat("\n=== Aggregating Cluster Results ===\n\n")

# Load configuration
config <- yaml::read_yaml(config_file)
cluster_settings <- config$cluster_settings

dgp_ids <- if (!is.null(dgp_filter)) {
  dgp_filter
} else {
  names(config$dgps)
}

cat(sprintf("DGPs to aggregate: %s\n\n", paste(dgp_ids, collapse = ", ")))

# =============================================================================
# Aggregate Each DGP
# =============================================================================

all_results <- list()

for (dgp_id in dgp_ids) {
  cat(sprintf("=== %s ===\n", dgp_id))

  dgp_config <- config$dgps[[dgp_id]]
  rho_true <- dgp_config$rho_true
  PTE_true <- dgp_config$PTE_P0

  # Find all result files
  results_dir <- file.path(cluster_settings$output_dir, dgp_id)

  if (!dir.exists(results_dir)) {
    cat(sprintf("  No results directory found: %s\n\n", results_dir))
    next
  }

  result_files <- list.files(results_dir, pattern = "^rep_.*\\.rds$", full.names = TRUE)
  n_files <- length(result_files)

  cat(sprintf("  Found %d result files\n", n_files))

  if (n_files == 0) {
    cat(sprintf("  No results to aggregate\n\n"))
    next
  }

  # Load all results
  results_list <- lapply(result_files, readRDS)

  # Extract key metrics
  df <- data.frame(
    rep = sapply(results_list, function(x) x$rep_number),
    rho_hat = sapply(results_list, function(x) x$rho_hat),
    se = sapply(results_list, function(x) x$se),
    ci_lower = sapply(results_list, function(x) x$ci_lower),
    ci_upper = sapply(results_list, function(x) x$ci_upper),
    converged = sapply(results_list, function(x) x$converged),
    M_final = sapply(results_list, function(x) x$M_final),
    PTE_hat = sapply(results_list, function(x) x$PTE_hat),
    elapsed_time = sapply(results_list, function(x) x$elapsed_time)
  )

  # Compute summary statistics
  # Correlation
  bias_rho <- mean(df$rho_hat) - rho_true
  empirical_sd_rho <- sd(df$rho_hat)
  mean_se_rho <- mean(df$se)
  se_calibration_rho <- empirical_sd_rho / mean_se_rho
  df$contains_truth_rho <- (df$ci_lower <= rho_true & rho_true <= df$ci_upper)
  coverage_rho <- mean(df$contains_truth_rho)

  # PTE
  bias_PTE <- mean(df$PTE_hat) - PTE_true
  empirical_sd_PTE <- sd(df$PTE_hat)

  # Convergence
  convergence_rate <- mean(df$converged)
  mean_M <- mean(df$M_final)
  mean_time <- mean(df$elapsed_time)

  cat(sprintf("\n  Correlation Results:\n"))
  cat(sprintf("    TRUE ρ = %.4f\n", rho_true))
  cat(sprintf("    Mean ρ̂ = %.4f (SD = %.4f)\n", mean(df$rho_hat), empirical_sd_rho))
  cat(sprintf("    Bias = %.4f (%.2f%%)\n", bias_rho, 100 * bias_rho / abs(rho_true)))
  cat(sprintf("    Mean SE = %.4f\n", mean_se_rho))
  cat(sprintf("    SE Calibration = %.4f\n", se_calibration_rho))
  cat(sprintf("    Coverage = %.1f%% (%d/%d)\n",
              100 * coverage_rho, sum(df$contains_truth_rho), nrow(df)))

  cat(sprintf("\n  PTE Results:\n"))
  cat(sprintf("    TRUE PTE = %.4f\n", PTE_true))
  cat(sprintf("    Mean PTE_hat = %.4f (SD = %.4f)\n", mean(df$PTE_hat), empirical_sd_PTE))
  cat(sprintf("    Bias = %.4f (%.2f%%)\n", bias_PTE, 100 * bias_PTE / PTE_true))

  cat(sprintf("\n  Computation:\n"))
  cat(sprintf("    Convergence rate = %.1f%%\n", 100 * convergence_rate))
  cat(sprintf("    Mean M = %.0f\n", mean_M))
  cat(sprintf("    Mean time = %.1f seconds\n", mean_time))
  cat(sprintf("    Total time = %.1f hours\n\n", sum(df$elapsed_time) / 3600))

  # Store
  all_results[[dgp_id]] <- list(
    dgp_id = dgp_id,
    dgp_config = dgp_config,
    n_reps = nrow(df),
    data = df,
    summary = list(
      rho_true = rho_true,
      mean_rho_hat = mean(df$rho_hat),
      bias_rho = bias_rho,
      empirical_sd_rho = empirical_sd_rho,
      mean_se_rho = mean_se_rho,
      se_calibration_rho = se_calibration_rho,
      coverage_rho = coverage_rho,
      PTE_true = PTE_true,
      mean_PTE_hat = mean(df$PTE_hat),
      bias_PTE = bias_PTE,
      empirical_sd_PTE = empirical_sd_PTE,
      convergence_rate = convergence_rate,
      mean_M = mean_M,
      mean_time = mean_time
    )
  )
}

# =============================================================================
# Save Aggregated Results
# =============================================================================

output_file <- file.path(cluster_settings$output_dir, "aggregated_results.rds")
saveRDS(all_results, output_file)

cat(sprintf("\nAggregated results saved to: %s\n", output_file))

# =============================================================================
# Create Summary Report
# =============================================================================

cat("\n")
cat(strrep("=", 70), "\n")
cat("SUMMARY REPORT\n")
cat(strrep("=", 70), "\n\n")

for (dgp_id in names(all_results)) {
  res <- all_results[[dgp_id]]
  s <- res$summary

  cat(sprintf("%s (%s)\n", dgp_id, res$dgp_config$name))
  cat(strrep("-", 70), "\n")
  cat(sprintf("  N = %d replications\n", res$n_reps))
  cat(sprintf("  Correlation: ρ_true = %.4f, bias = %.4f (%.1f%%), coverage = %.1f%%\n",
              s$rho_true, s$bias_rho, 100 * s$bias_rho / abs(s$rho_true), 100 * s$coverage_rho))
  cat(sprintf("  PTE: PTE_true = %.4f, bias = %.4f (%.1f%%)\n",
              s$PTE_true, s$bias_PTE, 100 * s$bias_PTE / s$PTE_true))
  cat(sprintf("  Computation: Mean M = %.0f, Mean time = %.1f sec\n\n", s$mean_M, s$mean_time))
}

cat("=== COMPLETE ===\n")
