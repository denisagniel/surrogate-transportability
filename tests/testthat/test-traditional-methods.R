test_that("compute_pte recovers a high PTE for a strongly mediated DGP", {
  set.seed(1)
  spec <- canonical_dgp_params("dgp1")  # PTE ~ 0.82
  d <- generate_dgp_data(5000, spec$params, spec$p_X, spec$X_levels)
  pte <- compute_pte(d)
  expect_true(is.finite(pte))
  expect_gt(pte, 0.5)  # strongly mediated
})

test_that("compute_pte returns NA (with warning) when total effect is exactly ~ 0", {
  # Construct data with total effect below the 1e-10 guard directly.
  d0 <- data.frame(A = c(0, 1, 0, 1), S = c(0, 1, 0, 1), Y = c(1, 1, 1, 1))
  expect_warning(pte <- compute_pte(d0), "near zero")
  expect_true(is.na(pte))
})

test_that("compute_pte is unstable for DGP5 (Delta_Y(P0) ~ 0, PTE undefined in theory)", {
  # DGP5: antisymmetric effects, population Delta_Y(P0) = 0 by symmetry, so PTE
  # is theoretically undefined. At finite n the empirical total effect is tiny
  # but nonzero, so PTE is a large/unstable number rather than exactly NA --
  # this instability is exactly why the paper uses correlation instead.
  set.seed(2)
  spec <- canonical_dgp_params("dgp5")
  reps <- vapply(1:20, function(i) {
    d <- generate_dgp_data(2000, spec$params, spec$p_X, spec$X_levels)
    suppressWarnings(compute_pte(d))
  }, numeric(1))
  # Highly variable across reps (unstable), unlike a well-defined PTE.
  expect_gt(stats::sd(reps, na.rm = TRUE), 0.5)
})

test_that("compute_pte validates inputs", {
  expect_error(compute_pte(data.frame(A = 0:1, S = 1:2)), "A, S, and Y")
})

test_that("compute_mediation_effects returns a decomposition", {
  set.seed(3)
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(2000, spec$params, spec$p_X, spec$X_levels)
  m <- compute_mediation_effects(d)
  expect_named(m, c("indirect_effect", "direct_effect",
                    "total_effect", "proportion_mediated"))
  expect_true(all(vapply(m, is.finite, logical(1))))
})

test_that("compute_within_study_correlation works on raw data", {
  set.seed(4)
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)
  r <- compute_within_study_correlation(d)
  expect_true(is.finite(r) && r >= -1 && r <= 1)
})
