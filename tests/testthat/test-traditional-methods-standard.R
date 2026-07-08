test_that("validate_method_availability works", {
  availability <- validate_method_availability()

  expect_type(availability, "logical")
  expect_named(availability, c("Rsurrogate", "mediation", "pseval"))

  # These should all be TRUE after package installation
  expect_true(availability["Rsurrogate"])
  expect_true(availability["mediation"])
  expect_true(availability["pseval"])
})


test_that("compute_pte_standard works and agrees with native", {
  skip_if_not_installed("Rsurrogate")

  # Generate simple test data
  set.seed(123)
  n <- 200
  data <- tibble::tibble(
    A = rbinom(n, 1, 0.5),
    S = rnorm(n, mean = 0.5 * A, sd = 1),
    Y = rnorm(n, mean = 0.3 * A + 0.4 * S, sd = 1)
  )

  # Compute using both methods
  native <- compute_pte(data)
  standard <- compute_pte_standard(data, method = "freedman")

  # Results should be similar (within 10% relative difference)
  expect_type(standard$pte, "double")
  expect_type(standard$se, "double")
  expect_type(standard$interpretation, "logical")

  # Check agreement (allowing some numerical difference)
  rel_diff <- abs(native - standard$pte) / abs(native)
  expect_lt(rel_diff, 0.15,
           label = sprintf("Native: %.3f, Standard: %.3f", native, standard$pte))

  # Check CI is reasonable
  expect_lt(standard$ci_lower, standard$pte)
  expect_gt(standard$ci_upper, standard$pte)
})


test_that("compute_mediation_standard works and agrees with native", {
  skip_if_not_installed("mediation")

  # Generate simple test data
  set.seed(456)
  n <- 200
  data <- tibble::tibble(
    A = rbinom(n, 1, 0.5),
    X = rnorm(n),
    S = rnorm(n, mean = 0.5 * A + 0.3 * X, sd = 1),
    Y = rnorm(n, mean = 0.3 * A + 0.4 * S + 0.2 * X, sd = 1)
  )

  # Compute using both methods
  native <- compute_mediation_effects(data)
  standard <- compute_mediation_standard(data, boot = FALSE, sims = 100)

  # Results should be similar
  expect_type(standard$acme, "double")
  expect_type(standard$ade, "double")
  expect_type(standard$total_effect, "double")
  expect_type(standard$prop_mediated, "double")
  expect_type(standard$interpretation, "logical")

  # Check agreement on proportion mediated
  rel_diff <- abs(native$proportion_mediated - standard$prop_mediated) /
              abs(native$proportion_mediated)
  expect_lt(rel_diff, 0.20,
           label = sprintf("Native: %.3f, Standard: %.3f",
                         native$proportion_mediated, standard$prop_mediated))

  # Check total effect decomposition
  total_from_components <- standard$acme + standard$ade
  expect_equal(total_from_components, standard$total_effect, tolerance = 0.01)
})


test_that("compare_native_vs_standard produces comparison table", {
  skip_if_not_installed("Rsurrogate")
  skip_if_not_installed("mediation")

  # Generate test data
  set.seed(789)
  n <- 200
  data <- tibble::tibble(
    A = rbinom(n, 1, 0.5),
    S = rnorm(n, mean = 0.5 * A, sd = 1),
    Y = rnorm(n, mean = 0.3 * A + 0.4 * S, sd = 1)
  )

  # Compare methods
  comparison <- compare_native_vs_standard(data, methods = c("pte", "mediation"))

  # Check structure
  expect_s3_class(comparison, "data.frame")
  expect_true(all(c("method", "native_estimate", "standard_estimate",
                   "difference", "relative_difference", "agree") %in% names(comparison)))

  # Should have 2 rows (PTE and mediation)
  expect_equal(nrow(comparison), 2)

  # Estimates should be numeric
  expect_type(comparison$native_estimate, "double")
  expect_type(comparison$standard_estimate, "double")

  # Agreement should be logical
  expect_type(comparison$agree, "logical")
})


test_that("PTE wrapper handles edge cases", {
  skip_if_not_installed("Rsurrogate")

  # Case 1: Very small treatment effect
  set.seed(111)
  n <- 100
  data_small_effect <- tibble::tibble(
    A = rbinom(n, 1, 0.5),
    S = rnorm(n, mean = 0.01 * A, sd = 1),
    Y = rnorm(n, mean = 0.01 * A + 0.5 * S, sd = 1)
  )

  expect_no_error({
    result <- compute_pte_standard(data_small_effect, method = "freedman")
  })

  # Case 2: Perfect mediation (PTE ≈ 1)
  set.seed(222)
  data_perfect <- tibble::tibble(
    A = rbinom(n, 1, 0.5),
    S = rnorm(n, mean = 1.0 * A, sd = 0.1),
    Y = S + rnorm(n, sd = 0.1)
  )

  result_perfect <- compute_pte_standard(data_perfect, method = "freedman")
  expect_gt(result_perfect$pte, 0.8,
           label = "PTE should be high for perfect mediation")
})


test_that("Mediation wrapper handles covariates", {
  skip_if_not_installed("mediation")

  # Generate data with confounders
  set.seed(333)
  n <- 200
  data <- tibble::tibble(
    X1 = rnorm(n),
    X2 = rnorm(n),
    A = rbinom(n, 1, 0.5),
    S = rnorm(n, mean = 0.5 * A + 0.3 * X1 + 0.2 * X2, sd = 1),
    Y = rnorm(n, mean = 0.3 * A + 0.4 * S + 0.3 * X1 + 0.1 * X2, sd = 1)
  )

  # With covariate adjustment
  result_adjusted <- compute_mediation_standard(data,
                                                covariates = c("X1", "X2"),
                                                boot = FALSE,
                                                sims = 100)

  # Without covariate adjustment
  result_unadjusted <- compute_mediation_standard(data, boot = FALSE, sims = 100)

  # Results should differ (confounding affects estimates)
  expect_false(isTRUE(all.equal(result_adjusted$prop_mediated,
                                result_unadjusted$prop_mediated,
                                tolerance = 0.05)))
})


test_that("compute_ps_standard gives appropriate message for non-time-to-event data", {
  skip_if_not_installed("pseval")

  # Regular continuous data (not time-to-event)
  set.seed(444)
  n <- 100
  data_wrong_format <- tibble::tibble(
    A = rbinom(n, 1, 0.5),
    S = rnorm(n),
    Y = rnorm(n)
  )

  # Should error because missing time-to-event structure
  expect_error(
    compute_ps_standard(data_wrong_format),
    "must contain columns.*Y_time.*Y_event"
  )
})
