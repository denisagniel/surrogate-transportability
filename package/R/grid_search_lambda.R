#' Grid Search for Lambda Threshold
#'
#' Evaluates phi(F_lambda) over a grid of lambda values to find the largest
#' lambda* where phi(F_lambda*) >= threshold. Implements Section 4 of the
#' methods paper: grid search with multiple testing adjustments.
#'
#' @param current_data A tibble or data.frame with the current study data.
#'   Must contain columns: A (treatment), S (surrogate), Y (outcome).
#' @param lambda_grid Numeric vector of lambda values to evaluate. Each value
#'   must be in [0,1]. Example: seq(0.05, 0.5, by = 0.05).
#' @param threshold Numeric. Minimum acceptable value of phi for surrogate
#'   quality. For correlation functional, typical values are 0.7-0.9.
#'   For probability functional, values depend on epsilon_s and epsilon_y.
#'   Default: 0.8.
#' @param functional_type Character. Type of functional to compute:
#'   "correlation", "probability", or "conditional_mean".
#' @param confidence_level Numeric in (0,1). Confidence level for intervals.
#'   Default: 0.95 for 95% confidence intervals.
#' @param multiplicity_adjustment Character. Method for multiple testing correction:
#'   \itemize{
#'     \item "none" - No adjustment (not recommended)
#'     \item "bonferroni" - Bonferroni correction (conservative)
#'     \item "sidak" - Šidák correction (slightly less conservative)
#'   }
#'   Default: "bonferroni".
#' @param n_draws_from_F Integer. Number of outer bootstrap samples for
#'   estimating phi. Larger values give more stable estimates but increase
#'   computation time. Default: 500.
#' @param n_future_studies_per_draw Integer. Number of future studies to
#'   generate per outer draw. Default: 200.
#' @param innovation_type Character. Type of innovation distribution:
#'   "bayesian_bootstrap" (default) or "dirichlet_process".
#' @param epsilon_s Numeric. Threshold for probability functional (if used).
#' @param epsilon_y Numeric. Threshold for probability functional (if used).
#' @param delta_s_values Numeric vector. Values for conditional mean functional (if used).
#' @param study_type Character. Type of study for treatment effect estimation.
#' @param covariates Character vector. Covariates for adjustment.
#' @param seed Integer. Random seed for reproducibility.
#' @param parallel Logical. Whether to use parallel processing across lambda values.
#'   Default: FALSE.
#'
#' @return A list of class "grid_search_result" with elements:
#' \describe{
#'   \item{phi_estimates}{A data.frame with columns: lambda, phi_hat, lower_ci, upper_ci, se}
#'   \item{lambda_star}{The largest lambda where lower_ci >= threshold, or NA if none found}
#'   \item{threshold}{The threshold value used}
#'   \item{confidence_level}{The confidence level used}
#'   \item{multiplicity_adjustment}{The multiplicity adjustment method used}
#'   \item{n_lambda}{The number of lambda values evaluated}
#'   \item{functional_type}{The functional type used}
#' }
#'
#' @details
#' This function implements the grid search algorithm from Section 4 of the
#' methods paper. For each lambda value in lambda_grid:
#' \enumerate{
#'   \item Call posterior_inference() with that fixed lambda
#'   \item Compute point estimate phi_hat and confidence interval
#'   \item Apply multiplicity adjustment to confidence level
#' }
#'
#' The function finds lambda_star = max{lambda : lower_ci(lambda) >= threshold},
#' which represents the largest perturbation distance where the surrogate
#' quality is still acceptable.
#'
#' **Multiple testing adjustments:**
#' When evaluating K lambda values, the familywise error rate is controlled by:
#' - Bonferroni: Use alpha/K for each test (conservative)
#' - Šidák: Use 1-(1-alpha)^(1/K) for each test (exact under independence)
#' - None: Use alpha for each test (not recommended, inflates Type I error)
#'
#' @seealso \code{\link{posterior_inference}} for single-lambda inference
#' @seealso \code{\link{plot.grid_search_result}} for visualizing results
#'
#' @examples
#' # Generate example data
#' set.seed(123)
#' current_data <- data.frame(
#'   A = rep(0:1, each = 250),
#'   S = rnorm(500),
#'   Y = rnorm(500)
#' )
#'
#' # Run grid search with correlation functional
#' result <- grid_search_lambda(
#'   current_data = current_data,
#'   lambda_grid = seq(0.1, 0.5, by = 0.1),
#'   threshold = 0.8,
#'   functional_type = "correlation",
#'   n_draws_from_F = 100,
#'   n_future_studies_per_draw = 50,
#'   seed = 123
#' )
#'
#' # View results
#' print(result)
#' print(result$lambda_star)
#' print(result$phi_estimates)
#'
#' # Plot results
#' plot(result)
#'
#' @export
grid_search_lambda <- function(
  current_data,
  lambda_grid,
  threshold = 0.8,
  functional_type = c("correlation", "probability", "conditional_mean"),
  confidence_level = 0.95,
  multiplicity_adjustment = c("bonferroni", "sidak", "none"),
  n_draws_from_F = 500,
  n_future_studies_per_draw = 200,
  innovation_type = c("bayesian_bootstrap", "dirichlet_process"),
  epsilon_s = 0.2,
  epsilon_y = 0.1,
  delta_s_values = c(0.3, 0.5, 0.7),
  study_type = c("randomized", "observational"),
  covariates = NULL,
  seed = NULL,
  parallel = FALSE
) {

  # Match arguments
  functional_type <- match.arg(functional_type)
  multiplicity_adjustment <- match.arg(multiplicity_adjustment)
  innovation_type <- match.arg(innovation_type)
  study_type <- match.arg(study_type)

  # Validate inputs
  if (!is.numeric(lambda_grid) || any(lambda_grid < 0) || any(lambda_grid > 1)) {
    stop("lambda_grid must contain numeric values in [0, 1]")
  }

  if (!is.numeric(threshold) || length(threshold) != 1) {
    stop("threshold must be a single numeric value")
  }

  if (!is.numeric(confidence_level) || confidence_level <= 0 || confidence_level >= 1) {
    stop("confidence_level must be in (0, 1)")
  }

  if (!is.null(seed)) set.seed(seed)

  # Sort lambda_grid for easier interpretation
  lambda_grid <- sort(lambda_grid)
  K <- length(lambda_grid)

  # Compute adjusted alpha level for confidence intervals
  alpha <- 1 - confidence_level
  adjusted_alpha <- switch(multiplicity_adjustment,
    "bonferroni" = alpha / K,
    "sidak" = 1 - (1 - alpha)^(1/K),
    "none" = alpha
  )
  adjusted_confidence_level <- 1 - adjusted_alpha

  # Progress message
  message(sprintf(
    "Running grid search over %d lambda values with %s adjustment",
    K, multiplicity_adjustment
  ))
  message(sprintf(
    "Adjusted confidence level: %.3f (alpha = %.4f)",
    adjusted_confidence_level, adjusted_alpha
  ))

  # Evaluate phi at each lambda value
  if (parallel && requireNamespace("future", quietly = TRUE)) {
    # Parallel implementation
    future::plan(future::multisession)

    results <- future::future_lapply(
      lambda_grid,
      function(lambda_val) {
        estimate_phi_at_lambda(
          current_data = current_data,
          lambda = lambda_val,
          functional_type = functional_type,
          confidence_level = adjusted_confidence_level,
          n_draws_from_F = n_draws_from_F,
          n_future_studies_per_draw = n_future_studies_per_draw,
          innovation_type = innovation_type,
          epsilon_s = epsilon_s,
          epsilon_y = epsilon_y,
          delta_s_values = delta_s_values,
          study_type = study_type,
          covariates = covariates
        )
      },
      future.seed = TRUE
    )

    future::plan(future::sequential)

  } else {
    # Sequential implementation with progress
    results <- vector("list", K)

    for (i in seq_along(lambda_grid)) {
      lambda_val <- lambda_grid[i]

      if (i == 1 || i %% 5 == 0 || i == K) {
        message(sprintf("  Evaluating lambda = %.3f (%d/%d)", lambda_val, i, K))
      }

      results[[i]] <- estimate_phi_at_lambda(
        current_data = current_data,
        lambda = lambda_val,
        functional_type = functional_type,
        confidence_level = adjusted_confidence_level,
        n_draws_from_F = n_draws_from_F,
        n_future_studies_per_draw = n_future_studies_per_draw,
        innovation_type = innovation_type,
        epsilon_s = epsilon_s,
        epsilon_y = epsilon_y,
        delta_s_values = delta_s_values,
        study_type = study_type,
        covariates = covariates
      )
    }
  }

  # Combine results into data frame
  phi_estimates <- do.call(rbind, lapply(results, as.data.frame))

  # Find lambda_star: largest lambda where lower_ci >= threshold
  above_threshold <- phi_estimates$lower_ci >= threshold & !is.na(phi_estimates$lower_ci)

  if (any(above_threshold)) {
    lambda_star <- max(phi_estimates$lambda[above_threshold])
    message(sprintf(
      "\nLambda* found: %.3f (largest lambda with lower_ci >= %.3f)",
      lambda_star, threshold
    ))
  } else {
    lambda_star <- NA_real_
    warning(sprintf(
      "No lambda value meets the threshold criterion (lower_ci >= %.3f)",
      threshold
    ))
  }

  # Return structured result
  result <- structure(
    list(
      phi_estimates = phi_estimates,
      lambda_star = lambda_star,
      threshold = threshold,
      confidence_level = confidence_level,
      adjusted_confidence_level = adjusted_confidence_level,
      multiplicity_adjustment = multiplicity_adjustment,
      n_lambda = K,
      functional_type = functional_type
    ),
    class = c("grid_search_result", "list")
  )

  result
}


#' Estimate phi at a single lambda value
#'
#' Internal helper function that estimates phi(F_lambda) for a single lambda.
#'
#' @inheritParams grid_search_lambda
#' @param lambda Numeric. Single lambda value to evaluate.
#' @param confidence_level Numeric. Confidence level for this lambda (may be adjusted).
#'
#' @return A list with: lambda, phi_hat, lower_ci, upper_ci, se
#'
#' @keywords internal
estimate_phi_at_lambda <- function(
  current_data,
  lambda,
  functional_type,
  confidence_level,
  n_draws_from_F,
  n_future_studies_per_draw,
  innovation_type,
  epsilon_s,
  epsilon_y,
  delta_s_values,
  study_type,
  covariates
) {

  # Call posterior_inference with fixed lambda
  post_result <- posterior_inference(
    current_data = current_data,
    n_draws_from_F = n_draws_from_F,
    n_future_studies_per_draw = n_future_studies_per_draw,
    lambda = lambda,
    innovation_type = innovation_type,
    functional_type = functional_type,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y,
    delta_s_values = delta_s_values,
    study_type = study_type,
    covariates = covariates,
    seed = NULL
  )

  # Extract posterior samples
  samples <- post_result$functionals

  # Remove NA values
  samples <- samples[!is.na(samples)]

  if (length(samples) == 0) {
    return(list(
      lambda = lambda,
      phi_hat = NA_real_,
      lower_ci = NA_real_,
      upper_ci = NA_real_,
      se = NA_real_
    ))
  }

  # Compute point estimate and confidence interval
  phi_hat <- mean(samples)
  se <- sd(samples)

  # Quantiles for confidence interval
  alpha <- 1 - confidence_level
  lower_ci <- quantile(samples, alpha/2, names = FALSE)
  upper_ci <- quantile(samples, 1 - alpha/2, names = FALSE)

  list(
    lambda = lambda,
    phi_hat = phi_hat,
    lower_ci = lower_ci,
    upper_ci = upper_ci,
    se = se
  )
}


#' Print method for grid search results
#'
#' @param x A grid_search_result object
#' @param ... Additional arguments (not used)
#'
#' @return Invisibly returns x
#' @export
print.grid_search_result <- function(x, ...) {
  cat("Grid Search Results for Lambda Threshold\n")
  cat(sprintf("=========================================\n\n"))
  cat(sprintf("Functional type: %s\n", x$functional_type))
  cat(sprintf("Number of lambda values: %d\n", x$n_lambda))
  cat(sprintf("Lambda range: [%.3f, %.3f]\n",
              min(x$phi_estimates$lambda),
              max(x$phi_estimates$lambda)))
  cat(sprintf("Threshold: %.3f\n", x$threshold))
  cat(sprintf("Confidence level: %.3f (adjusted: %.3f, %s)\n",
              x$confidence_level,
              x$adjusted_confidence_level,
              x$multiplicity_adjustment))
  cat(sprintf("\nLambda*: %s\n",
              if (is.na(x$lambda_star)) "None found" else sprintf("%.3f", x$lambda_star)))
  cat("\nPhi estimates:\n")
  print(x$phi_estimates, digits = 3, row.names = FALSE)

  invisible(x)
}


#' Plot method for grid search results
#'
#' Creates a visualization of phi(F_lambda) across the lambda grid with
#' confidence intervals and threshold line.
#'
#' @param x A grid_search_result object
#' @param ... Additional arguments (not used)
#'
#' @return A ggplot2 object
#' @export
plot.grid_search_result <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for plotting. Please install it.")
  }

  df <- x$phi_estimates

  p <- ggplot2::ggplot(df, ggplot2::aes(x = lambda, y = phi_hat)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lower_ci, ymax = upper_ci),
      alpha = 0.2,
      fill = "steelblue"
    ) +
    ggplot2::geom_line(color = "steelblue", linewidth = 1) +
    ggplot2::geom_point(color = "steelblue", size = 2) +
    ggplot2::geom_hline(
      yintercept = x$threshold,
      linetype = "dashed",
      color = "red",
      linewidth = 0.8
    ) +
    ggplot2::labs(
      title = sprintf("Grid Search: %s Functional",
                      tools::toTitleCase(x$functional_type)),
      subtitle = sprintf(
        "Lambda* = %s (threshold = %.3f, %d%% CI with %s adjustment)",
        if (is.na(x$lambda_star)) "None" else sprintf("%.3f", x$lambda_star),
        x$threshold,
        round(x$adjusted_confidence_level * 100),
        x$multiplicity_adjustment
      ),
      x = expression(lambda ~ "(Perturbation Distance)"),
      y = expression(hat(phi)(F[lambda]))
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(color = "gray30")
    )

  # Add vertical line for lambda_star if found
  if (!is.na(x$lambda_star)) {
    p <- p + ggplot2::geom_vline(
      xintercept = x$lambda_star,
      linetype = "dotted",
      color = "darkgreen",
      linewidth = 0.8
    )
  }

  p
}
