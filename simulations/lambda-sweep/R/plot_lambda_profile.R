#!/usr/bin/env Rscript
# =============================================================================
# plot_lambda_profile.R -- the paper's missing lambda-sensitivity figure
# =============================================================================
# Purpose: turn a combined lambda-sweep result set into (a) a per-(DGP, lambda)
#          summary table and (b) the RAND-styled figure promised by
#          inst/paper/main.tex ("Interpreting lambda"; Section sec:sim-future,
#          third bullet): Theta-hat_n(lambda) with influence-function-based CI
#          bands across a grid of lambda.
# Inputs:  results/<run-id>_reps<R>.rds     (from local/combine.R)
#          results/exit_interior_prediction.rds  (from R/exit_interior_prediction.R)
# Outputs: results/lambda_profile_summary.rds / .csv
#          results/figures/lambda_profile.pdf   <- VECTOR, for the paper
#          results/figures/lambda_profile.png   <- raster preview
#          results/figures/lambda_contrast.pdf / .png
#
# Usage (from the study directory):
#   Rscript R/plot_lambda_profile.R --results results/<run-id>_reps20.rds
# Run time: seconds.
#
# Three things are drawn on purpose, because the figure has to be readable as
# EVIDENCE and not just as a shape:
#   1. the wide band  = mean IF-based 95% CI half-width (what one study reports);
#   2. the dark band  = +/-1.96 x Monte-Carlo SE of the mean profile (how well
#      THIS study pins the mean down) -- without it a reader cannot tell a real
#      tilt from MC noise;
#   3. the dashed horizontal line = Corr_K(tau_S, tau_Y), which Proposition
#      "Interior-regime closed form" says Theta EQUALS for lambda <= p_min, and
#      the dashed vertical line = p_min, the sharp interior-regime boundary.
# =============================================================================

# 0. Setup ----
suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(ggplot2)
  library(randplot)
  library(surrogateTransportability)
})

set.seed(20260925)  # nothing random here; set once for reproducibility discipline

option_list <- list(
  make_option("--study-dir", type = "character", dest = "study_dir", default = ".",
              help = "Study directory [default %default]"),
  make_option("--results", type = "character", dest = "results", default = NULL,
              help = "Combined results .rds; defaults to the newest in results/")
)
opt <- parse_args(OptionParser(option_list = option_list))

source(file.path(opt$study_dir, "config", "grid.R"))
source(file.path(opt$study_dir, "R", "cell_cates.R"))

fig_dir <- file.path(opt$study_dir, "results", "figures")
fs::dir_create(fig_dir)

# 1. Data ----
results_path <- opt$results
if (is.null(results_path)) {
  cand <- list.files(file.path(opt$study_dir, "results"), pattern = "_reps[0-9]+\\.rds$",
                     full.names = TRUE)
  if (length(cand) == 0L) {
    stop("No combined results found in results/. Run local/combine.R first.")
  }
  results_path <- cand[order(file.mtime(cand), decreasing = TRUE)][1]
}
raw <- readr::read_rds(results_path)
cat(sprintf("[plot] %s: %d rows, %d reps, %d lambdas, %d DGPs\n", basename(results_path),
            nrow(raw), dplyr::n_distinct(raw$rep_id), dplyr::n_distinct(raw$lambda),
            dplyr::n_distinct(raw$dgp)))

n_failed <- sum(!is.na(raw$error_msg))
if (n_failed > 0L) {
  stop(n_failed, " rows carry an error_msg; fix or purge them before plotting.")
}

# Slide labels (the paper renumbers dgp1/2/4/5 as DGP 1-4) come from the package
# spec, so the figure cannot drift from the manuscript's numbering.
dgp_labels <- vapply(sort(unique(raw$dgp)),
                     function(d) canonical_dgp_params(d)$slide_label, character(1))
interior_value <- vapply(sort(unique(raw$dgp)), corr_K_cell_cates, numeric(1))

ref <- tibble::tibble(
  dgp       = names(dgp_labels),
  panel     = sprintf("%s (%s)", dgp_labels, names(dgp_labels)),
  interior  = interior_value[names(dgp_labels)]
)

dat <- raw |>
  left_join(ref, by = "dgp") |>
  mutate(panel = factor(panel, levels = ref$panel[order(ref$dgp)]))

# 2. Summarise: mean profile, mean IF band, Monte-Carlo SE of the mean ----
# The Monte-Carlo SE uses the PAIRED structure only for the contrast below; the
# level's MC SE is the ordinary sd/sqrt(R) across independent replications.
summary_tbl <- dat |>
  summarise(
    .by = c(dgp, panel, lambda, interior),
    reps          = dplyr::n(),
    mean_theta    = mean(estimate),
    sd_theta      = stats::sd(estimate),
    mc_se         = stats::sd(estimate) / sqrt(dplyr::n()),
    mean_se       = mean(std_error),
    mean_ci_lower = mean(ci_lower),
    mean_ci_upper = mean(ci_upper),
    mean_M        = mean(M_final),
    coverage      = if (all(is.na(covered))) NA_real_ else mean(covered, na.rm = TRUE),
    truth_source  = dplyr::first(truth_source),
    mean_secs     = mean(secs)
  ) |>
  mutate(
    interior_regime = lambda <= P_MIN_CANONICAL,
    bias_vs_interior = mean_theta - interior
  ) |>
  arrange(dgp, lambda)

# Paired within-replication contrast against the smallest lambda: the quantity the
# paired design buys. Its MC SE is much smaller than the level's because the
# replication's own sampling noise cancels.
base_lambda <- min(LAMBDA_GRID)
contrast_tbl <- dat |>
  select(dgp, panel, rep_id, lambda, estimate) |>
  left_join(
    dat |> filter(lambda == base_lambda) |> select(dgp, rep_id, base_estimate = estimate),
    by = c("dgp", "rep_id")
  ) |>
  mutate(delta = estimate - base_estimate) |>
  summarise(
    .by = c(dgp, panel, lambda),
    mean_delta = mean(delta),
    se_delta   = stats::sd(delta) / sqrt(dplyr::n())
  ) |>
  arrange(dgp, lambda)

readr::write_rds(list(summary = summary_tbl, contrast = contrast_tbl,
                      results_file = basename(results_path)),
                 file.path(opt$study_dir, "results", "lambda_profile_summary.rds"))
readr::write_csv(summary_tbl, file.path(opt$study_dir, "results", "lambda_profile_summary.csv"))

# 3. Figures ----
theta_lab <- expression(hat(Theta)[n](lambda))

p_profile <- ggplot(summary_tbl, aes(x = lambda)) +
  geom_vline(xintercept = P_MIN_CANONICAL, linetype = "22", colour = RandGrayPal[6]) +
  geom_hline(aes(yintercept = interior), linetype = "42", colour = RandCatPal[3]) +
  geom_ribbon(aes(ymin = mean_ci_lower, ymax = mean_ci_upper),
              fill = RandCatPal[1], alpha = 0.18) +
  geom_ribbon(aes(ymin = mean_theta - 1.96 * mc_se, ymax = mean_theta + 1.96 * mc_se),
              fill = RandCatPal[1], alpha = 0.55) +
  geom_line(aes(y = mean_theta), colour = RandCatPal[1], linewidth = 0.7) +
  geom_point(aes(y = mean_theta), colour = RandCatPal[1], size = 1.5) +
  facet_wrap(~ panel, scales = "free_y", nrow = 2) +
  scale_x_continuous(breaks = LAMBDA_GRID, labels = function(x) sub("^0", "", x)) +
  labs(
    x = expression(paste("TV-ball radius ", lambda)),
    y = theta_lab,
    title = expression(paste("Sensitivity of the across-study correlation to the ball radius ",
                             lambda)),
    subtitle = sprintf(paste0("Mean over %d replications at n = %s. Light band: mean ",
                              "influence-function 95%% CI. ",
                              "Dark band: \u00b11.96 Monte-Carlo SE of the mean.\n",
                              "Vertical dashes: interior-regime boundary ",
                              "\u03bb = min p\u2080(k) = %.2f. ",
                              "Horizontal dashes: interior-regime closed form ",
                              "Corr\u2096(\u03c4\u209b, \u03c4\u1d67)."),
                       max(summary_tbl$reps), format(unique(dat$n), big.mark = ","),
                       P_MIN_CANONICAL)
  ) +
  theme_rand() +
  theme(plot.subtitle = element_text(size = 8, colour = RandGrayPal[7]),
        panel.spacing = unit(1, "lines"))

ggsave(fs::path(fig_dir, "lambda_profile.pdf"), p_profile,
       device = "pdf", width = 10, height = 6.5)          # VECTOR: paper asset
ggsave(fs::path(fig_dir, "lambda_profile.png"), p_profile,
       device = "png", width = 10, height = 6.5, dpi = 200, bg = "transparent")

p_contrast <- ggplot(contrast_tbl, aes(x = lambda, y = mean_delta)) +
  geom_vline(xintercept = P_MIN_CANONICAL, linetype = "22", colour = RandGrayPal[6]) +
  geom_hline(yintercept = 0, colour = RandGrayPal[5], linewidth = 0.3) +
  geom_ribbon(aes(ymin = mean_delta - 1.96 * se_delta, ymax = mean_delta + 1.96 * se_delta),
              fill = RandCatPal[2], alpha = 0.3) +
  geom_line(colour = RandCatPal[2], linewidth = 0.7) +
  geom_point(colour = RandCatPal[2], size = 1.5) +
  facet_wrap(~ panel, scales = "free_y", nrow = 2) +
  scale_x_continuous(breaks = LAMBDA_GRID, labels = function(x) sub("^0", "", x)) +
  labs(
    x = expression(paste("TV-ball radius ", lambda)),
    y = bquote(hat(Theta)[n](lambda) - hat(Theta)[n](.(base_lambda))),
    title = expression(paste("Paired within-study change in ", hat(Theta)[n],
                             " relative to the deepest interior radius")),
    subtitle = sprintf(paste0("Each replication contributes a within-study difference ",
                              "(same dataset at every \u03bb), ",
                              "so replication-level noise cancels.\n",
                              "Band: \u00b11.96 Monte-Carlo SE. ",
                              "Vertical dashes: interior boundary \u03bb = %.2f, where theory ",
                              "predicts the profile first departs from flat."),
                       P_MIN_CANONICAL)
  ) +
  theme_rand() +
  theme(plot.subtitle = element_text(size = 8, colour = RandGrayPal[7]),
        panel.spacing = unit(1, "lines"))

ggsave(fs::path(fig_dir, "lambda_contrast.pdf"), p_contrast,
       device = "pdf", width = 10, height = 6.5)
ggsave(fs::path(fig_dir, "lambda_contrast.png"), p_contrast,
       device = "png", width = 10, height = 6.5, dpi = 200, bg = "transparent")

# 4. Report the numbers ----
pred_path <- file.path(opt$study_dir, "results", "exit_interior_prediction.rds")
if (file.exists(pred_path)) {
  cat("\n--- MCMC-free first-order prediction at the interior edge ---\n")
  print(readr::read_rds(pred_path)[, c("dgp", "r_K_interior", "sum_varpi", "prediction")],
        row.names = FALSE)
}

cat("\n--- Theta-hat_n(lambda) profile ---\n")
summary_tbl |>
  mutate(across(c(mean_theta, sd_theta, mc_se, mean_se, bias_vs_interior), \(x) round(x, 4)),
         coverage = round(coverage, 3), mean_M = round(mean_M)) |>
  select(dgp, lambda, interior_regime, mean_theta, mc_se, mean_se, sd_theta,
         bias_vs_interior, coverage, mean_M) |>
  as.data.frame() |>
  print(row.names = FALSE)

cat("\n--- Paired within-study contrast vs lambda = ", base_lambda, " ---\n", sep = "")
contrast_tbl |>
  mutate(across(c(mean_delta, se_delta), \(x) round(x, 4)),
         z = round(mean_delta / se_delta, 1)) |>
  select(dgp, lambda, mean_delta, se_delta, z) |>
  as.data.frame() |>
  print(row.names = FALSE)

cat(sprintf("\n[plot] wrote %s and %s (+ .png previews)\n",
            fs::path(fig_dir, "lambda_profile.pdf"), fs::path(fig_dir, "lambda_contrast.pdf")))
