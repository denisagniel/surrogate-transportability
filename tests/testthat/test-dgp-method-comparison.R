test_that("generate_high_cor_low_pte produces valid data", {
  dgp <- generate_high_cor_low_pte(n = 100, seed = 123)

  # Check structure
  expect_type(dgp, "list")
  expect_named(dgp, c("data", "truth"))

  # Check data
  expect_s3_class(dgp$data, "tbl_df")
  expect_equal(nrow(dgp$data), 100)
  expect_named(dgp$data, c("X", "A", "S", "Y"))

  # Check all variables are binary
  expect_true(all(dgp$data$X %in% c(0, 1)))
  expect_true(all(dgp$data$A %in% c(0, 1)))
  expect_true(all(dgp$data$S %in% c(0, 1)))
  expect_true(all(dgp$data$Y %in% c(0, 1)))

  # Check truth
  expect_type(dgp$truth, "list")
  expect_equal(dgp$truth$scenario, "high_cor_low_pte")
  expect_true(dgp$truth$is_transportable)
})

test_that("generate_moderate_cor_high_pte produces valid data", {
  dgp <- generate_moderate_cor_high_pte(n = 100, seed = 456)

  # Check structure
  expect_type(dgp, "list")
  expect_named(dgp, c("data", "truth"))

  # Check data
  expect_s3_class(dgp$data, "tbl_df")
  expect_equal(nrow(dgp$data), 100)
  expect_named(dgp$data, c("X", "A", "S", "Y"))

  # Check all variables are binary
  expect_true(all(dgp$data$X %in% c(0, 1)))
  expect_true(all(dgp$data$A %in% c(0, 1)))
  expect_true(all(dgp$data$S %in% c(0, 1)))
  expect_true(all(dgp$data$Y %in% c(0, 1)))

  # Check truth
  expect_equal(dgp$truth$scenario, "moderate_cor_high_pte")
  expect_false(dgp$truth$is_transportable)
})

test_that("high_cor_low_pte has expected treatment effect patterns", {
  dgp <- generate_high_cor_low_pte(n = 1000, seed = 789)
  data <- dgp$data

  # Treatment effect on S should vary with X (A×X interaction)
  delta_s_x0 <- mean(data$S[data$A == 1 & data$X == 0]) -
                mean(data$S[data$A == 0 & data$X == 0])
  delta_s_x1 <- mean(data$S[data$A == 1 & data$X == 1]) -
                mean(data$S[data$A == 0 & data$X == 1])

  expect_true(abs(delta_s_x1 - delta_s_x0) > 0.1,
              label = "Treatment effect on S should vary with X")

  # Treatment effect on Y should vary with X (A×X interaction)
  delta_y_x0 <- mean(data$Y[data$A == 1 & data$X == 0]) -
                mean(data$Y[data$A == 0 & data$X == 0])
  delta_y_x1 <- mean(data$Y[data$A == 1 & data$X == 1]) -
                mean(data$Y[data$A == 0 & data$X == 1])

  expect_true(abs(delta_y_x1 - delta_y_x0) > 0.1,
              label = "Treatment effect on Y should vary with X")
})

test_that("moderate_cor_high_pte has expected treatment effect patterns", {
  dgp <- generate_moderate_cor_high_pte(n = 1000, seed = 987)
  data <- dgp$data

  # Treatment effect on S should NOT vary with X (no A×X interaction)
  delta_s_x0 <- mean(data$S[data$A == 1 & data$X == 0]) -
                mean(data$S[data$A == 0 & data$X == 0])
  delta_s_x1 <- mean(data$S[data$A == 1 & data$X == 1]) -
                mean(data$S[data$A == 0 & data$X == 1])

  expect_true(abs(delta_s_x1 - delta_s_x0) < 0.15,
              label = "Treatment effect on S should be constant across X")

  # S should have strong effect on Y
  # (Can check via stratified analysis)
  y_s1 <- mean(data$Y[data$S == 1])
  y_s0 <- mean(data$Y[data$S == 0])

  expect_true(abs(y_s1 - y_s0) > 0.2,
              label = "S should have substantial effect on Y")
})

test_that("generate_future_study_effects produces valid output", {
  dgp <- generate_high_cor_low_pte(n = 500, seed = 111)
  future_effects <- generate_future_study_effects(dgp$data, M = 20, seed = 222)

  # Check structure
  expect_s3_class(future_effects, "tbl_df")
  expect_equal(nrow(future_effects), 20)
  expect_named(future_effects, c("study_id", "p_x", "delta_s", "delta_y"))

  # Check study IDs
  expect_equal(future_effects$study_id, 1:20)

  # Check p_x values are in range
  expect_true(all(future_effects$p_x >= 0.1 & future_effects$p_x <= 0.9))

  # Check treatment effects are numeric
  expect_type(future_effects$delta_s, "double")
  expect_type(future_effects$delta_y, "double")
})

test_that("generate_future_study_effects handles edge cases", {
  # Small dataset
  dgp <- generate_high_cor_low_pte(n = 50, seed = 333)
  future_effects <- generate_future_study_effects(dgp$data, M = 10, seed = 444)

  expect_s3_class(future_effects, "tbl_df")
  expect_equal(nrow(future_effects), 10)

  # Should handle resampling with replacement
  expect_true(all(!is.na(future_effects$delta_s) | !is.na(future_effects$delta_y)))
})

test_that("across-study correlation differs between scenarios", {
  # Generate larger samples for stable estimates
  set.seed(555)

  # Scenario 1: High correlation
  dgp1 <- generate_high_cor_low_pte(n = 1000)
  effects1 <- generate_future_study_effects(dgp1$data, M = 100)
  cor1 <- cor(effects1$delta_s, effects1$delta_y, use = "complete.obs")

  # Scenario 2: Moderate correlation
  dgp2 <- generate_moderate_cor_high_pte(n = 1000)
  effects2 <- generate_future_study_effects(dgp2$data, M = 100)
  cor2 <- cor(effects2$delta_s, effects2$delta_y, use = "complete.obs")

  # Correlation should be higher in scenario 1
  expect_true(cor1 > cor2,
              label = "Scenario 1 should have higher across-study correlation")

  # Scenario 1 correlation should be high
  expect_true(cor1 > 0.6,
              label = "Scenario 1 correlation should be > 0.6")
})

test_that("generate functions respect seed", {
  dgp1a <- generate_high_cor_low_pte(n = 100, seed = 999)
  dgp1b <- generate_high_cor_low_pte(n = 100, seed = 999)

  expect_equal(dgp1a$data, dgp1b$data)

  dgp2a <- generate_moderate_cor_high_pte(n = 100, seed = 888)
  dgp2b <- generate_moderate_cor_high_pte(n = 100, seed = 888)

  expect_equal(dgp2a$data, dgp2b$data)
})
