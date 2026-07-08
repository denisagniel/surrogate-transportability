# Quick test: Does IF method work with 5-level discrete X?

devtools::load_all(".", quiet = TRUE)

set.seed(2026)

message("=== Quick Test: 5-Level Discrete X ===\n")

# DGP parameters (from slides, calibrated for binary)
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

# P0 distribution (approximate N(0,1))
p_X_0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
X_levels <- c(-2, -1, 0, 1, 2)

# Step 1: Generate reference study with 5-level X
message("1. Generating reference study (n=300)...")
n <- 300
X <- sample(X_levels, size = n, replace = TRUE, prob = p_X_0)
A <- rbinom(n, 1, 0.5)
S <- (params$gamma_A + params$gamma_AX * X) * A + rnorm(n, sd = params$sigma_S)
Y <- (params$beta_A + params$beta_AX * X) * A + params$beta_S * S +
     params$beta_SX * S * X + rnorm(n, sd = params$sigma_Y)

data <- data.frame(X = X, A = A, S = S, Y = Y)

cat(sprintf("   Sample: %.1f%% A=1\n", mean(data$A) * 100))
cat(sprintf("   X distribution: %s\n",
            paste(sprintf("%.2f", table(data$X)/n), collapse = ", ")))
cat(sprintf("   Unique X values: %d\n", length(unique(data$X))))

# Step 2: Estimate correlation with IF method
message("\n2. Estimating correlation with IF method...")
result_IF <- tv_ball_correlation_IF(
  data = data,
  lambda = 0.3,
  M = 200,
  burn_in = 500,
  thin = 5,
  verbose = FALSE
)

cat(sprintf("   Estimated correlation: %.4f (SE = %.4f)\n",
            result_IF$rho_hat, result_IF$se))
cat(sprintf("   95%% CI: [%.4f, %.4f]\n",
            result_IF$ci_lower, result_IF$ci_upper))

# Step 3: Compute "true" correlation via large-sample simulation
message("\n3. Computing true correlation (50 studies, n=20k each)...")

source("explorations/calibrate_5level_x_dgp.R")

true_result <- compute_correlation_5level(
  p_X_0 = p_X_0,
  lambda = 0.3,
  params = params,
  n_studies = 50,
  n_per_study = 20000
)

cat(sprintf("   True correlation: %.4f\n", true_result$correlation))

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

# Assessment
message("\n=== Assessment ===")
if (abs(bias) < 0.2 && contains_truth) {
  message("✓ METHOD WORKS with 5-level X!")
  message("  Estimate is close to truth and CI contains truth")
} else {
  message("✗ Issues remain:")
  message(sprintf("  |Bias| = %.3f", abs(bias)))
  message(sprintf("  CI coverage: %s", ifelse(contains_truth, "YES", "NO")))
}

# Check if variance is reasonable (not near zero)
if (result_IF$se > 0.01) {
  message("✓ Standard error is reasonable (> 0.01)")
} else {
  message(sprintf("✗ Standard error too small: %.4f", result_IF$se))
}

# Check correlation magnitude
if (abs(result_IF$rho_hat) < 0.99) {
  message(sprintf("✓ Correlation is not perfect (|ρ̂| = %.3f < 0.99)", abs(result_IF$rho_hat)))
} else {
  message(sprintf("✗ Correlation near ±1 (|ρ̂| = %.3f)", abs(result_IF$rho_hat)))
}
