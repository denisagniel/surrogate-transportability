# Tests for the confounded (observational) DGP path and the CATE-based truth
# utilities that give the confounded study its reference values.

test_that("generate_dgp_data defaults to a balanced randomized trial", {
  spec <- canonical_dgp_params("dgp1")
  set.seed(1)
  d <- generate_dgp_data(4000, spec$params, spec$p_X, spec$X_levels)

  expect_setequal(names(d), c("X", "A", "S", "Y"))
  expect_equal(nrow(d), 4000)
  expect_true(all(d$A %in% c(0, 1)))
  # Randomization: marginal and within-cell treatment probability both ~ 0.5.
  expect_equal(mean(d$A), 0.5, tolerance = 0.05)
  cell_rates <- tapply(d$A, d$X, mean)
  expect_true(all(abs(cell_rates - 0.5) < 0.12))
})

test_that("supplying e_coef induces a monotone covariate-dependent propensity", {
  spec <- confounded_dgp_params("conf1")
  set.seed(2)
  d <- generate_dgp_data(20000, spec$params, spec$p_X, spec$X_levels,
                         e_int = spec$e_int, e_coef = spec$e_coef)

  cell_rates <- tapply(d$A, d$X, mean)
  target <- stats::plogis(spec$e_int + spec$e_coef * sort(unique(d$X)))
  expect_equal(as.numeric(cell_rates), target, tolerance = 0.04)
  # Confounding means the treated group is shifted in X relative to control.
  expect_gt(mean(d$X[d$A == 1]) - mean(d$X[d$A == 0]), 0.5)
})

test_that("e_int alone is honoured and leaves the propensity flat in X", {
  spec <- canonical_dgp_params("dgp1")
  set.seed(3)
  d <- generate_dgp_data(20000, spec$params, spec$p_X, spec$X_levels, e_int = -1)

  expect_equal(mean(d$A), stats::plogis(-1), tolerance = 0.02)
  cell_rates <- tapply(d$A, d$X, mean)
  expect_true(all(abs(cell_rates - stats::plogis(-1)) < 0.1))
})

test_that("a near-deterministic propensity warns about positivity", {
  spec <- canonical_dgp_params("dgp1")
  expect_warning(
    generate_dgp_data(200, spec$params, spec$p_X, spec$X_levels, e_coef = 3),
    "positivity-stress"
  )
})

test_that("generate_dgp_data rejects malformed propensity arguments", {
  spec <- canonical_dgp_params("dgp1")
  expect_error(
    generate_dgp_data(100, spec$params, spec$p_X, spec$X_levels, e_coef = c(1, 2)),
    "single number"
  )
})

test_that("canonical_cates matches the empirical cell CATEs of the generator", {
  spec <- canonical_dgp_params("dgp2")
  cc <- canonical_cates(spec$params, spec$X_levels)

  set.seed(4)
  d <- generate_dgp_data(4e5, spec$params, spec$p_X, spec$X_levels)
  emp_S <- vapply(spec$X_levels, function(k) {
    mean(d$S[d$X == k & d$A == 1]) - mean(d$S[d$X == k & d$A == 0])
  }, numeric(1))
  emp_Y <- vapply(spec$X_levels, function(k) {
    mean(d$Y[d$X == k & d$A == 1]) - mean(d$Y[d$X == k & d$A == 0])
  }, numeric(1))

  expect_equal(emp_S, cc$tau_S, tolerance = 0.05)
  expect_equal(emp_Y, cc$tau_Y, tolerance = 0.05)
})

test_that("canonical_cates are invariant to the assignment mechanism", {
  # The estimand depends on the mean structure only, which is why confounded and
  # randomized versions of one parameter set share a single rho_true.
  spec <- confounded_dgp_params("conf2")
  cc <- canonical_cates(spec$params, spec$X_levels)

  set.seed(5)
  d <- generate_dgp_data(4e5, spec$params, spec$p_X, spec$X_levels,
                         e_int = spec$e_int, e_coef = spec$e_coef)
  emp_S <- vapply(spec$X_levels, function(k) {
    mean(d$S[d$X == k & d$A == 1]) - mean(d$S[d$X == k & d$A == 0])
  }, numeric(1))

  expect_equal(emp_S, cc$tau_S, tolerance = 0.08)
})

test_that("canonical_cates validates its inputs", {
  expect_error(canonical_cates(list(gamma_A = 1), c(-1, 1)), "missing")
  expect_error(canonical_cates(canonical_dgp_params("dgp1")$params, numeric(0)),
               "non-empty numeric")
})

test_that("true_rho_from_cates reproduces the stored canonical rho_true", {
  spec <- canonical_dgp_params("dgp2")
  cc <- canonical_cates(spec$params, spec$X_levels)
  res <- true_rho_from_cates(cc$tau_S, cc$tau_Y, spec$p_X, spec$lambda,
                             M_ref = 4000L, thin = 10L, seed = 11L)
  # Tolerance covers the documented Monte Carlo variation at modest M_ref.
  expect_equal(res$rho_true, spec$rho_true, tolerance = 0.02)
  expect_identical(res$M_ref, 4000L)
})

test_that("true_rho_from_cates validates its inputs", {
  expect_error(true_rho_from_cates(1:3, 1:3, c(0.5, 0.5), 0.3), "same length")
  expect_error(true_rho_from_cates(1:2, 1:2, c(0.5, 0.6), 0.3), "must sum to 1")
  expect_error(true_rho_from_cates(1:2, 1:2, c(0.5, 0.5), -1), "positive")
})

test_that("iw_limit_from_cates returns the target when the propensity is flat", {
  spec <- canonical_dgp_params("dgp1")
  cc <- canonical_cates(spec$params, spec$X_levels)
  e_flat <- rep(0.5, length(spec$p_X))
  res <- iw_limit_from_cates(cc$tau_S, cc$tau_Y, e_flat, spec$p_X, spec$lambda,
                             M_ref = 2000L, thin = 10L, seed = 12L)
  # Constant e cancels out of the Hajek tilt, so there is nothing for AIPW to fix.
  expect_equal(res$rho_iw_limit, res$rho_true, tolerance = 1e-10)
  expect_equal(res$bias, 0, tolerance = 1e-10)
})

test_that("iw_limit_from_cates reproduces the stored confounded bias", {
  for (id in c("conf1", "conf2")) {
    spec <- confounded_dgp_params(id)
    cc <- canonical_cates(spec$params, spec$X_levels)
    e <- stats::plogis(spec$e_int + spec$e_coef * spec$X_levels)
    res <- iw_limit_from_cates(cc$tau_S, cc$tau_Y, e, spec$p_X, spec$lambda,
                               M_ref = 4000L, thin = 10L, seed = 13L)
    expect_equal(res$rho_true, spec$rho_true, tolerance = 0.02,
                 info = paste(id, "rho_true"))
    expect_equal(res$rho_iw_limit, spec$rho_iw_limit, tolerance = 0.03,
                 info = paste(id, "rho_iw_limit"))
  }
})

test_that("iw_limit_from_cates rejects propensities outside (0, 1)", {
  spec <- canonical_dgp_params("dgp1")
  cc <- canonical_cates(spec$params, spec$X_levels)
  expect_error(
    iw_limit_from_cates(cc$tau_S, cc$tau_Y, c(0, 0.5, 0.5, 0.5, 0.5),
                        spec$p_X, spec$lambda, M_ref = 100L),
    "strictly inside"
  )
  expect_error(
    iw_limit_from_cates(cc$tau_S, cc$tau_Y, rep(0.5, 3), spec$p_X, spec$lambda,
                        M_ref = 100L),
    "same length as"
  )
})

test_that("confounded_dgp_params exposes both specs and rejects unknown ids", {
  expect_setequal(names(confounded_dgp_params()), c("conf1", "conf2"))
  expect_error(confounded_dgp_params("nope"), "Unknown confounded DGP id")

  for (id in c("conf1", "conf2")) {
    spec <- confounded_dgp_params(id)
    expect_true(all(c("params", "p_X", "X_levels", "lambda", "e_int", "e_coef",
                      "rho_true", "rho_iw_limit") %in% names(spec)))
    # Each confounded spec must actually be discriminating: if the importance-
    # weighting limit equalled the target there would be nothing to demonstrate.
    expect_gt(abs(spec$rho_iw_limit - spec$rho_true), 0.1)
  }
  # Both share dgp1's mean structure, hence one rho_true.
  expect_identical(confounded_dgp_params("conf1")$rho_true,
                   confounded_dgp_params("conf2")$rho_true)
  expect_identical(confounded_dgp_params("conf1")$params,
                   canonical_dgp_params("dgp1")$params)
})
