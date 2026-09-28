# =============================================================================
# run_study.R -- local parallel driver for the confounded-aipw study
# =============================================================================
# Purpose: run every unit of unit_table() on this machine and write ONE combined
#   results file. Deliberately scheduler-less: this study is sized to run in about
#   an hour on a laptop, so the O2 scaffold would add a cluster round-trip and a
#   Duo approval for no benefit. run_one() is unchanged from the cluster contract,
#   so handing this study to the scaffold later needs no edit to the science.
# Inputs : config/grid.R, R/{dgp,estimators,run_one}.R, and the installed package.
# Outputs: results/<run-id>.rds  (one row per unit, plus provenance attributes)
#
# Run time: ~32 s per large-n unit, ~2 s per small-n unit. At the default grid
# (640 large-n, 480 small-n units) that is roughly 6 core-hours, or about 70
# minutes on 5 workers. Prototype first with --smoke.
#
# Usage (from the repository root):
#   Rscript simulations/confounded-aipw/run_study.R --smoke
#   Rscript simulations/confounded-aipw/run_study.R --workers 6
#   Rscript simulations/confounded-aipw/run_study.R --blocks confounded,smalln
#
# Parallel backend: parallel::mclapply (fork). Forking shares the loaded package
# copy-on-write, so per-worker memory is dominated by the estimator's two
# n x M_final influence-function matrices (~150 MB at n = 10000, M = 900). Keep
# workers * 300 MB below available RAM. No backend to unregister (fork only).
# =============================================================================

# --- 0. Setup ----------------------------------------------------------------
library(parallel)
library(surrogateTransportability)

STUDY_DIR <- "simulations/confounded-aipw"
if (!dir.exists(STUDY_DIR)) {
  stop("Run this from the repository root: ", STUDY_DIR, " not found.")
}

source(file.path(STUDY_DIR, "R", "dgp.R"))
source(file.path(STUDY_DIR, "config", "grid.R"))
source(file.path(STUDY_DIR, "R", "estimators.R"))
source(file.path(STUDY_DIR, "R", "run_one.R"))

# Reproducibility: every unit sets its own deterministic seed inside run_one()
# from unit_table()'s `seed` column, so this driver needs no global seed and the
# results do not depend on the order units happen to be dispatched in.

# --- CLI ---------------------------------------------------------------------
parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list(smoke = FALSE, workers = max(1L, detectCores() - 4L), blocks = NULL)
  i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (a == "--smoke") {
      out$smoke <- TRUE
    } else if (a == "--workers") {
      out$workers <- as.integer(args[[i + 1L]]); i <- i + 1L
    } else if (a == "--blocks") {
      out$blocks <- strsplit(args[[i + 1L]], ",", fixed = TRUE)[[1]]; i <- i + 1L
    } else {
      stop("Unknown argument '", a, "'. See the usage block at the top of this file.")
    }
    i <- i + 1L
  }
  if (is.na(out$workers) || out$workers < 1L) {
    stop("--workers must be a positive integer.")
  }
  out
}
opt <- parse_args()

# --- 1. Units to run ---------------------------------------------------------
units <- unit_table()

if (!is.null(opt$blocks)) {
  unknown <- setdiff(opt$blocks, unique(units$block))
  if (length(unknown) > 0) {
    stop("Unknown block(s): ", paste(unknown, collapse = ", "),
         ". Available: ", paste(unique(units$block), collapse = ", "), ".")
  }
  units <- units[units$block %in% opt$blocks, , drop = FALSE]
}

if (opt$smoke) {
  # One replication of every configuration, at a reduced M, to prove the pipeline
  # end to end before spending the full budget. Smoke results are NOT reportable:
  # M_MAX is overridden, so they are not comparable to a full run.
  M_MAX <<- 300L
  units <- do.call(rbind, lapply(split(units, units$config_id), function(u) u[1, ]))
  message("SMOKE: ", nrow(units), " units (1 per config), M_max forced to ", M_MAX)
}

run_id <- format(Sys.time(), "%Y%m%d-%H%M%S")
if (opt$smoke) run_id <- paste0(run_id, "_smoke")

message(sprintf("confounded-aipw | run-id %s | %d units | %d workers",
                run_id, nrow(units), opt$workers))
message(sprintf("blocks: %s",
                paste(sprintf("%s=%d", names(table(units$block)),
                              as.integer(table(units$block))), collapse = " ")))

# --- 2. Run ------------------------------------------------------------------
# One unit -> one row, failures captured as an error row rather than dropped, so
# a failed replication persists its error TEXT instead of vanishing or appearing
# as an indistinguishable NA (no silent fallbacks).
run_unit_safely <- function(k) {
  unit_row <- units[k, , drop = FALSE]
  tryCatch(
    run_one(unit_row),
    error = function(e) {
      data.frame(
        unit = unit_row$unit, config_id = unit_row$config_id,
        rep_id = unit_row$rep_id, block = unit_row$block,
        dgp_kind = unit_row$dgp_kind, dgp = unit_row$dgp, n = unit_row$n,
        lambda = unit_row$lambda, method = unit_row$method,
        estimate = NA_real_, std_error = NA_real_,
        ci_lower = NA_real_, ci_upper = NA_real_,
        truth = as.numeric(unit_row$rho_true),
        rho_iw_limit = as.numeric(unit_row$rho_iw_limit),
        error = NA_real_, error_vs_iw_limit = NA_real_,
        covered = NA_integer_, M_final = NA_integer_,
        converged = NA_integer_, n_clipped = NA_integer_,
        error_msg = conditionMessage(e), stringsAsFactors = FALSE
      )
    }
  )
}

# Progress is reported per chunk rather than per unit: a fork worker's output is
# interleaved and unordered, so per-unit printing would be unreadable and would
# also serialize on the console. Chunks are sized so each reports every few
# minutes at the default worker count.
chunk_size <- max(opt$workers * 4L, 8L)
chunks <- split(seq_len(nrow(units)),
                ceiling(seq_len(nrow(units)) / chunk_size))

started <- Sys.time()
results <- vector("list", length(chunks))
for (ci in seq_along(chunks)) {
  results[[ci]] <- do.call(rbind, mclapply(chunks[[ci]], run_unit_safely,
                                           mc.cores = opt$workers,
                                           mc.preschedule = FALSE))
  done <- max(chunks[[ci]])
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "mins"))
  message(sprintf("  %d/%d units | %.1f min elapsed | ~%.1f min remaining",
                  done, nrow(units), elapsed,
                  elapsed / done * (nrow(units) - done)))
}
res <- do.call(rbind, results)

# --- 3. Integrity checks -----------------------------------------------------
# Every requested unit must appear exactly once; a missing or duplicated unit
# would silently change the denominator of every mean reported downstream.
stopifnot(nrow(res) == nrow(units))
if (anyDuplicated(res$unit) > 0) {
  stop("Duplicate units in results: ", paste(res$unit[duplicated(res$unit)],
                                             collapse = ", "))
}
missing_units <- setdiff(units$unit, res$unit)
if (length(missing_units) > 0) {
  stop(length(missing_units), " units missing from results.")
}

n_failed <- sum(!is.na(res$error_msg))
if (n_failed > 0) {
  message(sprintf("WARNING: %d/%d units failed. First message: %s",
                  n_failed, nrow(res), res$error_msg[!is.na(res$error_msg)][1]))
}
n_unconverged <- sum(res$converged == 0L, na.rm = TRUE)
if (n_unconverged > 0) {
  message(sprintf("NOTE: %d/%d units hit M_max = %d without meeting the adaptive-M ",
                  n_unconverged, nrow(res), M_MAX),
          "tolerance; their M is the ceiling, not a converged choice.")
}

# --- 4. Export ---------------------------------------------------------------
# Provenance travels with the numbers: a results file that cannot say which grid,
# which package version and which R produced it is not reproducible.
attr(res, "run_id")       <- run_id
attr(res, "smoke")        <- opt$smoke
attr(res, "grid")         <- GRID
attr(res, "M_max")        <- M_MAX
attr(res, "pkg_version")  <- as.character(utils::packageVersion("surrogateTransportability"))
attr(res, "r_version")    <- R.version.string
attr(res, "runtime_mins") <- as.numeric(difftime(Sys.time(), started, units = "mins"))

out_dir <- file.path(STUDY_DIR, "results")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
out_file <- file.path(out_dir, paste0(run_id, ".rds"))
saveRDS(res, out_file)

message(sprintf("\nWrote %s (%d rows, %.1f min)",
                out_file, nrow(res), attr(res, "runtime_mins")))
message("Next: Rscript ", file.path(STUDY_DIR, "analyze.R"), " --run-id ", run_id)
