#' Main inference function for surrogate transportability
#'
#' Implements the nested Bayesian bootstrap approach for inference about
#' surrogate functionals across future studies. This is the main function
#' for applying the innovation approach to surrogate evaluation.
#'
#' @param current_data A tibble with the current study data.
#' @param n_draws_from_F Integer. Number of draws from super-population F (resampling P₀).
#' @param n_future_studies_per_draw Integer. Number of future studies Q generated per draw from F.
#' @param n_baseline_resamples Integer. Number of times to resample baseline for proper CI.
#'   When n_baseline_resamples > 1, implements nested bootstrap for valid inference.
#'   Default: 1 (single baseline, quantiles only).
#' @param lambda Numeric value in [0,1] controlling the perturbation distance from P₀.
#'   When λ = 0, future studies equal current study.
#'   When λ = 1, future studies are purely from innovation distribution.
#'   Default: 0.3 for moderate perturbation.
#' @param innovation_type Character. Type of innovation distribution.
#' @param functional_type Character. Type of functional to compute.
#' @param epsilon_s Numeric. Threshold for probability functional.
#' @param epsilon_y Numeric. Threshold for probability functional.
#' @param delta_s_values Numeric vector. Values for conditional mean functional.
#' @param study_type Character. Type of study for treatment effect estimation.
#' @param covariates Character vector. Covariates for adjustment.
#' @param seed Integer. Random seed for reproducibility.
#' @param parallel Logical. Whether to use parallel processing.
#'
#' @return A list with elements:
#'   \item{functionals}{Posterior samples of the functional}
#'   \item{summary}{Summary statistics (mean, quantiles)}
#'   \item{current_effects}{Treatment effects in current study}
#'   \item{parameters}{Parameters used in the analysis}
#'
#' @details
#' This function implements the nested Bayesian bootstrap:
#' 1. Outer loop: Resample the current study P₀ using Bayesian bootstrap
#' 2. Inner loop: Generate future studies from each resampled P₀
#' 3. Compute functionals for each set of future studies
#' 4. Aggregate results to get posterior distribution of functionals
#'
#' @examples
#' # Generate current study data
#' current_data <- generate_study_data(n = 500)
#'
#' # Run inference for correlation functional with moderate perturbation
#' result <- posterior_inference(
#'   current_data,
#'   n_draws_from_F = 100,
#'   n_future_studies_per_draw = 50,
#'   lambda = 0.3,
#'   functional_type = "correlation"
#' )
#'
#' # Run inference for probability functional with high perturbation
#' result_prob <- posterior_inference(
#'   current_data,
#'   n_draws_from_F = 100,
#'   n_future_studies_per_draw = 50,
#'   lambda = 0.5,
#'   functional_type = "probability",
#'   epsilon_s = 0.2,
#'   epsilon_y = 0.1
#' )
#'
#' @export
posterior_inference <- function(current_data,
                              n_draws_from_F = 500,
                              n_future_studies_per_draw = 200,
                              n_baseline_resamples = 1,
                              lambda = 0.3,
                              innovation_type = c("bayesian_bootstrap", "dirichlet_process"),
                              functional_type = c("correlation", "probability", "conditional_mean", "all"),
                              epsilon_s = 0.2,
                              epsilon_y = 0.1,
                              delta_s_values = c(0.3, 0.5, 0.7),
                              study_type = c("randomized", "observational"),
                              covariates = NULL,
                              seed = NULL,
                              parallel = FALSE) {
  
  if (!is.null(seed)) set.seed(seed)

  innovation_type <- match.arg(innovation_type)
  functional_type <- match.arg(functional_type)
  study_type <- match.arg(study_type)

  n <- nrow(current_data)

  # If n_baseline_resamples > 1, implement proper nested bootstrap
  if (n_baseline_resamples > 1) {
    return(posterior_inference_nested(
      current_data = current_data,
      n_draws_from_F = n_draws_from_F,
      n_future_studies_per_draw = n_future_studies_per_draw,
      n_baseline_resamples = n_baseline_resamples,
      lambda = lambda,
      innovation_type = innovation_type,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates,
      parallel = parallel
    ))
  }
  
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
  
  # Outer loop: draw from super-population F (resample current study P₀)
  for (draw_i in 1:n_draws_from_F) {
    
    # Resample current study using Bayesian bootstrap
    outer_weights <- as.numeric(MCMCpack::rdirichlet(1, rep(1, n)))
    outer_indices <- sample(1:n, size = n, replace = TRUE, prob = outer_weights)
    resampled_current_data <- current_data[outer_indices, ]
    
    # Inner loop: generate future studies Q from this draw of P₀
    future_studies <- generate_multiple_future_studies(
      resampled_current_data,
      n_future_studies = n_future_studies_per_draw,
      lambda = lambda,
      innovation_type = innovation_type,
      seed = NULL
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
      n_baseline_resamples = n_baseline_resamples,
      lambda = lambda,
      innovation_type = innovation_type,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates
    )
  )
}

#' Nested bootstrap for proper confidence intervals
#'
#' Implements proper nested bootstrap to separate uncertainty in baseline P0
#' from variability across future studies Q ~ F_lambda.
#'
#' @inheritParams posterior_inference
#' @keywords internal
posterior_inference_nested <- function(current_data,
                                      n_draws_from_F,
                                      n_future_studies_per_draw,
                                      n_baseline_resamples,
                                      lambda,
                                      innovation_type,
                                      functional_type,
                                      epsilon_s,
                                      epsilon_y,
                                      delta_s_values,
                                      study_type,
                                      covariates,
                                      parallel) {

  n <- nrow(current_data)

  # Compute treatment effects in current study (original data)
  current_effects <- compute_multiple_treatment_effects(
    current_data, c("S", "Y"), study_type, covariates
  )

  # Storage for nested bootstrap results
  if (functional_type == "all") {
    mean_estimates <- list(
      correlation = numeric(n_baseline_resamples),
      probability = numeric(n_baseline_resamples),
      conditional_means = matrix(NA, nrow = n_baseline_resamples, ncol = length(delta_s_values))
    )
    all_samples <- list(
      correlation = numeric(n_baseline_resamples * n_draws_from_F),
      probability = numeric(n_baseline_resamples * n_draws_from_F),
      conditional_means = matrix(NA, nrow = n_baseline_resamples * n_draws_from_F, ncol = length(delta_s_values))
    )
  } else {
    mean_estimates <- numeric(n_baseline_resamples)
    all_samples <- numeric(n_baseline_resamples * n_draws_from_F)
  }

  # Outer loop: resample baseline M times
  # This is where parallelization would go
  run_one_baseline_resample <- function(m) {
    # Resample baseline once (completely new P0*)
    baseline_weights <- as.numeric(MCMCpack::rdirichlet(1, rep(1, n)))
    baseline_indices <- sample(1:n, size = n, replace = TRUE, prob = baseline_weights)
    resampled_baseline <- current_data[baseline_indices, ]

    # Run standard posterior inference on this resampled baseline
    # (with n_baseline_resamples=1 to avoid recursion)
    result <- posterior_inference(
      current_data = resampled_baseline,
      n_draws_from_F = n_draws_from_F,
      n_future_studies_per_draw = n_future_studies_per_draw,
      n_baseline_resamples = 1,  # Important: no further nesting
      lambda = lambda,
      innovation_type = innovation_type,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates,
      seed = NULL,
      parallel = FALSE
    )

    list(
      mean_estimate = result$summary$mean,
      samples = result$functionals
    )
  }

  # Run outer loop (potentially in parallel)
  if (parallel && requireNamespace("parallel", quietly = TRUE)) {
    # Detect available cores (respects Slurm allocation)
    slurm_cpus <- Sys.getenv("SLURM_CPUS_PER_TASK", unset = "")
    if (slurm_cpus != "") {
      n_cores <- as.integer(slurm_cpus)
    } else if (requireNamespace("parallelly", quietly = TRUE)) {
      n_cores <- parallelly::availableCores()
    } else {
      n_cores <- 1
    }
    cl <- parallel::makeCluster(n_cores)
    parallel::clusterEvalQ(cl, library(dplyr))
    parallel::clusterExport(cl, varlist = ls(envir = environment()), envir = environment())

    results_list <- parallel::parLapply(cl, 1:n_baseline_resamples, run_one_baseline_resample)
    parallel::stopCluster(cl)
  } else {
    results_list <- lapply(1:n_baseline_resamples, run_one_baseline_resample)
  }

  # Aggregate results
  if (functional_type == "all") {
    for (m in 1:n_baseline_resamples) {
      mean_estimates$correlation[m] <- results_list[[m]]$mean_estimate$correlation
      mean_estimates$probability[m] <- results_list[[m]]$mean_estimate$probability
      mean_estimates$conditional_means[m, ] <- results_list[[m]]$mean_estimate$conditional_means

      idx_start <- (m - 1) * n_draws_from_F + 1
      idx_end <- m * n_draws_from_F
      all_samples$correlation[idx_start:idx_end] <- results_list[[m]]$samples$correlation
      all_samples$probability[idx_start:idx_end] <- results_list[[m]]$samples$probability
      all_samples$conditional_means[idx_start:idx_end, ] <- results_list[[m]]$samples$conditional_means
    }

    summary_stats <- list(
      correlation = compute_summary_stats_nested(mean_estimates$correlation, all_samples$correlation),
      probability = compute_summary_stats_nested(mean_estimates$probability, all_samples$probability),
      conditional_means = apply(mean_estimates$conditional_means, 2, function(col_means) {
        col_idx <- which(mean_estimates$conditional_means[1,] == col_means[1])
        compute_summary_stats_nested(col_means, all_samples$conditional_means[, col_idx])
      })
    )
    names(summary_stats$conditional_means) <- paste0("delta_s_", delta_s_values)
  } else {
    for (m in 1:n_baseline_resamples) {
      mean_estimates[m] <- results_list[[m]]$mean_estimate
      idx_start <- (m - 1) * n_draws_from_F + 1
      idx_end <- m * n_draws_from_F
      all_samples[idx_start:idx_end] <- results_list[[m]]$samples
    }

    summary_stats <- compute_summary_stats_nested(mean_estimates, all_samples)
  }

  # Return results
  list(
    functionals = all_samples,
    summary = summary_stats,
    current_effects = current_effects,
    mean_estimates = mean_estimates,  # New: M estimates of E[phi]
    parameters = list(
      n_draws_from_F = n_draws_from_F,
      n_future_studies_per_draw = n_future_studies_per_draw,
      n_baseline_resamples = n_baseline_resamples,
      lambda = lambda,
      innovation_type = innovation_type,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_values = delta_s_values,
      study_type = study_type,
      covariates = covariates
    )
  )
}

#' Compute summary statistics for nested bootstrap
#'
#' Computes both CI for E[phi] and prediction interval for phi(Q).
#'
#' @param mean_estimates Numeric vector. M estimates of E[phi(F_lambda)]
#' @param all_samples Numeric vector. All M*B samples of phi(Q)
#' @keywords internal
compute_summary_stats_nested <- function(mean_estimates, all_samples) {
  # Remove NAs
  mean_estimates <- mean_estimates[!is.na(mean_estimates)]
  all_samples <- all_samples[!is.na(all_samples)]

  if (length(mean_estimates) == 0 || length(all_samples) == 0) {
    return(list(
      mean = NA_real_,
      median = NA_real_,
      sd = NA_real_,
      se = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      q025 = NA_real_,
      q975 = NA_real_
    ))
  }

  # CI for E[phi(F_lambda)]: based on M estimates of the mean
  grand_mean <- mean(mean_estimates)
  se_mean <- sd(mean_estimates) / sqrt(length(mean_estimates))
  ci_lower <- quantile(mean_estimates, 0.025)
  ci_upper <- quantile(mean_estimates, 0.975)

  # Prediction interval: based on all M*B samples
  q025 <- quantile(all_samples, 0.025)
  q975 <- quantile(all_samples, 0.975)

  list(
    mean = grand_mean,
    median = median(all_samples),
    sd = sd(all_samples),
    se = se_mean,
    ci_lower = as.numeric(ci_lower),
    ci_upper = as.numeric(ci_upper),
    q025 = q025,
    q975 = q975
  )
}

#' Compute summary statistics for posterior samples
#'
#' Helper function to compute summary statistics from posterior samples.
#' Returns both quantiles (describing the distribution of phi across different Q)
#' and confidence intervals (for the mean E[phi(F_lambda)]).
#'
#' @param samples Numeric vector. Posterior samples.
#'
#' @return A list with summary statistics:
#'   \itemize{
#'     \item mean: Point estimate of E[phi(F_lambda)]
#'     \item median: Median of the distribution
#'     \item sd: Standard deviation of phi(Q) across Q ~ F_lambda
#'     \item se: Standard error of the mean estimate
#'     \item ci_lower: Lower 95% CI for E[phi(F_lambda)] (mean - 1.96*SE)
#'     \item ci_upper: Upper 95% CI for E[phi(F_lambda)] (mean + 1.96*SE)
#'     \item q025: 2.5th percentile (prediction interval, not CI)
#'     \item q975: 97.5th percentile (prediction interval, not CI)
#'   }
#'
#' @export
compute_summary_stats <- function(samples) {

  # Remove NA values
  samples <- samples[!is.na(samples)]

  if (length(samples) == 0) {
    return(list(
      mean = NA_real_,
      median = NA_real_,
      sd = NA_real_,
      se = NA_real_,
      ci_lower = NA_real_,
      ci_upper = NA_real_,
      q025 = NA_real_,
      q975 = NA_real_
    ))
  }

  n <- length(samples)
  mean_val <- mean(samples)
  sd_val <- sd(samples)
  se_val <- sd_val / sqrt(n)

  # 95% CI for the mean (normal approximation)
  ci_lower <- mean_val - qnorm(0.975) * se_val
  ci_upper <- mean_val + qnorm(0.975) * se_val

  list(
    mean = mean_val,
    median = median(samples),
    sd = sd_val,
    se = se_val,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    q025 = quantile(samples, 0.025),
    q975 = quantile(samples, 0.975)
  )
}

#' Compare surrogate evaluation methods
#'
#' Compares the innovation approach with traditional surrogate evaluation methods
#' on the same dataset.
#'
#' @param current_data A tibble with the current study data.
#' @param n_outer Integer. Number of outer bootstrap samples for innovation approach.
#' @param n_inner Integer. Number of inner bootstrap samples for innovation approach.
#' @param lambda Numeric value in [0,1]. Fixed perturbation distance.
#' @param epsilon_s Numeric. Threshold for probability functional.
#' @param epsilon_y Numeric. Threshold for probability functional.
#' @param seed Integer. Random seed.
#'
#' @return A list with results from different methods:
#'   \item{innovation}{Results from innovation approach}
#'   \item{traditional}{Results from traditional methods (placeholder)}
#'
#' @details
#' This function provides a framework for comparing the innovation approach
#' with traditional surrogate evaluation methods. The traditional methods
#' are not yet implemented but can be added as wrappers to existing packages.
#'
#' @examples
#' # Generate data
#' current_data <- generate_study_data(n = 500)
#'
#' # Compare methods
#' comparison <- compare_surrogate_methods(current_data)
#'
#' @export
compare_surrogate_methods <- function(current_data,
                                    n_outer = 100,
                                    n_inner = 50,
                                    lambda = 0.3,
                                    epsilon_s = 0.2,
                                    epsilon_y = 0.1,
                                    seed = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  # Innovation approach
  innovation_result <- posterior_inference(
    current_data,
    n_draws_from_F = n_outer,
    n_future_studies_per_draw = n_inner,
    lambda = lambda,
    functional_type = "all",
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y,
    seed = NULL
  )
  
  # Traditional methods (placeholder)
  traditional_result <- list(
    pte = NA_real_,  # Proportion of Treatment Effect
    correlation = NA_real_,  # Within-study correlation
    mediation_effect = NA_real_,  # Mediation indirect effect
    note = "Traditional methods not yet implemented"
  )
  
  list(
    innovation = innovation_result,
    traditional = traditional_result
  )
}

#' Plot posterior distribution of functionals
#'
#' Creates visualization of the posterior distribution of surrogate functionals.
#'
#' @param posterior_result List. Result from posterior_inference().
#' @param functional_type Character. Type of functional to plot.
#' @param plot_type Character. Type of plot: "density", "histogram", or "trace".
#'
#' @return A ggplot2 object.
#'
#' @examples
#' # Run inference
#' current_data <- generate_study_data(n = 500)
#' result <- posterior_inference(current_data, n_outer = 100, n_inner = 50)
#'
#' # Plot posterior distribution
#' plot_posterior(result, "correlation")
#'
#' @export
plot_posterior <- function(posterior_result,
                         functional_type = c("correlation", "probability", "conditional_mean"),
                         plot_type = c("density", "histogram", "trace")) {
  
  functional_type <- match.arg(functional_type)
  plot_type <- match.arg(plot_type)
  
  # Extract samples
  if (functional_type == "correlation") {
    samples <- posterior_result$functionals$correlation
  } else if (functional_type == "probability") {
    samples <- posterior_result$functionals$probability
  } else {
    samples <- posterior_result$functionals$conditional_means[, 1]
  }
  
  # Remove NA values
  samples <- samples[!is.na(samples)]
  
  if (length(samples) == 0) {
    stop("No valid samples found for plotting")
  }
  
  # Create plot
  if (plot_type == "density") {
    p <- ggplot2::ggplot(data.frame(samples = samples), ggplot2::aes(x = samples)) +
      ggplot2::geom_density(fill = "lightblue", alpha = 0.7) +
      ggplot2::labs(
        title = paste("Posterior Distribution of", functional_type, "Functional"),
        x = paste("Value of", functional_type, "functional"),
        y = "Density"
      )
  } else if (plot_type == "histogram") {
    p <- ggplot2::ggplot(data.frame(samples = samples), ggplot2::aes(x = samples)) +
      ggplot2::geom_histogram(bins = 30, fill = "lightblue", alpha = 0.7) +
      ggplot2::labs(
        title = paste("Posterior Distribution of", functional_type, "Functional"),
        x = paste("Value of", functional_type, "functional"),
        y = "Count"
      )
  } else {
    p <- ggplot2::ggplot(data.frame(samples = samples, iteration = 1:length(samples)), 
                        ggplot2::aes(x = iteration, y = samples)) +
      ggplot2::geom_line() +
      ggplot2::labs(
        title = paste("Trace Plot of", functional_type, "Functional"),
        x = "Iteration",
        y = paste("Value of", functional_type, "functional")
      )
  }
  
  p + ggplot2::theme_minimal()
}
