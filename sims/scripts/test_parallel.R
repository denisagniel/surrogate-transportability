#!/usr/bin/env Rscript

#' Test parallelization of nested bootstrap
#' Minimal parameters to verify speedup

library(devtools)
library(dplyr)
library(tibble)

devtools::load_all("package/", quiet = TRUE)

set.seed(12345)

# Very small parameters for quick test
N_BASELINE <- 300
N_BASELINE_RESAMPLES <- 10
N_BOOTSTRAP <- 20
N_MC_DRAWS <- 10

cat("================================================================\n")
cat("PARALLELIZATION TEST\n")
cat("================================================================\n\n")

cat("Parameters (minimal for speed):\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Baseline resamples: %d\n", N_BASELINE_RESAMPLES))
cat(sprintf("  Bootstrap samples: %d\n", N_BOOTSTRAP))
cat(sprintf("  MC draws: %d\n", N_MC_DRAWS))
cat(sprintf("  Total inner studies: %d\n", N_BASELINE_RESAMPLES * N_BOOTSTRAP * N_MC_DRAWS))

# Generate baseline once
baseline <- generate_study_data(
  n = N_BASELINE,
  n_classes = 2,
  class_probs = c(0.5, 0.5),
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8),
  surrogate_type = "continuous",
  outcome_type = "continuous"
)

cat("\n----------------------------------------------------------------\n")
cat("Run 1: Serial (parallel = FALSE)\n")
cat("----------------------------------------------------------------\n")

start_serial <- Sys.time()

result_serial <- posterior_inference(
  baseline,
  n_draws_from_F = N_BOOTSTRAP,
  n_future_studies_per_draw = N_MC_DRAWS,
  n_baseline_resamples = N_BASELINE_RESAMPLES,
  lambda = 0.1,
  functional_type = "correlation",
  innovation_type = "bayesian_bootstrap",
  parallel = FALSE
)

time_serial <- as.numeric(difftime(Sys.time(), start_serial, units = "secs"))
cat(sprintf("\nTime (serial): %.2f seconds\n", time_serial))

cat("\n----------------------------------------------------------------\n")
cat("Run 2: Parallel (parallel = TRUE)\n")
cat("----------------------------------------------------------------\n")

# Check available cores
if (requireNamespace("parallel", quietly = TRUE)) {
  n_cores <- parallel::detectCores()
  cat(sprintf("Detected %d cores\n", n_cores))
  cat(sprintf("Using %d cores (leaving 1 free)\n\n", n_cores - 1))
} else {
  cat("parallel package not available\n")
}

start_parallel <- Sys.time()

result_parallel <- posterior_inference(
  baseline,
  n_draws_from_F = N_BOOTSTRAP,
  n_future_studies_per_draw = N_MC_DRAWS,
  n_baseline_resamples = N_BASELINE_RESAMPLES,
  lambda = 0.1,
  functional_type = "correlation",
  innovation_type = "bayesian_bootstrap",
  parallel = TRUE
)

time_parallel <- as.numeric(difftime(Sys.time(), start_parallel, units = "secs"))
cat(sprintf("\nTime (parallel): %.2f seconds\n", time_parallel))

cat("\n================================================================\n")
cat("COMPARISON\n")
cat("================================================================\n\n")

cat(sprintf("Serial time:   %.2f sec\n", time_serial))
cat(sprintf("Parallel time: %.2f sec\n", time_parallel))
cat(sprintf("Speedup:       %.2fx\n", time_serial / time_parallel))
cat(sprintf("Efficiency:    %.1f%%\n", 100 * (time_serial / time_parallel) / (n_cores - 1)))

cat("\n----------------------------------------------------------------\n")
cat("Results comparison (should be similar):\n")
cat("----------------------------------------------------------------\n")
cat(sprintf("Serial   - Mean: %.3f, SE: %.4f, CI: [%.3f, %.3f]\n",
            result_serial$summary$mean, result_serial$summary$se,
            result_serial$summary$ci_lower, result_serial$summary$ci_upper))
cat(sprintf("Parallel - Mean: %.3f, SE: %.4f, CI: [%.3f, %.3f]\n",
            result_parallel$summary$mean, result_parallel$summary$se,
            result_parallel$summary$ci_lower, result_parallel$summary$ci_upper))

cat("\n================================================================\n")
cat("SCALING ESTIMATES\n")
cat("================================================================\n\n")

full_scale_studies <- 100 * 100 * 50  # Full validation parameters
current_studies <- N_BASELINE_RESAMPLES * N_BOOTSTRAP * N_MC_DRAWS

cat(sprintf("Current: %d inner studies\n", current_studies))
cat(sprintf("Full validation: %d inner studies\n", full_scale_studies))
cat(sprintf("Scale factor: %.1fx\n\n", full_scale_studies / current_studies))

cat("Estimated time per replication (1000 reps × 4 scenarios):\n")
cat(sprintf("  Serial:   %.1f min/rep → %.1f hours total\n",
            time_serial * (full_scale_studies / current_studies) / 60,
            1000 * 4 * time_serial * (full_scale_studies / current_studies) / 3600))
cat(sprintf("  Parallel: %.1f min/rep → %.1f hours total\n",
            time_parallel * (full_scale_studies / current_studies) / 60,
            1000 * 4 * time_parallel * (full_scale_studies / current_studies) / 3600))

cat("\n================================================================\n")
cat("RECOMMENDATION\n")
cat("================================================================\n\n")

speedup <- time_serial / time_parallel
if (speedup > 1.5) {
  cat(sprintf("✓ Parallelization working! %.1fx speedup achieved.\n", speedup))
  cat("  Recommend using parallel = TRUE for validation studies.\n")
} else {
  cat("⚠ Parallelization overhead may not be worth it for small problems.\n")
  cat("  May still be valuable for full validation (500k+ studies per rep).\n")
}

if (full_scale_studies / current_studies > 20) {
  cat("\n⚠ Full scale will take much longer. Consider:\n")
  cat("  - Running on cluster (SLURM)\n")
  cat("  - Reducing parameters (e.g., 50 baseline resamples instead of 100)\n")
  cat("  - Running overnight with parallel = TRUE\n")
}

cat("\n================================================================\n")
