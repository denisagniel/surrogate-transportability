#!/usr/bin/env Rscript
# Test methods with genuinely nonlinear DGP
# Compare: Linear, GAM, RF on truly nonlinear treatment effects

library(mgcv)
library(randomForest)

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(2026)

cat("========================================\n")
cat("NONLINEAR DGP TEST\n")
cat("========================================\n\n")

# Generate data with GENUINELY NONLINEAR treatment effects
generate_nonlinear_data <- function(n, d) {
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  colnames(X) <- paste0("X", 1:d)

  A <- rbinom(n, 1, 0.5)

  # NONLINEAR treatment effects with:
  # - Interactions
  # - Thresholds
  # - Non-additive terms

  if (d >= 2) {
    # Interaction effects
    tau_S <- 0.3 + 0.4 * X[,1] * X[,2] +
             0.2 * (X[,1]^2 - 1) +
             0.15 * ifelse(X[,1] > 0, X[,2], -X[,2])  # Threshold

    tau_Y <- 0.5 + 0.5 * X[,1] * X[,2] +
             0.3 * (X[,1]^2 - 1) +
             0.2 * ifelse(X[,1] > 0, X[,2], -X[,2])

    # Add more covariates if d > 2
    if (d > 2) {
      for (j in 3:d) {
        weight <- 0.1 / j
        tau_S <- tau_S + weight * X[,j] * X[,1]  # Interaction with X1
        tau_Y <- tau_Y + 1.5 * weight * X[,j] * X[,1]
      }
    }
  } else {
    # For d=1, just quadratic + threshold
    tau_S <- 0.3 + 0.3 * (X[,1]^2 - 1) + 0.2 * abs(X[,1])
    tau_Y <- 0.5 + 0.4 * (X[,1]^2 - 1) + 0.3 * abs(X[,1])
  }

  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)

  data <- data.frame(X, A = A, S = S, Y = Y)

  list(data = data, tau_S_true = tau_S, tau_Y_true = tau_Y)
}

# Compute oracle truth
compute_truth <- function(d, gamma = 0.5, tau = 0.1) {
  n_large <- 10000
  dgp <- generate_nonlinear_data(n_large, d)
  X <- as.matrix(dgp$data[, paste0("X", 1:d), drop = FALSE])

  tau_S_true <- dgp$tau_S_true
  tau_Y_true <- dgp$tau_Y_true
  h_oracle <- tau_S_true * tau_Y_true

  phi_j <- numeric(n_large)
  for (j in 1:n_large) {
    costs <- rowSums((X - matrix(X[j, ], nrow = n_large, ncol = d, byrow = TRUE))^2) / d
    values <- exp(-(h_oracle + gamma * costs) / tau)
    m_j <- mean(values)
    phi_j[j] <- -tau * log(m_j)
  }

  mean(phi_j)
}

# LINEAR nuisances (will be misspecified)
estimate_nuisances_linear <- function(train_data, test_data, covariates) {
  formula_S <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_Y <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))

  fit_S1 <- lm(formula_S, data = train_data[train_data$A == 1, ])
  fit_S0 <- lm(formula_S, data = train_data[train_data$A == 0, ])
  fit_Y1 <- lm(formula_Y, data = train_data[train_data$A == 1, ])
  fit_Y0 <- lm(formula_Y, data = train_data[train_data$A == 0, ])

  mu_S1_hat <- predict(fit_S1, newdata = test_data)
  mu_S0_hat <- predict(fit_S0, newdata = test_data)
  mu_Y1_hat <- predict(fit_Y1, newdata = test_data)
  mu_Y0_hat <- predict(fit_Y0, newdata = test_data)

  tau_S_hat <- mu_S1_hat - mu_S0_hat
  tau_Y_hat <- mu_Y1_hat - mu_Y0_hat

  list(
    tau_S_hat = tau_S_hat,
    tau_Y_hat = tau_Y_hat,
    h_hat = tau_S_hat * tau_Y_hat,
    mu_S1_hat = mu_S1_hat,
    mu_S0_hat = mu_S0_hat,
    mu_Y1_hat = mu_Y1_hat,
    mu_Y0_hat = mu_Y0_hat
  )
}

# GAM nuisances (should capture nonlinearity)
estimate_nuisances_gam <- function(train_data, test_data, covariates) {
  smooth_terms <- paste0("s(", covariates, ")")
  formula_S <- as.formula(paste("S ~", paste(smooth_terms, collapse = " + "), "+ A"))
  formula_Y <- as.formula(paste("Y ~", paste(smooth_terms, collapse = " + "), "+ A"))

  fit_S <- gam(formula_S, data = train_data)
  fit_Y <- gam(formula_Y, data = train_data)

  test_A1 <- test_data
  test_A1$A <- 1
  test_A0 <- test_data
  test_A0$A <- 0

  mu_S1_hat <- predict(fit_S, newdata = test_A1)
  mu_S0_hat <- predict(fit_S, newdata = test_A0)
  mu_Y1_hat <- predict(fit_Y, newdata = test_A1)
  mu_Y0_hat <- predict(fit_Y, newdata = test_A0)

  tau_S_hat <- mu_S1_hat - mu_S0_hat
  tau_Y_hat <- mu_Y1_hat - mu_Y0_hat

  list(
    tau_S_hat = tau_S_hat,
    tau_Y_hat = tau_Y_hat,
    h_hat = tau_S_hat * tau_Y_hat,
    mu_S1_hat = mu_S1_hat,
    mu_S0_hat = mu_S0_hat,
    mu_Y1_hat = mu_Y1_hat,
    mu_Y0_hat = mu_Y0_hat
  )
}

# RF nuisances (tuned)
estimate_nuisances_rf_tuned <- function(train_data, test_data, covariates) {
  train_A1 <- train_data[train_data$A == 1, ]
  train_A0 <- train_data[train_data$A == 0, ]

  formula_S <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_Y <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))

  fit_S1 <- randomForest(formula_S, data = train_A1, ntree = 500, nodesize = 20)
  fit_S0 <- randomForest(formula_S, data = train_A0, ntree = 500, nodesize = 20)
  fit_Y1 <- randomForest(formula_Y, data = train_A1, ntree = 500, nodesize = 20)
  fit_Y0 <- randomForest(formula_Y, data = train_A0, ntree = 500, nodesize = 20)

  mu_S1_hat <- predict(fit_S1, newdata = test_data)
  mu_S0_hat <- predict(fit_S0, newdata = test_data)
  mu_Y1_hat <- predict(fit_Y1, newdata = test_data)
  mu_Y0_hat <- predict(fit_Y0, newdata = test_data)

  tau_S_hat <- mu_S1_hat - mu_S0_hat
  tau_Y_hat <- mu_Y1_hat - mu_Y0_hat

  list(
    tau_S_hat = tau_S_hat,
    tau_Y_hat = tau_Y_hat,
    h_hat = tau_S_hat * tau_Y_hat,
    mu_S1_hat = mu_S1_hat,
    mu_S0_hat = mu_S0_hat,
    mu_Y1_hat = mu_Y1_hat,
    mu_Y0_hat = mu_Y0_hat
  )
}

# Inference wrapper
wasserstein_test <- function(data, covariates, method,
                              gamma = 0.5, tau = 0.1, K = 5) {
  n <- nrow(data)
  fold_ids <- sample(rep(1:K, length.out = n))

  all_phi <- numeric(K)
  all_IF <- numeric(n)

  for (k in 1:K) {
    test_idx <- which(fold_ids == k)
    train_idx <- which(fold_ids != k)

    train_data <- data[train_idx, ]
    test_data <- data[test_idx, ]

    # Estimate nuisances
    if (method == "linear") {
      nuisances <- estimate_nuisances_linear(train_data, test_data, covariates)
    } else if (method == "gam") {
      nuisances <- estimate_nuisances_gam(train_data, test_data, covariates)
    } else if (method == "rf") {
      nuisances <- estimate_nuisances_rf_tuned(train_data, test_data, covariates)
    }

    # Estimate dual
    phi_k <- estimate_dual_fold_wasserstein(
      test_data, nuisances$h_hat, covariates, gamma, tau
    )
    all_phi[k] <- phi_k

    # Compute IF
    IF_k <- compute_IF_fold_wasserstein(
      test_data, nuisances, covariates, gamma, tau
    )
    IF_k <- IF_k - mean(IF_k)
    all_IF[test_idx] <- IF_k
  }

  phi_star <- mean(all_phi)
  sigma_sq <- mean(all_IF^2)
  se <- sqrt(sigma_sq / n)

  z_crit <- qnorm(0.975)
  ci_lower <- phi_star - z_crit * se
  ci_upper <- phi_star + z_crit * se

  list(
    phi_star = phi_star,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper
  )
}

# Test configuration
test_config <- function(d, n, method, n_sims = 50) {
  # Get truth
  truth <- compute_truth(d)

  # Run simulations
  results <- replicate(n_sims, {
    dgp <- generate_nonlinear_data(n, d)
    data <- dgp$data
    covariates <- paste0("X", 1:d)

    result <- tryCatch({
      wasserstein_test(
        data = data,
        covariates = covariates,
        method = method,
        gamma = 0.5,
        tau = 0.1,
        K = 5
      )
    }, error = function(e) NULL)

    if (is.null(result)) return(c(est=NA, se=NA, lower=NA, upper=NA))

    c(est = result$phi_star,
      se = result$se,
      lower = result$ci_lower,
      upper = result$ci_upper)
  }, simplify = FALSE)

  results_df <- do.call(rbind, results)
  results_df <- results_df[complete.cases(results_df), ]

  n_valid <- nrow(results_df)
  coverage <- mean(results_df[, "lower"] <= truth & results_df[, "upper"] >= truth)
  mean_est <- mean(results_df[, "est"])
  bias <- mean_est - truth
  rel_bias <- bias / truth * 100
  empirical_se <- sd(results_df[, "est"])
  mean_IF_se <- mean(results_df[, "se"])
  variance_ratio <- mean_IF_se / empirical_se

  data.frame(
    d = d,
    n = n,
    method = method,
    n_valid = n_valid,
    truth = truth,
    coverage = coverage,
    bias = bias,
    rel_bias = rel_bias,
    empirical_se = empirical_se,
    mean_IF_se = mean_IF_se,
    variance_ratio = variance_ratio
  )
}

# Test grid
cat("Testing nonlinear DGP...\n")
cat("Dimensions: d=3,4\n")
cat("Sample size: n=1000\n")
cat("Methods: linear (misspecified), gam, rf\n\n")

cat("DGP includes:\n")
cat("  - Interactions: X1 * X2\n")
cat("  - Thresholds: I(X1 > 0)\n")
cat("  - Quadratic terms: X1^2\n")
cat("  - Non-additive effects\n\n")

configs <- expand.grid(
  d = c(3, 4),
  n = c(1000),
  method = c("linear", "gam", "rf"),
  stringsAsFactors = FALSE
)

results_list <- list()
for (i in 1:nrow(configs)) {
  d <- configs$d[i]
  n <- configs$n[i]
  method <- configs$method[i]

  cat(sprintf("d=%d, n=%d, %s ... ", d, n, method))
  start_time <- Sys.time()

  result <- test_config(d, n, method, n_sims = 50)
  results_list[[i]] <- result

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("done (%.1f sec, coverage: %.1f%%)\n",
              elapsed, result$coverage * 100))
}

results_all <- do.call(rbind, results_list)

cat("\n========================================\n")
cat("RESULTS - NONLINEAR DGP\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("COMPARISON BY DIMENSION\n")
cat("========================================\n\n")

for (d in unique(results_all$d)) {
  cat(sprintf("\nDimension d=%d:\n", d))
  subset_d <- results_all[results_all$d == d, ]

  for (j in 1:nrow(subset_d)) {
    row <- subset_d[j, ]
    status <- if (row$coverage >= 0.88 && row$coverage <= 0.98) "✓" else "⚠"
    cat(sprintf("  %s %-8s: %.1f%% coverage (bias: %+.2f%%, var_ratio: %.2f)\n",
                status, row$method, row$coverage * 100, row$rel_bias, row$variance_ratio))
  }

  # Find best method
  best_idx <- which.max(subset_d$coverage)
  best <- subset_d[best_idx, ]
  cat(sprintf("\n  Best method: %s (%.1f%% coverage)\n", best$method, best$coverage * 100))
}

cat("\n========================================\n")
cat("KEY FINDINGS\n")
cat("========================================\n\n")

# Compare to linear DGP baseline
cat("Previous results with linear DGP (d=4, n=1000):\n")
cat("  Linear: 98% coverage\n")
cat("  GAM:    90% coverage\n")
cat("  RF:     34% coverage\n\n")

cat("Current results with nonlinear DGP:\n")
for (d in unique(results_all$d)) {
  cat(sprintf("\nd=%d:\n", d))
  subset_d <- results_all[results_all$d == d, ]
  for (j in 1:nrow(subset_d)) {
    row <- subset_d[j, ]
    cat(sprintf("  %-8s: %.1f%% coverage\n", row$method, row$coverage * 100))
  }
}

cat("\nConclusion:\n")
linear_worst <- min(results_all[results_all$method == "linear", "coverage"])
flexible_best <- max(results_all[results_all$method != "linear", "coverage"])

if (flexible_best > linear_worst + 0.05) {
  cat("  ✓ Flexible methods (GAM/RF) perform better with nonlinear DGP\n")
} else if (abs(flexible_best - linear_worst) <= 0.05) {
  cat("  ≈ Methods perform similarly regardless of nonlinearity\n")
} else {
  cat("  ✗ Linear still performs best even with misspecification\n")
}

# Save results
saveRDS(results_all, "nonlinear_dgp_results.rds")
cat("\nResults saved to: nonlinear_dgp_results.rds\n")
