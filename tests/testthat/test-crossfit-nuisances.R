# Tests for crossfit_nuisances_once(): the fit-once AIPW nuisance utility that
# makes the observational arm of the confounded study affordable.

test_that("crossfit_nuisances_once returns five out-of-fold n-vectors", {
  spec <- confounded_dgp_params("conf1")
  set.seed(101)
  d <- generate_dgp_data(1200, spec$params, spec$p_X, spec$X_levels,
                         e_int = spec$e_int, e_coef = spec$e_coef)

  nu <- crossfit_nuisances_once(d, seed = 1)

  expect_setequal(names(nu), c("e_hat", "mu_1_S", "mu_0_S", "mu_1_Y", "mu_0_Y"))
  expect_true(all(vapply(nu, length, integer(1)) == nrow(d)))
  expect_true(all(vapply(nu, function(v) all(is.finite(v)), logical(1))))
  expect_true(all(nu$e_hat > 0 & nu$e_hat < 1))
})

test_that("estimated propensities track the true confounded propensity", {
  spec <- confounded_dgp_params("conf1")
  set.seed(102)
  d <- generate_dgp_data(20000, spec$params, spec$p_X, spec$X_levels,
                         e_int = spec$e_int, e_coef = spec$e_coef)

  nu <- crossfit_nuisances_once(d, seed = 2)
  fitted_by_cell <- tapply(nu$e_hat, d$X, mean)
  target <- stats::plogis(spec$e_int + spec$e_coef * sort(unique(d$X)))
  # The learner is correctly specified (logistic in X), so cell means should be close.
  expect_equal(as.numeric(fitted_by_cell), target, tolerance = 0.03)
})

test_that("estimated outcome regressions recover the canonical cell CATEs", {
  spec <- confounded_dgp_params("conf1")
  cc <- canonical_cates(spec$params, spec$X_levels)
  set.seed(103)
  d <- generate_dgp_data(20000, spec$params, spec$p_X, spec$X_levels,
                         e_int = spec$e_int, e_coef = spec$e_coef)

  nu <- crossfit_nuisances_once(d, seed = 3)
  cate_S <- tapply(nu$mu_1_S - nu$mu_0_S, d$X, mean)
  expect_equal(as.numeric(cate_S), cc$tau_S, tolerance = 0.06)
})

test_that("the returned nuisances satisfy tv_ball_correlation_IF_adaptive's contract", {
  spec <- confounded_dgp_params("conf1")
  set.seed(104)
  d <- generate_dgp_data(600, spec$params, spec$p_X, spec$X_levels,
                         e_int = spec$e_int, e_coef = spec$e_coef)
  nu <- crossfit_nuisances_once(d, seed = 4)

  fit <- tv_ball_correlation_IF_adaptive(
    data = d, lambda = spec$lambda, method = "aipw",
    M_start = 150, M_increment = 150, M_max = 300,
    e_hat = nu$e_hat, mu_1_S = nu$mu_1_S, mu_0_S = nu$mu_0_S,
    mu_1_Y = nu$mu_1_Y, mu_0_Y = nu$mu_0_Y,
    verbose = FALSE
  )
  expect_true(is.finite(fit$rho_hat))
  expect_gte(fit$rho_hat, -1)
  expect_lte(fit$rho_hat, 1)
  expect_true(is.finite(fit$se))
})

test_that("crossfit_nuisances_once validates its inputs", {
  spec <- canonical_dgp_params("dgp1")
  set.seed(105)
  d <- generate_dgp_data(200, spec$params, spec$p_X, spec$X_levels)

  expect_error(crossfit_nuisances_once(d[, c("X", "A")]), "missing required columns")
  expect_error(crossfit_nuisances_once(d, n_folds = 1), "integer >= 2")
  expect_error(crossfit_nuisances_once(d[1:5, ]), "too few for")

  d_bad <- d
  d_bad$A[1] <- 2
  expect_error(crossfit_nuisances_once(d_bad), "binary")
})

test_that("clipping a near-deterministic propensity warns rather than passing silently", {
  spec <- canonical_dgp_params("dgp1")
  set.seed(106)
  d <- suppressWarnings(
    generate_dgp_data(3000, spec$params, spec$p_X, spec$X_levels, e_coef = 6)
  )
  expect_warning(crossfit_nuisances_once(d, seed = 6), "clipped")
})

test_that("seed controls the fold split reproducibly", {
  spec <- canonical_dgp_params("dgp1")
  set.seed(107)
  d <- generate_dgp_data(400, spec$params, spec$p_X, spec$X_levels)

  a <- crossfit_nuisances_once(d, seed = 42)
  b <- crossfit_nuisances_once(d, seed = 42)
  expect_equal(a$e_hat, b$e_hat)
})
