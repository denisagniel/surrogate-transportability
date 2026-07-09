# =============================================================================
# dgp_theta.R -- Stage 2 DGP + geometry: end-to-end correlation Theta on
# continuous X via a discretize-to-cells geometry.
# =============================================================================
# Reuses the Stage 1 smooth DGP (generate_stage1). For Stage 2 we additionally:
#   * discretize X into K equal-probability cells (quantile bins on [0,1]^d, d=1
#     here) to sample the TV-ball geometry with the package's hit-and-run sampler;
#   * sample Sigma = Cov_mu(q) over M draws (FIXED given the draws -- conditional
#     on the geometry, matching the audited proof);
#   * define the TRUE Theta from the true cell CATEs and that same Sigma:
#       Theta_true = tau_S' Sigma tau_Y / sqrt( (tau_S' Sigma tau_S)(tau_Y' Sigma tau_Y) ),
#     where tau_a are the DGP CATEs averaged within each cell (population values).
#
# The estimator (theta_estimator.R) plugs cross-fit grf CATEs into the SAME Sigma.
# Requires the package's sample_tv_ball(); loaded via library(surrogateTransportability).
# =============================================================================

# cell edges: K equal-probability bins on [0,1] (d=1). Returns breakpoints.
cell_edges <- function(K) seq(0, 1, length.out = K + 1L)

# assign X (n x 1, in [0,1]) to cells 1..K
assign_cells <- function(x, K) {
  edges <- cell_edges(K)
  cl <- findInterval(x, edges, rightmost.closed = TRUE, all.inside = TRUE)
  pmin(pmax(cl, 1L), K)
}

# baseline cell probabilities p0(k) under Uniform[0,1] = 1/K (equal bins).
cell_p0 <- function(K) rep(1 / K, K)

# population cell CATE: average of tau_a(x) over cell k under Uniform. Computed by
# fine quadrature of the true cosine-series CATE within each bin. y_decorr applies
# the same alternating-sign mixing to the Y CATE as generate_stage1() (so truth
# matches the DGP when tau_Y is decorrelated from tau_S).
true_cell_cate <- function(cfg, which = "S", K = 10L, ngrid = 2000L, c_scale = 1,
                           y_decorr = 0) {
  s <- if (which == "S") cfg$s_S else cfg$s_Y
  b <- cate_basis(s, 1L, 200L)
  if (which == "Y" && y_decorr != 0) {
    j1 <- b$freqs[, 1]
    b$decay <- b$decay * (1 - 2 * y_decorr * (j1 %% 2))
  }
  xg <- (seq_len(ngrid) - 0.5) / ngrid
  tg <- eval_cate(matrix(xg, ncol = 1), b, c_scale)
  cl <- assign_cells(xg, K)
  as.numeric(tapply(tg, factor(cl, levels = seq_len(K)), mean))
}

# sample the TV-ball geometry -> Sigma (K x K) = Cov over M sampled reweightings.
# Uses the package sampler on the baseline p0 (equal bins).
sample_geometry <- function(K, lambda, M = 800, burn_in = 200, thin = 2) {
  p0 <- cell_p0(K)
  Q <- sample_tv_ball(p0, lambda, M = M, burn_in = burn_in, thin = thin, verbose = FALSE)
  # Sigma = Cov_mu(q) over the M draws (each row is a distribution over cells).
  stats::cov(Q)
}

# true Theta given true cell CATEs and a sampled Sigma.
theta_true_from_cells <- function(tS, tY, Sig) {
  num <- as.numeric(t(tS) %*% Sig %*% tY)
  a   <- as.numeric(t(tS) %*% Sig %*% tS)
  b   <- as.numeric(t(tY) %*% Sig %*% tY)
  num / sqrt(a * b)
}
