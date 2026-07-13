# =============================================================================
# grid.R -- single source of truth for the "generality-validation" study
# =============================================================================
# GOAL: show the canonical TV-ball correlation estimator (importance_weighting /
# RCT path, WAVE 1) works IN GENERAL -- not on 4 hand-picked DGPs. Three blocks:
#
#   1. ENSEMBLE  -- N_ENS random DGPs (draw_random_dgp, RCT-only) at large n,
#                   plus a subset repeated across an n-grid (generality x n).
#   2. STRESSORS -- the 4 canonical DGPs (structural anchors incl. dgp5 stress).
#   3. NSCALE    -- one canonical anchor (dgp1) across a fine n-grid to document
#                   the finite-n attenuation and the jackknife's effect.
#
# Each config carries dgp_kind ("random"/"canonical"), the info to rebuild the
# DGP (dgp id OR dgp_seed), n, lambda, method, and a PRECOMPUTED rho_true.
# rho_true is filled by build_truth_table() (run offline once; cached to
# config/truth_table.rds) so cluster jobs never recompute the exact truth.
#
# Work model (unchanged from canonical-validation): one row per config; each run
# TOTAL_REPS times; a "unit" = (config, rep); seed = BASE_SEED + unit index.
# =============================================================================

STUDY_NAME   <- "generality-validation"
PROJECT_NAME <- "surrogate-transportability"

BASE_SEED <- 80800000L      # distinct range from canonical-validation
TOTAL_REPS <- 500L          # ensemble reads across-DGP distribution; 500 is ample

# --- Design knobs ------------------------------------------------------------
ENS_SEED0    <- 8000L                  # base rng_seed for draw_random_dgp
N_LARGE      <- 10000L                 # "operating" sample size
N_GRID       <- c(500L, 2000L, 10000L, 40000L)  # n-scaling grid
N_ENS_NGRID  <- 12L                    # ensemble DGPs also run across N_GRID
LAMBDA       <- 0.3
METHOD       <- "importance_weighting" # WAVE 1

# Ensemble seeds: a rho-BALANCED subset (build_balanced_seeds) cached offline to
# config/ensemble_seeds.rds. Raw draws pile up at |rho|~1 (easy cases); the
# balanced set flattens rho across [-1,1] so the ensemble actually stresses the
# estimator. Fall back to a naive contiguous block if the cache is absent (with
# a loud warning) so the grid is still constructable for smoke tests.
.ensemble_seeds <- function(study_dir = ".") {
  f <- file.path(study_dir, "config", "ensemble_seeds.rds")
  if (file.exists(f)) return(readRDS(f))
  warning("config/ensemble_seeds.rds not found; using naive seed block ",
          "(rho NOT balanced). Run slurm/prep_offline.R first.")
  ENS_SEED0 + seq_len(60L)
}
ENS_SEEDS <- .ensemble_seeds(tryCatch(get("opt")$study_dir, error = function(e) "."))
N_ENS     <- length(ENS_SEEDS)

# Load the DGP samplers so build_truth_table() (and any grid construction that
# needs specs) works when this file is sourced standalone.
if (!exists("draw_random_dgp")) {
  .sd <- tryCatch(get("opt")$study_dir, error = function(e) ".")
  source(file.path(.sd, "R", "random_dgp.R"))
  source(file.path(.sd, "R", "true_rho.R"))
}

# --- Build the config grid (heterogeneous blocks, rbind'd) -------------------
build_grid <- function() {
  cols <- c("dgp_kind", "dgp", "dgp_seed", "n", "lambda", "method")
  mk <- function(dgp_kind, dgp, dgp_seed, n) {
    data.frame(dgp_kind = dgp_kind, dgp = dgp, dgp_seed = dgp_seed,
               n = n, lambda = LAMBDA, method = METHOD,
               stringsAsFactors = FALSE)
  }

  # Block 1a: ensemble at large n (rho-balanced seeds)
  b1a <- do.call(rbind, lapply(ENS_SEEDS, function(s)
    mk("random", NA_character_, s, N_LARGE)))
  # Block 1b: a subset of ensemble DGPs across the n-grid (generality x n)
  b1b <- do.call(rbind, lapply(head(ENS_SEEDS, N_ENS_NGRID), function(s)
    do.call(rbind, lapply(setdiff(N_GRID, N_LARGE), function(nn)
      mk("random", NA_character_, s, nn)))))

  # Block 2: structural anchors (the 4 canonical DGPs) at large n
  b2 <- do.call(rbind, lapply(c("dgp1", "dgp2", "dgp4", "dgp5"), function(id)
    mk("canonical", id, NA_integer_, N_LARGE)))

  # Block 3: n-scaling on dgp1 anchor
  b3 <- do.call(rbind, lapply(setdiff(N_GRID, N_LARGE), function(nn)
    mk("canonical", "dgp1", NA_integer_, nn)))

  grid <- rbind(b1a, b1b, b2, b3)
  grid$config_id <- seq_len(nrow(grid))
  grid
}

GRID <- build_grid()

# --- Exact truth per config (offline; cached) --------------------------------
# For canonical: analytic CATEs. For random: reconstruct spec, use its CATEs.
# M_ref large so across-seed error << CI half-width in every cell.
build_truth_table <- function(grid = GRID, M_ref = 100000L, thin = 20L,
                              seed = 20260713L) {
  vapply(seq_len(nrow(grid)), function(i) {
    g <- grid[i, ]
    if (g$dgp_kind == "canonical") {
      sp <- canonical_dgp_params(g$dgp)
      cc <- canonical_cates(sp$params, sp$X_levels)
      true_rho_from_cates(cc$tau_S, cc$tau_Y, sp$p_X, g$lambda,
                          M_ref = M_ref, thin = thin, seed = seed)$rho_true
    } else {
      sp <- draw_random_dgp(rng_seed = g$dgp_seed, allow_observational = FALSE)
      true_rho_from_cates(sp$tau_S, sp$tau_Y, sp$p_X, g$lambda,
                          M_ref = M_ref, thin = thin, seed = seed)$rho_true
    }
  }, numeric(1))
}

# Load cached truth table if present; else NA (build offline before submit).
.truth_file <- function(study_dir = ".") file.path(study_dir, "config", "truth_table.rds")
load_truth <- function(study_dir = ".") {
  f <- .truth_file(study_dir)
  if (file.exists(f)) readRDS(f) else rep(NA_real_, nrow(GRID))
}

# -----------------------------------------------------------------------------
# unit_table() -- deterministic (config, rep) enumeration + per-unit seed + truth
# -----------------------------------------------------------------------------
unit_table <- function(grid = GRID, total_reps = TOTAL_REPS, base_seed = BASE_SEED,
                       truth = NULL, study_dir = ".") {
  if (is.null(truth)) truth <- load_truth(study_dir)
  reps <- seq_len(total_reps)
  ut <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    data.frame(
      config_id = grid$config_id[i],
      rep_id    = reps,
      grid[i, setdiff(names(grid), "config_id"), drop = FALSE],
      rho_true  = truth[i],
      row.names = NULL, stringsAsFactors = FALSE
    )
  }))
  ut$unit <- seq_len(nrow(ut))
  ut$seed <- base_seed + ut$unit
  ut[, c("unit", "config_id", "rep_id", "seed", "rho_true",
         setdiff(names(ut), c("unit", "config_id", "rep_id", "seed", "rho_true")))]
}

n_units <- function() nrow(GRID) * TOTAL_REPS
