# Hit-and-Run Diagnostics
#
# Verify that the sampler:
# 1. Converges (burn-in is adequate)
# 2. Mixes well (autocorrelation decays)
# 3. Produces uniform coverage

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Compute autocorrelation for a time series
#'
#' @param x numeric vector
#' @param max_lag maximum lag
autocorr <- function(x, max_lag = 50) {
  acf_result <- acf(x, lag.max = max_lag, plot = FALSE)
  tibble(
    lag = 0:max_lag,
    autocorr = as.numeric(acf_result$acf)
  )
}

#' Run multiple chains to assess convergence
#'
#' @param P0 baseline distribution
#' @param lambda TV radius
#' @param n_chains number of chains
#' @param n_samples samples per chain
check_convergence <- function(P0, lambda, n_chains = 4, n_samples = 1000) {

  K <- length(P0)

  cat(sprintf("Running %d chains for convergence diagnostics\n", n_chains))

  # Run multiple chains with different starting points
  chains <- list()

  for (chain in 1:n_chains) {
    cat(sprintf("  Chain %d/%d\n", chain, n_chains))

    # Different starting point for each chain
    if (chain == 1) {
      initial <- P0  # Start at center
    } else {
      # Start at random point in ball
      lambda_start <- runif(1, 0, lambda)
      Q_tilde <- MCMCpack::rdirichlet(1, rep(1, K))[1,]
      initial <- (1 - lambda_start) * P0 + lambda_start * Q_tilde
    }

    samples <- hit_and_run_tv_ball(
      P0 = P0,
      lambda = lambda,
      n_samples = n_samples,
      burn_in = 500,
      thin = 5,
      initial = initial,
      verbose = FALSE
    )

    # Compute TV distances
    tv_distances <- apply(samples, 1, tv_distance, P0 = P0)

    chains[[chain]] <- tibble(
      chain = chain,
      iteration = 1:n_samples,
      tv_distance = tv_distances,
      dim1 = samples[, 1],
      dim2 = samples[, 2]
    )
  }

  df <- bind_rows(chains)

  # Plot trace plots for TV distance
  p1 <- ggplot(df, aes(x = iteration, y = tv_distance, color = factor(chain))) +
    geom_line(alpha = 0.7) +
    labs(
      title = "Trace Plots: TV Distance",
      subtitle = "Chains should mix and overlap",
      x = "Iteration",
      y = "TV Distance",
      color = "Chain"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  print(p1)
  ggsave(
    "explorations/tv_ball_geometry/figures/convergence_trace.pdf",
    p1, width = 10, height = 5
  )

  # Plot trace plots for first dimension
  p2 <- ggplot(df, aes(x = iteration, y = dim1, color = factor(chain))) +
    geom_line(alpha = 0.7) +
    labs(
      title = "Trace Plots: First Dimension",
      x = "Iteration",
      y = "P[1]",
      color = "Chain"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  print(p2)
  ggsave(
    "explorations/tv_ball_geometry/figures/convergence_trace_dim1.pdf",
    p2, width = 10, height = 5
  )

  # Gelman-Rubin diagnostic (simplified version)
  # Compare within-chain and between-chain variance
  chain_means <- df %>%
    group_by(chain) %>%
    summarise(mean_tv = mean(tv_distance), .groups = "drop")

  within_var <- df %>%
    group_by(chain) %>%
    summarise(var_tv = var(tv_distance), .groups = "drop") %>%
    pull(var_tv) %>%
    mean()

  between_var <- var(chain_means$mean_tv)

  rhat <- sqrt((within_var + between_var) / within_var)

  cat(sprintf("\nGelman-Rubin R-hat (informal): %.4f\n", rhat))
  cat("  (Values close to 1.0 indicate convergence; typically want < 1.1)\n")

  invisible(df)
}

#' Check autocorrelation and effective sample size
#'
#' @param P0 baseline distribution
#' @param lambda TV radius
check_mixing <- function(P0, lambda) {

  cat("Checking mixing and autocorrelation\n")

  # Run sampler with no thinning to assess autocorrelation
  samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = 2000,
    burn_in = 1000,
    thin = 1,  # No thinning
    verbose = FALSE
  )

  # Compute TV distances
  tv_distances <- apply(samples, 1, tv_distance, P0 = P0)

  # Autocorrelation for TV distance
  acf_tv <- autocorr(tv_distances, max_lag = 100)

  # Autocorrelation for first dimension
  acf_dim1 <- autocorr(samples[, 1], max_lag = 100)

  # Plot
  acf_df <- bind_rows(
    acf_tv %>% mutate(variable = "TV Distance"),
    acf_dim1 %>% mutate(variable = "Dimension 1")
  )

  p <- ggplot(acf_df, aes(x = lag, y = autocorr)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_hline(yintercept = c(-0.2, 0.2), linetype = "dotted", color = "gray70") +
    geom_col(fill = "steelblue", alpha = 0.7) +
    facet_wrap(~ variable, ncol = 1) +
    labs(
      title = "Autocorrelation Function",
      subtitle = "Should decay quickly for good mixing",
      x = "Lag",
      y = "Autocorrelation"
    ) +
    theme_minimal()

  print(p)
  ggsave(
    "explorations/tv_ball_geometry/figures/autocorrelation.pdf",
    p, width = 8, height = 6
  )

  # Estimate effective sample size
  # ESS ≈ n / (1 + 2*sum of positive autocorrelations)
  positive_acf <- acf_tv$autocorr[acf_tv$autocorr > 0 & acf_tv$lag > 0]
  ess <- length(tv_distances) / (1 + 2 * sum(positive_acf))

  cat(sprintf("Effective sample size (TV distance): %.0f / %d = %.2f%%\n",
              ess, length(tv_distances), 100 * ess / length(tv_distances)))

  invisible(list(acf_tv = acf_tv, acf_dim1 = acf_dim1, ess = ess))
}

#' Test uniformity of volume coverage
#'
#' @param P0 baseline distribution
#' @param lambda TV radius
#' @param n_samples number of samples
test_volume_coverage <- function(P0, lambda, n_samples = 5000) {

  cat("Testing volume coverage\n")
  cat("If sampling is uniform, TV distances should follow a specific distribution\n")
  cat("(related to the geometry of the TV ball)\n\n")

  samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = n_samples,
    burn_in = 1000,
    thin = 10,
    verbose = FALSE
  )

  tv_distances <- apply(samples, 1, tv_distance, P0 = P0)

  # For a uniform distribution over a d-ball of radius R,
  # the radial distribution is proportional to r^(d-1)
  # For TV ball in K dimensions, effective dimension is K-1 (simplex constraint)
  # So we expect TV distances ~ r^(K-2) for small K

  K <- length(P0)

  # Theoretical: for uniform in K-1 dimensional ball,
  # radial density is proportional to r^(K-2)
  # CDF: F(r) = (r/R)^(K-1)

  # QQ plot against this theoretical distribution
  empirical_quantiles <- quantile(tv_distances, probs = seq(0.01, 0.99, by = 0.01))
  theoretical_quantiles <- lambda * (seq(0.01, 0.99, by = 0.01)^(1/(K-1)))

  qq_df <- tibble(
    theoretical = theoretical_quantiles,
    empirical = empirical_quantiles
  )

  p <- ggplot(qq_df, aes(x = theoretical, y = empirical)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "red") +
    geom_point(alpha = 0.6) +
    labs(
      title = sprintf("QQ Plot: Radial Distribution (K=%d)", K),
      subtitle = sprintf("Theoretical: r^(K-1) distribution in %d-ball", K-1),
      x = "Theoretical Quantiles",
      y = "Empirical Quantiles"
    ) +
    theme_minimal() +
    coord_fixed()

  print(p)
  ggsave(
    "explorations/tv_ball_geometry/figures/volume_coverage_qq.pdf",
    p, width = 6, height = 6
  )

  # Compute correlation (should be high if matches theoretical)
  qq_cor <- cor(qq_df$theoretical, qq_df$empirical)
  cat(sprintf("QQ correlation: %.4f (high values indicate good fit)\n", qq_cor))

  invisible(qq_df)
}

# Run diagnostics if interactive
if (interactive()) {
  # Setup
  K <- 5
  lambda <- 0.3
  P0 <- rep(1/K, K)

  # Check convergence
  cat("\n=== Convergence Check ===\n")
  conv_results <- check_convergence(P0, lambda, n_chains = 4, n_samples = 1000)

  # Check mixing
  cat("\n=== Mixing Check ===\n")
  mix_results <- check_mixing(P0, lambda)

  # Check volume coverage
  cat("\n=== Volume Coverage ===\n")
  vol_results <- test_volume_coverage(P0, lambda, n_samples = 5000)

  cat("\n=== Summary ===\n")
  cat("All diagnostics complete. Check figures/ directory for plots.\n")
}
