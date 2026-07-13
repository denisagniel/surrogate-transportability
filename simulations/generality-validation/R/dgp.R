# =============================================================================
# dgp.R -- data generation for the generality-validation study
# =============================================================================
# Two DGP families, dispatched by config$dgp_kind:
#   "canonical" -- a named canonical DGP (dgp1/dgp2/dgp4/dgp5) from the package;
#                  used for the structural anchor + n-scaling slice.
#   "random"    -- an ensemble DGP reconstructed deterministically from
#                  config$dgp_seed via draw_random_dgp() (RCT-only in wave 1).
#
# Both reduce to: given a spec, simulate n rows of (X, A, S, Y). The RNG seed for
# the DATA is set by run_one() BEFORE this is called, so do NOT set.seed() here.
# (draw_random_dgp() sets its own seed to rebuild the SPEC, not the data; it is
# called with a distinct dgp_seed and restores nothing about the data RNG state
# because run_one sets the data seed immediately after.)
#
# Assumes random_dgp.R (draw_random_dgp, generate_random_data) is sourced.
# =============================================================================

generate_data <- function(config) {
  if (config$dgp_kind == "canonical") {
    spec <- canonical_dgp_params(config$dgp)  # errors on unknown id
    generate_dgp_data(
      n = config$n, params = spec$params,
      p_X = spec$p_X, X_levels = spec$X_levels
    )
  } else if (config$dgp_kind == "random") {
    spec <- draw_random_dgp(rng_seed = config$dgp_seed,
                            allow_observational = FALSE)  # wave 1: RCT only
    generate_random_data(spec, n = config$n)
  } else {
    stop(sprintf("Unknown dgp_kind: '%s'", config$dgp_kind))  # no silent fallback
  }
}
