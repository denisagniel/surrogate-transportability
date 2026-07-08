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
#' with `A ~ Bernoulli(0.5)` (a balanced randomized trial) and
#' `X \in` `X_levels` drawn with probabilities `p_X`.
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
#'
#' @return A data frame with columns `X`, `A`, `S`, `Y` and `n` rows.
#'
#' @seealso [canonical_dgp_params()] for the four paper DGP specifications.
#'
#' @examples
#' spec <- canonical_dgp_params("dgp1")
#' d <- generate_dgp_data(1000, spec$params, spec$p_X, spec$X_levels)
#' head(d)
#'
#' @export
generate_dgp_data <- function(n, params, p_X, X_levels = c(-2, -1, 0, 1, 2)) {
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
  A <- stats::rbinom(n, 1, 0.5)

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
#' [tv_ball_correlation_IF_adaptive()]), verified analytically. `pte_P0` is the
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
