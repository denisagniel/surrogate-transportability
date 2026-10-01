# =============================================================================
# analyze.R -- summarise a generality-validation run into the three block reports
# =============================================================================
# Purpose: turn one combined results file into the numbers the manuscript reports
#   for this study's three design blocks (README.md "Design"):
#     1. ENSEMBLE  -- the DISTRIBUTION of coverage and bias across a rho-balanced
#                     set of random DGPs at n = 10,000. The headline claim is that
#                     the estimator is calibrated across a broad DGP ensemble, not
#                     only on the four hand-picked canonical specifications, so the
#                     reportable quantity is a distribution, not a single mean.
#     2. ANCHORS   -- the four canonical DGPs at n = 10,000, which must reproduce
#                     the main validation table (inst/paper/main.tex,
#                     \label{tab:performance}). Disagreement there is an
#                     implementation problem, not a finding.
#     3. NSCALE    -- dgp1 and a 12-DGP ensemble subset across
#                     n in {500, 2000, 10000, 40000}, documenting the finite-n
#                     attenuation and what the jackknife correction does to it.
#   Every block is reported for BOTH the raw plug-in estimate and the
#   jackknife bias-corrected estimate, because the raw-vs-corrected contrast is
#   the study's second deliverable.
#
# Inputs : results/<run-id>.rds  (written by slurm/combine.R)
# Outputs: results/<run-id>_summary.rds  (per-configuration table, with the
#          block-level roll-ups attached as attributes) and a console report.
#
# Usage (from the repository root):
#   Rscript simulations/generality-validation/analyze.R                 # newest run
#   Rscript simulations/generality-validation/analyze.R --run-id 20260928-141420_1188e58
#
# Run time: a few seconds (reads one ~50k-row data frame; no simulation).
# =============================================================================

# --- 0. Setup ----------------------------------------------------------------
STUDY_DIR <- "simulations/generality-validation"
if (!dir.exists(STUDY_DIR)) {
  stop("Run this from the repository root: ", STUDY_DIR, " not found.")
}
RESULTS_DIR <- file.path(STUDY_DIR, "results")

N_LARGE     <- 10000L   # the study's "operating" sample size (config/grid.R)
NOMINAL     <- 0.95     # nominal CI level
CALIB_TOL   <- 0.02     # |coverage - NOMINAL| within which a DGP counts as calibrated

# dgp id -> the label the manuscript and slides use. The package ids are
# historical and skip "dgp3" (see canonical_dgp_params()'s @details), so the
# mapping has to be explicit or the anchor block cannot be compared to
# Table \ref{tab:performance} at all.
PAPER_LABEL <- c(dgp1 = "DGP 1", dgp2 = "DGP 2", dgp4 = "DGP 3", dgp5 = "DGP 4")

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(run_id = NULL)
  i <- 1L
  while (i <= length(args)) {
    if (args[[i]] == "--run-id") {
      out$run_id <- args[[i + 1L]]; i <- i + 1L
    } else {
      stop("Unknown argument '", args[[i]], "'.")
    }
    i <- i + 1L
  }
  out
}
opt <- parse_args()

resolve_run <- function(run_id) {
  if (!is.null(run_id)) {
    f <- file.path(RESULTS_DIR, paste0(run_id, ".rds"))
    if (!file.exists(f)) stop("No results file for run-id '", run_id, "' at ", f)
    return(f)
  }
  files <- list.files(RESULTS_DIR, pattern = "^[0-9]{8}-[0-9]{6}.*\\.rds$",
                      full.names = TRUE)
  files <- files[!grepl("_summary\\.rds$", files)]
  files <- files[!grepl("INVALID", basename(files))]   # quarantined runs never resolve
  if (length(files) == 0) {
    stop("No results files in ", RESULTS_DIR, "; run slurm/combine.R first.")
  }
  # Run ids are timestamps, so lexicographic order is chronological order.
  sort(files, decreasing = TRUE)[1]
}

res_file <- resolve_run(opt$run_id)
res      <- readRDS(res_file)
run_id   <- attr(res, "run_id")
if (is.null(run_id)) run_id <- sub("\\.rds$", "", basename(res_file))

combined_at <- attr(res, "combined_at")
message(sprintf("Run %s | %d rows | combined %s", run_id, nrow(res),
                if (is.null(combined_at)) "(not recorded)" else combined_at))

# --- Assertions on the input, immediately after reading it -------------------
# A missing column here means the results predate the current run_one() contract;
# silently summarising whatever is present would produce a table of NA that reads
# like a finding.
REQUIRED <- c("unit", "config_id", "rep_id", "dgp_kind", "dgp", "dgp_seed", "n",
              "lambda", "truth", "estimate", "std_error", "error", "covered",
              "rho_jk", "jk_bias", "error_jk", "covered_jk", "M_final",
              "converged", "error_msg")
missing_cols <- setdiff(REQUIRED, names(res))
if (length(missing_cols)) {
  stop("Results file is missing required column(s): ",
       paste(missing_cols, collapse = ", "))
}
if (any(is.na(res$truth))) {
  stop(sum(is.na(res$truth)), " row(s) have NA `truth`; the offline truth table ",
       "did not cover every configuration, so every coverage number below would ",
       "be meaningless.")
}

# --- 1. Failure accounting (before any aggregation) --------------------------
# Reporting a mean over an unknown denominator is worse than reporting nothing.
n_failed <- sum(!is.na(res$error_msg))
if (n_failed > 0) {
  message(sprintf("%d/%d replications FAILED; excluded from the summary below.",
                  n_failed, nrow(res)))
  print(utils::head(sort(table(res$error_msg[!is.na(res$error_msg)]),
                         decreasing = TRUE), 5))
}
ok <- res[is.na(res$error_msg) & is.finite(res$estimate) & is.finite(res$rho_jk), ,
          drop = FALSE]
if (nrow(ok) == 0) stop("No successful replications to summarise.")

# --- 2. Block labels (derived; config/grid.R carries no `block` column) ------
# Ensemble DGPs are the `random` kind, canonical anchors the `canonical` kind;
# within each, n == N_LARGE is the operating cell and the other n values are the
# n-scaling slice. This reproduces grid.R's four rbind'd blocks (b1a/b1b/b2/b3)
# from the row content alone, so it does not depend on config_id arithmetic.
label_block <- function(dgp_kind, n) {
  ifelse(dgp_kind == "random" & n == N_LARGE, "ensemble",
  ifelse(dgp_kind == "random",                "ensemble_n",
  ifelse(n == N_LARGE,                        "anchors", "nscale")))
}
ok$block <- label_block(ok$dgp_kind, ok$n)

# --- 3. Per-configuration summary -------------------------------------------
summarise_config <- function(d) {
  data.frame(
    config_id   = d$config_id[1],
    block       = d$block[1],
    dgp_kind    = d$dgp_kind[1],
    dgp         = if (is.na(d$dgp[1])) sprintf("seed%d", d$dgp_seed[1]) else d$dgp[1],
    dgp_seed    = d$dgp_seed[1],
    n           = d$n[1],
    reps        = nrow(d),
    rho_true    = d$truth[1],
    mean_est    = mean(d$estimate),
    emp_se      = stats::sd(d$estimate),
    mean_se     = mean(d$std_error),
    bias        = mean(d$error),
    rmse        = sqrt(mean(d$error^2)),
    coverage    = mean(d$covered),
    # jackknife bias-corrected arm
    mean_est_jk = mean(d$rho_jk),
    bias_jk     = mean(d$error_jk),
    rmse_jk     = sqrt(mean(d$error_jk^2)),
    coverage_jk = mean(d$covered_jk),
    mean_jk_adj = mean(d$jk_bias),
    # diagnostics
    mean_M      = mean(d$M_final),
    pct_M_capped = 100 * mean(d$converged == 0L),
    stringsAsFactors = FALSE
  )
}

summ <- do.call(rbind, lapply(split(ok, ok$config_id), summarise_config))
summ <- summ[order(match(summ$block, c("ensemble", "anchors", "ensemble_n", "nscale")),
                   summ$dgp, summ$n), ]
rownames(summ) <- NULL

fmt <- function(x, digits = 3) formatC(x, format = "f", digits = digits, width = 7)

# --- 4. Block 1: the ensemble distribution (the headline) --------------------
# The claim is about the DISTRIBUTION across DGPs, so quantiles of the per-DGP
# coverage and |bias| are the reportable summary; a pooled mean would hide a
# single badly-behaved DGP inside 56 well-behaved ones.
ensemble <- summ[summ$block == "ensemble", , drop = FALSE]
ens_stats <- if (nrow(ensemble) == 0) NULL else list(
  n_dgps        = nrow(ensemble),
  reps_per_dgp  = stats::median(ensemble$reps),
  rho_true_rng  = range(ensemble$rho_true),
  cov_q         = stats::quantile(ensemble$coverage, c(0, .05, .25, .5, .75, .95, 1)),
  cov_median    = stats::median(ensemble$coverage),
  cov_mean      = mean(ensemble$coverage),
  n_calibrated  = sum(abs(ensemble$coverage - NOMINAL) <= CALIB_TOL),
  n_under       = sum(ensemble$coverage < NOMINAL - CALIB_TOL),
  n_over        = sum(ensemble$coverage > NOMINAL + CALIB_TOL),
  absbias_q     = stats::quantile(abs(ensemble$bias), c(.5, .9, 1)),
  se_ratio_q    = stats::quantile(ensemble$mean_se / ensemble$emp_se, c(.5, 0, 1)),
  cov_jk_median = stats::median(ensemble$coverage_jk),
  absbias_jk_q  = stats::quantile(abs(ensemble$bias_jk), c(.5, .9, 1))
)

cat("\n=========== Block 1: random-DGP ensemble (n = ", N_LARGE, ") ===========\n",
    sep = "")
if (is.null(ens_stats)) {
  cat("(no ensemble configurations in this run)\n")
} else with(ens_stats, {
  cat(sprintf("%d random DGPs x %d reps; rho_true spans [%.3f, %.3f]\n",
              n_dgps, reps_per_dgp, rho_true_rng[1], rho_true_rng[2]))
  cat("Per-DGP coverage of nominal 95%% CIs, quantiles:\n")
  print(round(cov_q, 3))
  cat(sprintf("  median %.3f | mean %.3f | within +/-%.2f of nominal: %d/%d DGPs",
              cov_median, cov_mean, CALIB_TOL, n_calibrated, n_dgps))
  cat(sprintf(" (%d under, %d over)\n", n_under, n_over))
  cat(sprintf("  |bias| across DGPs: median %.3f, 90th pct %.3f, max %.3f\n",
              absbias_q[1], absbias_q[2], absbias_q[3]))
  cat(sprintf("  est.SE / emp.SE:    median %.3f, min %.3f, max %.3f\n",
              se_ratio_q[1], se_ratio_q[2], se_ratio_q[3]))
  cat(sprintf("  jackknife arm: median coverage %.3f; |bias| median %.3f, max %.3f\n",
              cov_jk_median, absbias_jk_q[1], absbias_jk_q[3]))
})

# Name the worst-behaved ensemble DGPs: an aggregate that hides its own tail is
# the failure mode this block exists to rule out.
if (!is.null(ens_stats)) {
  worst <- ensemble[order(ensemble$coverage), ][seq_len(min(5, nrow(ensemble))), ]
  cat("\n  lowest-coverage ensemble DGPs:\n")
  cat(sprintf("  %-10s %8s %8s %8s %8s %8s\n",
              "dgp", "rho_true", "bias", "cover", "cover_jk", "mean_M"))
  for (i in seq_len(nrow(worst))) {
    cat(sprintf("  %-10s %s %s %s %s %8.0f\n", worst$dgp[i], fmt(worst$rho_true[i]),
                fmt(worst$bias[i]), fmt(worst$coverage[i]),
                fmt(worst$coverage_jk[i]), worst$mean_M[i]))
  }
}

# --- 5. Block 2: canonical anchors -----------------------------------------
anchors <- summ[summ$block == "anchors", , drop = FALSE]
cat("\n=========== Block 2: canonical anchors (n = ", N_LARGE, ") ===========\n",
    sep = "")
if (nrow(anchors) == 0) {
  cat("(no anchor configurations in this run)\n")
} else {
  anchors$paper <- ifelse(anchors$dgp %in% names(PAPER_LABEL),
                          PAPER_LABEL[anchors$dgp], anchors$dgp)
  cat(sprintf("%-6s %-6s %5s %8s %8s %8s %8s %8s %8s %8s\n",
              "dgp", "paper", "reps", "rho_true", "mean_est", "bias",
              "emp_SE", "est_SE", "cover", "cover_jk"))
  for (i in seq_len(nrow(anchors))) {
    cat(sprintf("%-6s %-6s %5d %s %s %s %s %s %s %s\n",
                anchors$dgp[i], anchors$paper[i], anchors$reps[i],
                fmt(anchors$rho_true[i]), fmt(anchors$mean_est[i]),
                fmt(anchors$bias[i]), fmt(anchors$emp_se[i]),
                fmt(anchors$mean_se[i]), fmt(anchors$coverage[i]),
                fmt(anchors$coverage_jk[i])))
  }
}

# --- 6. Block 3: n-scaling, raw vs jackknife -------------------------------
# The attenuation claim is that |bias| falls roughly like 1/sqrt(n); the
# jackknife claim is that it halves the bias at small n and is harmless at large
# n. Both are read off the same table, per DGP, across the n grid.
nscale_ids <- unique(c(summ$dgp[summ$block == "nscale"],
                       summ$dgp[summ$block == "ensemble_n"]))
ngrid_rows <- summ[summ$dgp %in% nscale_ids, , drop = FALSE]

cat("\n=========== Block 3: n-scaling (raw vs jackknife) ===========\n")
if (nrow(ngrid_rows) == 0) {
  cat("(no n-scaling configurations in this run)\n")
} else {
  report_one_dgp <- function(d) {
    d <- d[order(d$n), , drop = FALSE]
    cat(sprintf("\n  %s (rho_true = %+.3f)\n", d$dgp[1], d$rho_true[1]))
    cat(sprintf("  %7s %5s %9s %9s %9s %9s %9s %9s\n",
                "n", "reps", "bias", "bias_jk", "|b|ratio", "rmse", "cover",
                "cover_jk"))
    for (i in seq_len(nrow(d))) {
      ratio <- if (abs(d$bias[i]) > 0) abs(d$bias_jk[i]) / abs(d$bias[i]) else NA_real_
      cat(sprintf("  %7d %5d %s %s %s %s %s %s\n",
                  d$n[i], d$reps[i], fmt(d$bias[i]), fmt(d$bias_jk[i]),
                  fmt(ratio), fmt(d$rmse[i]), fmt(d$coverage[i]),
                  fmt(d$coverage_jk[i])))
    }
    # sqrt(n) check: bias * sqrt(n) is flat if |bias| ~ c / sqrt(n).
    cat(sprintf("  bias * sqrt(n): %s\n",
                paste(sprintf("%.2f", d$bias * sqrt(d$n)), collapse = "  ")))
  }
  canon_ngrid <- ngrid_rows[ngrid_rows$dgp_kind == "canonical", , drop = FALSE]
  for (g in split(canon_ngrid, canon_ngrid$dgp)) report_one_dgp(g)

  # The 12-DGP ensemble n-grid is summarised as a distribution rather than DGP by
  # DGP: the per-DGP detail lives in the summary file, and the claim being checked
  # here ("the jackknife helps at small n, does not hurt at large n") is a
  # statement about the ensemble.
  ens_ngrid <- ngrid_rows[ngrid_rows$dgp_kind == "random", , drop = FALSE]
  if (nrow(ens_ngrid) > 0) {
    cat("\n  ensemble n-grid subset (distribution across DGPs at each n):\n")
    cat(sprintf("  %7s %6s %10s %10s %10s %10s %10s\n", "n", "DGPs",
                "med|bias|", "med|bias_jk|", "jk better", "med cover",
                "med cov_jk"))
    for (g in split(ens_ngrid, ens_ngrid$n)) {
      cat(sprintf("  %7d %6d %10.3f %12.3f %10s %10.3f %10.3f\n",
                  g$n[1], nrow(g),
                  stats::median(abs(g$bias)), stats::median(abs(g$bias_jk)),
                  sprintf("%d/%d", sum(abs(g$bias_jk) < abs(g$bias)), nrow(g)),
                  stats::median(g$coverage), stats::median(g$coverage_jk)))
    }
  }
}

# --- 7. Adaptive-M diagnostic ----------------------------------------------
# `converged == 0` means the MC-precision stopping rule never triggered and
# M_final is the M_max cap. Those cells carry more Monte Carlo noise in
# rho_hat than the tolerance targeted, which is worth knowing before reading a
# coverage number off them.
capped <- summ[summ$pct_M_capped > 0, , drop = FALSE]
cat(sprintf("\nAdaptive M: mean M_final %.0f overall; %d/%d configurations have >0%% of reps at the M_max cap",
            stats::weighted.mean(summ$mean_M, summ$reps), nrow(capped), nrow(summ)))
if (nrow(capped) > 0) {
  cat(sprintf(" (worst %.0f%% of reps, config %d, |rho_true| = %.2f)",
              max(capped$pct_M_capped),
              capped$config_id[which.max(capped$pct_M_capped)],
              abs(capped$rho_true[which.max(capped$pct_M_capped)])))
}
cat("\n")

# --- 8. Export ---------------------------------------------------------------
attr(summ, "run_id")       <- run_id
attr(summ, "n_failed")     <- n_failed
attr(summ, "n_units")      <- nrow(res)
attr(summ, "nominal")      <- NOMINAL
attr(summ, "calib_tol")    <- CALIB_TOL
attr(summ, "ensemble")     <- ens_stats
attr(summ, "analysed_at")  <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

write_summary <- function(x = summ, dir = RESULTS_DIR, id = run_id) {
  out_file <- file.path(dir, paste0(id, "_summary.rds"))
  saveRDS(x, out_file)
  cat(sprintf("Wrote %s\n", out_file))
  invisible(out_file)
}

# Script-only: sourcing this file interactively gives you `res`, `ok` and `summ`
# to inspect without writing anything; call write_summary() by hand if you want
# the file. The literal guard is required -- `!interactive()` alone is also TRUE
# when another script sources this one under Rscript.
if (!interactive() && sys.nframe() == 0L) {
  write_summary()
}
