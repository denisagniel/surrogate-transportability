#' Create Data Generating Processes for Classification Study
#'
#' Generates the four scenario types for evaluating classification accuracy:
#' True Positive, False Positive, False Negative, True Negative
#'
#' @description
#' The classification study tests whether methods correctly identify transportable
#' vs non-transportable surrogates. We create four scenarios in a 2×2 design:
#'
#' 1. **True Positive (TP)**: Transportable AND traditional says "good"
#'    - High within-study correlation (ρ_within ≈ 0.85)
#'    - High treatment effect correlation across types (ρ_across ≈ 0.85)
#'
#' 2. **False Positive (FP)**: NOT transportable BUT traditional says "good"
#'    - High within-study correlation (ρ_within ≈ 0.85) due to confounding
#'    - Low treatment effect correlation across types (ρ_across ≈ 0.2)
#'
#' 3. **False Negative (FN)**: Transportable BUT traditional says "bad"
#'    - Low within-study correlation (ρ_within ≈ 0.3) due to high noise
#'    - High treatment effect correlation across types (ρ_across ≈ 0.85)
#'
#' 4. **True Negative (TN)**: NOT transportable AND traditional says "bad"
#'    - Low within-study correlation (ρ_within ≈ 0.3)
#'    - Low treatment effect correlation across types (ρ_across ≈ 0.2)

library(tibble)
library(dplyr)

#' Generate True Positive scenario
#'
#' @param n Sample size
#' @param J Number of types
#' @param seed Random seed
#' @return List with data and ground truth
#' @export
generate_true_positive <- function(n = 500, J = 16, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Generate J types with HIGHLY CORRELATED treatment effects
  tau_y <- rnorm(J, mean = 0.5, sd = 0.15)
  tau_s <- 0.85 * tau_y + rnorm(J, mean = 0, sd = 0.08)

  # Verify correlation is high
  cor_effects <- cor(tau_s, tau_y)

  # Generate type probabilities (uniform)
  pi_types <- rep(1/J, J)

  # Assign types to individuals
  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)

  # Randomized treatment
  A <- rbinom(n, 1, 0.5)

  # Covariate
  X <- rnorm(n)

  # Generate S and Y WITHOUT unmeasured confounding
  # Use type-specific baseline levels to create within-study correlation
  # Generate correlated baseline levels
  baseline_s <- rnorm(J, 0, 0.5)
  baseline_y <- 0.8 * baseline_s + rnorm(J, 0, 0.3)  # Correlated baselines

  # Surrogate: type-specific baseline + treatment effect + covariate + noise
  S <- baseline_s[types] + tau_s[types] * A + 0.3 * X + rnorm(n, sd = 0.4)

  # Outcome: type-specific baseline + treatment effect + covariate + noise
  Y <- baseline_y[types] + tau_y[types] * A + 0.2 * X + rnorm(n, sd = 0.3)

  # Within-study correlation (should be high due to correlated baselines)
  cor_within <- cor(S, Y)

  data <- tibble(
    type = types,
    A = A,
    X = X,
    S = S,
    Y = Y
  )

  list(
    data = data,
    scenario_type = "true_positive",
    tau_s = tau_s,
    tau_y = tau_y,
    cor_effects = cor_effects,
    cor_within = cor_within,
    is_transportable = TRUE,
    traditional_says_good = TRUE
  )
}


#' Generate False Positive scenario
#'
#' @param n Sample size
#' @param J Number of types
#' @param seed Random seed
#' @return List with data and ground truth
#' @export
generate_false_positive <- function(n = 500, J = 16, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Generate J types with UNCORRELATED treatment effects
  tau_s <- rnorm(J, mean = 0.5, sd = 0.2)
  tau_y <- rnorm(J, mean = 0.5, sd = 0.2)  # Independent

  # Verify correlation is low
  cor_effects <- cor(tau_s, tau_y)

  # Generate type probabilities
  pi_types <- rep(1/J, J)

  # Assign types
  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)

  # Randomized treatment
  A <- rbinom(n, 1, 0.5)

  # Covariate
  X <- rnorm(n)

  # Generate S and Y with STRONGLY CORRELATED BASELINES
  # This creates high within-study correlation despite uncorrelated treatment effects
  baseline_s <- rnorm(J, 0, 0.7)
  baseline_y <- 0.9 * baseline_s + rnorm(J, 0, 0.2)  # Very correlated baselines

  # Surrogate: baseline + treatment effect + covariate + small noise
  S <- baseline_s[types] + tau_s[types] * A + 0.3 * X + rnorm(n, sd = 0.3)

  # Outcome: baseline + treatment effect + covariate + small noise
  Y <- baseline_y[types] + tau_y[types] * A + 0.2 * X + rnorm(n, sd = 0.25)

  # Within-study correlation (should be high due to correlated baselines)
  cor_within <- cor(S, Y)

  data <- tibble(
    type = types,
    A = A,
    X = X,
    S = S,
    Y = Y
  )

  list(
    data = data,
    scenario_type = "false_positive",
    tau_s = tau_s,
    tau_y = tau_y,
    cor_effects = cor_effects,
    cor_within = cor_within,
    is_transportable = FALSE,
    traditional_says_good = TRUE
  )
}


#' Generate False Negative scenario
#'
#' @param n Sample size
#' @param J Number of types
#' @param seed Random seed
#' @return List with data and ground truth
#' @export
generate_false_negative <- function(n = 500, J = 16, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Generate J types with HIGHLY CORRELATED treatment effects
  tau_y <- rnorm(J, mean = 0.5, sd = 0.15)
  tau_s <- 0.85 * tau_y + rnorm(J, mean = 0, sd = 0.08)

  # Verify correlation is high
  cor_effects <- cor(tau_s, tau_y)

  # Generate type probabilities
  pi_types <- rep(1/J, J)

  # Assign types
  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)

  # Randomized treatment
  A <- rbinom(n, 1, 0.5)

  # Covariate
  X <- rnorm(n)

  # Generate S and Y with UNCORRELATED BASELINES and HIGH NOISE
  # This creates low within-study correlation despite correlated treatment effects
  baseline_s <- rnorm(J, 0, 0.3)
  baseline_y <- rnorm(J, 0, 0.3)  # Independent baselines

  # Surrogate: baseline + treatment effect + covariate + VERY HIGH NOISE
  S <- baseline_s[types] + tau_s[types] * A + 0.3 * X + rnorm(n, sd = 1.5)

  # Outcome: baseline + treatment effect + covariate + moderate noise
  Y <- baseline_y[types] + tau_y[types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  # Within-study correlation (should be low due to high noise and uncorrelated baselines)
  cor_within <- cor(S, Y)

  data <- tibble(
    type = types,
    A = A,
    X = X,
    S = S,
    Y = Y
  )

  list(
    data = data,
    scenario_type = "false_negative",
    tau_s = tau_s,
    tau_y = tau_y,
    cor_effects = cor_effects,
    cor_within = cor_within,
    is_transportable = TRUE,
    traditional_says_good = FALSE
  )
}


#' Generate True Negative scenario
#'
#' @param n Sample size
#' @param J Number of types
#' @param seed Random seed
#' @return List with data and ground truth
#' @export
generate_true_negative <- function(n = 500, J = 16, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Generate J types with UNCORRELATED treatment effects
  tau_s <- rnorm(J, mean = 0.5, sd = 0.2)
  tau_y <- rnorm(J, mean = 0.5, sd = 0.2)  # Independent

  # Verify correlation is low
  cor_effects <- cor(tau_s, tau_y)

  # Generate type probabilities
  pi_types <- rep(1/J, J)

  # Assign types
  types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)

  # Randomized treatment
  A <- rbinom(n, 1, 0.5)

  # Covariate
  X <- rnorm(n)

  # Generate S and Y with UNCORRELATED BASELINES and HIGH NOISE
  # Low within-study correlation and uncorrelated effects
  baseline_s <- rnorm(J, 0, 0.3)
  baseline_y <- rnorm(J, 0, 0.3)  # Independent baselines

  # Surrogate: baseline + treatment effect + covariate + high noise
  S <- baseline_s[types] + tau_s[types] * A + 0.3 * X + rnorm(n, sd = 1.2)

  # Outcome: baseline + treatment effect + covariate + high noise
  Y <- baseline_y[types] + tau_y[types] * A + 0.2 * X + rnorm(n, sd = 1.0)

  # Within-study correlation (should be low)
  cor_within <- cor(S, Y)

  data <- tibble(
    type = types,
    A = A,
    X = X,
    S = S,
    Y = Y
  )

  list(
    data = data,
    scenario_type = "true_negative",
    tau_s = tau_s,
    tau_y = tau_y,
    cor_effects = cor_effects,
    cor_within = cor_within,
    is_transportable = FALSE,
    traditional_says_good = FALSE
  )
}


#' Generate all four classification scenarios
#'
#' @param n Sample size for each scenario
#' @param J Number of types
#' @param seed Base random seed (each scenario gets seed + offset)
#' @return List of four scenarios
#' @export
generate_all_classification_scenarios <- function(n = 500, J = 16, seed = NULL) {
  if (!is.null(seed)) {
    seeds <- seed + 0:3
  } else {
    seeds <- rep(NULL, 4)
  }

  list(
    true_positive = generate_true_positive(n, J, seeds[1]),
    false_positive = generate_false_positive(n, J, seeds[2]),
    false_negative = generate_false_negative(n, J, seeds[3]),
    true_negative = generate_true_negative(n, J, seeds[4])
  )
}


#' Print scenario diagnostics
#'
#' @param scenario Output from generate_* function
#' @export
print_scenario_diagnostics <- function(scenario) {
  cat(sprintf("\nScenario: %s\n", toupper(scenario$scenario_type)))
  cat(sprintf("  Treatment effect correlation: %.3f\n", scenario$cor_effects))
  cat(sprintf("  Within-study correlation: %.3f\n", scenario$cor_within))
  cat(sprintf("  Is transportable: %s\n", scenario$is_transportable))
  cat(sprintf("  Traditional says good: %s\n", scenario$traditional_says_good))
  cat(sprintf("  N observations: %d\n", nrow(scenario$data)))
  cat(sprintf("  Mean tau_s: %.3f (SD: %.3f)\n",
              mean(scenario$tau_s), sd(scenario$tau_s)))
  cat(sprintf("  Mean tau_y: %.3f (SD: %.3f)\n",
              mean(scenario$tau_y), sd(scenario$tau_y)))
}


#' Verify scenario properties
#'
#' Check that generated scenarios have expected properties
#'
#' @param scenarios Output from generate_all_classification_scenarios
#' @return Tibble with verification results
#' @export
verify_scenario_properties <- function(scenarios) {
  results <- list()

  for (name in names(scenarios)) {
    sc <- scenarios[[name]]

    # Expected properties
    expected <- list(
      true_positive = list(
        cor_effects_high = TRUE,
        cor_within_high = TRUE,
        transportable = TRUE
      ),
      false_positive = list(
        cor_effects_high = FALSE,
        cor_within_high = TRUE,
        transportable = FALSE
      ),
      false_negative = list(
        cor_effects_high = TRUE,
        cor_within_high = FALSE,
        transportable = TRUE
      ),
      true_negative = list(
        cor_effects_high = FALSE,
        cor_within_high = FALSE,
        transportable = FALSE
      )
    )[[name]]

    # Check properties
    cor_effects_high <- sc$cor_effects > 0.6
    cor_within_high <- sc$cor_within > 0.5

    results[[name]] <- tibble(
      scenario = name,
      cor_effects = sc$cor_effects,
      cor_effects_high = cor_effects_high,
      cor_effects_ok = cor_effects_high == expected$cor_effects_high,
      cor_within = sc$cor_within,
      cor_within_high = cor_within_high,
      cor_within_ok = cor_within_high == expected$cor_within_high,
      transportable = sc$is_transportable,
      transportable_ok = sc$is_transportable == expected$transportable
    )
  }

  bind_rows(results)
}
