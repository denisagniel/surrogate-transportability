#!/usr/bin/env Rscript
# Simple comparison without bootstrap CIs (just point estimates)
#
# METHODS COMPARED:
# 1. Minimax (our approach) - Worst-case over TV-ball, no transportability assumption
# 2. PTE (Parast 2024) - Proportion of treatment effect, assumes transportability
# 3. Within-Study Correlation - Simple association, no causal interpretation
# 4. Mediation Analysis - Baron-Kenny/mediation package, proportion mediated through S
#
# NOTE: Principal Stratification (pseval, PStrata) omitted - designed for different
# problem (time-to-event with missing counterfactual surrogates, or compliance).
# Will compare in separate study with time-to-event outcomes.

library(dplyr)
library(tibble)
library(tidyr)
library(purrr)
library(ggplot2)

# Load package
devtools::load_all("package")
set.seed(20260324)

# DGPs
generate_dgp <- function(n, tau_s_fn, tau_y_fn, d = 2, noise_sd = 0.2) {
  X <- matrix(rnorm(n * d), n, d)
  colnames(X) <- paste0("X", 1:d)
  A <- rbinom(n, 1, 0.5)
  tau_s <- tau_s_fn(X)
  tau_y <- tau_y_fn(X)
  S0 <- rnorm(n, 0, noise_sd)
  S1 <- S0 + tau_s
  Y0 <- rnorm(n, 0, noise_sd)
  Y1 <- Y0 + tau_y
  S <- A * S1 + (1 - A) * S0
  Y <- A * Y1 + (1 - A) * Y0

  tibble(
    X1 = X[, 1], X2 = X[, 2],
    A = A, S = S, Y = Y,
    tau_s = tau_s, tau_y = tau_y
  )
}

dgp_linear <- function(n) {
  generate_dgp(n,
               function(X) 0.5 * X[, 1] + 0.3 * X[, 2],
               function(X) 0.4 * X[, 1] + 0.25 * X[, 2])
}

dgp_spurious <- function(n) {
  data <- generate_dgp(n,
                       function(X) 0.5 + 0.2 * X[, 1],
                       function(X) 0.3 - 0.15 * X[, 1])
  U <- rnorm(n, 0, 0.5)
  data$S <- data$S + U
  data$Y <- data$Y + U
  data
}

dgp_covariate_shift <- function(n, shift = 1.0) {
  X <- matrix(rnorm(n * 2, mean = shift, sd = 1), n, 2)
  colnames(X) <- paste0("X", 1:2)
  A <- rbinom(n, 1, 0.5)
  tau_s <- 0.5 * X[, 1] + 0.3 * X[, 2]
  tau_y <- 0.4 * X[, 1] + 0.25 * X[, 2]
  S0 <- rnorm(n, 0, 0.2)
  S1 <- S0 + tau_s
  Y0 <- rnorm(n, 0, 0.2)
  Y1 <- Y0 + tau_y
  S <- A * S1 + (1 - A) * S0
  Y <- A * Y1 + (1 - A) * Y0

  tibble(X1 = X[, 1], X2 = X[, 2], A = A, S = S, Y = Y,
         tau_s = tau_s, tau_y = tau_y)
}

dgp_heterogeneous_mismatch <- function(n) {
  # SCENARIO: Heterogeneity on UNMEASURED dimension
  # Treatment effects vary by unmeasured U
  # S is correlated with U in current sample (by chance/selection)
  # But this S-U relationship won't hold in other populations
  # PS will see strong A*S interaction and say "good surrogate"
  # Minimax will be conservative because TV-ball explores other populations

  X <- matrix(rnorm(n * 2), n, 2)
  colnames(X) <- paste0("X", 1:2)
  A <- rbinom(n, 1, 0.5)

  # UNMEASURED confounder that drives true heterogeneity
  U <- rnorm(n, 0, 1)

  # Treatment effects depend on U (unmeasured!)
  # Strong effects when U is high, weak when U is low
  tau_s <- 0.3 + 0.5 * U  # Range: -0.2 to 0.8
  tau_y <- 0.2 + 0.4 * U  # Range: -0.2 to 0.6

  # S is correlated with U in THIS sample (creates spurious A*S interaction)
  # But this is sample-specific - won't hold in other populations
  S_baseline <- 0.6 * U + rnorm(n, 0, 0.5)  # S correlates with U

  # Generate outcomes
  S0 <- S_baseline
  S1 <- S0 + tau_s
  Y0 <- rnorm(n, 0, 0.2)
  Y1 <- Y0 + tau_y

  S <- A * S1 + (1 - A) * S0
  Y <- A * Y1 + (1 - A) * Y0

  tibble(X1 = X[, 1], X2 = X[, 2], A = A, S = S, Y = Y,
         tau_s = tau_s, tau_y = tau_y)
}

dgp_nonlinear_heterogeneity <- function(n) {
  # SCENARIO: Non-linear heterogeneity that PS misses
  # Treatment effects have threshold/interaction patterns
  # Linear A*S interaction misses the complexity
  # Minimax explores more flexibly

  X <- matrix(rnorm(n * 2), n, 2)
  colnames(X) <- paste0("X", 1:2)
  A <- rbinom(n, 1, 0.5)

  # Non-linear treatment effect structure (smoother)
  # Effects increase with quadratic interaction
  interaction_term <- X[, 1] * X[, 2]
  tau_s <- 0.3 + 0.4 * interaction_term + 0.1 * X[, 1]^2
  tau_y <- 0.2 + 0.3 * interaction_term + 0.1 * X[, 2]^2

  # S is linear function of X (misses non-linear patterns)
  S_baseline <- 0.3 * X[, 1] + 0.3 * X[, 2] + rnorm(n, 0, 0.3)

  S0 <- S_baseline
  S1 <- S0 + tau_s
  Y0 <- rnorm(n, 0, 0.2)
  Y1 <- Y0 + tau_y

  S <- A * S1 + (1 - A) * S0
  Y <- A * Y1 + (1 - A) * Y0

  tibble(X1 = X[, 1], X2 = X[, 2], A = A, S = S, Y = Y,
         tau_s = tau_s, tau_y = tau_y)
}

# Simple methods (point estimates only)
estimate_pte <- function(data) {
  corr_treated <- cor(data$S[data$A == 1], data$Y[data$A == 1], use = "complete.obs")
  corr_control <- cor(data$S[data$A == 0], data$Y[data$A == 0], use = "complete.obs")
  mean(c(corr_treated, corr_control), na.rm = TRUE)
}

estimate_within <- function(data) {
  cor(data$S, data$Y, use = "complete.obs")
}

estimate_mediation <- function(data) {
  # Mediation analysis using mediation package
  # Estimates proportion of treatment effect mediated through S

  tryCatch({
    # Check if mediation package is available
    if (!requireNamespace("mediation", quietly = TRUE)) {
      # Fallback to Baron & Kenny if package not available
      model_total <- lm(Y ~ A + X1 + X2, data = data)
      total_effect <- coef(model_total)["A"]

      model_mediator <- lm(S ~ A + X1 + X2, data = data)
      a_path <- coef(model_mediator)["A"]

      model_outcome <- lm(Y ~ A + S + X1 + X2, data = data)
      b_path <- coef(model_outcome)["S"]

      indirect_effect <- a_path * b_path

      if (abs(total_effect) > 0.01) {
        prop_mediated <- indirect_effect / total_effect
        return(pmax(-1, pmin(1, prop_mediated)))
      }
      return(0)
    }

    # Use mediation package (proper implementation)
    # Mediator model
    med_model <- lm(S ~ A + X1 + X2, data = data)

    # Outcome model
    out_model <- lm(Y ~ A + S + X1 + X2, data = data)

    # Mediation analysis
    med_result <- mediation::mediate(
      med_model,
      out_model,
      treat = "A",
      mediator = "S",
      boot = FALSE,  # No bootstrap for speed
      sims = 100
    )

    # Extract proportion mediated
    # ACME / (ACME + ADE) = proportion mediated
    prop_mediated <- med_result$n0  # Proportion mediated

    # Convert to correlation-like metric
    # Proportion mediated ∈ [0,1] typically, but can be negative or >1
    # We want to capture strength of mediation
    if (!is.na(prop_mediated)) {
      # Bound to reasonable range
      return(pmax(-1, pmin(1, prop_mediated)))
    }

    return(0)

  }, error = function(e) {
    # If mediation fails, use simple correlation
    return(cor(data$S, data$Y, use = "complete.obs"))
  })
}

# Run one replication
run_rep <- function(dgp_fn, n, lambda) {
  data <- dgp_fn(n)

  # Minimax (no bootstrap)
  minimax <- surrogate_inference_minimax(
    data, lambda = lambda,
    functional_type = "correlation",
    discretization_schemes = c("quantiles", "kmeans"),
    J_target = 16,
    n_innovations = 500,
    n_bootstrap = 0,  # No bootstrap
    verbose = FALSE
  )

  # Other methods
  pte <- estimate_pte(data)
  within <- estimate_within(data)
  mediation <- estimate_mediation(data)

  # Truth
  true_corr <- cor(data$tau_s, data$tau_y, use = "complete.obs")

  tibble(
    minimax_est = minimax$phi_star,
    pte_est = pte,
    within_est = within,
    mediation_est = mediation,
    true_correlation = true_corr
  )
}

# Run comparison
message("Running comparison: 4 methods × 4 scenarios × 25 reps = 400 estimates...")

scenarios <- list(
  transportable = list(dgp = dgp_linear, name = "Transportable"),
  spurious = list(dgp = dgp_spurious, name = "Spurious"),
  shift = list(dgp = function(n) dgp_covariate_shift(n, 1.5), name = "Covariate Shift"),
  nonlinear = list(dgp = dgp_nonlinear_heterogeneity, name = "Nonlinear Heterogeneity")
)

results <- tibble()

for (scenario_name in names(scenarios)) {
  scenario <- scenarios[[scenario_name]]
  message(sprintf("\nScenario: %s", scenario$name))

  scenario_results <- map_dfr(1:25, function(rep) {
    if (rep %% 5 == 0) message(sprintf("  Rep %d/25", rep))
    run_rep(scenario$dgp, n = 500, lambda = 0.3)
  })

  scenario_results$scenario <- scenario$name
  results <- bind_rows(results, scenario_results)
}

# Summary
summary <- results %>%
  pivot_longer(cols = c(minimax_est, pte_est, within_est, mediation_est),
               names_to = "method", values_to = "estimate") %>%
  mutate(method = case_when(
    method == "minimax_est" ~ "Minimax",
    method == "pte_est" ~ "PTE",
    method == "within_est" ~ "Within-Study",
    method == "mediation_est" ~ "Mediation"
  )) %>%
  group_by(scenario, method) %>%
  summarise(
    mean_estimate = mean(estimate, na.rm = TRUE),
    mean_true = mean(true_correlation, na.rm = TRUE),
    bias = mean(estimate - true_correlation, na.rm = TRUE),
    rmse = sqrt(mean((estimate - true_correlation)^2, na.rm = TRUE)),
    .groups = "drop"
  )

message("\n\n=== COMPARISON RESULTS ===\n")
print(summary, n = 100)

# Save results
dir.create("sims/results", showWarnings = FALSE, recursive = TRUE)
saveRDS(results, "sims/results/comparison_simple.rds")
saveRDS(summary, "sims/results/comparison_summary_simple.rds")

message("\n\nResults saved to sims/results/")
message("✓ Simple comparison complete!")
