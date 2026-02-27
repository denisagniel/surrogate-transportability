library(testthat)
library(surrogateTransportability)

test_that("compute_treatment_effect works for randomized studies", {
  # Generate test data
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.6),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )
  
  # Compute treatment effects
  delta_s <- compute_treatment_effect(data, "S", study_type = "randomized")
  delta_y <- compute_treatment_effect(data, "Y", study_type = "randomized")
  
  # Check that effects are numeric
  expect_type(delta_s, "double")
  expect_type(delta_y, "double")
  
  # Check that effects are finite
  expect_true(is.finite(delta_s))
  expect_true(is.finite(delta_y))
})

test_that("compute_treatment_effect works for observational studies", {
  # Generate test data
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.6),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )
  
  # Compute treatment effects with covariate adjustment
  delta_s <- compute_treatment_effect(data, "S", 
                                    study_type = "observational", 
                                    covariates = "X")
  delta_y <- compute_treatment_effect(data, "Y", 
                                    study_type = "observational", 
                                    covariates = "X")
  
  # Check that effects are numeric
  expect_type(delta_s, "double")
  expect_type(delta_y, "double")
  
  # Check that effects are finite
  expect_true(is.finite(delta_s))
  expect_true(is.finite(delta_y))
})

test_that("compute_multiple_treatment_effects works correctly", {
  # Generate test data
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.6),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )
  
  # Compute multiple treatment effects
  effects <- compute_multiple_treatment_effects(data, c("S", "Y"))
  
  # Check structure
  expect_type(effects, "double")
  expect_equal(length(effects), 2)
  expect_equal(names(effects), c("S", "Y"))
  
  # Check that effects are finite
  expect_true(all(is.finite(effects)))
})

test_that("compute_treatment_effect_with_ci works correctly", {
  # Generate test data
  data <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.6),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )
  
  # Compute treatment effect with CI
  result <- compute_treatment_effect_with_ci(data, "S", n_bootstrap = 100)
  
  # Check structure
  expect_type(result, "list")
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "bootstrap_samples") %in% names(result)))
  
  # Check that estimate is finite
  expect_true(is.finite(result$estimate))
  
  # Check that CI bounds are ordered correctly
  expect_true(result$ci_lower <= result$estimate)
  expect_true(result$estimate <= result$ci_upper)
  
  # Check bootstrap samples
  expect_equal(length(result$bootstrap_samples), 100)
  expect_true(all(is.finite(result$bootstrap_samples)))
})


