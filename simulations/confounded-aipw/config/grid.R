# =============================================================================
# grid.R -- single source of truth for the "confounded-aipw" study
# =============================================================================
# GOAL: validate the OBSERVATIONAL (cross-fitted AIPW) path of
# tv_ball_correlation_IF_adaptive() against the randomized (importance-weighting,
# "IW") path. Four blocks, in increasing order of what they claim:
#
#   1. AGREEMENT -- the 4 canonical (RANDOMIZED) DGPs, each estimated BOTH ways.
#      Both paths are consistent here, so this is a smoke test: AIPW must
#      reproduce IW. A disagreement is an implementation bug, not a finding.
#   2. CONFOUNDED -- the 2 confounded DGPs (confounded_dgp_params()), each
#      estimated both ways. IW is PROVABLY biased here: it converges to the
#      propensity-tilted correlation `rho_iw_limit`, not to `rho_true`. AIPW
#      targets `rho_true`. This block is the study's actual content.
#   3. SMALLN -- one randomized and one confounded DGP at n = 250, both paths.
#      Supports the manuscript's small-n statement in
#      inst/paper/main.tex (\label{sec:sim-future}) with an actual run rather
#      than a promise. n = 250 is a STRESS regime: the plug-in correlation is
#      strongly attenuated at this sample size and this block is expected to
#      show that, not to hide it.
#   4. NGRID -- the SAME two anchor DGPs as SMALLN (dgp1 canonical, conf1
#      confounded), both paths, at n in {500, 2000, 40000}. Combined with
#      SMALLN's n=250 cell and AGREEMENT/CONFOUNDED's n=10000 cells for these
#      same two DGPs, this completes the 5-point finite-sample grid
#      n in {250, 500, 2000, 10000, 40000} promised in
#      inst/paper/main.tex (\label{sec:sim-future}) -- for these two DGPs only,
#      not the full 6-DGP grid, to keep the added compute bounded (n=40000 is
#      ~4x n=10000's per-unit cost). A separate block rather than folding into
#      SMALLN because SMALLN's name is specifically about the n=250 stress
#      regime; NGRID is about n-scaling and reuses the anchors, not the label.
#
# `conf2` is additionally a POSITIVITY stress regime (e(X) down to 0.039 in the
# rarest covariate cell), so AIPW is expected to degrade there relative to
# `conf1` -- reported, not suppressed.
#
# Work model (as in canonical-validation): one row per configuration; each
# configuration is run `reps` times; a "unit" is one (config, rep) pair; the seed
# is a deterministic function of (config_id, rep_id) only.
#
# DEVIATION from canonical-validation, stated deliberately: `reps` is a GRID
# COLUMN rather than a single global TOTAL_REPS, because the three blocks differ
# in per-unit cost by two orders of magnitude and in the precision they need. The
# per-unit seed is keyed on MAX_REPS so that changing any block's `reps` never
# changes an existing replication's seed.
# =============================================================================

STUDY_NAME   <- "confounded-aipw"
PROJECT_NAME <- "surrogate-transportability"

# Distinct seed range from canonical-validation (7.08e7) and
# generality-validation (8.08e7).
BASE_SEED <- 90900000L

# Seed-space stride per config. Must be >= max(GRID$reps); fixed so that raising
# a block's reps extends its stream instead of shifting every later config's.
MAX_REPS <- 1000L

LAMBDA  <- 0.3
N_LARGE <- 10000L   # the regime where both paths' asymptotics are readable
N_SMALL <- 250L     # the manuscript's small-n cell (stress)

# The three additional n-grid cells (with N_SMALL and N_LARGE, completes the
# 5-point grid n in {250, 500, 2000, 10000, 40000} for the NGRID block's two
# anchor DGPs). N_XLARGE gets its own cost stratum below: at ~4x N_LARGE's per
# n*M cost, sizing it together with N_LARGE would either time out the n=40000
# cells or waste wall time on the n=10000 ones.
N_MID_LOW  <- 500L
N_MID_HIGH <- 2000L
N_XLARGE   <- 40000L

# Adaptive-M ceiling. The estimator's cost is O(n * M) in interpreted loops and
# it allocates two n x M_final influence-function matrices, so M_max is the main
# cost/memory knob. Since v0.4.1 the adaptive rule stops on a direct Monte Carlo
# precision test (se_mc = (1 - rho^2) / sqrt(M) < mc_tolerance, default 0.02;
# see NEWS.md) rather than a difference-window test, and se_mc does not depend
# on n -- only on rho and M -- so M_max does NOT need to scale with n across
# this study's n-grid. Required M for se_mc < 0.02 at this study's least
# favorable observed rho (~0.69, tau = 1-rho^2 ~ 0.52) is
# (tau / 0.02)^2 ~ 676, comfortably under 1500 at every n, including N_XLARGE.
# 1500 keeps an n = 10000 unit near 32 s / 250 MB (on-cluster smoke estimate;
# the confounded block's harder cells ran slower in practice -- see MANIFEST.md).
M_START     <- 300L
M_INCREMENT <- 300L
M_MAX       <- 1500L

# Replications per block. Chosen so the Monte Carlo standard error of each
# reported mean is small relative to the effect being demonstrated: the
# confounded block's IW-vs-AIPW gap is ~0.6-1.2, far above the MC error of a
# mean over 80 replications. NGRID matches SMALLN's rep count so all 5 points
# of the shared n-grid have the same Monte Carlo precision, making the
# across-n comparison itself apples-to-apples rather than confounding
# precision differences with the n-attenuation being measured.
REPS_AGREEMENT <- 40L
REPS_CONFOUND  <- 80L
REPS_SMALLN    <- 120L
REPS_NGRID     <- 120L

# -----------------------------------------------------------------------------
# build_grid() -- the three blocks, rbind'd.
# `dgp_kind` selects which package spec accessor rebuilds the DGP:
#   "canonical"  -> canonical_dgp_params(dgp),   randomized A ~ Bernoulli(0.5)
#   "confounded" -> confounded_dgp_params(dgp),  A | X ~ Bernoulli(e(X))
# -----------------------------------------------------------------------------
build_grid <- function() {
  mk <- function(dgp_kind, dgp, n, method, reps, block) {
    data.frame(dgp_kind = dgp_kind, dgp = dgp, n = n, lambda = LAMBDA,
               method = method, reps = reps, block = block,
               stringsAsFactors = FALSE)
  }
  both <- c("importance_weighting", "aipw")

  b1 <- do.call(rbind, lapply(c("dgp1", "dgp2", "dgp4", "dgp5"), function(id)
    do.call(rbind, lapply(both, function(mm)
      mk("canonical", id, N_LARGE, mm, REPS_AGREEMENT, "agreement")))))

  b2 <- do.call(rbind, lapply(c("conf1", "conf2"), function(id)
    do.call(rbind, lapply(both, function(mm)
      mk("confounded", id, N_LARGE, mm, REPS_CONFOUND, "confounded")))))

  b3 <- rbind(
    do.call(rbind, lapply(both, function(mm)
      mk("canonical", "dgp1", N_SMALL, mm, REPS_SMALLN, "smalln"))),
    do.call(rbind, lapply(both, function(mm)
      mk("confounded", "conf1", N_SMALL, mm, REPS_SMALLN, "smalln")))
  )

  b4 <- do.call(rbind, lapply(c(N_MID_LOW, N_MID_HIGH, N_XLARGE), function(nn)
    rbind(
      do.call(rbind, lapply(both, function(mm)
        mk("canonical", "dgp1", nn, mm, REPS_NGRID, "ngrid"))),
      do.call(rbind, lapply(both, function(mm)
        mk("confounded", "conf1", nn, mm, REPS_NGRID, "ngrid")))
    )))

  grid <- rbind(b1, b2, b3, b4)
  grid$config_id <- seq_len(nrow(grid))
  grid
}

GRID <- build_grid()

# -----------------------------------------------------------------------------
# stratum_of() -- cost strata, for when this study is handed to the O2 scaffold.
# Per-unit cost here is dominated by n (more than two orders of magnitude
# between the n = 250 and n = 40000 cells), so sizing them together would
# either time out the large cells or waste wall time on the small ones. Three
# strata: small_n (< 5000: n=250, 500, 2000), large_n (n=10000), xlarge_n
# (n=40000, ~4x large_n's per-unit n*M cost).
# -----------------------------------------------------------------------------
stratum_of <- function(grid = GRID) {
  ifelse(grid$n >= 20000L, "xlarge_n",
         ifelse(grid$n >= 5000L, "large_n", "small_n"))
}

# -----------------------------------------------------------------------------
# .unit_seed() -- deterministic seed for a (config, rep) pair.
# Depends ONLY on (config_id, rep_id); independent of unit ORDERING and of any
# block's `reps`. Arithmetic is done in doubles and reduced mod 2^31-1, because
# base-R integer arithmetic overflows to NA past 2^31.
# -----------------------------------------------------------------------------
.unit_seed <- function(config_id, rep_id, max_reps = MAX_REPS, base_seed = BASE_SEED) {
  MOD    <- 2147483647                                   # 2^31 - 1
  offset <- (as.double(config_id) - 1) * max_reps + rep_id
  as.integer((base_seed + offset) %% MOD)
}

# -----------------------------------------------------------------------------
# unit_table() -- deterministic enumeration of all (config, rep) work units,
# carrying the per-config reference values so no downstream step recomputes them:
#   rho_true      -- the estimand both paths are meant to target
#   rho_iw_limit  -- what the IW path actually converges to (== rho_true for a
#                    randomized DGP, tilted away from it under confounding)
# -----------------------------------------------------------------------------
unit_table <- function(grid = GRID, max_reps = MAX_REPS, base_seed = BASE_SEED) {
  ut <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
    spec <- spec_for(grid[i, ])
    data.frame(
      config_id    = grid$config_id[i],
      rep_id       = seq_len(grid$reps[i]),
      grid[i, setdiff(names(grid), c("config_id", "reps")), drop = FALSE],
      rho_true     = spec$rho_true,
      rho_iw_limit = if (is.null(spec$rho_iw_limit)) spec$rho_true else spec$rho_iw_limit,
      row.names = NULL, stringsAsFactors = FALSE
    )
  }))
  ut$unit <- seq_len(nrow(ut))
  ut$seed <- .unit_seed(ut$config_id, ut$rep_id, max_reps, base_seed)
  lead <- c("unit", "config_id", "rep_id", "seed", "rho_true", "rho_iw_limit")
  ut[, c(lead, setdiff(names(ut), lead))]
}

n_units <- function(grid = GRID) sum(grid$reps)
