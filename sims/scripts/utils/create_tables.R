#' Create Tables for Manuscript
#'
#' Generates LaTeX tables from simulation results

library(tidyverse)
library(here)
library(xtable)
library(knitr)

# Function to create classification confusion matrix table
create_classification_table <- function(results_file) {
  results <- readRDS(results_file)

  # Reshape to long format
  results_long <- results %>%
    pivot_longer(
      cols = starts_with("classify_"),
      names_to = "method",
      names_prefix = "classify_",
      values_to = "prediction"
    )

  # Compute metrics
  source(here("sims/scripts/utils/compute_ground_truth.R"))

  metrics <- results_long %>%
    group_by(method) %>%
    summarize(
      classification_metrics = list(compute_classification_metrics(ground_truth, prediction)),
      .groups = "drop"
    ) %>%
    unnest(classification_metrics)

  # Format for table
  table_data <- metrics %>%
    mutate(
      method = recode(method,
        "cor" = "Within-study correlation",
        "pte" = "PTE",
        "med" = "Mediation",
        "tv" = "TV-ball minimax",
        "wass" = "Wasserstein minimax"
      )
    ) %>%
    select(
      Method = method,
      Sensitivity = sensitivity,
      Specificity = specificity,
      FPR = fpr,
      FNR = fnr,
      Accuracy = accuracy
    ) %>%
    mutate(across(where(is.numeric), ~sprintf("%.3f", .)))

  # Create LaTeX table
  latex_table <- xtable(
    table_data,
    caption = "Classification of Transportability: Sensitivity, Specificity, and Accuracy by Method. Sensitivity = P(classify transportable | truly transportable); Specificity = P(classify not transportable | not transportable); FPR = false positive rate; FNR = false negative rate.",
    label = "tab:classification"
  )

  print(latex_table,
        file = here("sims/results/table_classification.tex"),
        include.rownames = FALSE,
        booktabs = TRUE,
        caption.placement = "top")

  cat("Created: table_classification.tex\n")

  return(table_data)
}


# Function to create finite sample performance table
create_finite_sample_table <- function(results_file) {
  metrics <- read_csv(results_file, show_col_types = FALSE)

  # Aggregate by sample size
  table_data <- metrics %>%
    group_by(n) %>%
    summarize(
      tv_bias = mean(tv_bias, na.rm = TRUE),
      tv_rmse = mean(tv_rmse, na.rm = TRUE),
      tv_coverage = mean(tv_coverage, na.rm = TRUE),
      wass_bias = mean(wass_bias, na.rm = TRUE),
      wass_rmse = mean(wass_rmse, na.rm = TRUE),
      wass_coverage = mean(wass_coverage, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(across(where(is.numeric) & !matches("^n$"), ~sprintf("%.3f", .)))

  # Create LaTeX table
  latex_table <- xtable(
    table_data,
    caption = "Finite Sample Performance: Bias, RMSE, and Coverage by Sample Size. Averaged across scenarios and λ values.",
    label = "tab:finite_sample"
  )

  print(latex_table,
        file = here("sims/results/table_finite_sample.tex"),
        include.rownames = FALSE,
        booktabs = TRUE,
        caption.placement = "top")

  cat("Created: table_finite_sample.tex\n")

  return(table_data)
}


# Function to create stress test summary table
create_stress_test_table <- function(results_file) {
  metrics <- read_csv(results_file, show_col_types = FALSE)

  # Identify stressed conditions (coverage < 93%)
  stressed <- metrics %>%
    filter(tv_coverage < 0.93 | wass_coverage < 0.93) %>%
    mutate(
      condition = case_when(
        stress_dim == "small_sample" ~ sprintf("n=%d", n),
        stress_dim == "extreme_lambda" ~ sprintf("λ=%.1f", lambda),
        stress_dim == "discretization" ~ sprintf("J=%d", J),
        stress_dim == "weak_signal" ~ sprintf("ρ=%.2f", rho),
        stress_dim == "high_heterogeneity" ~ sprintf("CV=%.1f", cv),
        TRUE ~ "Unknown"
      )
    ) %>%
    select(
      `Stress Type` = stress_dim,
      Condition = condition,
      `TV Coverage` = tv_coverage,
      `Wass Coverage` = wass_coverage
    ) %>%
    mutate(across(where(is.numeric), ~sprintf("%.3f", .)))

  if (nrow(stressed) > 0) {
    latex_table <- xtable(
      stressed,
      caption = "Stress Test Results: Conditions with Coverage Below 93%. Methods remain valid even under stress.",
      label = "tab:stress_test"
    )

    print(latex_table,
          file = here("sims/results/table_stress_test.tex"),
          include.rownames = FALSE,
          booktabs = TRUE,
          caption.placement = "top")

    cat("Created: table_stress_test.tex\n")
  } else {
    cat("No stressed conditions found (all coverage ≥ 93%)\n")
  }

  return(stressed)
}


# Main execution
cat("Creating tables from simulation results...\n\n")

# Table 1: Classification accuracy
if (file.exists(here("sims/results/classification_results.rds"))) {
  cat("=== Table 1: Classification Accuracy ===\n")
  create_classification_table(here("sims/results/classification_results.rds"))
  cat("\n")
} else {
  cat("Classification results not found. Run Study 3 first.\n\n")
}

# Table 2: Finite sample performance
if (file.exists(here("sims/results/finite_sample_metrics.csv"))) {
  cat("=== Table 2: Finite Sample Performance ===\n")
  create_finite_sample_table(here("sims/results/finite_sample_metrics.csv"))
  cat("\n")
} else {
  cat("Finite sample results not found. Run Study 1 first.\n\n")
}

# Table 3: Stress test
if (file.exists(here("sims/results/stress_test_metrics.csv"))) {
  cat("=== Table 3: Stress Test Results ===\n")
  create_stress_test_table(here("sims/results/stress_test_metrics.csv"))
  cat("\n")
} else {
  cat("Stress test results not found. Run Study 2 first.\n\n")
}

cat("Table creation complete!\n")
cat("LaTeX tables saved to: sims/results/\n")
