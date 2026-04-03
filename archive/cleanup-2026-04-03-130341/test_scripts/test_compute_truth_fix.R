#!/usr/bin/env Rscript
# Test the fixed compute_true_minimax function

library(tidyverse)

# Fixed version of compute_true_minimax
compute_true_minimax <- function(X1, X2, tau_s_fn, tau_y_fn, lambda_w,
                                  n_grid = 500) {
  # Compute true minimax on a fine grid
  # Add small buffer to ensure variation
  range_x1 <- range(X1)
  range_x2 <- range(X2)

  # Expand range slightly to ensure proper grid
  buffer <- 0.01
  grid_x1 <- seq(range_x1[1] - buffer * diff(range_x1),
                 range_x1[2] + buffer * diff(range_x1),
                 length.out = sqrt(n_grid))
  grid_x2 <- seq(range_x2[1] - buffer * diff(range_x2),
                 range_x2[2] + buffer * diff(range_x2),
                 length.out = sqrt(n_grid))
  grid <- expand.grid(X1 = grid_x1, X2 = grid_x2)

  tau_s_true <- tau_s_fn(grid$X1, grid$X2)
  tau_y_true <- tau_y_fn(grid$X1, grid$X2)
  h_true <- tau_s_true * tau_y_true

  # Check for valid numeric values
  if (!is.numeric(h_true) || any(!is.finite(h_true))) {
    warning("Non-finite values in concordance computation")
    return(NA_real_)
  }

  X_grid <- scale(cbind(grid$X1, grid$X2))

  # Check for scaling issues
  if (any(!is.finite(X_grid))) {
    warning("Scaling produced non-finite values, using unscaled distances")
    X_grid <- cbind(grid$X1, grid$X2)
  }

  cost_matrix <- as.matrix(dist(X_grid, method = "euclidean"))^2

  # Check cost matrix validity
  if (!is.numeric(cost_matrix) || any(!is.finite(cost_matrix))) {
    warning("Invalid cost matrix")
    return(NA_real_)
  }

  dual_objective <- function(gamma) {
    n <- nrow(grid)
    obj_matrix <- matrix(h_true, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  result <- optimize(dual_objective, interval = c(0, 100), maximum = TRUE)
  result$objective
}

cat("Testing fixed compute_true_minimax...\n\n")

# Test 1: Normal data
set.seed(123)
X1 <- rnorm(100)
X2 <- rnorm(100)
tau_s_fn <- function(X1, X2) 0.3 + 0.2 * X1
tau_y_fn <- function(X1, X2) 0.4 + 0.3 * X1

truth <- compute_true_minimax(X1, X2, tau_s_fn, tau_y_fn, 0.5, n_grid = 100)
cat("Test 1 (normal): truth =", truth, "\n")

# Test 2: Edge case - very small variation
X1_small <- rnorm(100, mean = 5, sd = 0.001)
X2_small <- rnorm(100, mean = 3, sd = 0.001)

truth2 <- compute_true_minimax(X1_small, X2_small, tau_s_fn, tau_y_fn, 0.5, n_grid = 100)
cat("Test 2 (small var): truth =", truth2, "\n")

# Test 3: Constant (should fail gracefully)
X1_const <- rep(5, 100)
X2_const <- rep(3, 100)

truth3 <- compute_true_minimax(X1_const, X2_const, tau_s_fn, tau_y_fn, 0.5, n_grid = 100)
cat("Test 3 (constant): truth =", truth3, "(should be NA or valid)\n")

cat("\n✓ All tests completed without errors\n")
