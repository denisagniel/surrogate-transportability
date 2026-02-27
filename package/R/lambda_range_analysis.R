#' Analyze surrogate functionals across different λ ranges
#'
#' Evaluates how surrogate functionals change when λ is constrained to different ranges.
#' This helps understand how the level of innovation affects surrogate quality assessment.
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
#' @return A list with elements:
#'   \item{lambda_range_results}{Results for each λ range}
#'   \item{summary_table}{Summary table comparing functionals across ranges}
#'   \item{parameters}{Parameters used in the analysis}
#'
#' @details
#' This function constrains λ to specific ranges and evaluates how the surrogate
#' functionals change. For example:
#' - λ ∈ [0, 0.1]: Future studies very similar to current study
#' - λ ∈ [0, 0.5]: Moderate innovation allowed
#' - λ ∈ [0, 1.0]: Full range of innovation allowed
#'
#' This helps answer: "How does surrogate quality assessment change as we allow
#' more or less innovation in future studies?"
#'
#' @examples
#' # Generate data
#' current_data <- generate_study_data(n = 500)
#'
#' # Analyze across λ ranges
#' lambda_analysis <- analyze_lambda_ranges(
#'   current_data,
#'   lambda_ranges = list(
#'     list(min = 0, max = 0.1),
#'     list(min = 0, max = 0.5),
#'     list(min = 0, max = 1.0)
#'   )
#' )
#'
#' # View summary
#' print(lambda_analysis$summary_table)
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
  
  if (!is.null(seed)) set.seed(seed)
  
  functional_type <- match.arg(functional_type)
  study_type <- match.arg(study_type)
  
  n <- nrow(current_data)
  
  # Initialize storage
  lambda_range_results <- list()
  summary_data <- list()
  
  # Analyze each λ range
  for (i in seq_along(lambda_ranges)) {
    range_i <- lambda_ranges[[i]]
    range_name <- paste0("λ ∈ [", range_i$min, ", ", range_i$max, "]")
    
    cat("Analyzing", range_name, "...\n")
    
    # Create constrained λ parameters
    # We'll use rejection sampling to ensure λ stays within bounds
    constrained_lambda_params <- list(
      min = range_i$min,
      max = range_i$max,
      a = 2,  # Will be adjusted based on range
      b = 5
    )
    
    # Adjust Beta parameters to center on the range
    range_center <- (range_i$min + range_i$max) / 2
    range_width <- range_i$max - range_i$min
    
    # Use truncated Beta distribution
    constrained_lambda_params$a <- 2 * (range_center / range_width)
    constrained_lambda_params$b <- 2 * ((1 - range_center) / range_width)
    
    # Run posterior inference with constrained λ
    result <- posterior_inference_constrained_lambda(
      current_data = current_data,
      n_draws_from_F = n_draws_from_F,
      n_future_studies_per_draw = n_future_studies_per_draw,
      lambda_params = constrained_lambda_params,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates
    )
    
    # Store results
    lambda_range_results[[range_name]] <- result
    
    # Extract summary statistics
    if (functional_type == "all") {
      summary_data[[i]] <- tibble::tibble(
        lambda_range = range_name,
        lambda_min = range_i$min,
        lambda_max = range_i$max,
        correlation_mean = result$summary$correlation$mean,
        correlation_sd = result$summary$correlation$sd,
        correlation_q025 = result$summary$correlation$q025,
        correlation_q975 = result$summary$correlation$q975,
        probability_mean = result$summary$probability$mean,
        probability_sd = result$summary$probability$sd,
        probability_q025 = result$summary$probability$q025,
        probability_q975 = result$summary$probability$q975
      )
    } else {
      summary_data[[i]] <- tibble::tibble(
        lambda_range = range_name,
        lambda_min = range_i$min,
        lambda_max = range_i$max,
        functional_mean = result$summary$mean,
        functional_sd = result$summary$sd,
        functional_q025 = result$summary$q025,
        functional_q975 = result$summary$q975
      )
    }
  }
  
  # Create summary table
  summary_table <- dplyr::bind_rows(summary_data)
  
  # Return results
  list(
    lambda_range_results = lambda_range_results,
    summary_table = summary_table,
    parameters = list(
      lambda_ranges = lambda_ranges,
      n_draws_from_F = n_draws_from_F,
      n_future_studies_per_draw = n_future_studies_per_draw,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates
    )
  )
}

#' Posterior inference with constrained λ values
#'
#' Internal function that runs posterior inference while constraining λ to a specific range.
#'
#' @param current_data A tibble with the current study data.
#' @param n_draws_from_F Integer. Number of draws from super-population F.
#' @param n_future_studies_per_draw Integer. Number of future studies per draw from F.
#' @param lambda_params List with λ constraints and Beta parameters.
#' @param functional_type Character. Type of functional to compute.
#' @param epsilon_s Numeric. Threshold for probability functional.
#' @param epsilon_y Numeric. Threshold for probability functional.
#' @param delta_s_values Numeric vector. Values for conditional mean functional.
#' @param study_type Character. Type of study for treatment effect estimation.
#' @param covariates Character vector. Covariates for adjustment.
#'
#' @return List with posterior inference results.
#'
#' @keywords internal
posterior_inference_constrained_lambda <- function(current_data,
                                                 n_draws_from_F,
                                                 n_future_studies_per_draw,
                                                 lambda_params,
                                                 functional_type,
                                                 epsilon_s,
                                                 epsilon_y,
                                                 delta_s_values,
                                                 study_type,
                                                 covariates) {
  
  n <- nrow(current_data)
  
  # Compute treatment effects in current study
  current_effects <- compute_multiple_treatment_effects(
    current_data, c("S", "Y"), study_type, covariates
  )
  
  # Initialize storage for posterior samples
  if (functional_type == "all") {
    posterior_samples <- list(
      correlation = numeric(n_draws_from_F),
      probability = numeric(n_draws_from_F),
      conditional_means = matrix(NA, nrow = n_draws_from_F, ncol = length(delta_s_values))
    )
  } else {
    posterior_samples <- numeric(n_draws_from_F)
  }
  
  # Outer loop: draw from super-population F
  for (draw_i in 1:n_draws_from_F) {
    
    # Resample current study using Bayesian bootstrap
    outer_weights <- as.numeric(MCMCpack::rdirichlet(1, rep(1, n)))
    outer_indices <- sample(1:n, size = n, replace = TRUE, prob = outer_weights)
    resampled_current_data <- current_data[outer_indices, ]
    
    # Inner loop: generate future studies with constrained λ
    future_studies <- generate_multiple_future_studies_constrained_lambda(
      resampled_current_data,
      n_future_studies = n_future_studies_per_draw,
      lambda_params = lambda_params
    )
    
    # Extract treatment effects from future studies
    treatment_effects <- extract_treatment_effects(
      future_studies, c("S", "Y"), study_type, covariates
    )
    
    # Compute functional(s)
    if (functional_type == "all") {
      functionals <- compute_all_functionals(
        treatment_effects,
        epsilon_s = epsilon_s,
        epsilon_y = epsilon_y,
        delta_s_values = delta_s_values
      )
      posterior_samples$correlation[draw_i] <- functionals$correlation
      posterior_samples$probability[draw_i] <- functionals$probability
      posterior_samples$conditional_means[draw_i, ] <- functionals$conditional_means
    } else {
      functional_value <- switch(functional_type,
        "correlation" = functional_correlation(treatment_effects),
        "probability" = functional_probability(treatment_effects, epsilon_s, epsilon_y),
        "conditional_mean" = functional_conditional_mean(treatment_effects, delta_s_values[1])
      )
      posterior_samples[draw_i] <- functional_value
    }
  }
  
  # Compute summary statistics
  if (functional_type == "all") {
    summary_stats <- list(
      correlation = compute_summary_stats(posterior_samples$correlation),
      probability = compute_summary_stats(posterior_samples$probability),
      conditional_means = apply(posterior_samples$conditional_means, 2, compute_summary_stats)
    )
    names(summary_stats$conditional_means) <- paste0("delta_s_", delta_s_values)
  } else {
    summary_stats <- compute_summary_stats(posterior_samples)
  }
  
  # Return results
  list(
    functionals = posterior_samples,
    summary = summary_stats,
    current_effects = current_effects,
    parameters = list(
      n_draws_from_F = n_draws_from_F,
      n_future_studies_per_draw = n_future_studies_per_draw,
      lambda_params = lambda_params,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates
    )
  )
}

#' Generate multiple future studies with constrained λ
#'
#' Internal function that generates future studies while constraining λ to a specific range.
#'
#' @param current_data A tibble with the current study data.
#' @param n_future_studies Integer. Number of future studies to generate.
#' @param lambda_params List with λ constraints.
#'
#' @return List of future study results.
#'
#' @keywords internal
generate_multiple_future_studies_constrained_lambda <- function(current_data,
                                                              n_future_studies,
                                                              lambda_params) {
  
  future_studies <- list()
  
  for (i in 1:n_future_studies) {
    # Sample λ from constrained range
    lambda <- sample_constrained_lambda(lambda_params)
    
    # Generate innovation weights
    n <- nrow(current_data)
    innovation_weights <- as.numeric(MCMCpack::rdirichlet(1, rep(1, n)))
    
    # Current study weights
    p0_weights <- rep(1/n, n)
    
    # Mixture weights: Q = (1-λ)P₀ + λP̃
    mixture_weights <- (1 - lambda) * p0_weights + lambda * innovation_weights
    
    # Sample future study
    future_indices <- sample(1:n, size = n, replace = TRUE, prob = mixture_weights)
    future_data <- current_data[future_indices, ]
    
    future_studies[[i]] <- list(
      lambda = lambda,
      future_data = future_data,
      innovation_weights = innovation_weights,
      mixture_weights = mixture_weights
    )
  }
  
  future_studies
}

#' Sample λ from constrained range
#'
#' Internal function to sample λ from a constrained range using rejection sampling.
#'
#' @param lambda_params List with λ constraints.
#'
#' @return Numeric λ value within the specified range.
#'
#' @keywords internal
sample_constrained_lambda <- function(lambda_params) {
  
  lambda_min <- lambda_params$min
  lambda_max <- lambda_params$max
  
  # Use rejection sampling to ensure λ stays within bounds
  max_attempts <- 1000
  
  for (attempt in 1:max_attempts) {
    # Sample from Beta distribution
    lambda_candidate <- rbeta(1, lambda_params$a, lambda_params$b)
    
    # Check if within bounds
    if (lambda_candidate >= lambda_min && lambda_candidate <= lambda_max) {
      return(lambda_candidate)
    }
  }
  
  # If rejection sampling fails, use uniform sampling within range
  warning("Rejection sampling failed, using uniform sampling within range")
  runif(1, lambda_min, lambda_max)
}

#' Plot λ range analysis results
#'
#' Creates visualizations of how functionals change across different λ ranges.
#'
#' @param lambda_analysis List. Results from analyze_lambda_ranges().
#' @param functional Character. Which functional to plot: "correlation" or "probability".
#'
#' @return A ggplot2 object.
#'
#' @examples
#' # Run analysis
#' lambda_analysis <- analyze_lambda_ranges(current_data)
#'
#' # Plot correlation functional
#' plot_lambda_range_analysis(lambda_analysis, "correlation")
#'
#' @export
plot_lambda_range_analysis <- function(lambda_analysis, functional = c("correlation", "probability")) {
  
  functional <- match.arg(functional)
  
  if (functional == "correlation") {
    plot_data <- lambda_analysis$summary_table %>%
      dplyr::select(lambda_range, lambda_max, correlation_mean, correlation_q025, correlation_q975)
    
    p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = lambda_max, y = correlation_mean)) +
      ggplot2::geom_point(size = 3) +
      ggplot2::geom_line() +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = correlation_q025, ymax = correlation_q975), width = 0.02) +
      ggplot2::labs(
        title = "Correlation Functional Across λ Ranges",
        subtitle = "How surrogate quality assessment changes with innovation level",
        x = "Maximum λ (Innovation Level)",
        y = "Correlation between ΔS and ΔY"
      ) +
      ggplot2::theme_minimal()
    
  } else {
    plot_data <- lambda_analysis$summary_table %>%
      dplyr::select(lambda_range, lambda_max, probability_mean, probability_q025, probability_q975)
    
    p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = lambda_max, y = probability_mean)) +
      ggplot2::geom_point(size = 3) +
      ggplot2::geom_line() +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = probability_q025, ymax = probability_q975), width = 0.02) +
      ggplot2::labs(
        title = "Probability Functional Across λ Ranges",
        subtitle = "P(ΔY > εY | ΔS > εS) as innovation level increases",
        x = "Maximum λ (Innovation Level)",
        y = "Probability Functional"
      ) +
      ggplot2::theme_minimal()
  }
  
  p
}


