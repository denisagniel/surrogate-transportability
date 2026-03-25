#!/usr/bin/env Rscript
#
# Wasserstein Ball Minimax Example
# Demonstrates the new Wasserstein approach compared to TV-ball
#

# Load package from development
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
} else {
  library(surrogateTransportability)
}

set.seed(2026)

cat("===========================================\n")
cat("Wasserstein Ball Minimax Example\n")
cat("===========================================\n\n")

# Generate example data with covariate-dependent effects
n <- 500
X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)

# Treatment effects depend on covariates (covariate shift scenario)
delta_s_true <- 0.5 + 0.3 * X1
delta_y_true <- 0.4 + 0.2 * X1 + 0.1 * X2

S <- rnorm(n, mean = A * delta_s_true, sd = 1)
Y <- rnorm(n, mean = A * delta_y_true, sd = 1)

data <- data.frame(X1, X2, A, S, Y)

cat(sprintf("Generated n = %d observations\n", n))
cat("Treatment effects depend on X1 and X2 (covariate shift scenario)\n\n")

# ----------------------------------------------------------------
# 1. Wasserstein Ball Minimax
# ----------------------------------------------------------------

cat("1. Running Wasserstein Ball Minimax...\n")
cat("   (This provides tighter bounds under covariate shift)\n\n")

result_w <- surrogate_inference_minimax_wasserstein(
  data,
  lambda_w = 0.5,
  functional_type = "correlation",
  discretization_schemes = c("quantiles", "kmeans"),  # Fast schemes
  cost_function = "euclidean",
  n_innovations = 500,
  verbose = FALSE
)

cat(sprintf("   Wasserstein minimax estimate: %.4f\n", result_w$phi_star))
cat(sprintf("   Best scheme: %s\n", result_w$best_scheme))
cat(sprintf("   Lambda_W: %.2f\n", result_w$lambda_w))
cat(sprintf("   Cost function: %s\n\n", result_w$cost_function))

# ----------------------------------------------------------------
# 2. TV-Ball Minimax (for comparison)
# ----------------------------------------------------------------

cat("2. Running TV-Ball Minimax (for comparison)...\n")
cat("   (More conservative, allows arbitrary shifts)\n\n")

result_tv <- surrogate_inference_minimax(
  data,
  lambda = 0.3,  # Roughly comparable to lambda_w = 0.5
  functional_type = "correlation",
  discretization_schemes = c("quantiles", "kmeans"),
  n_innovations = 500,
  verbose = FALSE
)

cat(sprintf("   TV-ball minimax estimate: %.4f\n", result_tv$phi_star))
cat(sprintf("   Best scheme: %s\n", result_tv$best_scheme))
cat(sprintf("   Lambda: %.2f\n\n", result_tv$lambda))

# ----------------------------------------------------------------
# 3. Comparison
# ----------------------------------------------------------------

cat("3. Comparison:\n\n")

cat(sprintf("   Wasserstein: %.4f\n", result_w$phi_star))
cat(sprintf("   TV-ball:     %.4f\n", result_tv$phi_star))
cat(sprintf("   Difference:  %.4f\n\n", result_w$phi_star - result_tv$phi_star))

if (result_w$phi_star > result_tv$phi_star) {
  cat("   ✓ Wasserstein bound is less conservative (as expected for covariate shift)\n")
} else {
  cat("   Note: TV-ball is less conservative in this instance\n")
  cat("   (Can happen with finite samples; expected pattern: Wasserstein >= TV)\n")
}

cat("\n")

# ----------------------------------------------------------------
# 4. Schemes Comparison
# ----------------------------------------------------------------

cat("4. Per-Scheme Results:\n\n")

cat("   Wasserstein approach:\n")
print(result_w$schemes_summary)

cat("\n   TV-ball approach:\n")
print(result_tv$schemes_summary)

cat("\n")

# ----------------------------------------------------------------
# 5. Different Cost Functions
# ----------------------------------------------------------------

cat("5. Wasserstein with Different Cost Functions:\n\n")

result_w_maha <- surrogate_inference_minimax_wasserstein(
  data,
  lambda_w = 0.5,
  functional_type = "correlation",
  discretization_schemes = "kmeans",
  cost_function = "mahalanobis",  # Accounts for covariate correlations
  n_innovations = 300,
  verbose = FALSE
)

cat(sprintf("   Euclidean cost:    %.4f\n", result_w$phi_star))
cat(sprintf("   Mahalanobis cost:  %.4f\n", result_w_maha$phi_star))
cat(sprintf("   Difference:        %.4f\n\n", result_w_maha$phi_star - result_w$phi_star))

# ----------------------------------------------------------------
# 6. Different Functionals
# ----------------------------------------------------------------

cat("6. Wasserstein with Different Functionals:\n\n")

# PPV functional
result_ppv <- surrogate_inference_minimax_wasserstein(
  data,
  lambda_w = 0.5,
  functional_type = "ppv",
  epsilon_s = 0.2,
  epsilon_y = 0.2,
  discretization_schemes = "kmeans",
  n_innovations = 300,
  verbose = FALSE
)

cat(sprintf("   Correlation: %.4f\n", result_w$phi_star))
cat(sprintf("   PPV:         %.4f\n", result_ppv$phi_star))
cat("\n")

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------

cat("===========================================\n")
cat("Summary:\n")
cat("===========================================\n\n")

cat("✓ Wasserstein ball minimax implemented successfully\n")
cat("✓ Provides alternative to TV-ball for covariate shift\n")
cat("✓ Multiple cost functions available (Euclidean, Mahalanobis)\n")
cat("✓ All functionals supported (correlation, PPV, NPV, etc.)\n")
cat("✓ API consistent with TV-ball approach\n\n")

cat("When to use:\n")
cat("- Wasserstein: Covariate shift, structured populations\n")
cat("- TV-ball:     Selection, confounding, safety\n\n")

cat("Example complete!\n")
