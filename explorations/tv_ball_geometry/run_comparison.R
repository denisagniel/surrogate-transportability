#!/usr/bin/env Rscript
# Run geometry comparison

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/tv_ball_geometry/10_other_geometries.R")
source("explorations/tv_ball_geometry/09_analytical_correlation.R")
source("explorations/tv_ball_geometry/11_geometry_comparison.R")

# Setup (same as analytical validation)
K <- 10
P0 <- rep(1/K, K)

set.seed(12345)
tau_S <- rnorm(K, mean = 0.5, sd = 0.3)
tau_Y <- 0.7 * tau_S + sqrt(1 - 0.7^2) * rnorm(K, sd = 0.3)

cat(sprintf("Type-level correlation: %.4f\n\n", cor(tau_S, tau_Y)))

# Run comparison with standard epsilon values
cat("Running comparison with standard epsilon values...\n\n")

comparison_results <- compare_geometries(
  tau_S = tau_S,
  tau_Y = tau_Y,
  P0 = P0,
  epsilon_values = list(
    tv = 0.3,
    chi2 = 0.3,
    l2 = 0.2,
    kl = 0.1
  ),
  M = 2000,
  n_replicates = 5,
  compute_exact = TRUE
)

# Save results
saveRDS(
  comparison_results,
  "explorations/tv_ball_geometry/results/geometry_comparison.rds"
)

# Visualize
p_comparison <- plot_geometry_comparison(comparison_results)
print(p_comparison)
ggsave(
  "explorations/tv_ball_geometry/figures/geometry_comparison.pdf",
  p_comparison, width = 8, height = 5
)

cat("\nResults saved to:\n")
cat("  - explorations/tv_ball_geometry/results/geometry_comparison.rds\n")
cat("  - explorations/tv_ball_geometry/figures/geometry_comparison.pdf\n")
