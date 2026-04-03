#!/usr/bin/env Rscript
#
# Validation: Does Wasserstein minimax give useful bounds for functionals?
#

suppressPackageStartupMessages({
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all()
  }
})

cat("========================================================\n")
cat("Functional Estimation Validation\n")
cat("Testing if Wasserstein minimax bounds are useful\n")
cat("========================================================\n\n")

set.seed(2026)

# ----------------------------------------------------------------
# Scenario: Covariate Shift (where Wasserstein should shine)
# ----------------------------------------------------------------

cat("Scenario: Pure Covariate Shift\n")
cat("-------------------------------\n\n")

# Current study (P0)
n_current <- 500
X1_current <- rnorm(n_current, mean = 0, sd = 1)
X2_current <- rnorm(n_current, mean = 0, sd = 1)
A_current <- rbinom(n_current, 1, 0.5)

# Treatment effects depend on covariates (but same function in all studies)
true_delta_s <- function(X1, X2) 0.5 + 0.3 * X1
true_delta_y <- function(X1, X2) 0.4 + 0.2 * X1 + 0.1 * X2

S_current <- rnorm(n_current, mean = A_current * true_delta_s(X1_current, X2_current), sd = 1)
Y_current <- rnorm(n_current, mean = A_current * true_delta_y(X1_current, X2_current), sd = 1)

data_current <- data.frame(
  X1 = X1_current,
  X2 = X2_current,
  A = A_current,
  S = S_current,
  Y = Y_current
)

cat(sprintf("Current study: n = %d\n", n_current))
cat("Treatment effects: delta_S = 0.5 + 0.3*X1\n")
cat("                   delta_Y = 0.4 + 0.2*X1 + 0.1*X2\n\n")

# ----------------------------------------------------------------
# Generate future studies with covariate shift
# ----------------------------------------------------------------

cat("Generating future studies with covariate shift...\n\n")

n_future_studies <- 30
n_future <- 500

future_studies <- list()
true_correlations <- numeric(n_future_studies)

for (i in 1:n_future_studies) {
  # Shift covariate distribution
  shift_x1 <- rnorm(1, mean = 0, sd = 0.8)
  shift_x2 <- rnorm(1, mean = 0, sd = 0.8)

  X1_future <- rnorm(n_future, mean = shift_x1, sd = 1)
  X2_future <- rnorm(n_future, mean = shift_x2, sd = 1)
  A_future <- rbinom(n_future, 1, 0.5)

  # SAME treatment effect function (only X distribution changes)
  S_future <- rnorm(n_future, mean = A_future * true_delta_s(X1_future, X2_future), sd = 1)
  Y_future <- rnorm(n_future, mean = A_future * true_delta_y(X1_future, X2_future), sd = 1)

  future_studies[[i]] <- data.frame(
    X1 = X1_future,
    X2 = X2_future,
    A = A_future,
    S = S_future,
    Y = Y_future
  )

  # Compute true correlation in this study
  treated <- A_future == 1
  control <- A_future == 0

  if (sum(treated) > 10 && sum(control) > 10) {
    delta_s_obs <- mean(S_future[treated]) - mean(S_future[control])
    delta_y_obs <- mean(Y_future[treated]) - mean(Y_future[control])

    # For correlation, we need the empirical correlation in this study
    # Use plug-in estimator (not perfect but practical)
    true_correlations[i] <- delta_s_obs * delta_y_obs / (sd(S_future) * sd(Y_future))
  }
}

cat(sprintf("Generated %d future studies\n", n_future_studies))
cat(sprintf("True correlations: mean = %.3f, sd = %.3f, range = [%.3f, %.3f]\n\n",
            mean(true_correlations, na.rm = TRUE),
            sd(true_correlations, na.rm = TRUE),
            min(true_correlations, na.rm = TRUE),
            max(true_correlations, na.rm = TRUE)))

# ----------------------------------------------------------------
# Compute Wasserstein minimax bounds
# ----------------------------------------------------------------

cat("Computing Wasserstein minimax bounds...\n")

# Try different lambda_w values
lambda_w_values <- c(0.3, 0.5, 0.8, 1.0)

results <- list()

for (lambda_w in lambda_w_values) {
  cat(sprintf("  Lambda_W = %.2f...", lambda_w))

  result <- surrogate_inference_minimax_wasserstein(
    data_current,
    lambda_w = lambda_w,
    functional_type = "correlation",
    discretization_schemes = c("quantiles", "kmeans"),
    n_innovations = 300,  # Modest for speed
    verbose = FALSE
  )

  # Check coverage
  n_covered <- sum(true_correlations >= result$phi_star, na.rm = TRUE)
  coverage_rate <- n_covered / sum(!is.na(true_correlations))

  results[[as.character(lambda_w)]] <- list(
    lambda_w = lambda_w,
    phi_star = result$phi_star,
    coverage_rate = coverage_rate,
    n_covered = n_covered
  )

  cat(sprintf(" phi_star = %.3f, coverage = %.1f%%\n", result$phi_star, coverage_rate * 100))
}

cat("\n")

# ----------------------------------------------------------------
# Compare with TV-ball
# ----------------------------------------------------------------

cat("Computing TV-ball minimax for comparison...\n")

lambda_tv <- 0.3
result_tv <- surrogate_inference_minimax(
  data_current,
  lambda = lambda_tv,
  functional_type = "correlation",
  discretization_schemes = c("quantiles", "kmeans"),
  n_innovations = 300,
  verbose = FALSE
)

n_covered_tv <- sum(true_correlations >= result_tv$phi_star, na.rm = TRUE)
coverage_rate_tv <- n_covered_tv / sum(!is.na(true_correlations))

cat(sprintf("  Lambda = %.2f: phi_star = %.3f, coverage = %.1f%%\n\n",
            lambda_tv, result_tv$phi_star, coverage_rate_tv * 100))

# ----------------------------------------------------------------
# Analysis and Summary
# ----------------------------------------------------------------

cat("========================================================\n")
cat("Analysis\n")
cat("========================================================\n\n")

cat("1. Coverage by Lambda_W:\n")
cat("   (Does phi_star bound the true correlations?)\n\n")

for (lam_str in names(results)) {
  r <- results[[lam_str]]
  status <- if (r$coverage_rate >= 0.9) "✓ GOOD" else if (r$coverage_rate >= 0.75) "~ OK" else "✗ POOR"
  cat(sprintf("   Lambda_W = %.2f: %d/%d covered (%.1f%%) %s\n",
              r$lambda_w, r$n_covered, sum(!is.na(true_correlations)),
              r$coverage_rate * 100, status))
}

cat("\n")

cat("2. Comparison: Wasserstein vs TV-Ball\n\n")

# Pick lambda_w = 0.5 for comparison
r_w <- results[["0.5"]]

cat(sprintf("   Wasserstein (λ_W=0.5): %.3f (%.1f%% coverage)\n",
            r_w$phi_star, r_w$coverage_rate * 100))
cat(sprintf("   TV-ball (λ=0.3):       %.3f (%.1f%% coverage)\n",
            result_tv$phi_star, coverage_rate_tv * 100))

if (r_w$phi_star > result_tv$phi_star) {
  cat("   → Wasserstein less conservative (tighter bound)\n")
} else {
  cat("   → TV-ball less conservative (tighter bound)\n")
}

cat("\n")

cat("3. Are the bounds useful?\n\n")

min_true <- min(true_correlations, na.rm = TRUE)
mean_true <- mean(true_correlations, na.rm = TRUE)

cat(sprintf("   True values: min = %.3f, mean = %.3f\n", min_true, mean_true))
cat(sprintf("   Wasserstein bound: %.3f\n", r_w$phi_star))

if (r_w$phi_star < min_true * 0.8) {
  cat("   ✗ Bound too conservative (much lower than reality)\n")
} else if (r_w$phi_star > min_true) {
  cat("   ✗ Bound too optimistic (exceeds minimum)\n")
} else {
  gap <- min_true - r_w$phi_star
  relative_gap <- gap / abs(mean_true)
  cat(sprintf("   ✓ Bound reasonable: %.3f gap from minimum (%.1f%% of mean)\n",
              gap, relative_gap * 100))
}

cat("\n")

# ----------------------------------------------------------------
# Practical Interpretation
# ----------------------------------------------------------------

cat("========================================================\n")
cat("Practical Interpretation\n")
cat("========================================================\n\n")

cat("Scenario: Pure covariate shift\n")
cat("(X distribution changes, treatment effect function stays same)\n\n")

cat("Question: What's the worst-case correlation in future studies?\n\n")

cat(sprintf("Wasserstein answer (λ_W=0.5): At least %.3f\n", r_w$phi_star))
cat(sprintf("TV-ball answer (λ=0.3):       At least %.3f\n", result_tv$phi_star))
cat(sprintf("Reality (observed):            Minimum was %.3f\n\n", min_true))

if (r_w$coverage_rate >= 0.8 && result_tv$phi_star < r_w$phi_star) {
  cat("✓ Wasserstein provides tighter (less conservative) but still valid bounds\n")
  cat("  for covariate shift scenarios, as expected.\n\n")
} else if (r_w$coverage_rate >= 0.8) {
  cat("✓ Wasserstein provides valid bounds with good coverage.\n\n")
} else {
  cat("⚠ Coverage could be better - may need larger λ_W or more data.\n\n")
}

# ----------------------------------------------------------------
# Recommendation
# ----------------------------------------------------------------

cat("========================================================\n")
cat("Recommendation\n")
cat("========================================================\n\n")

if (r_w$coverage_rate >= 0.8) {
  cat("✓ VALIDATED: Wasserstein minimax bounds work for covariate shift.\n\n")

  cat("Use Wasserstein when:\n")
  cat("  - Primary concern is covariate shift (X distribution changes)\n")
  cat("  - Treatment effect function believed stable\n")
  cat("  - Want tighter bounds than TV-ball\n\n")

  cat("Use TV-ball when:\n")
  cat("  - Concern includes selection/confounding\n")
  cat("  - Treatment effect function may change\n")
  cat("  - Want maximum robustness\n\n")

  quit(status = 0)
} else {
  cat("⚠ NEEDS TUNING: Coverage below 80%.\n\n")
  cat("Suggestions:\n")
  cat("  - Increase λ_W (try 0.8 or 1.0)\n")
  cat("  - Increase M (more innovations)\n")
  cat("  - Check if covariate shift assumption holds\n\n")

  quit(status = 1)
}
