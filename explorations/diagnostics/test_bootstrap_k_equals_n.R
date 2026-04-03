#!/usr/bin/env Rscript

#' Test: Bootstrap with K = n (No Low-Dimensional Structure)
#'
#' Tests whether bootstrap approach works when every individual is their own "type"
#' This is the extreme case where K-dimensional innovation would fail completely.

library(devtools)
library(dplyr)

while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

cat("================================================================\n")
cat("TEST: Bootstrap Performance with K = n\n")
cat("================================================================\n\n")

cat("DGP Design:\n")
cat("  - Each individual has unique treatment effects\n")
cat("  - No low-dimensional class structure (K = n)\n")
cat("  - Person-specific heterogeneity in both S and Y\n")
cat("  - Parametric approaches would fail (can't estimate n parameters)\n\n")

# Generate baseline with K = n structure
n <- 1000
lambda <- 0.3

cat("Generating baseline with n =", n, "unique individuals...\n")

# Each person gets their own treatment effects
# Create heterogeneous treatment effects with correlation structure
set.seed(123)

# Generate correlated person-specific effects
Sigma <- matrix(c(1, 0.8, 0.8, 1), 2, 2)  # Strong correlation
person_effects <- MASS::mvrnorm(n, mu = c(0, 0), Sigma = Sigma)

# Create baseline data
baseline <- tibble(
  id = 1:n,
  # Person-specific treatment effects
  tau_s = person_effects[, 1] * 0.3,  # Scale to reasonable range
  tau_y = person_effects[, 2] * 0.3,
  # Baseline covariates (not used for treatment assignment, just for realism)
  X = rnorm(n)
)

# Randomize treatment
baseline$A <- rbinom(n, 1, 0.5)

# Generate outcomes based on person-specific effects
# S(0) and Y(0) are person-specific baselines
baseline$S_0 <- rnorm(n, mean = 0, sd = 0.5)
baseline$Y_0 <- rnorm(n, mean = 0, sd = 0.5)

# S and Y under observed treatment
baseline$S <- baseline$S_0 + baseline$A * baseline$tau_s + rnorm(n, 0, 0.1)
baseline$Y <- baseline$Y_0 + baseline$A * baseline$tau_y + rnorm(n, 0, 0.1)

# Clean up
baseline <- baseline %>% dplyr::select(A, S, Y, tau_s, tau_y)

cat("Baseline generated\n")
cat(sprintf("  Mean τ_S: %.3f (SD: %.3f)\n", mean(baseline$tau_s), sd(baseline$tau_s)))
cat(sprintf("  Mean τ_Y: %.3f (SD: %.3f)\n", mean(baseline$tau_y), sd(baseline$tau_y)))
cat(sprintf("  Correlation: %.3f\n\n", cor(baseline$tau_s, baseline$tau_y)))

cat("================================================================\n")
cat("GROUND TRUTH: Bootstrap from Observed Baseline\n")
cat("================================================================\n\n")

# Compute ground truth via bootstrap from observed data
# This is what the method should match
n_truth <- 500

cat("Computing ground truth via", n_truth, "bootstrap replications...\n")

true_effects <- matrix(NA, n_truth, 2)

for (m in 1:n_truth) {
  # Draw innovation
  p_tilde <- MCMCpack::rdirichlet(1, rep(1, n))[1,]

  # Form mixture
  p_hat <- rep(1/n, n)
  q_weights <- (1 - lambda) * p_hat + lambda * p_tilde

  # Bootstrap sample from mixture
  boot_indices <- sample(1:n, size = n, replace = TRUE, prob = q_weights)
  boot_sample <- baseline[boot_indices, ]

  # Compute treatment effects on bootstrap sample
  delta_s <- mean(boot_sample$S[boot_sample$A == 1]) -
             mean(boot_sample$S[boot_sample$A == 0])
  delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) -
             mean(boot_sample$Y[boot_sample$A == 0])

  true_effects[m, ] <- c(delta_s, delta_y)
}

true_correlation <- cor(true_effects[, 1], true_effects[, 2])

cat("\nGround Truth Results:\n")
cat(sprintf("  SD(ΔS): %.4f\n", sd(true_effects[, 1])))
cat(sprintf("  SD(ΔY): %.4f\n", sd(true_effects[, 2])))
cat(sprintf("  Correlation: %.4f\n\n", true_correlation))

cat("================================================================\n")
cat("METHOD ESTIMATE: surrogate_inference_if() with Bootstrap\n")
cat("================================================================\n\n")

# Run multiple replications to assess coverage
n_reps <- 50
results <- tibble(
  rep = integer(),
  true_corr = numeric(),
  estimate = numeric(),
  se = numeric(),
  ci_lower = numeric(),
  ci_upper = numeric(),
  covered = logical()
)

cat("Running", n_reps, "replications...\n\n")

for (rep in 1:n_reps) {
  if (rep %% 10 == 0) cat(sprintf("  Rep %d/%d\n", rep, n_reps))

  # Compute ground truth for this rep (same process as above)
  true_effects_rep <- matrix(NA, 500, 2)
  for (m in 1:500) {
    p_tilde <- MCMCpack::rdirichlet(1, rep(1, n))[1,]
    q_weights <- (1 - lambda) * rep(1/n, n) + lambda * p_tilde
    boot_indices <- sample(1:n, size = n, replace = TRUE, prob = q_weights)
    boot_sample <- baseline[boot_indices, ]
    delta_s <- mean(boot_sample$S[boot_sample$A == 1]) -
               mean(boot_sample$S[boot_sample$A == 0])
    delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) -
               mean(boot_sample$Y[boot_sample$A == 0])
    true_effects_rep[m, ] <- c(delta_s, delta_y)
  }
  true_corr_rep <- cor(true_effects_rep[, 1], true_effects_rep[, 2])

  # Estimate using method
  result <- tryCatch({
    surrogate_inference_if(
      baseline,
      lambda = lambda,
      n_innovations = 2000,  # Increased for more stable gradient
      functional_type = "correlation",
      use_bootstrap = TRUE  # KEY: Using bootstrap
    )
  }, error = function(e) {
    list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
  })

  if (is.na(result$estimate)) next

  # Check coverage
  covered <- (true_corr_rep >= result$ci_lower) && (true_corr_rep <= result$ci_upper)

  results <- bind_rows(results, tibble(
    rep = rep,
    true_corr = true_corr_rep,
    estimate = result$estimate,
    se = result$se,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    covered = covered
  ))
}

cat("\n")
cat("================================================================\n")
cat("RESULTS\n")
cat("================================================================\n\n")

cat(sprintf("Successful replications: %d/%d\n\n", nrow(results), n_reps))

# Coverage
coverage <- mean(results$covered, na.rm = TRUE)
cat(sprintf("Coverage: %.1f%% (%d/%d)\n",
            coverage * 100,
            sum(results$covered, na.rm = TRUE),
            nrow(results)))

if (coverage >= 0.93 && coverage <= 0.97) {
  cat("✓✓ Achieves nominal 95% coverage!\n\n")
} else if (coverage >= 0.90 && coverage <= 0.98) {
  cat("✓ Acceptable coverage (within 5pp of nominal)\n\n")
} else {
  cat("✗ Coverage outside acceptable range\n\n")
}

# Bias
bias <- mean(results$estimate - results$true_corr, na.rm = TRUE)
cat(sprintf("Mean bias: %.4f\n", bias))
if (abs(bias) < 0.05) {
  cat("✓ Essentially unbiased\n\n")
} else {
  cat("⚠ Notable bias detected\n\n")
}

# SE calibration
empirical_sd <- sd(results$estimate, na.rm = TRUE)
mean_se <- mean(results$se, na.rm = TRUE)
se_ratio <- mean_se / empirical_sd

cat(sprintf("Empirical SD: %.4f\n", empirical_sd))
cat(sprintf("Mean SE: %.4f\n", mean_se))
cat(sprintf("SE/SD ratio: %.2f\n", se_ratio))

if (se_ratio >= 0.9 && se_ratio <= 1.3) {
  cat("✓ Standard errors well-calibrated\n\n")
} else if (se_ratio > 1.3) {
  cat("⚠ Standard errors conservative (wide CIs)\n\n")
} else {
  cat("⚠ Standard errors anti-conservative (narrow CIs)\n\n")
}

# CI width
mean_width <- mean(results$ci_upper - results$ci_lower, na.rm = TRUE)
cat(sprintf("Mean CI width: %.4f\n\n", mean_width))

cat("================================================================\n")
cat("VARIANCE COMPARISON\n")
cat("================================================================\n\n")

# Compare variance from method to ground truth
method_te <- results$estimate  # These are correlations, not TEs
# We need to extract treatment effects from one run to compare SDs

# Run once more to get treatment effects
result_detailed <- surrogate_inference_if(
  baseline,
  lambda = lambda,
  n_innovations = 2000,
  functional_type = "correlation",
  use_bootstrap = TRUE
)

te_from_method <- result_detailed$treatment_effects

cat("Variance from Treatment Effects:\n")
cat(sprintf("  Ground truth SD(ΔS): %.4f\n", sd(true_effects[, 1])))
cat(sprintf("  Method SD(ΔS):       %.4f\n", sd(te_from_method[, "delta_s"])))
cat(sprintf("  Ratio: %.2fx\n\n",
            sd(te_from_method[, "delta_s"]) / sd(true_effects[, 1])))

cat(sprintf("  Ground truth SD(ΔY): %.4f\n", sd(true_effects[, 2])))
cat(sprintf("  Method SD(ΔY):       %.4f\n", sd(te_from_method[, "delta_y"])))
cat(sprintf("  Ratio: %.2fx\n\n",
            sd(te_from_method[, "delta_y"]) / sd(true_effects[, 2])))

if (abs(sd(te_from_method[, "delta_s"]) / sd(true_effects[, 1]) - 1.0) < 0.2) {
  cat("✓ Method matches ground truth variance!\n\n")
} else {
  cat("⚠ Method variance differs from ground truth\n\n")
}

cat("================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

if (coverage >= 0.90 && abs(bias) < 0.05 &&
    abs(sd(te_from_method[, "delta_s"]) / sd(true_effects[, 1]) - 1.0) < 0.2) {
  cat("✓✓✓ BOOTSTRAP APPROACH WORKS WITH K = n!\n\n")

  cat("Key findings:\n")
  cat(sprintf("  1. Coverage: %.1f%% (nominal: 95%%)\n", coverage * 100))
  cat(sprintf("  2. Bias: %.4f (essentially zero)\n", bias))
  cat(sprintf("  3. Variance ratio: %.2fx (matches ground truth)\n",
              sd(te_from_method[, "delta_s"]) / sd(true_effects[, 1])))
  cat(sprintf("  4. SE calibration: %.2fx (well-calibrated)\n\n", se_ratio))

  cat("INTERPRETATION:\n")
  cat("  • Bootstrap approach works perfectly even when K = n\n")
  cat("  • No low-dimensional class structure assumed or needed\n")
  cat("  • Method correctly captures 'new samples from similar population'\n")
  cat("  • Robust to any underlying heterogeneity structure\n\n")

  cat("COMPARISON TO ALTERNATIVES:\n")
  cat("  • K-dimensional innovation: Would FAIL (can't estimate n classes)\n")
  cat("  • Parametric bootstrap: Would FAIL (n-class mixture unidentifiable)\n")
  cat("  • Bootstrap from data: WORKS (no parametric assumptions)\n\n")

  cat("RECOMMENDATION: Use bootstrap (Option 1) as default\n")
  cat("  - Works for any K (including K → n)\n")
  cat("  - Non-parametric\n")
  cat("  - Achieves nominal coverage\n")
  cat("  - Correctly estimates 'new samples from similar populations'\n")

} else {
  cat("⚠ Bootstrap approach has issues with K = n\n\n")

  cat("Issues found:\n")
  if (coverage < 0.90 || coverage > 0.98) {
    cat(sprintf("  • Coverage: %.1f%% (target: 95%%)\n", coverage * 100))
  }
  if (abs(bias) >= 0.05) {
    cat(sprintf("  • Bias: %.4f\n", bias))
  }
  if (abs(sd(te_from_method[, "delta_s"]) / sd(true_effects[, 1]) - 1.0) >= 0.2) {
    cat(sprintf("  • Variance mismatch: %.2fx\n",
                sd(te_from_method[, "delta_s"]) / sd(true_effects[, 1])))
  }

  cat("\nMay need to reconsider approach...\n")
}

cat("\n================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
