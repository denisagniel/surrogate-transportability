#!/usr/bin/env Rscript
# Validation: TV Ball Correlation IF with Slides DGP
#
# Tests tv_ball_correlation_IF() on the DGP from inst/presentation/slides.qmd
# (PTE Misleading Example). This DGP produces high PTE (~0.7) but near-zero
# correlation (~0.05), demonstrating surrogate quality divergence.
#
# Validation objectives:
# 1. Bias: |mean(ρ̂) - ρ_true| < 0.05
# 2. Coverage: 95% CIs contain ρ_true at least 94% of the time
# 3. Type I error: CIs exclude zero ≤ 6% of the time
# 4. Computation: Mean time < 30 sec per replication

library(tidyverse)
library(future.apply)

# Load package
devtools::load_all()

cat("================================================================\n")
cat("TV BALL CORRELATION IF VALIDATION: SLIDES DGP\n")
cat("================================================================\n\n")

# Source DGP generator
source("validation/dgp_slides_pte_misleading.R")

# ============================================================
# Parameters
# ============================================================

N <- 500           # Sample size
LAMBDA <- 0.55     # TV ball radius (covers X̄ ∈ [-1.5, 1.5] from slides)
M <- 500           # Number of future studies
N_REPS <- 500      # Monte Carlo replications (~80 min parallelized)
SEED_START <- 20260508  # Base seed for reproducibility

cat("Parameters:\n")
cat(sprintf("  n = %d (sample size)\n", N))
cat(sprintf("  λ = %.2f (TV ball radius)\n", LAMBDA))
cat(sprintf("  M = %d (future studies)\n", M))
cat(sprintf("  Replications = %d\n", N_REPS))
cat(sprintf("  Seed start = %d\n\n", SEED_START))

# ============================================================
# Compute True Correlation
# ============================================================

cat("Computing true correlation from DGP...\n")
cat("(Simulating 100 studies with n=10,000 each, X̄ ∈ [-1.5, 1.5])\n")

start_time <- Sys.time()
RHO_TRUE <- compute_true_correlation_slides(
  n_studies = 100,
  n_per_study = 10000,
  seed = SEED_START
)
elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

cat(sprintf("True correlation: %.4f (computed in %.1f sec)\n\n", RHO_TRUE, elapsed))

# ============================================================
# Single Replication Function
# ============================================================

run_single_rep <- function(rep_id, n, lambda, M, rho_true) {
  seed <- SEED_START + rep_id
  set.seed(seed)

  # Generate data from slides DGP at X̄ = 0 (P₀)
  data <- generate_dgp_slides(n, X_mean = 0, seed = seed)

  # Run IF inference
  start_time <- Sys.time()
  result <- tryCatch(
    {
      tv_ball_correlation_IF(
        data = data,
        lambda = lambda,
        M = M,
        verbose = FALSE
      )
    },
    error = function(e) {
      # Return NA on error
      list(
        rho_hat = NA_real_,
        se = NA_real_,
        ci_lower = NA_real_,
        ci_upper = NA_real_,
        error = as.character(e)
      )
    }
  )

  time_sec <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Return metrics
  tibble(
    rep = rep_id,
    rho_hat = result$rho_hat,
    se = result$se,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    bias = result$rho_hat - rho_true,
    abs_bias = abs(result$rho_hat - rho_true),
    coverage = (rho_true >= result$ci_lower) & (rho_true <= result$ci_upper),
    ci_includes_zero = (0 >= result$ci_lower) & (0 <= result$ci_upper),
    ci_width = result$ci_upper - result$ci_lower,
    time_sec = time_sec,
    error = if (!is.null(result$error)) result$error else NA_character_
  )
}

# ============================================================
# Run Replications in Parallel
# ============================================================

cat("Running replications in parallel...\n")
n_cores <- parallel::detectCores() - 1
cat(sprintf("Using %d cores\n\n", n_cores))

plan(multisession, workers = n_cores)

start_time_all <- Sys.time()

results <- future_lapply(
  X = 1:N_REPS,
  FUN = function(rep) {
    # Load package in each worker
    devtools::load_all(quiet = TRUE)
    source("validation/dgp_slides_pte_misleading.R")
    run_single_rep(rep, n = N, lambda = LAMBDA, M = M, rho_true = RHO_TRUE)
  },
  future.seed = TRUE
)

elapsed_all <- as.numeric(difftime(Sys.time(), start_time_all, units = "mins"))

# Combine results
results_df <- bind_rows(results)

# Check for errors
n_errors <- sum(!is.na(results_df$error))
if (n_errors > 0) {
  cat(sprintf("\n⚠️  WARNING: %d replications failed with errors\n", n_errors))
  cat("First error message:\n")
  cat(results_df$error[!is.na(results_df$error)][1], "\n\n")
}

# Remove failed replications for analysis
results_clean <- results_df %>% filter(!is.na(rho_hat))
n_success <- nrow(results_clean)

cat(sprintf("Completed: %d successful replications (%.1f min total)\n\n",
            n_success, elapsed_all))

# ============================================================
# Save Raw Results
# ============================================================

saveRDS(
  list(
    results = results_df,
    params = list(
      n = N, lambda = LAMBDA, M = M, n_reps = N_REPS,
      rho_true = RHO_TRUE, seed_start = SEED_START
    ),
    timestamp = Sys.time()
  ),
  "validation/results/tv_ball_IF_slides_dgp_raw.rds"
)

cat("Raw results saved to: validation/results/tv_ball_IF_slides_dgp_raw.rds\n\n")

# ============================================================
# Summary Statistics
# ============================================================

cat("================================================================\n")
cat("RESULTS SUMMARY\n")
cat("================================================================\n\n")

cat(sprintf("Sample: %d successful replications (out of %d)\n\n", n_success, N_REPS))

# Bias
cat("Bias:\n")
cat(sprintf("  Mean bias: %.4f\n", mean(results_clean$bias)))
cat(sprintf("  Median bias: %.4f\n", median(results_clean$bias)))
cat(sprintf("  RMSE: %.4f\n", sqrt(mean(results_clean$bias^2))))
cat(sprintf("  Mean absolute bias: %.4f\n", mean(results_clean$abs_bias)))

# Coverage
cat("\nCoverage:\n")
coverage_rate <- mean(results_clean$coverage, na.rm = TRUE)
coverage_se <- sqrt(coverage_rate * (1 - coverage_rate) / n_success)
cat(sprintf("  Coverage rate: %.3f (95%% CI: [%.3f, %.3f])\n",
            coverage_rate,
            coverage_rate - 1.96 * coverage_se,
            coverage_rate + 1.96 * coverage_se))

# Type I Error
cat("\nType I Error (H₀: ρ=0):\n")
type1_rate <- mean(!results_clean$ci_includes_zero, na.rm = TRUE)
type1_se <- sqrt(type1_rate * (1 - type1_rate) / n_success)
cat(sprintf("  Rate: %.3f (95%% CI: [%.3f, %.3f])\n",
            type1_rate,
            type1_rate - 1.96 * type1_se,
            type1_rate + 1.96 * type1_se))
cat(sprintf("  Target: ≤ 0.05 (allowing slack since ρ_true ≈ %.3f)\n", RHO_TRUE))

# CI Performance
cat("\nCI Performance:\n")
cat(sprintf("  Mean CI width: %.4f\n", mean(results_clean$ci_width, na.rm = TRUE)))
cat(sprintf("  SD CI width: %.4f\n", sd(results_clean$ci_width, na.rm = TRUE)))
cat(sprintf("  CIs including zero: %.1f%%\n",
            100 * mean(results_clean$ci_includes_zero, na.rm = TRUE)))

# Computational Performance
cat("\nComputational Performance:\n")
cat(sprintf("  Mean time: %.2f sec\n", mean(results_clean$time_sec)))
cat(sprintf("  Median time: %.2f sec\n", median(results_clean$time_sec)))
cat(sprintf("  SD time: %.2f sec\n", sd(results_clean$time_sec)))
cat(sprintf("  Total time: %.2f min\n", elapsed_all))

# Estimate Distribution
cat("\nEstimate Distribution:\n")
cat(sprintf("  Mean ρ̂: %.4f\n", mean(results_clean$rho_hat)))
cat(sprintf("  SD ρ̂: %.4f\n", sd(results_clean$rho_hat)))
cat(sprintf("  Min ρ̂: %.4f\n", min(results_clean$rho_hat)))
cat(sprintf("  Max ρ̂: %.4f\n", max(results_clean$rho_hat)))

# Standard Error Distribution
cat("\nStandard Error Distribution:\n")
cat(sprintf("  Mean SE: %.4f\n", mean(results_clean$se)))
cat(sprintf("  SD SE: %.4f\n", sd(results_clean$se)))

# ============================================================
# Validation Status
# ============================================================

cat("\n================================================================\n")
cat("VALIDATION STATUS\n")
cat("================================================================\n\n")

# Success criteria
bias_ok <- abs(mean(results_clean$bias)) < 0.05
coverage_ok <- coverage_rate >= 0.94
type1_ok <- type1_rate <= 0.06
time_ok <- mean(results_clean$time_sec) < 30

cat(sprintf("✓ Bias < 0.05: %s (%.4f)\n",
            ifelse(bias_ok, "PASS", "FAIL"),
            abs(mean(results_clean$bias))))

cat(sprintf("✓ Coverage ≥ 94%%: %s (%.1f%%)\n",
            ifelse(coverage_ok, "PASS", "FAIL"),
            100 * coverage_rate))

cat(sprintf("✓ Type I error ≤ 6%%: %s (%.1f%%)\n",
            ifelse(type1_ok, "PASS", "FAIL"),
            100 * type1_rate))

cat(sprintf("✓ Time < 30 sec: %s (%.1f sec)\n",
            ifelse(time_ok, "PASS", "FAIL"),
            mean(results_clean$time_sec)))

if (all(c(bias_ok, coverage_ok, type1_ok, time_ok))) {
  cat("\n🎉 VALIDATION PASSED\n")
  cat("\nConclusion:\n")
  cat("tv_ball_correlation_IF() correctly estimates near-zero correlation\n")
  cat("with unbiased estimates and correct coverage for the slides DGP.\n")
} else {
  cat("\n⚠️  VALIDATION ISSUES DETECTED\n")
  cat("\nFailed criteria:\n")
  if (!bias_ok) cat("  - Bias exceeds threshold\n")
  if (!coverage_ok) cat("  - Coverage below 94%\n")
  if (!type1_ok) cat("  - Type I error above 6%\n")
  if (!time_ok) cat("  - Computation time exceeds 30 sec\n")
}

cat("\n================================================================\n")
