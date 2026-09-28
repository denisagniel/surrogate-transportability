# =============================================================================
# cell_cates.R -- analytic cell-level CATEs for the canonical DGP
# =============================================================================
# The canonical DGP is linear with a single 5-level covariate, so the cell-level
# treatment effects on surrogate and outcome are available in CLOSED FORM. They
# are needed twice in this study, which is why they live in their own file:
#
#   1. estimators.R -- the interior-regime truth Corr_K(tau_S, tau_Y), which
#      Proposition "Interior-regime closed form" (inst/paper/theory.tex) says
#      equals Theta(P_0, lambda) EXACTLY for every lambda <= min_k p_0(k).
#   2. exit_interior_prediction.R -- the MCMC-free sign prediction of
#      d/dlambda^+ Theta at lambda = p_min (Proposition "First-order exit from
#      the interior regime").
#
# Derivation, for the DGP of generate_dgp_data():
#   S = (gamma_A + gamma_AX x) A + eps_S
#   Y = (beta_A + beta_AX x) A + beta_S S + beta_SX S x + eps_Y
# so, at covariate cell x,
#   tau_S(x) = gamma_A + gamma_AX x
#   tau_Y(x) = E[Y | A=1, x] - E[Y | A=0, x]
#            = (beta_A + beta_AX x) + (beta_S + beta_SX x) * tau_S(x)
# the second term being the indirect path through S (whose own A-effect is
# tau_S(x) and whose Y-coefficient is beta_S + beta_SX x).
# =============================================================================

#' Analytic cell-level CATEs for a canonical DGP
#'
#' @param dgp Character canonical id ("dgp1", "dgp2", "dgp4", "dgp5").
#' @return A list with `x` (covariate levels), `p0` (cell probabilities),
#'   `tau_S`, `tau_Y` (cell CATEs on surrogate and outcome).
cell_cates <- function(dgp) {
  spec <- canonical_dgp_params(dgp)   # errors on unknown id (no silent fallback)
  p    <- spec$params
  x    <- spec$X_levels

  tau_S <- p$gamma_A + p$gamma_AX * x
  tau_Y <- (p$beta_A + p$beta_AX * x) + (p$beta_S + p$beta_SX * x) * tau_S

  list(x = x, p0 = spec$p_X, tau_S = tau_S, tau_Y = tau_Y)
}

#' Interior-regime value of Theta: the UNWEIGHTED Pearson correlation of cell CATEs
#'
#' Proposition "Interior-regime closed form" (inst/paper/theory.tex): for
#' lambda <= min_k p_0(k), Theta(P_0, lambda) = Corr_K(tau_S, tau_Y), the ordinary
#' (equally-weighted, NOT p_0-weighted) Pearson correlation of the K cell CATEs,
#' independent of lambda and of p_0's composition.
#'
#' @param dgp Character canonical id.
#' @return Numeric scalar.
corr_K_cell_cates <- function(dgp) {
  cc <- cell_cates(dgp)
  stats::cor(cc$tau_S, cc$tau_Y)   # unweighted Pearson == Corr_K
}
