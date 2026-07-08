test_that("generate_nonmediated_heterogeneity creates valid data (types)", {
  dgp <- generate_nonmediated_heterogeneity(
    n = 200,
    heterogeneity_structure = "types",
    K = 8,
    correlation_across = 0.1,
    seed = 123
  )

  # Check structure
  expect_type(dgp, "list")
  expect_named(dgp, c("data", "truth", "scenario"))

  # Check data
  expect_s3_class(dgp$data, "data.frame")
  expect_equal(nrow(dgp$data), 200)
  expect_true(all(c("A", "S", "Y", "X", "type", "U") %in% names(dgp$data)))

  # Check treatment is binary
  expect_true(all(dgp$data$A %in% c(0, 1)))

  # Check types are 1 to K
  expect_true(all(dgp$data$type %in% 1:8))

  # Check truth structure
  expect_true(all(c("type_effects_S", "type_effects_Y", "correlation_across", "P0") %in%
                 names(dgp$truth)))
  expect_length(dgp$truth$type_effects_S, 8)
  expect_length(dgp$truth$type_effects_Y, 8)
  expect_length(dgp$truth$P0, 8)

  # Check correlation is approximately as requested
  actual_cor <- cor(dgp$truth$type_effects_S, dgp$truth$type_effects_Y)
  expect_equal(actual_cor, 0.1, tolerance = 0.15)
})


test_that("generate_nonmediated_heterogeneity creates valid data (continuous)", {
  dgp <- generate_nonmediated_heterogeneity(
    n = 200,
    heterogeneity_structure = "continuous",
    K = 3,
    correlation_across = 0.1,
    seed = 456
  )

  # Check structure
  expect_type(dgp, "list")
  expect_named(dgp, c("data", "truth", "scenario"))

  # Check data
  expect_s3_class(dgp$data, "data.frame")
  expect_equal(nrow(dgp$data), 200)
  expect_true(all(c("A", "S", "Y", "U", "X1", "X2", "X3") %in% names(dgp$data)))

  # Check truth structure
  expect_true(all(c("cate_S", "cate_Y", "beta_S", "beta_Y", "correlation_across") %in%
                 names(dgp$truth)))
  expect_type(dgp$truth$cate_S, "closure")  # Function
  expect_type(dgp$truth$cate_Y, "closure")  # Function
  expect_length(dgp$truth$beta_S, 3)
  expect_length(dgp$truth$beta_Y, 3)
})


test_that("DGP 1 produces expected traditional method failures", {
  skip_if_not_installed("Rsurrogate")
  skip_if_not_installed("mediation")

  dgp <- generate_nonmediated_heterogeneity(
    n = 500,
    heterogeneity_structure = "types",
    K = 16,
    correlation_across = 0.05,  # Nearly independent effects
    correlation_within = 0.5,
    confounding_strength = 0.5,
    seed = 789
  )

  # Traditional methods should give misleading results
  pte_result <- compute_pte_standard(dgp$data, method = "freedman")
  med_result <- compute_mediation_standard(dgp$data, boot = FALSE, sims = 100)

  # PTE should be moderate (misleading "good surrogate")
  # Note: Can be lower with confounding, but should be reasonable
  expect_gt(pte_result$pte, 0.15)
  expect_lt(pte_result$pte, 0.8)

  # Mediation proportion should be moderate (misleading)
  expect_gt(med_result$prop_mediated, 0.2)
  expect_lt(med_result$prop_mediated, 0.8)

  # Within-study correlation should be moderate to high (misleading)
  within_cor <- cor(dgp$data$S, dgp$data$Y)
  expect_gt(within_cor, 0.3)

  # But true across-type correlation should be low (correct assessment)
  true_cor <- cor(dgp$truth$type_effects_S, dgp$truth$type_effects_Y)
  expect_lt(abs(true_cor), 0.35)  # Should be near 0.05 target, but allow variation
})


test_that("DGP 1 truth values are stored correctly", {
  dgp <- generate_nonmediated_heterogeneity(
    n = 300,
    K = 10,
    seed = 111
  )

  # Check expected values are computed
  expect_type(dgp$truth$expected_pte, "double")
  expect_type(dgp$truth$expected_within_cor, "double")
  expect_type(dgp$truth$expected_mediation, "double")

  # All should be finite
  expect_true(is.finite(dgp$truth$expected_pte))
  expect_true(is.finite(dgp$truth$expected_within_cor))
  expect_true(is.finite(dgp$truth$expected_mediation))
})


test_that("DGP 1 scenario metadata is informative", {
  dgp <- generate_nonmediated_heterogeneity(n = 200, K = 8, seed = 222)

  # Check scenario metadata
  expect_equal(dgp$scenario$name, "Non-Mediated Heterogeneity (DGP 1)")
  expect_type(dgp$scenario$why_traditional_fails, "character")
  expect_type(dgp$scenario$why_tvball_works, "character")

  # Explanations should be non-empty
  expect_gt(nchar(dgp$scenario$why_traditional_fails), 50)
  expect_gt(nchar(dgp$scenario$why_tvball_works), 50)
})


test_that("DGP 1 handles different correlation targets", {
  # Test with near-zero correlation
  dgp_zero <- generate_nonmediated_heterogeneity(
    n = 300,
    K = 12,
    correlation_across = 0.0,
    seed = 333
  )

  cor_zero <- cor(dgp_zero$truth$type_effects_S, dgp_zero$truth$type_effects_Y)
  expect_lt(abs(cor_zero), 0.25)  # Allow more variation for small K

  # Test with small positive correlation
  dgp_pos <- generate_nonmediated_heterogeneity(
    n = 300,
    K = 12,
    correlation_across = 0.2,
    seed = 444
  )

  cor_pos <- cor(dgp_pos$truth$type_effects_S, dgp_pos$truth$type_effects_Y)
  expect_gt(cor_pos, -0.10)  # Allow some negative due to sampling variation with K=12
  expect_lt(cor_pos, 0.50)  # Allow some overshoot

  # Test with small negative correlation
  dgp_neg <- generate_nonmediated_heterogeneity(
    n = 300,
    K = 12,
    correlation_across = -0.1,
    seed = 555
  )

  cor_neg <- cor(dgp_neg$truth$type_effects_S, dgp_neg$truth$type_effects_Y)
  expect_lt(cor_neg, 0.05)
  expect_gt(cor_neg, -0.25)
})


test_that("DGP 1 confounder creates within-study correlation", {
  # High confounding
  dgp_high <- generate_nonmediated_heterogeneity(
    n = 400,
    K = 8,
    confounding_strength = 0.8,
    seed = 666
  )

  cor_high <- cor(dgp_high$data$S, dgp_high$data$Y)

  # Low confounding
  dgp_low <- generate_nonmediated_heterogeneity(
    n = 400,
    K = 8,
    confounding_strength = 0.2,
    seed = 777
  )

  cor_low <- cor(dgp_low$data$S, dgp_low$data$Y)

  # High confounding should create higher within-study correlation
  expect_gt(cor_high, cor_low)
})


test_that("DGP 1 validates parameters", {
  # Invalid n
  expect_error(
    generate_nonmediated_heterogeneity(n = 0),
    "n > 0"
  )

  # Invalid correlation_within
  expect_error(
    generate_nonmediated_heterogeneity(n = 100, correlation_within = 1.5)
  )

  # Invalid K
  expect_error(
    generate_nonmediated_heterogeneity(n = 100, K = 1),
    "K >= 2"
  )
})


test_that("DGP 1 is reproducible with seed", {
  dgp1 <- generate_nonmediated_heterogeneity(n = 200, K = 8, seed = 999)
  dgp2 <- generate_nonmediated_heterogeneity(n = 200, K = 8, seed = 999)

  # Data should be identical
  expect_equal(dgp1$data$A, dgp2$data$A)
  expect_equal(dgp1$data$S, dgp2$data$S)
  expect_equal(dgp1$data$Y, dgp2$data$Y)
  expect_equal(dgp1$data$type, dgp2$data$type)

  # Truth should be identical
  expect_equal(dgp1$truth$type_effects_S, dgp2$truth$type_effects_S)
  expect_equal(dgp1$truth$type_effects_Y, dgp2$truth$type_effects_Y)
})
