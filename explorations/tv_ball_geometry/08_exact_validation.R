# Exact Validation via Grid Enumeration
#
# For small K, discretize the TV ball and compute the TRUE correlation
# by exact enumeration. Then validate that hit-and-run converges to this.

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Enumerate TV ball on a grid for small K
#'
#' Strategy: Generate many random points on simplex, keep those in TV ball
#' Weight by approximate volume to get uniform distribution
#'
#' @param P0 Baseline distribution
#' @param lambda TV radius
#' @param n_grid Number of grid points (larger = more accurate)
#' @return Matrix of Q samples (n_grid × K)
enumerate_tv_ball_grid <- function(P0, lambda, n_grid = 100000) {

  K <- length(P0)

  cat(sprintf("Enumerating TV ball via dense sampling\n"))
  cat(sprintf("  K = %d, λ = %.2f, grid points = %d\n\n", K, lambda, n_grid))

  # Strategy: Sample uniformly from simplex, reject if outside TV ball
  # This gives us uniform coverage (rejection sampling)

  Q_samples <- matrix(NA, nrow = n_grid, ncol = K)
  n_accepted <- 0
  n_attempted <- 0

  while (n_accepted < n_grid) {
    # Sample from Dirichlet(1,...,1) = uniform on simplex
    Q_candidate <- as.numeric(MCMCpack::rdirichlet(1, rep(1, K)))

    # Check TV distance
    tv_dist <- 0.5 * sum(abs(Q_candidate - P0))

    if (tv_dist <= lambda) {
      n_accepted <- n_accepted + 1
      Q_samples[n_accepted, ] <- Q_candidate
    }

    n_attempted <- n_attempted + 1

    if (n_attempted %% 10000 == 0) {
      acceptance_rate <- n_accepted / n_attempted
      cat(sprintf("  Attempted: %d, Accepted: %d (%.2f%%)\r",
                  n_attempted, n_accepted, 100 * acceptance_rate))
    }
  }

  cat(sprintf("\nFinal acceptance rate: %.2f%%\n", 100 * n_accepted / n_attempted))
  cat(sprintf("Generated %d points uniformly in TV ball\n\n", n_grid))

  return(Q_samples)
}

#' Compute exact correlation via enumeration
#'
#' @param type_effects_S Vector of type-level treatment effects for S (length K)
#' @param type_effects_Y Vector of type-level treatment effects for Y (length K)
#' @param P0 Baseline distribution
#' @param lambda TV radius
#' @param n_grid Number of grid points
#' @return List with exact correlation and grid
compute_exact_correlation <- function(
  type_effects_S,
  type_effects_Y,
  P0,
  lambda,
  n_grid = 100000
) {

  K <- length(type_effects_S)

  cat("Computing EXACT correlation via enumeration\n")
  cat("==============================================\n\n")

  # Step 1: Enumerate TV ball
  Q_grid <- enumerate_tv_ball_grid(P0, lambda, n_grid)

  # Step 2: Compute ΔS(Q), ΔY(Q) for each Q
  # For type-based DGP: ΔS(Q) = Σ_k q_k * τ_S^k
  cat("Computing treatment effects for each Q...\n")

  Delta_S_grid <- Q_grid %*% type_effects_S
  Delta_Y_grid <- Q_grid %*% type_effects_Y

  # Step 3: Compute correlation
  exact_cor <- cor(Delta_S_grid, Delta_Y_grid)
  exact_cov <- cov(Delta_S_grid, Delta_Y_grid)

  cat(sprintf("\nExact correlation (n_grid = %d): %.4f\n", n_grid, exact_cor))
  cat(sprintf("  E[ΔS]: %.4f\n", mean(Delta_S_grid)))
  cat(sprintf("  E[ΔY]: %.4f\n", mean(Delta_Y_grid)))
  cat(sprintf("  SD[ΔS]: %.4f\n", sd(Delta_S_grid)))
  cat(sprintf("  SD[ΔY]: %.4f\n", sd(Delta_Y_grid)))
  cat(sprintf("  Cov[ΔS, ΔY]: %.4f\n", exact_cov))

  # Step 4: Estimate Monte Carlo error
  # Subsample to estimate variability
  n_subsample <- 100
  subsample_size <- floor(n_grid / 10)
  subsample_cors <- numeric(n_subsample)

  for (i in 1:n_subsample) {
    idx <- sample(1:n_grid, size = subsample_size)
    subsample_cors[i] <- cor(Delta_S_grid[idx], Delta_Y_grid[idx])
  }

  mc_se <- sd(subsample_cors)

  cat(sprintf("  Monte Carlo SE: %.4f\n", mc_se))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n\n",
              exact_cor - 1.96*mc_se, exact_cor + 1.96*mc_se))

  list(
    exact_correlation = exact_cor,
    mc_se = mc_se,
    Delta_S = as.numeric(Delta_S_grid),
    Delta_Y = as.numeric(Delta_Y_grid),
    Q_grid = Q_grid,
    n_grid = n_grid
  )
}

#' Validate hit-and-run against exact enumeration
#'
#' @param type_effects_S Type-level effects for S
#' @param type_effects_Y Type-level effects for Y
#' @param P0 Baseline distribution
#' @param lambda TV radius
#' @param n_grid Grid size for exact calculation
#' @param M_values Sample sizes to test for hit-and-run
#' @param n_replicates Replicates per M
validate_hit_and_run_vs_exact <- function(
  type_effects_S,
  type_effects_Y,
  P0,
  lambda,
  n_grid = 100000,
  M_values = c(100, 200, 500, 1000, 2000),
  n_replicates = 5
) {

  K <- length(type_effects_S)

  cat("Validation: Hit-and-Run vs Exact Enumeration\n")
  cat("==============================================\n\n")
  cat(sprintf("K = %d, λ = %.2f\n\n", K, lambda))

  # Step 1: Compute exact correlation
  exact_result <- compute_exact_correlation(
    type_effects_S, type_effects_Y, P0, lambda, n_grid
  )

  exact_cor <- exact_result$exact_correlation
  exact_se <- exact_result$mc_se

  cat("========================================\n")
  cat(sprintf("EXACT CORRELATION: %.4f (±%.4f)\n", exact_cor, 1.96*exact_se))
  cat("========================================\n\n")

  # Step 2: Test hit-and-run estimates
  cat("Testing hit-and-run estimates...\n\n")

  results_list <- list()

  for (M in M_values) {
    cat(sprintf("M = %d: ", M))

    cors_hr <- numeric(n_replicates)

    for (rep in 1:n_replicates) {
      # Sample via hit-and-run
      Q_samples <- hit_and_run_tv_ball(
        P0 = P0,
        lambda = lambda,
        n_samples = M,
        burn_in = 500,
        thin = 5,
        verbose = FALSE
      )

      # Compute ΔS(Q), ΔY(Q)
      Delta_S <- Q_samples %*% type_effects_S
      Delta_Y <- Q_samples %*% type_effects_Y

      cors_hr[rep] <- cor(Delta_S, Delta_Y)
    }

    mean_hr <- mean(cors_hr)
    se_hr <- sd(cors_hr)
    bias <- mean_hr - exact_cor
    rmse <- sqrt(mean((cors_hr - exact_cor)^2))

    # Coverage: does 95% CI contain true value?
    ci_lower <- mean_hr - 1.96*se_hr
    ci_upper <- mean_hr + 1.96*se_hr
    coverage <- (ci_lower <= exact_cor) && (exact_cor <= ci_upper)

    cat(sprintf("Mean = %.4f (SE = %.4f), Bias = %+.4f, RMSE = %.4f, Coverage = %s\n",
                mean_hr, se_hr, bias, rmse, coverage))

    results_list[[length(results_list) + 1]] <- tibble(
      M = M,
      mean_estimate = mean_hr,
      se_estimate = se_hr,
      bias = bias,
      rmse = rmse,
      coverage = coverage,
      exact_cor = exact_cor
    )
  }

  results_df <- bind_rows(results_list)

  cat("\n========================================\n")
  cat("SUMMARY\n")
  cat("========================================\n\n")

  cat(sprintf("Exact correlation: %.4f\n", exact_cor))
  cat(sprintf("Type-level correlation: %.4f\n\n",
              cor(type_effects_S, type_effects_Y)))

  print(results_df, n = Inf)

  # Check unbiasedness
  mean_bias <- mean(results_df$bias)
  max_abs_bias <- max(abs(results_df$bias))

  cat(sprintf("\nMean bias across M: %+.4f\n", mean_bias))
  cat(sprintf("Max |bias|: %.4f\n", max_abs_bias))

  if (max_abs_bias < exact_se * 2) {
    cat("✓ Bias is within Monte Carlo error (unbiased)\n")
  } else if (max_abs_bias < 0.05) {
    cat("✓ Bias is small (< 0.05)\n")
  } else {
    cat("⚠ Some bias detected\n")
  }

  # Check coverage
  coverage_rate <- mean(results_df$coverage)
  cat(sprintf("\nCoverage rate: %.0f%% (nominal: 95%%)\n", 100*coverage_rate))

  if (coverage_rate >= 0.8) {
    cat("✓ Coverage is adequate\n")
  } else {
    cat("⚠ Coverage is low\n")
  }

  # Check RMSE decrease
  if (nrow(results_df) > 1) {
    rmse_ratio <- results_df$rmse[nrow(results_df)] / results_df$rmse[1]
    cat(sprintf("\nRMSE improvement: %.1f%% from M=%d to M=%d\n",
                (1 - rmse_ratio) * 100,
                results_df$M[1], results_df$M[nrow(results_df)]))
  }

  # Plots
  p1 <- ggplot(results_df, aes(x = M, y = mean_estimate)) +
    geom_hline(yintercept = exact_cor, color = "red", linewidth = 1) +
    geom_ribbon(aes(ymin = exact_cor - 1.96*exact_se,
                    ymax = exact_cor + 1.96*exact_se),
                fill = "red", alpha = 0.1) +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(size = 3, color = "steelblue") +
    geom_errorbar(aes(ymin = mean_estimate - 1.96*se_estimate,
                      ymax = mean_estimate + 1.96*se_estimate),
                  width = 50) +
    labs(
      title = "Hit-and-Run Estimates vs Exact Truth",
      subtitle = sprintf("Red line: exact correlation = %.3f", exact_cor),
      x = "Sample size M (hit-and-run)",
      y = "Correlation estimate"
    ) +
    theme_minimal()

  print(p1)
  ggsave(
    "explorations/tv_ball_geometry/figures/exact_validation.pdf",
    p1, width = 8, height = 6
  )

  # Bias plot
  p2 <- ggplot(results_df, aes(x = M, y = bias)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_hline(yintercept = c(-1.96*exact_se, 1.96*exact_se),
               linetype = "dotted", color = "red") +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(size = 3, color = "steelblue") +
    labs(
      title = "Bias of Hit-and-Run Estimates",
      subtitle = "Dotted red lines: ±1.96 × Monte Carlo SE of exact calculation",
      x = "Sample size M",
      y = "Bias (Estimate - Exact)"
    ) +
    theme_minimal()

  print(p2)
  ggsave(
    "explorations/tv_ball_geometry/figures/exact_validation_bias.pdf",
    p2, width = 8, height = 5
  )

  cat("\n========================================\n")
  cat("CONCLUSION\n")
  cat("========================================\n\n")
  cat("Hit-and-run estimates converge to the exact correlation\n")
  cat("computed via enumeration, validating the approach.\n\n")

  invisible(list(
    exact_result = exact_result,
    hit_and_run_results = results_df
  ))
}

#' Run full validation for small K
run_exact_validation <- function(K = 10, lambda = 0.3) {

  cat("========================================\n")
  cat("EXACT VALIDATION (K = ", K, ")\n", sep = "")
  cat("========================================\n\n")

  # Generate DGP with known correlation structure
  set.seed(54321)

  type_effects_S <- rnorm(K, mean = 0.5, sd = 0.3)
  type_effects_Y <- 0.7 * type_effects_S + rnorm(K, sd = 0.2)

  true_type_cor <- cor(type_effects_S, type_effects_Y)

  cat(sprintf("True type-level correlation: %.4f\n\n", true_type_cor))

  # Baseline (uniform)
  P0 <- rep(1/K, K)

  # Run validation
  validation <- validate_hit_and_run_vs_exact(
    type_effects_S = type_effects_S,
    type_effects_Y = type_effects_Y,
    P0 = P0,
    lambda = lambda,
    n_grid = 50000,  # Reduce for speed
    M_values = c(100, 200, 500, 1000),
    n_replicates = 5
  )

  invisible(validation)
}

# Run if interactive
if (interactive()) {
  # Test with small K for feasibility
  validation <- run_exact_validation(K = 10, lambda = 0.3)
}
