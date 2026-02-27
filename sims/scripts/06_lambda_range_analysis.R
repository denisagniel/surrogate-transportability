#!/usr/bin/env Rscript

#' Lambda Grid Search Simulation
#'
#' Evaluates how surrogate functionals change across a grid of fixed lambda values.
#' Implements the grid search procedure from Section 4 of the methods paper.

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

# Define λ grid to analyze (fixed values)
lambda_grid <- seq(0, 1.0, by = 0.1)

cat("\nAnalyzing functionals across λ grid...\n")
cat("λ values:", paste(lambda_grid, collapse = ", "), "\n\n")

# Run grid search for correlation functional
cat("Running grid search for correlation functional...\n")
lambda_analysis_corr <- grid_search_lambda(
  current_data = current_data,
  lambda_grid = lambda_grid,
  threshold = 0.7,              # Minimum acceptable correlation
  functional_type = "correlation",
  confidence_level = 0.95,
  multiplicity_adjustment = "bonferroni",
  n_draws_from_F = 200,         # Reduced for faster execution
  n_future_studies_per_draw = 100,  # Reduced for faster execution
  epsilon_s = 0.2,
  epsilon_y = 0.1,
  seed = 12345
)

# Run grid search for probability functional
cat("\nRunning grid search for probability functional...\n")
lambda_analysis_prob <- grid_search_lambda(
  current_data = current_data,
  lambda_grid = lambda_grid,
  threshold = 0.8,              # Minimum acceptable probability
  functional_type = "probability",
  confidence_level = 0.95,
  multiplicity_adjustment = "bonferroni",
  n_draws_from_F = 200,
  n_future_studies_per_draw = 100,
  epsilon_s = 0.2,
  epsilon_y = 0.1,
  seed = 12345
)

# Display results
cat("\nGrid Search Results\n")
cat("===================\n\n")

cat("Correlation Functional:\n")
print(lambda_analysis_corr)

cat("\nProbability Functional:\n")
print(lambda_analysis_prob)

# Create visualizations
cat("\nCreating visualizations...\n")

# Ensure plots directory exists
if (!dir.exists("sims/results/plots")) {
  dir.create("sims/results/plots", recursive = TRUE)
}

# Correlation functional across λ values
p1 <- plot(lambda_analysis_corr) +
  ggplot2::labs(subtitle = paste0("Lambda* = ",
    if (is.na(lambda_analysis_corr$lambda_star)) "None found"
    else sprintf("%.2f", lambda_analysis_corr$lambda_star)))
ggsave("sims/results/plots/correlation_by_lambda_grid.png", p1, width = 10, height = 6, dpi = 300)

# Probability functional across λ values
p2 <- plot(lambda_analysis_prob) +
  ggplot2::labs(subtitle = paste0("Lambda* = ",
    if (is.na(lambda_analysis_prob$lambda_star)) "None found"
    else sprintf("%.2f", lambda_analysis_prob$lambda_star)))
ggsave("sims/results/plots/probability_by_lambda_grid.png", p2, width = 10, height = 6, dpi = 300)

# Create a combined plot comparing both functionals
combined_data <- rbind(
  lambda_analysis_corr$phi_estimates %>% dplyr::mutate(functional = "Correlation"),
  lambda_analysis_prob$phi_estimates %>% dplyr::mutate(functional = "Probability")
)

p3 <- ggplot2::ggplot(combined_data, ggplot2::aes(x = lambda, y = phi_hat, color = functional)) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = lower_ci, ymax = upper_ci, fill = functional),
    alpha = 0.2,
    color = NA
  ) +
  ggplot2::geom_line(linewidth = 1) +
  ggplot2::geom_point(size = 2) +
  ggplot2::geom_hline(yintercept = 0.7, linetype = "dashed", color = "#2E86AB", alpha = 0.5) +
  ggplot2::geom_hline(yintercept = 0.8, linetype = "dashed", color = "#A23B72", alpha = 0.5) +
  ggplot2::scale_color_manual(values = c("Correlation" = "#2E86AB", "Probability" = "#A23B72")) +
  ggplot2::scale_fill_manual(values = c("Correlation" = "#2E86AB", "Probability" = "#A23B72")) +
  ggplot2::labs(
    title = "Surrogate Functionals Across Lambda Grid (Fixed-Lambda Framework)",
    subtitle = "Dashed lines show thresholds; shaded areas show 95% CIs with Bonferroni adjustment",
    x = expression(lambda ~ "(Perturbation Distance)"),
    y = expression(hat(phi)(F[lambda])),
    color = "Functional",
    fill = "Functional"
  ) +
  ggplot2::theme_minimal() +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 14),
    plot.subtitle = ggplot2::element_text(size = 10),
    legend.position = "top"
  )

ggsave("sims/results/plots/functionals_by_lambda_grid.png", p3, width = 10, height = 6, dpi = 300)

# Save results
cat("\nSaving results...\n")
saveRDS(lambda_analysis_corr, "sims/results/lambda_grid_search_correlation.rds")
saveRDS(lambda_analysis_prob, "sims/results/lambda_grid_search_probability.rds")
write.csv(lambda_analysis_corr$phi_estimates,
          "sims/results/lambda_grid_correlation_estimates.csv",
          row.names = FALSE)
write.csv(lambda_analysis_prob$phi_estimates,
          "sims/results/lambda_grid_probability_estimates.csv",
          row.names = FALSE)

# Analysis summary
cat("\nAnalysis Summary\n")
cat("================\n\n")

# Correlation functional summary
corr_estimates <- lambda_analysis_corr$phi_estimates
max_corr_idx <- which.max(corr_estimates$phi_hat)
min_corr_idx <- which.min(corr_estimates$phi_hat)

cat("CORRELATION FUNCTIONAL:\n")
cat("Highest phi(F_lambda):",
    round(corr_estimates$phi_hat[max_corr_idx], 3),
    "at lambda =", corr_estimates$lambda[max_corr_idx], "\n")
cat("Lowest phi(F_lambda):",
    round(corr_estimates$phi_hat[min_corr_idx], 3),
    "at lambda =", corr_estimates$lambda[min_corr_idx], "\n")

corr_range <- max(corr_estimates$phi_hat) - min(corr_estimates$phi_hat)
cat("Range:", round(corr_range, 3), "\n")

cat("Lambda* (threshold = 0.7):",
    if (is.na(lambda_analysis_corr$lambda_star)) "None found"
    else sprintf("%.2f", lambda_analysis_corr$lambda_star), "\n")

# Check trend
correlation_trend <- cor(corr_estimates$lambda, corr_estimates$phi_hat)
cat("Trend (cor with lambda):", round(correlation_trend, 3))

if (abs(correlation_trend) > 0.5) {
  if (correlation_trend > 0) {
    cat(" → Positive: Higher lambda → Higher phi\n")
  } else {
    cat(" → Negative: Higher lambda → Lower phi\n")
  }
} else {
  cat(" → Weak: Lambda has limited effect\n")
}

# Probability functional summary
cat("\nPROBABILITY FUNCTIONAL:\n")
prob_estimates <- lambda_analysis_prob$phi_estimates
max_prob_idx <- which.max(prob_estimates$phi_hat)
min_prob_idx <- which.min(prob_estimates$phi_hat)

cat("Highest phi(F_lambda):",
    round(prob_estimates$phi_hat[max_prob_idx], 3),
    "at lambda =", prob_estimates$lambda[max_prob_idx], "\n")
cat("Lowest phi(F_lambda):",
    round(prob_estimates$phi_hat[min_prob_idx], 3),
    "at lambda =", prob_estimates$lambda[min_prob_idx], "\n")

prob_range <- max(prob_estimates$phi_hat, na.rm = TRUE) -
              min(prob_estimates$phi_hat, na.rm = TRUE)
cat("Range:", round(prob_range, 3), "\n")

cat("Lambda* (threshold = 0.8):",
    if (is.na(lambda_analysis_prob$lambda_star)) "None found"
    else sprintf("%.2f", lambda_analysis_prob$lambda_star), "\n")

cat("\nLambda grid search completed!\n")
cat("Results saved to sims/results/\n")
cat("Plots saved to sims/results/plots/\n")


