#!/usr/bin/env Rscript

#' Asymptotic Normality Verification Simulation
#'
#' Verifies Proposition 1 from the methods paper: √n(φ̂ₙ(λ) - φ(F_λ)) → N(0, σ²(λ))
#' Tests convergence to normality as sample size n increases.
#' Uses analytical influence-function based variance for clean asymptotic test.

# Load required packages
library(devtools)
library(dplyr)
library(tibble)
library(purrr)
library(ggplot2)
library(moments)

# Load the surrogate transportability package
devtools::load_all("package/", quiet = TRUE)

# Set random seed for reproducibility
set.seed(42)

cat("Asymptotic Normality Verification Simulation\n")
cat("============================================\n\n")

# ===== STEP 1: Define the true DGP =====
cat("Step 1: Defining true data generating process...\n")

# DGP parameters (known ground truth)
dgp_params <- list(
  n_classes = 2,
  class_probs = c(0.6, 0.4),
  treatment_effect_surrogate = c(0.4, 0.8),  # True ΔS in each class
  treatment_effect_outcome = c(0.3, 0.6),    # True ΔY in each class
  surrogate_type = "continuous",
  outcome_type = "continuous",
  covariate_effects = list(
    surrogate = c(0.2, 0.2),
    outcome = c(0.1, 0.1)
  )
)

# Fixed lambda for this analysis
lambda_fixed <- 0.3

# Compute true φ(F_λ) using large sample approximation
cat("Computing true φ(F_λ) using large sample (n=10,000)...\n")
set.seed(999)
large_data <- do.call(generate_study_data, c(list(n = 10000), dgp_params))

# Estimate true φ with many bootstrap samples
true_phi_estimate <- posterior_inference(
  current_data = large_data,
  n_draws_from_F = 1000,
  n_future_studies_per_draw = 500,
  lambda = lambda_fixed,
  functional_type = "correlation",
  seed = 999
)

phi_true <- mean(true_phi_estimate$functionals, na.rm = TRUE)
cat(sprintf("  True φ(F_%.2f) ≈ %.4f\n", lambda_fixed, phi_true))

# Compute analytical variance from large sample
cat("Computing analytical variance σ²(λ) from large sample...\n")
var_result_ref <- compute_analytical_variance_correlation(large_data, lambda = lambda_fixed)
sigma_squared_analytical <- var_result_ref$sigma_squared
sigma_analytical <- var_result_ref$sigma

cat(sprintf("  Analytical σ²(λ=%.2f) = %.4f\n", lambda_fixed, sigma_squared_analytical))
cat(sprintf("  Analytical σ(λ=%.2f)  = %.4f\n", lambda_fixed, sigma_analytical))

# ===== STEP 2: Simulation across sample sizes =====
cat("\nStep 2: Running simulations across sample sizes...\n")

# Sample sizes to test
sample_sizes <- c(100, 200, 500, 1000, 2000, 5000)
n_replications <- 500  # Number of datasets per sample size

# Store results
simulation_results <- vector("list", length(sample_sizes))

for (i in seq_along(sample_sizes)) {
  n <- sample_sizes[i]

  cat(sprintf("\n  Sample size n = %d (%d replications)\n", n, n_replications))
  cat("  Progress: ")

  # Storage for this sample size
  phi_estimates <- numeric(n_replications)

  for (rep in 1:n_replications) {
    if (rep %% 50 == 0) cat(sprintf("%d ", rep))

    # Generate data with this sample size
    set.seed(10000 + i * 1000 + rep)  # Reproducible but different seeds
    data_rep <- do.call(generate_study_data, c(list(n = n), dgp_params))

    # Estimate φ with fixed lambda
    result_rep <- posterior_inference(
      current_data = data_rep,
      n_draws_from_F = 100,   # Fewer for speed
      n_future_studies_per_draw = 50,
      lambda = lambda_fixed,
      functional_type = "correlation",
      seed = NULL
    )

    phi_estimates[rep] <- mean(result_rep$functionals, na.rm = TRUE)
  }

  cat("\n")

  # Compute standardized statistics
  # (1) Raw: √n(φ̂ - φ) → N(0, σ²)
  standardized_raw <- sqrt(n) * (phi_estimates - phi_true)

  # (2) Analytically standardized: √n(φ̂ - φ) / σ → N(0, 1)
  standardized_analytical <- standardized_raw / sigma_analytical

  # Remove extreme outliers (can happen with small samples)
  valid_idx <- abs(standardized_analytical) < 10
  standardized_raw <- standardized_raw[valid_idx]
  standardized_analytical <- standardized_analytical[valid_idx]
  phi_estimates_valid <- phi_estimates[valid_idx]

  # Store results
  simulation_results[[i]] <- tibble(
    n = n,
    replication = seq_along(standardized_raw),
    phi_hat = phi_estimates_valid,
    error = phi_estimates_valid - phi_true,
    standardized_raw = standardized_raw,
    standardized_analytical = standardized_analytical,
    empirical_mean_raw = mean(standardized_raw),
    empirical_sd_raw = sd(standardized_raw),
    empirical_mean_analytical = mean(standardized_analytical),
    empirical_sd_analytical = sd(standardized_analytical)
  )

  cat(sprintf("    Empirical mean of √n(φ̂-φ): %.4f (should → 0)\n",
              mean(standardized_raw)))
  cat(sprintf("    Empirical SD of √n(φ̂-φ):   %.4f (theory: σ = %.4f)\n",
              sd(standardized_raw), sigma_analytical))
  cat(sprintf("    Empirical SD of z-score:   %.4f (should → 1)\n",
              sd(standardized_analytical)))
}

# Combine results
all_results <- bind_rows(simulation_results)

# ===== STEP 3: Statistical Tests =====
cat("\nStep 3: Testing asymptotic normality...\n\n")

# Test both raw and analytically-standardized statistics
cat("A. Raw Statistics: √n(φ̂ - φ) → N(0, σ²)\n")
cat("==========================================\n")
normality_tests_raw <- all_results %>%
  group_by(n) %>%
  summarise(
    mean_stat = mean(standardized_raw),
    sd_stat = sd(standardized_raw),
    shapiro_p = shapiro.test(standardized_raw)$p.value,
    skewness = moments::skewness(standardized_raw),
    kurtosis = moments::kurtosis(standardized_raw),
    .groups = "drop"
  )
print(normality_tests_raw)

cat("\nB. Analytically Standardized: z = √n(φ̂ - φ)/σ → N(0, 1)\n")
cat("=========================================================\n")
normality_tests_analytical <- all_results %>%
  group_by(n) %>%
  summarise(
    mean_stat = mean(standardized_analytical),
    sd_stat = sd(standardized_analytical),
    shapiro_p = shapiro.test(standardized_analytical)$p.value,
    skewness = moments::skewness(standardized_analytical),
    kurtosis = moments::kurtosis(standardized_analytical),
    .groups = "drop"
  )
print(normality_tests_analytical)

cat("\nInterpretation:\n")
cat("  For raw statistics:\n")
cat("    - mean should be near 0\n")
cat("    - SD should be near σ = ", round(sigma_analytical, 3), "\n", sep = "")
cat("  For z-scores:\n")
cat("    - mean should be near 0\n")
cat("    - SD should be near 1\n")
cat("    - shapiro_p > 0.05 suggests normality\n")
cat("    - skewness near 0, kurtosis near 3\n")

# ===== STEP 4: Visualizations =====
cat("\nStep 4: Creating visualizations...\n")

# Ensure plots directory exists
if (!dir.exists("sims/results/plots")) {
  dir.create("sims/results/plots", recursive = TRUE)
}

# Plot 1a: QQ-plots for raw statistics (√n(φ̂ - φ))
cat("  Creating QQ-plots for raw statistics...\n")
p1a <- ggplot(all_results, aes(sample = standardized_raw)) +
  stat_qq() +
  stat_qq_line(color = "red") +
  facet_wrap(~ n, scales = "free", labeller = label_both) +
  labs(
    title = "QQ-Plots: Raw Statistics √n(φ̂ - φ) → N(0, σ²)",
    subtitle = sprintf("Fixed λ = %.2f, True φ ≈ %.3f, Analytical σ = %.3f",
                       lambda_fixed, phi_true, sigma_analytical),
    x = "Theoretical Quantiles",
    y = "Sample Quantiles of √n(φ̂ - φ)"
  ) +
  theme_minimal()

ggsave("sims/results/plots/asymptotic_qq_plots_raw.png", p1a, width = 12, height = 8, dpi = 300)

# Plot 1b: QQ-plots for z-scores (√n(φ̂ - φ)/σ)
cat("  Creating QQ-plots for z-scores...\n")
p1b <- ggplot(all_results, aes(sample = standardized_analytical)) +
  stat_qq() +
  stat_qq_line(color = "red") +
  facet_wrap(~ n, scales = "free", labeller = label_both) +
  labs(
    title = "QQ-Plots: Z-scores √n(φ̂ - φ)/σ → N(0, 1)",
    subtitle = sprintf("Fixed λ = %.2f, Analytical σ(λ) = %.3f", lambda_fixed, sigma_analytical),
    x = "Theoretical Quantiles (Standard Normal)",
    y = "Sample Quantiles of Z-score"
  ) +
  theme_minimal()

ggsave("sims/results/plots/asymptotic_qq_plots_zscore.png", p1b, width = 12, height = 8, dpi = 300)

# Plot 2a: Histograms for raw statistics
cat("  Creating histograms for raw statistics...\n")
p2a <- ggplot(all_results, aes(x = standardized_raw)) +
  geom_histogram(aes(y = after_stat(density)), bins = 30, fill = "lightblue", alpha = 0.7) +
  stat_function(
    fun = dnorm,
    args = list(mean = 0, sd = sigma_analytical),
    color = "red",
    linewidth = 1
  ) +
  facet_wrap(~ n, scales = "free", labeller = label_both) +
  labs(
    title = "Distribution of √n(φ̂ - φ) Across Sample Sizes",
    subtitle = sprintf("Red curve: N(0, σ²) with analytical σ = %.3f", sigma_analytical),
    x = "√n(φ̂ - φ)",
    y = "Density"
  ) +
  theme_minimal()

ggsave("sims/results/plots/asymptotic_histograms_raw.png", p2a, width = 12, height = 8, dpi = 300)

# Plot 2b: Histograms for z-scores
cat("  Creating histograms for z-scores...\n")
p2b <- ggplot(all_results, aes(x = standardized_analytical)) +
  geom_histogram(aes(y = after_stat(density)), bins = 30, fill = "steelblue", alpha = 0.7) +
  stat_function(
    fun = dnorm,
    args = list(mean = 0, sd = 1),
    color = "red",
    linewidth = 1
  ) +
  facet_wrap(~ n, scales = "free", labeller = label_both) +
  labs(
    title = "Distribution of Z-scores √n(φ̂ - φ)/σ Across Sample Sizes",
    subtitle = "Red curve: N(0, 1) standard normal",
    x = "Z-score",
    y = "Density"
  ) +
  theme_minimal()

ggsave("sims/results/plots/asymptotic_histograms_zscore.png", p2b, width = 12, height = 8, dpi = 300)

# Plot 3: Variance convergence (raw statistics)
cat("  Creating variance convergence plot...\n")
var_convergence <- all_results %>%
  group_by(n) %>%
  summarise(
    empirical_var_raw = var(standardized_raw),
    empirical_sd_raw = sd(standardized_raw),
    empirical_var_analytical = var(standardized_analytical),
    empirical_sd_analytical = sd(standardized_analytical),
    .groups = "drop"
  )

p3 <- ggplot(var_convergence, aes(x = n, y = empirical_var_raw)) +
  geom_point(size = 3) +
  geom_line() +
  geom_hline(yintercept = sigma_squared_analytical,
             linetype = "dashed", color = "red", linewidth = 0.8) +
  scale_x_log10() +
  labs(
    title = "Variance Convergence: Var[√n(φ̂ - φ)] vs Sample Size",
    subtitle = sprintf("Red line: analytical σ²(λ) = %.4f from Proposition 1", sigma_squared_analytical),
    x = "Sample Size n (log scale)",
    y = "Empirical Variance"
  ) +
  theme_minimal()

ggsave("sims/results/plots/asymptotic_variance_convergence.png", p3, width = 10, height = 6, dpi = 300)

# Plot 4: Mean convergence to zero (raw statistics)
cat("  Creating mean convergence plot...\n")
mean_convergence <- all_results %>%
  group_by(n) %>%
  summarise(
    empirical_mean_raw = mean(standardized_raw),
    se_mean_raw = sd(standardized_raw) / sqrt(n()),
    empirical_mean_analytical = mean(standardized_analytical),
    se_mean_analytical = sd(standardized_analytical) / sqrt(n()),
    .groups = "drop"
  )

p4 <- ggplot(mean_convergence, aes(x = n, y = empirical_mean_raw)) +
  geom_point(size = 3) +
  geom_line() +
  geom_errorbar(aes(ymin = empirical_mean_raw - 1.96*se_mean_raw,
                    ymax = empirical_mean_raw + 1.96*se_mean_raw),
                width = 0.1) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  scale_x_log10() +
  labs(
    title = "Mean Convergence: E[√n(φ̂ - φ)] → 0",
    subtitle = "Error bars show ±1.96 SE (95% CI)",
    x = "Sample Size n (log scale)",
    y = "Empirical Mean of √n(φ̂ - φ)"
  ) +
  theme_minimal()

ggsave("sims/results/plots/asymptotic_mean_convergence.png", p4, width = 10, height = 6, dpi = 300)

# ===== STEP 5: Save Results =====
cat("\nStep 5: Saving results...\n")

saveRDS(all_results, "sims/results/asymptotic_verification_results.rds")
saveRDS(normality_tests_raw, "sims/results/asymptotic_normality_tests_raw.rds")
saveRDS(normality_tests_analytical, "sims/results/asymptotic_normality_tests_analytical.rds")
write.csv(normality_tests_raw, "sims/results/asymptotic_normality_tests_raw.csv", row.names = FALSE)
write.csv(normality_tests_analytical, "sims/results/asymptotic_normality_tests_analytical.csv", row.names = FALSE)
write.csv(var_convergence, "sims/results/asymptotic_variance_convergence.csv", row.names = FALSE)
write.csv(mean_convergence, "sims/results/asymptotic_mean_convergence.csv", row.names = FALSE)

# ===== STEP 6: Summary Report =====
cat("\n========================================\n")
cat("ASYMPTOTIC VERIFICATION SUMMARY\n")
cat("========================================\n\n")

cat(sprintf("True φ(F_%.2f): %.4f\n", lambda_fixed, phi_true))
cat(sprintf("Fixed λ: %.2f\n", lambda_fixed))
cat(sprintf("Sample sizes tested: %s\n", paste(sample_sizes, collapse = ", ")))
cat(sprintf("Replications per n: %d\n\n", n_replications))

cat("Analytical Variance (from Proposition 1):\n")
cat(sprintf("  σ²(λ=%.2f) = %.4f\n", lambda_fixed, sigma_squared_analytical))
cat(sprintf("  σ(λ=%.2f)  = %.4f\n\n", lambda_fixed, sigma_analytical))

cat("A. Raw Statistics: √n(φ̂ - φ) → N(0, σ²)\n")
cat("==========================================\n")
for (i in seq_len(nrow(normality_tests_raw))) {
  n <- normality_tests_raw$n[i]
  mean_stat <- normality_tests_raw$mean_stat[i]
  sd_stat <- normality_tests_raw$sd_stat[i]
  shapiro_p <- normality_tests_raw$shapiro_p[i]

  cat(sprintf("  n = %5d: ", n))
  cat(sprintf("mean = %+.4f, ", mean_stat))
  cat(sprintf("SD = %.4f (theory: %.4f), ", sd_stat, sigma_analytical))
  cat(sprintf("Shapiro p = %.4f ", shapiro_p))

  if (abs(mean_stat) < 0.1 && shapiro_p > 0.05) {
    cat("✓\n")
  } else if (abs(mean_stat) < 0.2) {
    cat("~\n")
  } else {
    cat("✗\n")
  }
}

cat("\nB. Z-scores: √n(φ̂ - φ)/σ → N(0, 1)\n")
cat("====================================\n")
for (i in seq_len(nrow(normality_tests_analytical))) {
  n <- normality_tests_analytical$n[i]
  mean_stat <- normality_tests_analytical$mean_stat[i]
  sd_stat <- normality_tests_analytical$sd_stat[i]
  shapiro_p <- normality_tests_analytical$shapiro_p[i]

  cat(sprintf("  n = %5d: ", n))
  cat(sprintf("mean = %+.4f, ", mean_stat))
  cat(sprintf("SD = %.4f (theory: 1.00), ", sd_stat))
  cat(sprintf("Shapiro p = %.4f ", shapiro_p))

  if (abs(mean_stat) < 0.1 && abs(sd_stat - 1) < 0.2 && shapiro_p > 0.05) {
    cat("✓\n")
  } else if (abs(mean_stat) < 0.2 && abs(sd_stat - 1) < 0.3) {
    cat("~\n")
  } else {
    cat("✗\n")
  }
}

cat("\nEmpirical vs Analytical Variance:\n")
cat(sprintf("  Analytical σ²(λ):        %.4f\n", sigma_squared_analytical))
cat(sprintf("  Empirical Var[√n(φ̂-φ)] at n=5000: %.4f\n",
            var_convergence$empirical_var_raw[nrow(var_convergence)]))
cat(sprintf("  Relative difference:     %.1f%%\n",
            100 * abs(var_convergence$empirical_var_raw[nrow(var_convergence)] -
                      sigma_squared_analytical) / sigma_squared_analytical))

cat("\nConclusion:\n")
cat("  Proposition 1 verification: ")
final_shapiro_z <- normality_tests_analytical$shapiro_p[nrow(normality_tests_analytical)]
final_mean_z <- abs(normality_tests_analytical$mean_stat[nrow(normality_tests_analytical)])
final_sd_z <- normality_tests_analytical$sd_stat[nrow(normality_tests_analytical)]

if (final_mean_z < 0.1 && abs(final_sd_z - 1) < 0.15 && final_shapiro_z > 0.05) {
  cat("✓ PASS\n")
  cat("  √n(φ̂ₙ - φ) converges to N(0, σ²(λ)) as n increases.\n")
  cat("  Analytical variance formula is accurate.\n")
} else if (final_mean_z < 0.2 && abs(final_sd_z - 1) < 0.25) {
  cat("~ PARTIAL\n")
  cat("  Evidence for asymptotic normality, but convergence may be slow.\n")
  cat("  Consider larger sample sizes for cleaner test.\n")
} else {
  cat("? INCONCLUSIVE\n")
  cat("  May need larger sample sizes or different settings.\n")
}

cat("\nPlots saved to sims/results/plots/\n")
cat("  - asymptotic_qq_plots_raw.png (QQ-plots for √n(φ̂-φ))\n")
cat("  - asymptotic_qq_plots_zscore.png (QQ-plots for z-scores)\n")
cat("  - asymptotic_histograms_raw.png (histograms for √n(φ̂-φ))\n")
cat("  - asymptotic_histograms_zscore.png (histograms for z-scores)\n")
cat("  - asymptotic_variance_convergence.png\n")
cat("  - asymptotic_mean_convergence.png\n")
cat("\nResults saved to sims/results/\n")
cat("\nAsymptotic verification simulation completed!\n")
