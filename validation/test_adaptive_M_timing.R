# Test Adaptive M: Timing and Convergence
#
# Compare:
# 1. Fixed M=500 (original, fast but unstable)
# 2. Fixed M=2000 (stable but slow)
# 3. Adaptive M (smart, hopefully faster than M=2000)

library(dplyr)

devtools::load_all()
source("explorations/calibrate_5level_x_dgp.R")

cat("\n=== Testing Adaptive M: Timing and Convergence ===\n\n")

# Setup
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
lambda <- 0.3

# Load true correlation
results_true <- readRDS("validation/results/true_correlation_5level.rds")
rho_true <- results_true$true_correlation

cat(sprintf("TRUE correlation: ρ = %.6f\n\n", rho_true))

# Generate test dataset
set.seed(2030)
n <- 5000
data_test <- generate_5level_x_data(n = n, p_X = p_X_0, params = params)

cat(sprintf("Test dataset: n = %d\n\n", n))

# =============================================================================
# Test 1: Fixed M=500 (Original)
# =============================================================================

cat("=== Test 1: Fixed M=500 (Original) ===\n\n")

t1_start <- Sys.time()

result1 <- tv_ball_correlation_IF_v2(
  data = data_test,
  lambda = lambda,
  M = 500,
  burn_in = 500,
  thin = 5,
  method = "importance_weighting",
  verbose = FALSE
)

t1_end <- Sys.time()
t1_elapsed <- as.numeric(difftime(t1_end, t1_start, units = "secs"))

bias1 <- result1$rho_hat - rho_true

cat(sprintf("Time: %.1f seconds\n", t1_elapsed))
cat(sprintf("ρ̂ = %.4f (bias = %.4f)\n", result1$rho_hat, bias1))
cat(sprintf("SE = %.4f\n", result1$se))
cat(sprintf("95%% CI: [%.4f, %.4f]\n\n", result1$ci_lower, result1$ci_upper))

# =============================================================================
# Test 2: Fixed M=2000 (Stable)
# =============================================================================

cat("=== Test 2: Fixed M=2000 (Stable) ===\n\n")

t2_start <- Sys.time()

result2 <- tv_ball_correlation_IF_v2(
  data = data_test,
  lambda = lambda,
  M = 2000,
  burn_in = 500,
  thin = 5,
  method = "importance_weighting",
  verbose = FALSE
)

t2_end <- Sys.time()
t2_elapsed <- as.numeric(difftime(t2_end, t2_start, units = "secs"))

bias2 <- result2$rho_hat - rho_true

cat(sprintf("Time: %.1f seconds\n", t2_elapsed))
cat(sprintf("ρ̂ = %.4f (bias = %.4f)\n", result2$rho_hat, bias2))
cat(sprintf("SE = %.4f\n", result2$se))
cat(sprintf("95%% CI: [%.4f, %.4f]\n\n", result2$ci_lower, result2$ci_upper))

# =============================================================================
# Test 3: Adaptive M
# =============================================================================

cat("=== Test 3: Adaptive M ===\n\n")

t3_start <- Sys.time()

result3 <- tv_ball_correlation_IF_adaptive(
  data = data_test,
  lambda = lambda,
  M_start = 300,
  M_increment = 300,
  M_max = 5000,
  tolerance = 0.01,  # Tighter tolerance
  n_stable = 3,  # Require stable window of 4 iterations
  burn_in = 500,
  thin = 5,
  method = "importance_weighting",
  verbose = TRUE
)

t3_end <- Sys.time()
t3_elapsed <- as.numeric(difftime(t3_end, t3_start, units = "secs"))

bias3 <- result3$rho_hat - rho_true

cat(sprintf("\nTime: %.1f seconds\n", t3_elapsed))
cat(sprintf("ρ̂ = %.4f (bias = %.4f)\n", result3$rho_hat, bias3))
cat(sprintf("SE = %.4f\n", result3$se))
cat(sprintf("95%% CI: [%.4f, %.4f]\n", result3$ci_lower, result3$ci_upper))
cat(sprintf("Converged: %s at M = %d\n", ifelse(result3$converged, "YES", "NO"), result3$M_final))

# Show convergence path
cat("\nConvergence path:\n")
cat(sprintf("%-10s %-12s %-12s\n", "M", "ρ̂", "Change"))
cat(strrep("-", 35), "\n")
for (i in seq_along(result3$M_history)) {
  change <- if (i == 1) NA else abs(result3$rho_history[i] - result3$rho_history[i-1])
  cat(sprintf("%-10d %-12.4f %-12s\n",
              result3$M_history[i],
              result3$rho_history[i],
              ifelse(is.na(change), "-", sprintf("%.4f", change))))
}

cat("\n\n")

# =============================================================================
# Summary Comparison
# =============================================================================

cat("=== COMPARISON SUMMARY ===\n\n")

comparison <- data.frame(
  Method = c("Fixed M=500", "Fixed M=2000", "Adaptive M"),
  M = c(500, 2000, result3$M_final),
  Time_sec = c(t1_elapsed, t2_elapsed, t3_elapsed),
  rho_hat = c(result1$rho_hat, result2$rho_hat, result3$rho_hat),
  Bias = c(bias1, bias2, bias3),
  SE = c(result1$se, result2$se, result3$se)
)

print(comparison, row.names = FALSE)

cat("\n")

# Time comparison
cat("Time comparison:\n")
cat(sprintf("  M=500:    %.1f sec (baseline)\n", t1_elapsed))
cat(sprintf("  M=2000:   %.1f sec (%.1fx slower)\n", t2_elapsed, t2_elapsed / t1_elapsed))
cat(sprintf("  Adaptive: %.1f sec (%.1fx slower than baseline)\n",
            t3_elapsed, t3_elapsed / t1_elapsed))

if (result3$converged) {
  cat(sprintf("  Adaptive converged at M=%d (%.0f%% of M=2000)\n",
              result3$M_final, 100 * result3$M_final / 2000))
}

cat("\n")

# Bias comparison
cat("Bias comparison:\n")
cat(sprintf("  M=500:    %.4f (%.1f%% relative)\n", bias1, 100 * bias1 / rho_true))
cat(sprintf("  M=2000:   %.4f (%.1f%% relative)\n", bias2, 100 * bias2 / rho_true))
cat(sprintf("  Adaptive: %.4f (%.1f%% relative)\n", bias3, 100 * abs(bias3) / rho_true))

cat("\n")

# =============================================================================
# Recommendation
# =============================================================================

cat("=== RECOMMENDATION ===\n\n")

if (result3$converged) {
  speedup <- t2_elapsed / t3_elapsed
  bias_improvement <- abs(bias1) / abs(bias3)

  cat("✓ Adaptive M successfully converged\n\n")

  cat("Benefits:\n")
  cat(sprintf("  - Achieves bias of %.4f (similar to M=2000)\n", abs(bias3)))
  cat(sprintf("  - %.1fx faster than fixed M=2000\n", speedup))
  cat(sprintf("  - %d%% reduction in bias vs M=500\n", round(100 * (1 - abs(bias3) / abs(bias1)))))

  cat("\nFor simulation studies:\n")
  cat(sprintf("  - Use adaptive M with tolerance=%.2f, n_stable=%d\n", result3$tolerance, result3$n_stable))
  cat(sprintf("  - Expected M ≈ %d per replication\n", result3$M_final))
  cat(sprintf("  - Time per rep: ~%.1f seconds\n", t3_elapsed))
  cat(sprintf("  - For 200 reps: ~%.1f minutes\n", 200 * t3_elapsed / 60))

} else {
  cat("⚠ Adaptive M did not converge within M_max\n\n")
  cat(sprintf("Consider increasing M_max or tolerance.\n"))
  cat(sprintf("Final M: %d, final change: %.4f\n",
              result3$M_final,
              abs(result3$rho_history[length(result3$rho_history)] -
                  result3$rho_history[length(result3$rho_history) - 1])))
}

cat("\n=== COMPLETE ===\n")
