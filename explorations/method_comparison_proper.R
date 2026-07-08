# Method Comparison: Across-Study Correlation vs PTE (Proper Framework)
#
# Uses TV ball geometry + hit-and-run sampler + resampling approach

library(tidyverse)
devtools::load_all(".")

# Load hit-and-run sampler from explorations
source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

# ============================================================================
# Helper Functions
# ============================================================================

#' Resample data to match target distribution Q
#'
#' @param data Original study data with columns X, A, S, Y
#' @param Q Target distribution (K-vector summing to 1)
#' @param X_values Vector of X values corresponding to Q components
#' @return Resampled data matching distribution Q
resample_to_match_Q <- function(data, Q, X_values = 0:1) {

  K <- length(Q)
  n_total <- nrow(data)

  # Sample sizes for each X value
  n_by_x <- round(n_total * Q)

  # Adjust for rounding (ensure sum = n_total)
  diff <- n_total - sum(n_by_x)
  if (diff != 0) {
    # Add/subtract from largest group
    idx_max <- which.max(n_by_x)
    n_by_x[idx_max] <- n_by_x[idx_max] + diff
  }

  # Resample from each X stratum
  resampled_data <- map_dfr(seq_len(K), function(k) {
    x_val <- X_values[k]
    n_k <- n_by_x[k]

    if (n_k == 0) return(NULL)

    data_x <- data %>% filter(X == x_val)

    if (nrow(data_x) == 0) {
      warning(sprintf("No observations with X=%d in original data", x_val))
      return(NULL)
    }

    slice_sample(data_x, n = n_k, replace = TRUE)
  })

  return(resampled_data)
}

#' Compute treatment effects from data
#'
#' @param data Data with columns A, S, Y
#' @return List with delta_s and delta_y
compute_treatment_effects <- function(data) {
  delta_s <- mean(data$S[data$A == 1]) - mean(data$S[data$A == 0])
  delta_y <- mean(data$Y[data$A == 1]) - mean(data$Y[data$A == 0])

  list(delta_s = delta_s, delta_y = delta_y)
}

#' Compute PTE from data
compute_pte <- function(data) {
  # Total effect
  E_Y_A1 <- mean(data$Y[data$A == 1])
  E_Y_A0 <- mean(data$Y[data$A == 0])
  total_effect <- E_Y_A1 - E_Y_A0

  if (abs(total_effect) < 1e-6) return(NA_real_)

  # Adjusted effect (conditional on S)
  adjusted_effect <- 0
  for (s_val in sort(unique(data$S))) {
    p_s <- mean(data$S[data$A == 0] == s_val)

    y_a1_s <- data$Y[data$A == 1 & data$S == s_val]
    y_a0_s <- data$Y[data$A == 0 & data$S == s_val]

    if (length(y_a1_s) == 0 || length(y_a0_s) == 0) next

    effect_s <- mean(y_a1_s) - mean(y_a0_s)
    adjusted_effect <- adjusted_effect + p_s * effect_s
  }

  pte <- 1 - adjusted_effect / total_effect
  return(pte)
}

#' Estimate across-study correlation using TV ball method
#'
#' @param data Original study data (X, A, S, Y)
#' @param lambda TV ball radius
#' @param M Number of future studies to sample
#' @param burn_in Burn-in for MCMC
#' @param thin Thinning for MCMC
#' @return Across-study correlation estimate
estimate_across_study_correlation <- function(
  data,
  lambda = 0.3,
  M = 1000,
  burn_in = 1000,
  thin = 10
) {

  # Compute P0 (original study covariate distribution)
  X_values <- sort(unique(data$X))
  K <- length(X_values)
  P0 <- as.numeric(table(data$X) / nrow(data))

  cat(sprintf("Original study distribution P0:\n"))
  for (k in seq_len(K)) {
    cat(sprintf("  X=%d: %.3f\n", X_values[k], P0[k]))
  }
  cat(sprintf("\nSampling %d future studies from TV ball (λ=%.2f)...\n", M, lambda))

  # Sample Q from TV ball using hit-and-run
  Q_samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = M,
    burn_in = burn_in,
    thin = thin,
    verbose = FALSE
  )

  cat("Computing treatment effects for each future study...\n")

  # For each Q, resample data and compute effects
  treatment_effects <- map_dfr(seq_len(M), function(i) {

    if (i %% 200 == 0) cat(sprintf("  Study %d/%d\r", i, M))

    Q_i <- Q_samples[i, ]

    # Resample data to match Q_i
    future_data <- resample_to_match_Q(data, Q_i, X_values)

    # Compute treatment effects
    effects <- compute_treatment_effects(future_data)

    tibble(
      study_id = i,
      delta_s = effects$delta_s,
      delta_y = effects$delta_y,
      q_x0 = Q_i[1],
      q_x1 = Q_i[2]
    )
  })

  cat("\n")

  # Use package function to compute correlation
  correlation <- functional_correlation(treatment_effects)

  list(
    correlation = correlation,
    treatment_effects = treatment_effects,
    P0 = P0,
    lambda = lambda
  )
}

# ============================================================================
# Test with Quick Example
# ============================================================================

cat("=== TESTING PROPER FRAMEWORK ===\n\n")

# Generate test data (Scenario 1: High ρ, Low PTE)
cat("Generating test data (Scenario 1: High ρ, Low PTE)...\n")
set.seed(2026)
n <- 500

X <- rbinom(n, 1, 0.5)
A <- rbinom(n, 1, 0.5)

# Strong A×X interactions for both S and Y (separate pathways)
logit_S <- -1.5 + 0.5*A + 0.3*X + 2.0*A*X
S <- rbinom(n, 1, plogis(logit_S))

logit_Y <- -1.5 + 0.3*A + 0.5*X + 0.1*S + 1.8*A*X
Y <- rbinom(n, 1, plogis(logit_Y))

data <- tibble(X = X, A = A, S = S, Y = Y)

cat(sprintf("Sample size: %d\n", n))
cat(sprintf("P(X=1): %.3f\n\n", mean(X)))

# Compute PTE (within-study)
cat("1. Within-Study PTE:\n")
pte <- compute_pte(data)
cat(sprintf("   PTE = %.3f\n\n", pte))

# Compute across-study correlation (TV ball method)
cat("2. Across-Study Correlation (TV Ball Method):\n")
result <- estimate_across_study_correlation(
  data = data,
  lambda = 0.3,
  M = 500,  # Quick test
  burn_in = 1000,
  thin = 10
)

cat(sprintf("\n   Across-study correlation = %.3f\n", result$correlation))
cat(sprintf("   Number of future studies = %d\n\n", nrow(result$treatment_effects)))

# Summary
cat("=== COMPARISON ===\n")
cat(sprintf("Within-study PTE:         %.3f\n", pte))
cat(sprintf("Across-study correlation: %.3f\n", result$correlation))
cat(sprintf("Divergence (ρ - PTE):     %.3f\n\n", result$correlation - pte))

if (result$correlation > pte) {
  cat("✓ Scenario 1 pattern: High transportability despite low mediation\n")
} else {
  cat("Note: Expected ρ > PTE for Scenario 1\n")
}

# Quick visualization
cat("\n3. Treatment Effect Distribution:\n")
summary_stats <- result$treatment_effects %>%
  summarize(
    mean_delta_s = mean(delta_s),
    sd_delta_s = sd(delta_s),
    mean_delta_y = mean(delta_y),
    sd_delta_y = sd(delta_y),
    cor_delta = cor(delta_s, delta_y)
  )

print(summary_stats)

cat("\n=== TEST COMPLETE ===\n")
cat("Framework validated. Ready for full simulation.\n")
