# =============================================================================
# 03_elbow_signature.R -- Stage 1 elbow demonstration (local, R=200).
# =============================================================================
# For each design x n, run R reps of the debiased + plug-in estimator on the SS
# diagonal functional (where debiasing bites and the elbow is cleanest) and the
# SY cross functional. Summarize:
#   * bias, empirical SD, mean SE, RMSE, coverage (debiased);
#   * elbow signature: slope of log(RMSE) ~ log(n) -- ~ -1/2 above the first-order
#     boundary (sum > d), shallower in the gap/below;
#   * coverage trajectory (nominal above vs collapse in gap/below);
#   * plug-in coverage (miscovers -> debiasing load-bearing).
# Writes output/stage1_results.rds and prints the summary table.
# =============================================================================
suppressMessages({library(parallel)})
root <- "explorations/2026-07-09_a5-elbow-validation"
source(file.path(root, "config/grid.R"))
source(file.path(root, "R/dgp_smooth.R"))
source(file.path(root, "R/pseudo_outcome.R"))
source(file.path(root, "R/bilinear_estimator.R"))
source(file.path(root, "R/run_one_stage1.R"))

R_LOCAL <- as.integer(Sys.getenv("R_LOCAL", "200"))
PAIRS   <- c("SS", "SY")
NCORES  <- max(1L, detectCores() - 1L)

# Build the focused unit table: all designs x n x pairs, R reps, debiased+plugin
# (run_one emits both estimators, so we drop the estimator dim from the grid).
grid <- expand.grid(design = STAGE1_DESIGN$design, n = STAGE1_N, pair = PAIRS,
                    stringsAsFactors = FALSE)
grid <- merge(grid, STAGE1_DESIGN, by = "design", sort = FALSE)
grid$config_id <- seq_len(nrow(grid))
ut <- unit_table(grid, R_LOCAL, seed_offset = 0L)

cat(sprintf("Stage 1 elbow run: %d configs x %d reps = %d units on %d cores\n",
            nrow(grid), R_LOCAL, nrow(ut), NCORES))
t0 <- Sys.time()
res_list <- mclapply(seq_len(nrow(ut)), function(i) run_one_stage1(ut[i, ]),
                     mc.cores = NCORES)
res <- do.call(rbind, res_list)
cat(sprintf("done in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

saveRDS(res, file.path(root, "output/stage1_results.rds"))

# ---- summary ----------------------------------------------------------------
library(dplyr)
summ <- res |>
  group_by(design, d, s_S, s_Y, regime, pair, estimator, n) |>
  summarise(reps = n(), bias = mean(error), emp_sd = sd(estimate),
            mean_se = mean(std_error), rmse = sqrt(mean(error^2)),
            coverage = mean(covered), .groups = "drop")

# elbow signature: slope of log(rmse) ~ log(n) per (design,pair,estimator)
slopes <- summ |>
  group_by(design, d, s_S, s_Y, regime, pair, estimator) |>
  summarise(sum_s = unique(s_S + s_Y), d = unique(d),
            slope_rmse = coef(lm(log(rmse) ~ log(n)))[2],
            cov_hi_n = coverage[which.max(n)], .groups = "drop") |>
  mutate(above_firstorder = sum_s > d, hoif_estimable = sum_s > d / 2)

cat("\n=== elbow signature (SS diagonal, debiased) ===\n")
print(as.data.frame(
  slopes |> filter(pair == "SS", estimator == "debiased") |>
    select(design, d, sum_s, regime, slope_rmse, cov_hi_n, above_firstorder)),
  digits = 3, row.names = FALSE)

cat("\n=== coverage by n (SS, debiased) ===\n")
print(as.data.frame(
  summ |> filter(pair == "SS", estimator == "debiased") |>
    select(design, regime, n, bias, rmse, coverage) |> arrange(design, n)),
  digits = 3, row.names = FALSE)

cat("\n=== plug-in vs debiased coverage at max n (SS) ===\n")
print(as.data.frame(
  summ |> filter(pair == "SS", n == max(STAGE1_N)) |>
    select(design, regime, estimator, coverage, bias)),
  digits = 3, row.names = FALSE)

saveRDS(list(summ = summ, slopes = slopes),
        file.path(root, "output/stage1_summary.rds"))
cat("\nsaved output/stage1_results.rds + output/stage1_summary.rds\n")
