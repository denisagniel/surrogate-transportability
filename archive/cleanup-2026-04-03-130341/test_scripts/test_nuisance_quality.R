#!/usr/bin/env Rscript
# Compare nuisance estimation quality across methods
# Measure RMSE of estimated CATE vs true CATE

library(mgcv)
library(randomForest)

set.seed(2026)

cat("========================================\n")
cat("NUISANCE ESTIMATION QUALITY\n")
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

  list(data = data,
       weights_S = weights,
       weights_Y = 1.5 * weights,
       tau_S_true = tau_S,
       tau_Y_true = tau_Y)
}

# Compute true CATEs for test set
compute_true_cates <- function(X, weights_S, weights_Y) {
  tau_S_true <- 0.3 + as.vector(X %*% weights_S) + 0.05 * X[,1]^2
  tau_Y_true <- 0.4 + as.vector(X %*% weights_Y) + 0.08 * X[,1]^2

  list(tau_S_true = tau_S_true, tau_Y_true = tau_Y_true)
}

# LINEAR nuisances
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

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat)
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

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat)
}

# RF nuisances (original)
estimate_nuisances_rf_original <- function(train_data, test_data, covariates) {
  train_A1 <- train_data[train_data$A == 1, ]
  train_A0 <- train_data[train_data$A == 0, ]

  formula_S <- as.formula(paste("S ~", paste(covariates, collapse = " + ")))
  formula_Y <- as.formula(paste("Y ~", paste(covariates, collapse = " + ")))

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

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat)
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

  list(tau_S_hat = tau_S_hat, tau_Y_hat = tau_Y_hat)
}

# Test configuration
test_nuisance_quality <- function(d, n, method, n_sims = 100) {

  # Get DGP structure
  template <- generate_data(100, d)
  weights_S <- template$weights_S
  weights_Y <- template$weights_Y

  results <- replicate(n_sims, {
    # Generate train and test data
    train <- generate_data(n, d)
    test <- generate_data(n, d)  # Independent test set

    train_data <- train$data
    test_data <- test$data
    covariates <- paste0("X", 1:d)

    # Get true CATEs for test set
    test_X <- as.matrix(test_data[, covariates])
    true_cates <- compute_true_cates(test_X, weights_S, weights_Y)

    # Estimate nuisances
    if (method == "linear") {
      estimated <- estimate_nuisances_linear(train_data, test_data, covariates)
    } else if (method == "gam") {
      estimated <- estimate_nuisances_gam(train_data, test_data, covariates)
    } else if (method == "rf_original") {
      estimated <- estimate_nuisances_rf_original(train_data, test_data, covariates)
    } else if (method == "rf_tuned") {
      estimated <- estimate_nuisances_rf_tuned(train_data, test_data, covariates)
    }

    # Compute RMSE
    rmse_S <- sqrt(mean((estimated$tau_S_hat - true_cates$tau_S_true)^2))
    rmse_Y <- sqrt(mean((estimated$tau_Y_hat - true_cates$tau_Y_true)^2))

    # Also compute bias and correlation
    bias_S <- mean(estimated$tau_S_hat - true_cates$tau_S_true)
    bias_Y <- mean(estimated$tau_Y_hat - true_cates$tau_Y_true)
    cor_S <- cor(estimated$tau_S_hat, true_cates$tau_S_true)
    cor_Y <- cor(estimated$tau_Y_hat, true_cates$tau_Y_true)

    c(rmse_S = rmse_S, rmse_Y = rmse_Y,
      bias_S = bias_S, bias_Y = bias_Y,
      cor_S = cor_S, cor_Y = cor_Y)
  }, simplify = TRUE)

  data.frame(
    d = d,
    n = n,
    method = method,
    rmse_S = mean(results["rmse_S", ]),
    rmse_Y = mean(results["rmse_Y", ]),
    bias_S = mean(results["bias_S", ]),
    bias_Y = mean(results["bias_Y", ]),
    cor_S = mean(results["cor_S", ]),
    cor_Y = mean(results["cor_Y", ])
  )
}

# Test grid
cat("Testing nuisance quality...\n")
cat("Dimensions: d=4,5\n")
cat("Sample size: n=1000\n")
cat("Methods: linear, gam, rf_original, rf_tuned\n\n")

configs <- expand.grid(
  d = c(4, 5),
  n = c(1000),
  method = c("linear", "gam", "rf_original", "rf_tuned"),
  stringsAsFactors = FALSE
)

results_list <- list()
for (i in 1:nrow(configs)) {
  d <- configs$d[i]
  n <- configs$n[i]
  method <- configs$method[i]

  cat(sprintf("d=%d, n=%d, %s ... ", d, n, method))
  start_time <- Sys.time()

  result <- test_nuisance_quality(d, n, method, n_sims = 100)
  results_list[[i]] <- result

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("done (%.1f sec)\n", elapsed))
}

results_all <- do.call(rbind, results_list)

cat("\n========================================\n")
cat("NUISANCE QUALITY RESULTS\n")
cat("========================================\n\n")

print(results_all, digits = 4)

cat("\n========================================\n")
cat("COMPARISON BY DIMENSION\n")
cat("========================================\n\n")

for (d in unique(results_all$d)) {
  cat(sprintf("\nDimension d=%d:\n\n", d))
  subset_d <- results_all[results_all$d == d, ]

  cat("RMSE for τ_S:\n")
  for (j in 1:nrow(subset_d)) {
    row <- subset_d[j, ]
    cat(sprintf("  %-12s: %.4f (bias: %+.4f, cor: %.3f)\n",
                row$method, row$rmse_S, row$bias_S, row$cor_S))
  }

  cat("\nRMSE for τ_Y:\n")
  for (j in 1:nrow(subset_d)) {
    row <- subset_d[j, ]
    cat(sprintf("  %-12s: %.4f (bias: %+.4f, cor: %.3f)\n",
                row$method, row$rmse_Y, row$bias_Y, row$cor_Y))
  }

  # Find best method
  best_S <- subset_d[which.min(subset_d$rmse_S), "method"]
  best_Y <- subset_d[which.min(subset_d$rmse_Y), "method"]

  cat(sprintf("\nBest for τ_S: %s\n", best_S))
  cat(sprintf("Best for τ_Y: %s\n", best_Y))
}

cat("\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

# Average RMSE across both outcomes
results_all$avg_rmse <- (results_all$rmse_S + results_all$rmse_Y) / 2

for (d in unique(results_all$d)) {
  cat(sprintf("\nd=%d average RMSE:\n", d))
  subset_d <- results_all[results_all$d == d, ]
  subset_d <- subset_d[order(subset_d$avg_rmse), ]

  for (j in 1:nrow(subset_d)) {
    row <- subset_d[j, ]
    cat(sprintf("  %d. %-12s: %.4f\n", j, row$method, row$avg_rmse))
  }
}

# Save results
saveRDS(results_all, "nuisance_quality_results.rds")
cat("\nResults saved to: nuisance_quality_results.rds\n")
