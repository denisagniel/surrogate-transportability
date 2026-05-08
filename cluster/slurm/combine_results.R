#!/usr/bin/env Rscript
# Combine Cluster Simulation Results
#
# Aggregates results from all batches and computes summary statistics
#
# Usage: Rscript cluster/slurm/combine_results.R

suppressPackageStartupMessages({
  library(yaml)
})

cat("\n=== Combining Cluster Results ===\n\n")

# Load config
config <- yaml::read_yaml("cluster/config/dgp_specifications.yaml")

# DGPs to process
dgp_ids <- c("dgp1", "dgp2", "dgp4")

# =============================================================================
# Combine Results
# =============================================================================

all_results <- list()

for (dgp_id in dgp_ids) {
  cat(sprintf("=== %s ===\n", dgp_id))

  dgp_config <- config$dgps[[dgp_id]]
  results_dir <- file.path("cluster/results", dgp_id)

  if (!dir.exists(results_dir)) {
    cat(sprintf("  No results directory: %s\n\n", results_dir))
    next
  }

  # Find batch files
  batch_files <- list.files(results_dir, pattern = "^batch_.*\\.rds$",
                             full.names = TRUE)
  n_batches <- length(batch_files)

  cat(sprintf("  Found %d batch files\n", n_batches))

  if (n_batches == 0) {
    cat("  No results to combine\n\n")
    next
  }

  # Load all batches
  results_list <- list()

  for (batch_file in batch_files) {
    batch_data <- readRDS(batch_file)

    # Extract individual replication results
    for (rep_result in batch_data$results) {
      results_list[[length(results_list) + 1]] <- rep_result
    }
  }

  n_reps <- length(results_list)
  cat(sprintf("  Total replications: %d\n", n_reps))

  # Convert to data frame
  df <- data.frame(
    rep = sapply(results_list, function(x) x$rep_number),
    seed = sapply(results_list, function(x) x$seed),
    rho_hat = sapply(results_list, function(x) x$rho_hat),
    se = sapply(results_list, function(x) x$se),
    ci_lower = sapply(results_list, function(x) x$ci_lower),
    ci_upper = sapply(results_list, function(x) x$ci_upper),
    converged = sapply(results_list, function(x) x$converged),
    M_final = sapply(results_list, function(x) x$M_final),
    PTE_hat = sapply(results_list, function(x) x$PTE_hat),
    elapsed_time = sapply(results_list, function(x) x$elapsed_time),
    rho_true = sapply(results_list, function(x) x$rho_true),
    PTE_true = sapply(results_list, function(x) x$PTE_true)
  )

  # Compute summary statistics
  rho_true <- dgp_config$rho_true
  PTE_true <- dgp_config$PTE_P0

  # Correlation
  bias_rho <- mean(df$rho_hat) - rho_true
  empirical_sd_rho <- sd(df$rho_hat)
  mean_se_rho <- mean(df$se, na.rm = TRUE)
  se_calibration_rho <- empirical_sd_rho / mean_se_rho

  df$contains_truth_rho <- (df$ci_lower <= rho_true & rho_true <= df$ci_upper)
  coverage_rho <- mean(df$contains_truth_rho, na.rm = TRUE)

  # PTE
  bias_PTE <- mean(df$PTE_hat, na.rm = TRUE) - PTE_true
  empirical_sd_PTE <- sd(df$PTE_hat, na.rm = TRUE)

  # Convergence
  convergence_rate <- mean(df$converged)
  mean_M <- mean(df$M_final)
  mean_time <- mean(df$elapsed_time)

  cat(sprintf("\n  Correlation Results:\n"))
  cat(sprintf("    TRUE ρ = %.4f\n", rho_true))
  cat(sprintf("    Mean ρ̂ = %.4f (SD = %.4f)\n", mean(df$rho_hat), empirical_sd_rho))
  cat(sprintf("    Bias = %.4f (%.1f%%)\n", bias_rho, 100 * bias_rho / abs(rho_true)))
  cat(sprintf("    Mean SE = %.4f\n", mean_se_rho))
  cat(sprintf("    SE Calibration = %.4f\n", se_calibration_rho))
  cat(sprintf("    Coverage = %.1f%% (%d/%d)\n",
              100 * coverage_rho, sum(df$contains_truth_rho, na.rm = TRUE), n_reps))

  cat(sprintf("\n  PTE Results:\n"))
  cat(sprintf("    TRUE PTE = %.4f\n", PTE_true))
  cat(sprintf("    Mean PTE_hat = %.4f (SD = %.4f)\n",
              mean(df$PTE_hat, na.rm = TRUE), empirical_sd_PTE))
  cat(sprintf("    Bias = %.4f (%.1f%%)\n", bias_PTE, 100 * bias_PTE / PTE_true))

  cat(sprintf("\n  Computation:\n"))
  cat(sprintf("    Convergence rate = %.1f%%\n", 100 * convergence_rate))
  cat(sprintf("    Mean M = %.0f\n", mean_M))
  cat(sprintf("    Mean time = %.1f seconds\n", mean_time))
  cat(sprintf("    Total time = %.1f hours\n\n", sum(df$elapsed_time) / 3600))

  # Store
  all_results[[dgp_id]] <- list(
    dgp_id = dgp_id,
    dgp_config = dgp_config,
    n_reps = n_reps,
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
      mean_PTE_hat = mean(df$PTE_hat, na.rm = TRUE),
      bias_PTE = bias_PTE,
      empirical_sd_PTE = empirical_sd_PTE,
      convergence_rate = convergence_rate,
      mean_M = mean_M,
      mean_time = mean_time
    )
  )
}

# =============================================================================
# Save Combined Results
# =============================================================================

output_file <- "cluster/results/combined_results.rds"
saveRDS(all_results, output_file)

cat(sprintf("\nCombined results saved: %s\n", output_file))

# =============================================================================
# Summary Report
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
              s$rho_true, s$bias_rho,
              100 * s$bias_rho / abs(s$rho_true), 100 * s$coverage_rho))
  cat(sprintf("  PTE: PTE_true = %.4f, bias = %.4f (%.1f%%)\n",
              s$PTE_true, s$bias_PTE, 100 * s$bias_PTE / s$PTE_true))
  cat(sprintf("  Computation: Mean M = %.0f, Mean time = %.1f sec\n\n",
              s$mean_M, s$mean_time))
}

cat("=== COMPLETE ===\n")
