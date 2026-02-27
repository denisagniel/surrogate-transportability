#' Base R6 class for surrogate simulation experiments
#'
#' Provides a framework for running simulation experiments to evaluate
#' surrogate markers using the innovation approach.
#'
#' @import R6
#' @import dplyr
#' @import tibble
#' @import purrr
#'
#' @export
SurrogateSimulation <- R6::R6Class(
  "SurrogateSimulation",
  
  public = list(
    
    #' @field params List of simulation parameters
    params = NULL,
    
    #' @field data Generated study data
    data = NULL,
    
    #' @field results Simulation results
    results = NULL,
    
    #' @field metadata Additional metadata about the simulation
    metadata = NULL,
    
    #' @description
    #' Initialize a new SurrogateSimulation object
    #' @param params List of simulation parameters
    #' @param seed Random seed for reproducibility
    initialize = function(params = list(), seed = NULL) {
      self$params <- params
      self$metadata <- list(
        created_at = Sys.time(),
        seed = seed
      )
      
      if (!is.null(seed)) {
        set.seed(seed)
      }
    },
    
    #' @description
    #' Generate study data based on parameters
    #' @param ... Additional arguments passed to generate_study_data
    generate_data = function(...) {
      # Load the package functions
      devtools::load_all("package/", quiet = TRUE)
      
      # Merge parameters with additional arguments
      data_params <- c(self$params, list(...))
      
      # Remove scenario parameter as it's not used by generate_study_data
      data_params$scenario <- NULL
      
      # Generate data
      self$data <- do.call(generate_study_data, data_params)
      
      invisible(self)
    },
    
    #' @description
    #' Run the simulation experiment
    #' @param n_draws_from_F Number of draws from super-population F
    #' @param n_future_studies_per_draw Number of future studies per draw from F
    #' @param functional_type Type of functional to compute
    #' @param ... Additional arguments passed to posterior_inference
    run = function(n_draws_from_F = 500,
                  n_future_studies_per_draw = 200,
                  functional_type = "all",
                  ...) {
      
      if (is.null(self$data)) {
        stop("No data available. Call generate_data() first.")
      }
      
      # Load the package functions
      devtools::load_all("package/", quiet = TRUE)
      
      # Run posterior inference
      inference_params <- list(
        current_data = self$data,
        n_draws_from_F = n_draws_from_F,
        n_future_studies_per_draw = n_future_studies_per_draw,
        functional_type = functional_type,
        ...
      )
      
      self$results <- do.call(posterior_inference, inference_params)
      
      # Add metadata
      self$metadata$run_time <- Sys.time()
      self$metadata$n_draws_from_F <- n_draws_from_F
      self$metadata$n_future_studies_per_draw <- n_future_studies_per_draw
      self$metadata$functional_type <- functional_type
      
      invisible(self)
    },
    
    #' @description
    #' Analyze the simulation results
    #' @return A list with analysis results
    analyze = function() {
      if (is.null(self$results)) {
        stop("No results available. Call run() first.")
      }
      
      analysis <- list()
      
      # Extract current study treatment effects
      analysis$current_effects <- self$results$current_effects
      
      # Extract functional summaries
      if (self$metadata$functional_type == "all") {
        analysis$correlation_summary <- self$results$summary$correlation
        analysis$probability_summary <- self$results$summary$probability
        analysis$conditional_means_summary <- self$results$summary$conditional_means
      } else {
        analysis$functional_summary <- self$results$summary
      }
      
      # Compute additional statistics
      if (self$metadata$functional_type == "all") {
        correlation_samples <- self$results$functionals$correlation
        analysis$correlation_stats <- list(
          mean = mean(correlation_samples, na.rm = TRUE),
          sd = sd(correlation_samples, na.rm = TRUE),
          q025 = quantile(correlation_samples, 0.025, na.rm = TRUE),
          q975 = quantile(correlation_samples, 0.975, na.rm = TRUE)
        )
      }
      
      analysis
    },
    
    #' @description
    #' Save simulation results to file
    #' @param path Directory path to save results
    #' @param filename Optional filename (default: auto-generated)
    save = function(path = "sims/results/", filename = NULL) {
      if (is.null(self$results)) {
        stop("No results available. Call run() first.")
      }
      
      # Create directory if it doesn't exist
      if (!dir.exists(path)) {
        dir.create(path, recursive = TRUE)
      }
      
      # Generate filename if not provided
      if (is.null(filename)) {
        timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
        scenario <- self$params$scenario %||% "default"
        filename <- paste0("simulation_", scenario, "_", timestamp, ".rds")
      }
      
      # Prepare data for saving
      save_data <- list(
        params = self$params,
        results = self$results,
        metadata = self$metadata,
        analysis = self$analyze()
      )
      
      # Save to file
      saveRDS(save_data, file.path(path, filename))
      
      cat("Results saved to:", file.path(path, filename), "\n")
      invisible(self)
    },
    
    #' @description
    #' Load simulation results from file
    #' @param filepath Path to the saved results file
    load = function(filepath) {
      if (!file.exists(filepath)) {
        stop("File not found:", filepath)
      }
      
      loaded_data <- readRDS(filepath)
      
      self$params <- loaded_data$params
      self$results <- loaded_data$results
      self$metadata <- loaded_data$metadata
      
      cat("Results loaded from:", filepath, "\n")
      invisible(self)
    },
    
    #' @description
    #' Create summary report of the simulation
    #' @return A character string with the summary
    summary = function() {
      if (is.null(self$results)) {
        return("No results available. Call run() first.")
      }
      
      analysis <- self$analyze()
      
      report <- paste0(
        "Surrogate Simulation Summary\n",
        "============================\n\n",
        "Parameters:\n",
        "- Sample size: ", self$params$n %||% "Not specified", "\n",
        "- Scenario: ", self$params$scenario %||% "Default", "\n",
        "- Surrogate type: ", self$params$surrogate_type %||% "Not specified", "\n",
        "- Outcome type: ", self$params$outcome_type %||% "Not specified", "\n\n",
        "Simulation settings:\n",
        "- Draws from F: ", self$metadata$n_draws_from_F, "\n",
        "- Future studies per draw: ", self$metadata$n_future_studies_per_draw, "\n",
        "- Functional type: ", self$metadata$functional_type, "\n\n"
      )
      
      if (self$metadata$functional_type == "all") {
        report <- paste0(
          report,
          "Results:\n",
          "- Correlation functional: ", 
          round(analysis$correlation_summary$mean, 3), 
          " (", round(analysis$correlation_summary$q025, 3), ", ",
          round(analysis$correlation_summary$q975, 3), ")\n",
          "- Probability functional: ",
          round(analysis$probability_summary$mean, 3),
          " (", round(analysis$probability_summary$q025, 3), ", ",
          round(analysis$probability_summary$q975, 3), ")\n"
        )
      } else {
        report <- paste0(
          report,
          "Results:\n",
          "- ", self$metadata$functional_type, " functional: ",
          round(analysis$functional_summary$mean, 3),
          " (", round(analysis$functional_summary$q025, 3), ", ",
          round(analysis$functional_summary$q975, 3), ")\n"
        )
      }
      
      report
    }
  )
)
