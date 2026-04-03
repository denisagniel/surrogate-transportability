#!/usr/bin/env Rscript
# Test 1: Oracle nuisances (should work perfectly)
# Test 2: Large samples (5-10k) with RF

library(mgcv)
library(randomForest)

source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(2026)

cat("========================================\n")
cat("ORACLE AND LARGE N TEST\n")
cat("========================================\n\n")

# Generate data with GENUINELY NONLINEAR treatment effects
generate_nonlinear_data <- function(n, d) {
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  colnames(X) <- paste0("X", 1:d)

  A <- rbinom(n, 1, 0.5)

  # NONLINEAR treatment effects
  tau_S <- 0.3 + 0.4 * X[,1] * X[,2] +
           0.2 * (X[,1]^2 - 1) +
           0.15 * ifelse(X[,1] > 0, X[,2], -X[,2])

  tau_Y <- 0.5 + 0.5 * X[,1] * X[,2] +
           0.3 * (X[,1]^2 - 1) +
           0.2 * ifelse(X[,1] > 0, X[,2], -X[,2])

  if (d > 2) {
    for (j in 3:d) {
      weight <- 0.1 / j
      tau_S <- tau_S + weight * X[,j] * X[,1]
      tau_Y <- tau_Y + 1.5 * weight * X[,j] * X[,1]
    }
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

# ORACLE nuisances (perfect)
estimate_nuisances_oracle <- function(train_data, test_data, covariates) {
  # Generate true CATEs for test data
  test_X <- as.matrix(test_data[, covariates, drop = FALSE])
  n_test <- nrow(test_X)
  d <- ncol(test_X)

  # Compute true treatment effects
  tau_S <- 0.3 + 0.4 * test_X[,1] * test_X[,2] +
           0.2 * (test_X[,1]^2 - 1) +
           0.15 * ifelse(test_X[,1] > 0, test_X[,2], -test_X[,2])

  tau_Y <- 0.5 + 0.5 * test_X[,1] * test_X[,2] +
           0.3 * (test_X[,1]^2 - 1) +
           0.2 * ifelse(test_X[,1] > 0, test_X[,2], -test_X[,2])

  if (d > 2) {
    for (j in 3:d) {
      weight <- 0.1 / j
      tau_S <- tau_S + weight * test_X[,j] * test_X[,1]
      tau_Y <- tau_Y + 1.5 * weight * test_X[,j] * test_X[,1]
    }
  }

  # For oracle, we also need mu functions (just use tau since we don't need them for h)
  list(
    tau_S_hat = tau_S,
    tau_Y_hat = tau_Y,
    h_hat = tau_S * tau_Y,
    mu_S1_hat = tau_S,
    mu_S0_hat = rep(0, n_test),
    mu_Y1_hat = tau_Y,
    mu_Y0_hat = rep(0, n_test)
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

# GAM nuisances
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
    if (method == "oracle") {
      nuisances <- estimate_nuisances_oracle(train_data, test_data, covariates)
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
    }, error = function(e) {
      cat(sprintf("Error: %s\n", e$message))
      return(NULL)
    })

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

# ========================================
# TEST 1: ORACLE NUISANCES
# ========================================

cat("========================================\n")
cat("TEST 1: ORACLE NUISANCES (n=1000)\n")
cat("========================================\n\n")

cat("Testing with perfect nuisances...\n")
cat("Expected: ~95% coverage for all dimensions\n\n")

oracle_configs <- expand.grid(
  d = c(3, 4),
  n = c(1000),
  method = c("oracle"),
  stringsAsFactors = FALSE
)

oracle_results <- list()
for (i in 1:nrow(oracle_configs)) {
  d <- oracle_configs$d[i]
  n <- oracle_configs$n[i]
  method <- oracle_configs$method[i]

  cat(sprintf("d=%d, n=%d, %s ... ", d, n, method))
  start_time <- Sys.time()

  result <- test_config(d, n, method, n_sims = 50)
  oracle_results[[i]] <- result

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("done (%.1f sec, coverage: %.1f%%)\n",
              elapsed, result$coverage * 100))
}

oracle_all <- do.call(rbind, oracle_results)

cat("\n========================================\n")
cat("ORACLE RESULTS\n")
cat("========================================\n\n")

print(oracle_all, digits = 4)

cat("\nConclusion:\n")
if (all(oracle_all$coverage >= 0.90 & oracle_all$coverage <= 0.98)) {
  cat("  ✓ Oracle nuisances give ~95% coverage\n")
  cat("  → Method works correctly with perfect nuisances\n")
} else {
  cat("  ✗ Oracle nuisances don't give 95% coverage\n")
  cat("  → Possible issue with dual estimation or IF formula\n")
}

# ========================================
# TEST 2: LARGE SAMPLE SIZES
# ========================================

cat("\n========================================\n")
cat("TEST 2: LARGE SAMPLES (n=5000, 10000)\n")
cat("========================================\n\n")

cat("Testing RF with large samples...\n")
cat("Expected: RF should improve substantially with more data\n\n")

large_n_configs <- expand.grid(
  d = c(4),
  n = c(1000, 5000, 10000),
  method = c("gam", "rf"),
  stringsAsFactors = FALSE
)

large_n_results <- list()
for (i in 1:nrow(large_n_configs)) {
  d <- large_n_configs$d[i]
  n <- large_n_configs$n[i]
  method <- large_n_configs$method[i]

  cat(sprintf("d=%d, n=%d, %s ... ", d, n, method))
  start_time <- Sys.time()

  result <- test_config(d, n, method, n_sims = 50)
  large_n_results[[i]] <- result

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("done (%.1f sec, coverage: %.1f%%)\n",
              elapsed, result$coverage * 100))
}

large_n_all <- do.call(rbind, large_n_results)

cat("\n========================================\n")
cat("LARGE N RESULTS\n")
cat("========================================\n\n")

print(large_n_all, digits = 4)

cat("\n========================================\n")
cat("COMPARISON: RF vs GAM ACROSS SAMPLE SIZES\n")
cat("========================================\n\n")

for (n_val in unique(large_n_all$n)) {
  cat(sprintf("n = %d:\n", n_val))
  subset_n <- large_n_all[large_n_all$n == n_val, ]

  for (j in 1:nrow(subset_n)) {
    row <- subset_n[j, ]
    status <- if (row$coverage >= 0.88 && row$coverage <= 0.98) "✓" else "⚠"
    cat(sprintf("  %s %-8s: %.1f%% coverage (bias: %+.2f%%)\n",
                status, row$method, row$coverage * 100, row$rel_bias))
  }
  cat("\n")
}

cat("Sample size effect:\n")
rf_results <- large_n_all[large_n_all$method == "rf", ]
rf_results <- rf_results[order(rf_results$n), ]

cat("\nRF coverage by sample size:\n")
for (i in 1:nrow(rf_results)) {
  row <- rf_results[i, ]
  improvement <- if (i > 1) {
    sprintf(" [%+.1f pp]", (row$coverage - rf_results$coverage[i-1]) * 100)
  } else {
    ""
  }
  cat(sprintf("  n=%5d: %.1f%% coverage%s\n", row$n, row$coverage * 100, improvement))
}

cat("\nConclusion:\n")
final_rf <- rf_results[rf_results$n == max(rf_results$n), ]
if (final_rf$coverage >= 0.90) {
  cat(sprintf("  ✓ RF reaches %.1f%% coverage at n=%d\n",
              final_rf$coverage * 100, final_rf$n))
  cat("  → RF works with sufficient data\n")
} else {
  cat(sprintf("  ✗ RF only reaches %.1f%% coverage even at n=%d\n",
              final_rf$coverage * 100, final_rf$n))
  cat("  → RF has fundamental issues beyond sample size\n")
}

# Save results
saveRDS(list(oracle = oracle_all, large_n = large_n_all),
        "oracle_and_large_n_results.rds")
cat("\nResults saved to: oracle_and_large_n_results.rds\n")
