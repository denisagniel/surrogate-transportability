# =============================================================================
# dgp.R -- data generation for the confounded-aipw study
# =============================================================================
# Thin dispatch over the package's two spec accessors. All DGP mathematics lives
# in the package (generate_dgp_data, canonical_dgp_params, confounded_dgp_params)
# so this study cannot drift from the manuscript's DGP definition.
# =============================================================================

#' Resolve a grid row to its package DGP specification
#'
#' @param config One row of `GRID` (or of `unit_table()`), carrying `dgp_kind`
#'   and `dgp`.
#' @return The package spec list. Confounded specs additionally carry `e_int`,
#'   `e_coef` and `rho_iw_limit`.
spec_for <- function(config) {
  switch(as.character(config$dgp_kind),
    canonical  = canonical_dgp_params(config$dgp),
    confounded = confounded_dgp_params(config$dgp),
    stop("Unknown dgp_kind '", config$dgp_kind,
         "'; expected \"canonical\" or \"confounded\".")
  )
}

#' Generate one study's data for a grid row
#'
#' Randomized specs get `A ~ Bernoulli(0.5)`; confounded specs get
#' `A | X ~ Bernoulli(plogis(e_int + e_coef * X))`. The distinction is carried by
#' the spec, not by this function, so there is one place to change it.
#'
#' `conf2`'s propensity reaches 0.039, which trips the generator's intentional
#' positivity warning on every call. That warning is informative once and noise
#' 80 times, so it is suppressed here and recorded instead in the study README
#' and in the `dgp` label itself (`conf2` IS the positivity-stress regime).
#'
#' @param config One row of `unit_table()`.
#' @return A data frame with columns `X`, `A`, `S`, `Y` and `config$n` rows.
generate_data <- function(config) {
  spec <- spec_for(config)
  n <- as.integer(config$n)

  if (identical(as.character(config$dgp_kind), "confounded")) {
    return(withCallingHandlers(
      generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels,
                        e_int = spec$e_int, e_coef = spec$e_coef),
      warning = function(w) {
        if (grepl("positivity-stress", conditionMessage(w))) {
          invokeRestart("muffleWarning")
        }
      }
    ))
  }

  generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels)
}

#' The estimand this study measures error against
#'
#' Always `rho_true`, for BOTH methods and BOTH DGP kinds. The importance-
#' weighting path is scored against the same target as AIPW precisely so that its
#' confounding bias shows up as error rather than being defined away.
#'
#' @param config One row of `unit_table()`.
#' @return Scalar.
true_value <- function(config) {
  as.numeric(config$rho_true)
}
