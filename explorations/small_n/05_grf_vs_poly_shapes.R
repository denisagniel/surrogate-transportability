# =============================================================================
# 05_grf_vs_poly_shapes.R -- does an off-the-shelf data-adaptive CATE learner
# (grf) generalize across CATE shapes where hand-tuned poly2 misfires?
# EXPLORATION (fast-track). This is the key generalizability test.
#
# For each shape-varied DGP (threshold, sinusoid, monotone-nl) and sample size,
# compare across-study rho_hat under three CATE estimators:
#   raw   : per-cell diff-in-means on discretized X (nonparametric, high variance)
#   poly2 : degree-2 polynomial in X (WRONG basis for these shapes -> should misfire)
#   grf   : causal_forest per outcome, cross-fit, data-adaptive (should generalize)
# against the analytic truth. Report bias / RMSE / collapse-rate.
#
# Expectation: poly2 wins on the canonical (quadratic) DGP but LOSES here; grf is
# competitive across ALL shapes -> supports "use an off-the-shelf CATE learner"
# as the generalizable recommendation.
# =============================================================================

suppressMessages(devtools::load_all("."))
SOURCED_ONLY <- TRUE
source("explorations/small_n/02_cate_estimators.R")   # rho_from_cate, sigma_q_from_data, cate_poly
source("explorations/small_n/04_shape_varied_dgps.R")

set.seed(20260708)

N_GRID <- c(500L, 1000L)
N_REPS <- 120L
N_CELLS <- 10L
LAMBDA <- 0.3

run_cell <- function(dgp_name, n, rep) {
  dgp <- SHAPE_DGPS[[dgp_name]]
  set.seed(91000000L + rep + n * 13L + utf8ToInt(substr(dgp_name,1,1)))
  d <- gen_shape_data(n, dgp)
  disc <- discretize_X(d$X, N_CELLS)
  cell <- disc$cell; centers <- disc$centers; K <- length(centers)
  # Sigma_q on the empirical cell distribution
  P0 <- as.numeric(table(factor(cell, levels = seq_len(K)))) / n
  Q <- sample_tv_ball(P0, lambda = LAMBDA, M = 600, burn_in = 150, thin = 2, verbose = FALSE)
  Sig <- stats::cov(Q)
  # truth under this Sigma (analytic cell CATEs at the SAME centers)
  tru <- shape_true_cate(dgp, centers)
  truth <- rho_from_cate(tru$tS, tru$tY, Sig)
  # raw
  rawS <- cate_raw(d$S, d$A, cell, K); rawY <- cate_raw(d$Y, d$A, cell, K)
  rho_raw <- rho_from_cate(rawS$tau, rawY$tau, Sig)
  # poly2 (wrong basis for these shapes)
  p2S <- cate_poly(d$S, d$A, d$X, centers, 2); p2Y <- cate_poly(d$Y, d$A, d$X, centers, 2)
  rho_poly <- rho_from_cate(p2S$tau, p2Y$tau, Sig)
  # grf (data-adaptive, per outcome)
  gS <- cate_grf(d$S, d$A, d$X, centers); gY <- cate_grf(d$Y, d$A, d$X, centers)
  rho_grf <- rho_from_cate(gS$tau, gY$tau, Sig)
  c(truth = truth, raw = rho_raw, poly2 = rho_poly, grf = rho_grf)
}

rows <- list(); r <- 0; t0 <- Sys.time()
for (dgp_name in names(SHAPE_DGPS)) {
  for (n in N_GRID) {
    M <- t(vapply(seq_len(N_REPS), function(rep) run_cell(dgp_name, n, rep),
                  numeric(4)))
    truth <- mean(M[, "truth"], na.rm = TRUE)
    for (est in c("raw", "poly2", "grf")) {
      v <- M[, est]; v <- v[is.finite(v)]
      r <- r + 1
      rows[[r]] <- data.frame(
        dgp = dgp_name, n = n, estimator = est, reps = length(v),
        truth = round(truth, 3), mean = round(mean(v), 3),
        bias = round(mean(v) - truth, 3), sd = round(sd(v), 3),
        rmse = round(sqrt(mean((v - truth)^2)), 3),
        collapse_rate = round(mean(abs(v) > 0.999), 3), row.names = NULL)
    }
    cat(sprintf("[%s n=%d] %.1f min\n", dgp_name, n, as.numeric(Sys.time()-t0, units="mins")))
  }
}
out <- do.call(rbind, rows)
saveRDS(out, "explorations/small_n/grf_vs_poly_summary.rds")
cat("\n=== grf vs poly2 vs raw across CATE shapes (", N_REPS, "reps) ===\n")
print(out, row.names = FALSE)
cat(sprintf("\nTotal: %.1f min\n", as.numeric(Sys.time()-t0, units="mins")))
