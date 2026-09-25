#' Generate Data from the Canonical Surrogate-Transportability DGP
#'
#' Simulates one study `(X, A, S, Y)` from the canonical linear data-generating
#' process used throughout the paper and validation studies. A single 5-level
#' categorical covariate `X` modifies the treatment effects on both the
#' surrogate `S` and the outcome `Y`; the surrogate additionally enters the
#' outcome model with an `S x X` interaction.
#'
#' @details
#' The DGP is
#' \deqn{S = (\gamma_A + \gamma_{AX} X) A + \epsilon_S, \quad
#'       \epsilon_S \sim N(0, \sigma_S^2),}
#' \deqn{Y = (\beta_A + \beta_{AX} X) A + \beta_S S + \beta_{SX} (S X) + \epsilon_Y,
#'       \quad \epsilon_Y \sim N(0, \sigma_Y^2),}
#' with `X` taking values in `X_levels`, drawn with probabilities `p_X`.
#'
#' **Treatment assignment.** By default `A ~ Bernoulli(0.5)`, a balanced
#' randomized trial, for which the importance-weighting path of
#' [tv_ball_correlation_IF_adaptive()] is valid. Supplying `e_int` and/or
#' `e_coef` switches to a **confounded** (observational) assignment,
#' \deqn{A \mid X \sim \mathrm{Bernoulli}(\mathrm{expit}(e_{int} + e_{coef} X)),}
#' under which treated and control groups differ in `X` and the
#' importance-weighting path becomes biased while the cross-fitted AIPW path
#' remains consistent. The outcome and surrogate mean structure — and hence the
#' cell CATEs and the estimand `Theta` — are untouched by `e_int`/`e_coef`; only
#' the assignment mechanism changes. See [confounded_dgp_params()] for the
#' confounded specifications used in the validation studies.
#'
#' This is the single package implementation of the DGP; simulation scripts,
#' figure generators, and cluster jobs should call it rather than defining their
#' own copies. Use [canonical_dgp_params()] to obtain the four paper DGP
#' specifications.
#'
#' @param n Integer. Sample size.
#' @param params Named list of coefficients: `gamma_A`, `gamma_AX`, `beta_A`,
#'   `beta_AX`, `beta_S`, `beta_SX`, `sigma_S`, `sigma_Y`.
#' @param p_X Numeric vector of covariate-level probabilities (sums to 1),
#'   same length as `X_levels`.
#' @param X_levels Numeric vector of covariate values
#'   (default `c(-2, -1, 0, 1, 2)`).
#' @param e_int,e_coef Optional propensity intercept and covariate coefficient.
#'   If either is supplied the other defaults to `0` and treatment is assigned
#'   from `plogis(e_int + e_coef * X)`; if both are `NULL` (default) treatment is
#'   randomized with probability `0.5`. A propensity that leaves any covariate
#'   cell below `0.02` or above `0.98` triggers a positivity warning, because the
#'   AIPW path clips estimated propensities at `0.01`/`0.99`.
#'
#' @return A data frame with columns `X`, `A`, `S`, `Y` and `n` rows.
#'
#' @seealso [canonical_dgp_params()] for the four paper DGP specifications;
#'   [confounded_dgp_params()] for the confounded (observational) ones.
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' d <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)
#' head(d)
#'
#' # confounded version of the same mean structure
#' cspec <- confounded_dgp_params("conf1")
#' dc <- generate_dgp_data(1000, cspec$params, cspec$p_X, cspec$X_levels,
#'                         e_int = cspec$e_int, e_coef = cspec$e_coef)
#' tapply(dc$A, dc$X, mean)
#'
#' @export
generate_dgp_data <- function(n, params, p_X, X_levels = c(-2, -1, 0, 1, 2),
                              e_int = NULL, e_coef = NULL) {
  if (length(p_X) != length(X_levels)) {
    stop("`p_X` and `X_levels` must have the same length.")
  }
  if (abs(sum(p_X) - 1) > 1e-8) {
    stop("`p_X` must sum to 1 (current sum: ", sum(p_X), ").")
  }
  required <- c("gamma_A", "gamma_AX", "beta_A", "beta_AX",
                "beta_S", "beta_SX", "sigma_S", "sigma_Y")
  missing <- setdiff(required, names(params))
  if (length(missing) > 0) {
    stop("`params` is missing: ", paste(missing, collapse = ", "), ".")
  }

  X <- sample(X_levels, size = n, replace = TRUE, prob = p_X)
  A <- .assign_treatment(X, X_levels, e_int, e_coef)

  S <- (params$gamma_A + params$gamma_AX * X) * A +
    stats::rnorm(n, sd = params$sigma_S)
  Y <- (params$beta_A + params$beta_AX * X) * A +
    params$beta_S * S + params$beta_SX * S * X +
    stats::rnorm(n, sd = params$sigma_Y)

  data.frame(X = X, A = A, S = S, Y = Y)
}


#' Canonical DGP Specifications (Paper Validation Study)
#'
#' Returns the parameter specifications for the four data-generating processes
#' in the paper's validation study, as a single in-package source of truth
#' (previously duplicated across scripts and a YAML config).
#'
#' @details
#' **Numbering.** The four DGPs are stored under ids `dgp1`, `dgp2`, `dgp4`,
#' `dgp5` (there is no `dgp3`; the ids are historical). The presentation
#' renumbers them 1--4: slide "DGP 3" is `dgp4` (low PTE, near-perfect
#' correlation) and slide "DGP 4" is `dgp5` (PTE undefined). This mapping is
#' recorded in each spec's `slide_label`.
#'
#' Each spec's `rho_true` is the across-study correlation
#' `cor_mu(Delta_S(Q), Delta_Y(Q))` over `Q` uniform on the TV ball of radius
#' `lambda` around the reference `p_X` (the estimand of
#' [tv_ball_correlation_IF_adaptive()]). **Correction (2026-08-21):** these
#' values are Monte Carlo estimates from long-run hit-and-run sampling of the
#' TV ball, using the DGP's *analytic* cell CATEs (so no per-observation `S`,
#' `Y` data is simulated) — they are not closed-form/exactly analytic despite
#' earlier documentation claiming so. Reported precision is limited by Monte
#' Carlo error in the `Q`-draws, not sampling error in a dataset: at
#' `M_ref` in the 5,000-30,000 range with `thin = 20`, run-to-run variation is
#' on the order of 0.001-0.005 in `rho_true` (verified directly: dgp1/dgp2
#' recomputed at `M_ref = 30000` with a fresh seed differ from the stored
#' values by -0.0012/+0.0009; dgp4/dgp5, both near the +1 boundary, are
#' unaffected to displayed precision). This does not change any 2-decimal
#' value reported in the paper's tables, but the 4-decimal-precision value
#' quoted in `inst/paper/theory.tex` (`$\Theta=0.6907$`) overstates the
#' precision an MC estimate at this `M_ref` can honestly support and should be
#' revisited when Table 2/figures are finalized from the cluster
#' re-validation. A higher-`M_ref`, package-level exact-truth utility
#' (`true_rho()`, prototyped in
#' `explorations/2026-07-13_generality-pilot/R/true_rho.R`) is planned for
#' that finalization pass; see
#' `quality_reports/plans/2026-07-13_bias-coverage-expansion-study.md`.
#' `pte_P0` is the
#' proportion of treatment effect at the reference distribution
#' (`NaN`/undefined for `dgp5`, where `Delta_Y(P0) ~ 0` by symmetry).
#'
#' @param which Optional character id (`"dgp1"`, `"dgp2"`, `"dgp4"`, `"dgp5"`).
#'   If `NULL` (default), returns all four as a named list.
#'
#' @return A named list of specifications (or one spec if `which` is given).
#'   Each spec has: `name`, `slide_label`, `params`, `p_X`, `X_levels`,
#'   `lambda`, `rho_true`, `pte_P0`, `notes`.
#'
#' @seealso [generate_dgp_data()]
#'
#' @examples
#' names(canonical_dgp_params())
#' canonical_dgp_params("dgp4")$rho_true
#'
#' @export
canonical_dgp_params <- function(which = NULL) {
  p_X <- c(0.05, 0.25, 0.40, 0.25, 0.05)
  X_levels <- c(-2, -1, 0, 1, 2)
  base_sigma <- list(sigma_S = 0.5, sigma_Y = 0.5)

  specs <- list(
    dgp1 = list(
      name = "Moderate positive correlation, high mediation",
      slide_label = "DGP 1",
      params = c(list(gamma_A = 1.0, gamma_AX = 0.5, beta_A = 0.25,
                      beta_AX = -0.3, beta_S = 0.9, beta_SX = -0.1), base_sigma),
      p_X = p_X, X_levels = X_levels, lambda = 0.3,
      rho_true = 0.6907059, pte_P0 = 0.8155961,
      notes = "High PTE (81.6%), moderate positive correlation."
    ),
    dgp2 = list(
      name = "Strong negative correlation, moderate mediation",
      slide_label = "DGP 2",
      params = c(list(gamma_A = 1.0, gamma_AX = 0.5, beta_A = 0.6,
                      beta_AX = -0.3, beta_S = 0.6, beta_SX = -0.15), base_sigma),
      p_X = p_X, X_levels = X_levels, lambda = 0.3,
      rho_true = -0.8844963, pte_P0 = 0.5305484,
      notes = "Moderate PTE (53.1%), strong negative correlation from S x X interaction."
    ),
    dgp4 = list(
      name = "Low PTE, near-perfect correlation",
      slide_label = "DGP 3",
      params = c(list(gamma_A = 1.0, gamma_AX = 0.5, beta_A = 0.7,
                      beta_AX = 0.4, beta_S = 0.3, beta_SX = 0.0), base_sigma),
      p_X = p_X, X_levels = X_levels, lambda = 0.3,
      rho_true = 0.999997, pte_P0 = 0.3001120,
      notes = "Low PTE (30.0%), near-perfect correlation: low PTE != poor surrogate."
    ),
    dgp5 = list(
      name = "Small Delta_Y at P0, high correlation (PTE undefined)",
      slide_label = "DGP 4",
      params = c(list(gamma_A = 0.0, gamma_AX = 0.5, beta_A = 0.0,
                      beta_AX = 0.5, beta_S = 0.6, beta_SX = 0.0), base_sigma),
      p_X = p_X, X_levels = X_levels, lambda = 0.3,
      rho_true = 0.999996, pte_P0 = NaN,
      notes = "Delta_Y(P0) ~ 0 by symmetry, PTE undefined, but correlation ~ 1.0."
    )
  )

  if (is.null(which)) {
    return(specs)
  }
  if (!which %in% names(specs)) {
    stop("Unknown DGP id '", which, "'. Available: ",
         paste(names(specs), collapse = ", "), ".")
  }
  specs[[which]]
}


#' Confounded DGP Specifications (Observational / AIPW Validation)
#'
#' Returns the confounded counterparts of the canonical DGP, in which treatment
#' assignment depends on the covariate. These are the specifications on which the
#' importance-weighting path is *provably* biased and the cross-fitted AIPW path
#' is not, so they are the discriminating cases for the observational arm of the
#' validation study.
#'
#' @details
#' **Construction.** Both specs reuse `dgp1`'s mean structure verbatim and change
#' only the assignment mechanism to `e(X) = expit(e_int + e_coef * X)`. Because the
#' cell CATEs — and hence the estimand
#' `Theta = cor_mu(Delta_S(Q), Delta_Y(Q))` — are properties of the mean structure
#' alone (see [canonical_cates()]), `rho_true` is identical across the two specs
#' and equal to `dgp1`'s. What differs is the importance-weighting *estimand*: that
#' path converges to the propensity-tilted correlation `rho_iw_limit`
#' (see [iw_limit_from_cates()]), so `rho_iw_limit - rho_true` is exactly the
#' asymptotic bias AIPW is expected to remove.
#'
#' **The two regimes.**
#'
#' * `conf1` (`e_coef = 0.8`): the headline discriminating case. Propensities span
#'   `[0.17, 0.83]`, comfortably interior, so positivity is not stressed and any
#'   AIPW failure would be an implementation problem rather than a design
#'   artifact. Importance weighting is biased by about `-0.61`, nearly erasing a
#'   `+0.69` correlation.
#' * `conf2` (`e_coef = 1.6`): the **stress** regime. Propensities span
#'   `[0.039, 0.961]`, so the smallest covariate cell (`p_X = 0.05`) is both rare
#'   and nearly untreated and AIPW's inverse-propensity term is near the clipping
#'   boundary the estimator applies at `0.01`/`0.99`. Importance weighting is
#'   biased by about `-1.16`, i.e. it reverses the sign of the correlation.
#'
#' **Provenance of the numeric values.** `rho_true` and `rho_iw_limit` are Monte
#' Carlo values from [iw_limit_from_cates()] at `M_ref = 1e5`, `thin = 20`,
#' `seed = 20260713`, computed from the analytic cell CATEs (no per-observation
#' data simulated). The `e_coef` values were selected from the propensity-strength
#' scan in `explorations/2026-09-24_confounded-aipw-arm/`. Note `rho_true` here
#' (`0.6876023`) differs from `canonical_dgp_params("dgp1")$rho_true`
#' (`0.6907059`) by `0.003` even though the mean structure is identical: the two
#' were computed at different `M_ref`, and this gap is within the Monte Carlo
#' variation documented in [canonical_dgp_params()]. The value stored here is the
#' tighter of the two and is the one the confounded study compares against.
#'
#' @param which Optional character id (`"conf1"`, `"conf2"`). If `NULL` (default),
#'   returns both as a named list.
#'
#' @return A named list of specifications (or one spec if `which` is given). Each
#'   spec has: `name`, `params`, `p_X`, `X_levels`, `lambda`, `e_int`, `e_coef`,
#'   `rho_true`, `rho_iw_limit`, `notes`.
#'
#' @seealso [generate_dgp_data()] (pass `e_int`/`e_coef` to realize these),
#'   [iw_limit_from_cates()], [canonical_dgp_params()]
#'
#' @examples
#' names(confounded_dgp_params())
#' spec <- confounded_dgp_params("conf1")
#' spec$rho_iw_limit - spec$rho_true   # asymptotic importance-weighting bias
#'
#' @export
confounded_dgp_params <- function(which = NULL) {
  dgp1 <- canonical_dgp_params("dgp1")

  specs <- list(
    conf1 = list(
      name = "Confounded, moderate propensity tilt (interior positivity)",
      params = dgp1$params, p_X = dgp1$p_X, X_levels = dgp1$X_levels,
      lambda = dgp1$lambda,
      e_int = 0, e_coef = 0.8,
      rho_true = 0.6876023, rho_iw_limit = 0.0772552,
      notes = paste("e(X) in [0.17, 0.83]; importance weighting biased by",
                    "-0.61, collapsing rho from 0.69 to 0.08.")
    ),
    conf2 = list(
      name = "Confounded, strong propensity tilt (positivity stress)",
      params = dgp1$params, p_X = dgp1$p_X, X_levels = dgp1$X_levels,
      lambda = dgp1$lambda,
      e_int = 0, e_coef = 1.6,
      rho_true = 0.6876023, rho_iw_limit = -0.4709488,
      notes = paste("STRESS regime: e(X) in [0.039, 0.961], smallest cell rare",
                    "and nearly untreated; importance weighting biased by -1.16,",
                    "reversing the sign of rho.")
    )
  )

  if (is.null(which)) {
    return(specs)
  }
  if (!which %in% names(specs)) {
    stop("Unknown confounded DGP id '", which, "'. Available: ",
         paste(names(specs), collapse = ", "), ".")
  }
  specs[[which]]
}


# Draw treatment: randomized Bernoulli(0.5) unless a propensity is specified,
# in which case A | X ~ Bernoulli(plogis(e_int + e_coef * X)). Kept internal so
# the confounding mechanism has exactly one implementation.
.assign_treatment <- function(X, X_levels, e_int, e_coef) {
  if (is.null(e_int) && is.null(e_coef)) {
    return(stats::rbinom(length(X), 1, 0.5))
  }

  # Supplying one coefficient implies the other is zero (an intercept-only shift
  # is still confounding-free, but we do not silently reinterpret it as an RCT).
  if (is.null(e_int)) e_int <- 0
  if (is.null(e_coef)) e_coef <- 0
  if (!is.numeric(e_int) || length(e_int) != 1 ||
      !is.numeric(e_coef) || length(e_coef) != 1) {
    stop("`e_int` and `e_coef` must each be a single number or NULL.")
  }

  e_cells <- stats::plogis(e_int + e_coef * X_levels)
  if (min(e_cells) < 0.02 || max(e_cells) > 0.98) {
    warning("Propensity reaches [", sprintf("%.4f", min(e_cells)), ", ",
            sprintf("%.4f", max(e_cells)), "] across covariate cells; the AIPW ",
            "path clips estimated propensities at 0.01/0.99, so inference near ",
            "this boundary is a positivity-stress regime, not a clean test.")
  }

  stats::rbinom(length(X), 1, stats::plogis(e_int + e_coef * X))
}
