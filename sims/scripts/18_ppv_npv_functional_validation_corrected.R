#!/usr/bin/env Rscript

#' Correlation Functional Validation (POPULATION-BASED GROUND TRUTH)
#'
#' Research Questions:
#' 1. Does the method correctly estimate ground truth from population?
#' 2. Do 95% CIs achieve nominal coverage?
#' 3. Does this work for high-dimensional K (K ≈ n/2)?
#'
#' APPROACH (2026-03-23 EVENING):
#'   1. Define POPULATION with known parameters (K types)
#'   2. Ground truth: Generate NEW samples from population with varying type weights
#'   3. Method sees: ONE sample from population
#'   4. Validation: Does method CI capture population ground truth?
#'
#' Uses CORRELATION functional (smooth, no boundary issues)
#'
#' This is NOT circular! We're testing:
#'   - Ground truth: Computed from population parameters
#'   - Method: Computed from finite sample (doesn't see population)

library(devtools)
library(dplyr)
library(tibble)
library(ggplot2)

# Ensure we're in project root
while (!dir.exists("package") && dirname(getwd()) != getwd()) {
  setwd("..")
}

if (!dir.exists("package")) {
  stop("Cannot find package/ directory. Please run from project root or sims/scripts/")
}

devtools::load_all("package/", quiet = TRUE)

set.seed(20260323)

# Parameters
N_BASELINE <- 1000  # Sample size for observed baseline
N_REPLICATIONS <- 200  # Number of validation replications per scenario
N_TRUE_STUDIES <- 500  # For computing TRUE φ(F_λ) from population
N_INNOVATIONS <- 2000   # For method estimation
CONFIDENCE_LEVEL <- 0.95

# Lambda scenarios
lambda_scenarios <- list(
  small = list(name = "Small λ=0.1", lambda = 0.1),
  moderate = list(name = "Moderate λ=0.3", lambda = 0.3),
  large = list(name = "Large λ=0.5", lambda = 0.5)
)

# Population scenarios - varying K and correlation strength
population_scenarios <- list()

# K=4 (low-dimensional, strong correlation)
set.seed(12345)
population_scenarios$k4_strong <- list(
  name = "K=4 Strong-Corr",
  K = 4,
  tau_s = c(-0.6, -0.2, 0.2, 0.6),
  tau_y = c(-0.5, -0.1, 0.1, 0.5),
  s0_mean = 0, s0_sd = 0.5,
  y0_mean = 0, y0_sd = 0.5,
  noise_sd = 0.2,
  description = "4 types, strong correlation (ρ ≈ 0.99)"
)

# K=100 (medium-dimensional, moderate correlation)
set.seed(12346)
Sigma_mod <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
type_effects_mod <- MASS::mvrnorm(100, mu = c(0, 0), Sigma = Sigma_mod)
population_scenarios$k100_moderate <- list(
  name = "K=100 Mod-Corr",
  K = 100,
  tau_s = type_effects_mod[, 1] * 0.3,
  tau_y = type_effects_mod[, 2] * 0.3,
  s0_mean = 0, s0_sd = 0.5,
  y0_mean = 0, y0_sd = 0.5,
  noise_sd = 0.2,
  description = "100 types, moderate correlation (ρ ≈ 0.5)"
)

# K=500 (high-dimensional, strong correlation)
set.seed(12347)
Sigma_strong <- matrix(c(1, 0.8, 0.8, 1), 2, 2)
type_effects_strong <- MASS::mvrnorm(500, mu = c(0, 0), Sigma = Sigma_strong)
population_scenarios$k500_strong <- list(
  name = "K=500 Strong-Corr",
  K = 500,
  tau_s = type_effects_strong[, 1] * 0.3,
  tau_y = type_effects_strong[, 2] * 0.3,
  s0_mean = 0, s0_sd = 0.5,
  y0_mean = 0, y0_sd = 0.5,
  noise_sd = 0.2,
  description = "500 types, strong correlation (ρ ≈ 0.8)"
)

# K=500 (high-dimensional, weak correlation)
set.seed(12348)
Sigma_weak <- matrix(c(1, 0.2, 0.2, 1), 2, 2)
type_effects_weak <- MASS::mvrnorm(500, mu = c(0, 0), Sigma = Sigma_weak)
population_scenarios$k500_weak <- list(
  name = "K=500 Weak-Corr",
  K = 500,
  tau_s = type_effects_weak[, 1] * 0.3,
  tau_y = type_effects_weak[, 2] * 0.3,
  s0_mean = 0, s0_sd = 0.5,
  y0_mean = 0, y0_sd = 0.5,
  noise_sd = 0.2,
  description = "500 types, weak correlation (ρ ≈ 0.2)"
)

cat("================================================================\n")
cat("CORRELATION VALIDATION: POPULATION-BASED GROUND TRUTH\n")
cat("================================================================\n\n")

cat("KEY DESIGN:\n")
cat("  1. Define POPULATION with K types and known parameters\n")
cat("  2. Ground truth: Generate NEW samples from population\n")
cat("  3. Method: Sees ONE sample from population\n")
cat("  4. Check: Does method CI capture population truth?\n\n")

cat("This tests: Does inference work when method sees finite sample\n")
cat("           but we know the underlying population?\n\n")

cat("Parameters:\n")
cat(sprintf("  Baseline n: %d\n", N_BASELINE))
cat(sprintf("  Replications per scenario: %d\n", N_REPLICATIONS))
cat(sprintf("  True studies from population: %d\n", N_TRUE_STUDIES))
cat(sprintf("  Innovations (M) for method: %d\n", N_INNOVATIONS))
cat(sprintf("  Functional: Correlation (treatment effects)\n\n"))

cat("Test Dimensions:\n")
cat(sprintf("  Lambda values: %d (%s)\n",
            length(lambda_scenarios),
            paste(sapply(lambda_scenarios, function(x) x$lambda), collapse=", ")))
cat(sprintf("  Population scenarios: %d\n", length(population_scenarios)))
for (pop_name in names(population_scenarios)) {
  pop <- population_scenarios[[pop_name]]
  cat(sprintf("    - %s: %s\n", pop$name, pop$description))
}
cat(sprintf("  Total replications: %d\n",
            length(lambda_scenarios) * length(population_scenarios) * N_REPLICATIONS))

cat("\n")
cat("----------------------------------------------------------------\n")
cat("Defining Population and Computing Ground Truth\n")
cat("----------------------------------------------------------------\n\n")

#' Generate sample from population
#'
#' @param population List with type parameters
#' @param type_weights Weights over types (sums to 1)
#' @param n Sample size
#' @return tibble with A, S, Y
generate_sample_from_population <- function(population, type_weights, n) {
  K <- population$K

  # Sample types according to weights
  types <- sample(1:K, size = n, replace = TRUE, prob = type_weights)

  # Randomize treatment
  A <- rbinom(n, 1, 0.5)

  # Generate outcomes for each person
  S <- numeric(n)
  Y <- numeric(n)

  for (i in 1:n) {
    type_i <- types[i]

    # Baseline values (type-specific)
    s0 <- rnorm(1, population$s0_mean, population$s0_sd)
    y0 <- rnorm(1, population$y0_mean, population$y0_sd)

    # Treatment effects (type-specific)
    tau_s_i <- population$tau_s[type_i]
    tau_y_i <- population$tau_y[type_i]

    # Observed outcomes
    S[i] <- s0 + A[i] * tau_s_i + rnorm(1, 0, population$noise_sd)
    Y[i] <- y0 + A[i] * tau_y_i + rnorm(1, 0, population$noise_sd)
  }

  tibble(A = A, S = S, Y = Y)
}

start_time <- Sys.time()

validation_results <- tibble::tibble(
  lambda_scenario = character(),
  population_scenario = character(),
  replication = integer(),
  lambda = numeric(),
  true_correlation = numeric(),
  estimate = numeric(),
  se = numeric(),
  ci_lower = numeric(),
  ci_upper = numeric(),
  covered = logical()
)

n_degenerate <- 0
total_iterations <- length(lambda_scenarios) * length(population_scenarios) * N_REPLICATIONS
iteration <- 0

for (lambda_name in names(lambda_scenarios)) {
  lambda_scenario <- lambda_scenarios[[lambda_name]]

  for (pop_name in names(population_scenarios)) {
    population <- population_scenarios[[pop_name]]

    cat(sprintf("Lambda: %s, Population: %s\n",
                lambda_scenario$name, population$name))
    cat(sprintf("  K = %d types\n", population$K))
    if (population$K <= 10) {
      cat(sprintf("  τ_S: %s\n", paste(round(population$tau_s, 2), collapse=", ")))
      cat(sprintf("  τ_Y: %s\n", paste(round(population$tau_y, 2), collapse=", ")))
    } else {
      cat(sprintf("  τ_S: Mean=%.3f, SD=%.3f\n", mean(population$tau_s), sd(population$tau_s)))
      cat(sprintf("  τ_Y: Mean=%.3f, SD=%.3f\n", mean(population$tau_y), sd(population$tau_y)))
      cat(sprintf("  Population correlation: %.3f\n", cor(population$tau_s, population$tau_y)))
    }

    # Compute GROUND TRUTH from population (once per scenario)
    cat(sprintf("  Computing ground truth from %d NEW samples from population...\n",
                N_TRUE_STUDIES))

    true_effects <- matrix(NA, nrow = N_TRUE_STUDIES, ncol = 2)

    for (m in 1:N_TRUE_STUDIES) {
      # Draw type mixture from Dirichlet(1,...,1)
      type_weights_m <- MCMCpack::rdirichlet(1, rep(1, population$K))[1,]

      # Form Q_m = (1-λ)P₀ + λΠ̃_m
      p0_weights <- rep(1/population$K, population$K)  # Uniform over types
      q_m_weights <- (1 - lambda_scenario$lambda) * p0_weights +
                     lambda_scenario$lambda * type_weights_m

      # Generate NEW sample from population with Q_m weights
      new_sample <- generate_sample_from_population(
        population, q_m_weights, N_BASELINE
      )

      # Compute treatment effects from this NEW sample
      delta_s <- mean(new_sample$S[new_sample$A == 1]) -
                 mean(new_sample$S[new_sample$A == 0])
      delta_y <- mean(new_sample$Y[new_sample$A == 1]) -
                 mean(new_sample$Y[new_sample$A == 0])

      true_effects[m, ] <- c(delta_s, delta_y)
    }

    # Compute TRUE correlation from population
    true_correlation_scenario <- cor(true_effects[, 1], true_effects[, 2])

    cat(sprintf("  Ground truth from population:\n"))
    cat(sprintf("    Correlation: %.3f\n", true_correlation_scenario))
    cat(sprintf("    SD(ΔS): %.4f\n", sd(true_effects[, 1])))
    cat(sprintf("    SD(ΔY): %.4f\n\n", sd(true_effects[, 2])))

    # Now run replications where method sees finite samples
    cat(sprintf("  Running %d replications (method sees ONE sample each time)...\n",
                N_REPLICATIONS))

    for (rep in 1:N_REPLICATIONS) {
      iteration <- iteration + 1

      if (rep %% 20 == 0 || rep == 1) {
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
        rate <- elapsed / iteration
        remaining <- rate * (total_iterations - iteration)
        cat(sprintf("    Rep %d/%d (%.2f min elapsed, %.1f min remaining)\n",
                    rep, N_REPLICATIONS, elapsed, remaining))
      }

      # Generate ONE observed baseline from population (uniform type weights)
      p0_weights <- rep(1/population$K, population$K)
      observed_baseline <- generate_sample_from_population(
        population, p0_weights, N_BASELINE
      )

      # Estimate correlation using method (method doesn't see population!)
      result <- tryCatch({
        surrogate_inference_if(
          observed_baseline,
          lambda = lambda_scenario$lambda,
          n_innovations = N_INNOVATIONS,
          functional_type = "correlation",
          use_bootstrap = TRUE
        )
      }, error = function(e) {
        list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
      })

      # Check for failure
      if (is.na(result$estimate)) {
        n_degenerate <- n_degenerate + 1
        next
      }

      # Check coverage against POPULATION ground truth
      covered <- (true_correlation_scenario >= result$ci_lower) &&
                 (true_correlation_scenario <= result$ci_upper)

      # Extract values to avoid tibble evaluation issues
      lambda_val <- lambda_scenario$lambda
      lambda_name_val <- lambda_scenario$name
      pop_name_val <- population$name

      # Store results
      new_row <- tibble(
        lambda_scenario = lambda_name_val,
        population_scenario = pop_name_val,
        replication = rep,
        lambda = lambda_val,
        true_correlation = true_correlation_scenario,
        estimate = result$estimate,
        se = result$se,
        ci_lower = result$ci_lower,
        ci_upper = result$ci_upper,
        covered = covered
      )
      validation_results <- bind_rows(validation_results, new_row)
    }
  }
}

cat("\n")
cat("================================================================\n")
cat("VALIDATION RESULTS\n")
cat("================================================================\n\n")

cat(sprintf("Total replications: %d\n", nrow(validation_results)))
cat(sprintf("Degenerate cases: %d\n", n_degenerate))
cat(sprintf("Successful replications: %d\n\n", nrow(validation_results)))

# Compute coverage by scenario
summary_by_scenario <- validation_results %>%
  group_by(lambda_scenario, population_scenario) %>%
  summarise(
    n = n(),
    coverage = mean(covered, na.rm = TRUE),
    bias = mean(estimate - true_correlation, na.rm = TRUE),
    rmse = sqrt(mean((estimate - true_correlation)^2, na.rm = TRUE)),
    mean_se = mean(se, na.rm = TRUE),
    empirical_sd = sd(estimate, na.rm = TRUE),
    se_ratio = mean_se / empirical_sd,
    .groups = "drop"
  )

cat("\n")
cat("================================================================\n")
cat("DETAILED RESULTS BY SCENARIO\n")
cat("================================================================\n\n")

print(summary_by_scenario)

cat("\n")
cat("================================================================\n")
cat("OVERALL SUMMARY\n")
cat("================================================================\n\n")

# Overall statistics
coverage_overall <- mean(validation_results$covered, na.rm = TRUE)
bias_overall <- mean(validation_results$estimate - validation_results$true_correlation, na.rm = TRUE)
se_ratio_overall <- mean(validation_results$se, na.rm = TRUE) / sd(validation_results$estimate, na.rm = TRUE)

cat(sprintf("Total replications: %d across %d scenarios\n\n",
            nrow(validation_results),
            nrow(summary_by_scenario)))

cat("Overall Performance:\n")
cat(sprintf("  Coverage: %.1f%%\n", coverage_overall * 100))
cat(sprintf("  Bias: %.4f\n", bias_overall))
cat(sprintf("  SE/SD ratio: %.2fx\n\n", se_ratio_overall))

# Breakdown by lambda
cat("Coverage by Lambda:\n")
by_lambda <- validation_results %>%
  group_by(lambda_scenario) %>%
  summarise(
    n = n(),
    coverage = mean(covered, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(lambda_scenario)
print(by_lambda)

cat("\nCoverage by Population:\n")
by_pop <- validation_results %>%
  group_by(population_scenario) %>%
  summarise(
    n = n(),
    coverage = mean(covered, na.rm = TRUE),
    bias = mean(estimate - true_correlation, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(population_scenario)
print(by_pop)

cat("\n")
cat("================================================================\n")
cat("INTERPRETATION\n")
cat("================================================================\n\n")

coverage <- coverage_overall

if (coverage >= 0.93 && coverage <= 0.97) {
  cat("✓✓✓ EXCELLENT! Achieves nominal 95% coverage!\n\n")
} else if (coverage >= 0.90 && coverage <= 0.98) {
  cat("✓ GOOD! Achieves acceptable coverage (90-98%)\n\n")
} else {
  cat("✗ Coverage outside acceptable range\n\n")
}

# Bias
bias <- mean(validation_results$estimate - validation_results$true_correlation, na.rm = TRUE)

cat("Bias:\n")
cat(sprintf("  Correlation: %.4f\n\n", bias))

if (abs(bias) < 0.05) {
  cat("✓ Essentially unbiased\n\n")
} else {
  cat("⚠ Notable bias detected\n\n")
}

# SE calibration
se_ratio <- mean(validation_results$se, na.rm = TRUE) / sd(validation_results$estimate, na.rm = TRUE)
cat("SE Calibration:\n")
cat(sprintf("  Mean SE: %.4f\n", mean(validation_results$se, na.rm = TRUE)))
cat(sprintf("  Empirical SD: %.4f\n", sd(validation_results$estimate, na.rm = TRUE)))
cat(sprintf("  SE/SD ratio: %.2f\n\n", se_ratio))

if (se_ratio >= 0.9 && se_ratio <= 1.3) {
  cat("✓ SEs well-calibrated\n\n")
} else if (se_ratio > 1.3) {
  cat("⚠ SEs conservative (CIs wider than needed)\n\n")
} else {
  cat("⚠ SEs anti-conservative (CIs too narrow)\n\n")
}

cat("================================================================\n")
cat("KEY FINDINGS\n")
cat("================================================================\n\n")

cat("WHAT WE TESTED:\n")
cat("  1. Defined population with K types and known parameters\n")
cat("  2. Computed ground truth from population (NEW samples)\n")
cat("  3. Method saw ONE finite sample from population\n")
cat("  4. Checked: Does method CI capture population truth?\n\n")

cat("WHAT THIS VALIDATES:\n")
cat("  • Method works with bootstrap for smooth functionals (correlation)\n")
cat("  • No circularity: ground truth from population, method from sample\n")
cat("  • Coverage tests: Does finite-sample inference work correctly?\n\n")

if (coverage >= 0.90 && abs(bias) < 0.05) {
  cat("✓✓✓ BOOTSTRAP APPROACH VALIDATED!\n\n")
  cat("Conclusion:\n")
  cat(sprintf("  • Coverage: %.1f%% (target: 95%%)\n", coverage * 100))
  cat(sprintf("  • Bias: %.4f (essentially zero)\n", bias))
  cat(sprintf("  • SE calibration: %.2fx\n", se_ratio))
  cat("  • Method correctly estimates population ground truth\n")
  cat("  • Approach works with high-dimensional K\n\n")

  cat("RECOMMENDATION:\n")
  cat("  Use bootstrap (use_bootstrap=TRUE) as default for correlation\n")
  cat("  Estimand: Surrogate quality for new samples from similar populations\n")
  cat("  Functional: Correlation (smooth, well-behaved gradients)\n")
  cat("  Variance: Includes sampling variability\n\n")

  cat("NOTE:\n")
  cat("  • Threshold functionals (PPV/NPV) have gradient issues at boundaries\n")
  cat("  • Correlation functional works reliably across K values\n")
} else {
  cat("⚠ Method has issues - further investigation needed\n")
  cat(sprintf("  Coverage: %.1f%% (should be ≥90%%)\n", coverage * 100))
  cat(sprintf("  Bias: %.4f\n", bias))
}

cat("\n================================================================\n")
cat("Validation complete!\n")
cat("================================================================\n")

# Save results
if (!dir.exists("sims/results")) dir.create("sims/results", recursive = TRUE)
saveRDS(validation_results, "sims/results/18_correlation_validation_results.rds")
cat("\nResults saved to: sims/results/18_correlation_validation_results.rds\n")
