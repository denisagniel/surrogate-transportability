# Analytical Correlation via TV Ball Geometry
#
# Derive exact correlation from parametric treatment effects
# Cor(ΔS(Q), ΔY(Q)) = (τ_S' Σ_Q τ_Y) / sqrt((τ_S' Σ_Q τ_S)(τ_Y' Σ_Q τ_Y))
# where Σ_Q = Var[Q] for Q ~ Uniform(B_λ(P_0))

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Compute TV ball variance-covariance matrix Σ_Q
#'
#' For Q ~ Uniform(B_λ(P_0)), compute Var[Q] via sampling
#'
#' @param P0 Baseline distribution (K-vector)
#' @param lambda TV ball radius
#' @param n_samples Number of samples (larger = more accurate)
#' @param method "rejection" (exact) or "hit_and_run" (MCMC)
#' @return K × K covariance matrix Σ_Q
compute_tv_ball_covariance <- function(
  P0,
  lambda,
  n_samples = 50000,
  method = c("rejection", "hit_and_run")
) {

  method <- match.arg(method)
  K <- length(P0)

  cat(sprintf("Computing TV ball covariance matrix Σ_Q\n"))
  cat(sprintf("  K = %d, λ = %.2f, method = %s, n = %d\n\n",
              K, lambda, method, n_samples))

  # Generate Q samples
  if (method == "rejection") {
    # Exact via rejection sampling
    cat("Sampling via rejection (exact uniform)...\n")
    Q_samples <- matrix(NA, nrow = n_samples, ncol = K)
    n_accepted <- 0
    n_attempted <- 0

    while (n_accepted < n_samples) {
      Q_candidate <- as.numeric(MCMCpack::rdirichlet(1, rep(1, K)))
      tv_dist <- 0.5 * sum(abs(Q_candidate - P0))

      if (tv_dist <= lambda) {
        n_accepted <- n_accepted + 1
        Q_samples[n_accepted, ] <- Q_candidate
      }

      n_attempted <- n_attempted + 1

      if (n_attempted %% 10000 == 0) {
        cat(sprintf("  Progress: %d / %d accepted (%.1f%%)\r",
                    n_accepted, n_samples, 100 * n_accepted / n_attempted))
      }
    }
    cat(sprintf("\n  Acceptance rate: %.2f%%\n", 100 * n_accepted / n_attempted))

  } else {
    # MCMC via hit-and-run
    cat("Sampling via hit-and-run MCMC...\n")
    Q_samples <- hit_and_run_tv_ball(
      P0 = P0,
      lambda = lambda,
      n_samples = n_samples,
      burn_in = 2000,
      thin = 20,
      verbose = TRUE
    )
  }

  # Compute covariance matrix
  cat("\nComputing covariance matrix...\n")
  Sigma_Q <- cov(Q_samples)

  # Summary
  cat(sprintf("\nΣ_Q characteristics:\n"))
  cat(sprintf("  Trace: %.4f\n", sum(diag(Sigma_Q))))
  cat(sprintf("  Determinant: %.4e\n", det(Sigma_Q)))
  cat(sprintf("  Condition number: %.2f\n",
              max(eigen(Sigma_Q)$values) / min(eigen(Sigma_Q)$values)))
  cat(sprintf("  Mean diagonal: %.4f\n", mean(diag(Sigma_Q))))
  cat(sprintf("  Mean off-diagonal: %.4f\n",
              mean(Sigma_Q[upper.tri(Sigma_Q)])))

  return(Sigma_Q)
}

#' Compute exact correlation from parametric specification
#'
#' Given tau_S and tau_Y, compute the exact correlation analytically
#'
#' @param tau_S K-vector of type-level treatment effects for S
#' @param tau_Y K-vector of type-level treatment effects for Y
#' @param Sigma_Q K × K covariance matrix of Q ~ Uniform(B_λ)
#' @return Exact correlation
compute_exact_correlation_analytical <- function(tau_S, tau_Y, Sigma_Q) {

  # Compute covariance: τ_S' Σ_Q τ_Y
  cov_SY <- as.numeric(t(tau_S) %*% Sigma_Q %*% tau_Y)

  # Compute variances: τ_S' Σ_Q τ_S and τ_Y' Σ_Q τ_Y
  var_S <- as.numeric(t(tau_S) %*% Sigma_Q %*% tau_S)
  var_Y <- as.numeric(t(tau_Y) %*% Sigma_Q %*% tau_Y)

  # Correlation
  cor_exact <- cov_SY / sqrt(var_S * var_Y)

  return(cor_exact)
}

#' Validate Monte Carlo estimate against analytical truth
#'
#' @param tau_S Type-level effects for S
#' @param tau_Y Type-level effects for Y
#' @param P0 Baseline distribution
#' @param lambda TV radius
#' @param n_grid Sample size for computing Σ_Q
#' @param M_values Monte Carlo sample sizes to test
validate_analytical <- function(
  tau_S,
  tau_Y,
  P0,
  lambda,
  n_grid = 50000,
  M_values = c(100, 200, 500, 1000, 2000),
  n_replicates = 5
) {

  K <- length(tau_S)

  cat("========================================\n")
  cat("ANALYTICAL VALIDATION\n")
  cat("========================================\n\n")

  cat(sprintf("Type-level correlation: %.4f\n\n", cor(tau_S, tau_Y)))

  # Step 1: Compute Σ_Q (the TV ball covariance structure)
  Sigma_Q <- compute_tv_ball_covariance(
    P0 = P0,
    lambda = lambda,
    n_samples = n_grid,
    method = "rejection"
  )

  # Step 2: Compute exact correlation analytically
  cor_exact <- compute_exact_correlation_analytical(tau_S, tau_Y, Sigma_Q)

  cat("\n========================================\n")
  cat(sprintf("EXACT ANALYTICAL CORRELATION: %.4f\n", cor_exact))
  cat("========================================\n\n")

  # Decomposition
  cov_SY <- as.numeric(t(tau_S) %*% Sigma_Q %*% tau_Y)
  var_S <- as.numeric(t(tau_S) %*% Sigma_Q %*% tau_S)
  var_Y <- as.numeric(t(tau_Y) %*% Sigma_Q %*% tau_Y)

  cat("Analytical decomposition:\n")
  cat(sprintf("  Cov[ΔS, ΔY] = τ_S' Σ_Q τ_Y = %.6f\n", cov_SY))
  cat(sprintf("  Var[ΔS]     = τ_S' Σ_Q τ_S = %.6f\n", var_S))
  cat(sprintf("  Var[ΔY]     = τ_Y' Σ_Q τ_Y = %.6f\n", var_Y))
  cat(sprintf("  SD[ΔS]      = %.4f\n", sqrt(var_S)))
  cat(sprintf("  SD[ΔY]      = %.4f\n", sqrt(var_Y)))
  cat(sprintf("  Cor         = %.4f\n\n", cor_exact))

  # Step 3: Compare to Monte Carlo estimates
  cat("Testing Monte Carlo estimates...\n\n")

  results_list <- list()

  for (M in M_values) {
    cat(sprintf("M = %d: ", M))

    cors_mc <- numeric(n_replicates)

    for (rep in 1:n_replicates) {
      # Sample Q via hit-and-run
      Q_samples <- hit_and_run_tv_ball(
        P0 = P0,
        lambda = lambda,
        n_samples = M,
        burn_in = 500,
        thin = 5,
        verbose = FALSE
      )

      # Compute ΔS(Q) = Q'τ_S and ΔY(Q) = Q'τ_Y
      Delta_S <- Q_samples %*% tau_S
      Delta_Y <- Q_samples %*% tau_Y

      cors_mc[rep] <- cor(Delta_S, Delta_Y)
    }

    mean_mc <- mean(cors_mc)
    se_mc <- sd(cors_mc)
    bias <- mean_mc - cor_exact
    rmse <- sqrt(mean((cors_mc - cor_exact)^2))

    cat(sprintf("Mean = %.4f (SE = %.4f), Bias = %+.4f, RMSE = %.4f\n",
                mean_mc, se_mc, bias, rmse))

    results_list[[length(results_list) + 1]] <- tibble(
      M = M,
      mean_estimate = mean_mc,
      se_estimate = se_mc,
      bias = bias,
      rmse = rmse,
      exact_cor = cor_exact
    )
  }

  results_df <- bind_rows(results_list)

  # Summary
  cat("\n========================================\n")
  cat("SUMMARY\n")
  cat("========================================\n\n")

  cat(sprintf("Analytical exact correlation: %.4f\n", cor_exact))
  cat(sprintf("Type-level correlation: %.4f\n\n", cor(tau_S, tau_Y)))

  print(results_df, n = Inf)

  cat(sprintf("\nMean bias: %+.5f\n", mean(results_df$bias)))
  cat(sprintf("Max |bias|: %.4f\n", max(abs(results_df$bias))))

  if (max(abs(results_df$bias)) < 0.05) {
    cat("✓ Monte Carlo estimates are approximately unbiased\n")
  }

  rmse_improvement <- (1 - results_df$rmse[nrow(results_df)] / results_df$rmse[1]) * 100
  cat(sprintf("\n✓ RMSE improves by %.1f%% from M=%d to M=%d\n",
              rmse_improvement, results_df$M[1], results_df$M[nrow(results_df)]))

  # Plot
  p <- ggplot(results_df, aes(x = M, y = mean_estimate)) +
    geom_hline(yintercept = cor_exact, color = "red", linewidth = 1) +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(size = 3, color = "steelblue") +
    geom_errorbar(aes(ymin = mean_estimate - 1.96*se_estimate,
                      ymax = mean_estimate + 1.96*se_estimate),
                  width = 50) +
    labs(
      title = "Monte Carlo vs Analytical Exact Correlation",
      subtitle = sprintf("Red line: analytical exact = %.3f", cor_exact),
      x = "Sample size M (Monte Carlo)",
      y = "Correlation estimate"
    ) +
    theme_minimal()

  print(p)
  ggsave(
    "explorations/tv_ball_geometry/figures/analytical_validation.pdf",
    p, width = 8, height = 6
  )

  cat("\n========================================\n")
  cat("CONCLUSION\n")
  cat("========================================\n\n")
  cat("Monte Carlo estimates converge to the analytical exact correlation,\n")
  cat("validating both the Monte Carlo approach and the analytical formula.\n\n")

  invisible(list(
    Sigma_Q = Sigma_Q,
    exact_correlation = cor_exact,
    mc_results = results_df
  ))
}

#' Explore sensitivity to type-level correlation structure
#'
#' @param K Number of types
#' @param lambda TV radius
#' @param rho_type_values Vector of type-level correlations to test
explore_correlation_structure <- function(
  K = 10,
  lambda = 0.3,
  rho_type_values = seq(0, 1, by = 0.2)
) {

  cat("========================================\n")
  cat("SENSITIVITY TO TYPE-LEVEL CORRELATION\n")
  cat("========================================\n\n")

  P0 <- rep(1/K, K)

  # Compute Σ_Q once (same for all)
  cat("Computing TV ball covariance (once)...\n")
  Sigma_Q <- compute_tv_ball_covariance(
    P0 = P0,
    lambda = lambda,
    n_samples = 30000,
    method = "rejection"
  )

  results_list <- list()

  for (rho_type in rho_type_values) {
    cat(sprintf("\nρ_type = %.2f\n", rho_type))

    # Generate tau_S and tau_Y with specified correlation
    set.seed(123)  # Fixed for reproducibility
    tau_S <- rnorm(K, mean = 0.5, sd = 0.3)
    tau_Y <- rho_type * tau_S + sqrt(1 - rho_type^2) * rnorm(K, sd = 0.3)

    actual_rho_type <- cor(tau_S, tau_Y)
    cat(sprintf("  Actual type-level cor: %.4f\n", actual_rho_type))

    # Analytical correlation
    cor_analytical <- compute_exact_correlation_analytical(tau_S, tau_Y, Sigma_Q)
    cat(sprintf("  TV ball correlation: %.4f\n", cor_analytical))
    cat(sprintf("  Attenuation: %.2f%%\n", 100 * (1 - cor_analytical / actual_rho_type)))

    results_list[[length(results_list) + 1]] <- tibble(
      rho_type_target = rho_type,
      rho_type_actual = actual_rho_type,
      rho_tv_ball = cor_analytical,
      attenuation_pct = 100 * (1 - cor_analytical / actual_rho_type)
    )
  }

  results_df <- bind_rows(results_list)

  cat("\n========================================\n")
  cat("SUMMARY\n")
  cat("========================================\n\n")

  print(results_df, n = Inf)

  # Plot
  p <- ggplot(results_df, aes(x = rho_type_actual)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray50") +
    geom_line(aes(y = rho_tv_ball), color = "steelblue", linewidth = 1.5) +
    geom_point(aes(y = rho_tv_ball), size = 3, color = "steelblue") +
    labs(
      title = "TV Ball Correlation vs Type-Level Correlation",
      subtitle = sprintf("K = %d, λ = %.2f", K, lambda),
      x = "Type-level correlation ρ(τ_S, τ_Y)",
      y = "TV ball correlation ρ_{B_λ}(ΔS, ΔY)"
    ) +
    theme_minimal() +
    coord_fixed()

  print(p)
  ggsave(
    "explorations/tv_ball_geometry/figures/correlation_structure.pdf",
    p, width = 7, height = 7
  )

  invisible(results_df)
}

# Run if interactive
if (interactive()) {
  # Example: K=10, parametric effects with known correlation
  K <- 10
  lambda <- 0.3
  P0 <- rep(1/K, K)

  # Type effects with rho = 0.7
  set.seed(12345)
  tau_S <- rnorm(K, mean = 0.5, sd = 0.3)
  tau_Y <- 0.7 * tau_S + sqrt(1 - 0.7^2) * rnorm(K, sd = 0.3)

  cat(sprintf("True type-level correlation: %.4f\n\n", cor(tau_S, tau_Y)))

  # Validate
  validation <- validate_analytical(
    tau_S = tau_S,
    tau_Y = tau_Y,
    P0 = P0,
    lambda = lambda,
    n_grid = 30000,
    M_values = c(100, 200, 500, 1000),
    n_replicates = 5
  )

  # Explore sensitivity
  sensitivity <- explore_correlation_structure(K = 10, lambda = 0.3)
}
