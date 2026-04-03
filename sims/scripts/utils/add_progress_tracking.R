#' Progress Tracking Utilities for Simulation Studies
#'
#' Provides functions to track and report progress during long-running simulations.

library(glue)

#' Initialize progress tracking
#'
#' @param study_name Name of the study (e.g., "study1", "study2")
#' @param progress_file Path to progress file (auto-generated if NULL)
#' @return Path to progress file
#' @export
init_progress <- function(study_name, progress_file = NULL) {
  if (is.null(progress_file)) {
    progress_file <- glue("sims/results/{study_name}_progress.txt")
  }

  start_msg <- glue("{study_name} started at {Sys.time()}")
  writeLines(start_msg, progress_file)
  cat(start_msg, "\n")

  return(progress_file)
}

#' Track progress during simulation
#'
#' @param rep_id Current replication number
#' @param N_REPS Total replications
#' @param context_info Contextual information (scenario, parameters, etc.)
#' @param progress_file Path to progress file
#' @param every Report every N replications (default: 50)
#' @export
track_progress <- function(rep_id, N_REPS, context_info,
                          progress_file, every = 50) {
  if (rep_id %% every == 0) {
    pct <- round(100 * rep_id / N_REPS, 1)
    elapsed <- format(Sys.time(), "%H:%M:%S")
    msg <- glue("[{elapsed}] {context_info} | Rep {rep_id}/{N_REPS} ({pct}%)")
    cat(msg, "\n")
    write(as.character(msg), progress_file, append = TRUE)
  }
}

#' Finalize progress tracking
#'
#' @param progress_file Path to progress file
#' @param n_total Total number of replications completed
#' @export
finalize_progress <- function(progress_file, n_total) {
  end_msg <- glue("Completed {n_total} replications at {Sys.time()}")
  cat(end_msg, "\n")
  write(as.character(end_msg), progress_file, append = TRUE)
}

#' Estimate time remaining
#'
#' @param current Current replication number
#' @param total Total replications
#' @param start_time Start time (from Sys.time())
#' @return String with time remaining estimate
#' @export
estimate_remaining <- function(current, total, start_time) {
  if (current == 0) return("Calculating...")

  elapsed_sec <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  rate <- current / elapsed_sec
  remaining_sec <- (total - current) / rate

  hours <- floor(remaining_sec / 3600)
  mins <- floor((remaining_sec %% 3600) / 60)

  if (hours > 0) {
    return(glue("{hours}h {mins}m remaining"))
  } else {
    return(glue("{mins}m remaining"))
  }
}

#' Monitor worker processes
#'
#' @return Data frame with worker information
#' @export
monitor_workers <- function() {
  # Get R worker processes
  cmd <- "ps aux | grep 'parallelly.parent' | grep -v grep"
  result <- try(system(cmd, intern = TRUE), silent = TRUE)

  if (inherits(result, "try-error") || length(result) == 0) {
    return(data.frame(n_workers = 0, total_cpu = 0, total_mem = 0))
  }

  # Parse output
  workers <- strsplit(result, "\\s+")
  cpu <- sapply(workers, function(x) as.numeric(x[3]))
  mem <- sapply(workers, function(x) as.numeric(x[6]))

  data.frame(
    n_workers = length(result),
    total_cpu = sum(cpu),
    total_mem_mb = sum(mem) / 1024,
    avg_cpu = mean(cpu),
    avg_mem_mb = mean(mem) / 1024
  )
}
