#!/usr/bin/env Rscript

#' TV Ball Coverage Verification - QUICK TEST RUN
#'
#' Reduced parameters for fast verification (~5 min)

# Load package from source
devtools::load_all(quiet = TRUE)

library(dplyr)
library(tibble)
library(ggplot2)
library(purrr)

set.seed(20260407)

# REDUCED Parameters for testing
N_BASELINE <- 200           # Reduced from 500
N_REPLICATIONS <- 10        # Reduced from 100
N_TEST_POINTS <- 10         # Reduced from 50
M_SAMPLES <- c(50, 100)     # Reduced from c(50, 100, 200, 500, 1000)
EPSILON_REACH <- 0.05
ALPHA_DIRICHLET <- 1.0

# Test scenarios - keep all three
scenarios <- tibble::tibble(
  name = c("Small λ=0.1", "Moderate λ=0.3", "Large λ=0.5"),
  lambda = c(0.1, 0.3, 0.5)
)

# Functionals - keep all three
functionals <- list(
  correlation = list(name = "Correlation", type = "correlation"),
  ppv = list(name = "PPV (ε_s=0, ε_y=0)", type = "ppv",
             params = list(epsilon_s = 0, epsilon_y = 0)),
  concordance = list(name = "Concordance", type = "concordance")
)

cat("================================================================\n")
cat("TV BALL COVERAGE VERIFICATION - QUICK TEST RUN\n")
cat("================================================================\n\n")

cat("*** REDUCED PARAMETERS FOR TESTING ***\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d (reduced from 500)\n", N_BASELINE))
cat(sprintf("  Replications: %d (reduced from 100)\n", N_REPLICATIONS))
cat(sprintf("  Test points per scenario: %d (reduced from 50)\n", N_TEST_POINTS))
cat(sprintf("  M samples: %s (reduced set)\n", paste(M_SAMPLES, collapse = ", ")))
cat(sprintf("  Estimated time: ~5 minutes\n\n"))

cat(sprintf("Scenarios: %d\n", nrow(scenarios)))
cat(sprintf("Functionals: %d\n", length(functionals)))
cat("\n================================================================\n\n")

# Helper: Generate random valid distribution in TV ball
generate_random_in_tv_ball <- function(P0, lambda, n_points = 1) {
  results <- list()
  k <- length(P0)

  for (i in seq_len(n_points)) {
    direction <- MCMCpack::rdirichlet(1, rep(0.5, k))[1, ]
    max_shift <- lambda

    needs_scaling <- direction < P0
    if (any(needs_scaling)) {
      max_allowed_shift <- min(P0[needs_scaling] / (P0[needs_scaling] - direction[needs_scaling]))
      actual_shift <- min(max_shift, max_allowed_shift * 0.95)
    } else {
      actual_shift <- max_shift * 0.95
    }

    Q <- P0 + actual_shift * (direction - P0)
    Q <- Q / sum(Q)

    tv_dist <- compute_tv_distance(Q, P0)
    if (tv_dist > lambda * 1.01) {
      Q <- (1 - lambda/2) * P0 + (lambda/2) * direction
      Q <- Q / sum(Q)
    }

    results[[i]] <- Q
  }

  if (n_points == 1) {
    return(results[[1]])
  } else {
    return(results)
  }
}

# Helper: Compute functional value
compute_functional_value <- function(Q, P0, S_baseline, Y_baseline, X_baseline,
                                     functional_spec) {
  n_future <- length(S_baseline)
  types <- sample(seq_along(Q), size = n_future, replace = TRUE, prob = Q)

  S_future <- numeric(n_future)
  Y_future <- numeric(n_future)

  for (j in seq_along(types)) {
    sample_idx <- sample(seq_along(S_baseline), 1)
    S_future[j] <- S_baseline[sample_idx]
    Y_future[j] <- Y_baseline[sample_idx]
  }

  if (functional_spec$type == "correlation") {
    return(cor(S_future, Y_future))
  } else if (functional_spec$type == "ppv") {
    eps_s <- functional_spec$params$epsilon_s
    eps_y <- functional_spec$params$epsilon_y
    numer <- mean(S_future >= eps_s & Y_future >= eps_y)
    denom <- mean(S_future >= eps_s)
    return(ifelse(denom > 0, numer / denom, NA_real_))
  } else if (functional_spec$type == "concordance") {
    n <- length(S_future)
    concordant <- 0
    discordant <- 0
    for (i in seq_len(n-1)) {
      for (j in (i+1):n) {
        if (S_future[i] != S_future[j]) {
          if ((S_future[i] > S_future[j] && Y_future[i] > Y_future[j]) ||
              (S_future[i] < S_future[j] && Y_future[i] < Y_future[j])) {
            concordant <- concordant + 1
          } else {
            discordant <- discordant + 1
          }
        }
      }
    }
    return(ifelse(concordant + discordant > 0,
                  concordant / (concordant + discordant),
                  NA_real_))
  } else {
    stop("Unknown functional type: ", functional_spec$type)
  }
}

# Main simulation
results_all <- list()
start_time <- Sys.time()

for (scenario_idx in seq_len(nrow(scenarios))) {
  scenario <- scenarios[scenario_idx, ]
  lambda <- scenario$lambda

  cat(sprintf("\n================================================================\n"))
  cat(sprintf("SCENARIO: %s (λ = %.2f)\n", scenario$name, lambda))
  cat(sprintf("================================================================\n\n"))

  for (func_name in names(functionals)) {
    func_spec <- functionals[[func_name]]

    cat(sprintf("Testing functional: %s\n", func_spec$name))

    for (rep in seq_len(N_REPLICATIONS)) {
      if (rep %% 5 == 0) {
        cat(sprintf("  Replication %d/%d\n", rep, N_REPLICATIONS))
      }

      # Generate baseline data
      library(MASS)
      Sigma <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
      data_baseline <- MASS::mvrnorm(N_BASELINE, mu = c(0, 0), Sigma = Sigma)
      S_baseline <- data_baseline[, 1]
      Y_baseline <- data_baseline[, 2]
      X_baseline <- NULL

      # Compute baseline P₀
      n_types <- 10
      S_bins <- cut(S_baseline, breaks = n_types, labels = FALSE)
      P0 <- table(S_bins) / N_BASELINE
      P0 <- as.numeric(P0)
      P0 <- pmax(P0, 1e-6)
      P0 <- P0 / sum(P0)

      # Generate test points
      test_points <- generate_random_in_tv_ball(P0, lambda, N_TEST_POINTS)

      # Compute empirical infimum
      test_values <- numeric(N_TEST_POINTS)
      for (i in seq_len(N_TEST_POINTS)) {
        test_values[i] <- compute_functional_value(
          Q = test_points[[i]],
          P0 = P0,
          S_baseline = S_baseline,
          Y_baseline = Y_baseline,
          X_baseline = X_baseline,
          functional_spec = func_spec
        )
      }
      empirical_inf <- min(test_values, na.rm = TRUE)

      # Test each M
      for (M in M_SAMPLES) {
        # Generate M samples
        Q_samples <- list()
        for (m in seq_len(M)) {
          P_tilde <- MCMCpack::rdirichlet(1, rep(ALPHA_DIRICHLET, length(P0)))[1, ]
          Q_samples[[m]] <- (1 - lambda) * P0 + lambda * P_tilde
        }

        # Compute φ(Q_m)
        phi_values <- numeric(M)
        for (m in seq_len(M)) {
          phi_values[m] <- compute_functional_value(
            Q = Q_samples[[m]],
            P0 = P0,
            S_baseline = S_baseline,
            Y_baseline = Y_baseline,
            X_baseline = X_baseline,
            functional_spec = func_spec
          )
        }

        min_phi <- min(phi_values, na.rm = TRUE)

        # Compute reachability
        reachability_count <- 0
        for (i in seq_len(N_TEST_POINTS)) {
          Q_target <- test_points[[i]]
          min_dist <- Inf
          for (m in seq_len(M)) {
            dist <- compute_tv_distance(Q_samples[[m]], Q_target)
            min_dist <- min(min_dist, dist)
          }
          if (min_dist < EPSILON_REACH) {
            reachability_count <- reachability_count + 1
          }
        }
        reachability <- reachability_count / N_TEST_POINTS

        # Compute gap
        gap <- min_phi - empirical_inf

        # Store results
        results_all[[length(results_all) + 1]] <- tibble::tibble(
          scenario = scenario$name,
          lambda = lambda,
          functional = func_name,
          functional_name = func_spec$name,
          replication = rep,
          M = M,
          min_phi = min_phi,
          empirical_inf = empirical_inf,
          gap = gap,
          reachability = reachability
        )
      }
    }

    cat(sprintf("  Completed %d replications\n\n", N_REPLICATIONS))
  }
}

elapsed_time <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
cat(sprintf("\nTotal elapsed time: %.2f minutes\n\n", elapsed_time))

# Combine results
results_df <- bind_rows(results_all)

# Save results
if (!dir.exists("sims/results")) {
  dir.create("sims/results", recursive = TRUE)
}
saveRDS(results_df, "sims/results/29_tv_ball_coverage_TEST_results.rds")
cat("Results saved to: sims/results/29_tv_ball_coverage_TEST_results.rds\n\n")

# Summarize
cat("================================================================\n")
cat("QUICK TEST SUMMARY\n")
cat("================================================================\n\n")

summary_stats <- results_df %>%
  group_by(scenario, lambda, functional_name, M) %>%
  summarise(
    mean_min_phi = mean(min_phi, na.rm = TRUE),
    mean_gap = mean(gap, na.rm = TRUE),
    mean_reachability = mean(reachability, na.rm = TRUE),
    sd_reachability = sd(reachability, na.rm = TRUE),
    .groups = "drop"
  )

print(summary_stats)

cat("\n================================================================\n")
cat("KEY PATTERNS (Quick Test)\n")
cat("================================================================\n\n")

for (scenario_name in unique(summary_stats$scenario)) {
  for (func in unique(summary_stats$functional_name)) {
    sub <- summary_stats %>%
      filter(scenario == scenario_name, functional_name == func) %>%
      arrange(M)

    if (nrow(sub) >= 2) {
      reach_low <- sub$mean_reachability[1]
      reach_high <- sub$mean_reachability[nrow(sub)]

      cat(sprintf("%s, %s:\n", scenario_name, func))
      cat(sprintf("  Reachability at M=%d: %.1f%%\n", sub$M[1], reach_low * 100))
      cat(sprintf("  Reachability at M=%d: %.1f%%\n", sub$M[nrow(sub)], reach_high * 100))
      cat(sprintf("  Change: %+.1f pp\n\n", (reach_high - reach_low) * 100))
    }
  }
}

cat("================================================================\n")
cat("TEST RUN COMPLETE\n")
cat("================================================================\n\n")

cat("Next steps:\n")
cat("  1. Review summary statistics above\n")
cat("  2. If patterns look reasonable, run full simulation\n")
cat("  3. Full run: sims/scripts/29_tv_ball_coverage_verification.R\n")
cat("  4. Estimated full run time: ~60 minutes\n\n")
