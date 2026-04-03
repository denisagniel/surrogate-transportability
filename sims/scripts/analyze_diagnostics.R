#!/usr/bin/env Rscript
#' Analyze Diagnostic Results
#'
#' Loads and analyzes the comprehensive diagnostics to identify root cause

library(tidyverse)
library(here)

cat("========================================\n")
cat("Diagnostic Results Analysis\n")
cat("========================================\n\n")

# Load diagnostic results
diag_file <- here("sims/results/coverage_diagnostics.rds")

if (!file.exists(diag_file)) {
  stop("Diagnostic results not found. Run diagnostic_coverage_failure.R first.")
}

diag <- readRDS(diag_file)

cat("Loaded diagnostics from:", format(diag$timestamp), "\n")
cat("Settings:", diag$settings$n, "obs,", diag$settings$scenario,
    ", λ =", diag$settings$lambda, ", J =", diag$settings$J, "\n\n")

# ============================================
# SUMMARY TABLE
# ============================================

cat("========================================\n")
cat("SUMMARY: All Diagnostics\n")
cat("========================================\n\n")

summary_table <- tribble(
  ~Test, ~Approach, ~Coverage, ~Bias, ~Mean_Est, ~Status,

  "1. Discretization",
  "Discretized types (current)",
  diag$d1_true_types$coverage_disc,
  diag$d1_true_types$bias_disc,
  diag$d1_true_types$mean_est_disc,
  "BASELINE",

  "1. Discretization",
  "True types (oracle)",
  diag$d1_true_types$coverage_true,
  diag$d1_true_types$bias_true,
  diag$d1_true_types$mean_est_true,
  if(diag$d1_true_types$coverage_true > 0.90) "✓ FIXES" else "✗ FAILS",

  "2. Ensemble",
  "RF only",
  diag$d2_schemes$coverage_rf,
  NA_real_,
  diag$d2_schemes$mean_est_rf,
  if(diag$d2_schemes$coverage_rf > 0.90) "✓ FIXES" else "✗ FAILS",

  "2. Ensemble",
  "Quantiles only",
  diag$d2_schemes$coverage_quantiles,
  NA_real_,
  diag$d2_schemes$mean_est_quantiles,
  if(diag$d2_schemes$coverage_quantiles > 0.90) "✓ FIXES" else "✗ FAILS",

  "2. Ensemble",
  "K-means only",
  diag$d2_schemes$coverage_kmeans,
  NA_real_,
  diag$d2_schemes$mean_est_kmeans,
  if(diag$d2_schemes$coverage_kmeans > 0.90) "✓ FIXES" else "✗ FAILS",

  "2. Ensemble",
  "Ensemble (min)",
  diag$d2_schemes$coverage_ensemble,
  NA_real_,
  diag$d2_schemes$mean_est_ensemble,
  "BASELINE",

  "4. Implementation",
  "Closed-form",
  NA_real_,
  diag$d4_closed_form_vs_sampling$bias_closed,
  diag$d4_closed_form_vs_sampling$mean_closed,
  if(abs(diag$d4_closed_form_vs_sampling$bias_closed) < 0.01) "✓ UNBIASED" else "✗ BIASED",

  "4. Implementation",
  "Sampling (check)",
  NA_real_,
  diag$d4_closed_form_vs_sampling$bias_sampling,
  diag$d4_closed_form_vs_sampling$mean_sampling,
  if(abs(diag$d4_closed_form_vs_sampling$bias_sampling) < 0.01) "✓ UNBIASED" else "✗ BIASED",

  "7. Fundamental",
  "Type-level (J=16)",
  if(!is.null(diag$d7_obs_vs_type$coverage_type)) diag$d7_obs_vs_type$coverage_type else NA_real_,
  if(!is.null(diag$d7_obs_vs_type$bias_type)) diag$d7_obs_vs_type$bias_type else NA_real_,
  if(!is.null(diag$d7_obs_vs_type$mean_est_type)) diag$d7_obs_vs_type$mean_est_type else NA_real_,
  if(!is.null(diag$d7_obs_vs_type$skipped) && diag$d7_obs_vs_type$skipped) "⊘ SKIPPED" else "BASELINE",

  "7. Fundamental",
  "Observation-level (n-dim)",
  if(!is.null(diag$d7_obs_vs_type$coverage_obs)) diag$d7_obs_vs_type$coverage_obs else NA_real_,
  if(!is.null(diag$d7_obs_vs_type$bias_obs)) diag$d7_obs_vs_type$bias_obs else NA_real_,
  if(!is.null(diag$d7_obs_vs_type$mean_est_obs)) diag$d7_obs_vs_type$mean_est_obs else NA_real_,
  if(!is.null(diag$d7_obs_vs_type$coverage_obs) && diag$d7_obs_vs_type$coverage_obs > 0.90) "✓ FIXES" else if(!is.null(diag$d7_obs_vs_type$skipped) && diag$d7_obs_vs_type$skipped) "⊘ SKIPPED" else "✗ FAILS"
)

print(summary_table, n = Inf)

cat("\nTruth mean:", round(diag$d1_true_types$mean_truth, 4), "\n\n")

# ============================================
# DIAGNOSTIC 3: J analysis
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 3: Effect of J\n")
cat("========================================\n\n")

print(diag$d3_increasing_J$summary, n = Inf)

# ============================================
# DIAGNOSTIC 6: CI analysis
# ============================================

cat("\n========================================\n")
cat("DIAGNOSTIC 6: Point Estimate vs CI\n")
cat("========================================\n\n")

cat("Coverage:", round(diag$d6_ci_construction$coverage, 3), "\n")
cat("Truth below CI:", round(diag$d6_ci_construction$pct_truth_below, 3), "\n")
cat("Truth above CI:", round(diag$d6_ci_construction$pct_truth_above, 3), "\n")
cat("Mean Z-score:", round(diag$d6_ci_construction$mean_z_score, 2),
    "(should be ~0)\n")
cat("SD Z-score:", round(diag$d6_ci_construction$sd_z_score, 2),
    "(should be ~1)\n")
cat("Mean estimate:", round(diag$d6_ci_construction$mean_estimate, 4), "\n")
cat("Mean truth:", round(diag$d6_ci_construction$mean_truth, 4), "\n\n")

# ============================================
# ROOT CAUSE IDENTIFICATION
# ============================================

cat("========================================\n")
cat("ROOT CAUSE IDENTIFICATION\n")
cat("========================================\n\n")

root_causes <- list()

# Test 1: Discretization mismatch
if (diag$d1_true_types$coverage_true > 0.90 &&
    diag$d1_true_types$coverage_disc < 0.70) {
  root_causes$discretization <- list(
    severity = "CRITICAL",
    evidence = sprintf("True types give %.1f%% coverage, discretized only %.1f%%",
                      100 * diag$d1_true_types$coverage_true,
                      100 * diag$d1_true_types$coverage_disc),
    recommendation = "FIX: Improve discretization (increase J, better alignment, or adaptive scheme)"
  )
}

# Test 2: Ensemble minimum
individual_coverages <- c(
  diag$d2_schemes$coverage_rf,
  diag$d2_schemes$coverage_quantiles,
  diag$d2_schemes$coverage_kmeans
)
max_individual_coverage <- max(individual_coverages, na.rm = TRUE)

if (max_individual_coverage > 0.90 &&
    diag$d2_schemes$coverage_ensemble < 0.70) {
  root_causes$ensemble <- list(
    severity = "CRITICAL",
    evidence = sprintf("Best individual scheme: %.1f%% coverage, ensemble: %.1f%%",
                      100 * max_individual_coverage,
                      100 * diag$d2_schemes$coverage_ensemble),
    recommendation = "FIX: Use best single scheme OR median/mean instead of minimum"
  )
}

# Test 3: J too small
j_summary <- diag$d3_increasing_J$summary
if (nrow(j_summary) > 0) {
  max_j <- max(j_summary$J)
  max_coverage_at_max_j <- j_summary %>%
    filter(J == max_j) %>%
    pull(coverage)

  if (max_coverage_at_max_j > 0.90 &&
      j_summary %>% filter(J == min(J)) %>% pull(coverage) < 0.70) {
    root_causes$J_too_small <- list(
      severity = "MAJOR",
      evidence = sprintf("J=%d gives %.1f%% coverage, J=%d gives %.1f%%",
                        min(j_summary$J), 100 * min(j_summary$coverage),
                        max_j, 100 * max_coverage_at_max_j),
      recommendation = sprintf("FIX: Increase default J from %d to %d",
                              diag$settings$J, max_j)
    )
  }
}

# Test 4: Closed-form bug
if (abs(diag$d4_closed_form_vs_sampling$bias_closed) > 0.02 &&
    abs(diag$d4_closed_form_vs_sampling$bias_sampling) < 0.01) {
  root_causes$closed_form_bug <- list(
    severity = "CRITICAL",
    evidence = sprintf("Closed-form bias: %.4f, sampling bias: %.4f",
                      diag$d4_closed_form_vs_sampling$bias_closed,
                      diag$d4_closed_form_vs_sampling$bias_sampling),
    recommendation = "FIX: Debug closed-form implementation in estimate_minimax_single_scheme()"
  )
}

# Test 6: CI width issue
if (abs(diag$d6_ci_construction$mean_estimate - diag$d6_ci_construction$mean_truth) < 0.01 &&
    diag$d6_ci_construction$coverage < 0.70) {
  root_causes$ci_too_narrow <- list(
    severity = "MAJOR",
    evidence = sprintf("Point estimate unbiased (diff: %.4f), but coverage only %.1f%%",
                      diag$d6_ci_construction$mean_estimate - diag$d6_ci_construction$mean_truth,
                      100 * diag$d6_ci_construction$coverage),
    recommendation = "FIX: Increase bootstrap samples or adjust CI method"
  )
}

# Test 7: Observation-level vs type-level
if (!is.null(diag$d7_obs_vs_type$coverage_obs) &&
    !is.null(diag$d7_obs_vs_type$coverage_type) &&
    !isTRUE(diag$d7_obs_vs_type$skipped)) {

  if (diag$d7_obs_vs_type$coverage_obs > 0.90 &&
      diag$d7_obs_vs_type$coverage_type < 0.70) {
    root_causes$j_dimensional_inadequate <- list(
      severity = "CRITICAL",
      evidence = sprintf("Observation-level: %.1f%% coverage, Type-level: %.1f%%",
                        100 * diag$d7_obs_vs_type$coverage_obs,
                        100 * diag$d7_obs_vs_type$coverage_type),
      recommendation = "FIX: Use observation-level (n-dimensional) for small n, OR increase J dramatically (from Diagnostic 3 results)"
    )
  }
}

# Display root causes
if (length(root_causes) == 0) {
  cat("❌ NO CLEAR ROOT CAUSE IDENTIFIED\n\n")
  cat("All diagnostics failed to improve coverage.\n")
  cat("This suggests a fundamental issue with the approach.\n")
  cat("Consult with advisors or review theory.\n\n")
} else {
  for (cause_name in names(root_causes)) {
    cause <- root_causes[[cause_name]]
    cat(sprintf("✗ %s: %s\n", cause$severity, toupper(gsub("_", " ", cause_name))), "\n")
    cat("  Evidence:", cause$evidence, "\n")
    cat("  →", cause$recommendation, "\n\n")
  }

  # Prioritize fixes
  cat("========================================\n")
  cat("RECOMMENDED ACTION PLAN\n")
  cat("========================================\n\n")

  critical_causes <- names(root_causes)[sapply(root_causes, function(x) x$severity == "CRITICAL")]

  if (length(critical_causes) > 0) {
    cat("PRIORITY: Fix critical issues first\n\n")
    for (cause_name in critical_causes) {
      cat("1.", toupper(gsub("_", " ", cause_name)), "\n")
      cat("   ", root_causes[[cause_name]]$recommendation, "\n\n")
    }
  }

  major_causes <- names(root_causes)[sapply(root_causes, function(x) x$severity == "MAJOR")]

  if (length(major_causes) > 0) {
    cat("FOLLOW-UP: Address major issues\n\n")
    for (cause_name in major_causes) {
      cat("•", toupper(gsub("_", " ", cause_name)), "\n")
      cat("   ", root_causes[[cause_name]]$recommendation, "\n\n")
    }
  }
}

# ============================================
# DETAILED PLOTS (if requested)
# ============================================

if (interactive() || Sys.getenv("MAKE_PLOTS") == "TRUE") {
  cat("========================================\n")
  cat("Generating diagnostic plots...\n")
  cat("========================================\n\n")

  # Plot 1: Coverage by approach
  coverage_data <- tribble(
    ~Approach, ~Coverage,
    "Discretized (current)", diag$d1_true_types$coverage_disc,
    "True types", diag$d1_true_types$coverage_true,
    "RF only", diag$d2_schemes$coverage_rf,
    "Quantiles only", diag$d2_schemes$coverage_quantiles,
    "K-means only", diag$d2_schemes$coverage_kmeans,
    "Ensemble", diag$d2_schemes$coverage_ensemble
  )

  p1 <- ggplot(coverage_data, aes(x = reorder(Approach, Coverage), y = Coverage)) +
    geom_col(fill = "steelblue") +
    geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
    geom_hline(yintercept = 0.90, linetype = "dashed", color = "orange") +
    coord_flip() +
    scale_y_continuous(labels = scales::percent) +
    labs(
      title = "Coverage by Approach",
      subtitle = sprintf("Target: 95%% | n=%d, λ=%.1f", diag$settings$n, diag$settings$lambda),
      x = NULL,
      y = "Coverage Rate"
    ) +
    theme_minimal()

  print(p1)
  ggsave(here("sims/results/diagnostic_coverage_plot.pdf"), p1, width = 8, height = 5)

  # Plot 2: Effect of J
  if (nrow(diag$d3_increasing_J$results) > 0) {
    p2 <- ggplot(diag$d3_increasing_J$results, aes(x = factor(J), y = as.numeric(covered))) +
      geom_boxplot() +
      geom_hline(yintercept = 0.95, linetype = "dashed", color = "red") +
      labs(
        title = "Effect of Number of Types (J) on Coverage",
        x = "Number of Types (J)",
        y = "Coverage Rate"
      ) +
      theme_minimal()

    print(p2)
    ggsave(here("sims/results/diagnostic_J_effect.pdf"), p2, width = 6, height = 4)
  }

  cat("Plots saved to sims/results/\n\n")
}

cat("========================================\n")
cat("ANALYSIS COMPLETE\n")
cat("========================================\n\n")
