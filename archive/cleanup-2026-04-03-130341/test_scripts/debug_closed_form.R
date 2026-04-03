#!/usr/bin/env Rscript
# Debug script to isolate closed-form bug

library(tidyverse)
library(here)
library(MCMCpack)

# Load package
devtools::load_all(here("package"))

# Generate simple test case
set.seed(12345)
J <- 4
n <- 200
lambda <- 0.4

# Generate true type structure
type_probs <- c(0.4, 0.3, 0.2, 0.1)
true_types <- sample(1:J, n, replace = TRUE, prob = type_probs)

# Generate treatment assignment
A <- rbinom(n, 1, 0.5)

# True type-level treatment effects (tau_s, tau_y)
# Make type 1 have high concordance, type 4 have low/negative concordance
true_tau_s <- c(0.8, 0.5, 0.3, 0.2)
true_tau_y <- c(0.7, 0.4, 0.2, -0.3)

# Generate S, Y based on types
S <- numeric(n)
Y <- numeric(n)

for (j in 1:J) {
  idx_type <- which(true_types == j)

  # Treated
  idx_treated <- idx_type[A[idx_type] == 1]
  S[idx_treated] <- rnorm(length(idx_treated), mean = 0.5 + true_tau_s[j], sd = 0.3)
  Y[idx_treated] <- rnorm(length(idx_treated), mean = 0.5 + true_tau_y[j], sd = 0.3)

  # Control
  idx_control <- idx_type[A[idx_type] == 0]
  S[idx_control] <- rnorm(length(idx_control), mean = 0.5, sd = 0.3)
  Y[idx_control] <- rnorm(length(idx_control), mean = 0.5, sd = 0.3)
}

data <- tibble(A = A, S = S, Y = Y)

cat("==== TRUE PARAMETERS ====\n")
cat("Type probabilities:", round(type_probs, 3), "\n")
cat("True tau_s:", round(true_tau_s, 3), "\n")
cat("True tau_y:", round(true_tau_y, 3), "\n")
cat("True concordances:", round(true_tau_s * true_tau_y, 3), "\n")
cat("Min concordance:", round(min(true_tau_s * true_tau_y), 3), "\n\n")

# True minimax
true_concordance_p0 <- sum(type_probs * true_tau_s * true_tau_y)
true_min_concordance <- min(true_tau_s * true_tau_y)
true_minimax <- (1 - lambda) * true_concordance_p0 + lambda * true_min_concordance

cat("True E_P0[conc]:", round(true_concordance_p0, 4), "\n")
cat("True min conc:", round(true_min_concordance, 4), "\n")
cat("True minimax:", round(true_minimax, 4), "\n\n")

cat("==== ESTIMATED PARAMETERS ====\n")

# Compute estimated type-level effects
type_stats <- compute_type_level_effects(data, true_types)

cat("Estimated type probs:", round(type_stats$p0, 3), "\n")
cat("Estimated tau_s:", round(type_stats$tau_s, 3), "\n")
cat("Estimated tau_y:", round(type_stats$tau_y, 3), "\n")
cat("Estimated concordances:", round(type_stats$tau_s * type_stats$tau_y, 3), "\n\n")

# ===== METHOD 1: CLOSED-FORM (CURRENT) =====
cat("==== METHOD 1: CLOSED-FORM ====\n")

concordance_p0 <- sum(type_stats$p0 * type_stats$tau_s * type_stats$tau_y)
concordances <- type_stats$tau_s * type_stats$tau_y
min_concordance <- min(concordances)

phi_closed <- (1 - lambda) * concordance_p0 + lambda * min_concordance

cat("E_P0[conc] =", round(concordance_p0, 4), "\n")
cat("min conc =", round(min_concordance, 4), "\n")
cat("Closed-form estimate:", round(phi_closed, 4), "\n")
cat("Error vs truth:", round(phi_closed - true_minimax, 4), "\n\n")

# ===== METHOD 2: SAMPLING (DIAGNOSTIC 4) =====
cat("==== METHOD 2: SAMPLING (5000 innovations) ====\n")

M <- 5000
innovations <- MCMCpack::rdirichlet(M, rep(1, type_stats$J))

concordances_sampling <- numeric(M)
for (m in 1:M) {
  # Type-level mixture weights
  q_m <- (1 - lambda) * type_stats$p0 + lambda * innovations[m, ]

  # Concordance under Q_m
  concordances_sampling[m] <- sum(q_m * type_stats$tau_s * type_stats$tau_y)
}

phi_sampling <- min(concordances_sampling)

cat("Sampling estimate:", round(phi_sampling, 4), "\n")
cat("Error vs truth:", round(phi_sampling - true_minimax, 4), "\n\n")

# ===== ANALYSIS =====
cat("==== ANALYSIS ====\n")
cat("Closed-form error:", round(phi_closed - true_minimax, 4), "\n")
cat("Sampling error:", round(phi_sampling - true_minimax, 4), "\n")
cat("Difference (closed - sampling):", round(phi_closed - phi_sampling, 4), "\n\n")

# Check: What does the closed-form ASSUME the minimax innovation is?
cat("==== WHAT THE CLOSED-FORM ASSUMES ====\n")
cat("The closed-form assumes the adversary puts ALL innovation mass on type", which.min(concordances), "\n")
cat("With concordance:", round(min_concordance, 4), "\n\n")

# Check: What does the sampling FIND?
min_idx <- which.min(concordances_sampling)
cat("==== WHAT SAMPLING FOUND ====\n")
cat("Best innovation (lowest concordance):\n")
print(round(innovations[min_idx, ], 3))
cat("Resulting mixture Q:\n")
q_best <- (1 - lambda) * type_stats$p0 + lambda * innovations[min_idx, ]
print(round(q_best, 3))
cat("Concordance under this Q:", round(concordances_sampling[min_idx], 4), "\n\n")

# HYPOTHESIS: Maybe the closed-form should use Q weights, not just P0 and min?
cat("==== TESTING HYPOTHESIS ====\n")
cat("What if we compute concordance under Q* (point mass at min type)?\n")
p_tilde_pointmass <- rep(0, type_stats$J)
p_tilde_pointmass[which.min(concordances)] <- 1
q_star <- (1 - lambda) * type_stats$p0 + lambda * p_tilde_pointmass

concordance_q_star <- sum(q_star * type_stats$tau_s * type_stats$tau_y)
cat("Concordance under Q* (point mass):", round(concordance_q_star, 4), "\n")
cat("This should equal closed-form:", round(phi_closed, 4), "\n")
cat("Match?", abs(concordance_q_star - phi_closed) < 1e-10, "\n\n")

cat("==== VERDICT ====\n")
if (abs(phi_closed - phi_sampling) > 0.01) {
  cat("BUG CONFIRMED: Closed-form does NOT match sampling\n")
  cat("Closed-form gives:", round(phi_closed, 4), "\n")
  cat("Sampling gives:", round(phi_sampling, 4), "\n")
  cat("Difference:", round(phi_closed - phi_sampling, 4), "\n")
} else {
  cat("No bug detected in this test case\n")
}
