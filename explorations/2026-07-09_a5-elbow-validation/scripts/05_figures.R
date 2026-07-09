# =============================================================================
# 05_figures.R -- elbow-signature figures from output/stage1_summary.rds.
#   elbow_scaling.pdf     : log(RMSE) vs log(n), faceted by pair, colored by
#                           regime, with a -1/2 reference slope.
#   coverage_vs_n.pdf     : debiased coverage vs n by design, 0.95 band.
# Uses randplot house style.
# =============================================================================
suppressMessages({library(ggplot2); library(dplyr); library(randplot)})
root <- "explorations/2026-07-09_a5-elbow-validation"
S <- readRDS(file.path(root, "output/stage1_summary.rds"))
summ <- S$summ
figdir <- file.path(root, "output/figures")

lab <- function(design, sum_s) sprintf("%s (Σs=%.1f)", design, sum_s)
summ <- summ |> mutate(sum_s = s_S + s_Y,
                       design_lab = lab(design, sum_s),
                       regime = factor(regime, levels = c("above","edge","gap","below")))

# ---- elbow scaling: log RMSE ~ log n (debiased) -----------------------------
d_sig <- summ |> filter(estimator == "debiased")
p1 <- ggplot(d_sig, aes(log(n), log(rmse), color = regime, group = design_lab)) +
  geom_line() + geom_point(size = 1.6) +
  facet_wrap(~pair, scales = "free_y") +
  scale_color_manual(values = RandCatPal[c(1, 3, 5, 7)]) +
  labs(title = "A5 elbow signature: RMSE scaling of the one-step debiased estimator",
       subtitle = "Slope ~ -1/2 above the first-order boundary (Σs > d); shallower in the gap/below",
       x = "log n", y = "log RMSE", color = "regime") +
  theme_rand()
ggsave(file.path(figdir, "elbow_scaling.pdf"), p1, width = 9, height = 4.5, device = "pdf")

# ---- coverage vs n (debiased, SS) -------------------------------------------
d_cov <- summ |> filter(estimator == "debiased", pair == "SS")
p2 <- ggplot(d_cov, aes(n, coverage, color = regime, group = design_lab)) +
  geom_hline(yintercept = 0.95, linetype = 2, color = "grey40") +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = 0.94, ymax = 0.96,
           alpha = 0.08, fill = "grey30") +
  geom_line() + geom_point(size = 1.8) +
  scale_x_log10() +
  scale_color_manual(values = RandCatPal[c(1, 3, 5, 7)]) +
  labs(title = "Coverage of the debiased CI (SS diagonal functional)",
       subtitle = "Nominal above the first-order boundary; degrades in the gap/below",
       x = "n (log scale)", y = "empirical coverage", color = "regime") +
  theme_rand()
ggsave(file.path(figdir, "coverage_vs_n.pdf"), p2, width = 8, height = 4.5, device = "pdf")

cat("wrote elbow_scaling.pdf and coverage_vs_n.pdf\n")
