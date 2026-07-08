# Quick Test: Importance Weighting vs TRUE Correlation
# Just 10 reps to see intermediate results while full test runs

library(dplyr)

# Load package functions
devtools::load_all()

source("explorations/calibrate_5level_x_dgp.R")

cat("\n=== Quick Test: Importance Weighting (10 reps) ===\n\n")

# Load true correlation
results_true <- readRDS("validation/results/true_correlation_5level.rds")
rho_true <- results_true$true_correlation
lambda <- results_true$lambda

cat(sprintf("TRUE correlation: ρ = %.6f\n", rho_true))
cat(sprintf("TV ball radius: λ = %.2f\n\n", lambda))

# Quick test parameters
N_reps <- 10
n <- 5000
M <- 500
alpha <- 0.05

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

cat(sprintf("Running %d replications...\n\n", N_reps))

results <- data.frame(
  rep = 1:N_reps,
  rho_hat = NA_real_,
  se = NA_real_,
  ci_lower = NA_real_,
  ci_upper = NA_real_,
  contains_truth = NA
)

set.seed(2026)

for (rep in 1:N_reps) {
  cat(sprintf("Rep %d/%d...\n", rep, N_reps))

  data <- generate_5level_x_data(n = n, p_X = p_X_0, params = params)

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

  results$rho_hat[rep] <- result$rho_hat
  results$se[rep] <- result$se
  results$ci_lower[rep] <- result$ci_lower
  results$ci_upper[rep] <- result$ci_upper
  results$contains_truth[rep] <- (result$ci_lower <= rho_true & rho_true <= result$ci_upper)

  cat(sprintf("  ρ̂ = %.4f (SE = %.4f), 95%% CI: [%.4f, %.4f], Contains truth: %s\n\n",
              result$rho_hat, result$se, result$ci_lower, result$ci_upper,
              ifelse(results$contains_truth[rep], "YES", "NO")))
}

cat("\n=== QUICK RESULTS (N=10) ===\n\n")

bias <- mean(results$rho_hat) - rho_true
empirical_sd <- sd(results$rho_hat)
mean_se <- mean(results$se)
se_calibration <- empirical_sd / mean_se
coverage <- mean(results$contains_truth)

cat(sprintf("Bias:\n"))
cat(sprintf("  TRUE ρ = %.6f\n", rho_true))
cat(sprintf("  Mean ρ̂ = %.6f\n", mean(results$rho_hat)))
cat(sprintf("  Bias = %.6f\n\n", bias))

cat(sprintf("Variability:\n"))
cat(sprintf("  Empirical SD(ρ̂) = %.6f\n", empirical_sd))
cat(sprintf("  Mean SE = %.6f\n", mean_se))
cat(sprintf("  SE Calibration = %.4f\n\n", se_calibration))

cat(sprintf("Coverage:\n"))
cat(sprintf("  95%% CIs containing truth: %d/%d (%.1f%%)\n\n",
            sum(results$contains_truth), N_reps, 100 * coverage))

cat("Note: These are preliminary results from N=10 reps.\n")
cat("Wait for full N=200 test to complete for final assessment.\n")

cat("\n=== COMPLETE ===\n")
