#!/usr/bin/env Rscript
# Deep dive: What's actually wrong?

library(tidyverse)
library(here)
library(MCMCpack)

devtools::load_all(here("package"))

# Use EXACT same DGP
generate_data_with_true_types <- function(n, J, rho, cv, seed) {
  set.seed(seed)
  tau_y <- rnorm(J, mean = 0.5, sd = cv)
  tau_s <- rho * tau_y + sqrt(1 - rho^2) * rnorm(J, sd = cv)
  pi_types <- rep(1/J, J)

  true_types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  S <- tau_s[true_types] * A + 0.3 * X + rnorm(n, sd = 0.5)
  Y <- tau_y[true_types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  data <- tibble(type = true_types, A = A, X = X, S = S, Y = Y)

  true_concordance_p0 <- sum(pi_types * tau_s * tau_y)
  true_min_concordance <- min(tau_s * tau_y)

  list(
    data = data,
    true_types = true_types,
    tau_s = tau_s,
    tau_y = tau_y,
    pi_types = pi_types,
    true_concordance_p0 = true_concordance_p0,
    true_min_concordance = true_min_concordance
  )
}

# Run ONE replication with full analysis
lambda <- 0.4
dgp <- generate_data_with_true_types(n = 250, J = 16, rho = 0.9, cv = 0.1, seed = 42)

cat("==== TRUE PARAMETERS ====\n")
cat("True tau_s (by type):\n")
print(round(dgp$tau_s, 3))
cat("\nTrue tau_y (by type):\n")
print(round(dgp$tau_y, 3))
cat("\nTrue concordances (by type):\n")
true_concordances <- dgp$tau_s * dgp$tau_y
print(round(true_concordances, 3))
cat("\nTrue minimum concordance:", round(min(true_concordances), 3), "at type", which.min(true_concordances), "\n")
cat("True E_P0[conc]:", round(dgp$true_concordance_p0, 4), "\n")
cat("True minimax:", round((1-lambda) * dgp$true_concordance_p0 + lambda * min(true_concordances), 4), "\n\n")

# Estimate type-level effects from data
type_stats <- compute_type_level_effects(dgp$data, dgp$true_types)

cat("==== ESTIMATED PARAMETERS ====\n")
cat("Estimated tau_s (by type):\n")
print(round(type_stats$tau_s, 3))
cat("\nEstimated tau_y (by type):\n")
print(round(type_stats$tau_y, 3))
cat("\nEstimated concordances (by type):\n")
est_concordances <- type_stats$tau_s * type_stats$tau_y
print(round(est_concordances, 3))
cat("\nEstimated minimum concordance:", round(min(est_concordances), 3), "at type", which.min(est_concordances), "\n")
cat("Estimated E_P0[conc]:", round(sum(type_stats$p0 * est_concordances), 4), "\n\n")

# Compare true vs estimated
cat("==== ESTIMATION ERRORS ====\n")
errors_tau_s <- type_stats$tau_s - dgp$tau_s
errors_tau_y <- type_stats$tau_y - dgp$tau_y
errors_conc <- est_concordances - true_concordances

cat("Errors in tau_s:\n")
print(round(errors_tau_s, 3))
cat("  RMSE:", round(sqrt(mean(errors_tau_s^2)), 3), "\n\n")

cat("Errors in tau_y:\n")
print(round(errors_tau_y, 3))
cat("  RMSE:", round(sqrt(mean(errors_tau_y^2)), 3), "\n\n")

cat("Errors in concordances:\n")
print(round(errors_conc, 3))
cat("  RMSE:", round(sqrt(mean(errors_conc^2)), 3), "\n\n")

# Key question: Is the estimated minimum type the TRUE minimum type?
true_min_type <- which.min(true_concordances)
est_min_type <- which.min(est_concordances)

cat("==== THE SELECTION BIAS ====\n")
cat("True minimum type:", true_min_type, "with concordance", round(true_concordances[true_min_type], 3), "\n")
cat("Estimated minimum type:", est_min_type, "with concordance", round(true_concordances[est_min_type], 3), "(TRUTH!)\n")
cat("Selection error:", est_min_type != true_min_type, "\n\n")

if (est_min_type != true_min_type) {
  cat("We selected type", est_min_type, "but the true minimum is type", true_min_type, "\n")
  cat("Type", est_min_type, "has TRUE concordance", round(true_concordances[est_min_type], 3), "\n")
  cat("Type", true_min_type, "has TRUE concordance", round(true_concordances[true_min_type], 3), "\n")
  cat("We're overcommitting to a type that ISN'T actually the worst!\n\n")
}

# What does the closed-form give us?
cat("==== CLOSED-FORM CALCULATION ====\n")
concordance_p0_est <- sum(type_stats$p0 * est_concordances)
min_conc_est <- min(est_concordances)
phi_closed <- (1 - lambda) * concordance_p0_est + lambda * min_conc_est

cat("Closed-form minimax estimate:", round(phi_closed, 4), "\n")
cat("Using estimated argmin (type", est_min_type, ")\n")
cat("That type's TRUE concordance:", round(true_concordances[est_min_type], 3), "\n\n")

# What SHOULD the closed-form give if we used TRUE argmin?
cat("==== IF WE KNEW THE TRUE ARGMIN ====\n")
phi_oracle <- (1 - lambda) * concordance_p0_est + lambda * true_concordances[true_min_type]
cat("Oracle closed-form (using true argmin type", true_min_type, "):", round(phi_oracle, 4), "\n")
cat("True minimax:", round((1-lambda) * dgp$true_concordance_p0 + lambda * min(true_concordances), 4), "\n\n")

cat("==== DIAGNOSIS ====\n")
cat("Problem 1: SELECTION BIAS\n")
cat("  - We select argmin based on noisy estimates\n")
cat("  - Selected type (", est_min_type, ") may not be the true minimum (", true_min_type, ")\n")
cat("  - Winner's curse: estimated min is systematically too low\n\n")

cat("Problem 2: ESTIMATION NOISE\n")
cat("  - RMSE in concordance estimates:", round(sqrt(mean(errors_conc^2)), 3), "\n")
cat("  - With small bins (~15 obs/type), estimates are very noisy\n")
cat("  - Noise amplified when we take minimum\n\n")

cat("==== POTENTIAL FIXES ====\n\n")

cat("FIX 1: SHRINKAGE ESTIMATION\n")
cat("  - Shrink type-level estimates towards grand mean\n")
cat("  - Reduces noise in individual bin estimates\n")
cat("  - Empirical Bayes or James-Stein estimator\n\n")

cat("FIX 2: DEBIASED SELECTION\n")
cat("  - Bootstrap to estimate selection bias\n")
cat("  - Correct the minimum for expected downward bias\n")
cat("  - Similar to post-selection inference methods\n\n")

cat("FIX 3: CROSS-VALIDATION\n")
cat("  - Split data: fit types on one half, estimate effects on other\n")
cat("  - Avoids using same data for selection and estimation\n")
cat("  - Reduces overfitting to noise\n\n")

cat("FIX 4: HIERARCHICAL MODEL\n")
cat("  - Model tau_j ~ N(mu, sigma^2)\n")
cat("  - Borrow strength across types\n")
cat("  - Posterior mean estimates are shrunken\n\n")

cat("FIX 5: BETTER BINS\n")
cat("  - Use fewer, more stable types (smaller J)\n")
cat("  - Or stratified bins with more obs per bin\n")
cat("  - Trade off granularity for stability\n\n")
