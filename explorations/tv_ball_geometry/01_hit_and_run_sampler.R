# Hit-and-Run Sampler for TV Ball
#
# Implements uniform sampling from B_λ(P₀) = {Q : TV(Q, P₀) ≤ λ}
# where TV(Q, P₀) = (1/2) Σ|Q_i - P₀_i|
#
# Algorithm: Hit-and-run MCMC
# 1. Start at P₀ (always feasible)
# 2. Sample random direction on simplex tangent space
# 3. Find feasible segment along that direction
# 4. Sample uniformly on segment
# 5. Repeat with burn-in

library(tidyverse)

#' Sample uniform direction on probability simplex tangent space
#'
#' @param K dimension of simplex (number of types)
#' @return K-vector d with sum(d) = 0 and ||d|| = 1
sample_simplex_direction <- function(K) {
  # Sample from standard normal
  d <- rnorm(K)

  # Project onto simplex tangent space: subtract mean
  d <- d - mean(d)

  # Normalize
  d <- d / sqrt(sum(d^2))

  return(d)
}

#' Compute TV distance between two probability distributions
#'
#' @param Q probability vector
#' @param P0 baseline probability vector
#' @return TV distance (1/2) * sum(|Q - P0|)
tv_distance <- function(Q, P0) {
  0.5 * sum(abs(Q - P0))
}

#' Find feasible step range along a direction in TV ball
#'
#' Given current point q and direction d, find the range [t_min, t_max]
#' such that q + t*d satisfies:
#' 1. TV(q + t*d, P₀) ≤ λ
#' 2. (q + t*d)_i ≥ 0 for all i
#'
#' @param q_current current point (K-vector, sums to 1)
#' @param direction direction vector (K-vector, sums to 0, normalized)
#' @param P0 baseline distribution (K-vector)
#' @param lambda TV ball radius
#' @return list with t_min and t_max
find_feasible_range <- function(q_current, direction, P0, lambda) {
  K <- length(q_current)

  # Constraint 1: Stay on positive orthant (q_i ≥ 0)
  # q_i + t * d_i ≥ 0
  # If d_i > 0: no upper bound from this constraint, t ≥ -q_i/d_i (lower bound)
  # If d_i < 0: t ≤ -q_i/d_i (upper bound), no lower bound from this constraint
  # If d_i = 0: no constraint from this dimension

  t_min <- -Inf
  t_max <- Inf

  for (i in 1:K) {
    if (direction[i] > 1e-10) {
      # d_i > 0: lower bound
      t_lower <- -q_current[i] / direction[i]
      t_min <- max(t_min, t_lower)
    } else if (direction[i] < -1e-10) {
      # d_i < 0: upper bound
      t_upper <- -q_current[i] / direction[i]
      t_max <- min(t_max, t_upper)
    }
  }

  # Constraint 2: Stay in TV ball
  # This is trickier. TV(q + t*d, P₀) is piecewise linear in t.
  # We need to find where TV(q + t*d, P₀) = λ

  # TV(q + t*d, P₀) = (1/2) Σ|q_i + t*d_i - P₀_i|
  # Each term |q_i + t*d_i - P₀_i| is piecewise linear with breakpoint at
  # t_i = (P₀_i - q_i) / d_i (if d_i ≠ 0)

  # Strategy: Evaluate TV at many points along the line and use bisection
  # This is not elegant but works for exploration

  # Sample points along the current feasible range
  if (is.infinite(t_min) || is.infinite(t_max)) {
    # If unbounded, use a reasonable range
    t_test <- seq(-10, 10, length.out = 1000)
  } else {
    t_test <- seq(t_min, t_max, length.out = 1000)
  }

  # Compute TV at each point
  tv_vals <- sapply(t_test, function(t) {
    q_new <- q_current + t * direction
    # Check if on simplex (should be by construction)
    if (any(q_new < -1e-10)) return(Inf)  # Violates positivity
    tv_distance(q_new, P0)
  })

  # Find where TV ≤ λ
  feasible <- tv_vals <= lambda + 1e-10  # Small tolerance

  if (!any(feasible)) {
    # No feasible points (shouldn't happen if we start at a feasible point)
    warning("No feasible points found along direction")
    return(list(t_min = 0, t_max = 0))
  }

  feasible_indices <- which(feasible)
  t_min_tv <- t_test[min(feasible_indices)]
  t_max_tv <- t_test[max(feasible_indices)]

  # Take intersection of constraints
  t_min_final <- max(t_min, t_min_tv)
  t_max_final <- min(t_max, t_max_tv)

  # Sanity check
  if (t_min_final > t_max_final) {
    warning("Infeasible: t_min > t_max. Setting to current point.")
    return(list(t_min = 0, t_max = 0))
  }

  return(list(t_min = t_min_final, t_max = t_max_final))
}

#' Hit-and-run sampler for TV ball
#'
#' @param P0 baseline distribution (K-vector, sums to 1)
#' @param lambda TV ball radius
#' @param n_samples number of samples to return
#' @param burn_in number of burn-in iterations
#' @param thin thinning interval (keep every thin-th sample)
#' @param initial starting point (if NULL, use P0)
#' @param verbose print progress
#' @return matrix of samples (n_samples × K)
hit_and_run_tv_ball <- function(
  P0,
  lambda,
  n_samples = 1000,
  burn_in = 1000,
  thin = 10,
  initial = NULL,
  verbose = TRUE
) {

  K <- length(P0)

  # Validate inputs
  stopifnot(abs(sum(P0) - 1) < 1e-10)
  stopifnot(all(P0 >= 0))
  stopifnot(lambda > 0 && lambda <= 1)

  # Initialize at P0 (always feasible)
  if (is.null(initial)) {
    q_current <- P0
  } else {
    q_current <- initial
    # Check feasibility
    if (tv_distance(q_current, P0) > lambda + 1e-10) {
      stop("Initial point not in TV ball")
    }
  }

  # Storage
  total_iterations <- burn_in + n_samples * thin
  samples <- matrix(NA, nrow = n_samples, ncol = K)

  # Hit-and-run iterations
  if (verbose) {
    cat(sprintf("Running hit-and-run sampler: %d iterations (burn-in: %d, thin: %d)\n",
                total_iterations, burn_in, thin))
  }

  sample_idx <- 1
  accept_count <- 0

  for (iter in 1:total_iterations) {

    # Progress
    if (verbose && iter %% 1000 == 0) {
      cat(sprintf("  Iteration %d / %d\n", iter, total_iterations))
    }

    # 1. Sample direction
    direction <- sample_simplex_direction(K)

    # 2. Find feasible range
    range <- find_feasible_range(q_current, direction, P0, lambda)

    # 3. Sample uniformly on feasible segment
    if (range$t_max - range$t_min < 1e-10) {
      # Stuck at current point (shouldn't happen often)
      t_step <- 0
    } else {
      t_step <- runif(1, range$t_min, range$t_max)
    }

    # 4. Move to new point
    q_new <- q_current + t_step * direction

    # Sanity checks (should always pass)
    if (any(q_new < -1e-10)) {
      warning(sprintf("Iter %d: Negative probability (min: %.6f)", iter, min(q_new)))
      next  # Skip this iteration
    }

    if (abs(sum(q_new) - 1) > 1e-6) {
      warning(sprintf("Iter %d: Sum not 1 (sum: %.6f)", iter, sum(q_new)))
      q_new <- q_new / sum(q_new)  # Renormalize
    }

    tv_new <- tv_distance(q_new, P0)
    if (tv_new > lambda + 1e-6) {
      warning(sprintf("Iter %d: Outside TV ball (TV: %.6f, lambda: %.6f)", iter, tv_new, lambda))
      next  # Skip this iteration
    }

    # Accept move
    q_current <- q_new
    accept_count <- accept_count + 1

    # 5. Store sample (after burn-in, with thinning)
    if (iter > burn_in && (iter - burn_in) %% thin == 0) {
      samples[sample_idx, ] <- q_current
      sample_idx <- sample_idx + 1
    }
  }

  if (verbose) {
    cat(sprintf("Acceptance rate: %.2f%%\n", 100 * accept_count / total_iterations))
  }

  return(samples)
}

#' Test the hit-and-run sampler
#'
#' @param K dimension
#' @param lambda TV radius
#' @param n_samples number of samples
test_hit_and_run <- function(K = 5, lambda = 0.3, n_samples = 1000) {

  cat("Testing hit-and-run sampler\n")
  cat(sprintf("K = %d, lambda = %.2f, n_samples = %d\n\n", K, lambda, n_samples))

  # Create baseline distribution
  P0 <- rep(1/K, K)

  # Run sampler
  samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = n_samples,
    burn_in = 500,
    thin = 5,
    verbose = TRUE
  )

  cat("\nDiagnostics:\n")

  # Check samples are valid
  cat(sprintf("All samples sum to 1: %s\n",
              all(abs(rowSums(samples) - 1) < 1e-6)))
  cat(sprintf("All samples non-negative: %s\n",
              all(samples >= -1e-10)))

  # Check TV distances
  tv_distances <- apply(samples, 1, tv_distance, P0 = P0)
  cat(sprintf("TV distances - mean: %.4f, sd: %.4f, max: %.4f\n",
              mean(tv_distances), sd(tv_distances), max(tv_distances)))
  cat(sprintf("All within TV ball: %s\n",
              all(tv_distances <= lambda + 1e-6)))

  # Plot TV distance distribution
  df <- tibble(tv = tv_distances)

  p <- ggplot(df, aes(x = tv)) +
    geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7) +
    geom_vline(xintercept = lambda, color = "red", linetype = "dashed", linewidth = 1) +
    labs(
      title = sprintf("TV Distance Distribution (K=%d, λ=%.2f)", K, lambda),
      x = "TV distance to P₀",
      y = "Count"
    ) +
    theme_minimal()

  print(p)

  # Check coverage (should be somewhat uniform if sampling correctly)
  cat("\nSample statistics (first 3 dimensions):\n")
  for (i in 1:min(3, K)) {
    cat(sprintf("  Dimension %d - mean: %.4f, sd: %.4f, range: [%.4f, %.4f]\n",
                i, mean(samples[,i]), sd(samples[,i]),
                min(samples[,i]), max(samples[,i])))
  }

  # Return samples for further inspection
  invisible(list(samples = samples, tv_distances = tv_distances))
}

# If running interactively, run test
if (interactive()) {
  test_hit_and_run()
}
