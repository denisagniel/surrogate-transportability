test_that("cate_estimator('saturated') satisfies the contract", {
  set.seed(1)
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(800, spec$params, spec$p_X, spec$X_levels)
  f <- cate_estimator("saturated")
  out <- f(d$S, d$A, d$X, spec$X_levels)
  expect_true(all(c("tau", "var") %in% names(out)))
  expect_length(out$tau, length(spec$X_levels))
  expect_length(out$var, length(spec$X_levels))
  expect_true(all(is.finite(out$tau)))
})

test_that("saturated CATE is robust to sparse arm-cells (no NaN)", {
  set.seed(2)
  spec <- canonical_dgp_params("dgp1")
  # small n makes the +/-2 (5% mass) cells sparse
  d <- generate_dgp_data(120, spec$params, spec$p_X, spec$X_levels)
  f <- cate_estimator("saturated")
  outS <- f(d$S, d$A, d$X, spec$X_levels)
  outY <- f(d$Y, d$A, d$X, spec$X_levels)
  expect_false(anyNA(outS$tau))
  expect_false(anyNA(outY$tau))
})

test_that("tv_ball_correlation_cate recovers rho on the canonical DGP (saturated)", {
  set.seed(3)
  spec <- canonical_dgp_params("dgp1")   # true rho ~ 0.69
  d <- generate_dgp_data(3000, spec$params, spec$p_X, spec$X_levels)
  r <- tv_ball_correlation_cate(d, lambda = 0.3, cate = "saturated",
                                x_eval = spec$X_levels, se = "none", verbose = FALSE)
  expect_true(is.finite(r$rho_hat))
  expect_gt(r$rho_hat, 0.4)   # attenuated at this n but clearly positive
  expect_lt(r$rho_hat, 0.95)
  expect_equal(r$cate, "saturated")
})

test_that("bootstrap SE path returns a finite SE and ordered CI", {
  set.seed(4)
  spec <- canonical_dgp_params("dgp2")
  d <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)
  r <- tv_ball_correlation_cate(d, lambda = 0.3, cate = "saturated",
                                x_eval = spec$X_levels, se = "bootstrap", B = 50,
                                verbose = FALSE)
  expect_true(is.finite(r$se))
  expect_true(r$ci_lower <= r$rho_hat && r$rho_hat <= r$ci_upper)
  expect_match(r$se_type, "bootstrap")
})

test_that("a user CATE function satisfying the contract works", {
  set.seed(5)
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)
  # user estimator: saturated implemented by hand
  my_cate <- function(y, A, X, x_eval) {
    tau <- vapply(x_eval, function(xx) {
      mean(y[X == xx & A == 1]) - mean(y[X == xx & A == 0])
    }, numeric(1))
    list(tau = tau, var = rep(NA_real_, length(x_eval)))
  }
  r <- tv_ball_correlation_cate(d, lambda = 0.3, cate = my_cate,
                                x_eval = spec$X_levels, se = "none", verbose = FALSE)
  expect_true(is.finite(r$rho_hat))
  expect_equal(r$cate, "user")
})

test_that("GUARDRAIL: a rigid linear-in-X CATE manufactures |rho|=1 (documents the trap)", {
  # This is why the package must NOT default to a fixed-basis CATE model.
  set.seed(6)
  spec <- canonical_dgp_params("dgp1")   # true tau_Y is quadratic
  d <- generate_dgp_data(2000, spec$params, spec$p_X, spec$X_levels)
  linear_cate <- function(y, A, X, x_eval) {
    fit <- lm(y ~ A * X, data = data.frame(y = y, A = A, X = X))
    p1 <- predict(fit, data.frame(A = 1, X = x_eval))
    p0 <- predict(fit, data.frame(A = 0, X = x_eval))
    list(tau = as.numeric(p1 - p0), var = rep(NA_real_, length(x_eval)))
  }
  r <- tv_ball_correlation_cate(d, lambda = 0.3, cate = linear_cate,
                                x_eval = spec$X_levels, se = "none", verbose = FALSE)
  # linear tau_S and linear tau_Y are collinear across cells -> |rho| = 1
  expect_gt(abs(r$rho_hat), 0.999)
})

test_that("saturated estimator returns an influence matrix", {
  set.seed(8)
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(600, spec$params, spec$p_X, spec$X_levels)
  out <- cate_estimator("saturated")(d$S, d$A, d$X, spec$X_levels)
  expect_true(is.matrix(out$if_mat))
  expect_equal(dim(out$if_mat), c(600L, length(spec$X_levels)))
  # IF is the mean-zero deviation (tau_hat - tau ~ mean(IF)); in-sample it centers ~0
  expect_true(all(abs(colMeans(out$if_mat)) < 1e-8))
})

test_that("se = 'if' gives a finite SE close to bootstrap SE (saturated)", {
  set.seed(9)
  spec <- canonical_dgp_params("dgp2")
  d <- generate_dgp_data(1500, spec$params, spec$p_X, spec$X_levels)
  r_if <- tv_ball_correlation_cate(d, lambda = 0.3, cate = "saturated",
                                   x_eval = spec$X_levels, se = "if", verbose = FALSE)
  r_bs <- tv_ball_correlation_cate(d, lambda = 0.3, cate = "saturated",
                                   x_eval = spec$X_levels, se = "bootstrap", B = 100,
                                   verbose = FALSE)
  expect_true(is.finite(r_if$se))
  expect_equal(r_if$se_type, "influence-function")
  expect_true(r_if$ci_lower <= r_if$rho_hat && r_if$rho_hat <= r_if$ci_upper)
  # IF-SE and single-dataset bootstrap-SE should be the same order of magnitude
  # (they differ by up to ~40% on one draw; the calibrated IF-SE-vs-empirical-SD
  # validation is in explorations/small_n/07_if_se_prototype.R, ratio ~0.95).
  expect_true(is.finite(r_bs$se))
  expect_gt(r_if$se / r_bs$se, 0.5)
  expect_lt(r_if$se / r_bs$se, 2.0)
})

test_that("se = 'if' errors when the estimator lacks an influence matrix", {
  my_cate <- function(y, A, X, x_eval) {
    tau <- vapply(x_eval, function(xx)
      mean(y[X == xx & A == 1]) - mean(y[X == xx & A == 0]), numeric(1))
    list(tau = tau, var = rep(NA_real_, length(x_eval)))  # no if_mat
  }
  spec <- canonical_dgp_params("dgp1")
  set.seed(10)
  d <- generate_dgp_data(500, spec$params, spec$p_X, spec$X_levels)
  expect_error(
    tv_ball_correlation_cate(d, lambda = 0.3, cate = my_cate,
                             x_eval = spec$X_levels, se = "if", verbose = FALSE),
    "if_mat"
  )
})

test_that("grf path is skipped cleanly when grf is unavailable", {
  skip_if_not_installed("grf")
  set.seed(7)
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(800, spec$params, spec$p_X, spec$X_levels)
  r <- tv_ball_correlation_cate(d, lambda = 0.3, cate = "grf",
                                x_eval = spec$X_levels, se = "none", verbose = FALSE)
  expect_true(is.finite(r$rho_hat))
  expect_equal(r$cate, "grf")
})
