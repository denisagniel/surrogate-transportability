# Compare Hit-and-Run vs Dirichlet Sampling
#
# This script demonstrates that hit-and-run gives uniform coverage
# of the TV ball, while Dirichlet sampling does not.

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Dirichlet-based sampling (existing approach)
#'
#' @param P0 baseline distribution
#' @param lambda TV ball radius
#' @param n_samples number of samples
#' @param alpha Dirichlet concentration parameter
#' @return matrix of samples (n_samples × K)
dirichlet_tv_sampler <- function(P0, lambda, n_samples = 1000, alpha = 1) {
  K <- length(P0)
  samples <- matrix(NA, nrow = n_samples, ncol = K)

  for (i in 1:n_samples) {
    # Sample mixing weight
    lambda_i <- runif(1, 0, lambda)

    # Sample direction from Dirichlet
    Q_tilde <- MCMCpack::rdirichlet(1, rep(alpha, K))[1,]

    # Mix with P0
    Q <- (1 - lambda_i) * P0 + lambda_i * Q_tilde

    samples[i, ] <- Q
  }

  return(samples)
}

#' Compare sampling methods
#'
#' @param K dimension
#' @param lambda TV radius
#' @param n_samples number of samples per method
compare_samplers <- function(K = 5, lambda = 0.3, n_samples = 1000) {

  cat("Comparing Hit-and-Run vs Dirichlet Sampling\n")
  cat(sprintf("K = %d, lambda = %.2f, n_samples = %d\n\n", K, lambda, n_samples))

  # Baseline distribution
  P0 <- rep(1/K, K)

  # Method 1: Hit-and-run (uniform)
  cat("Method 1: Hit-and-Run (uniform over TV ball)\n")
  samples_hr <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = n_samples,
    burn_in = 1000,
    thin = 10,
    verbose = TRUE
  )

  cat("\nMethod 2: Dirichlet-based (ray sampling)\n")
  samples_dir <- dirichlet_tv_sampler(
    P0 = P0,
    lambda = lambda,
    n_samples = n_samples,
    alpha = 1
  )

  # Compute TV distances
  tv_hr <- apply(samples_hr, 1, tv_distance, P0 = P0)
  tv_dir <- apply(samples_dir, 1, tv_distance, P0 = P0)

  cat(sprintf("  Done.\n\n"))

  # Compare distributions
  cat("TV Distance Distributions:\n")
  cat(sprintf("  Hit-and-Run  - mean: %.4f, sd: %.4f\n", mean(tv_hr), sd(tv_hr)))
  cat(sprintf("  Dirichlet    - mean: %.4f, sd: %.4f\n", mean(tv_dir), sd(tv_dir)))

  # Create comparison data
  df <- bind_rows(
    tibble(method = "Hit-and-Run (uniform)", tv = tv_hr),
    tibble(method = "Dirichlet (ray)", tv = tv_dir)
  )

  # Plot 1: TV distance distributions
  p1 <- ggplot(df, aes(x = tv, fill = method)) +
    geom_histogram(bins = 40, alpha = 0.6, position = "identity") +
    geom_vline(xintercept = lambda, linetype = "dashed", color = "red") +
    labs(
      title = sprintf("TV Distance Distributions (K=%d, λ=%.2f)", K, lambda),
      x = "TV distance to P₀",
      y = "Count",
      fill = "Method"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  print(p1)
  ggsave(
    "explorations/tv_ball_geometry/figures/compare_tv_distributions.pdf",
    p1, width = 8, height = 5
  )

  # Plot 2: First two dimensions (2D projection)
  df_2d <- bind_rows(
    tibble(method = "Hit-and-Run", dim1 = samples_hr[,1], dim2 = samples_hr[,2]),
    tibble(method = "Dirichlet", dim1 = samples_dir[,1], dim2 = samples_dir[,2])
  )

  p2 <- ggplot(df_2d, aes(x = dim1, y = dim2, color = method)) +
    geom_point(alpha = 0.3, size = 1) +
    geom_point(x = P0[1], y = P0[2], color = "red", size = 3, shape = 4) +
    annotate("text", x = P0[1], y = P0[2] + 0.03, label = "P₀", color = "red") +
    labs(
      title = "2D Projection of Samples",
      x = "Dimension 1",
      y = "Dimension 2",
      color = "Method"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom") +
    coord_fixed()

  print(p2)
  ggsave(
    "explorations/tv_ball_geometry/figures/compare_2d_projection.pdf",
    p2, width = 7, height = 6
  )

  # Statistical test: Are the TV distributions different?
  ks_test <- ks.test(tv_hr, tv_dir)
  cat(sprintf("\nKolmogorov-Smirnov test: D = %.4f, p < %.4f\n",
              ks_test$statistic, ks_test$p.value))

  if (ks_test$p.value < 0.001) {
    cat("  → TV distributions are significantly different\n")
  }

  # Return results
  invisible(list(
    samples_hr = samples_hr,
    samples_dir = samples_dir,
    tv_hr = tv_hr,
    tv_dir = tv_dir
  ))
}

#' Test sensitivity to dimension K
test_dimension_sensitivity <- function(lambda = 0.3, n_samples = 500) {

  cat("Testing dimension sensitivity\n\n")

  K_values <- c(3, 5, 10, 20)
  results <- list()

  for (K in K_values) {
    cat(sprintf("K = %d\n", K))
    P0 <- rep(1/K, K)

    samples <- hit_and_run_tv_ball(
      P0 = P0,
      lambda = lambda,
      n_samples = n_samples,
      burn_in = 500,
      thin = 5,
      verbose = FALSE
    )

    tv_dist <- apply(samples, 1, tv_distance, P0 = P0)

    results[[length(results) + 1]] <- tibble(
      K = K,
      tv = tv_dist
    )
  }

  df <- bind_rows(results)

  p <- ggplot(df, aes(x = tv, fill = factor(K))) +
    geom_histogram(bins = 30, alpha = 0.6, position = "identity") +
    geom_vline(xintercept = lambda, linetype = "dashed", color = "red") +
    facet_wrap(~ K, scales = "free_y", labeller = label_both) +
    labs(
      title = sprintf("TV Distance by Dimension (λ=%.2f)", lambda),
      x = "TV distance to P₀",
      y = "Count"
    ) +
    theme_minimal() +
    theme(legend.position = "none")

  print(p)
  ggsave(
    "explorations/tv_ball_geometry/figures/dimension_sensitivity.pdf",
    p, width = 10, height = 6
  )

  # Summary statistics
  summary_stats <- df %>%
    group_by(K) %>%
    summarise(
      mean_tv = mean(tv),
      sd_tv = sd(tv),
      min_tv = min(tv),
      max_tv = max(tv),
      .groups = "drop"
    )

  print(summary_stats)

  invisible(list(df = df, summary = summary_stats))
}

# If running interactively, run comparisons
if (interactive()) {
  # Install MCMCpack if needed
  if (!require(MCMCpack)) {
    install.packages("MCMCpack")
    library(MCMCpack)
  }

  results <- compare_samplers(K = 5, lambda = 0.3, n_samples = 1000)
  dim_results <- test_dimension_sensitivity(lambda = 0.3, n_samples = 500)
}
