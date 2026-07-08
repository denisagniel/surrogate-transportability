# Quick test of discrete X fix for tv_ball_correlation_IF

devtools::load_all(".", quiet = TRUE)
source("validation/dgp_discrete_x.R")

set.seed(2026)

message("=== Quick Test: Discrete X Fix ===\n")

# Step 1: Compute true correlation
message("1. Computing true correlation...")
true_result <- compute_true_correlation_discrete_x(
  p_X_0 = 0.5,
  lambda = 0.3,
  n_studies = 50,
  n_per_study = 20000
)

cat(sprintf("   True correlation: %.4f\n", true_result$correlation))
cat(sprintf("   p_X range: [%.2f, %.2f]\n",
            true_result$p_X_range[1], true_result$p_X_range[2]))

# Step 2: Generate reference study
message("\n2. Generating reference study (n=300)...")
data_P0 <- generate_dgp_discrete_x(n = 300, p_X = 0.5)

cat(sprintf("   Sample: %.1f%% X=1, %.1f%% A=1\n",
            mean(data_P0$X) * 100, mean(data_P0$A) * 100))
cat(sprintf("   Unique X values: %d\n", length(unique(data_P0$X))))

# Step 3: Estimate correlation
message("\n3. Estimating correlation with IF method...")
result_IF <- tv_ball_correlation_IF(
  data = data_P0,
  lambda = 0.3,
  M = 200,  # Smaller M for quick test
  burn_in = 500,
  thin = 5,
  verbose = FALSE
)

# Step 4: Compare
message("\n=== Comparison ===")
cat(sprintf("True correlation:      %.4f\n", true_result$correlation))
cat(sprintf("Estimated correlation: %.4f (SE = %.4f)\n",
            result_IF$rho_hat, result_IF$se))
cat(sprintf("95%% CI:                [%.4f, %.4f]\n",
            result_IF$ci_lower, result_IF$ci_upper))

contains_truth <- (result_IF$ci_lower <= true_result$correlation &&
                  true_result$correlation <= result_IF$ci_upper)
cat(sprintf("Contains truth?        %s\n", ifelse(contains_truth, "YES ✓", "NO ✗")))

bias <- result_IF$rho_hat - true_result$correlation
cat(sprintf("Bias:                  %.4f\n", bias))
cat(sprintf("Standardized bias:     %.2f SEs\n", bias / result_IF$se))

# Check if fix worked
message("\n=== Fix Status ===")
if (abs(bias) < 0.15 && contains_truth) {
  message("✓ FIX SUCCESSFUL: Estimate is close to truth and CI contains truth")
  message("  Ready to run full validation.")
} else {
  message("✗ FIX INCOMPLETE: Still have issues")
  message(sprintf("  |Bias| = %.3f (target: < 0.15)", abs(bias)))
  message(sprintf("  CI coverage: %s (target: YES)", ifelse(contains_truth, "YES", "NO")))
}
