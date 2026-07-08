# =============================================================================
# 04_shape_varied_dgps.R -- non-polynomial DGPs + off-the-shelf (grf) CATE, to
# test GENERALIZABILITY: does a data-adaptive CATE learner beat hand-tuned poly2
# on CATE shapes that poly2 cannot match? EXPLORATION (fast-track).
#
# The canonical DGPs have tau_S linear, tau_Y quadratic in X, so poly2 is
# "cheating" (given the true basis). Here we build DGPs with tau shapes that a
# degree-2 polynomial in a 5-level X CANNOT represent well, and we use a
# CONTINUOUS X (10 discretization cells) so smoothing/forests are meaningful.
#
# CATE truth is specified directly via tau_S(x), tau_Y(x); we then build
# S = tau_S(X)*A + noise, Y = tau_Y(X)*A + beta_S*S + noise (S enters Y so the
# two CATEs are related but NOT collinear). The across-study correlation truth is
# computed analytically from the cell CATE vectors under Sigma_q, as before.
# =============================================================================

# --- shape-varied DGPs on continuous X in [-2, 2], discretized into cells ------
# Each entry: tau_S(x), tau_Y_direct(x) (direct effect on Y), beta_S (S->Y).
# tau_Y(x) = tau_Y_direct(x) + beta_S * tau_S(x).
SHAPE_DGPS <- list(
  threshold = list(  # step change: poly2 cannot fit a threshold
    tau_S = function(x) 0.5 + 1.0 * (x > 0),
    tau_Yd = function(x) 0.3 + 0.8 * (x > 0.5),
    beta_S = 0.6, sigma = 0.5,
    label = "threshold (step) CATEs"
  ),
  sinusoid = list(  # oscillating: degree-2 poly cannot capture a full period
    tau_S = function(x) sin(1.5 * x),
    tau_Yd = function(x) 0.4 * cos(1.5 * x),
    beta_S = 0.7, sigma = 0.5,
    label = "sinusoidal CATEs"
  ),
  monotone_nl = list(  # monotone but nonlinear (logistic): mild curvature
    tau_S = function(x) plogis(2 * x),
    tau_Yd = function(x) 0.5 * plogis(1.5 * x - 0.5),
    beta_S = 0.8, sigma = 0.5,
    label = "monotone nonlinear (logistic) CATEs"
  )
)

gen_shape_data <- function(n, dgp, x_sd = 1) {
  X <- runif(n, -2, 2)                       # continuous covariate
  A <- rbinom(n, 1, 0.5)
  tS <- dgp$tau_S(X)
  S <- tS * A + rnorm(n, sd = dgp$sigma)
  Y <- dgp$tau_Yd(X) * A + dgp$beta_S * S + rnorm(n, sd = dgp$sigma)
  data.frame(X = X, A = A, S = S, Y = Y)
}

# cell CATE truth on a discretization grid (for the analytic across-study rho)
shape_true_cate <- function(dgp, x_cells) {
  tS <- dgp$tau_S(x_cells)
  tY <- dgp$tau_Yd(x_cells) + dgp$beta_S * dgp$tau_S(x_cells)
  list(tS = tS, tY = tY)
}

# --- off-the-shelf CATE via grf::causal_forest, ONE OUTCOME AT A TIME ----------
# Returns per-cell CATE (predicted at cell centers) + per-cell variance.
# W.hat = 0.5 (known RCT propensity). Separate forest per outcome => safe.
cate_grf <- function(y, A, X, x_cells) {
  if (!requireNamespace("grf", quietly = TRUE)) stop("grf not installed")
  cf <- grf::causal_forest(X = matrix(X, ncol = 1), Y = y, W = A,
                           W.hat = 0.5, num.trees = 500)
  pr <- predict(cf, newdata = matrix(x_cells, ncol = 1), estimate.variance = TRUE)
  list(tau = pr$predictions, var = pr$variance.estimates)
}

# raw per-cell diff-in-means on a discretized continuous X (bin to cells)
discretize_X <- function(X, n_cells = 10) {
  br <- quantile(X, probs = seq(0, 1, length.out = n_cells + 1))
  br[1] <- -Inf; br[length(br)] <- Inf
  cell <- cut(X, breaks = br, labels = FALSE)
  centers <- tapply(X, cell, mean)
  list(cell = cell, centers = as.numeric(centers[order(as.integer(names(centers)))]))
}
