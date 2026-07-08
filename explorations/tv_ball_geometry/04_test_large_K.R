# Test Hit-and-Run with Large K (Realistic Problem Sizes)
#
# Real problems might have K = 100-500 types
# Test scalability and timing

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Test sampler performance for different K values
#'
#' @param K_values vector of dimensions to test
#' @param lambda TV radius
#' @param n_samples number of samples (per K)
test_large_K <- function(
  K_values = c(10, 50, 100, 200),
  lambda = 0.3,
  n_samples = 500
) {

  cat("Testing hit-and-run with large K\n")
  cat(sprintf("K values: %s\n", paste(K_values, collapse=", ")))
  cat(sprintf("λ = %.2f, n_samples = %d\n\n", lambda, n_samples))

  results <- list()

  for (K in K_values) {
    cat(sprintf("\n=== Testing K = %d ===\n", K))

    # Baseline distribution
    P0 <- rep(1/K, K)

    # Time the sampling
    start_time <- Sys.time()

    samples <- hit_and_run_tv_ball(
      P0 = P0,
      lambda = lambda,
      n_samples = n_samples,
      burn_in = 500,
      thin = 5,
      verbose = FALSE
    )

    end_time <- Sys.time()
    elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

    # Diagnostics
    tv_distances <- apply(samples, 1, tv_distance, P0 = P0)

    cat(sprintf("Time elapsed: %.2f seconds (%.1f samples/sec)\n",
                elapsed, n_samples / elapsed))
    cat(sprintf("TV distances - mean: %.4f, sd: %.4f, max: %.4f\n",
                mean(tv_distances), sd(tv_distances), max(tv_distances)))
    cat(sprintf("All valid: %s\n",
                all(tv_distances <= lambda + 1e-6) && all(samples >= -1e-10)))

    # Store results
    results[[length(results) + 1]] <- tibble(
      K = K,
      elapsed_sec = elapsed,
      samples_per_sec = n_samples / elapsed,
      mean_tv = mean(tv_distances),
      sd_tv = sd(tv_distances),
      max_tv = max(tv_distances),
      all_valid = all(tv_distances <= lambda + 1e-6)
    )
  }

  # Combine results
  df <- bind_rows(results)

  # Print summary table
  cat("\n=== Summary ===\n")
  print(df, n = Inf)

  # Plot timing
  p1 <- ggplot(df, aes(x = K, y = elapsed_sec)) +
    geom_point(size = 3) +
    geom_line() +
    labs(
      title = "Computation Time vs Dimension",
      x = "Dimension K",
      y = "Time (seconds)"
    ) +
    theme_minimal()

  print(p1)
  ggsave(
    "explorations/tv_ball_geometry/figures/timing_vs_K.pdf",
    p1, width = 7, height = 5
  )

  # Plot throughput
  p2 <- ggplot(df, aes(x = K, y = samples_per_sec)) +
    geom_point(size = 3) +
    geom_line() +
    labs(
      title = "Sampling Throughput vs Dimension",
      x = "Dimension K",
      y = "Samples per second"
    ) +
    theme_minimal()

  print(p2)
  ggsave(
    "explorations/tv_ball_geometry/figures/throughput_vs_K.pdf",
    p2, width = 7, height = 5
  )

  # Plot TV statistics
  p3 <- ggplot(df, aes(x = K)) +
    geom_point(aes(y = mean_tv, color = "Mean"), size = 3) +
    geom_line(aes(y = mean_tv, color = "Mean")) +
    geom_point(aes(y = mean_tv + sd_tv, color = "Mean + SD"), size = 2) +
    geom_line(aes(y = mean_tv + sd_tv, color = "Mean + SD"), linetype = "dashed") +
    geom_hline(yintercept = lambda, linetype = "dotted", color = "red") +
    labs(
      title = "TV Distance Statistics vs Dimension",
      x = "Dimension K",
      y = "TV Distance",
      color = ""
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  print(p3)
  ggsave(
    "explorations/tv_ball_geometry/figures/tv_stats_vs_K.pdf",
    p3, width = 7, height = 5
  )

  invisible(df)
}

#' Quick test with a very large K
#'
#' @param K dimension
#' @param lambda TV radius
quick_test_very_large_K <- function(K = 500, lambda = 0.3) {

  cat(sprintf("\n=== Quick Test: K = %d ===\n", K))

  P0 <- rep(1/K, K)

  # Just get 100 samples to test feasibility
  start_time <- Sys.time()

  samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = 100,
    burn_in = 200,
    thin = 5,
    verbose = TRUE
  )

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  tv_distances <- apply(samples, 1, tv_distance, P0 = P0)

  cat(sprintf("\nTime for 100 samples: %.2f seconds\n", elapsed))
  cat(sprintf("Estimated time for 5000 samples: %.1f minutes\n", elapsed * 50 / 60))
  cat(sprintf("Mean TV distance: %.4f\n", mean(tv_distances)))
  cat(sprintf("All valid: %s\n", all(tv_distances <= lambda + 1e-6)))
}

#' Test mixing for large K
#'
#' @param K dimension
#' @param lambda TV radius
test_mixing_large_K <- function(K = 100, lambda = 0.3) {

  cat(sprintf("\n=== Testing Mixing for K = %d ===\n", K))

  P0 <- rep(1/K, K)

  # Sample with no thinning to check autocorrelation
  samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = 1000,
    burn_in = 500,
    thin = 1,
    verbose = FALSE
  )

  tv_distances <- apply(samples, 1, tv_distance, P0 = P0)

  # Autocorrelation
  acf_result <- acf(tv_distances, lag.max = 50, plot = FALSE)
  acf_df <- tibble(
    lag = 0:50,
    autocorr = as.numeric(acf_result$acf)
  )

  # Estimate ESS
  positive_acf <- acf_df$autocorr[acf_df$autocorr > 0 & acf_df$lag > 0]
  ess <- length(tv_distances) / (1 + 2 * sum(positive_acf))

  cat(sprintf("Effective sample size: %.0f / %d = %.2f%%\n",
              ess, length(tv_distances), 100 * ess / length(tv_distances)))

  # Plot
  p <- ggplot(acf_df, aes(x = lag, y = autocorr)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_col(fill = "steelblue", alpha = 0.7) +
    labs(
      title = sprintf("Autocorrelation for K = %d", K),
      x = "Lag",
      y = "Autocorrelation"
    ) +
    theme_minimal()

  print(p)
  ggsave(
    sprintf("explorations/tv_ball_geometry/figures/autocorr_K%d.pdf", K),
    p, width = 7, height = 5
  )

  invisible(list(acf = acf_df, ess = ess))
}

# Run tests if interactive
if (interactive()) {
  cat("=== Scalability Test ===\n")
  timing_results <- test_large_K(
    K_values = c(10, 50, 100, 200),
    lambda = 0.3,
    n_samples = 500
  )

  cat("\n=== Mixing Test (K=100) ===\n")
  mixing_results <- test_mixing_large_K(K = 100, lambda = 0.3)

  cat("\n=== Very Large K Test (K=500) ===\n")
  quick_test_very_large_K(K = 500, lambda = 0.3)
}
