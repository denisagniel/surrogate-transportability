#' Create Figures for Manuscript
#'
#' Generates publication-quality figures from simulation results

library(tidyverse)
library(here)
library(patchwork)

# RAND plot theme
theme_rand <- function() {
  theme_minimal() +
    theme(
      text = element_text(family = "sans"),
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 10),
      axis.title = element_text(size = 10),
      axis.text = element_text(size = 9),
      legend.title = element_text(size = 10),
      legend.text = element_text(size = 9),
      strip.text = element_text(size = 10, face = "bold"),
      panel.grid.minor = element_blank()
    )
}

# Color palette
method_colors <- c(
  "Within-study correlation" = "#E41A1C",
  "PTE" = "#377EB8",
  "Mediation" = "#4DAF4A",
  "TV-ball minimax" = "#984EA3",
  "Wasserstein minimax" = "#FF7F00"
)

#' Figure 1: Classification Performance Comparison
create_figure_classification_performance <- function(results_file) {
  results <- readRDS(results_file)

  # Compute metrics
  source(here("sims/scripts/utils/compute_ground_truth.R"))

  results_long <- results %>%
    pivot_longer(
      cols = starts_with("classify_"),
      names_to = "method",
      names_prefix = "classify_",
      values_to = "prediction"
    )

  metrics <- results_long %>%
    group_by(method) %>%
    summarize(
      classification_metrics = list(compute_classification_metrics(ground_truth, prediction)),
      .groups = "drop"
    ) %>%
    unnest(classification_metrics)

  # Format method names
  metrics <- metrics %>%
    mutate(
      method = recode(method,
        "cor" = "Within-study correlation",
        "pte" = "PTE",
        "med" = "Mediation",
        "tv" = "TV-ball minimax",
        "wass" = "Wasserstein minimax"
      ),
      method_type = ifelse(method %in% c("TV-ball minimax", "Wasserstein minimax"),
                          "Local Geometric", "Traditional")
    )

  # Plot 1a: Bar chart of key metrics
  p1 <- metrics %>%
    pivot_longer(
      cols = c(sensitivity, specificity, accuracy),
      names_to = "metric",
      values_to = "value"
    ) %>%
    mutate(
      metric = recode(metric,
        "sensitivity" = "Sensitivity",
        "specificity" = "Specificity",
        "accuracy" = "Accuracy"
      ),
      metric = factor(metric, levels = c("Sensitivity", "Specificity", "Accuracy"))
    ) %>%
    ggplot(aes(x = method, y = value, fill = method_type)) +
    geom_col() +
    geom_hline(yintercept = 0.9, linetype = "dashed", color = "gray50", linewidth = 0.5) +
    facet_wrap(~metric, ncol = 3) +
    scale_fill_manual(values = c("Traditional" = "#E74C3C", "Local Geometric" = "#3498DB")) +
    labs(
      title = "Classification Performance by Method",
      x = NULL,
      y = "Value",
      fill = "Method Type"
    ) +
    theme_rand() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "bottom"
    ) +
    ylim(0, 1)

  ggsave(here("sims/results/figure_classification_performance.pdf"),
         p1, width = 10, height = 5)

  # Plot 1b: ROC-style plot (FPR vs TPR)
  p2 <- metrics %>%
    ggplot(aes(x = fpr, y = sensitivity, color = method, shape = method_type)) +
    geom_point(size = 4) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray50") +
    scale_color_manual(values = method_colors) +
    scale_shape_manual(values = c("Traditional" = 16, "Local Geometric" = 17)) +
    labs(
      title = "Classification Accuracy: False Positive Rate vs True Positive Rate",
      subtitle = "Ideal methods appear in upper-left corner (high TPR, low FPR)",
      x = "False Positive Rate",
      y = "True Positive Rate (Sensitivity)",
      color = "Method",
      shape = "Method Type"
    ) +
    theme_rand() +
    xlim(0, 1) +
    ylim(0, 1) +
    coord_fixed()

  ggsave(here("sims/results/figure_classification_roc.pdf"),
         p2, width = 8, height = 6)

  cat("Created: figure_classification_performance.pdf\n")
  cat("Created: figure_classification_roc.pdf\n")

  invisible(list(performance = p1, roc = p2))
}


#' Figure 2: Finite Sample Performance
create_figure_finite_sample <- function(metrics_file) {
  metrics <- read_csv(metrics_file, show_col_types = FALSE)

  # Plot 2a: Coverage by sample size
  p1 <- metrics %>%
    pivot_longer(
      cols = c(tv_coverage, wass_coverage),
      names_to = "method",
      values_to = "coverage"
    ) %>%
    mutate(
      method = recode(method,
        "tv_coverage" = "TV-ball minimax",
        "wass_coverage" = "Wasserstein minimax"
      )
    ) %>%
    ggplot(aes(x = n, y = coverage, color = method)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    geom_hline(yintercept = 0.95, linetype = "dashed", color = "red", linewidth = 0.5) +
    facet_wrap(~scenario, ncol = 1) +
    scale_x_log10(breaks = unique(metrics$n)) +
    scale_color_manual(values = method_colors[c("TV-ball minimax", "Wasserstein minimax")]) +
    labs(
      title = "Coverage Probability by Sample Size",
      subtitle = "Dashed line shows nominal 95% coverage",
      x = "Sample Size",
      y = "Coverage Probability",
      color = "Method"
    ) +
    theme_rand() +
    ylim(0.85, 1.0)

  ggsave(here("sims/results/figure_finite_sample_coverage.pdf"),
         p1, width = 8, height = 10)

  # Plot 2b: RMSE by sample size
  p2 <- metrics %>%
    pivot_longer(
      cols = c(tv_rmse, wass_rmse),
      names_to = "method",
      values_to = "rmse"
    ) %>%
    mutate(
      method = recode(method,
        "tv_rmse" = "TV-ball minimax",
        "wass_rmse" = "Wasserstein minimax"
      )
    ) %>%
    ggplot(aes(x = n, y = rmse, color = method)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    facet_wrap(~scenario, ncol = 1, scales = "free_y") +
    scale_x_log10(breaks = unique(metrics$n)) +
    scale_y_log10() +
    scale_color_manual(values = method_colors[c("TV-ball minimax", "Wasserstein minimax")]) +
    labs(
      title = "RMSE by Sample Size (Showing Consistency)",
      subtitle = "RMSE decreases as n increases",
      x = "Sample Size",
      y = "RMSE (log scale)",
      color = "Method"
    ) +
    theme_rand()

  ggsave(here("sims/results/figure_finite_sample_rmse.pdf"),
         p2, width = 8, height = 10)

  cat("Created: figure_finite_sample_coverage.pdf\n")
  cat("Created: figure_finite_sample_rmse.pdf\n")

  invisible(list(coverage = p1, rmse = p2))
}


#' Figure 3: Stress Test Results
create_figure_stress_test <- function(metrics_file) {
  metrics <- read_csv(metrics_file, show_col_types = FALSE)

  # Create a plot for each stress dimension
  stress_dims <- unique(metrics$stress_dim)

  for (stress_name in stress_dims) {
    stress_data <- metrics %>% filter(stress_dim == stress_name)

    # Determine which parameter varies
    param_names <- c("n", "lambda", "J", "rho", "cv")
    n_distinct_by_param <- stress_data %>%
      summarize(across(all_of(param_names), n_distinct))

    varying_param <- param_names[which(n_distinct_by_param > 1)][1]

    if (is.na(varying_param)) next

    # Create plot
    p <- stress_data %>%
      pivot_longer(
        cols = c(tv_coverage, wass_coverage),
        names_to = "method",
        values_to = "coverage"
      ) %>%
      mutate(
        method = recode(method,
          "tv_coverage" = "TV-ball minimax",
          "wass_coverage" = "Wasserstein minimax"
        )
      ) %>%
      ggplot(aes(x = .data[[varying_param]], y = coverage, color = method)) +
      geom_line(linewidth = 1) +
      geom_point(size = 3) +
      geom_hline(yintercept = 0.95, linetype = "dashed", color = "red", linewidth = 0.5) +
      geom_hline(yintercept = 0.90, linetype = "dotted", color = "orange", linewidth = 0.5) +
      scale_color_manual(values = method_colors[c("TV-ball minimax", "Wasserstein minimax")]) +
      labs(
        title = sprintf("Stress Test: %s", stress_name),
        subtitle = "Dashed: 95% nominal; Dotted: 90% acceptable",
        x = varying_param,
        y = "Coverage Probability",
        color = "Method"
      ) +
      theme_rand() +
      ylim(0.75, 1.0)

    filename <- sprintf("figure_stress_test_%s.pdf", stress_name)
    ggsave(here("sims/results", filename), p, width = 8, height = 6)

    cat(sprintf("Created: %s\n", filename))
  }

  invisible(NULL)
}


#' Figure 4: DGP Scenario Illustration
create_figure_dgp_scenarios <- function(results_file) {
  results <- readRDS(results_file)

  # Take one replication from each scenario for illustration
  examples <- results %>%
    group_by(scenario_type) %>%
    slice(1) %>%
    ungroup()

  # Create 2x2 grid showing cor_effects vs cor_within
  p <- examples %>%
    mutate(
      scenario_label = recode(scenario_type,
        "true_positive" = "True Positive\n(Transportable, Traditional Good)",
        "false_positive" = "False Positive\n(Not Transportable, Traditional Good)",
        "false_negative" = "False Negative\n(Transportable, Traditional Bad)",
        "true_negative" = "True Negative\n(Not Transportable, Traditional Bad)"
      ),
      scenario_label = factor(scenario_label,
        levels = c(
          "True Positive\n(Transportable, Traditional Good)",
          "False Positive\n(Not Transportable, Traditional Good)",
          "False Negative\n(Transportable, Traditional Bad)",
          "True Negative\n(Not Transportable, Traditional Bad)"
        )
      )
    ) %>%
    ggplot(aes(x = cor_effects, y = cor_within, color = scenario_type)) +
    geom_point(size = 8, alpha = 0.7) +
    geom_vline(xintercept = 0.6, linetype = "dashed", color = "gray50") +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
    scale_color_brewer(palette = "Set1") +
    labs(
      title = "DGP Scenario Design: 2×2 Classification Framework",
      subtitle = "Vertical line: transportability threshold (ρ_effects > 0.6)\nHorizontal line: traditional threshold (ρ_within > 0.5)",
      x = "Treatment Effect Correlation (ρ_effects)",
      y = "Within-Study Correlation (ρ_within)",
      color = "Scenario"
    ) +
    theme_rand() +
    xlim(-0.2, 1.0) +
    ylim(0, 1.0) +
    coord_fixed()

  ggsave(here("sims/results/figure_dgp_scenarios.pdf"),
         p, width = 10, height = 8)

  cat("Created: figure_dgp_scenarios.pdf\n")

  invisible(p)
}


# Main execution
cat("Creating figures from simulation results...\n\n")

# Figure 1: Classification performance
if (file.exists(here("sims/results/classification_results.rds"))) {
  cat("=== Figure 1: Classification Performance ===\n")
  create_figure_classification_performance(here("sims/results/classification_results.rds"))
  cat("\n")
} else {
  cat("Classification results not found. Run Study 3 first.\n\n")
}

# Figure 2: Finite sample performance
if (file.exists(here("sims/results/finite_sample_metrics.csv"))) {
  cat("=== Figure 2: Finite Sample Performance ===\n")
  create_figure_finite_sample(here("sims/results/finite_sample_metrics.csv"))
  cat("\n")
} else {
  cat("Finite sample results not found. Run Study 1 first.\n\n")
}

# Figure 3: Stress test
if (file.exists(here("sims/results/stress_test_metrics.csv"))) {
  cat("=== Figure 3: Stress Test Results ===\n")
  create_figure_stress_test(here("sims/results/stress_test_metrics.csv"))
  cat("\n")
} else {
  cat("Stress test results not found. Run Study 2 first.\n\n")
}

# Figure 4: DGP scenarios
if (file.exists(here("sims/results/classification_results.rds"))) {
  cat("=== Figure 4: DGP Scenario Illustration ===\n")
  create_figure_dgp_scenarios(here("sims/results/classification_results.rds"))
  cat("\n")
} else {
  cat("Classification results not found. Run Study 3 first.\n\n")
}

cat("Figure creation complete!\n")
cat("PDF figures saved to: sims/results/\n")
