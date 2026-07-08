# =============================================================================
# 03_compare_estimators.R -- multi-rep bias/variance of rho_hat across CATE
# estimators and sample sizes. EXPLORATION (fast-track).
#
# Uses the closed-form rho = f(cell CATEs, Sigma_q) from 02_cate_estimators.R:
# per rep we sample Sigma_q ONCE and evaluate all CATE variants, so this is fast
# and isolates the CATE-estimation effect. Reports, per (dgp, n, estimator):
# mean rho_hat, bias vs analytic-under-Sigma truth, SD, RMSE, and the fraction of
# reps with |rho_hat| > 0.999 (the "manufacture-correlation" / collapse rate).
# =============================================================================

SOURCED_ONLY <- TRUE
source("explorations/small_n/02_cate_estimators.R")

set.seed(20260708)

N_GRID  <- c(250L, 500L, 1000L, 2000L)
DGPS    <- c("dgp1", "dgp2")
N_REPS  <- 200L
LAMBDA  <- 0.3
ESTIMATORS <- c("raw", "shrink", "poly2", "linearX", "disatten")

rows <- list(); r <- 0
t0 <- Sys.time()
for (id in DGPS) {
  spec <- canonical_dgp_params(id)
  for (n in N_GRID) {
    mat <- matrix(NA_real_, N_REPS, length(ESTIMATORS),
                  dimnames = list(NULL, ESTIMATORS))
    truth_vec <- numeric(N_REPS)
    for (rep in seq_len(N_REPS)) {
      set.seed(90000000L + rep + n * 11L + which(DGPS == id) * 7L)
      d   <- generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels)
      Sig <- sigma_q_from_data(d$X, spec$X_levels, lambda = LAMBDA,
                               M = 800, burn_in = 200, thin = 2)  # lighter M (speed)
      mat[rep, ] <- estimate_all(d, spec$X_levels, Sig)
      truth_vec[rep] <- true_rho_analytic(spec, Sig)  # truth under this rep's Sigma
    }
    truth <- mean(truth_vec)
    for (est in ESTIMATORS) {
      v <- mat[, est]; v <- v[is.finite(v)]
      r <- r + 1
      rows[[r]] <- data.frame(
        dgp = id, n = n, estimator = est, reps = length(v),
        truth = round(truth, 3),
        mean = round(mean(v), 3),
        bias = round(mean(v) - truth, 3),
        sd = round(sd(v), 3),
        rmse = round(sqrt(mean((v - truth)^2)), 3),
        collapse_rate = round(mean(abs(v) > 0.999), 3),  # fraction pinned at +/-1
        row.names = NULL
      )
    }
    cat(sprintf("[%s n=%d] %.1f min\n", id, n, as.numeric(Sys.time()-t0, units="mins")))
  }
}

out <- do.call(rbind, rows)
saveRDS(out, "explorations/small_n/compare_summary.rds")
cat("\n=== rho_hat by CATE estimator x n (200 reps) ===\n")
print(out, row.names = FALSE)

# Rank by RMSE within each (dgp,n), excluding the linearX guardrail
cat("\n=== best estimator by RMSE (excluding linearX guardrail) ===\n")
sub <- out[out$estimator != "linearX", ]
best <- do.call(rbind, lapply(split(sub, list(sub$dgp, sub$n)), function(g)
  g[which.min(g$rmse), c("dgp","n","estimator","bias","rmse","collapse_rate")]))
print(best[order(best$dgp, best$n), ], row.names = FALSE)
cat(sprintf("\nTotal: %.1f min\n", as.numeric(Sys.time()-t0, units="mins")))
