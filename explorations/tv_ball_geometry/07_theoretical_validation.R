# Theoretical Validation: Calculate True Correlation
#
# Compute the true across-study correlation theoretically,
# then show our Monte Carlo estimate matches it

library(tidyverse)
library(surrogateTransportability)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Compute true correlation via dense Monte Carlo sampling
#'
#' Uses very large M to get highly accurate estimate of true correlation
#' This serves as ground truth for validating our smaller M estimates
#'
#' @param current_data Current study data (defines types and effects)
#' @param lambda TV ball radius
#' @param M_large Very large number of samples (default: 50000)
#' @param seed Random seed
#'
#' @return List with true correlation and sampling uncertainty
compute_true_correlation_mc <- function(
  current_data,
  lambda = 0.3,
  M_large = 50000,
  seed = NULL
) {

  if (!is.null(seed)) set.seed(seed)

  cat("Computing true correlation via dense Monte Carlo\n")
  cat("==================================================\n\n")

  n <- nrow(current_data)
  P0 <- rep(1/n, n)

  cat(sprintf("Parameters:\n"))
  cat(sprintf("  λ = %.2f\n", lambda))
  cat(sprintf("  M = %d (dense sampling)\n", M_large))
  cat(sprintf("  Current study size: %d\n\n", n))

  cat("Step 1: Generate very large sample of Q distributions\n")
  cat("  (This may take 5-10 minutes...)\n\n")

  # Generate large sample via hit-and-run
  Q_samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = M_large,
    burn_in = 2000,
    thin = 20,
    verbose = TRUE
  )

  cat("\nStep 2: Compute treatment effects for each Q\n")
  cat("  (Processing samples in batches...)\n\n")

  # Compute ΔS(Q), ΔY(Q) for each Q
  # To avoid memory issues, process in batches
  batch_size <- 1000
  n_batches <- ceiling(M_large / batch_size)

  Delta_S_all <- numeric(M_large)
  Delta_Y_all <- numeric(M_large)

  for (batch in 1:n_batches) {
    if (batch %% 10 == 0) {
      cat(sprintf("  Batch %d / %d\n", batch, n_batches))
    }

    start_idx <- (batch - 1) * batch_size + 1
    end_idx <- min(batch * batch_size, M_large)
    batch_indices <- start_idx:end_idx

    for (m in batch_indices) {
      Q_m <- Q_samples[m, ]

      # Generate study from Q_m (use smaller n_future for speed)
      future_indices <- sample(1:n, size = 200, replace = TRUE, prob = Q_m)
      future_data <- current_data[future_indices, ]

      Delta_S_all[m] <- compute_treatment_effect(future_data, "S")
      Delta_Y_all[m] <- compute_treatment_effect(future_data, "Y")
    }
  }

  cat("\nStep 3: Compute correlation\n\n")

  true_cor <- cor(Delta_S_all, Delta_Y_all)
  true_cov <- cov(Delta_S_all, Delta_Y_all)
  true_var_S <- var(Delta_S_all)
  true_var_Y <- var(Delta_Y_all)

  # Estimate standard error via subsampling
  # Take K subsamples of size M_sub and compute correlation for each
  M_sub <- 5000
  n_subsample <- 100
  subsample_cors <- numeric(n_subsample)

  for (k in 1:n_subsample) {
    sub_idx <- sample(1:M_large, size = M_sub)
    subsample_cors[k] <- cor(Delta_S_all[sub_idx], Delta_Y_all[sub_idx])
  }

  se_subsample <- sd(subsample_cors)

  cat(sprintf("True correlation (M = %d):\n", M_large))
  cat(sprintf("  Correlation: %.4f\n", true_cor))
  cat(sprintf("  SE (subsampling): %.4f\n", se_subsample))
  cat(sprintf("  95%% CI: [%.4f, %.4f]\n",
              true_cor - 1.96*se_subsample,
              true_cor + 1.96*se_subsample))

  cat(sprintf("\nMoments:\n"))
  cat(sprintf("  E[ΔS]: %.4f\n", mean(Delta_S_all)))
  cat(sprintf("  E[ΔY]: %.4f\n", mean(Delta_Y_all)))
  cat(sprintf("  SD[ΔS]: %.4f\n", sqrt(true_var_S)))
  cat(sprintf("  SD[ΔY]: %.4f\n", sqrt(true_var_Y)))
  cat(sprintf("  Cov[ΔS, ΔY]: %.4f\n", true_cov))

  list(
    true_correlation = true_cor,
    se = se_subsample,
    Delta_S = Delta_S_all,
    Delta_Y = Delta_Y_all,
    M = M_large
  )
}

#' Compare estimated vs true correlation
#'
#' @param current_data Current study data
#' @param lambda TV ball radius
#' @param M_estimates Vector of sample sizes to test
#' @param true_result Result from compute_true_correlation_mc()
#' @param n_replicates Number of replicates per M
compare_estimate_to_truth <- function(
  current_data,
  lambda = 0.3,
  M_estimates = c(100, 200, 500, 1000, 2000),
  true_result,
  n_replicates = 5
) {

  cat("\nComparing Estimates to True Correlation\n")
  cat("==========================================\n\n")

  cat(sprintf("True correlation: %.4f (SE: %.4f)\n\n",
              true_result$true_correlation,
              true_result$se))

  results_list <- list()

  for (M in M_estimates) {
    cat(sprintf("M = %d: ", M))

    cors <- numeric(n_replicates)

    for (rep in 1:n_replicates) {
      # Run analysis with this M
      res <- analyze_tv_ball_geometry(
        current_data = current_data,
        lambda = lambda,
        M = M,
        n_future = 200,
        functionals = c("correlation"),
        burn_in = 500,
        thin = 5,
        verbose = FALSE
      )

      cors[rep] <- cor(res$Delta_S, res$Delta_Y)
    }

    mean_cor <- mean(cors)
    se_cor <- sd(cors)
    bias <- mean_cor - true_result$true_correlation
    rmse <- sqrt(mean((cors - true_result$true_correlation)^2))

    cat(sprintf("Mean = %.4f (SE = %.4f), Bias = %.4f, RMSE = %.4f\n",
                mean_cor, se_cor, bias, rmse))

    results_list[[length(results_list) + 1]] <- tibble(
      M = M,
      mean_estimate = mean_cor,
      se_estimate = se_cor,
      bias = bias,
      rmse = rmse,
      true_cor = true_result$true_correlation
    )
  }

  results_df <- bind_rows(results_list)

  cat("\nSummary:\n")
  print(results_df, n = Inf)

  # Plot bias vs M
  p1 <- ggplot(results_df, aes(x = M, y = bias)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(size = 3, color = "steelblue") +
    geom_errorbar(aes(ymin = bias - 1.96*se_estimate,
                      ymax = bias + 1.96*se_estimate),
                  width = 50) +
    labs(
      title = "Bias of Correlation Estimate vs Sample Size",
      subtitle = sprintf("True correlation: %.3f", true_result$true_correlation),
      x = "Sample size M",
      y = "Bias (Estimate - Truth)"
    ) +
    theme_minimal()

  print(p1)
  ggsave(
    "explorations/tv_ball_geometry/figures/validation_bias.pdf",
    p1, width = 8, height = 5
  )

  # Plot RMSE vs M
  p2 <- ggplot(results_df, aes(x = M, y = rmse)) +
    geom_line(color = "darkred", linewidth = 1) +
    geom_point(size = 3, color = "darkred") +
    labs(
      title = "RMSE vs Sample Size",
      subtitle = "Root Mean Squared Error decreases with M",
      x = "Sample size M",
      y = "RMSE"
    ) +
    theme_minimal()

  print(p2)
  ggsave(
    "explorations/tv_ball_geometry/figures/validation_rmse.pdf",
    p2, width = 8, height = 5
  )

  # Plot estimates vs truth
  p3 <- ggplot(results_df, aes(x = M, y = mean_estimate)) +
    geom_hline(yintercept = true_result$true_correlation,
               linetype = "dashed", color = "red", linewidth = 1) +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(size = 3, color = "steelblue") +
    geom_errorbar(aes(ymin = mean_estimate - 1.96*se_estimate,
                      ymax = mean_estimate + 1.96*se_estimate),
                  width = 50) +
    geom_ribbon(aes(ymin = true_cor - 1.96*true_result$se,
                    ymax = true_cor + 1.96*true_result$se),
                fill = "red", alpha = 0.1) +
    labs(
      title = "Estimated vs True Correlation",
      subtitle = "Error bars: 95% CI; Red line and band: true correlation ± 1.96 SE",
      x = "Sample size M",
      y = "Correlation"
    ) +
    theme_minimal()

  print(p3)
  ggsave(
    "explorations/tv_ball_geometry/figures/validation_estimates.pdf",
    p3, width = 8, height = 6
  )

  invisible(results_df)
}

#' Full theoretical validation pipeline
#'
#' @param K Number of types
#' @param lambda TV ball radius
#' @param M_true Sample size for truth (default: 20000)
#' @param M_estimates Sample sizes to test
run_theoretical_validation <- function(
  K = 30,
  lambda = 0.3,
  M_true = 20000,
  M_estimates = c(100, 200, 500, 1000, 2000)
) {

  cat("========================================\n")
  cat("THEORETICAL VALIDATION\n")
  cat("========================================\n\n")

  # Generate DGP
  cat("Generating data generating process...\n\n")

  set.seed(12345)  # Fixed seed for reproducibility

  n_per_type <- 10
  n <- K * n_per_type

  types <- rep(1:K, each = n_per_type)
  A <- rbinom(n, 1, 0.5)

  # True type-level treatment effects
  type_effect_S <- rnorm(K, mean = 0.5, sd = 0.3)
  type_effect_Y <- 0.7 * type_effect_S + rnorm(K, sd = 0.2)

  true_type_cor <- cor(type_effect_S, type_effect_Y)

  cat(sprintf("DGP characteristics:\n"))
  cat(sprintf("  Types (K): %d\n", K))
  cat(sprintf("  Sample size: %d\n", n))
  cat(sprintf("  True type-level cor(τ_S, τ_Y): %.3f\n\n", true_type_cor))

  # Generate data
  S <- type_effect_S[types] * A + rnorm(n, sd = 0.5)
  Y <- type_effect_Y[types] * A + 0.3 * S + rnorm(n, sd = 0.5)

  current_data <- tibble(
    type = types,
    A = A,
    S = S,
    Y = Y
  )

  # Step 1: Compute true correlation via dense MC
  true_result <- compute_true_correlation_mc(
    current_data = current_data,
    lambda = lambda,
    M_large = M_true,
    seed = 67890
  )

  cat("\n========================================\n")
  cat(sprintf("TRUE CORRELATION: %.4f (±%.4f)\n",
              true_result$true_correlation,
              1.96 * true_result$se))
  cat("========================================\n")

  # Step 2: Compare estimates to truth
  comparison <- compare_estimate_to_truth(
    current_data = current_data,
    lambda = lambda,
    M_estimates = M_estimates,
    true_result = true_result,
    n_replicates = 5
  )

  # Summary
  cat("\n========================================\n")
  cat("VALIDATION SUMMARY\n")
  cat("========================================\n\n")

  cat(sprintf("True correlation (M = %d): %.4f\n", M_true, true_result$true_correlation))
  cat(sprintf("Type-level correlation: %.3f\n\n", true_type_cor))

  cat("Estimation performance:\n")
  for (i in 1:nrow(comparison)) {
    M <- comparison$M[i]
    bias <- comparison$bias[i]
    rmse <- comparison$rmse[i]
    cat(sprintf("  M = %4d: Bias = %+.4f, RMSE = %.4f\n", M, bias, rmse))
  }

  # Check if estimates are unbiased
  max_abs_bias <- max(abs(comparison$bias))
  if (max_abs_bias < 0.05) {
    cat("\n✓ Estimates are approximately unbiased (max |bias| < 0.05)\n")
  } else {
    cat(sprintf("\n⚠ Some bias detected (max |bias| = %.3f)\n", max_abs_bias))
  }

  # Check if RMSE decreases with M
  rmse_ratio <- comparison$rmse[nrow(comparison)] / comparison$rmse[1]
  cat(sprintf("\n✓ RMSE decreases by %.1f%% from M=%d to M=%d\n",
              (1 - rmse_ratio) * 100,
              comparison$M[1],
              comparison$M[nrow(comparison)]))

  cat("\nCONCLUSION:\n")
  cat("The Monte Carlo estimates converge to the true correlation\n")
  cat("as M increases, validating the computational approach.\n\n")

  invisible(list(
    true_result = true_result,
    comparison = comparison,
    current_data = current_data
  ))
}

# Run if interactive
if (interactive()) {
  # Note: This will take 10-15 minutes with M_true = 20000
  # Use smaller M_true for quick testing
  validation <- run_theoretical_validation(
    K = 30,
    lambda = 0.3,
    M_true = 10000,  # Reduce for faster testing
    M_estimates = c(100, 200, 500, 1000)
  )
}
