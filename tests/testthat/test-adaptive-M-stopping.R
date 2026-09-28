# Tests for the Monte Carlo precision stopping rule of
# tv_ball_correlation_IF_adaptive() (mc_tolerance / se_mc), introduced in 0.4.1.

make_adaptive_test_data <- function(dgp_id, n = 800, seed = 20260928) {
  set.seed(seed)
  spec <- canonical_dgp_params(dgp_id)
  generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels)
}

test_that("near-unit-correlation DGP converges at M_start", {
  # dgp4 has rho_true = 0.999997, so se_mc = (1 - rho^2)/sqrt(300) is ~1e-6 at
  # M_start. The superseded difference-window rule needed n_stable + 1 = 4
  # iterations, i.e. M >= 1200, before it could even be evaluated.
  spec <- canonical_dgp_params("dgp4")
  data <- make_adaptive_test_data("dgp4")

  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = spec$lambda, method = "importance_weighting",
    M_start = 300, M_increment = 300, M_max = 1500,
    burn_in = 200, thin = 3, verbose = FALSE
  )

  expect_true(fit$converged)
  expect_equal(fit$M_final, 300)
  expect_lt(fit$se_mc, 0.02)
})

test_that("se_mc is present and numeric on a converged run", {
  spec <- canonical_dgp_params("dgp4")
  data <- make_adaptive_test_data("dgp4")

  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = spec$lambda, method = "importance_weighting",
    M_start = 300, M_increment = 300, M_max = 900,
    burn_in = 200, thin = 3, verbose = FALSE
  )

  expect_true(fit$converged)
  expect_true("se_mc" %in% names(fit))
  expect_type(fit$se_mc, "double")
  expect_length(fit$se_mc, 1L)
  expect_false(is.na(fit$se_mc))
})

test_that("se_mc is present and numeric when M_max is hit without converging", {
  # Moderate rho + tiny M_max + very tight mc_tolerance forces the non-converged
  # exit path; se_mc must still be returned.
  spec <- canonical_dgp_params("dgp1")
  data <- make_adaptive_test_data("dgp1")

  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = spec$lambda, method = "importance_weighting",
    M_start = 100, M_increment = 100, M_max = 200,
    mc_tolerance = 1e-6,
    burn_in = 200, thin = 3, verbose = FALSE
  )

  expect_false(fit$converged)
  expect_equal(fit$M_final, 200)
  expect_true("se_mc" %in% names(fit))
  expect_type(fit$se_mc, "double")
  expect_false(is.na(fit$se_mc))
  expect_gt(fit$se_mc, 1e-6)
})

test_that("se_mc equals the plug-in formula at the final M", {
  spec <- canonical_dgp_params("dgp1")
  data <- make_adaptive_test_data("dgp1")

  fit <- tv_ball_correlation_IF_adaptive(
    data, lambda = spec$lambda, method = "importance_weighting",
    M_start = 200, M_increment = 200, M_max = 600,
    burn_in = 200, thin = 3, verbose = FALSE
  )

  expect_equal(fit$se_mc, (1 - fit$rho_hat^2) / sqrt(fit$M_final))
})

test_that("mc_tolerance controls how far M grows", {
  spec <- canonical_dgp_params("dgp1")
  data <- make_adaptive_test_data("dgp1")

  fit_loose <- tv_ball_correlation_IF_adaptive(
    data, lambda = spec$lambda, method = "importance_weighting",
    M_start = 100, M_increment = 100, M_max = 1200, mc_tolerance = 0.10,
    burn_in = 200, thin = 3, verbose = FALSE
  )
  fit_tight <- tv_ball_correlation_IF_adaptive(
    data, lambda = spec$lambda, method = "importance_weighting",
    M_start = 100, M_increment = 100, M_max = 1200, mc_tolerance = 0.02,
    burn_in = 200, thin = 3, verbose = FALSE
  )

  expect_true(fit_loose$converged)
  expect_lte(fit_loose$M_final, fit_tight$M_final)
})

test_that("legacy tolerance / n_stable arguments are still accepted", {
  # simulations/confounded-aipw/ and simulations/generality-validation/ pass these
  # by name; they are unused by the stopping rule but must not error.
  spec <- canonical_dgp_params("dgp4")
  data <- make_adaptive_test_data("dgp4")

  expect_no_error(
    fit <- tv_ball_correlation_IF_adaptive(
      data, lambda = spec$lambda, method = "importance_weighting",
      M_start = 300, M_increment = 300, M_max = 600,
      tolerance = 0.01, n_stable = 3,
      burn_in = 200, thin = 3, verbose = FALSE
    )
  )
  expect_equal(fit$tolerance, 0.01)
  expect_equal(fit$n_stable, 3)
  expect_equal(fit$mc_tolerance, 0.02)
})
