#!/usr/bin/env Rscript
# QUICK COVERAGE VALIDATION: Sample Splitting Method (Reduced parameters for testing)
#
# This is a faster version for initial validation.
# For final results, use the full version with:
#   - n_reps = 500+
#   - n_bootstrap = 500
#   - All 5 DGPs

# Copy the full script but with reduced parameters
source(here::here("sims/scripts/25_sample_splitting_coverage.R"), local = TRUE)

# Override parameters for quick run
cat("=============================================================================\n")
cat("QUICK VALIDATION (Reduced parameters for testing)\n")
cat("=============================================================================\n\n")

n_reps_quick <- 20  # Instead of 100
n_bootstrap_quick <- 100  # Instead of 500
dgps_quick <- list(baseline = dgps$baseline)  # Just baseline DGP

cat("Quick run parameters:\n")
cat(sprintf("  Replications: %d (full: 100)\n", n_reps_quick))
cat(sprintf("  Bootstrap: %d (full: 500)\n", n_bootstrap_quick))
cat(sprintf("  DGPs: 1 (full: 5)\n\n"))

# Run quick validation
all_results_quick <- list()
summary_stats_quick <- list()

for (dgp_name in names(dgps_quick)) {
  dgp <- dgps_quick[[dgp_name]]

  results <- run_coverage_study(
    dgp = dgp,
    n_reps = n_reps_quick,
    n = n,
    lambda_w = lambda_w,
    split_ratio = split_ratio,
    n_bootstrap = n_bootstrap_quick,
    confidence_level = confidence_level,
    verbose = TRUE
  )

  all_results_quick[[dgp_name]] <- results

  summary_stats_quick[[dgp_name]] <- analyze_coverage_results(
    results = results,
    dgp_name = dgp$name,
    confidence_level = confidence_level,
    verbose = TRUE
  )
}

cat("\n")
cat("=============================================================================\n")
cat("QUICK VALIDATION COMPLETE\n")
cat("=============================================================================\n\n")

if (!is.null(summary_stats_quick$baseline) &&
    !is.null(summary_stats_quick$baseline$coverage)) {
  coverage_quick <- summary_stats_quick$baseline$coverage
  cat(sprintf("Quick validation coverage: %.3f\n", coverage_quick))

  if (coverage_quick >= 0.90) {
    cat("✓ Looks promising! Coverage >= 90%\n")
    cat("\nNext step: Run full validation with:\n")
    cat("  Rscript sims/scripts/25_sample_splitting_coverage.R\n")
    cat("  (Est. time: 2-3 hours for all 5 DGPs × 100 reps × 500 bootstrap)\n")
  } else {
    cat("⚠ Coverage below 90% - needs investigation\n")
  }
} else {
  cat("⚠ No valid results from quick validation\n")
}

# Save quick results
output_file_quick <- here::here("sims/results/sample_splitting_coverage_quick.rds")
dir.create(dirname(output_file_quick), showWarnings = FALSE, recursive = TRUE)

saveRDS(list(
  results = all_results_quick,
  summary = summary_stats_quick,
  parameters = list(
    n_reps = n_reps_quick,
    n = n,
    lambda_w = lambda_w,
    split_ratio = split_ratio,
    n_bootstrap = n_bootstrap_quick,
    confidence_level = confidence_level
  ),
  date = Sys.Date()
), output_file_quick)

cat(sprintf("\nQuick results saved to: %s\n", output_file_quick))
