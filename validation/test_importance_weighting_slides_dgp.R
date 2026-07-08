# Test Importance Weighting on Slides DGP (Strong Negative Correlation)
#
# DGP 2: Modified slides parameters with decorrelated effect modification
# TRUE correlation: ρ = -0.885
#
# Faster parameters:
# - N_reps = 100 (vs 200)
# - M = 300 (vs 500)
# - burn_in = 500 (vs 1000)
# - thin = 5 (vs 10)
# This reduces MCMC iterations from 6000 to 2000 per rep (3x speedup)

library(dplyr)

# Load package functions
devtools::load_all()

# =============================================================================
# DGP: Slides (Discrete X)
# =============================================================================

generate_slides_discrete_x_data <- function(n, p_X, params) {
  X_levels <- c(-2, -1, 0, 1, 2)
  K <- length(X_levels)

  if (length(p_X) != K) stop("p_X must have length 5")
  if (abs(sum(p_X) - 1) > 1e-10) stop("p_X must sum to 1")

  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- rbinom(n, 1, 0.5)

  gamma_A <- params$gamma_A
  gamma_AX <- params$gamma_AX
  beta_A <- params$beta_A
  beta_AX <- params$beta_AX
  beta_S <- params$beta_S
  beta_SX <- params$beta_SX
  sigma_S <- params$sigma_S
  sigma_Y <- params$sigma_Y

  S <- (gamma_A + gamma_AX * X) * A + rnorm(n, sd = sigma_S)
  Y <- (beta_A + beta_AX * X) * A + beta_S * S + beta_SX * S * X +
       rnorm(n, sd = sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}

# =============================================================================
# Setup
# =============================================================================

cat("\n=== Testing Importance Weighting: Slides DGP ===\n\n")

# Load true correlation
results_true <- readRDS("validation/results/true_correlation_slides_discrete.rds")
rho_true <- results_true$true_correlation
lambda <- results_true$lambda
params <- results_true$params

cat(sprintf("TRUE correlation: ρ = %.6f (strong negative)\n", rho_true))
cat(sprintf("TV ball radius: λ = %.2f\n\n", lambda))

# Faster simulation parameters with larger sample size
N_reps <- 100  # 100 replications
n <- 10000     # Larger sample size for better CATE estimation
M <- 300       # Reduced from 500 for speed
burn_in <- 500 # Reduced from 1000 for speed
thin <- 5      # Reduced from 10 for speed
alpha <- 0.05

p_X_0 <- results_true$P0

cat("DGP Parameters (Slides - Discrete X):\n")
cat(sprintf("  γ_A = %.2f, γ_AX = %.2f\n", params$gamma_A, params$gamma_AX))
cat(sprintf("  β_A = %.2f, β_AX = %.2f\n", params$beta_A, params$beta_AX))
cat(sprintf("  β_S = %.2f, β_SX = %.2f\n\n", params$beta_S, params$beta_SX))

cat(sprintf("Simulation Settings (Larger Sample Size, Fast MCMC):\n"))
cat(sprintf("  N_reps = %d\n", N_reps))
cat(sprintf("  n = %d (vs 5000 in other tests, for better CATE estimation)\n", n))
cat(sprintf("  M = %d (vs 500 in full test)\n", M))
cat(sprintf("  burn_in = %d (vs 1000 in full test)\n", burn_in))
cat(sprintf("  thin = %d (vs 10 in full test)\n", thin))
cat(sprintf("  MCMC iterations/rep: %d (vs 6000 in full test, 3x speedup)\n\n",
            burn_in + M * thin))

cat(sprintf("Estimated time: ~20-25 minutes (100 reps × ~12 sec/rep)\n\n"))

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

set.seed(2027)

cat("Progress: ")
for (rep in 1:N_reps) {
  if (rep %% 10 == 0) cat(sprintf("%d ", rep))

  # Generate data
  data <- generate_slides_discrete_x_data(n = n, p_X = p_X_0, params = params)

  # Run importance weighting with faster settings
  result <- tv_ball_correlation_IF_v2(
    data = data,
    lambda = lambda,
    M = M,
    burn_in = burn_in,
    thin = thin,
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

cat("=== RESULTS: SLIDES DGP ===\n\n")

# Bias
bias <- mean(results$rho_hat) - rho_true
cat(sprintf("Bias:\n"))
cat(sprintf("  TRUE ρ = %.6f\n", rho_true))
cat(sprintf("  Mean ρ̂ = %.6f\n", mean(results$rho_hat)))
cat(sprintf("  Bias = %.6f (%.2f%%)\n\n", bias, 100 * bias / abs(rho_true)))

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
  burn_in = burn_in,
  thin = thin,
  N_reps = N_reps,
  results = results,
  summary = list(
    bias = bias,
    empirical_sd = empirical_sd,
    mean_se = mean_se,
    se_calibration = se_calibration,
    coverage = coverage
  ),
  dgp = "slides_discrete",
  params = params
)

saveRDS(output, "validation/results/importance_weighting_slides_dgp.rds")
cat("\n\nResults saved to validation/results/importance_weighting_slides_dgp.rds\n")

cat("\n=== COMPLETE ===\n")
