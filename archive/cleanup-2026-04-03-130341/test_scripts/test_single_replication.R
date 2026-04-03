#!/usr/bin/env Rscript
# Test a single replication to see what error occurs

library(tidyverse)
library(here)

devtools::load_all(here("package"))

# Source the helper function from validation script
compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w,
                                  n_grid = 500) {
  grid_x1 <- seq(min(X1), max(X1), length.out = sqrt(n_grid))
  grid_x2 <- seq(min(X2), max(X2), length.out = sqrt(n_grid))
  grid <- expand.grid(X1 = grid_x1, X2 = grid_x2)

  tau_s_true <- tau_s_fn(grid$X1, grid$X2)
  tau_y_true <- tau_y_fn(grid$X1, grid$X2)
  h_true <- tau_s_true * tau_y_true

  X_grid <- scale(cbind(grid$X1, grid$X2))
  cost_matrix <- as.matrix(dist(X_grid, method = "euclidean"))^2

  dual_objective <- function(gamma) {
    n <- nrow(grid)
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  optimize(dual_objective, interval = c(0, 100), maximum = TRUE)$objective
}

cat("Testing single replication...\n\n")

set.seed(10001)
n <- 500
lambda_w <- 0.5

# Baseline DGP
tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1 - 0.1 * X2
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1 + 0.1 * X2

X1 <- rnorm(n)
X2 <- rnorm(n)
A <- rbinom(n, 1, 0.5)

tau_s_true <- tau_s_fn(X1, X2)
tau_y_true <- tau_y_fn(X1, X2)

S <- tau_s_true * A + 0.5 + 0.2 * X1 + rnorm(n, sd = 0.3)
Y <- tau_y_true * A + 0.6 + 0.3 * X2 + rnorm(n, sd = 0.4)

data <- tibble(A = A, S = S, Y = Y, X1 = X1, X2 = X2)

cat("Data generated successfully\n")
cat("Computing truth...\n")

truth <- compute_true_minimax(X1, X2, tau_s_fn, tau_y_fn, lambda_w)
cat(sprintf("Truth: %.4f\n\n", truth))

cat("Running bootstrap_ci_sample_splitting...\n")

result <- tryCatch({
  bootstrap_ci_sample_splitting(
    data = data,
    covariates = c("X1", "X2"),
    lambda_w = lambda_w,
    split_ratio = 0.5,
    tau_method = "kernel",
    cross_fit = TRUE,
    n_bootstrap = 10,  # Just 10 for quick test
    confidence_level = 0.95,
    seed = 10001,
    verbose = TRUE
  )
}, error = function(e) {
  cat("\n\nERROR CAUGHT:\n")
  cat(conditionMessage(e), "\n")
  cat("\nFull error:\n")
  print(e)
  NULL
})

if (!is.null(result)) {
  cat("\n\nSuccess!\n")
  cat(sprintf("phi_star: %.4f\n", result$phi_star))
  cat(sprintf("CI: [%.4f, %.4f]\n", result$ci_lower, result$ci_upper))
  cat(sprintf("Truth in CI: %s\n",
              ifelse(truth >= result$ci_lower & truth <= result$ci_upper, "YES", "NO")))
} else {
  cat("\n\nFunction returned NULL\n")
}
