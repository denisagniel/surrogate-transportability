#!/usr/bin/env Rscript
# Validation study: Check if CI coverage achieves nominal 95% level
#
# This simulates the covariate shift scenario and checks if the influence
# function approach produces correct coverage.

library(dplyr)
library(parallel)

source("package/R/data_generators.R")
source("package/R/compute_treatment_effects.R")
source("package/R/generate_future_study.R")
source("package/R/surrogate_functionals.R")
source("package/R/inference_influence_function.R")

# Simulation parameters
N_REPS <- 500  # Number of replications
N_CURRENT <- 1000  # Current study sample size
LAMBDA <- 0.3  # Perturbation level
N_INNOVATIONS <- 1000  # M for influence function
ALPHA <- 1  # Dirichlet concentration

cat("=== CI Coverage Validation Study ===\n")
cat("Comparing influence function vs true value\n\n")
cat("Parameters:\n")
cat("  N replications:", N_REPS, "\n")
cat("  Current study n:", N_CURRENT, "\n")
cat("  Lambda:", LAMBDA, "\n")
cat("  Innovations M:", N_INNOVATIONS, "\n\n")

# Compute true value by simulation (large M)
cat("Computing true value (1 large simulation)...\n")
set.seed(42)
data_for_truth <- generate_study_data(
  n = 5000,  # Large sample for good estimate
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8)
)
truth_result <- surrogate_inference_if(
  data_for_truth,
  lambda = LAMBDA,
  n_innovations = 5000,  # Very large M for accurate truth
  functional_type = "correlation"
)
TRUE_VALUE <- truth_result$estimate
cat("True correlation at lambda =", LAMBDA, ":", round(TRUE_VALUE, 4), "\n\n")

# Run simulation study
cat("Running", N_REPS, "replications...\n")

run_one_rep <- function(rep_id) {
  set.seed(1000 + rep_id)

  # Generate current study data
  data <- generate_study_data(
    n = N_CURRENT,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  # Inference with influence function
  result <- surrogate_inference_if(
    data,
    lambda = LAMBDA,
    n_innovations = N_INNOVATIONS,
    functional_type = "correlation",
    alpha = ALPHA
  )

  # Check coverage
  covered <- (result$ci_lower <= TRUE_VALUE) & (TRUE_VALUE <= result$ci_upper)

  list(
    estimate = result$estimate,
    se = result$se,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    ci_width = result$ci_upper - result$ci_lower,
    covered = covered
  )
}

# Run in parallel
n_cores <- min(4, detectCores() - 1)
cat("Using", n_cores, "cores\n")
results <- mclapply(1:N_REPS, run_one_rep, mc.cores = n_cores)

# Extract results
estimates <- sapply(results, function(x) x$estimate)
ses <- sapply(results, function(x) x$se)
ci_lower <- sapply(results, function(x) x$ci_lower)
ci_upper <- sapply(results, function(x) x$ci_upper)
ci_widths <- sapply(results, function(x) x$ci_width)
covered <- sapply(results, function(x) x$covered)

# Compute coverage
coverage_rate <- mean(covered)

# Print results
cat("\n=== RESULTS ===\n\n")
cat("True value:", round(TRUE_VALUE, 4), "\n\n")

cat("Point estimates:\n")
cat("  Mean:", round(mean(estimates), 4), "\n")
cat("  Bias:", round(mean(estimates) - TRUE_VALUE, 4), "\n")
cat("  SD:", round(sd(estimates), 4), "\n")
cat("  RMSE:", round(sqrt(mean((estimates - TRUE_VALUE)^2)), 4), "\n\n")

cat("Standard errors:\n")
cat("  Mean SE:", round(mean(ses), 4), "\n")
cat("  SD of estimates:", round(sd(estimates), 4), "\n")
cat("  SE/SD ratio:", round(mean(ses) / sd(estimates), 3), "\n\n")

cat("Confidence intervals:\n")
cat("  Coverage rate:", round(coverage_rate * 100, 1), "%\n")
cat("  Target: 95%\n")
if (coverage_rate >= 0.94 && coverage_rate <= 0.96) {
  cat("  ✓ Coverage is within [94%, 96%] (PASS)\n")
} else if (coverage_rate >= 0.90) {
  cat("  ⚠ Coverage is between 90-94% (ACCEPTABLE)\n")
} else {
  cat("  ✗ Coverage is below 90% (FAIL)\n")
}
cat("  Mean CI width:", round(mean(ci_widths), 3), "\n")
cat("  Median CI width:", round(median(ci_widths), 3), "\n\n")

# Detailed diagnostics
cat("CI width distribution:\n")
cat("  Min:", round(min(ci_widths), 3), "\n")
cat("  Q1:", round(quantile(ci_widths, 0.25), 3), "\n")
cat("  Median:", round(median(ci_widths), 3), "\n")
cat("  Q3:", round(quantile(ci_widths, 0.75), 3), "\n")
cat("  Max:", round(max(ci_widths), 3), "\n\n")

# Save results
save(results, TRUE_VALUE, coverage_rate, file = "validation_coverage_results.rda")
cat("Results saved to: validation_coverage_results.rda\n")
