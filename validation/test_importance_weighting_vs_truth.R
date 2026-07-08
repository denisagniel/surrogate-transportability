# Test Importance Weighting Against TRUE Correlation
#
# Strategy:
# 1. Load true correlation computed analytically
# 2. Run N replications with importance weighting
# 3. Check bias, SE calibration, and CI coverage

library(dplyr)

# Load package functions
devtools::load_all()

source("explorations/calibrate_5level_x_dgp.R")

# =============================================================================
# Setup
# =============================================================================

cat("\n=== Testing Importance Weighting vs TRUE Correlation ===\n\n")

# Load true correlation
results_true <- readRDS("validation/results/true_correlation_5level.rds")
rho_true <- results_true$true_correlation
lambda <- results_true$lambda

cat(sprintf("TRUE correlation: ρ = %.6f\n", rho_true))
cat(sprintf("TV ball radius: λ = %.2f\n\n", lambda))

# Simulation parameters
N_reps <- 200  # Number of replications
n <- 5000      # Sample size (validated to give good CATE estimates)
M <- 500       # Number of Q samples
alpha <- 0.05  # Significance level

params <- list(
  gamma_A = 1.0,
  gamma_AX = 0.5,
  beta_A = 0.25,
  beta_AX = -0.3,
  beta_S = 0.9,
  beta_SX = -0.1,
  sigma_S = 0.5,
  sigma_Y = 0.5
)

p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)

cat(sprintf("Running %d replications with n=%d, M=%d\n\n", N_reps, n, M))

# =============================================================================
# Run Replications
# =============================================================================

results <- data.frame(
  rep = 1:N_reps,
  rho_hat = NA_real_,
  se = NA_real_,
  ci_lower = NA_real_,
  ci_upper = NA_real_,
  contains_truth = NA
)

set.seed(2026)

cat("Progress: ")
for (rep in 1:N_reps) {
  if (rep %% 20 == 0) cat(sprintf("%d ", rep))

  # Generate data
  data <- generate_5level_x_data(n = n, p_X = p_X_0, params = params)

  # Run importance weighting
  result <- tv_ball_correlation_IF_v2(
    data = data,
    lambda = lambda,
    M = M,
    burn_in = 1000,
    thin = 10,
    alpha = alpha,
    method = "importance_weighting",
    verbose = FALSE
  )

  # Store results
  results$rho_hat[rep] <- result$rho_hat
  results$se[rep] <- result$se
  results$ci_lower[rep] <- result$ci_lower
  results$ci_upper[rep] <- result$ci_upper
  results$contains_truth[rep] <- (result$ci_lower <= rho_true & rho_true <= result$ci_upper)
}

cat("\n\n")

# =============================================================================
# Compute Summary Statistics
# =============================================================================

cat("=== RESULTS ===\n\n")

# Bias
bias <- mean(results$rho_hat) - rho_true
cat(sprintf("Bias:\n"))
cat(sprintf("  TRUE ρ = %.6f\n", rho_true))
cat(sprintf("  Mean ρ̂ = %.6f\n", mean(results$rho_hat)))
cat(sprintf("  Bias = %.6f (%.2f%%)\n\n", bias, 100 * bias / rho_true))

# Standard errors
empirical_sd <- sd(results$rho_hat)
mean_se <- mean(results$se)
se_calibration <- empirical_sd / mean_se

cat(sprintf("Standard Error Calibration:\n"))
cat(sprintf("  Empirical SD(ρ̂) = %.6f\n", empirical_sd))
cat(sprintf("  Mean SE = %.6f\n", mean_se))
cat(sprintf("  SE Calibration = %.4f (should be ≈ 1.0)\n\n", se_calibration))

# Coverage
coverage <- mean(results$contains_truth)

cat(sprintf("Coverage:\n"))
cat(sprintf("  95%% CIs containing truth: %.1f%% (%d/%d)\n",
            100 * coverage, sum(results$contains_truth), N_reps))
cat(sprintf("  Target: 95.0%%\n\n"))

# Distribution of estimates
cat(sprintf("Distribution of ρ̂:\n"))
cat(sprintf("  Min: %.4f\n", min(results$rho_hat)))
cat(sprintf("  Q1:  %.4f\n", quantile(results$rho_hat, 0.25)))
cat(sprintf("  Median: %.4f\n", median(results$rho_hat)))
cat(sprintf("  Q3:  %.4f\n", quantile(results$rho_hat, 0.75)))
cat(sprintf("  Max: %.4f\n\n", max(results$rho_hat)))

# =============================================================================
# Assessment
# =============================================================================

cat("=== ASSESSMENT ===\n\n")

# Check bias
if (abs(bias) < 0.05) {
  cat("✓ Bias: GOOD (|bias| < 0.05)\n")
} else if (abs(bias) < 0.10) {
  cat("~ Bias: ACCEPTABLE (0.05 < |bias| < 0.10)\n")
} else {
  cat("✗ Bias: POOR (|bias| > 0.10)\n")
}

# Check SE calibration
if (se_calibration >= 0.9 & se_calibration <= 1.1) {
  cat("✓ SE Calibration: GOOD (0.9 < ratio < 1.1)\n")
} else if (se_calibration >= 0.8 & se_calibration <= 1.2) {
  cat("~ SE Calibration: ACCEPTABLE (0.8 < ratio < 1.2)\n")
} else {
  cat("✗ SE Calibration: POOR (ratio outside [0.8, 1.2])\n")
}

# Check coverage
if (coverage >= 0.93 & coverage <= 0.97) {
  cat("✓ Coverage: GOOD (93% < coverage < 97%)\n")
} else if (coverage >= 0.90 & coverage <= 0.98) {
  cat("~ Coverage: ACCEPTABLE (90% < coverage < 98%)\n")
} else {
  cat("✗ Coverage: POOR (coverage outside [90%, 98%])\n")
}

cat("\n")

# Overall assessment
if (abs(bias) < 0.05 & se_calibration >= 0.9 & se_calibration <= 1.1 &
    coverage >= 0.93 & coverage <= 0.97) {
  cat("==> OVERALL: EXCELLENT - All metrics within target ranges\n")
} else if (abs(bias) < 0.10 & se_calibration >= 0.8 & se_calibration <= 1.2 &
           coverage >= 0.90 & coverage <= 0.98) {
  cat("==> OVERALL: GOOD - All metrics acceptable\n")
} else {
  cat("==> OVERALL: NEEDS INVESTIGATION - Some metrics out of range\n")
}

# =============================================================================
# Save Results
# =============================================================================

dir.create("validation/results", showWarnings = FALSE, recursive = TRUE)

output <- list(
  rho_true = rho_true,
  lambda = lambda,
  n = n,
  M = M,
  N_reps = N_reps,
  results = results,
  summary = list(
    bias = bias,
    empirical_sd = empirical_sd,
    mean_se = mean_se,
    se_calibration = se_calibration,
    coverage = coverage
  )
)

saveRDS(output, "validation/results/importance_weighting_vs_truth.rds")
cat("\n\nResults saved to validation/results/importance_weighting_vs_truth.rds\n")

cat("\n=== COMPLETE ===\n")
