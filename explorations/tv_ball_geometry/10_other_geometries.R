# Sampling from Other Local Geometries
#
# Extend hit-and-run to other f-divergence balls:
# - KL divergence ball
# - Chi-squared divergence ball
# - Hellinger distance ball
# - L2 ball (Euclidean)

library(tidyverse)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

# ============================================================================
# Distance/Divergence Functions
# ============================================================================

#' KL divergence from P0 to Q
kl_divergence <- function(Q, P0) {
  # KL(Q || P0) = sum(Q * log(Q/P0))
  # Handle zeros carefully
  valid <- Q > 1e-10 & P0 > 1e-10
  if (!any(valid)) return(Inf)
  sum(Q[valid] * log(Q[valid] / P0[valid]))
}

#' Chi-squared divergence
chi_squared_divergence <- function(Q, P0) {
  # χ²(Q || P0) = sum((Q - P0)^2 / P0)
  valid <- P0 > 1e-10
  sum((Q[valid] - P0[valid])^2 / P0[valid])
}

#' Hellinger distance
hellinger_distance <- function(Q, P0) {
  # H(Q, P0) = sqrt(sum((sqrt(Q) - sqrt(P0))^2)) / sqrt(2)
  sqrt(sum((sqrt(Q) - sqrt(P0))^2)) / sqrt(2)
}

#' L2 (Euclidean) distance
l2_distance <- function(Q, P0) {
  sqrt(sum((Q - P0)^2))
}

# ============================================================================
# Geometry-Specific Feasible Range Finders
# ============================================================================

#' Find feasible range for KL divergence ball
#'
#' @param q_current Current point
#' @param direction Direction vector
#' @param P0 Baseline
#' @param epsilon Ball radius
find_feasible_range_kl <- function(q_current, direction, P0, epsilon) {

  K <- length(q_current)

  # Simplex constraint (same as TV)
  t_min <- -Inf
  t_max <- Inf

  for (i in 1:K) {
    if (direction[i] > 1e-10) {
      t_min <- max(t_min, -q_current[i] / direction[i])
    } else if (direction[i] < -1e-10) {
      t_max <- min(t_max, -q_current[i] / direction[i])
    }
  }

  # KL constraint: more complex, use grid search
  if (is.infinite(t_min) || is.infinite(t_max)) {
    t_test <- seq(-5, 5, length.out = 1000)
  } else {
    t_test <- seq(t_min, t_max, length.out = 1000)
  }

  kl_vals <- sapply(t_test, function(t) {
    q_new <- q_current + t * direction
    if (any(q_new < -1e-10)) return(Inf)
    kl_divergence(q_new, P0)
  })

  feasible <- kl_vals <= epsilon + 1e-8

  if (!any(feasible)) {
    return(list(t_min = 0, t_max = 0))
  }

  feasible_indices <- which(feasible)
  t_min_kl <- t_test[min(feasible_indices)]
  t_max_kl <- t_test[max(feasible_indices)]

  return(list(t_min = max(t_min, t_min_kl), t_max = min(t_max, t_max_kl)))
}

#' Find feasible range for chi-squared ball
find_feasible_range_chi2 <- function(q_current, direction, P0, epsilon) {

  K <- length(q_current)

  # Simplex constraint
  t_min <- -Inf
  t_max <- Inf

  for (i in 1:K) {
    if (direction[i] > 1e-10) {
      t_min <- max(t_min, -q_current[i] / direction[i])
    } else if (direction[i] < -1e-10) {
      t_max <- min(t_max, -q_current[i] / direction[i])
    }
  }

  # Chi-squared constraint: χ²(q + td, P0) = sum((q_i + td_i - P0_i)^2 / P0_i)
  # This is quadratic in t: at² + bt + c ≤ ε

  valid <- P0 > 1e-10
  a <- sum(direction[valid]^2 / P0[valid])
  b <- 2 * sum(direction[valid] * (q_current[valid] - P0[valid]) / P0[valid])
  c <- sum((q_current[valid] - P0[valid])^2 / P0[valid])

  # Solve at² + bt + c = ε
  discriminant <- b^2 - 4*a*(c - epsilon)

  if (discriminant < 0) {
    # No feasible points
    return(list(t_min = 0, t_max = 0))
  }

  t_roots <- c((-b - sqrt(discriminant))/(2*a),
               (-b + sqrt(discriminant))/(2*a))
  t_min_chi2 <- min(t_roots)
  t_max_chi2 <- max(t_roots)

  return(list(t_min = max(t_min, t_min_chi2), t_max = min(t_max, t_max_chi2)))
}

#' Find feasible range for L2 ball
find_feasible_range_l2 <- function(q_current, direction, P0, epsilon) {

  K <- length(q_current)

  # Simplex constraint
  t_min <- -Inf
  t_max <- Inf

  for (i in 1:K) {
    if (direction[i] > 1e-10) {
      t_min <- max(t_min, -q_current[i] / direction[i])
    } else if (direction[i] < -1e-10) {
      t_max <- min(t_max, -q_current[i] / direction[i])
    }
  }

  # L2 constraint: ||q + td - P0||² ≤ ε²
  # Expanding: ||q - P0||² + 2t⟨q - P0, d⟩ + t²||d||² ≤ ε²

  diff <- q_current - P0
  a <- sum(direction^2)  # Should be 1 since direction is normalized
  b <- 2 * sum(diff * direction)
  c <- sum(diff^2) - epsilon^2

  # Solve at² + bt + c = 0
  discriminant <- b^2 - 4*a*c

  if (discriminant < 0) {
    return(list(t_min = 0, t_max = 0))
  }

  t_roots <- c((-b - sqrt(discriminant))/(2*a),
               (-b + sqrt(discriminant))/(2*a))
  t_min_l2 <- min(t_roots)
  t_max_l2 <- max(t_roots)

  return(list(t_min = max(t_min, t_min_l2), t_max = min(t_max, t_max_l2)))
}

# ============================================================================
# Generic Hit-and-Run for Different Geometries
# ============================================================================

#' Hit-and-run for general f-divergence balls
#'
#' @param P0 Baseline distribution
#' @param epsilon Ball radius (in divergence units)
#' @param distance_fn Function to compute distance/divergence
#' @param range_fn Function to find feasible range
#' @param n_samples Number of samples
#' @param burn_in Burn-in iterations
#' @param thin Thinning interval
#' @param verbose Print progress
hit_and_run_general <- function(
  P0,
  epsilon,
  distance_fn,
  range_fn,
  n_samples = 1000,
  burn_in = 1000,
  thin = 10,
  verbose = TRUE
) {

  K <- length(P0)

  # Validate starting point
  if (distance_fn(P0, P0) > epsilon + 1e-6) {
    stop("P0 is not in the ball!")
  }

  q_current <- P0
  samples <- matrix(NA, nrow = n_samples, ncol = K)

  total_iterations <- burn_in + n_samples * thin
  sample_idx <- 1
  accept_count <- 0

  if (verbose) {
    cat(sprintf("Hit-and-run sampling: %d iterations\n", total_iterations))
  }

  for (iter in 1:total_iterations) {

    if (verbose && iter %% 1000 == 0) {
      cat(sprintf("  Iteration %d / %d\n", iter, total_iterations))
    }

    # Sample direction
    direction <- sample_simplex_direction(K)

    # Find feasible range
    range <- range_fn(q_current, direction, P0, epsilon)

    # Sample on segment
    if (range$t_max - range$t_min < 1e-10) {
      t_step <- 0
    } else {
      t_step <- runif(1, range$t_min, range$t_max)
    }

    # Move
    q_new <- q_current + t_step * direction

    # Validate (should always be satisfied)
    if (any(q_new < -1e-10)) {
      warning(sprintf("Iter %d: Negative probability", iter))
      next
    }

    if (abs(sum(q_new) - 1) > 1e-6) {
      q_new <- q_new / sum(q_new)
    }

    dist_new <- distance_fn(q_new, P0)
    if (dist_new > epsilon + 1e-6) {
      warning(sprintf("Iter %d: Outside ball (dist: %.6f, epsilon: %.6f)",
                     iter, dist_new, epsilon))
      next
    }

    q_current <- q_new
    accept_count <- accept_count + 1

    # Store sample
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

# ============================================================================
# Convenience Wrappers
# ============================================================================

#' Hit-and-run for KL divergence ball
hit_and_run_kl_ball <- function(P0, epsilon, n_samples = 1000,
                                burn_in = 1000, thin = 10, verbose = TRUE) {
  hit_and_run_general(P0, epsilon, kl_divergence,
                     find_feasible_range_kl,
                     n_samples, burn_in, thin, verbose)
}

#' Hit-and-run for chi-squared ball
hit_and_run_chi2_ball <- function(P0, epsilon, n_samples = 1000,
                                  burn_in = 1000, thin = 10, verbose = TRUE) {
  hit_and_run_general(P0, epsilon, chi_squared_divergence,
                     find_feasible_range_chi2,
                     n_samples, burn_in, thin, verbose)
}

#' Hit-and-run for L2 ball
hit_and_run_l2_ball <- function(P0, epsilon, n_samples = 1000,
                               burn_in = 1000, thin = 10, verbose = TRUE) {
  hit_and_run_general(P0, epsilon, l2_distance,
                     find_feasible_range_l2,
                     n_samples, burn_in, thin, verbose)
}

# ============================================================================
# Comparison Across Geometries
# ============================================================================

#' Compare geometries for same "size"
#'
#' Match balls by choosing epsilon values that give similar volumes
#'
#' @param K dimension
#' @param size_measure How to match: "volume" or "radius_from_center"
compare_geometries <- function(K = 10, size_measure = "volume") {

  cat("Comparing Different Local Geometries\n")
  cat("=====================================\n\n")

  P0 <- rep(1/K, K)

  # For fair comparison, we want balls of similar "size"
  # Let's use epsilon values that give approximately same empirical spread

  # Reference: TV ball with λ = 0.3
  epsilon_tv <- 0.3

  # Heuristic calibrations (these would need tuning)
  epsilon_kl <- 0.1    # KL divergence grows faster
  epsilon_chi2 <- 0.3  # Similar scale to TV
  epsilon_l2 <- 0.2    # Euclidean distance

  geometries <- list(
    list(name = "TV",
         epsilon = epsilon_tv,
         sampler = function() hit_and_run_tv_ball(P0, epsilon_tv, 1000, 500, 5, FALSE),
         distance = tv_distance),

    list(name = "KL",
         epsilon = epsilon_kl,
         sampler = function() hit_and_run_kl_ball(P0, epsilon_kl, 1000, 500, 5, FALSE),
         distance = kl_divergence),

    list(name = "Chi-squared",
         epsilon = epsilon_chi2,
         sampler = function() hit_and_run_chi2_ball(P0, epsilon_chi2, 1000, 500, 5, FALSE),
         distance = chi_squared_divergence),

    list(name = "L2",
         epsilon = epsilon_l2,
         sampler = function() hit_and_run_l2_ball(P0, epsilon_l2, 1000, 500, 5, FALSE),
         distance = l2_distance)
  )

  results_list <- list()

  for (geom in geometries) {
    cat(sprintf("\nSampling from %s ball (ε = %.2f)...\n", geom$name, geom$epsilon))

    samples <- geom$sampler()

    # Compute distances to P0
    distances <- apply(samples, 1, geom$distance, P0 = P0)

    # Spread measures
    mean_dist <- mean(distances)
    sd_dist <- sd(distances)
    max_dist <- max(distances)

    # Variance of Q
    var_Q <- apply(samples, 2, var)
    mean_var <- mean(var_Q)

    cat(sprintf("  Distance to P0: mean = %.4f, sd = %.4f, max = %.4f\n",
                mean_dist, sd_dist, max_dist))
    cat(sprintf("  Mean Var[Q_i]: %.4f\n", mean_var))

    results_list[[length(results_list) + 1]] <- tibble(
      geometry = geom$name,
      epsilon = geom$epsilon,
      mean_distance = mean_dist,
      sd_distance = sd_dist,
      max_distance = max_dist,
      mean_variance = mean_var
    )
  }

  results_df <- bind_rows(results_list)

  cat("\n=== Summary ===\n")
  print(results_df, n = Inf)

  return(results_df)
}

#' Test analytical correlation across geometries
#'
#' @param tau_S Type effects for S
#' @param tau_Y Type effects for Y
#' @param P0 Baseline
#' @param geometries List of geometry specifications
test_correlation_across_geometries <- function(
  tau_S,
  tau_Y,
  P0,
  geometries = NULL
) {

  K <- length(tau_S)

  cat("Testing Correlation Across Geometries\n")
  cat("======================================\n\n")
  cat(sprintf("Type-level correlation: %.4f\n\n", cor(tau_S, tau_Y)))

  if (is.null(geometries)) {
    # Default geometries with calibrated epsilon
    geometries <- list(
      list(name = "TV", epsilon = 0.3,
           sampler = function() hit_and_run_tv_ball(P0, 0.3, 1000, 500, 5, FALSE)),
      list(name = "KL", epsilon = 0.1,
           sampler = function() hit_and_run_kl_ball(P0, 0.1, 1000, 500, 5, FALSE)),
      list(name = "Chi2", epsilon = 0.3,
           sampler = function() hit_and_run_chi2_ball(P0, 0.3, 1000, 500, 5, FALSE)),
      list(name = "L2", epsilon = 0.2,
           sampler = function() hit_and_run_l2_ball(P0, 0.2, 1000, 500, 5, FALSE))
    )
  }

  results_list <- list()

  for (geom in geometries) {
    cat(sprintf("\n%s ball (ε = %.2f)\n", geom$name, geom$epsilon))

    # Sample
    Q_samples <- geom$sampler()

    # Compute treatment effects
    Delta_S <- Q_samples %*% tau_S
    Delta_Y <- Q_samples %*% tau_Y

    # Correlation
    cor_est <- cor(Delta_S, Delta_Y)

    cat(sprintf("  Correlation: %.4f\n", cor_est))
    cat(sprintf("  E[ΔS]: %.4f, SD[ΔS]: %.4f\n", mean(Delta_S), sd(Delta_S)))
    cat(sprintf("  E[ΔY]: %.4f, SD[ΔY]: %.4f\n", mean(Delta_Y), sd(Delta_Y)))

    results_list[[length(results_list) + 1]] <- tibble(
      geometry = geom$name,
      epsilon = geom$epsilon,
      correlation = cor_est,
      mean_Delta_S = mean(Delta_S),
      sd_Delta_S = sd(Delta_S),
      mean_Delta_Y = mean(Delta_Y),
      sd_Delta_Y = sd(Delta_Y)
    )
  }

  results_df <- bind_rows(results_list)

  cat("\n=== Summary ===\n")
  print(results_df, n = Inf)

  # Plot
  p <- ggplot(results_df, aes(x = geometry, y = correlation, fill = geometry)) +
    geom_col(alpha = 0.7) +
    geom_hline(yintercept = cor(tau_S, tau_Y), linetype = "dashed", color = "red") +
    labs(
      title = "Correlation Across Different Local Geometries",
      subtitle = sprintf("Red line: type-level correlation = %.3f", cor(tau_S, tau_Y)),
      x = "Geometry",
      y = "Across-study correlation"
    ) +
    theme_minimal() +
    theme(legend.position = "none")

  print(p)
  ggsave(
    "explorations/tv_ball_geometry/figures/geometry_comparison.pdf",
    p, width = 8, height = 5
  )

  invisible(results_df)
}

# ============================================================================
# Run Examples
# ============================================================================

if (interactive()) {
  # Test different geometries
  K <- 10
  P0 <- rep(1/K, K)

  set.seed(123)
  tau_S <- rnorm(K, 0.5, 0.3)
  tau_Y <- 0.7 * tau_S + sqrt(1 - 0.7^2) * rnorm(K, 0.3)

  # Compare geometries
  comparison <- compare_geometries(K = 10)

  # Test correlations
  cor_comparison <- test_correlation_across_geometries(tau_S, tau_Y, P0)
}
