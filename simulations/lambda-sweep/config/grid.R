# =============================================================================
# grid.R -- single source of truth for the "lambda-sweep" simulation study
# =============================================================================
# Sourced by local/run_local.R, local/combine.R, and R/plot_lambda_profile.R.
# Defines the parameter grid, the number of replications, and study identity.
# Nothing here has side effects beyond assigning objects.
#
# Structure deliberately mirrors simulations/canonical-validation/config/grid.R
# (GRID -> config_id -> unit_table() -> deterministic per-unit seed) so the two
# studies read the same way. ONE substantive difference, and it is the point of
# this study:
#
#   PAIRED DESIGN. The dataset for replication r of DGP d is the SAME dataset at
#   every lambda in the grid. `data_seed` therefore depends on (dgp, rep) ONLY,
#   never on lambda, so Theta-hat_n(lambda) is a profile computed on one study --
#   exactly the diagnostic the paper's "Interpreting lambda" paragraph asks a
#   practitioner to report. Rep-level sampling noise is COMMON across lambda, so
#   the SHAPE of the profile is estimated far more precisely than its level, and
#   within-rep lambda-contrasts are meaningful. canonical-validation, by
#   contrast, needed independent datasets per cell and keyed its seed on
#   (config_id, rep_id).
# =============================================================================

STUDY_NAME   <- "lambda-sweep"
PROJECT_NAME <- "surrogate-transportability"

# Base seed for the whole study. Distinct range from canonical-validation
# (70,800,000+) so the two studies never share a replication seed.
BASE_SEED <- 92500000L

# Replications per (DGP, lambda). Executed in rep BLOCKS by local/run_local.R
# (--rep-from/--rep-to) because the sweep is a ~3 CPU-hour-per-10-reps job on
# one workstation; see README.md for the sizing arithmetic. Seeds depend only on
# (dgp, rep), so a later block extends the study without invalidating an
# earlier one.
TOTAL_REPS <- 40L

# -----------------------------------------------------------------------------
# lambda grid.
#
# The scientifically load-bearing choice. All four canonical DGPs share
# p_X = (0.05, 0.25, 0.40, 0.25, 0.05), so
#
#     p_min := min_k p_0(k) = 0.05
#
# and Definition "Interior regime" in inst/paper/theory.tex is SHARP at that
# value (Lemma "The interior regime requires atomic support, and the sufficient
# condition is sharp"). Hence:
#
#   * lambda <= 0.05  -> interior regime. Theory predicts Theta(P_0, lambda) =
#     Corr_K(tau_S, tau_Y) EXACTLY and independently of lambda (Proposition
#     "Interior-regime closed form"). The profile must be FLAT here; any tilt is
#     estimation noise or bias, not signal.
#   * lambda  > 0.05  -> outside the interior regime. Proposition "First-order
#     exit from the interior regime" gives the one-sided slope at lambda = p_min
#     up to a positive constant C_K, so its SIGN is predicted MCMC-free by
#     sum_{k in argmin p_0(k)} varpi(k) (see R/exit_interior_prediction.R).
#
# The grid therefore STRADDLES 0.05 rather than sitting safely inside it: four
# interior points to establish the predicted plateau, the boundary point itself,
# and five exterior points out to the paper's operating radius lambda = 0.3
# (Table 2 / Section "Validation"). lambda = 0.02 is kept well inside so that
# the plateau is visible even if the boundary point behaves marginally.
LAMBDA_GRID <- c(0.010, 0.020, 0.035, 0.050,   # interior (lambda <= p_min)
                 0.070, 0.100, 0.150, 0.220, 0.300)  # past the interior edge

# p_min for the canonical p_X; asserted against the package spec in
# local/run_local.R rather than trusted as a comment.
P_MIN_CANONICAL <- 0.05

# -----------------------------------------------------------------------------
# Parameter grid: the four canonical DGPs x the lambda grid. n and method match
# canonical-validation exactly (n = 10,000, importance_weighting) so this study's
# lambda = 0.3 column is directly comparable to the paper's Table 2.
# dgp5 (Delta_Y(P0) ~ 0, PTE undefined) is the STRESS regime.
# -----------------------------------------------------------------------------
GRID <- expand.grid(
  dgp    = c("dgp1", "dgp2", "dgp4", "dgp5"),
  lambda = LAMBDA_GRID,
  n      = 10000L,
  method = "importance_weighting",
  stringsAsFactors = FALSE
)

# Stable configuration id (1..nrow(GRID)); do not reorder GRID after a run
# without cleaning stale partials, or unit->config mapping will change.
GRID$config_id <- seq_len(nrow(GRID))

# -----------------------------------------------------------------------------
# .data_seed() -- deterministic seed for the DATASET of (dgp, rep).
# Depends ONLY on (dgp, rep_id): the paired design's defining property. Arithmetic
# is done in doubles then reduced mod 2^31-1, because base-R integer arithmetic
# overflows to NA past 2^31 (MEMORY: base-r-hashing-gotcha).
# -----------------------------------------------------------------------------
.data_seed <- function(dgp, rep_id, total_reps = TOTAL_REPS, base_seed = BASE_SEED) {
  MOD      <- 2147483647                      # 2^31 - 1 (Mersenne prime)
  dgp_idx  <- match(dgp, c("dgp1", "dgp2", "dgp4", "dgp5"))
  if (anyNA(dgp_idx)) stop("Unknown dgp id in .data_seed(): ", paste(unique(dgp), collapse = ", "))
  offset   <- (as.double(dgp_idx) - 1) * total_reps + rep_id
  as.integer((base_seed + offset) %% MOD)
}

# -----------------------------------------------------------------------------
# .mcmc_seed() -- deterministic seed for the hit-and-run SAMPLER of a unit.
# Depends on (config_id, rep_id), so two lambdas sharing a dataset still get
# independent MCMC streams (they must: the same stream would induce a spurious
# common-random-numbers dependence between neighbouring lambda points on top of
# the intended shared-data pairing).
# -----------------------------------------------------------------------------
.mcmc_seed <- function(config_id, rep_id, total_reps = TOTAL_REPS, base_seed = BASE_SEED) {
  MOD    <- 2147483647
  offset <- (as.double(config_id) - 1) * total_reps + rep_id
  as.integer((base_seed + 1e6 + offset) %% MOD)
}

# -----------------------------------------------------------------------------
# unit_table() -- deterministic enumeration of all (config, rep) work units.
# Returns a data frame with columns: unit, config_id, rep_id, data_seed,
# mcmc_seed, plus the grid columns. unit runs 1..(nrow(GRID) * total_reps).
# -----------------------------------------------------------------------------
unit_table <- function(grid = GRID, total_reps = TOTAL_REPS, base_seed = BASE_SEED) {
  reps <- seq_len(total_reps)
  ut <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    data.frame(
      config_id = grid$config_id[i],
      rep_id    = reps,
      grid[i, setdiff(names(grid), "config_id"), drop = FALSE],
      row.names = NULL,
      stringsAsFactors = FALSE
    )
  }))
  ut$unit      <- seq_len(nrow(ut))
  ut$data_seed <- .data_seed(ut$dgp, ut$rep_id, total_reps, base_seed)
  ut$mcmc_seed <- .mcmc_seed(ut$config_id, ut$rep_id, total_reps, base_seed)
  ut[, c("unit", "config_id", "rep_id", "data_seed", "mcmc_seed",
         setdiff(names(ut), c("unit", "config_id", "rep_id", "data_seed", "mcmc_seed")))]
}

# Convenience: total number of work units at full TOTAL_REPS.
n_units <- function() nrow(GRID) * TOTAL_REPS
