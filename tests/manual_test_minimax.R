#!/usr/bin/env Rscript
# Manual test and demonstration of minimax inference

library(surrogateTransportability)
library(ggplot2)

# Generate baseline data
set.seed(42)
data <- generate_study_data(
  n = 200,
  treatment_effect_surrogate = c(0.3, 0.9),
  treatment_effect_outcome = c(0.2, 0.8)
)

# Run minimax inference
cat("Running minimax inference...\n")
result <- surrogate_inference_minimax(
  current_data = data,
  lambda = 0.3,
  functional_type = "correlation",
  n_dirichlet_grid = 20,
  include_vertices = TRUE,
  max_vertices = 20,
  n_innovations = 500,
  parallel = FALSE,
  verbose = TRUE
)

# Display results
cat("\n=== Minimax Bounds ===\n")
cat(sprintf("Supremum: %.4f\n", result$phi_star))
cat(sprintf("Infimum:  %.4f\n", result$phi_star_lower))
cat(sprintf("Width:    %.4f\n", result$bound_width))

cat("\n=== Achieved at ===\n")
cat(sprintf("Supremum: %s", result$mu_at_sup$mu_type))
if (result$mu_at_sup$mu_type == "dirichlet") {
  cat(sprintf(" (α = %.3f)", result$mu_at_sup$alpha))
}
cat("\n")
cat(sprintf("Infimum:  %s", result$mu_at_inf$mu_type))
if (result$mu_at_inf$mu_type == "dirichlet") {
  cat(sprintf(" (α = %.3f)", result$mu_at_inf$alpha))
}
cat("\n")

cat("\n=== Standard Method Comparison ===\n")
cat(sprintf("Estimate: %.4f [%.4f, %.4f]\n",
            result$method_estimate,
            result$method_ci_lower,
            result$method_ci_upper))
cat(sprintf("Contained in bounds: %s\n", result$method_contained))

# Visualize search grid
cat("\n=== Visualizing search grid ===\n")

# Plot φ vs α for Dirichlet distributions
dirichlet_grid <- result$search_grid %>%
  dplyr::filter(mu_type == "dirichlet")

p <- ggplot(dirichlet_grid, aes(x = alpha, y = phi_value)) +
  geom_point(size = 2) +
  geom_line() +
  geom_hline(yintercept = result$phi_star, linetype = "dashed", color = "red") +
  geom_hline(yintercept = result$phi_star_lower, linetype = "dashed", color = "blue") +
  geom_hline(yintercept = result$method_estimate, linetype = "dotted", color = "green") +
  scale_x_log10() +
  labs(
    title = "Surrogate Quality φ(F_λ) across Innovation Distributions",
    subtitle = sprintf("λ = %.2f, n = %d", result$lambda, nrow(data)),
    x = "Dirichlet concentration α (log scale)",
    y = "Correlation φ",
    caption = "Red: supremum, Blue: infimum, Green: standard method (α=1)"
  ) +
  theme_minimal()

ggsave("/tmp/minimax_search_grid.png", p, width = 8, height = 5)
cat("Plot saved to: /tmp/minimax_search_grid.png\n")

# Show summary statistics
cat("\n=== Search Grid Summary ===\n")
cat(sprintf("Total evaluations: %d\n", nrow(result$search_grid)))
cat(sprintf("  Dirichlet: %d\n", sum(result$search_grid$mu_type == "dirichlet")))
cat(sprintf("  Vertex:    %d\n", sum(result$search_grid$mu_type == "vertex")))
cat(sprintf("  Uniform:   %d\n", sum(result$search_grid$mu_type == "uniform")))

# Show vertex contributions
vertex_grid <- result$search_grid %>%
  dplyr::filter(mu_type == "vertex") %>%
  dplyr::arrange(phi_value)

cat("\n=== Vertex Extremes ===\n")
cat("Lowest φ vertices:\n")
print(head(vertex_grid, 3))
cat("\nHighest φ vertices:\n")
print(tail(vertex_grid, 3))

cat("\n=== Test completed successfully! ===\n")
