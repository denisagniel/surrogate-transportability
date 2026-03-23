#!/usr/bin/env Rscript
#' Local Runner for All Simulation Studies
#'
#' Runs all simulation scenarios sequentially on your laptop.
#' With influence function method, this should take minutes not hours!

library(cli)

# Color output helpers
success <- function(msg) cat(cli::col_green("✓"), msg, "\n")
error <- function(msg) cat(cli::col_red("✗"), msg, "\n")
info <- function(msg) cat(cli::col_blue("ℹ"), msg, "\n")
heading <- function(msg) {
  cat("\n")
  cat(cli::col_silver(strrep("=", 70)), "\n")
  cat(cli::col_cyan(cli::style_bold(msg)), "\n")
  cat(cli::col_silver(strrep("=", 70)), "\n\n")
}

heading("SURROGATE TRANSPORTABILITY SIMULATION RUNNER")

info("This will run all simulation studies sequentially.")
info("Using influence function method (60-120x faster than nested bootstrap)")
info("")

# Define simulation studies
# Note: Only including studies that use inference methods
# Skipping visualization and aggregation scripts
studies <- list(
  list(
    name = "Covariate Shift Validation",
    script = "sims/scripts/08_covariate_shift_validation.R",
    description = "Tests inference under pure covariate shift",
    estimated_time = "5-10 minutes (1000 reps)"
  )
  # Add more as they're updated:
  # list(
  #   name = "Selection Bias Validation",
  #   script = "sims/scripts/09_selection_bias_validation.R",
  #   description = "Tests robustness to selection bias",
  #   estimated_time = "5-10 minutes"
  # ),
  # ...
)

cat(sprintf("Found %d simulation studies to run:\n\n", length(studies)))

for (i in seq_along(studies)) {
  study <- studies[[i]]
  cat(sprintf("  %d. %s\n", i, study$name))
  cat(sprintf("     %s\n", study$description))
  cat(sprintf("     Estimated: %s\n", study$estimated_time))
  if (i < length(studies)) cat("\n")
}

cat("\n")
response <- readline(prompt = "Run all studies? [y/N]: ")

if (tolower(response) != "y") {
  info("Cancelled by user.")
  quit(save = "no", status = 0)
}

cat("\n")

# Run each study
overall_start <- Sys.time()
results_summary <- list()

for (i in seq_along(studies)) {
  study <- studies[[i]]

  heading(sprintf("Study %d/%d: %s", i, length(studies), study$name))

  info(sprintf("Script: %s", study$script))
  info(sprintf("Starting at: %s", Sys.time()))

  study_start <- Sys.time()

  # Run the script
  result <- tryCatch({
    system2("Rscript", args = study$script, stdout = TRUE, stderr = TRUE)
    status <- 0
  }, error = function(e) {
    error(sprintf("Failed: %s", e$message))
    status <- 1
  })

  study_end <- Sys.time()
  elapsed <- as.numeric(difftime(study_end, study_start, units = "mins"))

  if (status == 0) {
    success(sprintf("Completed in %.1f minutes", elapsed))
    results_summary[[study$name]] <- list(
      status = "success",
      time = elapsed
    )
  } else {
    error(sprintf("Failed after %.1f minutes", elapsed))
    results_summary[[study$name]] <- list(
      status = "failed",
      time = elapsed
    )
  }

  cat("\n")
}

overall_end <- Sys.time()
total_elapsed <- as.numeric(difftime(overall_end, overall_start, units = "mins"))

heading("ALL SIMULATIONS COMPLETE")

cat("Summary:\n\n")
for (name in names(results_summary)) {
  result <- results_summary[[name]]
  if (result$status == "success") {
    success(sprintf("%-40s %.1f min", name, result$time))
  } else {
    error(sprintf("%-40s %.1f min (FAILED)", name, result$time))
  }
}

cat("\n")
info(sprintf("Total time: %.1f minutes (%.1f hours)",
             total_elapsed, total_elapsed / 60))

n_success <- sum(sapply(results_summary, function(x) x$status == "success"))
n_total <- length(results_summary)

if (n_success == n_total) {
  success(sprintf("All %d studies completed successfully!", n_total))
} else {
  error(sprintf("%d/%d studies completed successfully", n_success, n_total))
}

cat("\n")
info("Results saved to: sims/results/")
info("Check individual study outputs for detailed results")

cat("\n")
