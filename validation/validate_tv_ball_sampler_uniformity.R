# Validate corrected hit-and-run TV-ball sampler against a rejection oracle.
source("R/tv_ball_sampling.R")

set.seed(20260708)

# --- Oracle: Dirichlet(1) proposal + exact TV acceptance = uniform on TV ball ---
rdirichlet1 <- function(K) { g <- rexp(K); g / sum(g) }
rejection_tv_ball <- function(P0, lambda, M) {
  K <- length(P0); out <- matrix(NA_real_, M, K); k <- 0; tries <- 0
  while (k < M && tries < M * 200000) {
    q <- rdirichlet1(K); tries <- tries + 1
    if (0.5 * sum(abs(q - P0)) <= lambda) { k <- k + 1; out[k, ] <- q }
  }
  out[seq_len(k), , drop = FALSE]
}

# Test on a small-K non-uniform P0 (so acceptance is feasible)
K <- 5
P0 <- c(0.05, 0.25, 0.40, 0.25, 0.05)
lambda <- 0.3

# Oracle sample
Q_ref <- rejection_tv_ball(P0, lambda, M = 4000)
cat(sprintf("Oracle: %d accepted samples\n", nrow(Q_ref)))

# Hit-and-run sample (corrected)
Q_hr <- sample_tv_ball(P0, lambda, M = 4000, burn_in = 2000, thin = 5, verbose = FALSE)

# --- Checks ---
# 1. All samples valid (nonneg, sum 1, within ball)
tv_hr <- apply(Q_hr, 1, function(q) 0.5 * sum(abs(q - P0)))
cat(sprintf("HR: all sum-to-1: %s | all nonneg: %s | all TV<=lambda: %s | max TV: %.4f\n",
            all(abs(rowSums(Q_hr) - 1) < 1e-8), all(Q_hr >= -1e-10),
            all(tv_hr <= lambda + 1e-8), max(tv_hr)))

# 2. Coordinate-wise means should match oracle (uniform on ball => same marginal means)
cat("\nPer-coordinate MEAN (oracle vs hit-and-run):\n")
m_ref <- colMeans(Q_ref); m_hr <- colMeans(Q_hr)
print(round(rbind(oracle = m_ref, hitrun = m_hr, diff = m_hr - m_ref), 4))

# 3. Per-coordinate SD should match too
cat("\nPer-coordinate SD (oracle vs hit-and-run):\n")
s_ref <- apply(Q_ref, 2, sd); s_hr <- apply(Q_hr, 2, sd)
print(round(rbind(oracle = s_ref, hitrun = s_hr, diff = s_hr - s_ref), 4))

# 4. TV-distance distribution should match (KS test): uniform on ball has a
#    characteristic radial density; a biased sampler (e.g. staying near P0) fails this.
cat("\nTV-distance distribution (oracle vs hit-and-run):\n")
cat(sprintf("  mean TV: oracle=%.4f  hitrun=%.4f\n", mean(apply(Q_ref,1,function(q)0.5*sum(abs(q-P0)))), mean(tv_hr)))
ks <- suppressWarnings(ks.test(tv_hr, apply(Q_ref, 1, function(q) 0.5*sum(abs(q-P0)))))
cat(sprintf("  KS test D=%.4f, p=%.4f  (large p => distributions match)\n", ks$statistic, ks$p.value))
