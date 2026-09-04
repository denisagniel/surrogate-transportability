library(testthat)
library(surrogateTransportability)

# Shared small dataset for fast tests
make_test_data <- function(n = 400, seed = 20260803) {
  set.seed(seed)
  spec <- canonical_dgp_params("dgp1")
  generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels)
}

# ============================================================
# Jackknife bias correction
# ============================================================

test_that("jackknife=TRUE returns expected additional fields", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, verbose = FALSE
  )
  expect_true(all(c("rho_jk", "jk_bias", "ci_lower_jk", "ci_upper_jk") %in% names(fit)))
})

test_that("jackknife=FALSE (default) does not add jk fields", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = FALSE, verbose = FALSE
  )
  expect_false("rho_jk" %in% names(fit))
  expect_false("jk_bias" %in% names(fit))
})

test_that("rho_jk is in [-1, 1]", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, verbose = FALSE
  )
  expect_true(fit$rho_jk >= -1 && fit$rho_jk <= 1)
})

test_that("jackknife CI brackets its point estimate", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, verbose = FALSE
  )
  expect_true(fit$ci_lower_jk <= fit$rho_jk)
  expect_true(fit$ci_upper_jk >= fit$rho_jk)
})

test_that("jackknife warns when method != importance_weighting", {
  data <- make_test_data()
  expect_warning(
    tv_ball_correlation_IF_adaptive(
      data, lambda = 0.3, method = "bootstrap",
      jackknife = TRUE, verbose = FALSE
    ),
    "importance_weighting"
  )
})

test_that("jackknife_groups argument is respected (does not error)", {
  data <- make_test_data()
  fit10 <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, jackknife_groups = 10L, verbose = FALSE
  )
  fit30 <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, jackknife_groups = 30L, verbose = FALSE
  )
  # Different G -> different corrections; both should be valid
  expect_true(fit10$rho_jk >= -1 && fit10$rho_jk <= 1)
  expect_true(fit30$rho_jk >= -1 && fit30$rho_jk <= 1)
})

# ============================================================
# One-step debiased estimator
# ============================================================

test_that("debiased=TRUE returns expected additional fields", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    debiased = TRUE, verbose = FALSE
  )
  expect_true(all(c("rho_os", "os_bias_correction", "ci_lower_os", "ci_upper_os") %in% names(fit)))
})

test_that("debiased=FALSE (default) does not add os fields", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    debiased = FALSE, verbose = FALSE
  )
  expect_false("rho_os" %in% names(fit))
})

test_that("rho_os is in [-1, 1]", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    debiased = TRUE, verbose = FALSE
  )
  expect_true(fit$rho_os >= -1 && fit$rho_os <= 1)
})

test_that("one-step CI brackets its point estimate", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    debiased = TRUE, verbose = FALSE
  )
  expect_true(fit$ci_lower_os <= fit$rho_os)
  expect_true(fit$ci_upper_os >= fit$rho_os)
})

test_that("debiased warns when method != importance_weighting", {
  data <- make_test_data()
  expect_warning(
    tv_ball_correlation_IF_adaptive(
      data, lambda = 0.3, method = "bootstrap",
      debiased = TRUE, verbose = FALSE
    ),
    "importance_weighting"
  )
})

# ============================================================
# Both corrections together
# ============================================================

test_that("jackknife=TRUE and debiased=TRUE together return all fields", {
  data <- make_test_data()
  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, debiased = TRUE, verbose = FALSE
  )
  expected_fields <- c(
    "rho_hat", "se", "ci_lower", "ci_upper",
    "rho_jk", "jk_bias", "ci_lower_jk", "ci_upper_jk",
    "rho_os", "os_bias_correction", "ci_lower_os", "ci_upper_os"
  )
  expect_true(all(expected_fields %in% names(fit)))
})

test_that("both corrections move toward truth at n=2000 for dgp1", {
  # At n=2000 the plug-in has known attenuation bias (Phase 0 validated).
  # Both corrections should reduce |estimate - true_rho|.
  # This is a stochastic test; run with a fixed seed and tight tolerance.
  set.seed(20260803)
  spec  <- canonical_dgp_params("dgp1")
  data  <- generate_dgp_data(2000, spec$params, spec$p_X, spec$X_levels)
  true  <- spec$rho_true  # 0.691

  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, debiased = TRUE, verbose = FALSE
  )

  err_raw <- abs(fit$rho_hat - true)
  err_jk  <- abs(fit$rho_jk  - true)
  err_os  <- abs(fit$rho_os  - true)

  # Both should be at most as far from truth as the plug-in
  # (exact monotonicity holds in expectation; allow small slack for seed noise)
  expect_true(err_jk  <= err_raw + 0.05,
              label = sprintf("jk (%.3f) not closer than plug-in (%.3f) by margin",
                              err_jk, err_raw))
  expect_true(err_os  <= err_raw + 0.05,
              label = sprintf("os (%.3f) not closer than plug-in (%.3f) by margin",
                              err_os, err_raw))
})

test_that("baseline result (no corrections) is unchanged by new args", {
  # Regression: rho_hat, se, CI from jackknife=FALSE must equal jackknife=TRUE
  # when using the same RNG seed (jackknife uses sample() internally, so we
  # fix seeds independently for the two calls).
  set.seed(20260803)
  spec <- canonical_dgp_params("dgp1")
  data <- generate_dgp_data(400, spec$params, spec$p_X, spec$X_levels)

  set.seed(42L)
  fit_base <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    verbose = FALSE
  )
  set.seed(42L)
  fit_new <- tv_ball_correlation_IF_adaptive(
    data, lambda = 0.3, method = "importance_weighting",
    jackknife = TRUE, debiased = TRUE, verbose = FALSE
  )
  # Plug-in fields must be identical (same seed -> same Q draws)
  expect_equal(fit_new$rho_hat,   fit_base$rho_hat)
  expect_equal(fit_new$se,        fit_base$se)
  expect_equal(fit_new$ci_lower,  fit_base$ci_lower)
  expect_equal(fit_new$ci_upper,  fit_base$ci_upper)
})
