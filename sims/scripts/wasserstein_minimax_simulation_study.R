#!/usr/bin/env Rscript
# Comprehensive Simulation Study for Wasserstein Minimax IF-Based Inference
#
# This study evaluates:
# 1. Coverage at different sample sizes
# 2. Performance under different DGPs (linear, nonlinear, varying concordance)
# 3. Sensitivity to gamma (Wasserstein penalty) and tau (temperature)
# 4. Comparison to bootstrap inference
# 5. Power analysis

library(tidyverse)

# Source the package function
source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(2026)

# ==============================================================================
# DATA GENERATING PROCESSES
# ==============================================================================

#' DGP 1: Linear treatment effects (validated baseline)
generate_data_linear <- function(n, concordance_level = "moderate") {
  X <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)

  # Vary concordance by scaling tau_Y
  if (concordance_level == "low") {
    tau_S <- 0.3 + 0.2 * X
    tau_Y <- 0.1 + 0.05 * X  # Low concordance
  } else if (concordance_level == "moderate") {
    tau_S <- 0.3 + 0.2 * X
    tau_Y <- 0.4 + 0.3 * X   # Moderate concordance
  } else if (concordance_level == "high") {
    tau_S <- 0.3 + 0.2 * X
    tau_Y <- 0.6 + 0.4 * X   # High concordance
  }

  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)

  data.frame(X = X, A = A, S = S, Y = Y,
             tau_S_true = tau_S, tau_Y_true = tau_Y,
             dgp = paste0("linear_", concordance_level))
}

#' DGP 2: Nonlinear treatment effects
generate_data_nonlinear <- function(n) {
  X <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)

  # Quadratic effects
  tau_S <- 0.3 + 0.2 * X + 0.1 * X^2
  tau_Y <- 0.4 + 0.3 * X + 0.05 * X^2

  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)

  data.frame(X = X, A = A, S = S, Y = Y,
             tau_S_true = tau_S, tau_Y_true = tau_Y,
             dgp = "nonlinear")
}

#' DGP 3: Heterogeneous noise
generate_data_hetero_noise <- function(n) {
  X <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)

  tau_S <- 0.3 + 0.2 * X
  tau_Y <- 0.4 + 0.3 * X

  # Heteroskedastic errors
  noise_sd <- 0.3 + 0.2 * abs(X)
  S <- A * tau_S + rnorm(n, sd = noise_sd)
  Y <- A * tau_Y + rnorm(n, sd = noise_sd)

  data.frame(X = X, A = A, S = S, Y = Y,
             tau_S_true = tau_S, tau_Y_true = tau_Y,
             dgp = "hetero_noise")
}

#' DGP 4: Multiple covariates
generate_data_multivariate <- function(n) {
  X1 <- rnorm(n, mean = 0, sd = 1)
  X2 <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)

  tau_S <- 0.3 + 0.2 * X1 + 0.1 * X2
  tau_Y <- 0.4 + 0.3 * X1 + 0.15 * X2

  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)

  data.frame(X1 = X1, X2 = X2, A = A, S = S, Y = Y,
             tau_S_true = tau_S, tau_Y_true = tau_Y,
             dgp = "multivariate")
}

# ==============================================================================
# COMPUTE ORACLE TRUTH
# ==============================================================================

#' Compute true minimax concordance via large sample with oracle effects
compute_oracle_truth <- function(dgp_func, dgp_name, gamma, tau) {
  # Generate large sample
  if (dgp_name == "multivariate") {
    large_data <- dgp_func(10000)
    covariates <- c("X1", "X2")
  } else {
    large_data <- dgp_func(10000)
    covariates <- "X"
  }

  h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  X <- as.matrix(large_data[, covariates, drop = FALSE])
  n_large <- nrow(X)
  d <- ncol(X)  # Number of covariates for normalization

  # Compute Wasserstein dual with oracle h
  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- rowSums((X - matrix(X[j, ], nrow = n_large, ncol = ncol(X), byrow = TRUE))^2) / d
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# ==============================================================================
# SIMULATION FUNCTIONS
# ==============================================================================

#' Run single simulation replication
run_single_sim <- function(dgp_func, n, gamma, tau, covariates, truth) {
  # Generate data
  data <- dgp_func(n)

  # Estimate with IF-based inference
  result <- tryCatch({
    wasserstein_minimax_IF_inference(
      data = data,
      covariates = covariates,
      gamma = gamma,
      tau = tau,
      K = 5,
      alpha = 0.05
    )
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(result)) {
    return(data.frame(
      estimate = NA, se = NA, ci_lower = NA, ci_upper = NA,
      covered = NA, ci_width = NA, bias = NA
    ))
  }

  covered <- (truth >= result$ci_lower && truth <= result$ci_upper)

  data.frame(
    estimate = result$phi_star,
    se = result$se,
    ci_lower = result$ci_lower,
    ci_upper = result$ci_upper,
    covered = covered,
    ci_width = result$ci_upper - result$ci_lower,
    bias = result$phi_star - truth,
    concordance_p0 = result$concordance_p0
  )
}

#' Study 1: Coverage at different sample sizes
study_coverage_by_n <- function(n_sims = 500) {
  cat("\n========================================\n")
  cat("STUDY 1: Coverage by Sample Size\n")
  cat("========================================\n\n")

  sample_sizes <- c(200, 300, 500, 750, 1000)
  gamma <- 0.5
  tau <- 0.1

  # Compute truth
  truth <- compute_oracle_truth(
    function(n) generate_data_linear(n, "moderate"),
    "linear_moderate", gamma, tau
  )
  cat(sprintf("Oracle truth: %.6f\n\n", truth))

  results <- map_df(sample_sizes, function(n) {
    cat(sprintf("n = %d ... ", n))
    start_time <- Sys.time()

    sim_results <- replicate(n_sims, {
      run_single_sim(
        function(n) generate_data_linear(n, "moderate"),
        n, gamma, tau, "X", truth
      )
    }, simplify = FALSE)

    sim_df <- bind_rows(sim_results)

    # Remove NAs
    sim_df <- sim_df[complete.cases(sim_df), ]
    n_valid <- nrow(sim_df)

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    cat(sprintf("done (%.1f sec, %d/%d valid)\n", elapsed, n_valid, n_sims))

    data.frame(
      n = n,
      coverage = mean(sim_df$covered),
      mean_estimate = mean(sim_df$estimate),
      bias = mean(sim_df$bias),
      empirical_se = sd(sim_df$estimate),
      mean_IF_se = mean(sim_df$se),
      variance_ratio = mean(sim_df$se) / sd(sim_df$estimate),
      mean_ci_width = mean(sim_df$ci_width),
      n_valid = n_valid
    )
  })

  cat("\nResults:\n")
  print(results, digits = 4)

  results
}

#' Study 2: Performance across different DGPs
study_dgp_comparison <- function(n_sims = 500, n = 500) {
  cat("\n========================================\n")
  cat("STUDY 2: Performance Across DGPs\n")
  cat("========================================\n\n")

  gamma <- 0.5
  tau <- 0.1

  dgps <- list(
    linear_low = list(
      func = function(n) generate_data_linear(n, "low"),
      covariates = "X",
      name = "linear_low"
    ),
    linear_moderate = list(
      func = function(n) generate_data_linear(n, "moderate"),
      covariates = "X",
      name = "linear_moderate"
    ),
    linear_high = list(
      func = function(n) generate_data_linear(n, "high"),
      covariates = "X",
      name = "linear_high"
    ),
    nonlinear = list(
      func = generate_data_nonlinear,
      covariates = "X",
      name = "nonlinear"
    ),
    hetero_noise = list(
      func = generate_data_hetero_noise,
      covariates = "X",
      name = "hetero_noise"
    ),
    multivariate = list(
      func = generate_data_multivariate,
      covariates = c("X1", "X2"),
      name = "multivariate"
    )
  )

  results <- map_df(names(dgps), function(dgp_name) {
    dgp <- dgps[[dgp_name]]

    cat(sprintf("DGP: %s ... ", dgp_name))
    start_time <- Sys.time()

    # Compute truth
    truth <- compute_oracle_truth(dgp$func, dgp$name, gamma, tau)

    # Run simulations
    sim_results <- replicate(n_sims, {
      run_single_sim(dgp$func, n, gamma, tau, dgp$covariates, truth)
    }, simplify = FALSE)

    sim_df <- bind_rows(sim_results)
    sim_df <- sim_df[complete.cases(sim_df), ]
    n_valid <- nrow(sim_df)

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    cat(sprintf("done (%.1f sec, %d/%d valid)\n", elapsed, n_valid, n_sims))

    data.frame(
      dgp = dgp_name,
      truth = truth,
      coverage = mean(sim_df$covered),
      mean_estimate = mean(sim_df$estimate),
      bias = mean(sim_df$bias),
      rel_bias = mean(sim_df$bias) / truth,
      empirical_se = sd(sim_df$estimate),
      mean_IF_se = mean(sim_df$se),
      variance_ratio = mean(sim_df$se) / sd(sim_df$estimate),
      mean_concordance_p0 = mean(sim_df$concordance_p0),
      n_valid = n_valid
    )
  })

  cat("\nResults:\n")
  print(results, digits = 4)

  results
}

#' Study 3: Sensitivity to gamma (Wasserstein penalty)
study_gamma_sensitivity <- function(n_sims = 500, n = 500) {
  cat("\n========================================\n")
  cat("STUDY 3: Sensitivity to Gamma\n")
  cat("========================================\n\n")

  gamma_values <- c(0.1, 0.25, 0.5, 0.75, 1.0, 1.5)
  tau <- 0.1

  results <- map_df(gamma_values, function(gamma) {
    cat(sprintf("gamma = %.2f ... ", gamma))
    start_time <- Sys.time()

    # Compute truth for this gamma
    truth <- compute_oracle_truth(
      function(n) generate_data_linear(n, "moderate"),
      "linear_moderate", gamma, tau
    )

    # Run simulations
    sim_results <- replicate(n_sims, {
      run_single_sim(
        function(n) generate_data_linear(n, "moderate"),
        n, gamma, tau, "X", truth
      )
    }, simplify = FALSE)

    sim_df <- bind_rows(sim_results)
    sim_df <- sim_df[complete.cases(sim_df), ]
    n_valid <- nrow(sim_df)

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    cat(sprintf("done (%.1f sec, %d/%d valid)\n", elapsed, n_valid, n_sims))

    data.frame(
      gamma = gamma,
      truth = truth,
      coverage = mean(sim_df$covered),
      mean_estimate = mean(sim_df$estimate),
      bias = mean(sim_df$bias),
      empirical_se = sd(sim_df$estimate),
      mean_IF_se = mean(sim_df$se),
      variance_ratio = mean(sim_df$se) / sd(sim_df$estimate),
      mean_concordance_p0 = mean(sim_df$concordance_p0),
      n_valid = n_valid
    )
  })

  cat("\nResults:\n")
  print(results, digits = 4)

  results
}

#' Study 4: Sensitivity to tau (temperature)
study_tau_sensitivity <- function(n_sims = 500, n = 500) {
  cat("\n========================================\n")
  cat("STUDY 4: Sensitivity to Tau\n")
  cat("========================================\n\n")

  tau_values <- c(0.05, 0.1, 0.15, 0.2, 0.3, 0.5)
  gamma <- 0.5

  results <- map_df(tau_values, function(tau) {
    cat(sprintf("tau = %.2f ... ", tau))
    start_time <- Sys.time()

    # Compute truth for this tau
    truth <- compute_oracle_truth(
      function(n) generate_data_linear(n, "moderate"),
      "linear_moderate", gamma, tau
    )

    # Run simulations
    sim_results <- replicate(n_sims, {
      run_single_sim(
        function(n) generate_data_linear(n, "moderate"),
        n, gamma, tau, "X", truth
      )
    }, simplify = FALSE)

    sim_df <- bind_rows(sim_results)
    sim_df <- sim_df[complete.cases(sim_df), ]
    n_valid <- nrow(sim_df)

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    cat(sprintf("done (%.1f sec, %d/%d valid)\n", elapsed, n_valid, n_sims))

    data.frame(
      tau = tau,
      truth = truth,
      coverage = mean(sim_df$covered),
      mean_estimate = mean(sim_df$estimate),
      bias = mean(sim_df$bias),
      empirical_se = sd(sim_df$estimate),
      mean_IF_se = mean(sim_df$se),
      variance_ratio = mean(sim_df$se) / sd(sim_df$estimate),
      n_valid = n_valid
    )
  })

  cat("\nResults:\n")
  print(results, digits = 4)

  results
}

# ==============================================================================
# MAIN
# ==============================================================================

main <- function() {
  cat("========================================\n")
  cat("WASSERSTEIN MINIMAX SIMULATION STUDY\n")
  cat("========================================\n")
  cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat("========================================\n")

  # Run all studies
  study1 <- study_coverage_by_n(n_sims = 500)
  study2 <- study_dgp_comparison(n_sims = 500, n = 500)
  study3 <- study_gamma_sensitivity(n_sims = 500, n = 500)
  study4 <- study_tau_sensitivity(n_sims = 500, n = 500)

  # Combine results
  results <- list(
    coverage_by_n = study1,
    dgp_comparison = study2,
    gamma_sensitivity = study3,
    tau_sensitivity = study4
  )

  # Save results
  saveRDS(results, "sims/results/wasserstein_minimax_simulation_study.rds")

  cat("\n========================================\n")
  cat("SIMULATION STUDY COMPLETE\n")
  cat("========================================\n")
  cat("Results saved to: sims/results/wasserstein_minimax_simulation_study.rds\n")

  results
}

if (sys.nframe() == 0) {
  results <- main()
}
