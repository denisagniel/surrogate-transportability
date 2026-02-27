#!/usr/bin/env Rscript

#' Lambda Range Analysis Simulation
#'
#' Analyzes how surrogate functionals change when λ is constrained to different ranges.
#' This helps understand how the level of innovation affects surrogate quality assessment.

# Load required packages
library(devtools)
library(dplyr)
library(tibble)
library(purrr)
library(ggplot2)

# Load the surrogate transportability package
devtools::load_all("package/", quiet = TRUE)

# Set random seed for reproducibility
set.seed(12345)

cat("Running Lambda Range Analysis Simulation\n")
cat("=====================================\n\n")

# Generate study data
cat("Generating study data...\n")
current_data <- generate_study_data(
  n = 500,
  n_classes = 2,
  class_probs = c(0.6, 0.4),
  treatment_effect_surrogate = c(0.5, 0.8),
  treatment_effect_outcome = c(0.3, 0.7),
  surrogate_type = "continuous",
  outcome_type = "continuous",
  covariate_effects = list(
    surrogate = c(0.3, 0.3),
    outcome = c(0.1, 0.1)
  )
)

# Check current study treatment effects
cat("Current study treatment effects:\n")
current_effects <- compute_multiple_treatment_effects(current_data, c("S", "Y"))
print(current_effects)

# Define λ ranges to analyze
lambda_ranges <- list(
  list(min = 0, max = 0.1),   # Very low innovation
  list(min = 0, max = 0.2),   # Low innovation
  list(min = 0, max = 0.3),   # Moderate-low innovation
  list(min = 0, max = 0.5),   # Moderate innovation
  list(min = 0, max = 0.7),   # Moderate-high innovation
  list(min = 0, max = 0.9),   # High innovation
  list(min = 0, max = 1.0)    # Full innovation
)

cat("\nAnalyzing functionals across λ ranges...\n")
cat("λ ranges:", paste(sapply(lambda_ranges, function(x) paste0("[", x$min, ", ", x$max, "]")), collapse = ", "), "\n\n")

# Run λ range analysis
lambda_analysis <- analyze_lambda_ranges(
  current_data = current_data,
  lambda_ranges = lambda_ranges,
  n_draws_from_F = 200,        # Reduced for faster execution
  n_future_studies_per_draw = 100,  # Reduced for faster execution
  functional_type = "all",
  epsilon_s = 0.2,
  epsilon_y = 0.1,
  delta_s_values = c(0.3, 0.5, 0.7),
  seed = 12345
)

# Display results
cat("Lambda Range Analysis Results\n")
cat("============================\n")
print(lambda_analysis$summary_table)

# Create visualizations
cat("\nCreating visualizations...\n")

# Correlation functional across λ ranges
p1 <- plot_lambda_range_analysis(lambda_analysis, "correlation")
ggsave("sims/results/plots/correlation_by_lambda_range.png", p1, width = 10, height = 6, dpi = 300)

# Probability functional across λ ranges
p2 <- plot_lambda_range_analysis(lambda_analysis, "probability")
ggsave("sims/results/plots/probability_by_lambda_range.png", p2, width = 10, height = 6, dpi = 300)

# Create a combined plot
combined_data <- lambda_analysis$summary_table %>%
  dplyr::select(lambda_range, lambda_max, correlation_mean, probability_mean) %>%
  tidyr::pivot_longer(cols = c(correlation_mean, probability_mean),
                     names_to = "functional",
                     values_to = "value") %>%
  dplyr::mutate(functional = dplyr::case_when(
    functional == "correlation_mean" ~ "Correlation",
    functional == "probability_mean" ~ "Probability"
  ))

p3 <- ggplot2::ggplot(combined_data, ggplot2::aes(x = lambda_max, y = value, color = functional)) +
  ggplot2::geom_point(size = 3) +
  ggplot2::geom_line() +
  ggplot2::scale_color_manual(values = c("Correlation" = "#2E86AB", "Probability" = "#A23B72")) +
  ggplot2::labs(
    title = "Surrogate Functionals Across λ Ranges",
    subtitle = "How innovation level affects surrogate quality assessment",
    x = "Maximum λ (Innovation Level)",
    y = "Functional Value",
    color = "Functional"
  ) +
  ggplot2::theme_minimal() +
  ggplot2::theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "top"
  )

ggsave("sims/results/plots/functionals_by_lambda_range.png", p3, width = 10, height = 6, dpi = 300)

# Save results
cat("\nSaving results...\n")
saveRDS(lambda_analysis, "sims/results/lambda_range_analysis.rds")
write.csv(lambda_analysis$summary_table, "sims/results/lambda_range_analysis_summary.csv", row.names = FALSE)

# Analysis summary
cat("\nAnalysis Summary\n")
cat("================\n")

# Find the range with highest and lowest correlation
max_corr_idx <- which.max(lambda_analysis$summary_table$correlation_mean)
min_corr_idx <- which.min(lambda_analysis$summary_table$correlation_mean)

cat("Highest correlation functional:", 
    round(lambda_analysis$summary_table$correlation_mean[max_corr_idx], 3),
    "at λ ∈", lambda_analysis$summary_table$lambda_range[max_corr_idx], "\n")

cat("Lowest correlation functional:", 
    round(lambda_analysis$summary_table$correlation_mean[min_corr_idx], 3),
    "at λ ∈", lambda_analysis$summary_table$lambda_range[min_corr_idx], "\n")

# Calculate correlation range
corr_range <- max(lambda_analysis$summary_table$correlation_mean) - 
              min(lambda_analysis$summary_table$correlation_mean)
cat("Correlation functional range:", round(corr_range, 3), "\n")

# Check if there's a clear trend
correlation_trend <- cor(lambda_analysis$summary_table$lambda_max, 
                        lambda_analysis$summary_table$correlation_mean)
cat("Correlation between λ_max and correlation functional:", round(correlation_trend, 3), "\n")

if (abs(correlation_trend) > 0.5) {
  if (correlation_trend > 0) {
    cat("→ Strong positive trend: Higher innovation → Higher correlation functional\n")
  } else {
    cat("→ Strong negative trend: Higher innovation → Lower correlation functional\n")
  }
} else {
  cat("→ Weak trend: Innovation level has limited effect on correlation functional\n")
}

# Probability functional analysis
prob_range <- max(lambda_analysis$summary_table$probability_mean) - 
              min(lambda_analysis$summary_table$probability_mean)
cat("Probability functional range:", round(prob_range, 3), "\n")

cat("\nLambda range analysis completed!\n")
cat("Results saved to sims/results/\n")
cat("Plots saved to sims/results/plots/\n")


