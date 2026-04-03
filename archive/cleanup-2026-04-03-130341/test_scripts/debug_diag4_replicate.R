#!/usr/bin/env Rscript
# Replicate Diagnostic 4 to find the bug

library(tidyverse)
library(here)
library(MCMCpack)

devtools::load_all(here("package"))

# Use EXACT same DGP as diagnostic
generate_data_with_true_types <- function(n, J, rho, cv, seed) {
  set.seed(seed)

  # Generate treatment effects for J true types
  tau_y <- rnorm(J, mean = 0.5, sd = cv)
  tau_s <- rho * tau_y + sqrt(1 - rho^2) * rnorm(J, sd = cv)

  # Type probabilities (uniform)
  pi_types <- rep(1/J, J)

  # Generate data with known type assignments
  true_types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  S <- tau_s[true_types] * A + 0.3 * X + rnorm(n, sd = 0.5)
  Y <- tau_y[true_types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  data <- tibble(type = true_types, A = A, X = X, S = S, Y = Y)

  # True values
  true_concordance_p0 <- sum(pi_types * tau_s * tau_y)
  concordances <- tau_s * tau_y
  true_min_concordance <- min(concordances)

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

# Run 10 reps to see the pattern
n_test <- 10
lambda <- 0.4
n <- 250
J <- 16
rho <- 0.9
cv <- 0.1

results <- map_dfr(1:n_test, function(rep) {

  dgp <- generate_data_with_true_types(n, J, rho, cv, seed = rep + 30000)

  true_minimax <- (1 - lambda) * dgp$true_concordance_p0 + lambda * dgp$true_min_concordance

  # CLOSED-FORM
  est_closed <- estimate_minimax_single_scheme(
    data = dgp$data,
    bins = dgp$true_types,
    lambda = lambda,
    functional_type = "concordance"
  )$phi_value

  # SAMPLING
  type_stats <- compute_type_level_effects(dgp$data, dgp$true_types)

  M <- 5000
  innovations <- MCMCpack::rdirichlet(M, rep(1, type_stats$J))

  concordances_sampling <- numeric(M)
  for (m in 1:M) {
    q_m <- (1 - lambda) * type_stats$p0 + lambda * innovations[m, ]
    concordances_sampling[m] <- sum(q_m * type_stats$tau_s * type_stats$tau_y)
  }

  est_sampling <- min(concordances_sampling)

  # Also compute what closed-form SHOULD give
  concordance_p0 <- sum(type_stats$p0 * type_stats$tau_s * type_stats$tau_y)
  min_concordance <- min(type_stats$tau_s * type_stats$tau_y)
  est_closed_formula <- (1 - lambda) * concordance_p0 + lambda * min_concordance

  # Find which innovation achieved the minimum
  min_idx <- which.min(concordances_sampling)
  best_innovation <- innovations[min_idx, ]

  # What would happen if we used a POINT MASS at the min type?
  j_min <- which.min(type_stats$tau_s * type_stats$tau_y)
  point_mass <- rep(0, type_stats$J)
  point_mass[j_min] <- 1
  q_pointmass <- (1 - lambda) * type_stats$p0 + lambda * point_mass
  conc_pointmass <- sum(q_pointmass * type_stats$tau_s * type_stats$tau_y)

  tibble(
    rep = rep,
    truth = true_minimax,
    closed = est_closed,
    sampling = est_sampling,
    closed_formula = est_closed_formula,
    pointmass = conc_pointmass,
    best_innov_at_min = best_innovation[j_min],
    concordance_p0 = concordance_p0,
    min_conc = min_concordance
  )
})

cat("==== SUMMARY ACROSS", n_test, "REPLICATIONS ====\n\n")

cat("Mean estimates:\n")
cat("  Truth:           ", round(mean(results$truth), 4), "\n")
cat("  Closed-form:     ", round(mean(results$closed), 4), "\n")
cat("  Sampling:        ", round(mean(results$sampling), 4), "\n")
cat("  Point mass check:", round(mean(results$pointmass), 4), "\n\n")

cat("Mean bias:\n")
cat("  Closed-form: ", round(mean(results$closed - results$truth), 4), "\n")
cat("  Sampling:    ", round(mean(results$sampling - results$truth), 4), "\n\n")

cat("Check if closed-form formula matches:\n")
cat("  Closed == Closed_formula? ", all(abs(results$closed - results$closed_formula) < 1e-10), "\n")
cat("  Closed == Pointmass?      ", all(abs(results$closed - results$pointmass) < 1e-10), "\n\n")

cat("How much weight does best innovation put on min type?\n")
cat("  Mean weight: ", round(mean(results$best_innov_at_min), 3), "\n")
cat("  Min weight:  ", round(min(results$best_innov_at_min), 3), "\n")
cat("  Max weight:  ", round(max(results$best_innov_at_min), 3), "\n\n")

cat("Is sampling systematically better than point mass?\n")
cat("  Mean(sampling - pointmass): ", round(mean(results$sampling - results$pointmass), 4), "\n")
cat("  Proportion sampling < pointmass: ", mean(results$sampling < results$pointmass), "\n\n")

cat("==== DETAILED RESULTS ====\n")
print(results, n = n_test)

cat("\n==== DIAGNOSIS ====\n")
if (abs(mean(results$closed - results$truth)) > abs(mean(results$sampling - results$truth)) + 0.01) {
  cat("BUG CONFIRMED: Closed-form is systematically MORE biased than sampling\n")
  cat("Closed-form bias:", round(mean(results$closed - results$truth), 4), "\n")
  cat("Sampling bias:   ", round(mean(results$sampling - results$truth), 4), "\n")

  if (mean(results$sampling < results$pointmass) > 0.9) {
    cat("\nSampling BEATS point mass in >90% of cases\n")
    cat("This means the minimum is NOT always at a point mass!\n")
    cat("The closed-form assumption is WRONG.\n")
  }
} else {
  cat("No systematic difference detected\n")
}
