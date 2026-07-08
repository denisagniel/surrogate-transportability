# Comparative Analysis Across Local Geometries
#
# Compare TV, chi-squared, L2, and KL divergence balls
# Test robustness of correlation findings to geometry choice

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")
source("explorations/tv_ball_geometry/10_other_geometries.R")
source("explorations/tv_ball_geometry/09_analytical_correlation.R")

#' Compare correlations across multiple geometries
#'
#' @param tau_S K-vector of type-level effects for S
#' @param tau_Y K-vector of type-level effects for Y
#' @param P0 Baseline distribution
#' @param epsilon_values Named list of epsilon values for each geometry
#' @param M Sample size for Monte Carlo
#' @param n_replicates Number of replicates per geometry
#' @return Tibble with comparison results
compare_geometries <- function(
  tau_S,
  tau_Y,
  P0,
  epsilon_values = list(
    tv = 0.3,
    chi2 = 0.3,
    l2 = 0.2,
    kl = 0.1
  ),
  M = 2000,
  n_replicates = 5,
  compute_exact = TRUE
) {

  K <- length(tau_S)

  cat("========================================\n")
  cat("GEOMETRY COMPARISON\n")
  cat("========================================\n\n")

  cat(sprintf("Setup: K = %d, M = %d, n_replicates = %d\n\n", K, M, n_replicates))
  cat(sprintf("Type-level correlation: %.4f\n\n", cor(tau_S, tau_Y)))

  # Store results
  results_list <- list()

  # 1. TV Ball
  cat(sprintf("1. TV Ball (λ = %.2f)\n", epsilon_values$tv))
  cat("   Sampling via hit-and-run...\n")

  tv_cors <- numeric(n_replicates)
  for (rep in 1:n_replicates) {
    Q_samples <- hit_and_run_tv_ball(
      P0 = P0,
      lambda = epsilon_values$tv,
      n_samples = M,
      burn_in = 1000,
      thin = 10,
      verbose = FALSE
    )
    Delta_S <- Q_samples %*% tau_S
    Delta_Y <- Q_samples %*% tau_Y
    tv_cors[rep] <- cor(Delta_S, Delta_Y)
    cat(sprintf("   Replicate %d: %.4f\n", rep, tv_cors[rep]))
  }

  # Compute exact for TV if requested
  tv_exact <- if (compute_exact && K <= 20) {
    cat("   Computing exact via rejection sampling...\n")
    Sigma_Q <- compute_tv_ball_covariance(
      P0 = P0,
      lambda = epsilon_values$tv,
      n_samples = 30000,
      method = "rejection"
    )
    compute_exact_correlation_analytical(tau_S, tau_Y, Sigma_Q)
  } else {
    NA_real_
  }

  results_list[[1]] <- tibble(
    geometry = "TV",
    epsilon = epsilon_values$tv,
    mean_cor = mean(tv_cors),
    se_cor = sd(tv_cors),
    exact_cor = tv_exact,
    bias = if (!is.na(tv_exact)) mean_cor - tv_exact else NA_real_
  )

  cat(sprintf("   Mean: %.4f (SE = %.4f)\n", mean(tv_cors), sd(tv_cors)))
  if (!is.na(tv_exact)) {
    cat(sprintf("   Exact: %.4f (Bias = %+.4f)\n", tv_exact, mean(tv_cors) - tv_exact))
  }
  cat("\n")

  # 2. Chi-squared Ball
  cat(sprintf("2. Chi-squared Ball (ε = %.2f)\n", epsilon_values$chi2))
  cat("   Sampling via hit-and-run...\n")

  chi2_cors <- numeric(n_replicates)
  for (rep in 1:n_replicates) {
    Q_samples <- hit_and_run_chi2_ball(
      P0 = P0,
      epsilon = epsilon_values$chi2,
      n_samples = M,
      burn_in = 1000,
      thin = 10,
      verbose = FALSE
    )
    Delta_S <- Q_samples %*% tau_S
    Delta_Y <- Q_samples %*% tau_Y
    chi2_cors[rep] <- cor(Delta_S, Delta_Y)
    cat(sprintf("   Replicate %d: %.4f\n", rep, chi2_cors[rep]))
  }

  results_list[[2]] <- tibble(
    geometry = "Chi-squared",
    epsilon = epsilon_values$chi2,
    mean_cor = mean(chi2_cors),
    se_cor = sd(chi2_cors),
    exact_cor = NA_real_,
    bias = NA_real_
  )

  cat(sprintf("   Mean: %.4f (SE = %.4f)\n", mean(chi2_cors), sd(chi2_cors)))
  cat("\n")

  # 3. L2 Ball
  cat(sprintf("3. L2 Ball (ε = %.2f)\n", epsilon_values$l2))
  cat("   Sampling via hit-and-run...\n")

  l2_cors <- numeric(n_replicates)
  for (rep in 1:n_replicates) {
    Q_samples <- hit_and_run_l2_ball(
      P0 = P0,
      epsilon = epsilon_values$l2,
      n_samples = M,
      burn_in = 1000,
      thin = 10,
      verbose = FALSE
    )
    Delta_S <- Q_samples %*% tau_S
    Delta_Y <- Q_samples %*% tau_Y
    l2_cors[rep] <- cor(Delta_S, Delta_Y)
    cat(sprintf("   Replicate %d: %.4f\n", rep, l2_cors[rep]))
  }

  results_list[[3]] <- tibble(
    geometry = "L2",
    epsilon = epsilon_values$l2,
    mean_cor = mean(l2_cors),
    se_cor = sd(l2_cors),
    exact_cor = NA_real_,
    bias = NA_real_
  )

  cat(sprintf("   Mean: %.4f (SE = %.4f)\n", mean(l2_cors), sd(l2_cors)))
  cat("\n")

  # 4. KL Ball
  cat(sprintf("4. KL Ball (ε = %.2f)\n", epsilon_values$kl))
  cat("   Sampling via hit-and-run...\n")

  kl_cors <- numeric(n_replicates)
  for (rep in 1:n_replicates) {
    Q_samples <- hit_and_run_kl_ball(
      P0 = P0,
      epsilon = epsilon_values$kl,
      n_samples = M,
      burn_in = 1000,
      thin = 10,
      verbose = FALSE
    )
    Delta_S <- Q_samples %*% tau_S
    Delta_Y <- Q_samples %*% tau_Y
    kl_cors[rep] <- cor(Delta_S, Delta_Y)
    cat(sprintf("   Replicate %d: %.4f\n", rep, kl_cors[rep]))
  }

  results_list[[4]] <- tibble(
    geometry = "KL",
    epsilon = epsilon_values$kl,
    mean_cor = mean(kl_cors),
    se_cor = sd(kl_cors),
    exact_cor = NA_real_,
    bias = NA_real_
  )

  cat(sprintf("   Mean: %.4f (SE = %.4f)\n", mean(kl_cors), sd(kl_cors)))
  cat("\n")

  # Combine results
  results_df <- bind_rows(results_list)

  # Summary
  cat("========================================\n")
  cat("SUMMARY\n")
  cat("========================================\n\n")

  print(results_df, n = Inf)

  cat("\n")
  cat(sprintf("Correlation range: [%.3f, %.3f]\n",
              min(results_df$mean_cor), max(results_df$mean_cor)))
  cat(sprintf("Relative spread: %.1f%%\n",
              100 * (max(results_df$mean_cor) - min(results_df$mean_cor)) /
                mean(results_df$mean_cor)))

  # Test consistency
  if (all(results_df$mean_cor > 0)) {
    cat("\n✓ All geometries show POSITIVE correlation\n")
  }

  if (max(results_df$mean_cor) / min(results_df$mean_cor) < 1.5) {
    cat("✓ Magnitudes are CONSISTENT (within 50%)\n")
  }

  return(results_df)
}

#' Create visualization comparing geometries
#'
#' @param results_df Results from compare_geometries()
#' @return ggplot object
plot_geometry_comparison <- function(results_df) {

  p <- ggplot(results_df, aes(x = reorder(geometry, mean_cor), y = mean_cor)) +
    geom_col(fill = "steelblue", alpha = 0.8) +
    geom_errorbar(
      aes(ymin = mean_cor - 1.96*se_cor, ymax = mean_cor + 1.96*se_cor),
      width = 0.2
    ) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    coord_flip() +
    labs(
      title = "Across-Study Correlation by Local Geometry",
      subtitle = "Error bars: 95% confidence intervals",
      x = "Geometry",
      y = "Correlation",
      caption = sprintf("M = 2000 samples per replicate")
    ) +
    theme_minimal(base_size = 14) +
    theme(
      panel.grid.major.y = element_blank()
    )

  return(p)
}

# Run if interactive
if (interactive()) {

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

  # Visualize
  p_comparison <- plot_geometry_comparison(comparison_results)
  print(p_comparison)
  ggsave(
    "explorations/tv_ball_geometry/figures/geometry_comparison.pdf",
    p_comparison, width = 8, height = 5
  )
}
