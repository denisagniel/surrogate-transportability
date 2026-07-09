# =============================================================================
# grid.R -- single source of truth for the "a5-elbow-validation" exploration
# =============================================================================
# Defines the Stage 1 (elbow-isolation) and Stage 2 (end-to-end Theta) design
# grids, replication counts, seeds, and the deterministic unit enumeration.
# Mirrors simulations/canonical-validation/config/grid.R so this can graduate.
# Nothing here has side effects beyond assigning objects.
# =============================================================================

STUDY_NAME   <- "a5-elbow-validation"
PROJECT_NAME <- "surrogate-transportability"

# Per-unit seeds are BASE_SEED + unit_index (independent, reproducible, parallel-safe).
BASE_SEED <- 70900000L

# Replication counts. Local fast-track used 200; the cluster run uses 1000.
REPS_STAGE1 <- 1000L
REPS_STAGE2 <- 200L

# -----------------------------------------------------------------------------
# Stage 1 design points: continuous-X DGPs with a Sobolev smoothness knob.
#
# TWO thresholds matter, and they differ:
#   * HOIF / information-theoretic elbow:  s_S + s_Y > d/2   (A5 as cited; only
#     ATTAINED by higher-order-IF estimators).
#   * FIRST-ORDER one-step boundary:       sum of L2 rate exponents
#     s_S/(2 s_S+d) + s_Y/(2 s_Y+d) > 1/2, i.e. (equal case) s_S + s_Y > d.
#     This is what Theorem A's one-step estimator actually attains.
#
# Theorem A constructs the FIRST-ORDER estimator, so the honest boundary for it
# is s_S + s_Y > d. Design points span three regimes:
#   above   (sum > d):        first-order sqrt(n)         [A_above, D2_above]
#   gap     (d/2 < sum <= d):  functional HOIF-estimable, first-order FAILS
#                              -- the evidence that the paper must state s>d,
#                              not s>d/2, for the one-step estimator [E_edge, G_gap]
#   below   (sum <= d/2):      not even HOIF-estimable at sqrt(n)   [B_below]
# n-grid spans the range where the slope of log(RMSE)~log(n) separates
# above (-1/2) from gap/below (shallower, ~ -fo_exp).
# -----------------------------------------------------------------------------
STAGE1_DESIGN <- data.frame(
  design = c("A_above", "D2_above", "E_edge", "G_gap", "B_below"),
  d      = c(1L,        2L,         1L,       1L,      1L),
  s_S    = c(0.8,       1.2,        0.5,      0.4,     0.2),
  s_Y    = c(0.8,       1.2,        0.5,      0.4,     0.2),
  regime = c("above",   "above",    "edge",   "gap",   "below"),
  stringsAsFactors = FALSE
)

STAGE1_N <- c(500L, 1000L, 2000L, 4000L, 8000L, 16000L)

# Which functional pair to estimate. SY is the headline (cross bilinear); SS/YY
# are the diagonal variance functionals used to build Theta in Stage 2.
STAGE1_PAIR <- c("SY", "SS", "YY")

# NOTE: `estimator` (debiased vs plugin) is NOT a grid dimension -- run_one_stage1()
# emits BOTH estimators per replication (two rows). Adding it to the grid would
# double-count the Monte Carlo work.
STAGE1_GRID <- expand.grid(
  design    = STAGE1_DESIGN$design,
  n         = STAGE1_N,
  pair      = STAGE1_PAIR,
  stringsAsFactors = FALSE
)
# Attach the smoothness columns for each design row.
STAGE1_GRID <- merge(STAGE1_GRID, STAGE1_DESIGN, by = "design", sort = FALSE)
STAGE1_GRID$config_id <- seq_len(nrow(STAGE1_GRID))

# -----------------------------------------------------------------------------
# Stage 2 design points: end-to-end correlation Theta, discretize-to-cells
# geometry. One DGP above the elbow (expect nominal coverage), one near it
# (expect honest degradation).
# -----------------------------------------------------------------------------
STAGE2_DESIGN <- data.frame(
  design = c("above", "near"),
  d      = c(1L,       1L),
  s_S    = c(1.0,      0.35),
  s_Y    = c(1.0,      0.35),
  stringsAsFactors = FALSE
)

STAGE2_GRID <- expand.grid(
  design = STAGE2_DESIGN$design,
  n      = c(2000L, 8000L),
  lambda = 0.3,
  K      = 10L,      # number of discretization cells for the geometry
  stringsAsFactors = FALSE
)
STAGE2_GRID <- merge(STAGE2_GRID, STAGE2_DESIGN, by = "design", sort = FALSE)
STAGE2_GRID$config_id <- seq_len(nrow(STAGE2_GRID))

# -----------------------------------------------------------------------------
# unit_table() -- deterministic enumeration of all (config, rep) work units for
# a given stage grid. Returns unit, config_id, rep_id, seed + grid columns.
# rep varies fastest within a config (contiguous reps per config).
# -----------------------------------------------------------------------------
unit_table <- function(grid, total_reps, base_seed = BASE_SEED, seed_offset = 0L) {
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
  ut$unit <- seq_len(nrow(ut))
  ut$seed <- base_seed + seed_offset + ut$unit
  ut[, c("unit", "config_id", "rep_id", "seed",
         setdiff(names(ut), c("unit", "config_id", "rep_id", "seed")))]
}

# Stage 2 uses a disjoint seed range so no unit collides with Stage 1.
unit_table_stage1 <- function(reps = REPS_STAGE1) {
  unit_table(STAGE1_GRID, reps, seed_offset = 0L)
}
unit_table_stage2 <- function(reps = REPS_STAGE2) {
  unit_table(STAGE2_GRID, reps, seed_offset = 10000000L)
}
