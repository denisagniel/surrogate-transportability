# =============================================================================
# dgp_smooth.R -- Stage 1 continuous-X DGP with a Sobolev smoothness knob.
# =============================================================================
# X ~ Uniform[0,1]^d. Each CATE is a truncated cosine (Fourier) series whose
# coefficient decay sets its Sobolev smoothness exactly:
#
#   d = 1:  tau_a(x) = c_a * sum_{j=1..J} b_{a,j} phi_j(x),
#           phi_j(x) = sqrt(2) cos(pi j x)   (orthonormal on [0,1] wrt Lebesgue),
#           b_{a,j} = j^{-(s_a + 1/2)}.
#   The Sobolev-s norm sum_j j^{2s} b_j^2 = sum_j j^{2s - 2s_a - 1} is finite iff
#   s < s_a, so tau_a has smoothness s_a (the standard minimax construction).
#
#   d = 2:  tensor cosine basis phi_{jk}(x) = phi_j(x1) phi_k(x2), indexed by
#           frequency magnitude m = sqrt(j^2 + k^2); coefficient decay
#           m^{-(s_a + d/2)} gives isotropic Sobolev smoothness s_a.
#
# RCT: A ~ Bernoulli(1/2), known e = 1/2. Outcome means
#   mu_{a,0}(x) = g_a(x)  (a SMOOTH baseline; never binds the elbow),
#   mu_{a,1}(x) = g_a(x) + tau_a(x).
# Errors (eps_S, eps_Y) ~ N(0, Sigma_eps) with a nonzero cross-correlation so the
# IF cross-term is exercised.
#
# Closed-form truth (orthonormality wrt P0 = Uniform):
#   psi_ab = E[tau_a tau_b] = c_a c_b sum_j b_{a,j} b_{b,j}   (d = 1)
#          = c_a c_b sum_{jk} (decay^a_{jk})(decay^b_{jk})     (d = 2)
# computed to machine precision by summing the same truncation J.
#
# IMPORTANT: the CATE is a FINITE series (truncation J), so its psi is EXACTLY
# the J-truncated sum -- there is no infinite series to approximate, hence no
# truncation error, PROVIDED psi_truth_config() uses the SAME J as
# generate_stage1() (they share the default: 200 for d=1, 60 for d=2). The
# estimator's sieve truncation (J_n, data-driven) is deliberately DISTINCT from
# this DGP J, so the estimator never "knows" the true series length.
# =============================================================================

# --- basis coefficients (decay) for one CATE ---------------------------------
# Returns a named list: freqs (matrix of integer frequencies, d columns) and
# decay (numeric vector of coefficients b_j), for a given smoothness s, dim d,
# truncation J (per-axis max frequency).
cate_basis <- function(s, d, J = 200L) {
  if (d == 1L) {
    j <- seq_len(J)
    list(freqs = matrix(j, ncol = 1L), decay = j^(-(s + 0.5)))
  } else if (d == 2L) {
    grid <- expand.grid(j = seq_len(J), k = seq_len(J))
    m <- sqrt(grid$j^2 + grid$k^2)
    list(freqs = as.matrix(grid), decay = m^(-(s + d / 2)))
  } else {
    stop("dgp_smooth supports d in {1,2}")
  }
}

# --- evaluate a CATE function at a matrix of X (n x d) ------------------------
# X is n x d with entries in [0,1]. Returns length-n vector tau_a(X).
eval_cate <- function(X, basis, scale = 1) {
  X <- as.matrix(X)
  d <- ncol(X)
  freqs <- basis$freqs
  decay <- basis$decay
  # phi for each frequency component: product over axes of sqrt(2) cos(pi f x).
  # Build the n x nfreq design matrix Phi, then tau = scale * Phi %*% decay.
  n <- nrow(X)
  nf <- nrow(freqs)
  Phi <- matrix(1, n, nf)
  for (l in seq_len(d)) {
    # outer: cos(pi * f_l * x_l) for each obs x freq
    Phi <- Phi * (sqrt(2) * cos(pi * outer(X[, l], freqs[, l])))
  }
  as.numeric(scale * (Phi %*% decay))
}

# --- closed-form psi_ab = E[tau_a tau_b] -------------------------------------
# By orthonormality, E[phi_f phi_f'] = 1{f = f'}, so psi_ab = c_a c_b sum decay_a decay_b.
psi_true <- function(basis_a, basis_b, scale_a = 1, scale_b = 1) {
  stopifnot(nrow(basis_a$freqs) == nrow(basis_b$freqs))
  scale_a * scale_b * sum(basis_a$decay * basis_b$decay)
}

# --- generate one Stage 1 dataset --------------------------------------------
# config: list/row with d, s_S, s_Y (+ optional c_S, c_Y, rho_eps, sigma_eps,
#   baseline_s, J). Returns a data.frame with X1..Xd, A, S, Y, and attaches the
#   true CATE values (tau_S, tau_Y) and the psi truths as attributes for checks.
generate_stage1 <- function(n, config,
                            c_S = 1, c_Y = 1,
                            rho_eps = 0.3, sigma_eps = 0.5,
                            baseline_s = 3, J = NULL,
                            y_decorr = 0) {
  d   <- as.integer(config$d)
  s_S <- config$s_S
  s_Y <- config$s_Y
  if (is.null(J)) J <- if (d == 1L) 200L else 60L

  # covariates
  X <- matrix(runif(n * d), n, d)
  colnames(X) <- paste0("X", seq_len(d))

  # bases
  bS <- cate_basis(s_S, d, J)
  bY <- cate_basis(s_Y, d, J)
  # y_decorr in [0,1] mixes an alternating sign pattern into the Y coefficients:
  # decay_Y := decay_Y * (1 - 2*y_decorr*(j odd)). This makes tau_Y a genuinely
  # DIFFERENT function of x from tau_S (interior across-study correlation Theta)
  # while preserving |coefficients| = smoothness for y_decorr in {0,1}. Used only
  # in Stage 2 (Theta coverage); Stage 1 keeps y_decorr=0 (tau_S, tau_Y same shape).
  if (y_decorr != 0) {
    j1 <- bY$freqs[, 1]
    bY$decay <- bY$decay * (1 - 2 * y_decorr * (j1 %% 2))
  }
  # a smooth baseline g_a: same basis family but very smooth (baseline_s), so it
  # never binds the elbow. Independent frequencies not needed -- g cancels out of
  # psi_ab only if orthogonal; we keep g SMOOTH and separate from tau by using a
  # distinct scale and a large baseline_s (its roughness is irrelevant; only the
  # CATE roughness drives the elbow).
  bG <- cate_basis(baseline_s, d, J)

  tau_S <- eval_cate(X, bS, c_S)
  tau_Y <- eval_cate(X, bY, c_Y)
  g_S   <- eval_cate(X, bG, 0.5)
  g_Y   <- eval_cate(X, bG, 0.5)

  A <- rbinom(n, 1, 0.5)

  # correlated Gaussian errors
  Sig <- matrix(c(sigma_eps^2, rho_eps * sigma_eps^2,
                  rho_eps * sigma_eps^2, sigma_eps^2), 2, 2)
  L <- chol(Sig)
  E <- matrix(rnorm(n * 2), n, 2) %*% L

  S <- g_S + A * tau_S + E[, 1]
  Y <- g_Y + A * tau_Y + E[, 2]

  dat <- data.frame(X, A = A, S = S, Y = Y)
  attr(dat, "tau_S") <- tau_S
  attr(dat, "tau_Y") <- tau_Y
  attr(dat, "psi_SY") <- psi_true(bS, bY, c_S, c_Y)
  attr(dat, "psi_SS") <- psi_true(bS, bS, c_S, c_S)
  attr(dat, "psi_YY") <- psi_true(bY, bY, c_Y, c_Y)
  dat
}

# --- truth lookup for a config (no data needed) ------------------------------
psi_truth_config <- function(config, c_S = 1, c_Y = 1, J = NULL) {
  d <- as.integer(config$d)
  if (is.null(J)) J <- if (d == 1L) 200L else 60L
  bS <- cate_basis(config$s_S, d, J)
  bY <- cate_basis(config$s_Y, d, J)
  c(SY = psi_true(bS, bY, c_S, c_Y),
    SS = psi_true(bS, bS, c_S, c_S),
    YY = psi_true(bY, bY, c_Y, c_Y))
}
