# =============================================================================
# grid.R -- single source of truth for the "canonical-validation" simulation study
# =============================================================================
# Sourced by run_replication.R, profile_timing.R, combine.R, and (via Rscript)
# submit.sh. Defines the parameter grid, the number of replications, and study
# identity. Nothing here should have side effects beyond assigning objects.
#
# Work model:
#   - GRID has one row per configuration (a "cell" of the design).
#   - Each configuration is run TOTAL_REPS times.
#   - A "unit" is one (config, rep) pair. Total units = nrow(GRID) * TOTAL_REPS.
#   - Units are enumerated deterministically (see unit_table()) so that the
#     same unit index always maps to the same (config, rep) and the same seed.
# =============================================================================

STUDY_NAME   <- "canonical-validation"
PROJECT_NAME <- "surrogate-transportability"

# Base seed for the whole study. Per-unit seeds are BASE_SEED + unit_index so
# every replication is independent, reproducible, and parallel-safe.
# Distinct range from the pre-fix study (seeds 10000-19999) to avoid confusion.
BASE_SEED <- 70800000L

# Replications per configuration. Total Monte Carlo work = nrow(GRID) * TOTAL_REPS.
TOTAL_REPS <- 1000L

# -----------------------------------------------------------------------------
# Parameter grid: the four canonical DGPs. Their parameters + true rho live in
# the package (canonical_dgp_params()); here we name the regimes and the shared
# estimation settings only. dgp5 (Delta_Y(P0) ~ 0, PTE undefined) is the
# STRESS regime (Constitution Section 9): the traditional PTE comparison breaks
# there while the correlation estimand stays well-defined.
# Study goal: validate coverage of the FIXED tv_ball_correlation_IF_adaptive()
# estimator at the paper's large-n setting (confirm Table 2 after Phase 1.5 fixes).
# -----------------------------------------------------------------------------
GRID <- expand.grid(
  dgp    = c("dgp1", "dgp2", "dgp4", "dgp5"), # canonical ids; slides call these 1-4
  n      = 10000L,                            # large-n: isolate bias, not variance
  lambda = 0.3,                               # TV ball radius
  method = "importance_weighting",            # RCT estimation path
  stringsAsFactors = FALSE
)

# Stable configuration id (1..nrow(GRID)); do not reorder GRID after a run
# without cleaning stale scratch, or unit->config mapping will change.
GRID$config_id <- seq_len(nrow(GRID))

# -----------------------------------------------------------------------------
# unit_table() -- deterministic enumeration of all (config, rep) work units.
# Returns a data frame with columns: unit, config_id, rep_id, seed, plus the
# grid columns. unit runs 1..(nrow(GRID) * TOTAL_REPS).
# -----------------------------------------------------------------------------
unit_table <- function(grid = GRID, total_reps = TOTAL_REPS, base_seed = BASE_SEED) {
  reps <- seq_len(total_reps)
  # rep varies fastest within a config, so a config's reps are contiguous.
  ut <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    data.frame(
      config_id = grid$config_id[i],
      rep_id    = reps,
      grid[i, setdiff(names(grid), "config_id"), drop = FALSE],
      row.names = NULL,
      stringsAsFactors = FALSE
    )
  }))
  ut$unit <- seq_len(nrow(ut))
  ut$seed <- base_seed + ut$unit
  ut[, c("unit", "config_id", "rep_id", "seed",
         setdiff(names(ut), c("unit", "config_id", "rep_id", "seed")))]
}

# Convenience: total number of work units.
n_units <- function() nrow(GRID) * TOTAL_REPS
