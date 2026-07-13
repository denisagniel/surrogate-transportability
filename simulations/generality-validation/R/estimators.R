# =============================================================================
# estimators.R -- IW estimator + jackknife bias correction (generality study)
# =============================================================================
# WAVE 1 = importance_weighting (RCT) only. AIPW (fit-once, Mode 1) is wave 2.
#
# Two estimates per unit:
#   rho_raw  -- the canonical plug-in (tv_ball_correlation_IF_adaptive), with its
#               influence-function SE / CI.
#   rho_jk   -- grouped delete-block JACKKNIFE bias-corrected rho (validated
#               ensemble-wide in Phase 0: halves bias at n<=2000, harmless at
#               large n). CI via the IF SE recentred at the corrected point (the
#               jackknife corrects the point estimate; the sampling variance is
#               essentially unchanged, Phase 0).
#
# The jackknife is VECTORIZED: build the M x n importance-weight matrix ONCE from
# the fixed pre-sampled Q draws, then each delete-block rho is a Hajek weighted
# correlation over a column subset -- no MCMC, no refit. Uses the SAME Q draws as
# the raw estimator (re-derived from its seed) so raw and jackknife are coherent.
# =============================================================================

.EST_SETTINGS <- list(
  M_start = 300L, M_increment = 300L, M_max = 5000L,
  tolerance = 0.01, n_stable = 3L, burn_in = 500L, thin = 5L, alpha = 0.05
)

# Number of jackknife groups (delete-block). G=20 validated in Phase 0.
.JK_GROUPS <- 20L

estimate <- function(data, config) {
  switch(
    config$method,
    importance_weighting = .est_iw_with_jackknife(data, config),
    stop(sprintf("Unknown method: '%s'", config$method))  # no silent fallback
  )
}

# --- IW raw estimate + vectorized jackknife ----------------------------------
.est_iw_with_jackknife <- function(data, config) {
  s <- .EST_SETTINGS

  # Raw canonical estimator (authoritative rho_raw + IF-based SE/CI).
  res <- tv_ball_correlation_IF_adaptive(
    data = data, lambda = config$lambda, method = "importance_weighting",
    M_start = s$M_start, M_increment = s$M_increment, M_max = s$M_max,
    tolerance = s$tolerance, n_stable = s$n_stable, burn_in = s$burn_in,
    thin = s$thin, alpha = s$alpha, verbose = FALSE
  )

  # Jackknife bias correction, conditioned on M_final Q-draws. Re-sample the same
  # Q's the estimator used (its RNG is set inside; we reproduce with a fixed seed
  # tied to the unit so raw and jackknife share draws). Then delete-block.
  jk <- .jackknife_rho(data, config, M = res$M_final,
                       burn_in = s$burn_in, thin = s$thin, G = .JK_GROUPS)

  z <- stats::qnorm(1 - s$alpha / 2)
  list(
    estimate   = res$rho_hat,
    std_error  = res$se,
    ci_lower   = res$ci_lower,
    ci_upper   = res$ci_upper,
    M_final    = res$M_final,
    converged  = isTRUE(res$converged),
    # jackknife-corrected point estimate + CI (IF SE recentred at corrected point)
    rho_jk     = jk$rho_jk,
    jk_bias    = jk$bias,
    ci_lower_jk = jk$rho_jk - z * res$se,
    ci_upper_jk = jk$rho_jk + z * res$se
  )
}

# Vectorized grouped jackknife for the IW correlation of Delta's.
# Delta_S(Q_m) = Hajek weighted diff-in-means; recomputed on obs subsets by
# subtracting each block's weighted sums (O(M*n) once, O(M) per fold).
.jackknife_rho <- function(data, config, M, burn_in, thin, G = 20L,
                           seed_offset = 90000000L) {
  X_levels <- sort(unique(data$X))
  p0 <- as.numeric(table(factor(data$X, levels = X_levels))) / nrow(data)
  n <- nrow(data)

  # Fixed Q draws (own seed so jackknife is reproducible per unit).
  set.seed(seed_offset + config$seed %% 1000000L)
  Q <- sample_tv_ball(P0 = p0, lambda = config$lambda, M = M,
                      burn_in = burn_in, thin = thin, verbose = FALSE)

  k_i <- match(data$X, X_levels)
  W <- Q[, k_i, drop = FALSE] / matrix(p0[k_i], M, n, byrow = TRUE)  # M x n weights
  A <- data$A; S <- data$S; Y <- data$Y

  # Full-sample per-arm weighted sums (M-vectors).
  sumW1 <- W %*% A;            sumW0 <- W %*% (1 - A)
  sumS1 <- W %*% (S * A);      sumS0 <- W %*% (S * (1 - A))
  sumY1 <- W %*% (Y * A);      sumY0 <- W %*% (Y * (1 - A))

  rho_from_sums <- function(w1, w0, s1, s0, y1, y0) {
    dS <- s1 / w1 - s0 / w0
    dY <- y1 / w1 - y0 / w0
    stats::cor(dS, dY)
  }
  rho_full <- rho_from_sums(sumW1, sumW0, sumS1, sumS0, sumY1, sumY0)

  grp <- sample(rep(seq_len(G), length.out = n))
  rho_mg <- numeric(G)
  for (g in seq_len(G)) {
    keep <- grp != g
    Wg <- W[, keep, drop = FALSE]
    Ag <- A[keep]; Sg <- S[keep]; Yg <- Y[keep]
    rho_mg[g] <- rho_from_sums(
      Wg %*% Ag, Wg %*% (1 - Ag),
      Wg %*% (Sg * Ag), Wg %*% (Sg * (1 - Ag)),
      Wg %*% (Yg * Ag), Wg %*% (Yg * (1 - Ag))
    )
  }
  bias <- (G - 1) * (mean(rho_mg) - rho_full)
  rho_jk <- max(min(rho_full - bias, 1), -1)
  list(rho_jk = rho_jk, bias = bias, rho_full = rho_full)
}

# True across-study correlation for this config (exact, per-cell truth table).
# The grid attaches rho_true to each unit row (precomputed offline); fall back to
# on-the-fly true_rho() if absent.
true_value <- function(config) {
  if (!is.null(config$rho_true) && !is.na(config$rho_true)) return(config$rho_true)
  stop("rho_true missing for this config; precompute the truth table (grid.R).")
}
