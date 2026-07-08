test_that("generate_dgp_data returns correct structure", {
  spec <- canonical_dgp_params("dgp1")
  d <- generate_dgp_data(200, spec$params, spec$p_X, spec$X_levels)

  expect_s3_class(d, "data.frame")
  expect_equal(nrow(d), 200)
  expect_named(d, c("X", "A", "S", "Y"))
  expect_true(all(d$A %in% c(0, 1)))
  expect_true(all(d$X %in% spec$X_levels))
})

test_that("generate_dgp_data validates inputs", {
  spec <- canonical_dgp_params("dgp1")
  expect_error(
    generate_dgp_data(10, spec$params, c(0.5, 0.5), c(-2, -1, 0, 1, 2)),
    "same length"
  )
  expect_error(
    generate_dgp_data(10, spec$params, c(0.3, 0.3, 0.3), c(-1, 0, 1)),
    "sum to 1"
  )
  expect_error(
    generate_dgp_data(10, list(gamma_A = 1), spec$p_X, spec$X_levels),
    "missing"
  )
})

test_that("canonical_dgp_params exposes the four paper DGPs with slide mapping", {
  specs <- canonical_dgp_params()
  expect_named(specs, c("dgp1", "dgp2", "dgp4", "dgp5"))  # no dgp3 by design
  expect_equal(
    vapply(specs, function(s) s$slide_label, character(1)),
    c(dgp1 = "DGP 1", dgp2 = "DGP 2", dgp4 = "DGP 3", dgp5 = "DGP 4")
  )
  expect_error(canonical_dgp_params("dgp3"), "Unknown DGP id")
})

test_that("DGP5 has Delta_Y(P0) ~ 0 by symmetry (PTE undefined)", {
  s <- canonical_dgp_params("dgp5")
  p <- s$params
  x <- s$X_levels
  tau_Y <- (p$beta_A + p$beta_AX * x) +
    (p$beta_S + p$beta_SX * x) * (p$gamma_A + p$gamma_AX * x)
  expect_lt(abs(sum(s$p_X * tau_Y)), 1e-8)
  expect_true(is.nan(s$pte_P0))
})

test_that("stored true rho matches the analytic across-study correlation", {
  # Analytic across-study correlation over a large uniform-on-TV-ball sample,
  # compared to the stored rho_true. Tolerance is loose (sampling + rejection
  # oracle differs from hit-and-run), enough to catch a spec/label mismatch.
  skip_on_cran()
  rdir1 <- function(K) { g <- stats::rexp(K); g / sum(g) }
  cate <- function(p, x, which) {
    if (which == "S") p$gamma_A + p$gamma_AX * x
    else (p$beta_A + p$beta_AX * x) + (p$beta_S + p$beta_SX * x) * (p$gamma_A + p$gamma_AX * x)
  }
  approx_rho <- function(spec, M = 4000, seed = 1) {
    set.seed(seed)
    x <- spec$X_levels; p <- spec$params; P0 <- spec$p_X; lam <- spec$lambda
    tS <- cate(p, x, "S"); tY <- cate(p, x, "Y")
    dS <- numeric(0); dY <- numeric(0); K <- length(P0); tries <- 0
    while (length(dS) < M && tries < M * 5000) {
      q <- rdir1(K); tries <- tries + 1
      if (0.5 * sum(abs(q - P0)) <= lam) {
        dS <- c(dS, sum(q * tS)); dY <- c(dY, sum(q * tY))
      }
    }
    stats::cor(dS, dY)
  }
  for (id in c("dgp1", "dgp2")) {  # dgp4/dgp5 are ~1.0; dgp1/2 are the discriminating cases
    spec <- canonical_dgp_params(id)
    expect_equal(approx_rho(spec), spec$rho_true, tolerance = 0.05,
                 info = paste("DGP", id))
  }
})
