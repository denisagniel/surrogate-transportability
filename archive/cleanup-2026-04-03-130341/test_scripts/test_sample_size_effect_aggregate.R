#!/usr/bin/env Rscript
# Aggregate results from parallel sample size effect test

library(tidyverse)
library(here)
library(ggplot2)

cat("=============================================================================\n")
cat("AGGREGATING PHASE 1 RESULTS\n")
cat("=============================================================================\n\n")

# Read all individual results
results_dir <- "test_sample_size_results"

if (!dir.exists(results_dir)) {
  stop("Results directory not found: ", results_dir)
}

result_files <- list.files(results_dir, pattern = "^result_n.*\\.rds$", full.names = TRUE)

if (length(result_files) == 0) {
  stop("No result files found in ", results_dir)
}

cat("Found", length(result_files), "result files\n")
cat("Reading and combining...\n\n")

# Read all results
all_results <- map_dfr(result_files, readRDS)

cat("Total replications:", nrow(all_results), "\n")
cat("Successful:", sum(all_results$status == "success"), "\n")
cat("Failed:", sum(all_results$status == "failed"), "\n\n")

# =============================================================================
# Analysis: Compare Across Sample Sizes
# =============================================================================

cat("=============================================================================\n")
cat("COMPARATIVE ANALYSIS\n")
cat("=============================================================================\n\n")

# Summary by sample size
summary_by_n <- all_results %>%
  filter(status == "success") %>%
  group_by(n) %>%
  summarise(
    n_success = n(),
    coverage = mean(covered),
    coverage_se = sqrt(coverage * (1 - coverage) / n()),
    mean_bias = mean(bias),
    median_bias = median(bias),
    rmse = sqrt(mean(bias^2)),
    mean_ci_width = mean(ci_width),
    .groups = "drop"
  ) %>%
  arrange(n)

cat("SUMMARY BY SAMPLE SIZE:\n\n")
print(summary_by_n, n = Inf)
cat("\n")

# Key patterns
cat("KEY PATTERNS:\n\n")

# 1. Coverage trend
cat("1. COVERAGE TREND:\n")
for (i in 1:nrow(summary_by_n)) {
  n_val <- summary_by_n$n[i]
  cov <- summary_by_n$coverage[i]
  cov_se <- summary_by_n$coverage_se[i]
  status <- if (cov >= 0.90) "✓ GOOD" else if (cov >= 0.80) "~ OK" else "✗ POOR"
  cat(sprintf("   n=%4d: %5.1f%% (SE=%4.1f%%) %s\n", n_val, cov*100, cov_se*100, status))
}
cat("\n")

# 2. Bias trend
cat("2. BIAS TREND:\n")
for (i in 1:nrow(summary_by_n)) {
  n_val <- summary_by_n$n[i]
  bias <- summary_by_n$mean_bias[i]
  status <- if (abs(bias) < 0.01) "✓ LOW" else if (abs(bias) < 0.03) "~ MODERATE" else "✗ HIGH"
  cat(sprintf("   n=%4d: %7.4f %s\n", n_val, bias, status))
}
cat("\n")

# 3. RMSE trend
cat("3. RMSE TREND:\n")
for (i in 1:nrow(summary_by_n)) {
  n_val <- summary_by_n$n[i]
  rmse <- summary_by_n$rmse[i]
  cat(sprintf("   n=%4d: %6.4f\n", n_val, rmse))
}
cat("\n")

# Check if bias scales as 1/sqrt(n)
if (nrow(summary_by_n) >= 2) {
  bias_ratio <- abs(summary_by_n$mean_bias[1]) / abs(summary_by_n$mean_bias[nrow(summary_by_n)])
  n_ratio <- sqrt(summary_by_n$n[nrow(summary_by_n)] / summary_by_n$n[1])

  cat("4. BIAS SCALING:\n")
  cat("   Expected ratio (if bias ∝ 1/√n): ", round(n_ratio, 2), "\n")
  cat("   Observed ratio (bias_n=250 / bias_n=", summary_by_n$n[nrow(summary_by_n)], "): ",
      round(bias_ratio, 2), "\n")

  if (abs(bias_ratio - n_ratio) < 0.5) {
    cat("   → Bias scales roughly as 1/√n ✓\n")
  } else if (bias_ratio > n_ratio + 0.5) {
    cat("   → Bias decreases slower than 1/√n (fundamental issue)\n")
  } else {
    cat("   → Bias decreases faster than 1/√n (good news!)\n")
  }
  cat("\n")
}

# =============================================================================
# Decision
# =============================================================================

cat("=============================================================================\n")
cat("PHASE 1 DECISION\n")
cat("=============================================================================\n\n")

# Get results for n=2000
results_n2000 <- summary_by_n %>% filter(n == 2000)

if (nrow(results_n2000) == 0) {
  cat("ERROR: No successful replications for n=2000\n")
  cat("Cannot make decision - investigation failed.\n\n")
} else {
  coverage_2000 <- results_n2000$coverage
  bias_2000 <- results_n2000$mean_bias

  cat("Results for n=2000:\n")
  cat("  Coverage:  ", round(coverage_2000, 3), " (SE = ", round(results_n2000$coverage_se, 3), ")\n", sep = "")
  cat("  95% CI:    [", round(coverage_2000 - 1.96*results_n2000$coverage_se, 3), ", ",
      round(coverage_2000 + 1.96*results_n2000$coverage_se, 3), "]\n", sep = "")
  cat("  Mean bias: ", round(bias_2000, 4), "\n")
  cat("  RMSE:      ", round(results_n2000$rmse, 4), "\n\n")

  if (coverage_2000 >= 0.90) {
    cat("✓✓✓ PHASE 1: SUCCESS ✓✓✓\n\n")
    cat("Larger sample size SOLVES the problem!\n\n")
    cat("RECOMMENDATION:\n")
    cat("  - Use observation-level Wasserstein with n ≥ 1000\n")
    cat("  - Document sample size requirements\n")
    cat("  - No need for Phase 2 debiasing\n\n")
    cat("NEXT STEPS:\n")
    cat("  1. Run full coverage validation with n=2000\n")
    cat("  2. Update documentation\n")
    cat("  3. Add sample size guidance to package\n\n")

  } else if (coverage_2000 >= 0.85) {
    cat("~ PHASE 1: PARTIAL SUCCESS ~\n\n")
    cat("Larger sample size helps but insufficient.\n\n")
    cat("  Coverage improved from ", round(summary_by_n$coverage[1], 2),
        " to ", round(coverage_2000, 2), "\n")
    cat("  But still below target (0.90-0.95)\n\n")
    cat("RECOMMENDATION:\n")
    cat("  - Proceed to Phase 2 (systematic debiasing)\n")
    cat("  - Sample size helps but needs correction too\n\n")

  } else {
    cat("✗ PHASE 1: INSUFFICIENT ✗\n\n")
    cat("Larger sample size does NOT solve the problem.\n\n")
    cat("Coverage remains at ", round(coverage_2000, 2), " (target: 0.90+)\n\n")
    cat("RECOMMENDATION:\n")
    cat("  - PROCEED TO PHASE 2: Systematic debiasing approaches\n")
    cat("  - Selection bias is fundamental, not just small-sample\n\n")
    cat("PHASE 2 OPTIONS:\n")
    cat("  1. Larger conservative penalty (k > 3)\n")
    cat("  2. Shrinkage + DRO\n")
    cat("  3. Double robust estimation\n")
    cat("  4. Empirical Bayes shrinkage\n")
    cat("  5. Bayesian DRO\n\n")
  }
}

# =============================================================================
# Visualization
# =============================================================================

cat("=============================================================================\n")
cat("CREATING VISUALIZATION\n")
cat("=============================================================================\n\n")

# 1. Coverage by sample size
p1 <- ggplot(summary_by_n, aes(x = n, y = coverage)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = coverage - 1.96*coverage_se,
                    ymax = coverage + 1.96*coverage_se),
                width = 50) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.90, linetype = "dashed", color = "orange") +
  labs(
    title = "Coverage vs Sample Size",
    x = "Sample Size (n)",
    y = "Coverage",
    subtitle = "Target: 95% (dashed red), Acceptable: 90% (dashed orange)"
  ) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  theme_minimal(base_size = 12)

# 2. Bias by sample size
p2 <- ggplot(summary_by_n, aes(x = n, y = mean_bias)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
  labs(
    title = "Mean Bias vs Sample Size",
    x = "Sample Size (n)",
    y = "Mean Bias",
    subtitle = "Target: 0 (dashed gray)"
  ) +
  theme_minimal(base_size = 12)

# 3. RMSE by sample size
p3 <- ggplot(summary_by_n, aes(x = n, y = rmse)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  labs(
    title = "RMSE vs Sample Size",
    x = "Sample Size (n)",
    y = "RMSE"
  ) +
  theme_minimal(base_size = 12)

# 4. Bias distribution by sample size
results_success <- all_results %>% filter(status == "success")
p4 <- ggplot(results_success, aes(x = factor(n), y = bias)) +
  geom_boxplot() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
  labs(
    title = "Bias Distribution by Sample Size",
    x = "Sample Size (n)",
    y = "Bias (Estimate - Truth)"
  ) +
  theme_minimal(base_size = 12)

# Save plots
ggsave(here("test_sample_size_coverage.png"), p1, width = 8, height = 6)
ggsave(here("test_sample_size_bias.png"), p2, width = 8, height = 6)
ggsave(here("test_sample_size_rmse.png"), p3, width = 8, height = 6)
ggsave(here("test_sample_size_bias_dist.png"), p4, width = 8, height = 6)

cat("Plots saved:\n")
cat("  - test_sample_size_coverage.png\n")
cat("  - test_sample_size_bias.png\n")
cat("  - test_sample_size_rmse.png\n")
cat("  - test_sample_size_bias_dist.png\n\n")

# =============================================================================
# Save Results
# =============================================================================

results_list <- list(
  summary = summary_by_n,
  all_results = all_results,
  parameters = list(
    sample_sizes = unique(all_results$n),
    n_reps = max(all_results$rep),
    lambda_w = 0.5,
    n_bootstrap = 500
  )
)

saveRDS(results_list, here("test_sample_size_effect_results.rds"))
cat("Full results saved to: test_sample_size_effect_results.rds\n\n")

cat("=============================================================================\n")
cat("PHASE 1 ANALYSIS COMPLETE\n")
cat("=============================================================================\n")
