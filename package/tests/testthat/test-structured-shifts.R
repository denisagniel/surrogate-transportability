# Tests for structured shift DGPs (covariate shift and selection)

test_that("generate_covariate_shift_study produces valid output", {
  # Generate baseline study
  baseline <- generate_study_data(
    n = 200,
    n_classes = 2,
    class_probs = c(0.5, 0.5),
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 123
  )

  # Generate covariate shift study
  shifted <- generate_covariate_shift_study(
    baseline,
    target_class_probs = c(0.7, 0.3),
    seed = 456
  )

  # Check structure
  expect_type(shifted, "list")
  expect_true("future_study" %in% names(shifted))
  expect_true("tv_distance" %in% names(shifted))
  expect_true("baseline_class_probs" %in% names(shifted))
  expect_true("target_class_probs" %in% names(shifted))

  # Check future study has correct structure
  expect_s3_class(shifted$future_study, "tbl_df")
  expect_equal(nrow(shifted$future_study), 200)
  expect_true(all(c("class", "A", "X", "S", "Y") %in% names(shifted$future_study)))

  # Check class probabilities approximately match target
  future_class_probs <- as.numeric(table(shifted$future_study$class) / nrow(shifted$future_study))
  expect_equal(future_class_probs, c(0.7, 0.3), tolerance = 0.1)

  # Check TV distance is positive and reasonable
  expect_true(shifted$tv_distance > 0)
  expect_true(shifted$tv_distance < 1)

  # Check shift magnitude
  expect_equal(shifted$shift_magnitude, 0.2, tolerance = 0.02)
})

test_that("generate_covariate_shift_study validates inputs", {
  baseline <- generate_study_data(
    n = 100,
    n_classes = 2,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 123
  )

  # Wrong length of target_class_probs
  expect_error(
    generate_covariate_shift_study(baseline, target_class_probs = c(0.5)),
    "must have length"
  )

  # target_class_probs don't sum to 1
  expect_error(
    generate_covariate_shift_study(baseline, target_class_probs = c(0.5, 0.6)),
    "must sum to 1"
  )
})

test_that("generate_selection_study produces valid output", {
  # Generate baseline study
  baseline <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    surrogate_type = "continuous",
    outcome_type = "continuous",
    seed = 123
  )

  # Test outcome_favorable selection
  selected_favorable <- generate_selection_study(
    baseline,
    selection_type = "outcome_favorable",
    selection_strength = 0.7,
    seed = 456
  )

  expect_type(selected_favorable, "list")
  expect_true("future_study" %in% names(selected_favorable))
  expect_true("selection_weights" %in% names(selected_favorable))
  expect_true("effective_sample_size" %in% names(selected_favorable))

  # Check future study structure
  expect_s3_class(selected_favorable$future_study, "tbl_df")
  expect_equal(nrow(selected_favorable$future_study), 200)

  # Check selection weights
  expect_equal(length(selected_favorable$selection_weights), nrow(baseline))
  expect_equal(sum(selected_favorable$selection_weights), 1, tolerance = 1e-10)

  # Check effective sample size
  expect_true(selected_favorable$effective_sample_size > 0)
  expect_true(selected_favorable$effective_sample_size <= nrow(baseline))

  # With strong selection, future study should have higher average Y
  baseline_mean_y <- mean(baseline$Y)
  future_mean_y <- mean(selected_favorable$future_study$Y)
  expect_true(future_mean_y > baseline_mean_y)
})

test_that("generate_selection_study with different selection types", {
  baseline <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    surrogate_type = "continuous",
    outcome_type = "continuous",
    seed = 123
  )

  # Test different selection types
  selection_types <- c("outcome_favorable", "outcome_unfavorable",
                      "treatment_responders", "treatment_nonresponders",
                      "covariate_extreme")

  for (sel_type in selection_types) {
    result <- generate_selection_study(
      baseline,
      selection_type = sel_type,
      selection_strength = 0.5,
      seed = 789
    )

    expect_type(result, "list")
    expect_equal(result$selection_type, sel_type)
    expect_equal(nrow(result$future_study), nrow(baseline))
  }
})

test_that("generate_selection_study with zero strength gives uniform sampling", {
  baseline <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 123
  )

  # Zero selection strength should be like uniform sampling
  selected <- generate_selection_study(
    baseline,
    selection_type = "outcome_favorable",
    selection_strength = 0,
    seed = 456
  )

  # All weights should be approximately equal
  expect_equal(var(selected$selection_weights), 0, tolerance = 1e-10)

  # Effective sample size should be close to actual sample size
  expect_equal(selected$effective_sample_size, nrow(baseline), tolerance = 1)
})

test_that("generate_selection_study validates inputs", {
  baseline <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 123
  )

  # Invalid selection_strength
  expect_error(
    generate_selection_study(baseline, selection_strength = 1.5),
    "must be in"
  )

  expect_error(
    generate_selection_study(baseline, selection_strength = -0.1),
    "must be in"
  )

  # Custom without function
  expect_error(
    generate_selection_study(baseline, selection_type = "custom"),
    "selection_function must be provided"
  )
})

test_that("generate_selection_study works with binary outcomes", {
  baseline <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.3, 0.7),
    treatment_effect_outcome = c(0.2, 0.8),
    surrogate_type = "binary",
    outcome_type = "binary",
    seed = 123
  )

  selected <- generate_selection_study(
    baseline,
    selection_type = "outcome_favorable",
    selection_strength = 0.8,
    seed = 456
  )

  expect_type(selected, "list")
  expect_s3_class(selected$future_study, "tbl_df")

  # With strong selection for outcome_favorable, Y=1 should be more common
  baseline_prop_y1 <- mean(baseline$Y)
  future_prop_y1 <- mean(selected$future_study$Y)
  expect_true(future_prop_y1 > baseline_prop_y1)
})

test_that("tv_distance_empirical computes distances correctly", {
  # Identical data should have TV distance = 0
  data1 <- generate_study_data(
    n = 200,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 123
  )
  data2 <- data1

  tv_dist <- tv_distance_empirical(data1, data2)
  expect_equal(tv_dist, 0, tolerance = 1e-10)

  # Different data should have positive TV distance
  data3 <- generate_study_data(
    n = 200,
    class_probs = c(0.7, 0.3),
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 456
  )
  tv_dist2 <- tv_distance_empirical(data1, data3)
  expect_true(tv_dist2 > 0)
  expect_true(tv_dist2 <= 1)
})

test_that("tv_distance_empirical validates inputs", {
  data1 <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 123
  )
  data2 <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8),
    seed = 456
  )

  # Missing variables
  expect_error(
    tv_distance_empirical(data1, data2, variables = c("A", "S", "Z")),
    "Not all variables found"
  )
})

test_that("covariate shift preserves conditional distributions", {
  # Generate baseline with clear class structure
  baseline <- generate_study_data(
    n = 500,
    n_classes = 2,
    class_probs = c(0.5, 0.5),
    treatment_effect_surrogate = c(0.2, 0.8),
    treatment_effect_outcome = c(0.1, 0.9),
    surrogate_type = "continuous",
    outcome_type = "continuous",
    seed = 123
  )

  # Generate shifted study
  shifted <- generate_covariate_shift_study(
    baseline,
    target_class_probs = c(0.8, 0.2),
    n = 500,
    seed = 456
  )

  # Within each class, distributions should be similar
  for (class_val in 1:2) {
    baseline_class <- baseline[baseline$class == class_val, ]
    shifted_class <- shifted$future_study[shifted$future_study$class == class_val, ]

    if (nrow(baseline_class) > 10 && nrow(shifted_class) > 10) {
      # Mean S should be similar within class
      expect_equal(mean(baseline_class$S), mean(shifted_class$S), tolerance = 0.3)
      # Mean Y should be similar within class
      expect_equal(mean(baseline_class$Y), mean(shifted_class$Y), tolerance = 0.3)
    }
  }
})
