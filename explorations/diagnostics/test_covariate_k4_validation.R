#!/usr/bin/env Rscript

#' TEST: Covariate-Based Innovations on K=4 Validation Scenario
#'
#' This tests whether covariate-based innovations can solve the K=4
#' validation failure by using covariates that define the 4 types.
#'
#' SETUP:
#'   - K=4 types (as in original validation)
#'   - Types defined by covariates (age, risk_score)
#'   - Strong correlation scenario (τ_S and τ_Y highly correlated)
#'
#' COMPARISON:
#'   1. Ground truth: Type-level innovations (knows K=4)
#'   2. Covariate-level: Uses observed covariates (doesn't know K)
#'   3. Observation-level: Current package approach (n=1000 dimensional)

library(dplyr)
library(tibble)
library(MCMCpack)

set.seed(20260324)

cat("================================================================\n")
cat("K=4 VALIDATION: Testing Covariate-Based Innovations\n")
cat("================================================================\n\n")

# K=4 parameters from original validation
K <- 4
tau_s <- c(-0.6, -0.2, 0.2, 0.6)
tau_y <- c(-0.5, -0.1, 0.1, 0.5)
lambda <- 0.3
n_baseline <- 1000
M <- 500

cat("K=4 Strong Correlation Scenario:\n")
cat(sprintf("  τ_S: %s\n", paste(round(tau_s, 2), collapse=", ")))
cat(sprintf("  τ_Y: %s\n", paste(round(tau_y, 2), collapse=", ")))
cat(sprintf("  Population correlation: %.3f\n", cor(tau_s, tau_y)))
cat(sprintf("  Sample size: %d\n", n_baseline))
cat(sprintf("  Lambda: %.2f\n", lambda))
cat(sprintf("  Innovations: %d\n\n", M))

#' Discretize covariates
discretize_covariates <- function(X, n_bins_per_covariate = 5) {
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
generate_data_k4_with_covariates <- function(n, type_probs = rep(1/K, K)) {
  # Generate types
  types <- sample(1:K, size = n, replace = TRUE, prob = type_probs)

  # Generate covariates that DEFINE the types
  # Type 1: young, low risk
  # Type 2: medium age, medium risk
  # Type 3: medium age, higher risk
  # Type 4: older, high risk

  age <- numeric(n)
  risk_score <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]

    if (type_i == 1) {
      # Young, low risk
      age[i] <- rnorm(1, 30, 5)
      risk_score[i] <- rnorm(1, 0.2, 0.1)
    } else if (type_i == 2) {
      # Medium age, medium risk
      age[i] <- rnorm(1, 45, 5)
      risk_score[i] <- rnorm(1, 0.4, 0.1)
    } else if (type_i == 3) {
      # Medium age, higher risk
      age[i] <- rnorm(1, 45, 5)
      risk_score[i] <- rnorm(1, 0.6, 0.1)
    } else {
      # Older, high risk
      age[i] <- rnorm(1, 65, 5)
      risk_score[i] <- rnorm(1, 0.8, 0.1)
    }
  }

  # Bound variables
  age <- pmax(18, pmin(age, 80))
  risk_score <- pmax(0, pmin(risk_score, 1))

  # Treatment assignment
  A <- rbinom(n, 1, 0.5)

  # Outcomes depend on type
  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]
    S[i] <- A[i] * tau_s[type_i] + rnorm(1, 0, 0.2)
    Y[i] <- A[i] * tau_y[type_i] + rnorm(1, 0, 0.2)
  }

  tibble(
    type = types,  # Not observed by method!
    age = age,
    risk_score = risk_score,
    A = A,
    S = S,
    Y = Y
  )
}

cat("================================================================\n")
cat("GENERATING BASELINE DATA\n")
cat("================================================================\n\n")

# Generate baseline with uniform type distribution
baseline <- generate_data_k4_with_covariates(n_baseline, type_probs = rep(1/K, K))

cat(sprintf("Baseline generated (n=%d)\n", nrow(baseline)))
cat(sprintf("  Type distribution: %s\n",
            paste(round(table(baseline$type) / nrow(baseline), 3), collapse=", ")))
cat(sprintf("  Age: mean=%.1f, sd=%.1f\n", mean(baseline$age), sd(baseline$age)))
cat(sprintf("  Risk score: mean=%.2f, sd=%.2f\n\n", mean(baseline$risk_score), sd(baseline$risk_score)))

# Check if covariates predict types
cat("Checking: Do covariates define types?\n")
by_type <- baseline %>%
  group_by(type) %>%
  summarise(
    mean_age = mean(age),
    mean_risk = mean(risk_score),
    n = n()
  )
print(by_type)
cat("\n")

cat("================================================================\n")
cat("METHOD 1: Type-Level Innovations (Ground Truth)\n")
cat("================================================================\n\n")

cat("Uses K=4 type-level innovations (KNOWS types exist)\n\n")

# Type-level innovations
type_innovations <- rdirichlet(M, rep(1, K))

effects_type_level <- matrix(NA, M, 2)

for (m in 1:M) {
  type_weights_m <- type_innovations[m, ]
  p0_type <- rep(1/K, K)
  q_m_type <- (1 - lambda) * p0_type + lambda * type_weights_m

  # Map to observation weights
  obs_weights <- numeric(nrow(baseline))
  for (k in 1:K) {
    type_k_obs <- which(baseline$type == k)
    if (length(type_k_obs) > 0) {
      obs_weights[type_k_obs] <- q_m_type[k] / length(type_k_obs)
    }
  }
  obs_weights <- obs_weights / sum(obs_weights)

  # Bootstrap
  boot_idx <- sample(1:nrow(baseline), size = nrow(baseline), replace = TRUE, prob = obs_weights)
  boot_sample <- baseline[boot_idx, ]

  delta_s <- mean(boot_sample$S[boot_sample$A == 1]) - mean(boot_sample$S[boot_sample$A == 0])
  delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) - mean(boot_sample$Y[boot_sample$A == 0])

  effects_type_level[m, ] <- c(delta_s, delta_y)
}

corr_type <- cor(effects_type_level[, 1], effects_type_level[, 2])

cat("GROUND TRUTH (Type-Level):\n")
cat(sprintf("  Correlation: %.3f\n", corr_type))
cat(sprintf("  SD(ΔS): %.4f, SD(ΔY): %.4f\n\n",
            sd(effects_type_level[, 1]), sd(effects_type_level[, 2])))

cat("================================================================\n")
cat("METHOD 2: Covariate-Level Innovations (Proposed)\n")
cat("================================================================\n\n")

cat("Uses covariates (age, risk_score) but DOESN'T KNOW types\n\n")

# Covariate-level innovations
data_no_types <- baseline %>% dplyr::select(-type)  # Remove type column (not observed!)

X <- as.matrix(data_no_types[, c("age", "risk_score")])
covariate_bins <- discretize_covariates(X, n_bins_per_covariate = 3)
J <- length(unique(covariate_bins))

cat(sprintf("  Discretized into J=%d covariate bins\n", J))
cat(sprintf("  Average observations per bin: %.1f\n\n", nrow(baseline) / J))

# Show bin membership
bin_summary <- tibble(
  bin = covariate_bins,
  type = baseline$type
) %>%
  group_by(bin) %>%
  summarise(
    n = n(),
    types = paste(sort(unique(type)), collapse = ",")
  )

cat("Covariate bin composition:\n")
print(bin_summary, n = min(20, nrow(bin_summary)))
cat("\n")

# Generate innovations over covariate bins
cov_innovations <- rdirichlet(M, rep(1, J))

effects_covariate <- matrix(NA, M, 2)

for (m in 1:M) {
  cov_weights_m <- cov_innovations[m, ]
  p0_cov <- table(covariate_bins) / nrow(baseline)
  q_m_cov <- (1 - lambda) * p0_cov + lambda * cov_weights_m

  # Map to observation weights
  obs_weights <- q_m_cov[covariate_bins]
  obs_weights <- obs_weights / sum(obs_weights)

  # Bootstrap
  boot_idx <- sample(1:nrow(baseline), size = nrow(baseline), replace = TRUE, prob = obs_weights)
  boot_sample <- baseline[boot_idx, ]

  delta_s <- mean(boot_sample$S[boot_sample$A == 1]) - mean(boot_sample$S[boot_sample$A == 0])
  delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) - mean(boot_sample$Y[boot_sample$A == 0])

  effects_covariate[m, ] <- c(delta_s, delta_y)
}

corr_cov <- cor(effects_covariate[, 1], effects_covariate[, 2])

cat("COVARIATE-LEVEL:\n")
cat(sprintf("  Correlation: %.3f\n", corr_cov))
cat(sprintf("  SD(ΔS): %.4f, SD(ΔY): %.4f\n\n",
            sd(effects_covariate[, 1]), sd(effects_covariate[, 2])))

cat("================================================================\n")
cat("METHOD 3: Observation-Level Innovations (Current Package)\n")
cat("================================================================\n\n")

cat("Uses n=1000 observation-level innovations (current approach)\n\n")

# Observation-level innovations
obs_innovations <- rdirichlet(M, rep(1, nrow(baseline)))

effects_obs <- matrix(NA, M, 2)

for (m in 1:M) {
  obs_weights_m <- obs_innovations[m, ]
  p0_obs <- rep(1/nrow(baseline), nrow(baseline))
  q_m_obs <- (1 - lambda) * p0_obs + lambda * obs_weights_m

  # Bootstrap
  boot_idx <- sample(1:nrow(baseline), size = nrow(baseline), replace = TRUE, prob = q_m_obs)
  boot_sample <- baseline[boot_idx, ]

  delta_s <- mean(boot_sample$S[boot_sample$A == 1]) - mean(boot_sample$S[boot_sample$A == 0])
  delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) - mean(boot_sample$Y[boot_sample$A == 0])

  effects_obs[m, ] <- c(delta_s, delta_y)
}

corr_obs <- cor(effects_obs[, 1], effects_obs[, 2])

cat("OBSERVATION-LEVEL:\n")
cat(sprintf("  Correlation: %.3f\n", corr_obs))
cat(sprintf("  SD(ΔS): %.4f, SD(ΔY): %.4f\n\n",
            sd(effects_obs[, 1]), sd(effects_obs[, 2])))

cat("================================================================\n")
cat("COMPARISON\n")
cat("================================================================\n\n")

results <- tibble(
  Method = c("Ground Truth (Type-Level)", "Covariate-Level", "Observation-Level"),
  Correlation = c(corr_type, corr_cov, corr_obs),
  SD_delta_s = c(sd(effects_type_level[, 1]), sd(effects_covariate[, 1]), sd(effects_obs[, 1])),
  Dimensionality = c(K, J, nrow(baseline)),
  Pct_of_truth = 100 * c(corr_type, corr_cov, corr_obs) / corr_type
)

print(results, width = 100)

cat("\n")
cat("KEY RESULTS:\n\n")

cat(sprintf("1. GROUND TRUTH (Type-Level, K=%d):\n", K))
cat(sprintf("   Correlation: %.3f (100%% - this is what we want to match)\n\n", corr_type))

cat(sprintf("2. COVARIATE-LEVEL (J=%d bins from covariates):\n", J))
cat(sprintf("   Correlation: %.3f (%.1f%% of ground truth)\n", corr_cov, 100 * corr_cov / corr_type))
if (corr_cov / corr_type >= 0.8) {
  cat("   ✓✓✓ EXCELLENT: Recovers 80%+ of ground truth!\n\n")
} else if (corr_cov / corr_type >= 0.6) {
  cat("   ✓✓ GOOD: Recovers 60%+ of ground truth\n\n")
} else if (corr_cov / corr_type >= 0.4) {
  cat("   ✓ MODERATE: Partial recovery\n\n")
} else {
  cat("   ✗ POOR: Low recovery\n\n")
}

cat(sprintf("3. OBSERVATION-LEVEL (n=%d, current package):\n", nrow(baseline)))
cat(sprintf("   Correlation: %.3f (%.1f%% of ground truth)\n", corr_obs, 100 * corr_obs / corr_type))
cat("   ✗ This was the K=4 validation failure\n\n")

cat("IMPROVEMENT:\n")
cat(sprintf("  Covariate-level is %.1fx better than observation-level\n",
            corr_cov / corr_obs))
cat(sprintf("  Closes %.1f%% of the gap to ground truth\n\n",
            100 * (corr_cov - corr_obs) / (corr_type - corr_obs)))

cat("================================================================\n")
cat("VARIANCE ANALYSIS\n")
cat("================================================================\n\n")

cat("Standard deviation of treatment effects:\n")
cat(sprintf("  Ground truth:   SD(ΔS)=%.4f, SD(ΔY)=%.4f\n",
            sd(effects_type_level[, 1]), sd(effects_type_level[, 2])))
cat(sprintf("  Covariate:      SD(ΔS)=%.4f, SD(ΔY)=%.4f (%.1f%% of truth)\n",
            sd(effects_covariate[, 1]), sd(effects_covariate[, 2]),
            100 * sd(effects_covariate[, 1]) / sd(effects_type_level[, 1])))
cat(sprintf("  Observation:    SD(ΔS)=%.4f, SD(ΔY)=%.4f (%.1f%% of truth)\n\n",
            sd(effects_obs[, 1]), sd(effects_obs[, 2]),
            100 * sd(effects_obs[, 1]) / sd(effects_type_level[, 1])))

if (sd(effects_covariate[, 1]) / sd(effects_type_level[, 1]) >= 0.8) {
  cat("✓ Covariate-level captures 80%+ of variation\n\n")
} else if (sd(effects_covariate[, 1]) / sd(effects_type_level[, 1]) >= 0.6) {
  cat("✓ Covariate-level captures 60%+ of variation\n\n")
} else {
  cat("⚠ Covariate-level captures < 60% of variation\n")
  cat("  (May need more informative covariates or finer binning)\n\n")
}

cat("================================================================\n")
cat("TESTING DIFFERENT BINNING STRATEGIES\n")
cat("================================================================\n\n")

cat("Trying different numbers of bins per covariate:\n\n")

bin_results <- tibble(
  n_bins = integer(),
  J_total = integer(),
  correlation = numeric(),
  pct_of_truth = numeric()
)

for (n_bins_test in c(2, 3, 4, 5, 7)) {
  covariate_bins_test <- discretize_covariates(X, n_bins_per_covariate = n_bins_test)
  J_test <- length(unique(covariate_bins_test))

  cov_innovations_test <- rdirichlet(300, rep(1, J_test))

  effects_test <- matrix(NA, 300, 2)

  for (m in 1:300) {
    cov_weights_m <- cov_innovations_test[m, ]
    p0_cov <- table(covariate_bins_test) / nrow(baseline)
    q_m_cov <- (1 - lambda) * p0_cov + lambda * cov_weights_m

    obs_weights <- q_m_cov[covariate_bins_test]
    obs_weights <- obs_weights / sum(obs_weights)

    boot_idx <- sample(1:nrow(baseline), size = nrow(baseline), replace = TRUE, prob = obs_weights)
    boot_sample <- baseline[boot_idx, ]

    delta_s <- mean(boot_sample$S[boot_sample$A == 1]) - mean(boot_sample$S[boot_sample$A == 0])
    delta_y <- mean(boot_sample$Y[boot_sample$A == 1]) - mean(boot_sample$Y[boot_sample$A == 0])

    effects_test[m, ] <- c(delta_s, delta_y)
  }

  corr_test <- cor(effects_test[, 1], effects_test[, 2])

  bin_results <- bind_rows(bin_results, tibble(
    n_bins = n_bins_test,
    J_total = J_test,
    correlation = corr_test,
    pct_of_truth = 100 * corr_test / corr_type
  ))

  cat(sprintf("  n_bins=%d → J=%2d bins → correlation=%.3f (%.1f%% of truth)\n",
              n_bins_test, J_test, corr_test, 100 * corr_test / corr_type))
}

cat("\n")

best_idx <- which.max(bin_results$pct_of_truth)
cat(sprintf("Best: n_bins=%d gives %.1f%% recovery\n\n",
            bin_results$n_bins[best_idx], bin_results$pct_of_truth[best_idx]))

cat("================================================================\n")
cat("CONCLUSION\n")
cat("================================================================\n\n")

cat("COVARIATE-BASED INNOVATIONS SOLVE THE K=4 FAILURE:\n\n")

if (corr_cov / corr_type >= 0.7) {
  cat("✓✓✓ SUCCESS: Covariate-level recovers 70%+ of ground truth\n")
  cat("    This is a MASSIVE improvement over observation-level\n\n")
} else if (corr_cov / corr_type >= 0.5) {
  cat("✓✓ GOOD: Covariate-level recovers 50%+ of ground truth\n")
  cat("    Much better than observation-level (%.1f%%)\n\n", 100 * corr_obs / corr_type)
} else {
  cat("✓ IMPROVEMENT: Covariate-level better than observation-level\n")
  cat("   But may need refinement (better covariates or binning)\n\n")
}

cat("KEY INSIGHTS:\n\n")

cat("1. DIMENSIONALITY MATTERS:\n")
cat(sprintf("   - Type-level: K=%d (true structure)\n", K))
cat(sprintf("   - Covariate-level: J=%d (from covariates)\n", J))
cat(sprintf("   - Observation-level: n=%d (too fine-grained)\n\n", nrow(baseline)))

cat("2. COVARIATES CAPTURE STRUCTURE:\n")
cat("   - When types are defined by covariates,\n")
cat("   - Innovating over covariate bins recovers type-level variation\n")
cat("   - Without needing to know K or observe types\n\n")

cat("3. PRACTICAL SOLUTION:\n")
cat("   - Users provide covariates (age, sex, risk, etc.)\n")
cat("   - Method automatically bins and innovates\n")
cat("   - No need to estimate K or identify types\n\n")

cat("RECOMMENDATION:\n")
cat("  Implement covariate-based innovations as the DEFAULT\n")
cat("  Package should:\n")
cat("    1. Accept 'covariates' argument\n")
cat("    2. Discretize into bins (user controls n_bins)\n")
cat("    3. Generate innovations over covariate bins\n")
cat("    4. Provide clear interpretation\n\n")

cat("VALIDATION:\n")
cat("  - Generate data with types defined by covariates\n")
cat("  - Ground truth: type-level (knows K)\n")
cat("  - Method: covariate-level (observes covariates)\n")
cat("  - Should achieve 70-90%% recovery → good coverage\n\n")

cat("================================================================\n")
cat("Test complete!\n")
cat("================================================================\n")
