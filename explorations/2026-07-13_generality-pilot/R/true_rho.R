# =============================================================================
# true_rho.R -- exact across-study correlation for ANY DGP on finite X-support
# =============================================================================
# The estimand of tv_ball_correlation_IF_adaptive() is
#   Theta = cor_mu( Delta_S(Q), Delta_Y(Q) ),  Q ~ Uniform(TV-ball(P0, lambda)),
# with per-study effects Delta_S(Q) = sum_k q_k tau_S(k),  Delta_Y(Q) = sum_k q_k tau_Y(k)
# (derivation_influence_functions.md, §1). The cell CATEs tau_S(k), tau_Y(k) are
# properties of the DGP's MEAN structure and do NOT depend on the error law.
#
# So given the cell CATEs and Q-draws from the ball, the truth is EXACT (up to
# MCMC error in the draws, driven to negligible by large M_ref). No per-study
# data simulation, no dependence on error distribution -> non-Gaussian errors
# are free stressors that leave the truth unchanged.
#
# This lives in explorations/ during the pilot; graduates to R/true_rho.R
# (package) in Phase 1 if it checks out.
# =============================================================================

# --- Core: exact rho given cell CATEs ----------------------------------------
# tau_S, tau_Y : numeric K-vectors, cell CATEs at each X-level (same order as p_X)
# p_X          : K-vector, reference covariate distribution (ball center), sums to 1
# lambda       : TV-ball radius
# M_ref        : number of Q-draws for the reference average (large -> exact)
# returns      : list(rho_true, mean_dS, sd_dS, mean_dY, sd_dY, M_ref)
true_rho_from_cates <- function(tau_S, tau_Y, p_X, lambda,
                                M_ref = 20000L, burn_in = 2000L, thin = 20L,
                                seed = 20260713L) {
  stopifnot(length(tau_S) == length(p_X), length(tau_Y) == length(p_X),
            abs(sum(p_X) - 1) < 1e-8)
  set.seed(seed)

  Q <- sample_tv_ball(P0 = p_X, lambda = lambda, M = M_ref,
                      burn_in = burn_in, thin = thin, verbose = FALSE)

  # Delta_S(Q_m) = sum_k q_mk tau_S(k)  ==  Q %*% tau  (vectorized over draws)
  dS <- as.numeric(Q %*% tau_S)
  dY <- as.numeric(Q %*% tau_Y)

  list(
    rho_true = stats::cor(dS, dY),
    mean_dS = mean(dS), sd_dS = sd(dS),
    mean_dY = mean(dY), sd_dY = sd(dY),
    M_ref = M_ref
  )
}

# --- Canonical-family CATEs (analytic) ---------------------------------------
# For the linear canonical DGP (dgp_canonical.R):
#   S = (gamma_A + gamma_AX X) A + eps_S
#   Y = (beta_A + beta_AX X) A + beta_S S + beta_SX (S X) + eps_Y
# =>  tau_S(k) = gamma_A + gamma_AX k
#     E[S|A=a,k] = (gamma_A + gamma_AX k) a
#     tau_Y(k) = (beta_A + beta_AX k) + (beta_S + beta_SX k)(gamma_A + gamma_AX k)
canonical_cates <- function(params, X_levels) {
  g <- params
  tau_S <- g$gamma_A + g$gamma_AX * X_levels
  tau_Y <- (g$beta_A + g$beta_AX * X_levels) +
           (g$beta_S + g$beta_SX * X_levels) * (g$gamma_A + g$gamma_AX * X_levels)
  list(tau_S = tau_S, tau_Y = tau_Y)
}

# Convenience wrapper for a canonical spec id.
true_rho_canonical <- function(spec, M_ref = 20000L, seed = 20260713L) {
  cc <- canonical_cates(spec$params, spec$X_levels)
  true_rho_from_cates(cc$tau_S, cc$tau_Y, spec$p_X, spec$lambda,
                      M_ref = M_ref, seed = seed)
}
