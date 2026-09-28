# Validate the Monte Carlo error formula underlying the adaptive-M stopping rule.
#
# The stopping rule in tv_ball_correlation_IF_adaptive() declares convergence when
#   se_mc = (1 - rho_hat^2) / sqrt(M) < mc_tolerance.
# That plug-in formula is the sampling sd of a correlation computed from M
# INDEPENDENT draws. Our draws come from a thinned hit-and-run chain, so residual
# MCMC autocorrelation would inflate the true sd above the plug-in value (the
# effective sample size is below M). This script measures the inflation directly.
#
# Design: fix ONE dataset; run the estimator 50 times at a FIXED M = 1500,
# varying only the sampler's random seed; compare the empirical sd of the 50
# rho_hat point estimates to the plug-in se_mc.
#
# Run time: ~2-4 minutes (50 x M=1500 at n=2000). Sequential by design — the
# whole point is to vary only the RNG stream.
#
# MEASURED 2026-09-28 (dgp1, n=2000, M=1500, 50 reps):
#   empirical sd  = 0.01797
#   plug-in se_mc = 0.01153 (at mean rho_hat = 0.744) -> ratio 1.559
#   plug-in se_mc = 0.01350 (at rho_true  = 0.691)    -> ratio 1.331
# The ratio straddles the 1.5 flag, so the plug-in formula is mildly OPTIMISTIC:
# residual hit-and-run autocorrelation leaves ESS ~ M/1.8-2.4. RECOMMENDATION:
# consider tightening mc_tolerance from 0.02 to 0.01. NOT changed in the function
# default — flagged for an explicit decision.

library(devtools)

set.seed(20260928)

suppressMessages(devtools::load_all(".", quiet = TRUE))

# --- Configuration -----------------------------------------------------------
dgp_id  <- "dgp1"   # moderate rho (~0.69): the regime the paper actually cares about
n       <- 2000
M_fixed <- 1500
n_reps  <- 50
burn_in <- 500
thin    <- 5

spec <- canonical_dgp_params(dgp_id)

# One fixed dataset: any variability across reps is sampler-only.
data_fixed <- generate_dgp_data(n, spec$params, spec$p_X, spec$X_levels)

# M_start = M_increment = M_max = M_fixed pins M: the loop executes exactly once
# and exits on M_current == M_max regardless of the convergence verdict.
run_once <- function(seed) {
  set.seed(seed)
  fit <- tv_ball_correlation_IF_adaptive(
    data_fixed,
    lambda       = spec$lambda,
    M_start      = M_fixed,
    M_increment  = M_fixed,
    M_max        = M_fixed,
    mc_tolerance = 0.02,
    burn_in      = burn_in,
    thin         = thin,
    method       = "importance_weighting",
    verbose      = FALSE
  )
  c(rho_hat = fit$rho_hat, se_mc = fit$se_mc, se_if = fit$se)
}

message(sprintf("Running %d reps at fixed M = %d (n = %d, %s)...",
                n_reps, M_fixed, n, dgp_id))

res <- t(vapply(seq_len(n_reps), function(r) run_once(20260928L + r),
                numeric(3)))
res <- res[is.finite(res[, "rho_hat"]), , drop = FALSE]

# --- Compare empirical sd to the plug-in formula -----------------------------
rho_bar  <- mean(res[, "rho_hat"])
emp_sd   <- stats::sd(res[, "rho_hat"])

# Plug-in at the mean rho_hat, and at the DGP's exact across-study truth.
plugin_at_mean <- (1 - rho_bar^2) / sqrt(M_fixed)
plugin_at_true <- (1 - spec$rho_true^2) / sqrt(M_fixed)

ratio_mean <- emp_sd / plugin_at_mean
ratio_true <- emp_sd / plugin_at_true

cat("\n=== MC error formula validation ===\n")
cat(sprintf("DGP           : %s (rho_true = %.6f)\n", dgp_id, spec$rho_true))
cat(sprintf("n / M / reps  : %d / %d / %d\n", n, M_fixed, nrow(res)))
cat(sprintf("mean rho_hat  : %.5f\n", rho_bar))
cat(sprintf("empirical sd  : %.5f  (across %d sampler seeds, dataset fixed)\n",
            emp_sd, nrow(res)))
cat(sprintf("plug-in se_mc : %.5f  (at mean rho_hat)\n", plugin_at_mean))
cat(sprintf("plug-in se_mc : %.5f  (at rho_true)\n", plugin_at_true))
cat(sprintf("RATIO emp/plug: %.3f  (at mean rho_hat)\n", ratio_mean))
cat(sprintf("RATIO emp/plug: %.3f  (at rho_true)\n", ratio_true))
cat(sprintf("mean IF SE    : %.5f  (se_mc / se_if = %.3f)\n",
            mean(res[, "se_if"]), plugin_at_mean / mean(res[, "se_if"])))

ratio_max <- max(ratio_mean, ratio_true)
if (ratio_max > 1.5) {
  cat("\n*** WARNING: empirical sd exceeds the plug-in formula by more than 50%.\n")
  cat("*** Residual MCMC autocorrelation makes se_mc OPTIMISTIC: the effective\n")
  cat(sprintf("*** sample size is roughly M / %.1f, not M.\n", ratio_max^2))
  cat("*** RECOMMENDATION: tighten mc_tolerance from 0.02 to 0.01 (the default in\n")
  cat("*** tv_ball_correlation_IF_adaptive() was deliberately NOT changed here --\n")
  cat("*** report this ratio and decide explicitly).\n")
} else {
  cat("\nOK: empirical sd is within 1.5x of the plug-in formula.\n")
  cat("The (1 - rho^2)/sqrt(M) stopping rule is adequately calibrated at\n")
  cat("mc_tolerance = 0.02; thinning is absorbing the chain autocorrelation.\n")
}

out_dir <- fs::path("validation", "results")
fs::dir_create(out_dir)
readr::write_rds(
  list(
    dgp = dgp_id, n = n, M = M_fixed, reps = nrow(res),
    rho_hat = res[, "rho_hat"], emp_sd = emp_sd,
    plugin_at_mean = plugin_at_mean, plugin_at_true = plugin_at_true,
    ratio_mean = ratio_mean, ratio_true = ratio_true
  ),
  fs::path(out_dir, "mc_error_formula_validation.rds")
)
cat(sprintf("\nSaved: %s\n", fs::path(out_dir, "mc_error_formula_validation.rds")))
