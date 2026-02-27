library(testthat)
library(surrogateTransportability)

test_that("generate_study_data creates data with correct structure", {
  # Test basic data generation
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.5, 0.8),
    treatment_effect_outcome = c(0.3, 0.6),
    surrogate_type = "continuous",
    outcome_type = "continuous"
  )
  
  # Check structure
  expect_s3_class(data, "tbl_df")
  expect_equal(nrow(data), 100)
  expect_true(all(c("class", "A", "X", "S", "Y") %in% names(data)))
  
  # Check treatment assignment
  expect_true(all(data$A %in% c(0, 1)))
  
  # Check latent classes
  expect_true(all(data$class %in% c(1, 2)))
})

test_that("generate_study_data handles binary variables correctly", {
  data <- generate_study_data(
    n = 50,
    treatment_effect_surrogate = c(0.3, 0.7),
    treatment_effect_outcome = c(0.2, 0.8),
    surrogate_type = "binary",
    outcome_type = "binary"
  )
  
  # Check binary variables
  expect_true(all(data$S %in% c(0, 1)))
  expect_true(all(data$Y %in% c(0, 1)))
})

test_that("generate_comparison_scenario works for all scenarios", {
  scenarios <- c("good_innovation_poor_traditional", 
                "poor_innovation_good_traditional", 
                "mixture_structure")
  
  for (scenario in scenarios) {
    data <- generate_comparison_scenario(scenario, n = 100)
    
    expect_s3_class(data, "tbl_df")
    expect_equal(nrow(data), 100)
    expect_true(all(c("class", "A", "X", "S", "Y") %in% names(data)))
  }
})

test_that("generate_study_data validates inputs correctly", {
  # Test invalid n_classes
  expect_error(
    generate_study_data(
      n = 100,
      n_classes = 2,
      treatment_effect_surrogate = c(0.5),  # Wrong length
      treatment_effect_outcome = c(0.3, 0.6)
    )
  )
  
  # Test invalid class_probs
  expect_error(
    generate_study_data(
      n = 100,
      class_probs = c(0.6, 0.3),  # Doesn't sum to 1
      treatment_effect_surrogate = c(0.5, 0.8),
      treatment_effect_outcome = c(0.3, 0.6)
    )
  )
})


