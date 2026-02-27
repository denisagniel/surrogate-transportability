library(testthat)
library(surrogateTransportability)

# Create test data for functionals
create_test_treatment_effects <- function() {
  tibble::tibble(
    delta_s = c(0.2, 0.5, 0.8, 0.3, 0.6, 0.9, 0.1, 0.4, 0.7, 0.5),
    delta_y = c(0.1, 0.4, 0.7, 0.2, 0.5, 0.8, 0.05, 0.3, 0.6, 0.4)
  )
}

test_that("functional_correlation works correctly", {
  treatment_effects <- create_test_treatment_effects()
  
  # Compute correlation
  correlation <- functional_correlation(treatment_effects)
  
  # Check that correlation is numeric and in valid range
  expect_type(correlation, "double")
  expect_true(is.finite(correlation))
  expect_true(correlation >= -1 && correlation <= 1)
})

test_that("functional_probability works correctly", {
  treatment_effects <- create_test_treatment_effects()
  
  # Compute probability functional
  probability <- functional_probability(treatment_effects, epsilon_s = 0.3, epsilon_y = 0.2)
  
  # Check that probability is numeric and in valid range
  expect_type(probability, "double")
  expect_true(is.finite(probability))
  expect_true(probability >= 0 && probability <= 1)
})

test_that("functional_conditional_mean works correctly", {
  treatment_effects <- create_test_treatment_effects()
  
  # Compute conditional mean
  conditional_mean <- functional_conditional_mean(treatment_effects, delta_s_value = 0.5)
  
  # Check that conditional mean is numeric
  expect_type(conditional_mean, "double")
  expect_true(is.finite(conditional_mean))
})

test_that("compute_all_functionals works correctly", {
  treatment_effects <- create_test_treatment_effects()
  
  # Compute all functionals
  functionals <- compute_all_functionals(
    treatment_effects,
    epsilon_s = 0.3,
    epsilon_y = 0.2,
    delta_s_values = c(0.3, 0.5, 0.7)
  )
  
  # Check structure
  expect_type(functionals, "list")
  expect_true(all(c("correlation", "probability", "conditional_means") %in% names(functionals)))
  
  # Check correlation
  expect_type(functionals$correlation, "double")
  expect_true(is.finite(functionals$correlation))
  
  # Check probability
  expect_type(functionals$probability, "double")
  expect_true(is.finite(functionals$probability))
  
  # Check conditional means
  expect_type(functionals$conditional_means, "double")
  expect_equal(length(functionals$conditional_means), 3)
  expect_true(all(is.finite(functionals$conditional_means)))
})

test_that("compute_functional_with_ci works correctly", {
  treatment_effects <- create_test_treatment_effects()
  
  # Compute functional with CI
  result <- compute_functional_with_ci(
    treatment_effects, 
    "correlation", 
    n_bootstrap = 100
  )
  
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

test_that("functionals handle edge cases correctly", {
  # Test with no observations meeting criteria
  treatment_effects <- tibble::tibble(
    delta_s = c(0.1, 0.2, 0.15, 0.18, 0.12),
    delta_y = c(0.05, 0.1, 0.08, 0.09, 0.06)
  )
  
  # This should return NA for probability functional
  probability <- functional_probability(treatment_effects, epsilon_s = 0.5, epsilon_y = 0.3)
  expect_true(is.na(probability))
})


