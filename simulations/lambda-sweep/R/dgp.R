# =============================================================================
# dgp.R -- data-generating process for the "lambda-sweep" study
# =============================================================================
# Thin wrapper over the PACKAGE DGP, identical in spirit to
# simulations/canonical-validation/R/dgp.R: all four canonical DGPs share one
# linear 5-level-X generator (generate_dgp_data), parameterized by
# canonical_dgp_params() in the surrogateTransportability package. No inline copy
# of the DGP -- the package is the single source of truth.
#
# The RNG seed is set by the caller (run_one) BEFORE generate_data() is called,
# so do NOT call set.seed() here.
# =============================================================================

# config$dgp is one of the canonical ids: "dgp1", "dgp2", "dgp4", "dgp5".
generate_data <- function(config) {
  spec <- canonical_dgp_params(config$dgp)  # errors on unknown id (no silent fallback)
  generate_dgp_data(
    n        = config$n,
    params   = spec$params,
    p_X      = spec$p_X,
    X_levels = spec$X_levels
  )
}
