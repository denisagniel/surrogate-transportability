test_that("Dirichlet innovation mechanism satisfies TV constraint", {
  # Test that Q = (1-λ)P0 + λP̃ with P̃ ~ Dirichlet satisfies TV(Q, P0) ≤ λ
  # This verifies the theoretical property used in Theorem 5

  set.seed(20260407)
  P0 <- c(0.3, 0.5, 0.2)

  # Test multiple λ values
  lambda_values <- c(0.1, 0.3, 0.5, 0.7, 0.9)

  for (lambda in lambda_values) {
    # Generate multiple samples
    n_samples <- 100

    for (i in seq_len(n_samples)) {
      # Generate Dirichlet innovation
      P_tilde <- MCMCpack::rdirichlet(1, rep(1, length(P0)))[1, ]

      # Form innovation mechanism output
      Q <- (1 - lambda) * P0 + lambda * P_tilde

      # Verify TV constraint
      result <- verify_tv_constraint(Q, P0, lambda)

      expect_true(result$satisfies_constraint,
                  label = sprintf("TV constraint for λ=%.2f, sample %d", lambda, i))
      expect_lte(result$tv_distance, lambda + 1e-10,
                 label = sprintf("TV distance for λ=%.2f, sample %d", lambda, i))
    }
  }
})


test_that("Dirichlet innovations with different concentrations satisfy TV constraint", {
  # Test various Dirichlet concentration parameters
  set.seed(20260408)
  P0 <- c(0.25, 0.25, 0.25, 0.25)
  lambda <- 0.4

  # Test different concentration parameters
  alpha_values <- c(0.1, 0.5, 1.0, 2.0, 10.0)

  for (alpha in alpha_values) {
    n_samples <- 50

    for (i in seq_len(n_samples)) {
      # Generate Dirichlet innovation with concentration α
      P_tilde <- MCMCpack::rdirichlet(1, rep(alpha, length(P0)))[1, ]

      # Form innovation mechanism output
      Q <- (1 - lambda) * P0 + lambda * P_tilde

      # Verify TV constraint
      result <- verify_tv_constraint(Q, P0, lambda)

      expect_true(result$satisfies_constraint,
                  label = sprintf("TV constraint for α=%.2f, sample %d", alpha, i))
    }
  }
})


test_that("Coverage of test points increases with M samples", {
  # Empirical verification of Theorem 5(b): density of coverage
  # As M increases, we should be able to get closer to arbitrary test points

  set.seed(20260409)
  P0 <- c(0.3, 0.5, 0.2)
  lambda <- 0.3

  # Generate a fixed test point in TV ball
  # Use a point that's not trivial (not P0, not on boundary)
  P_target_direction <- c(0.5, 0.3, 0.2)
  Q_target <- 0.7 * P0 + 0.3 * P_target_direction
  Q_target <- Q_target / sum(Q_target)

  # Verify test point is in TV ball
  tv_test <- compute_tv_distance(Q_target, P0)
  expect_lte(tv_test, lambda)

  # Test with increasing M
  M_values <- c(10, 50, 100, 500)
  min_distances <- numeric(length(M_values))

  for (idx in seq_along(M_values)) {
    M <- M_values[idx]

    # Generate M samples from innovation mechanism
    distances <- numeric(M)
    for (m in seq_len(M)) {
      P_tilde <- MCMCpack::rdirichlet(1, rep(1, length(P0)))[1, ]
      Q <- (1 - lambda) * P0 + lambda * P_tilde

      # Distance to target
      distances[m] <- compute_tv_distance(Q, Q_target)
    }

    min_distances[idx] <- min(distances)
  }

  # Verify: minimum distance should decrease as M increases
  # (we get closer to the target with more samples)
  for (i in seq_len(length(M_values) - 1)) {
    expect_lte(min_distances[i + 1], min_distances[i] * 1.5,
               label = sprintf("Distance should decrease from M=%d to M=%d",
                              M_values[i], M_values[i + 1]))
  }

  # At M=500, we should be reasonably close
  expect_lt(min_distances[length(M_values)], 0.1,
            label = "Should get within 0.1 TV distance at M=500")
})


test_that("Minimum functional value decreases with M samples", {
  # Empirical verification of Theorem 5(c): convergence to infimum
  # As M increases, min φ(Q_m) should approach inf φ(Q)

  set.seed(20260410)
  P0 <- c(0.3, 0.5, 0.2)
  lambda <- 0.3

  # Simple functional: sum of squared differences from uniform
  phi <- function(Q) {
    uniform <- rep(1/length(Q), length(Q))
    sum((Q - uniform)^2)
  }

  # Compute functional at P0 as baseline
  phi_P0 <- phi(P0)

  # Test with increasing M
  M_values <- c(10, 50, 100, 500, 1000)
  min_phi_values <- numeric(length(M_values))

  for (idx in seq_along(M_values)) {
    M <- M_values[idx]

    # Generate M samples and compute minimum
    phi_values <- numeric(M)
    for (m in seq_len(M)) {
      P_tilde <- MCMCpack::rdirichlet(1, rep(1, length(P0)))[1, ]
      Q <- (1 - lambda) * P0 + lambda * P_tilde
      phi_values[m] <- phi(Q)
    }

    min_phi_values[idx] <- min(phi_values)
  }

  # Verify: minimum should be non-increasing
  for (i in seq_len(length(M_values) - 1)) {
    expect_lte(min_phi_values[i + 1], min_phi_values[i] + 0.01,
               label = sprintf("Minimum should not increase from M=%d to M=%d",
                              M_values[i], M_values[i + 1]))
  }

  # The minimum at large M should be less than at small M
  expect_lt(min_phi_values[length(M_values)], min_phi_values[1],
            label = "Minimum at M=1000 should be less than at M=10")
})


test_that("Innovation mechanism explores diverse distributions", {
  # Verify that the mechanism generates diverse Q values (not all the same)

  set.seed(20260411)
  P0 <- c(0.3, 0.5, 0.2)
  lambda <- 0.4
  M <- 100

  # Generate M samples
  Q_samples <- matrix(0, nrow = M, ncol = length(P0))
  for (m in seq_len(M)) {
    P_tilde <- MCMCpack::rdirichlet(1, rep(1, length(P0)))[1, ]
    Q_samples[m, ] <- (1 - lambda) * P0 + lambda * P_tilde
  }

  # Compute pairwise TV distances
  # Should see substantial variation
  distances <- numeric(0)
  for (i in 1:(M-1)) {
    for (j in (i+1):M) {
      if (length(distances) < 1000) {  # Don't compute all pairs for speed
        d <- compute_tv_distance(Q_samples[i, ], Q_samples[j, ])
        distances <- c(distances, d)
      }
    }
  }

  # Verify diversity: mean pairwise distance should be meaningful
  mean_dist <- mean(distances)
  expect_gt(mean_dist, 0.01,
            label = "Mean pairwise distance should show diversity")

  # Verify some samples are close to P0, others are far
  distances_to_P0 <- apply(Q_samples, 1, function(Q) compute_tv_distance(Q, P0))
  expect_lt(min(distances_to_P0), 0.2,
            label = "Some samples should be close to P0")
  expect_gt(max(distances_to_P0), 0.25,
            label = "Some samples should be far from P0")
  # Note: max possible is λ = 0.4, so expect at least 0.25 with M=100
})


test_that("Constructive algorithm from generate_tv_ball_point matches innovation mechanism", {
  # Integration test: verify that the constructive algorithm (Part a of Theorem 5)
  # produces valid outputs that could have come from the innovation mechanism

  set.seed(20260412)
  P0 <- c(0.3, 0.5, 0.2)
  lambda <- 0.4

  # Generate several Q values from innovation mechanism
  n_tests <- 20
  for (i in seq_len(n_tests)) {
    # Generate Q from innovation mechanism
    P_tilde_original <- MCMCpack::rdirichlet(1, rep(1, length(P0)))[1, ]
    Q <- (1 - lambda) * P0 + lambda * P_tilde_original

    # Use constructive algorithm to recover (λ', P̃')
    result <- generate_tv_ball_point(P0, Q, lambda_max = lambda)

    # Verify algorithm succeeded
    expect_true(result$algorithm_successful,
                label = sprintf("Algorithm should succeed for test %d", i))
    expect_true(result$satisfies_constraint,
                label = sprintf("Constraint should be satisfied for test %d", i))

    # Verify reconstruction is accurate
    expect_lt(result$reconstruction_error, 1e-9,
              label = sprintf("Reconstruction error for test %d", i))

    # Verify λ' ≤ λ
    expect_lte(result$lambda_actual, lambda + 1e-10,
               label = sprintf("λ_actual should be ≤ λ for test %d", i))

    # Verify P̃' is a valid distribution
    expect_true(all(result$P_tilde >= -1e-10),
                label = sprintf("P̃ should be non-negative for test %d", i))
    expect_equal(sum(result$P_tilde), 1, tolerance = 1e-10,
                 label = sprintf("P̃ should sum to 1 for test %d", i))
  }
})
