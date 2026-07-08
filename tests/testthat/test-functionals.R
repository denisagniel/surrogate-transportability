library(testthat)
library(surrogateTransportability)

create_test_treatment_effects <- function() {
  data.frame(
    delta_s = c(0.2, 0.5, 0.8, 0.3, 0.6, 0.9, 0.1, 0.4, 0.7, 0.5),
    delta_y = c(0.1, 0.4, 0.7, 0.2, 0.5, 0.8, 0.05, 0.3, 0.6, 0.4)
  )
}

test_that("functional_correlation computes across-study correlation", {
  te <- create_test_treatment_effects()
  correlation <- functional_correlation(te)
  expect_type(correlation, "double")
  expect_equal(correlation, cor(te$delta_s, te$delta_y))
  expect_true(correlation >= -1 && correlation <= 1)
})

test_that("functional_correlation supports rank methods", {
  te <- create_test_treatment_effects()
  expect_equal(functional_correlation(te, "spearman"),
               cor(te$delta_s, te$delta_y, method = "spearman"))
  expect_equal(functional_correlation(te, "kendall"),
               cor(te$delta_s, te$delta_y, method = "kendall"))
})

test_that("functional_correlation rejects wrong input", {
  expect_error(functional_correlation(data.frame(x = 1:3, y = 4:6)), "delta_s")
  expect_error(
    functional_correlation(data.frame(A = 0:1, S = 1:2, Y = 3:4)),
    "across-study"
  )
})
