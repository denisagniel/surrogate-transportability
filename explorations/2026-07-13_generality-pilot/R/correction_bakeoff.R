# =============================================================================
# correction_bakeoff.R -- compare bias-correction strategies for rho_hat
# =============================================================================
# The plug-in rho attenuates toward 0 at small n (correlation of noisy Delta's).
# We compare four corrections against EXACT truth (true_rho()):
#   (1) none        -- raw plug-in
#   (2) eiv_bounded -- moment-subtraction disattenuation, reliability-guarded
#   (3) jackknife   -- grouped delete-block jackknife bias correction
#   (4) simex       -- simulation-extrapolation using the per-study IF error cov
#
# SPEED TRICK: condition on ONE fixed set of Q-draws (mu_M). Given fixed Q, the
# IW per-study effects Delta_S(Q_m), Delta_Y(Q_m) are Hajek weighted means over
# observations -- recomputable on any resample WITHOUT MCMC or refitting. So
# jackknife/bootstrap/SIMEX become cheap. The MCMC/M error is a separate,
# established term (§4); we hold M large and fixed to isolate the finite-n bias.
# =============================================================================

# Pre-sample Q once (shared across all corrections + resamples for a given rep).
make_Q <- function(p_X, lambda, M = 1500L, burn_in = 2000L, thin = 15L, seed = 1L) {
  set.seed(seed)
  sample_tv_ball(P0 = p_X, lambda = lambda, M = M, burn_in = burn_in,
                thin = thin, verbose = FALSE)
}

# Fast IW per-study effects given fixed Q. Returns M-vectors Delta_S, Delta_Y.
# Wmat[m,i] = Q[m, k_i] / p0[k_i]  (importance weight of obs i under study m).
iw_deltas <- function(data, Q, p_X, X_levels, idx = NULL) {
  if (!is.null(idx)) data <- data[idx, , drop = FALSE]
  k_i <- match(data$X, X_levels)
  n <- nrow(data)
  Wmat <- Q[, k_i, drop = FALSE] / matrix(p_X[k_i], nrow(Q), n, byrow = TRUE)
  A <- data$A; S <- data$S; Y <- data$Y
  dA1 <- Wmat %*% A;         dA0 <- Wmat %*% (1 - A)
  S1 <- (Wmat %*% (S * A)) / dA1;  S0 <- (Wmat %*% (S * (1 - A))) / dA0
  Y1 <- (Wmat %*% (Y * A)) / dA1;  Y0 <- (Wmat %*% (Y * (1 - A))) / dA0
  list(dS = as.numeric(S1 - S0), dY = as.numeric(Y1 - Y0))
}

rho_from_deltas <- function(d) stats::cor(d$dS, d$dY)

# Per-study estimation-error (co)variances from the Hajek IF (★★), given fixed Q.
# V_S(Q_m) ≈ (1/n^2) Σ_i psi_S[i,m]^2, etc. Returns M-vectors + their means.
iw_error_cov <- function(data, Q, p_X, X_levels) {
  k_i <- match(data$X, X_levels); n <- nrow(data)
  Wmat <- Q[, k_i, drop = FALSE] / matrix(p_X[k_i], nrow(Q), n, byrow = TRUE)
  A <- data$A; S <- data$S; Y <- data$Y
  # normalize weights to mean 1 per study (row), per-arm average weights
  rowmean <- rowMeans(Wmat)
  Wn <- Wmat / rowmean
  ebar1 <- rowMeans(sweep(Wn, 2, A, `*`))
  ebar0 <- rowMeans(sweep(Wn, 2, 1 - A, `*`))
  M <- nrow(Q)
  VS <- VY <- CSY <- numeric(M)
  # arm means per study
  d <- iw_deltas(data, Q, p_X, X_levels)
  # recompute arm means (needed for centering)
  dA1 <- Wmat %*% A; dA0 <- Wmat %*% (1 - A)
  mS1 <- (Wmat %*% (S * A)) / dA1; mS0 <- (Wmat %*% (S * (1 - A))) / dA0
  mY1 <- (Wmat %*% (Y * A)) / dA1; mY0 <- (Wmat %*% (Y * (1 - A))) / dA0
  for (m in seq_len(M)) {
    wn <- Wn[m, ]
    psiS <- wn * (A * (S - mS1[m]) / ebar1[m] - (1 - A) * (S - mS0[m]) / ebar0[m])
    psiY <- wn * (A * (Y - mY1[m]) / ebar1[m] - (1 - A) * (Y - mY0[m]) / ebar0[m])
    VS[m] <- sum(psiS^2) / n^2
    VY[m] <- sum(psiY^2) / n^2
    CSY[m] <- sum(psiS * psiY) / n^2
  }
  list(VS = VS, VY = VY, CSY = CSY,
       VS_bar = mean(VS), VY_bar = mean(VY), CSY_bar = mean(CSY), dS = d$dS, dY = d$dY)
}

# --- Correction (2): reliability-guarded EIV ---------------------------------
corr_eiv_bounded <- function(ec, rel_floor = 0.1) {
  vS <- var(ec$dS) * (length(ec$dS) - 1) / length(ec$dS)
  vY <- var(ec$dY) * (length(ec$dY) - 1) / length(ec$dY)
  cSY <- mean(ec$dS * ec$dY) - mean(ec$dS) * mean(ec$dY)
  # reliability = signal / total; only correct by the estimated reliable fraction,
  # and never let corrected variance drop below rel_floor * plug-in variance.
  relS <- max(1 - ec$VS_bar / vS, rel_floor)
  relY <- max(1 - ec$VY_bar / vY, rel_floor)
  vS_c <- vS * relS; vY_c <- vY * relY
  cSY_c <- cSY - ec$CSY_bar
  r <- cSY_c / sqrt(vS_c * vY_c)
  max(min(r, 1), -1)
}

# --- Correction (3): grouped jackknife ---------------------------------------
corr_jackknife <- function(data, Q, p_X, X_levels, G = 20L) {
  n <- nrow(data)
  rho_full <- rho_from_deltas(iw_deltas(data, Q, p_X, X_levels))
  grp <- sample(rep(1:G, length.out = n))
  rho_mg <- sapply(1:G, function(g) rho_from_deltas(iw_deltas(data, Q, p_X, X_levels, idx = which(grp != g))))
  bias <- (G - 1) * (mean(rho_mg) - rho_full)
  max(min(rho_full - bias, 1), -1)
}

# --- Correction (4): SIMEX ---------------------------------------------------
# Add pseudo estimation-noise to (dS, dY) at inflation levels (1+lambda), average
# rho over B sims per level, fit rho(lambda) with a quadratic, extrapolate to
# lambda = -1 (zero measurement error). Per-study error cov from iw_error_cov.
corr_simex <- function(ec, lambdas = c(0.5, 1, 1.5, 2), B = 25L, seed = 7L) {
  set.seed(seed)
  M <- length(ec$dS)
  rho_lam <- sapply(lambdas, function(lam) {
    rr <- numeric(B)
    for (b in seq_len(B)) {
      # per-study 2D Gaussian noise with cov [[VS,CSY],[CSY,VY]] scaled by lam
      zS <- rnorm(M); zY <- rnorm(M)
      # Cholesky per study would be exact; use scalar approx via correlation rho_e
      sdS <- sqrt(pmax(ec$VS, 0)); sdY <- sqrt(pmax(ec$VY, 0))
      rho_e <- ec$CSY / pmax(sdS * sdY, 1e-12); rho_e <- pmax(pmin(rho_e, 1), -1)
      eS <- sqrt(lam) * sdS * zS
      eY <- sqrt(lam) * sdY * (rho_e * zS + sqrt(pmax(1 - rho_e^2, 0)) * zY)
      rr[b] <- stats::cor(ec$dS + eS, ec$dY + eY)
    }
    mean(rr)
  })
  # quadratic extrapolation to lambda = -1
  fit <- lm(rho_lam ~ lambdas + I(lambdas^2))
  r <- as.numeric(predict(fit, newdata = data.frame(lambdas = -1)))
  max(min(r, 1), -1)
}
