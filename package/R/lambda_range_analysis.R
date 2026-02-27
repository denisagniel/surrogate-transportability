#' Analyze surrogate functionals across different λ ranges (DEPRECATED)
#'
#' @description
#' **This function is deprecated.** Use \code{\link{grid_search_lambda}} instead,
#' which implements the fixed-lambda framework from the revised methods paper.
#'
#' The old approach sampled λ randomly from constrained Beta distributions,
#' which is inconsistent with the current paper's theoretical framework that
#' treats λ as a fixed design parameter. The new \code{grid_search_lambda}
#' evaluates phi(F_lambda) at fixed lambda values and finds the threshold λ*.
#'
#' @param current_data A tibble with the current study data.
#' @param lambda_ranges List of λ ranges to analyze. Each element should be a list
#'   with 'min' and 'max' values. Default: c(0, 0.1), c(0, 0.3), c(0, 0.5), c(0, 0.8), c(0, 1.0).
#' @param n_draws_from_F Integer. Number of draws from super-population F.
#' @param n_future_studies_per_draw Integer. Number of future studies per draw from F.
#' @param functional_type Character. Type of functional to compute.
#' @param epsilon_s Numeric. Threshold for probability functional.
#' @param epsilon_y Numeric. Threshold for probability functional.
#' @param delta_s_values Numeric vector. Values for conditional mean functional.
#' @param study_type Character. Type of study for treatment effect estimation.
#' @param covariates Character vector. Covariates for adjustment.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A list similar to the output of \code{grid_search_lambda} for backward compatibility.
#'
#' @details
#' This function is maintained for backward compatibility but is deprecated.
#' It converts the old lambda_ranges specification into a lambda_grid and
#' calls \code{grid_search_lambda}.
#'
#' **Migration guide:**
#' ```r
#' # OLD CODE (deprecated):
#' result <- analyze_lambda_ranges(
#'   current_data,
#'   lambda_ranges = list(
#'     list(min = 0, max = 0.1),
#'     list(min = 0, max = 0.5)
#'   )
#' )
#'
#' # NEW CODE (recommended):
#' result <- grid_search_lambda(
#'   current_data,
#'   lambda_grid = seq(0, 0.5, by = 0.05),
#'   threshold = 0.8
#' )
#' ```
#'
#' @seealso \code{\link{grid_search_lambda}} for the recommended approach
#'
#' @export
analyze_lambda_ranges <- function(current_data,
                                lambda_ranges = list(
                                  list(min = 0, max = 0.1),
                                  list(min = 0, max = 0.3),
                                  list(min = 0, max = 0.5),
                                  list(min = 0, max = 0.8),
                                  list(min = 0, max = 1.0)
                                ),
                                n_draws_from_F = 200,
                                n_future_studies_per_draw = 100,
                                functional_type = c("correlation", "probability", "conditional_mean", "all"),
                                epsilon_s = 0.2,
                                epsilon_y = 0.1,
                                delta_s_values = c(0.3, 0.5, 0.7),
                                study_type = c("randomized", "observational"),
                                covariates = NULL,
                                seed = NULL) {

  # Issue deprecation warning
  .Deprecated(
    new = "grid_search_lambda",
    msg = paste(
      "\n'analyze_lambda_ranges' is deprecated and will be removed in a future version.",
      "\nUse 'grid_search_lambda' instead, which implements the fixed-lambda framework.",
      "\n",
      "\nOLD: analyze_lambda_ranges(data, lambda_ranges = list(list(min=0, max=0.5)))",
      "\nNEW: grid_search_lambda(data, lambda_grid = seq(0, 0.5, by=0.05), threshold = 0.8)",
      "\n",
      "\nSee ?grid_search_lambda for details."
    )
  )

  # Match arguments
  functional_type <- match.arg(functional_type)
  study_type <- match.arg(study_type)

  # Convert lambda_ranges to lambda_grid
  # Strategy: Sample 5 points from each range
  lambda_grid <- sort(unique(unlist(lapply(lambda_ranges, function(r) {
    seq(r$min, r$max, length.out = 5)
  }))))

  message(sprintf(
    "Converting %d lambda ranges to %d grid points: [%.3f, %.3f]",
    length(lambda_ranges),
    length(lambda_grid),
    min(lambda_grid),
    max(lambda_grid)
  ))

  # Call new grid_search_lambda function
  result <- grid_search_lambda(
    current_data = current_data,
    lambda_grid = lambda_grid,
    threshold = 0.5,  # Default threshold; user should set appropriately
    functional_type = functional_type,
    confidence_level = 0.95,
    multiplicity_adjustment = "bonferroni",
    n_draws_from_F = n_draws_from_F,
    n_future_studies_per_draw = n_future_studies_per_draw,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y,
    delta_s_values = delta_s_values,
    study_type = study_type,
    covariates = covariates,
    seed = seed,
    parallel = FALSE
  )

  # For backward compatibility, create summary_table in old format
  summary_table <- result$phi_estimates
  names(summary_table)[names(summary_table) == "phi_hat"] <- "functional_mean"
  names(summary_table)[names(summary_table) == "lower_ci"] <- "functional_q025"
  names(summary_table)[names(summary_table) == "upper_ci"] <- "functional_q975"
  names(summary_table)[names(summary_table) == "se"] <- "functional_sd"

  # Return in format similar to old analyze_lambda_ranges
  list(
    lambda_range_results = result,  # Just include the full grid search result
    summary_table = summary_table,
    parameters = list(
      lambda_grid = lambda_grid,  # Note: changed from lambda_ranges
      n_draws_from_F = n_draws_from_F,
      n_future_studies_per_draw = n_future_studies_per_draw,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates,
      note = "This function is deprecated. Use grid_search_lambda() instead."
    )
  )
}


#' Plot λ range analysis results
#'
#' Creates visualizations of how functionals change across different λ values.
#'
#' @param lambda_analysis List. Results from \code{analyze_lambda_ranges()} or
#'   a \code{grid_search_result} object from \code{grid_search_lambda()}.
#' @param functional Character. Which functional to plot: "correlation" or "probability".
#'   Only used if lambda_analysis is from old analyze_lambda_ranges().
#'
#' @return A ggplot2 object.
#'
#' @details
#' This function works with both old \code{analyze_lambda_ranges()} results and
#' new \code{grid_search_lambda()} results. For new code, prefer using
#' \code{plot(grid_search_result)} directly.
#'
#' @examples
#' # NEW approach (recommended):
#' result <- grid_search_lambda(current_data, lambda_grid = seq(0.1, 0.5, 0.1))
#' plot(result)  # Uses plot.grid_search_result method
#'
#' # OLD approach (deprecated but still works):
#' lambda_analysis <- analyze_lambda_ranges(current_data)
#' plot_lambda_range_analysis(lambda_analysis, "correlation")
#'
#' @export
plot_lambda_range_analysis <- function(lambda_analysis, functional = c("correlation", "probability")) {

  # Check if this is a grid_search_result object
  if (inherits(lambda_analysis, "grid_search_result")) {
    message("Using plot.grid_search_result method (recommended)")
    return(plot.grid_search_result(lambda_analysis))
  }

  functional <- match.arg(functional)

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting. Please install it.")
  }

  # Handle old format from deprecated analyze_lambda_ranges
  if ("summary_table" %in% names(lambda_analysis)) {
    plot_data <- lambda_analysis$summary_table

    # Try to detect which columns are present
    has_correlation <- any(grepl("correlation", names(plot_data)))
    has_probability <- any(grepl("probability", names(plot_data)))

    if (functional == "correlation" && has_correlation) {
      p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = lambda, y = correlation_mean)) +
        ggplot2::geom_point(size = 3) +
        ggplot2::geom_line() +
        ggplot2::geom_errorbar(
          ggplot2::aes(ymin = correlation_q025, ymax = correlation_q975),
          width = 0.02
        ) +
        ggplot2::labs(
          title = "Correlation Functional Across λ Values (DEPRECATED FORMAT)",
          subtitle = "Use grid_search_lambda() for current implementation",
          x = "λ (Perturbation Distance)",
          y = "Correlation between ΔS and ΔY"
        ) +
        ggplot2::theme_minimal()

    } else if (functional == "probability" && has_probability) {
      p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = lambda, y = probability_mean)) +
        ggplot2::geom_point(size = 3) +
        ggplot2::geom_line() +
        ggplot2::geom_errorbar(
          ggplot2::aes(ymin = probability_q025, ymax = probability_q975),
          width = 0.02
        ) +
        ggplot2::labs(
          title = "Probability Functional Across λ Values (DEPRECATED FORMAT)",
          subtitle = "Use grid_search_lambda() for current implementation",
          x = "λ (Perturbation Distance)",
          y = "Probability Functional"
        ) +
        ggplot2::theme_minimal()

    } else {
      # Generic plot for functional_mean if no specific functional columns
      p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = lambda, y = functional_mean)) +
        ggplot2::geom_point(size = 3) +
        ggplot2::geom_line() +
        ggplot2::geom_errorbar(
          ggplot2::aes(ymin = functional_q025, ymax = functional_q975),
          width = 0.02
        ) +
        ggplot2::labs(
          title = "Functional Across λ Values (DEPRECATED FORMAT)",
          subtitle = "Use grid_search_lambda() for current implementation",
          x = "λ (Perturbation Distance)",
          y = "Functional Value"
        ) +
        ggplot2::theme_minimal()
    }

    return(p)
  }

  stop("Unrecognized lambda_analysis format. Use grid_search_lambda() for current implementation.")
}
