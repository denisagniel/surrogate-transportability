#!/usr/bin/env Rscript
# Test high-dimensional coverage with flexible nuisance learners
# Compare: Linear, GAM, Random Forest
# Dimensions: d=3,4,5
# Sample sizes: n=500, 1000, 2000

library(mgcv)       # For GAM
library(randomForest)  # For RF

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(2026)

cat("========================================\n")
cat("FLEXIBLE NUISANCES - HIGH DIMENSIONS\n")
cat("========================================\n\n")

# Generate data with d covariates
generate_data <- function(n, d) {
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  colnames(X) <- paste0("X", 1:d)

  A <- rbinom(n, 1, 0.5)

  # Nonlinear treatment effects with diminishing weights
  weights <- 0.2 / (2^(0:(d-1)))

  # Add some nonlinearity
  tau_S <- 0.3 + as.vector(X %*% weights) + 0.05 * X[,1]^2
  tau_Y <- 0.4 + as.vector(X %*% (1.5 * weights)) + 0.08 * X[,1]^2

  S <- A * tau_S + rnorm(n, sd = 0.5)
  Y <- A * tau_Y + rnorm(n, sd = 0.5)

  data <- data.frame(X, A = A, S = S, Y = Y)

  list(data = data, weights_S = weights, weights_Y = 1.5 * weights)
}

# Compute oracle truth
compute_truth <- function(d, weights_S, weights_Y, gamma = 0.5, tau = 0.1) {
  n_large <- 10000
  X <- matrix(rnorm(n_large * d), nrow = n_large, ncol = d)

  tau_S_true <- 0.3 + as.vector(X %*% weights_S) + 0.05 * X[,1]^2
  tau_Y_true <- 0.4 + as.vector(X %*% weights_Y) + 0.08 * X[,1]^2
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

# Modified inference with flexible models
wasserstein_with_flexible_nuisances <- function(data, covariates, method = "linear",
                                                 gamma = 0.5, tau = 0.1, K = 5) {
  n <- nrow(data)
  fold_ids <- sample(rep(1:K, length.out = n))

  all_phi <- numeric(K)
  all_IF <- numeric(n)
  tau_s_hat_all <- numeric(n)
  tau_y_hat_all <- numeric(n)

  for (k in 1:K) {
    test_idx <- which(fold_ids == k)
    train_idx <- which(fold_ids != k)

    train_data <- data[train_idx, ]
    test_data <- data[test_idx, ]

    # Estimate nuisances based on method
    if (method == "linear") {
      nuisances <- estimate_nuisances_linear(train_data, test_data, covariates)
    } else if (method == "gam") {
      nuisances <- estimate_nuisances_gam(train_data, test_data, covariates)
    } else if (method == "rf") {
      nuisances <- estimate_nuisances_rf(train_data, test_data, covariates)
    }

    tau_s_hat_all[test_idx] <- nuisances$tau_S_hat
    tau_y_hat_all[test_idx] <- nuisances$tau_Y_hat

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

# Linear nuisances (existing)
estimate_nuisances_linear <- function(train_data, test_data, covariates) {
  formula_S1 <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_S0 <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_Y1 <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))
  formula_Y0 <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))

  fit_S1 <- lm(formula_S1, data = train_data[train_data$A == 1, ])
  fit_S0 <- lm(formula_S0, data = train_data[train_data$A == 0, ])
  fit_Y1 <- lm(formula_Y1, data = train_data[train_data$A == 1, ])
  fit_Y0 <- lm(formula_Y0, data = train_data[train_data$A == 0, ])

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

# GAM nuisances
estimate_nuisances_gam <- function(train_data, test_data, covariates) {
  # Build GAM formula with smooth terms
  smooth_terms <- paste0("s(", covariates, ")")
  formula_S <- as.formula(paste("S ~", paste(smooth_terms, collapse = " + "), "+ A"))
  formula_Y <- as.formula(paste("Y ~", paste(smooth_terms, collapse = " + "), "+ A"))

  # Fit GAMs
  fit_S <- gam(formula_S, data = train_data)
  fit_Y <- gam(formula_Y, data = train_data)

  # Predict at A=1 and A=0
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

# Random Forest nuisances
estimate_nuisances_rf <- function(train_data, test_data, covariates) {
  # Fit separate RFs for A=1 and A=0
  train_A1 <- train_data[train_data$A == 1, ]
  train_A0 <- train_data[train_data$A == 0, ]

  # Build formulas
  formula_S <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_Y <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))

  # Fit RFs (suppress output)
  fit_S1 <- randomForest(formula_S, data = train_A1, ntree = 100)
  fit_S0 <- randomForest(formula_S, data = train_A0, ntree = 100)
  fit_Y1 <- randomForest(formula_Y, data = train_A1, ntree = 100)
  fit_Y0 <- randomForest(formula_Y, data = train_A0, ntree = 100)

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

# Test configuration
test_config <- function(d, n, method, n_sims = 50) {
  # Get truth
  template <- generate_data(100, d)
  truth <- compute_truth(d, template$weights_S, template$weights_Y)

  # Run simulations
  results <- replicate(n_sims, {
    dgp <- generate_data(n, d)
    data <- dgp$data
    covariates <- paste0("X", 1:d)

    result <- tryCatch({
      wasserstein_with_flexible_nuisances(
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
cat("Testing configurations...\n")
cat("Dimensions: d=3,4,5\n")
cat("Sample sizes: n=500,1000,2000\n")
cat("Methods: linear, gam, rf\n\n")

configs <- expand.grid(
  d = c(3, 4, 5),
  n = c(500, 1000, 2000),
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
cat("COMPLETE RESULTS\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("COVERAGE BY METHOD AND DIMENSION (n=1000)\n")
cat("========================================\n\n")

results_n1000 <- results_all[results_all$n == 1000, ]
results_n1000 <- results_n1000[order(results_n1000$d, results_n1000$method), ]

for (d in unique(results_n1000$d)) {
  cat(sprintf("\nDimension d=%d (n=1000):\n", d))
  subset_d <- results_n1000[results_n1000$d == d, ]

  for (j in 1:nrow(subset_d)) {
    row <- subset_d[j, ]
    status <- if (row$coverage >= 0.88 && row$coverage <= 0.98) "✓" else "⚠"
    cat(sprintf("  %s %-8s: %.1f%% coverage (bias: %+.2f%%)\n",
                status, row$method, row$coverage * 100, row$rel_bias))
  }
}

cat("\n========================================\n")
cat("METHOD COMPARISON AT DIFFERENT SAMPLE SIZES\n")
cat("========================================\n\n")

for (d in c(4, 5)) {
  cat(sprintf("\nDimension d=%d:\n", d))

  subset_d <- results_all[results_all$d == d, ]

  for (method in c("linear", "gam", "rf")) {
    cat(sprintf("\n  %s:\n", toupper(method)))
    subset_method <- subset_d[subset_d$method == method, ]
    subset_method <- subset_method[order(subset_method$n), ]

    for (j in 1:nrow(subset_method)) {
      row <- subset_method[j, ]
      status <- if (row$coverage >= 0.88 && row$coverage <= 0.98) "✓" else "⚠"
      cat(sprintf("    %s n=%d: %.1f%% coverage (bias: %+.2f%%)\n",
                  status, row$n, row$coverage * 100, row$rel_bias))
    }
  }
}

cat("\n========================================\n")
cat("KEY FINDINGS\n")
cat("========================================\n\n")

# Best method per dimension
for (d in c(3, 4, 5)) {
  cat(sprintf("d=%d at n=1000:\n", d))
  subset <- results_all[results_all$d == d & results_all$n == 1000, ]

  best_idx <- which.max(subset$coverage)
  best <- subset[best_idx, ]

  cat(sprintf("  Best method: %s (%.1f%% coverage)\n",
              toupper(best$method), best$coverage * 100))

  # Compare to linear
  linear <- subset[subset$method == "linear", ]
  improvement <- best$coverage - linear$coverage

  if (improvement > 0.05) {
    cat(sprintf("  Improvement over linear: %.1f percentage points\n",
                improvement * 100))
  }
  cat("\n")
}

# Sample size effect
cat("Sample size effect (d=5, GAM):\n")
subset_d5_gam <- results_all[results_all$d == 5 & results_all$method == "gam", ]
subset_d5_gam <- subset_d5_gam[order(subset_d5_gam$n), ]

for (i in 1:nrow(subset_d5_gam)) {
  row <- subset_d5_gam[i, ]
  cat(sprintf("  n=%d: %.1f%% coverage\n", row$n, row$coverage * 100))
}

cat("\n========================================\n")
cat("RECOMMENDATIONS\n")
cat("========================================\n\n")

# Find minimum n for 90% coverage by dimension and method
for (d in c(3, 4, 5)) {
  cat(sprintf("For d=%d:\n", d))

  for (method in c("linear", "gam", "rf")) {
    subset <- results_all[results_all$d == d & results_all$method == method, ]
    subset <- subset[order(subset$n), ]

    good_coverage <- subset$coverage >= 0.90

    if (any(good_coverage)) {
      min_n <- min(subset$n[good_coverage])
      cat(sprintf("  %s: n ≥ %d for 90%% coverage\n",
                  toupper(method), min_n))
    } else {
      cat(sprintf("  %s: Need n > %d\n",
                  toupper(method), max(subset$n)))
    }
  }
  cat("\n")
}

# Save results
saveRDS(results_all, "flexible_nuisances_high_dim_results.rds")
cat("Results saved to: flexible_nuisances_high_dim_results.rds\n")
