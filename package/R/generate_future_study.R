#' Generate future study from innovation distribution
#'
#' Implements the core innovation approach where future studies are generated
#' as mixtures of the current study distribution P₀ and an innovation distribution P̃.
#' Specifically, Q = (1-λ)P₀ + λP̃ where λ controls the closeness to the current study.
#'
#' @param current_data A tibble or data.frame with the current study data.
#'   Must contain columns: A (treatment), S (surrogate), Y (outcome), and
#'   optionally X (covariates).
#' @param lambda Numeric value in [0,1] controlling the perturbation distance from P₀.
#'   When λ = 0, future study equals current study.
#'   When λ = 1, future study is purely from innovation distribution.
#'   Default: 0.3 for moderate perturbation.
#' @param innovation_type Character. Type of innovation distribution:
#'   "bayesian_bootstrap" (default) or "dirichlet_process".
#' @param future_n Integer. Sample size for the future study. Default: same as current study.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A list with elements:
#'   \item{lambda}{The fixed closeness parameter}
#'   \item{future_data}{A tibble with the generated future study data}
#'   \item{innovation_weights}{The innovation distribution weights}
#'
#' @details
#' The innovation approach models future studies as:
#' Q = (1-λ)P₀ + λP̃
#'
#' where:
#' - P₀ is the current study distribution (empirical distribution)
#' - P̃ is the innovation distribution (Bayesian bootstrap or Dirichlet process)
#' - λ is a fixed design parameter controlling the total variation distance
#'
#' When λ ≈ 0, future studies are very similar to the current study.
#' When λ ≈ 1, future studies may differ substantially from the current study.
#'
#' This implementation follows the fixed-λ framework from the methods paper (Section 3).
#' For grid search over multiple λ values, see \code{\link{grid_search_lambda}}.
#'
#' @seealso \code{\link{grid_search_lambda}} for evaluating surrogate quality across λ values
#'
#' @examples
#' # Generate current study data
#' current_data <- generate_study_data(
#'   n = 500,
#'   treatment_effect_surrogate = c(0.5, 0.8),
#'   treatment_effect_outcome = c(0.3, 0.7)
#' )
#'
#' # Generate future study with moderate perturbation
#' future_study <- generate_future_study(current_data, lambda = 0.3)
#'
#' # Generate future study with high perturbation
#' future_study_high <- generate_future_study(current_data, lambda = 0.8)
#'
#' @export
generate_future_study <- function(current_data,
                                 lambda = 0.3,
                                 innovation_type = c("bayesian_bootstrap", "dirichlet_process"),
                                 future_n = nrow(current_data),
                                 seed = NULL) {

  if (!is.null(seed)) set.seed(seed)

  innovation_type <- match.arg(innovation_type)

  n <- nrow(current_data)

  # Step 1: Validate lambda parameter
  if (!is.numeric(lambda) || length(lambda) != 1 || lambda < 0 || lambda > 1) {
    stop("lambda must be a single numeric value in [0, 1]")
  }
  
  # Step 2: Generate innovation distribution weights
  innovation_weights <- switch(innovation_type,
    "bayesian_bootstrap" = {
      # Bayesian bootstrap: Dirichlet(1, 1, ..., 1)
      as.numeric(MCMCpack::rdirichlet(1, rep(1, n)))
    },
    "dirichlet_process" = {
      # Dirichlet process: more concentrated weights
      # Use Dirichlet with concentration parameter
      concentration <- 1.0
      as.numeric(MCMCpack::rdirichlet(1, rep(concentration, n)))
    }
  )
  
  # Step 3: Current study weights (uniform empirical distribution)
  p0_weights <- rep(1/n, n)
  
  # Step 4: Mixture weights: (1-λ)P₀ + λP̃
  mixture_weights <- (1 - lambda) * p0_weights + lambda * innovation_weights
  
  # Step 5: Sample future study from mixture distribution
  future_indices <- sample(seq_len(n), 
                          size = future_n, 
                          replace = TRUE, 
                          prob = mixture_weights)
  
  future_data <- current_data[future_indices, ]
  
  # Return results
  list(
    lambda = lambda,
    future_data = future_data,
    innovation_weights = innovation_weights,
    mixture_weights = mixture_weights
  )
}

#' Generate multiple future studies
#'
#' Convenience function to generate multiple future studies from the same
#' current study with a fixed lambda value. Useful for Monte Carlo estimation
#' of functionals phi(F_lambda).
#'
#' @param current_data A tibble with the current study data.
#' @param n_future_studies Integer. Number of future studies to generate.
#' @param lambda Numeric value in [0,1] controlling the perturbation distance.
#'   Default: 0.3. All generated studies use the same lambda value.
#' @param innovation_type Character. Type of innovation distribution.
#' @param future_n Integer. Sample size for each future study.
#' @param seed Integer. Random seed for reproducibility.
#' @param parallel Logical. Whether to use parallel processing (future package).
#'   Default: FALSE.
#'
#' @return A list of length n_future_studies, where each element is the
#'   result of generate_future_study(). All studies have the same lambda.
#'
#' @details
#' This function generates multiple future studies Q_m for m=1,...,M, where each
#' Q_m = (1-lambda)*P_0 + lambda*P_m and P_m ~ mu. All studies use the same
#' fixed lambda value, which is required for estimating phi(F_lambda) as described
#' in Section 3 of the methods paper.
#'
#' @seealso \code{\link{generate_future_study}} for generating a single study
#' @seealso \code{\link{grid_search_lambda}} for evaluating across multiple lambda values
#'
#' @examples
#' # Generate current study
#' current_data <- generate_study_data(n = 500)
#'
#' # Generate 100 future studies with lambda = 0.3
#' future_studies <- generate_multiple_future_studies(
#'   current_data,
#'   n_future_studies = 100,
#'   lambda = 0.3
#' )
#'
#' # Extract treatment effects from all future studies
#' treatment_effects <- purrr::map_dfr(future_studies, function(study) {
#'   delta_s <- compute_treatment_effect(study$future_data, "S")
#'   delta_y <- compute_treatment_effect(study$future_data, "Y")
#'   tibble::tibble(delta_s = delta_s, delta_y = delta_y, lambda = study$lambda)
#' })
#'
#' @export
generate_multiple_future_studies <- function(current_data,
                                           n_future_studies = 100,
                                           lambda = 0.3,
                                           innovation_type = c("bayesian_bootstrap", "dirichlet_process"),
                                           future_n = nrow(current_data),
                                           seed = NULL,
                                           parallel = FALSE) {
  
  innovation_type <- match.arg(innovation_type)
  
  if (!is.null(seed)) {
    # Set seed for reproducibility
    set.seed(seed)
  }
  
  if (parallel && requireNamespace("future", quietly = TRUE)) {
    # Parallel implementation using future package
    future::plan(future::multisession)
    
    future_studies <- future::future_lapply(
      1:n_future_studies,
      function(i) {
        generate_future_study(
          current_data = current_data,
          lambda = lambda,
          innovation_type = innovation_type,
          future_n = future_n,
          seed = NULL  # Don't set seed in parallel
        )
      }
    )
    
    future::plan(future::sequential)  # Reset to sequential
    
  } else {
    # Sequential implementation
    future_studies <- purrr::map(
      1:n_future_studies,
      function(i) {
        generate_future_study(
          current_data = current_data,
          lambda = lambda,
          innovation_type = innovation_type,
          future_n = future_n,
          seed = NULL
        )
      }
    )
  }
  
  future_studies
}

#' Compute innovation distribution statistics
#'
#' Helper function to compute summary statistics of the innovation distribution
#' for diagnostic purposes.
#'
#' @param innovation_weights Numeric vector. Innovation distribution weights.
#' @param current_data A tibble with the current study data.
#'
#' @return A list with summary statistics of the innovation distribution.
#'
#' @details
#' Returns statistics including:
#' - Effective sample size
#' - Weight concentration (Gini coefficient)
#' - Maximum weight
#' - Number of observations with zero weight
#'
#' @examples
#' current_data <- generate_study_data(n = 500)
#' future_study <- generate_future_study(current_data)
#' 
#' innovation_stats <- compute_innovation_stats(
#'   future_study$innovation_weights,
#'   current_data
#' )
#'
#' @export
compute_innovation_stats <- function(innovation_weights, current_data) {
  
  n <- length(innovation_weights)
  
  # Effective sample size
  ess <- 1 / sum(innovation_weights^2)
  
  # Gini coefficient (measure of concentration)
  sorted_weights <- sort(innovation_weights)
  cumsum_weights <- cumsum(sorted_weights)
  gini <- (2 * sum((1:n) * sorted_weights)) / (n * sum(innovation_weights)) - (n + 1) / n
  
  # Maximum weight
  max_weight <- max(innovation_weights)
  
  # Number of observations with zero weight
  n_zero <- sum(innovation_weights == 0)
  
  # Weight entropy
  entropy <- -sum(innovation_weights * log(innovation_weights + 1e-10))
  
  list(
    effective_sample_size = ess,
    gini_coefficient = gini,
    max_weight = max_weight,
    n_zero_weights = n_zero,
    entropy = entropy,
    n_observations = n
  )
}

