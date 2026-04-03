#!/usr/bin/env Rscript
# Test different scalings for the nuisance term to find the correct formula

library(tidyverse)

# ==============================================================================
# DGP (same as test_nested_crossfit_linear.R)
# ==============================================================================

generate_data <- function(n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  X <- rnorm(n, mean = 0, sd = 1)
  A <- rbinom(n, 1, 0.5)

  tau_S_true <- 0.3 + 0.2 * X
  tau_Y_true <- 0.4 + 0.3 * X

  S <- A * tau_S_true + rnorm(n, sd = 0.5)
  Y <- A * tau_Y_true + rnorm(n, sd = 0.5)

  data.frame(X = X, A = A, S = S, Y = Y,
             tau_S_true = tau_S_true, tau_Y_true = tau_Y_true)
}

# ==============================================================================
# Nuisance Estimation
# ==============================================================================

estimate_nuisances_linear <- function(train_data) {
  fit_S1 <- lm(S ~ X, data = train_data[train_data$A == 1, ])
  fit_S0 <- lm(S ~ X, data = train_data[train_data$A == 0, ])
  fit_Y1 <- lm(Y ~ X, data = train_data[train_data$A == 1, ])
  fit_Y0 <- lm(Y ~ X, data = train_data[train_data$A == 0, ])

  list(fit_S1 = fit_S1, fit_S0 = fit_S0,
       fit_Y1 = fit_Y1, fit_Y0 = fit_Y0)
}

predict_nuisances <- function(fits, test_data) {
  mu_S1_hat <- predict(fits$fit_S1, newdata = test_data)
  mu_S0_hat <- predict(fits$fit_S0, newdata = test_data)
  mu_Y1_hat <- predict(fits$fit_Y1, newdata = test_data)
  mu_Y0_hat <- predict(fits$fit_Y0, newdata = test_data)

  tau_S_hat <- mu_S1_hat - mu_S0_hat
  tau_Y_hat <- mu_Y1_hat - mu_Y0_hat
  h_hat <- tau_S_hat * tau_Y_hat

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat, h_hat = h_hat,
       mu_S1_hat = mu_S1_hat, mu_S0_hat = mu_S0_hat,
       mu_Y1_hat = mu_Y1_hat, mu_Y0_hat = mu_Y0_hat)
}

# ==============================================================================
# Estimator
# ==============================================================================

estimate_dual_on_fold <- function(test_data, h_hat, gamma = 0.5, tau = 0.1) {
  X <- test_data$X
  n <- length(X)

  phi_j <- numeric(n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h_hat + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# ==============================================================================
# IF Computation with DIFFERENT SCALINGS
# ==============================================================================

compute_IF_tau <- function(obs, outcome, mu1_hat, mu0_hat) {
  A <- obs$A
  Y <- obs[[outcome]]
  e <- 0.5

  IF_val <- A * (Y - mu1_hat) / e - (1 - A) * (Y - mu0_hat) / (1 - e)
  return(IF_val)
}

compute_IF_with_scaling <- function(test_data, h_hat, nuisances,
                                    gamma = 0.5, tau = 0.1,
                                    scaling = "1/n") {
  X <- test_data$X
  n <- length(X)

  # Compute m(X_j) for all j
  m_vals <- numeric(n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h_hat + gamma * costs) / tau)
    m_vals[j] <- mean(values)
  }

  psi_hat <- mean(-tau * log(m_vals))

  # Compute softmax weights
  W <- matrix(0, n, n)
  for (j in 1:n) {
    costs <- (X - X[j])^2
    values <- exp(-(h_hat + gamma * costs) / tau)
    W[, j] <- values / sum(values)
  }

  # IF for each observation
  IF_vals <- numeric(n)

  for (k in 1:n) {
    obs <- test_data[k, ]

    # TERM 1 (OUTER)
    term1 <- -tau * log(m_vals[k]) - psi_hat

    # TERM 2 (INNER)
    inner_contrib <- numeric(n)
    for (j in 1:n) {
      cost_kj <- (X[k] - X[j])^2
      g_kj <- exp(-(h_hat[k] + gamma * cost_kj) / tau)
      inner_contrib[j] <- -tau * g_kj / m_vals[j]
    }
    term2 <- mean(inner_contrib) + tau

    # TERM 3 (NUISANCE) - DIFFERENT SCALINGS
    IF_tau_S_k <- compute_IF_tau(obs, "S", nuisances$mu_S1_hat[k], nuisances$mu_S0_hat[k])
    IF_tau_Y_k <- compute_IF_tau(obs, "Y", nuisances$mu_Y1_hat[k], nuisances$mu_Y0_hat[k])
    IF_h_k <- nuisances$tau_S_hat[k] * IF_tau_Y_k + nuisances$tau_Y_hat[k] * IF_tau_S_k

    if (scaling == "1/n") {
      # Current formula
      term3 <- (1/n) * sum(W[k, ]) * IF_h_k
    } else if (scaling == "1/n^2") {
      # Derived formula
      term3 <- (1/n^2) * sum(W[k, ]) * IF_h_k
    } else if (scaling == "none") {
      # No extra scaling
      term3 <- sum(W[k, ]) * IF_h_k
    } else if (scaling == "mean") {
      # Mean of weights
      term3 <- mean(W[k, ]) * IF_h_k
    }

    IF_vals[k] <- term1 + term2 + term3
  }

  # Center within fold
  IF_vals <- IF_vals - mean(IF_vals)

  return(IF_vals)
}

# ==============================================================================
# Cross-Fitting with Different Scalings
# ==============================================================================

estimate_with_crossfit <- function(data, gamma = 0.5, tau = 0.1, K = 5, scaling = "1/n") {
  n <- nrow(data)

  fold_ids <- sample(rep(1:K, length.out = n))

  all_phi <- numeric(K)
  all_IF <- numeric(n)

  for (k in 1:K) {
    test_idx <- which(fold_ids == k)
    train_idx <- which(fold_ids != k)

    train_data <- data[train_idx, ]
    test_data <- data[test_idx, ]

    fits <- estimate_nuisances_linear(train_data)
    nuisances <- predict_nuisances(fits, test_data)

    phi_k <- estimate_dual_on_fold(test_data, nuisances$h_hat, gamma, tau)
    all_phi[k] <- phi_k

    IF_k <- compute_IF_with_scaling(test_data, nuisances$h_hat, nuisances,
                                     gamma, tau, scaling)

    all_IF[test_idx] <- IF_k
  }

  phi_star <- mean(all_phi)
  sigma_sq <- mean(all_IF^2)
  se <- sqrt(sigma_sq / n)

  list(phi_star = phi_star, se = se, IF_vals = all_IF)
}

# ==============================================================================
# Test Coverage for Each Scaling
# ==============================================================================

test_scaling <- function(scaling_name, n_sims = 100, n = 500, gamma = 0.5, tau = 0.1) {
  # True value
  set.seed(999)
  large_data <- generate_data(10000)
  h_oracle <- large_data$tau_S_true * large_data$tau_Y_true
  X <- large_data$X
  n_large <- length(X)

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- (X - X[j])^2
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }
  phi_true <- mean(phi_j)

  # Simulations
  results <- replicate(n_sims, {
    data <- generate_data(n, seed = NULL)
    result <- estimate_with_crossfit(data, gamma, tau, K = 5, scaling = scaling_name)

    z_crit <- qnorm(0.975)
    ci_lower <- result$phi_star - z_crit * result$se
    ci_upper <- result$phi_star + z_crit * result$se
    covered <- (phi_true >= ci_lower && phi_true <= ci_upper)

    list(estimate = result$phi_star, se = result$se, covered = covered)
  }, simplify = FALSE)

  estimates <- sapply(results, function(x) x$estimate)
  ses <- sapply(results, function(x) x$se)
  covered <- sapply(results, function(x) x$covered)

  coverage_rate <- mean(covered)
  mean_estimate <- mean(estimates)
  empirical_se <- sd(estimates)
  mean_IF_se <- mean(ses)
  variance_ratio <- mean_IF_se / empirical_se

  list(
    scaling = scaling_name,
    coverage = coverage_rate,
    bias = mean_estimate - phi_true,
    variance_ratio = variance_ratio,
    mean_IF_se = mean_IF_se,
    empirical_se = empirical_se
  )
}

# ==============================================================================
# Main: Test All Scalings
# ==============================================================================

main <- function() {
  cat(strrep("=", 70), "\n")
  cat("TESTING DIFFERENT NUISANCE TERM SCALINGS\n")
  cat(strrep("=", 70), "\n\n")

  scalings <- c("1/n", "1/n^2", "none", "mean")

  results <- map_df(scalings, function(s) {
    cat("Testing scaling:", s, "...\n")
    as.data.frame(test_scaling(s, n_sims = 100, n = 500))
  })

  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("RESULTS\n")
  cat(strrep("=", 70), "\n\n")

  print(results, digits = 4)

  cat("\n")
  cat("Interpretation:\n")
  cat("- Coverage should be ~95%\n")
  cat("- Variance ratio should be ~1.0\n")
  cat("- Bias should be near 0\n\n")

  cat("Current formula uses: 1/n\n")
  cat("Derived formula suggests: 1/n^2\n\n")

  results
}

if (sys.nframe() == 0) {
  results <- main()
  saveRDS(results, "nuisance_scaling_test_results.rds")
  cat("Results saved to: nuisance_scaling_test_results.rds\n")
}
