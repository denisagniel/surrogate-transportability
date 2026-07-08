# =============================================================================
# 01_characterize_small_n.R -- how does the TV-ball correlation estimator behave
# at practical (small) sample sizes? EXPLORATION (fast-track, ~60/100).
#
# Motivation: at n=10,000 the estimator is well-calibrated, but spot checks show
# rho_hat attenuated toward 0 at small n (0.61 vs true 0.69 at n=3000; 0.58 at
# n=800) with mild under-coverage. This is the errors-in-variables signature:
# each study's Delta_hat carries estimation noise that inflates the across-study
# variance (the correlation denominator), biasing rho toward 0.
#
# This harness quantifies bias / empirical SD / mean IF-SE / coverage across an
# n-grid for the two discriminating DGPs (dgp1, dgp2), and SAVES the raw per-study
# (Delta_S, Delta_Y) pairs per rep so the disattenuation remedy can be prototyped
# offline (02_*) without re-running the MCMC.
#
# Run time: long -- launched in the background. Fixed M (not adaptive) for speed.
# =============================================================================

suppressMessages(devtools::load_all("."))

set.seed(20260708)

N_GRID   <- c(250L, 500L, 1000L, 2000L)
DGPS     <- c("dgp1", "dgp2")           # discriminating cases (dgp4/5 are rho~1)
N_REPS   <- 60L
M_FIXED  <- 400L                        # fixed M for speed (no adaptive loop)
LAMBDA   <- 0.3

run_one <- function(dgp_id, n, seed) {
  set.seed(seed)
  spec <- canonical_dgp_params(dgp_id)
  d <- generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels)
  r <- tv_ball_correlation_IF_adaptive(
    d, lambda = LAMBDA, method = "importance_weighting",
    M_start = M_FIXED, M_increment = 1L, M_max = M_FIXED,   # forces fixed M
    tolerance = 1, n_stable = 2, burn_in = 300, thin = 3,
    alpha = 0.05, verbose = FALSE
  )
  list(
    dgp = dgp_id, n = n, seed = seed,
    rho_hat = r$rho_hat, se = r$se,
    ci_lower = r$ci_lower, ci_upper = r$ci_upper,
    truth = spec$rho_true,
    covered = as.integer(spec$rho_true >= r$ci_lower & spec$rho_true <= r$ci_upper),
    # raw per-study effect pairs (for offline disattenuation prototyping)
    Delta_S = r$Delta_S, Delta_Y = r$Delta_Y
  )
}

results <- list()
k <- 0
t0 <- Sys.time()
for (dgp_id in DGPS) {
  for (n in N_GRID) {
    for (rep in seq_len(N_REPS)) {
      k <- k + 1
      seed <- 80000000L + rep + n * 7L + which(DGPS == dgp_id) * 1000003L
      results[[k]] <- tryCatch(run_one(dgp_id, n, seed),
                               error = function(e) list(dgp = dgp_id, n = n,
                                                        seed = seed, error = conditionMessage(e)))
    }
    el <- as.numeric(Sys.time() - t0, units = "mins")
    cat(sprintf("[%s n=%d] done (%d runs, %.1f min elapsed)\n", dgp_id, n, k, el))
  }
}

saveRDS(results, "explorations/small_n/results_raw.rds")

# --- Summary table (bias / emp SD / mean SE / coverage) ----------------------
ok <- Filter(function(x) is.null(x$error), results)
summ <- do.call(rbind, lapply(split(ok, sapply(ok, function(x) paste(x$dgp, x$n))), function(grp) {
  rho <- sapply(grp, function(x) x$rho_hat)
  se  <- sapply(grp, function(x) x$se)
  cov <- sapply(grp, function(x) x$covered)
  truth <- grp[[1]]$truth
  data.frame(
    dgp = grp[[1]]$dgp, n = grp[[1]]$n, reps = length(grp),
    truth = round(truth, 3),
    mean_rho = round(mean(rho, na.rm = TRUE), 4),
    bias = round(mean(rho, na.rm = TRUE) - truth, 4),
    emp_sd = round(sd(rho, na.rm = TRUE), 4),
    mean_se = round(mean(se, na.rm = TRUE), 4),
    se_sd_ratio = round(mean(se, na.rm = TRUE) / sd(rho, na.rm = TRUE), 3),
    coverage = round(mean(cov, na.rm = TRUE), 3),
    row.names = NULL
  )
}))
summ <- summ[order(summ$dgp, summ$n), ]
saveRDS(summ, "explorations/small_n/summary.rds")
cat("\n=== SMALL-n CHARACTERIZATION ===\n")
print(summ, row.names = FALSE)
cat(sprintf("\nTotal runtime: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))
