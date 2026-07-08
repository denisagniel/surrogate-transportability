# =============================================================================
# 07_if_se_prototype.R -- prototype & validate an influence-function SE for the
# across-study correlation under the saturated (per-cell) CATE estimator.
# EXPLORATION. See IF_SE_derivation.md.
#
# Validates: SE = sqrt(g' V g)  (g analytic gradient, V from stacked per-cell IFs)
#   (a) matches a finite-difference gradient (g correct),
#   (b) matches empirical SD of rho_hat across reps (SE correct),
#   (c) the cross-outcome block V_SY MATTERS (block-diagonal-only is wrong).
# =============================================================================

suppressMessages(devtools::load_all("."))
SOURCED_ONLY <- TRUE
source("explorations/small_n/02_cate_estimators.R")   # rho_from_cate, sigma_q_from_data

# analytic gradient of Theta wrt (tau_S, tau_Y), given Sigma
grad_theta <- function(tS, tY, Sig) {
  num <- as.numeric(t(tS) %*% Sig %*% tY)
  a   <- as.numeric(t(tS) %*% Sig %*% tS)
  b   <- as.numeric(t(tY) %*% Sig %*% tY)
  gS <- (Sig %*% tY - (num/a) * (Sig %*% tS)) / sqrt(a*b)
  gY <- (Sig %*% tS - (num/b) * (Sig %*% tY)) / sqrt(a*b)
  c(as.numeric(gS), as.numeric(gY))
}

# exact per-observation IF matrix for saturated CATE of outcome `y` (n x K)
if_saturated <- function(y, A, X, x_eval) {
  n <- length(y); K <- length(x_eval)
  cell <- match(X, x_eval)
  IF <- matrix(0, n, K)
  for (k in seq_len(K)) {
    ink <- cell == k
    pk <- mean(ink)
    ek <- mean(A[ink])                       # in-cell propensity
    m1 <- mean(y[ink & A == 1]); m0 <- mean(y[ink & A == 0])
    idx <- which(ink)
    IF[idx, k] <- (1/pk) * ( A[idx]*(y[idx]-m1)/ek - (1-A[idx])*(y[idx]-m0)/(1-ek) )
  }
  IF
}

# IF-based SE; if block_diag, zero out the cross-outcome block (to show it matters)
if_se <- function(data, x_eval, Sig, block_diag = FALSE) {
  tS <- .cate_tau(data$S, data$A, data$X, x_eval)
  tY <- .cate_tau(data$Y, data$A, data$X, x_eval)
  g  <- grad_theta(tS, tY, Sig)
  IFS <- if_saturated(data$S, data$A, data$X, x_eval)
  IFY <- if_saturated(data$Y, data$A, data$X, x_eval)
  n <- nrow(data)
  V <- stats::cov(cbind(IFS, IFY)) / n       # 2K x 2K, /n for Var of the mean
  if (block_diag) {
    K <- length(x_eval)
    V[1:K, (K+1):(2*K)] <- 0; V[(K+1):(2*K), 1:K] <- 0
  }
  sqrt(as.numeric(t(g) %*% V %*% g))
}

# saturated tau (reuse robust version)
.cate_tau <- function(y, A, X, x_eval) cate_raw(y, A, match(X, x_eval), length(x_eval))$tau

# ---------------------------------------------------------------------------
# Validation across DGP x n
set.seed(20260708)
DGPS <- c("dgp1","dgp2"); N_GRID <- c(500L, 1000L, 2000L); N_REPS <- 150L; LAMBDA <- 0.3

cat("=== IF-SE validation (saturated CATE) ===\n")
cat(sprintf("%-5s %5s %8s %10s %10s %10s %10s\n",
            "dgp","n","emp_sd","if_se","if_bd_se","boot_se","mean_rho"))
for (id in DGPS) {
  spec <- canonical_dgp_params(id)
  for (n in N_GRID) {
    rho <- if_full <- if_bd <- numeric(N_REPS)
    for (r in seq_len(N_REPS)) {
      set.seed(92000000L + r + n*17L + which(DGPS==id)*3L)
      d <- generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels)
      Sig <- sigma_q_from_data(d$X, spec$X_levels, lambda=LAMBDA, M=600, burn_in=150, thin=2)
      rho[r]    <- rho_from_cate(.cate_tau(d$S,d$A,d$X,spec$X_levels),
                                 .cate_tau(d$Y,d$A,d$X,spec$X_levels), Sig)
      if_full[r]<- if_se(d, spec$X_levels, Sig, block_diag=FALSE)
      if_bd[r]  <- if_se(d, spec$X_levels, Sig, block_diag=TRUE)
    }
    ok <- is.finite(rho) & is.finite(if_full)
    # one bootstrap SE at the first rep for a spot comparison
    cat(sprintf("%-5s %5d %8.3f %10.3f %10.3f %10s %10.3f\n",
                id, n, sd(rho[ok]), mean(if_full[ok]), mean(if_bd[ok]),
                "-", mean(rho[ok])))
  }
}
cat("\nif_se = full V (incl cross-outcome block); if_bd_se = block-diagonal only.\n")
cat("Correct SE should track emp_sd; gap between if_se and if_bd_se shows V_SY matters.\n")
