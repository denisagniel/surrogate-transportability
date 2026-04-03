#!/usr/bin/env Rscript

#' TEST: Covariate-Based Innovations vs Independent Samples Ground Truth
#'
#' PROPER VALIDATION SETUP:
#'   - Ground truth: Generate NEW independent samples (fresh A, fresh ε)
#'   - Method: Use covariate-based innovations from ONE observed sample
#'
#' QUESTION: Does covariate-based method match independent samples?

library(dplyr)
library(tibble)
library(MCMCpack)

set.seed(20260324)

cat("================================================================\n")
cat("COVARIATE METHOD vs INDEPENDENT SAMPLES (Proper Validation)\n")
cat("================================================================\n\n")

# K=4 parameters
K <- 4
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)
lambda <- 0.3
n_baseline <- 1000
M <- 500

cat("VALIDATION SETUP:\n")
cat("  Ground truth: Generate NEW independent samples\n")
cat("               (fresh A ~ Bern(0.5), fresh ε ~ N(0, σ²))\n")
cat("  Method: Bootstrap from ONE observed sample\n")
cat("           (using covariate-based innovations)\n\n")

cat("Population: K=4, τ_S: %s, τ_Y: %s\n",
    paste(round(tau_s, 2), collapse=", "),
    paste(round(tau_y, 2), collapse=", "))
cat(sprintf("True correlation: %.3f\n\n", cor(tau_s, tau_y)))

#' Discretize covariates
discretize_covariates <- function(X, n_bins_per_covariate = 3) {
  if (is.vector(X)) X <- matrix(X, ncol = 1)
  n_covariates <- ncol(X)
  bin_assignments <- matrix(NA, nrow = nrow(X), ncol = n_covariates)

  for (j in 1:n_covariates) {
    unique_vals <- unique(X[, j])
    if (length(unique_vals) <= 2) {
      bin_assignments[, j] <- as.integer(factor(X[, j]))
    } else {
      breaks <- unique(quantile(X[, j], probs = seq(0, 1, length.out = n_bins_per_covariate + 1)))
      if (length(breaks) <= 2) {
        bin_assignments[, j] <- as.integer(cut(X[, j], breaks = 2, labels = FALSE))
      } else {
        bin_assignments[, j] <- cut(X[, j], breaks = breaks, labels = FALSE, include.lowest = TRUE)
      }
    }
  }

  bin_id <- apply(bin_assignments, 1, function(row) paste(row, collapse = "_"))
  as.integer(factor(bin_id))
}

#' Generate data with types defined by covariates
generate_data_with_covariates <- function(n, type_probs = rep(1/K, K)) {
  types <- sample(1:K, size = n, replace = TRUE, prob = type_probs)
  age <- numeric(n)
  risk_score <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]
    if (type_i == 1) {
      age[i] <- rnorm(1, 30, 5)
      risk_score[i] <- rnorm(1, 0.2, 0.1)
    } else if (type_i == 2) {
      age[i] <- rnorm(1, 45, 5)
      risk_score[i] <- rnorm(1, 0.4, 0.1)
    } else if (type_i == 3) {
      age[i] <- rnorm(1, 45, 5)
      risk_score[i] <- rnorm(1, 0.6, 0.1)
    } else {
      age[i] <- rnorm(1, 65, 5)
      risk_score[i] <- rnorm(1, 0.8, 0.1)
    }
  }

  age <- pmax(18, pmin(age, 80))
  risk_score <- pmax(0, pmin(risk_score, 1))
  A <- rbinom(n, 1, 0.5)
  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]
    S[i] <- A[i] * tau_s[type_i] + rnorm(1, 0, 0.2)
    Y[i] <- A[i] * tau_y[type_i] + rnorm(1, 0, 0.2)
  }

  tibble(type = types, age = age, risk_score = risk_score, A = A, S = S, Y = Y)
}

cat("================================================================\n")
cat("GROUND TRUTH: Independent Samples\n")
cat("================================================================\n\n")

cat("Generating %d NEW independent samples...\n", M)
cat("  Each sample: n=%d with fresh A and ε\n\n", n_baseline)

# Type-level innovations for ground truth
type_innovations <- rdirichlet(M, rep(1, K))

effects_independent <- matrix(NA, M, 2)

for (m in 1:M) {
  # Type proportions for this innovation
  type_weights_m <- type_innovations[m, ]
  p0_type <- rep(1/K, K)
  q_m_type <- (1 - lambda) * p0_type + lambda * type_weights_m

  # Generate NEW independent sample
  new_sample <- generate_data_with_covariates(n_baseline, type_probs = q_m_type)

  # Compute treatment effects
  delta_s <- mean(new_sample$S[new_sample$A == 1]) - mean(new_sample$S[new_sample$A == 0])
  delta_y <- mean(new_sample$Y[new_sample$A == 1]) - mean(new_sample$Y[new_sample$A == 0])

  effects_independent[m, ] <- c(delta_s, delta_y)
}

corr_independent <- cor(effects_independent[, 1], effects_independent[, 2])

cat("GROUND TRUTH (Independent Samples):\n")
cat(sprintf("  Correlation: %.3f\n", corr_independent))
cat(sprintf("  SD(ΔS): %.4f, SD(ΔY): %.4f\n\n",
            sd(effects_independent[, 1]), sd(effects_independent[, 2])))

cat("================================================================\n")
cat("METHOD 1: Covariate-Level Bootstrap (Standard)\n")
cat("================================================================\n\n")

# Generate ONE baseline sample
baseline <- generate_data_with_covariates(n_baseline, type_probs = rep(1/K, K))

cat("ONE observed baseline sample:\n")
cat(sprintf("  n=%d, types: %s\n\n", nrow(baseline),
            paste(round(table(baseline$type) / nrow(baseline), 3), collapse=", ")))

# Discretize covariates
X <- as.matrix(baseline[, c("age", "risk_score")])
covariate_bins <- discretize_covariates(X, n_bins_per_covariate = 3)
J <- length(unique(covariate_bins))

cat(sprintf("Covariate bins: J=%d\n\n", J))

# Covariate-level innovations
cov_innovations <- rdirichlet(M, rep(1, J))

effects_cov_standard <- matrix(NA, M, 2)

for (m in 1:M) {
  cov_weights_m <- cov_innovations[m, ]
  p0_cov <- table(covariate_bins) / nrow(baseline)
  q_m_cov <- (1 - lambda) * p0_cov + lambda * cov_weights_m

  obs_weights <- q_m_cov[covariate_bins]
  obs_weights <- obs_weights / sum(obs_weights)

  # Standard bootstrap: resamples from observed data
  boot_idx <- sample(1:nrow(baseline), size = nrow(baseline), replace = TRUE, prob = obs_weights)
  boot_sample <- baseline[boot_idx, ]

  delta_s <- mean(boot_sample$S[boot_sample$A == 1]) - mean(boot_sample$S[boot_sample$A == 0])
  delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) - mean(boot_sample$Y[boot_sample$A == 0])

  effects_cov_standard[m, ] <- c(delta_s, delta_y)
}

corr_cov_standard <- cor(effects_cov_standard[, 1], effects_cov_standard[, 2])

cat("COVARIATE-LEVEL (Standard Bootstrap):\n")
cat(sprintf("  Correlation: %.3f (%.1f%% of ground truth)\n",
            corr_cov_standard, 100 * corr_cov_standard / corr_independent))
cat(sprintf("  SD(ΔS): %.4f, SD(ΔY): %.4f\n\n",
            sd(effects_cov_standard[, 1]), sd(effects_cov_standard[, 2])))

cat("================================================================\n")
cat("METHOD 2: Covariate-Level with Regenerated Randomness\n")
cat("================================================================\n\n")

cat("Testing: What if we regenerate A and ε in bootstrap?\n\n")

effects_cov_regen <- matrix(NA, M, 2)

for (m in 1:M) {
  cov_weights_m <- cov_innovations[m, ]
  p0_cov <- table(covariate_bins) / nrow(baseline)
  q_m_cov <- (1 - lambda) * p0_cov + lambda * cov_weights_m

  obs_weights <- q_m_cov[covariate_bins]
  obs_weights <- obs_weights / sum(obs_weights)

  # Bootstrap covariate bins, then regenerate A and outcomes
  boot_idx <- sample(1:nrow(baseline), size = nrow(baseline), replace = TRUE, prob = obs_weights)

  # Get sampled types and covariates
  sampled_types <- baseline$type[boot_idx]
  sampled_ages <- baseline$age[boot_idx]
  sampled_risks <- baseline$risk_score[boot_idx]

  # Regenerate treatment assignment
  A_new <- rbinom(nrow(baseline), 1, 0.5)

  # Regenerate outcomes with fresh noise
  S_new <- numeric(nrow(baseline))
  Y_new <- numeric(nrow(baseline))

  for (i in 1:nrow(baseline)) {
    type_i <- sampled_types[i]
    S_new[i] <- A_new[i] * tau_s[type_i] + rnorm(1, 0, 0.2)
    Y_new[i] <- A_new[i] * tau_y[type_i] + rnorm(1, 0, 0.2)
  }

  delta_s <- mean(S_new[A_new == 1]) - mean(S_new[A_new == 0])
  delta_y <- mean(Y_new[A_new == 1]) - mean(Y_new[A_new == 0])

  effects_cov_regen[m, ] <- c(delta_s, delta_y)
}

corr_cov_regen <- cor(effects_cov_regen[, 1], effects_cov_regen[, 2])

cat("COVARIATE-LEVEL (Regenerated A & ε):\n")
cat(sprintf("  Correlation: %.3f (%.1f%% of ground truth)\n",
            corr_cov_regen, 100 * corr_cov_regen / corr_independent))
cat(sprintf("  SD(ΔS): %.4f, SD(ΔY): %.4f\n\n",
            sd(effects_cov_regen[, 1]), sd(effects_cov_regen[, 2])))

cat("================================================================\n")
cat("COMPARISON\n")
cat("================================================================\n\n")

results <- tibble(
  Method = c(
    "Ground Truth (Independent)",
    "Covariate + Standard Bootstrap",
    "Covariate + Regenerated A&ε"
  ),
  Correlation = c(corr_independent, corr_cov_standard, corr_cov_regen),
  SD_delta_s = c(
    sd(effects_independent[, 1]),
    sd(effects_cov_standard[, 1]),
    sd(effects_cov_regen[, 1])
  ),
  Pct_of_truth = 100 * c(corr_independent, corr_cov_standard, corr_cov_regen) / corr_independent,
  SD_pct = 100 * c(
    sd(effects_independent[, 1]),
    sd(effects_cov_standard[, 1]),
    sd(effects_cov_regen[, 1])
  ) / sd(effects_independent[, 1])
)

print(results, width = 100)

cat("\n")
cat("KEY FINDINGS:\n\n")

cat("1. STANDARD COVARIATE BOOTSTRAP:\n")
cat(sprintf("   Recovers %.1f%% of ground truth correlation\n",
            100 * corr_cov_standard / corr_independent))
cat(sprintf("   Captures %.1f%% of variation (SD)\n\n",
            100 * sd(effects_cov_standard[, 1]) / sd(effects_independent[, 1])))

cat("2. COVARIATE + REGENERATED RANDOMNESS:\n")
cat(sprintf("   Recovers %.1f%% of ground truth correlation\n",
            100 * corr_cov_regen / corr_independent))
cat(sprintf("   Captures %.1f%% of variation (SD)\n\n",
            100 * sd(effects_cov_regen[, 1]) / sd(effects_independent[, 1])))

improvement <- (corr_cov_regen - corr_cov_standard) / (corr_independent - corr_cov_standard)
cat(sprintf("3. REGENERATING RANDOMNESS CLOSES %.1f%% OF REMAINING GAP\n\n",
            100 * improvement))

cat("================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

if (corr_cov_regen / corr_independent >= 0.9) {
  cat("✓✓✓ EXCELLENT: Covariate + regenerated randomness matches independent samples\n\n")
  cat("RECOMMENDATION:\n")
  cat("  Implement covariate-based innovations WITH randomness regeneration\n")
  cat("  This properly matches the 'independent samples' ground truth\n\n")

} else if (corr_cov_standard / corr_independent >= 0.8) {
  cat("✓✓ GOOD: Standard covariate bootstrap is sufficient\n\n")
  cat("RECOMMENDATION:\n")
  cat("  Standard covariate-based bootstrap captures most variation\n")
  cat("  Regenerating randomness provides marginal improvement\n\n")

} else {
  cat("⚠ PARTIAL SUCCESS: Covariate method captures substantial variation\n\n")
  cat("The gap between bootstrap and independent samples reflects:\n")
  cat("  - Fixed randomness in bootstrap (A and ε from one sample)\n")
  cat("  - Fresh randomness in independent samples (new A and ε)\n\n")
  cat("RECOMMENDATION:\n")
  cat("  Consider whether estimand should be:\n")
  cat("    (a) 'New samples from populations' → regenerate randomness\n")
  cat("    (b) 'Reweightings of observed population' → standard bootstrap\n\n")
}

cat("PRACTICAL IMPLICATIONS:\n\n")

cat("If using INDEPENDENT SAMPLES for validation:\n")
cat("  → Method should regenerate A and ε in bootstrap\n")
cat("  → This matches 'genuinely new populations' estimand\n")
cat("  → More variation, wider CIs\n\n")

cat("If using BOOTSTRAP RESAMPLING for validation:\n")
cat("  → Method uses standard bootstrap (resamples A and ε)\n")
cat("  → This matches 'reweighted population' estimand\n")
cat("  → Less variation, narrower CIs\n\n")

cat("YOUR CHOICE: Independent samples ground truth\n")
cat("  → Method should use: Covariate + regenerated randomness\n\n")

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
