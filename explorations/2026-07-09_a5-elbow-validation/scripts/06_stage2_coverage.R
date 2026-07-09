# =============================================================================
# 06_stage2_coverage.R -- Stage 2 end-to-end Theta coverage (local, modest R).
# =============================================================================
# Composed debiased correlation estimator at continuous X, conditional on a
# discretize-to-cells geometry. One DGP ABOVE the (first-order) boundary
# (s=1.0, expect ~nominal coverage) and one NEAR it (s=0.35, expect honest
# degradation). Each rep: generate data, sample Sigma, estimate Theta (debiased),
# score coverage vs the true Theta under the SAME Sigma.
#
# Serial (grf + hit-and-run per rep, ~2.5s/rep). n=2000 only for the local check;
# n=8000 belongs on the cluster. Safe on a laptop at modest R.
# =============================================================================
root <- "explorations/2026-07-09_a5-elbow-validation"
suppressMessages({library(surrogateTransportability); library(grf)})
for (f in c("config/grid.R","R/dgp_smooth.R","R/pseudo_outcome.R","R/bilinear_estimator.R",
            "R/dgp_theta.R","R/theta_estimator.R","R/run_one_stage2.R")) source(file.path(root,f))

R_S2 <- as.integer(Sys.getenv("R_S2", "100"))
N    <- as.integer(Sys.getenv("N_S2", "2000"))
ut <- unit_table_stage2(R_S2)

cat(sprintf("Stage 2 coverage: R=%d, n=%d\n\n", R_S2, N))
rows <- list(); ri <- 0
for (dn in c("above", "near")) {
  sub <- ut[ut$design == dn & ut$n == N, ]
  sub <- sub[seq_len(min(R_S2, nrow(sub))), ]
  res <- do.call(rbind, lapply(seq_len(nrow(sub)), function(i) run_one_stage2(sub[i, ])))
  ri <- ri + 1
  rows[[ri]] <- data.frame(
    design = dn, s = sub$s_S[1], n = N, reps = nrow(res),
    mean_theta = mean(res$estimate), mean_truth = mean(res$truth),
    bias = mean(res$error), emp_sd = sd(res$estimate),
    mean_se = mean(res$std_error), coverage = mean(res$covered))
  cat(sprintf("  %-6s s=%.2f n=%d | theta=%.3f truth=%.3f bias=%+.4f empSD=%.3f meanSE=%.3f cov=%.2f\n",
      dn, sub$s_S[1], N, mean(res$estimate), mean(res$truth), mean(res$error),
      sd(res$estimate), mean(res$std_error), mean(res$covered)))
}
res_all <- do.call(rbind, rows)
saveRDS(res_all, file.path(root, "output/stage2_coverage_local.rds"))
cat("\nsaved output/stage2_coverage_local.rds\n")
