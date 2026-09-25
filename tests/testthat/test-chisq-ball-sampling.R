# Tests for sample_chisq_ball() — the chi-squared-ball hit-and-run sampler.
#
# The theory being tested lives in inst/paper/theory.tex, Section sec:chisq:
#   - Definition def:interior-chisq           (interior regime)
#   - Lemma lem:interior-chisq-threshold      (sharp threshold p_min/(1-p_min))
#   - Proposition prop:interior-chisq          (Cov(V) = lambda/(K+1) (D - p0 p0'))
# and Corollary cor:saturation-chisq (saturation at (1 - p_min)/p_min).

chisq_of <- function(Q, P0) sum((Q - P0)^2 / P0)

interior_threshold <- function(P0) min(P0) / (1 - min(P0))


test_that("sample_chisq_ball returns valid distributions in the chi-squared ball", {
  set.seed(20260925)
  P0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
  lambda <- 0.03  # strictly inside interior regime (threshold 0.05/0.95 = 0.0526)

  Q <- sample_chisq_ball(P0, lambda = lambda, M = 300, burn_in = 200,
                         thin = 5, verbose = FALSE)

  expect_true(is.matrix(Q))
  expect_equal(dim(Q), c(300L, length(P0)))
  expect_false(anyNA(Q))
  expect_true(all(abs(rowSums(Q) - 1) < 1e-9))
  expect_true(all(Q >= 0))

  d <- apply(Q, 1, chisq_of, P0 = P0)
  expect_true(all(d <= lambda + 1e-9))
  # Non-degenerate: the chain actually explores, it does not sit at P0.
  expect_gt(max(d), 0.5 * lambda)
})


test_that("sample_chisq_ball reproduces the theoretical covariance in the interior regime", {
  # Proposition prop:interior-chisq: in whitened coordinates u = D^{-1/2}(Q - P0),
  # Cov(u) = lambda/(K+1) * (I - nu nu'), nu = sqrt(P0); equivalently
  # Cov(Q) = lambda/(K+1) * (diag(P0) - P0 P0').
  set.seed(20260925)
  P0 <- c(0.10, 0.15, 0.25, 0.20, 0.30)
  K <- length(P0)
  lambda <- 0.08  # threshold is 0.10/0.90 = 0.111 -> strictly interior

  expect_lt(lambda, interior_threshold(P0))

  Q <- sample_chisq_ball(P0, lambda = lambda, M = 8000, burn_in = 500,
                         thin = 5, verbose = FALSE)

  # E[Q] = P0 (the body is centrally symmetric about P0 in the interior regime)
  expect_equal(colMeans(Q), P0, tolerance = 0.02)

  nu <- sqrt(P0)
  U <- sweep(Q - matrix(P0, nrow(Q), K, byrow = TRUE), 2, nu, "/")

  cov_hat <- stats::cov(U)
  cov_theory <- (lambda / (K + 1)) * (diag(K) - outer(nu, nu))

  # Relative agreement on the Frobenius scale (MCMC + MC error at M = 8000).
  rel_err <- sqrt(sum((cov_hat - cov_theory)^2)) / sqrt(sum(cov_theory^2))
  expect_lt(rel_err, 0.10)

  # E[chi^2] = lambda * (K-1)/(K+1) for uniform draws on a (K-1)-ball of
  # radius sqrt(lambda).
  d <- apply(Q, 1, chisq_of, P0 = P0)
  expect_equal(mean(d), lambda * (K - 1) / (K + 1), tolerance = 0.10 * lambda)
})


test_that("sample_chisq_ball works for K = 2", {
  # K = 2: the whitened feasible set is a 1-dimensional segment.
  set.seed(20260925)
  P0 <- c(0.4, 0.6)
  lambda <- 0.2  # threshold 0.4/0.6 = 0.667 -> interior
  K <- 2

  Q <- sample_chisq_ball(P0, lambda = lambda, M = 4000, burn_in = 200,
                         thin = 2, verbose = FALSE)

  expect_equal(ncol(Q), 2L)
  expect_true(all(abs(rowSums(Q) - 1) < 1e-9))
  expect_true(all(Q >= 0))
  expect_true(all(apply(Q, 1, chisq_of, P0 = P0) <= lambda + 1e-9))

  # In one dimension uniform on [-sqrt(lambda), sqrt(lambda)] gives
  # E[chi^2] = lambda/3 = lambda (K-1)/(K+1).
  expect_equal(mean(apply(Q, 1, chisq_of, P0 = P0)),
               lambda * (K - 1) / (K + 1), tolerance = 0.12 * lambda)
})


test_that("sample_chisq_ball handles large lambda where nonnegativity binds", {
  # Outside the interior regime the box constraint truncates the whitened ball.
  # The sampler must stay feasible, and the realised chi-squared must fall short
  # of the untruncated prediction because mass near the boundary is cut off.
  set.seed(20260925)
  P0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
  K <- length(P0)
  lambda <- 2.0  # well past the interior threshold (0.0526); saturation at 19

  Q <- sample_chisq_ball(P0, lambda = lambda, M = 2000, burn_in = 500,
                         thin = 5, verbose = FALSE)

  expect_true(all(abs(rowSums(Q) - 1) < 1e-9))
  expect_true(all(Q >= 0))
  d <- apply(Q, 1, chisq_of, P0 = P0)
  expect_true(all(d <= lambda + 1e-9))
  expect_lt(mean(d), lambda * (K - 1) / (K + 1))
})


test_that("sample_chisq_ball concentrates at P0 as lambda shrinks", {
  set.seed(20260925)
  P0 <- c(0.2, 0.3, 0.5)

  Q_small <- sample_chisq_ball(P0, lambda = 1e-4, M = 500, burn_in = 100,
                               thin = 2, verbose = FALSE)
  Q_big <- sample_chisq_ball(P0, lambda = 1e-1, M = 500, burn_in = 100,
                             thin = 2, verbose = FALSE)

  expect_lt(max(abs(Q_small - matrix(P0, nrow(Q_small), 3, byrow = TRUE))), 0.01)
  expect_gt(max(abs(Q_big - matrix(P0, nrow(Q_big), 3, byrow = TRUE))), 0.05)
})


test_that("sample_chisq_ball accepts a feasible initial point and rejects infeasible ones", {
  set.seed(20260925)
  P0 <- c(0.2, 0.3, 0.5)
  lambda <- 0.05

  init <- P0 + c(0.01, -0.01, 0)
  expect_lt(chisq_of(init, P0), lambda)

  Q <- sample_chisq_ball(P0, lambda = lambda, M = 50, burn_in = 50,
                         thin = 2, initial = init, verbose = FALSE)
  expect_equal(dim(Q), c(50L, 3L))

  far <- c(0.9, 0.05, 0.05)
  expect_error(
    sample_chisq_ball(P0, lambda = lambda, M = 10, initial = far, verbose = FALSE),
    "not in chi-squared ball"
  )
  expect_error(
    sample_chisq_ball(P0, lambda = lambda, M = 10, initial = c(0.2, 0.3),
                      verbose = FALSE),
    "wrong length"
  )
})


test_that("sample_chisq_ball validates its inputs", {
  expect_error(sample_chisq_ball(c(0.5, 0.4), lambda = 0.1, verbose = FALSE),
               "must sum to 1")
  expect_error(sample_chisq_ball(c(0.5, 0.5, 0.0), lambda = 0.1, verbose = FALSE),
               "full support")
  expect_error(sample_chisq_ball(c(-0.1, 0.6, 0.5), lambda = 0.1, verbose = FALSE),
               "full support")
  expect_error(sample_chisq_ball(1, lambda = 0.1, verbose = FALSE),
               "at least 2 cells")
  expect_error(sample_chisq_ball(c(0.5, 0.5), lambda = 0, verbose = FALSE),
               "positive chi-squared budget")
  expect_error(sample_chisq_ball(c(0.5, 0.5), lambda = -1, verbose = FALSE),
               "positive chi-squared budget")
  expect_error(sample_chisq_ball(c(0.5, 0.5), lambda = 0.1, M = 0, verbose = FALSE),
               "Invalid sampling parameters")
  expect_error(sample_chisq_ball(c(0.5, 0.5), lambda = 0.1, thin = 0, verbose = FALSE),
               "Invalid sampling parameters")
})


test_that("whitening internals satisfy their algebraic contracts", {
  set.seed(20260925)
  P0 <- c(0.1, 0.2, 0.3, 0.4)
  nu <- sqrt(P0)

  # nu is a unit vector because sum_k p0(k) = 1 (this is what makes the
  # whitened sum-to-one constraint a hyperplane through the origin).
  expect_equal(sum(nu^2), 1)

  d <- sample_whitened_direction(nu)
  expect_equal(sqrt(sum(d^2)), 1)
  expect_equal(sum(nu * d), 0)
  # Un-whitening a direction in H' gives a zero-sum perturbation of P0.
  expect_equal(sum(nu * d), 0)

  # The chord endpoints solve ||u + t d||^2 = lambda exactly when the box
  # does not bind.
  lambda <- 0.05
  u <- rep(0, 4)
  rng <- find_feasible_range_chisq(u, d, nu, lambda)
  expect_equal(sum((u + rng$t_max * d)^2), lambda)
  expect_equal(sum((u + rng$t_min * d)^2), lambda)
  expect_lt(rng$t_min, 0)
  expect_gt(rng$t_max, 0)

  # chisq_divergence matches the definition in eq:chisq-def.
  Q <- c(0.15, 0.2, 0.25, 0.4)
  expect_equal(chisq_divergence(Q, P0), sum((Q - P0)^2 / P0))
  expect_equal(chisq_divergence(P0, P0), 0)
})
