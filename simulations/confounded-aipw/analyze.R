# =============================================================================
# analyze.R -- summarise a confounded-aipw run into the IW-vs-AIPW comparison
# =============================================================================
# Purpose: turn one results file into the per-configuration table the manuscript
#   and session notes report: mean estimate, bias against the target rho_true,
#   bias against the importance-weighting limit, RMSE, CI coverage, and the
#   positivity diagnostic.
# Inputs : results/<run-id>.rds  (written by run_study.R)
# Outputs: results/<run-id>_summary.rds and a console table
#
# Usage (from the repository root):
#   Rscript simulations/confounded-aipw/analyze.R                 # newest run
#   Rscript simulations/confounded-aipw/analyze.R --run-id 20260925-101500
# =============================================================================

# --- 0. Setup ----------------------------------------------------------------
STUDY_DIR <- "simulations/confounded-aipw"
if (!dir.exists(STUDY_DIR)) {
  stop("Run this from the repository root: ", STUDY_DIR, " not found.")
}
RESULTS_DIR <- file.path(STUDY_DIR, "results")

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
  if (length(files) == 0) {
    stop("No results files in ", RESULTS_DIR, "; run run_study.R first.")
  }
  # Run ids are timestamps, so lexicographic order is chronological order.
  sort(files, decreasing = TRUE)[1]
}

res_file <- resolve_run(opt$run_id)
res <- readRDS(res_file)
message(sprintf("Run %s | package %s | %s | %d rows%s",
                attr(res, "run_id"), attr(res, "pkg_version"),
                attr(res, "r_version"), nrow(res),
                if (isTRUE(attr(res, "smoke"))) " | SMOKE (not reportable)" else ""))

# --- 1. Failure accounting (before any aggregation) --------------------------
# Reporting a mean over an unknown denominator is worse than reporting nothing,
# so failures are counted and named first.
n_failed <- sum(!is.na(res$error_msg))
if (n_failed > 0) {
  message(sprintf("%d/%d replications FAILED; excluded from the summary below.",
                  n_failed, nrow(res)))
  print(table(res$error_msg[!is.na(res$error_msg)]))
}
ok <- res[is.na(res$error_msg) & is.finite(res$estimate), , drop = FALSE]
if (nrow(ok) == 0) stop("No successful replications to summarise.")

# --- 2. Per-configuration summary -------------------------------------------
summarise_config <- function(d) {
  data.frame(
    block        = d$block[1],
    dgp          = d$dgp[1],
    dgp_kind     = d$dgp_kind[1],
    n            = d$n[1],
    method       = d$method[1],
    reps         = nrow(d),
    rho_true     = d$truth[1],
    rho_iw_limit = d$rho_iw_limit[1],
    mean_est     = mean(d$estimate),
    mc_se        = stats::sd(d$estimate) / sqrt(nrow(d)),
    bias         = mean(d$error),
    bias_vs_iw   = mean(d$error_vs_iw_limit),
    rmse         = sqrt(mean(d$error^2)),
    coverage     = mean(d$covered),
    mean_se      = mean(d$std_error),
    mean_M       = mean(d$M_final),
    pct_clipped  = if (all(is.na(d$n_clipped))) NA_real_ else
                     100 * mean(d$n_clipped / d$n, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

summ <- do.call(rbind, lapply(split(ok, ok$config_id), summarise_config))
summ <- summ[order(summ$block, summ$dgp, summ$n, summ$method), ]
rownames(summ) <- NULL

# --- 3. Console report -------------------------------------------------------
fmt <- function(x, digits = 4) formatC(x, format = "f", digits = digits, width = 8)

cat("\n================ IW vs AIPW: per-configuration summary ================\n")
for (blk in c("agreement", "confounded", "smalln")) {
  s <- summ[summ$block == blk, , drop = FALSE]
  if (nrow(s) == 0) next
  cat(sprintf("\n--- block: %s ---\n", blk))
  cat(sprintf("%-8s %-6s %-22s %5s %9s %9s %9s %9s %8s %7s\n",
              "dgp", "n", "method", "reps", "rho_true", "mean_est",
              "bias", "bias_vs_iw", "rmse", "cover"))
  for (i in seq_len(nrow(s))) {
    cat(sprintf("%-8s %-6d %-22s %5d %s %s %s %s %s %6.3f\n",
                s$dgp[i], s$n[i], s$method[i], s$reps[i],
                fmt(s$rho_true[i]), fmt(s$mean_est[i]), fmt(s$bias[i]),
                fmt(s$bias_vs_iw[i]), fmt(s$rmse[i]), s$coverage[i]))
  }
}

# --- 4. The headline contrast ------------------------------------------------
# One row per (dgp, n) pairing the two methods, which is the comparison the
# manuscript actually makes. `|bias| reduction` is positive when AIPW is closer to
# the target than IW is; it is the number the confounded block exists to produce.
cat("\n================ Paired contrast: AIPW minus IW ================\n")
cat(sprintf("%-8s %-6s %10s %10s %10s %10s %9s %9s\n",
            "dgp", "n", "rho_true", "iw_limit", "IW est", "AIPW est",
            "IW bias", "AIPW bias"))
keys <- unique(summ[, c("dgp", "n", "block")])
for (i in seq_len(nrow(keys))) {
  a <- summ[summ$dgp == keys$dgp[i] & summ$n == keys$n[i] &
              summ$method == "importance_weighting", ]
  b <- summ[summ$dgp == keys$dgp[i] & summ$n == keys$n[i] &
              summ$method == "aipw", ]
  if (nrow(a) != 1 || nrow(b) != 1) next
  cat(sprintf("%-8s %-6d %s %s %s %s %s %s\n",
              keys$dgp[i], keys$n[i], fmt(a$rho_true), fmt(a$rho_iw_limit),
              fmt(a$mean_est), fmt(b$mean_est), fmt(a$bias), fmt(b$bias)))
}

clip <- summ[!is.na(summ$pct_clipped) & summ$pct_clipped > 0, , drop = FALSE]
if (nrow(clip) > 0) {
  cat("\nPositivity diagnostic (AIPW arm): % of cross-fit propensities clipped\n")
  for (i in seq_len(nrow(clip))) {
    cat(sprintf("  %-8s n=%-6d %.2f%%\n", clip$dgp[i], clip$n[i], clip$pct_clipped[i]))
  }
}

# --- 5. Export ---------------------------------------------------------------
attr(summ, "run_id")      <- attr(res, "run_id")
attr(summ, "n_failed")    <- n_failed
attr(summ, "pkg_version") <- attr(res, "pkg_version")
out_file <- file.path(RESULTS_DIR, paste0(attr(res, "run_id"), "_summary.rds"))
saveRDS(summ, out_file)
cat(sprintf("\nWrote %s\n", out_file))
