#!/usr/bin/env Rscript
# Test RF tuning fixes to resolve severe undercoverage
# Compare: Original RF, Tuned RF, Joint RF

library(randomForest)
source("package/R/wasserstein_minimax_IF_inference.R")

set.seed(2026)

cat("========================================\n")
cat("RF TUNING INVESTIGATION\n")
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

# ORIGINAL RF (from test_flexible_nuisances_high_dim.R)
estimate_nuisances_rf_original <- function(train_data, test_data, covariates) {
  train_A1 <- train_data[train_data$A == 1, ]
  train_A0 <- train_data[train_data$A == 0, ]

  formula_S <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_Y <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))

  # Original: ntree=100, no constraints
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

# FIX 1: More trees + constrain tree depth
estimate_nuisances_rf_tuned <- function(train_data, test_data, covariates) {
  train_A1 <- train_data[train_data$A == 1, ]
  train_A0 <- train_data[train_data$A == 0, ]

  formula_S <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_Y <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))

  # Tuned: ntree=500, nodesize=20 (prevent deep overfitting)
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

# FIX 2: Joint model (like GAM does)
estimate_nuisances_rf_joint <- function(train_data, test_data, covariates) {
  # Build joint formulas with treatment indicator
  formula_S <- as.formula(paste("S ~", paste(covariates, collapse = " + "), "+ A"))
  formula_Y <- as.formula(paste("Y ~", paste(covariates, collapse = " + "), "+ A"))

  # Fit joint models (uses all training data)
  fit_S <- randomForest(formula_S, data = train_data, ntree = 500, nodesize = 20)
  fit_Y <- randomForest(formula_Y, data = train_data, ntree = 500, nodesize = 20)

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

# Inference wrapper
wasserstein_rf_test <- function(data, covariates, rf_method,
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

    # Estimate nuisances based on RF method
    if (rf_method == "original") {
      nuisances <- estimate_nuisances_rf_original(train_data, test_data, covariates)
    } else if (rf_method == "tuned") {
      nuisances <- estimate_nuisances_rf_tuned(train_data, test_data, covariates)
    } else if (rf_method == "joint") {
      nuisances <- estimate_nuisances_rf_joint(train_data, test_data, covariates)
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
test_config <- function(d, n, rf_method, n_sims = 50) {
  # Get truth
  template <- generate_data(100, d)
  truth <- compute_truth(d, template$weights_S, template$weights_Y)

  # Run simulations
  results <- replicate(n_sims, {
    dgp <- generate_data(n, d)
    data <- dgp$data
    covariates <- paste0("X", 1:d)

    result <- tryCatch({
      wasserstein_rf_test(
        data = data,
        covariates = covariates,
        rf_method = rf_method,
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
    rf_method = rf_method,
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

# Test grid: Focus on problematic cases
cat("Testing RF fixes on problematic configurations...\n")
cat("Dimensions: d=4,5\n")
cat("Sample size: n=1000\n")
cat("Methods: original, tuned, joint\n\n")

configs <- expand.grid(
  d = c(4, 5),
  n = c(1000),
  rf_method = c("original", "tuned", "joint"),
  stringsAsFactors = FALSE
)

results_list <- list()
for (i in 1:nrow(configs)) {
  d <- configs$d[i]
  n <- configs$n[i]
  rf_method <- configs$rf_method[i]

  cat(sprintf("d=%d, n=%d, RF-%s ... ", d, n, rf_method))
  start_time <- Sys.time()

  result <- test_config(d, n, rf_method, n_sims = 50)
  results_list[[i]] <- result

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("done (%.1f sec, coverage: %.1f%%)\n",
              elapsed, result$coverage * 100))
}

results_all <- do.call(rbind, results_list)

cat("\n========================================\n")
cat("RESULTS COMPARISON\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("COVERAGE COMPARISON BY DIMENSION\n")
cat("========================================\n\n")

for (d in unique(results_all$d)) {
  cat(sprintf("\nDimension d=%d:\n", d))
  subset_d <- results_all[results_all$d == d, ]

  # Original (baseline)
  original <- subset_d[subset_d$rf_method == "original", ]
  cat(sprintf("  Original RF:  %.1f%% coverage (bias: %+.2f%%)\n",
              original$coverage * 100, original$rel_bias))

  # Tuned
  tuned <- subset_d[subset_d$rf_method == "tuned", ]
  improvement_tuned <- tuned$coverage - original$coverage
  cat(sprintf("  Tuned RF:     %.1f%% coverage (bias: %+.2f%%) [%+.1f pp]\n",
              tuned$coverage * 100, tuned$rel_bias, improvement_tuned * 100))

  # Joint
  joint <- subset_d[subset_d$rf_method == "joint", ]
  improvement_joint <- joint$coverage - original$coverage
  cat(sprintf("  Joint RF:     %.1f%% coverage (bias: %+.2f%%) [%+.1f pp]\n",
              joint$coverage * 100, joint$rel_bias, improvement_joint * 100))
}

cat("\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

# Best method
best_idx <- which.max(results_all$coverage)
best <- results_all[best_idx, ]

cat(sprintf("Best performing RF method: %s\n", best$rf_method))
cat(sprintf("  d=%d, n=%d: %.1f%% coverage (bias: %+.2f%%)\n",
            best$d, best$n, best$coverage * 100, best$rel_bias))

# Compare to linear baseline (from previous test)
cat("\nComparison to linear regression:\n")
cat("  d=4, n=1000: Linear had 98.0% coverage\n")
cat("  d=5, n=1000: Linear had 92.0% coverage\n")

if (best$coverage >= 0.90) {
  cat(sprintf("\n✓ Best RF method achieves acceptable coverage (%.1f%% >= 90%%)\n",
              best$coverage * 100))
} else {
  cat(sprintf("\n✗ Best RF method still below 90%% threshold (%.1f%%)\n",
              best$coverage * 100))
}

# Save results
saveRDS(results_all, "rf_tuning_test_results.rds")
cat("\nResults saved to: rf_tuning_test_results.rds\n")
