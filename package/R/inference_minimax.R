#' @importFrom stats quantile sd cor weighted.mean dnorm
NULL

#' Minimax Inference for Surrogate Transportability
#'
#' Computes worst-case (minimax) bounds for surrogate quality over a
#' total variation (TV) ball of distributions. Uses RF-ensemble type-level
#' approach with validated <2% approximation error.
#'
#' @param current_data Data frame with columns A (treatment), S (surrogate), Y (outcome)
#' @param lambda TV-ball radius in [0,1] controlling perturbation magnitude
#' @param functional_type Character: "correlation", "probability", "conditional_mean", "ppv", or "npv"
#'
#' @param discretization_schemes Character vector: which schemes to use in ensemble
#'   Default: c("rf", "quantiles", "kmeans"). RF requires randomForest package.
#' @param covariate_cols Character vector of covariate column names.
#'   If NULL, auto-detects all columns except A, S, Y
#' @param J_target Integer: target number of types for discretization
#'
#' @param n_innovations Integer: number of Dirichlet innovations per scheme
#'
#' @param epsilon_s Numeric: threshold for probability/PPV functionals
#' @param epsilon_y Numeric: threshold for probability/PPV functionals
#' @param delta_s_value Numeric: conditioning value for conditional_mean functional
#'
#' @param confidence_level Numeric in (0,1): confidence level for bootstrap CI
#' @param n_bootstrap Integer: number of bootstrap samples for CI (0 = no CI)
#'
#' @param parallel Logical: use parallel processing for bootstrap?
#' @param seed Integer: random seed for reproducibility
#' @param verbose Logical: print progress messages?
#'
#' @return List with components:
#'   \item{phi_star}{Minimax estimate (conservative lower bound on surrogate quality)}
#'   \item{phi_star_lower}{Same as phi_star (for consistency with old API)}
#'   \item{best_scheme}{Which discretization scheme achieved minimum}
#'   \item{schemes_summary}{Tibble with results per scheme}
#'   \item{all_schemes}{Detailed results per scheme (if requested)}
#'   \item{ci_lower}{Bootstrap CI lower bound (if n_bootstrap > 0)}
#'   \item{ci_upper}{Bootstrap CI upper bound (if n_bootstrap > 0)}
#'   \item{lambda}{Lambda parameter used}
#'   \item{functional_type}{Functional type}
#'   \item{n}{Sample size}
#'   \item{call}{Function call}
#'
#' @details
#' This function implements the validated RF-ensemble type-level minimax approach:
#'
#' **Algorithm:**
#' 1. Discretize data into types using multiple schemes (RF, quantiles, k-means)
#' 2. For each scheme:
#'    - Generate J-dimensional Dirichlet innovations (type-level, NOT observation-level)
#'    - Form mixtures Q_m = (1-λ)P₀ + λP̃_m at type level
#'    - Map to observation weights and compute treatment effects
#'    - Compute functional from treatment effect distribution
#' 3. Take MINIMUM across all schemes (ensemble estimate)
#'
#' **Key Innovation:**
#' - Uses TYPE-LEVEL innovations (J-dimensional) instead of observation-level (n-dimensional)
#' - Validated to achieve <2% approximation error to true TV-ball minimax
#' - Ensemble over schemes explores different "directions" in TV-ball
#'
#' **Interpretation:**
#' The parameter lambda controls total variation distance: any future study Q
#' with TV(Q, P₀) ≤ lambda can be represented as Q = (1-lambda)P₀ + lambda*Pi_tilde.
#' The minimax estimate phi_star is a conservative lower bound: the true surrogate
#' quality in the worst-case future study within the TV-ball.
#'
#' **Discretization Schemes:**
#' - **RF**: Random forest on treatment effects (requires randomForest package)
#' - **Quantiles**: Quantile bins on covariates
#' - **K-means**: K-means clustering on covariates
#'
#' Each scheme explores different covariate relationships. Taking the minimum
#' approximates the true worst-case over all possible distributions in the TV-ball.
#'
#' @references
#' Validation: validate_rf_ensemble_theory.R shows <2% approximation error
#' across multiple data-generating scenarios.
#'
#' @seealso \code{\link{surrogate_inference_if}} for standard inference assuming innovation distribution known
#'
#' @examples
#' \dontrun{
#' # Generate example data
#' data <- generate_study_data(n = 1000)
#'
#' # Minimax inference with default settings
#' result <- surrogate_inference_minimax(data, lambda = 0.3)
#' cat(sprintf("Minimax correlation: %.3f\n", result$phi_star))
#'
#' # With bootstrap CI
#' result_ci <- surrogate_inference_minimax(
#'   data, lambda = 0.3,
#'   n_bootstrap = 100,
#'   confidence_level = 0.95
#' )
#' cat(sprintf("95%% CI: [%.3f, %.3f]\n",
#'             result_ci$ci_lower, result_ci$ci_upper))
#'
#' # PPV functional
#' result_ppv <- surrogate_inference_minimax(
#'   data, lambda = 0.3,
#'   functional_type = "ppv",
#'   epsilon_s = 0.5,
#'   epsilon_y = 0.5
#' )
#' }
#'
#' @export
surrogate_inference_minimax <- function(
  current_data,
  lambda,
  functional_type = c("correlation", "probability", "conditional_mean", "ppv", "npv"),

  # Discretization parameters
  discretization_schemes = c("rf", "quantiles", "kmeans"),
  covariate_cols = NULL,
  J_target = 16,

  # Innovation parameters
  n_innovations = 2000,

  # Functional-specific parameters
  epsilon_s = NULL,
  epsilon_y = NULL,
  delta_s_value = NULL,

  # Bootstrap CI (optional)
  confidence_level = 0.95,
  n_bootstrap = 0,

  # Execution parameters
  parallel = TRUE,
  seed = NULL,
  verbose = TRUE
) {

  # Match and validate arguments
  functional_type <- match.arg(functional_type)

  # Store function call
  call <- match.call()

  # Set seed if provided
  if (!is.null(seed)) set.seed(seed)

  n <- nrow(current_data)

  # Validate inputs
  if (!is.numeric(lambda) || length(lambda) != 1 || lambda < 0 || lambda > 1) {
    stop("lambda must be a single numeric value in [0, 1]")
  }

  if ((functional_type %in% c("probability", "ppv")) &&
      (is.null(epsilon_s) || is.null(epsilon_y))) {
    stop("epsilon_s and epsilon_y must be specified for probability/PPV functional")
  }

  if (functional_type == "npv" && (is.null(epsilon_s) || is.null(epsilon_y))) {
    stop("epsilon_s and epsilon_y must be specified for NPV functional")
  }

  if (functional_type == "conditional_mean" && is.null(delta_s_value)) {
    stop("delta_s_value must be specified for conditional_mean functional")
  }

  # Validate required columns
  required_cols <- c("A", "S", "Y")
  missing_cols <- setdiff(required_cols, names(current_data))
  if (length(missing_cols) > 0) {
    stop("Required columns missing from current_data: ", paste(missing_cols, collapse = ", "))
  }

  # Auto-detect covariate columns if needed
  if (is.null(covariate_cols)) {
    covariate_cols <- setdiff(names(current_data), c("A", "S", "Y"))
    if (length(covariate_cols) == 0) {
      stop("No covariate columns found. Data must have columns other than A, S, Y, ",
           "or specify covariate_cols explicitly")
    }
  }

  if (verbose) {
    message("========================================")
    message("Minimax Inference (RF-Ensemble)")
    message("========================================")
    message(sprintf("Sample size: n = %d", n))
    message(sprintf("Lambda: %.3f", lambda))
    message(sprintf("Functional: %s", functional_type))
    message(sprintf("Schemes: %s", paste(discretization_schemes, collapse = ", ")))
    message(sprintf("Target types: J = %d", J_target))
    message(sprintf("Innovations per scheme: M = %d", n_innovations))
    message("")
  }

  # Main estimation via ensemble
  result <- estimate_minimax_ensemble(
    data = current_data,
    lambda = lambda,
    schemes = discretization_schemes,
    covariate_cols = covariate_cols,
    J_target = J_target,
    M = n_innovations,
    functional_type = functional_type,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y,
    delta_s_value = delta_s_value,
    verbose = verbose
  )

  # Bootstrap CI if requested
  ci_lower <- NULL
  ci_upper <- NULL
  bootstrap_estimates <- NULL

  if (n_bootstrap > 0) {
    if (verbose) {
      message("")
      message(sprintf("Computing bootstrap CI (%d samples)...", n_bootstrap))
    }

    bootstrap_result <- bootstrap_minimax_ci(
      current_data = current_data,
      lambda = lambda,
      functional_type = functional_type,
      discretization_schemes = discretization_schemes,
      covariate_cols = covariate_cols,
      J_target = J_target,
      n_innovations = n_innovations,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_value = delta_s_value,
      n_bootstrap = n_bootstrap,
      confidence_level = confidence_level,
      parallel = parallel,
      verbose = verbose
    )

    ci_lower <- bootstrap_result$ci_lower
    ci_upper <- bootstrap_result$ci_upper
    bootstrap_estimates <- bootstrap_result$bootstrap_estimates

    if (verbose) {
      message(sprintf("Bootstrap %g%% CI: [%.4f, %.4f]",
                      100 * confidence_level, ci_lower, ci_upper))
    }
  }

  if (verbose) {
    message("")
    message("========================================")
    message("Results:")
    message(sprintf("  Minimax estimate: %.4f", result$phi_star))
    message(sprintf("  Best scheme: %s", result$best_scheme))
    if (!is.null(ci_lower)) {
      message(sprintf("  %g%% CI: [%.4f, %.4f]",
                      100 * confidence_level, ci_lower, ci_upper))
    }
    message("========================================")
  }

  # Format return object
  output <- list(
    phi_star = result$phi_star,
    phi_star_lower = result$phi_star,  # Same as phi_star (conservative bound)
    best_scheme = result$best_scheme,
    schemes_summary = result$schemes_summary,
    lambda = lambda,
    functional_type = functional_type,
    n = n,
    call = call
  )

  # Add optional components
  if (n_bootstrap > 0) {
    output$ci_lower <- ci_lower
    output$ci_upper <- ci_upper
    output$bootstrap_estimates <- bootstrap_estimates
    output$confidence_level <- confidence_level
  }

  # Add detailed scheme results if verbose
  if (verbose) {
    output$all_schemes <- result$all_schemes
  }

  output
}


#' Bootstrap Confidence Interval for Minimax Estimate
#'
#' Computes percentile bootstrap CI by resampling data.
#'
#' @inheritParams surrogate_inference_minimax
#'
#' @return List with ci_lower, ci_upper, bootstrap_estimates
#' @keywords internal
bootstrap_minimax_ci <- function(current_data,
                                  lambda,
                                  functional_type,
                                  discretization_schemes,
                                  covariate_cols,
                                  J_target,
                                  n_innovations,
                                  epsilon_s,
                                  epsilon_y,
                                  delta_s_value,
                                  n_bootstrap,
                                  confidence_level,
                                  parallel,
                                  verbose) {

  n <- nrow(current_data)

  # Bootstrap estimates
  bootstrap_estimates <- numeric(n_bootstrap)

  # Function to run one bootstrap iteration
  run_bootstrap_iter <- function(b) {
    if (verbose && (b %% 10 == 0 || b == 1)) {
      message(sprintf("  Bootstrap sample %d/%d", b, n_bootstrap))
    }

    # Bootstrap sample
    bootstrap_indices <- sample(1:n, size = n, replace = TRUE)
    bootstrap_data <- current_data[bootstrap_indices, ]

    # Run ensemble minimax on bootstrap sample
    result <- estimate_minimax_ensemble(
      data = bootstrap_data,
      lambda = lambda,
      schemes = discretization_schemes,
      covariate_cols = covariate_cols,
      J_target = J_target,
      M = n_innovations,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_value = delta_s_value,
      verbose = FALSE
    )

    result$phi_star
  }

  # Run bootstrap
  if (parallel && requireNamespace("furrr", quietly = TRUE) &&
      requireNamespace("future", quietly = TRUE)) {

    if (verbose) message("  Using parallel processing...")

    # Set up parallel backend
    future::plan(future::multisession, workers = parallel::detectCores() - 1)

    # Run in parallel
    bootstrap_estimates <- furrr::future_map_dbl(
      1:n_bootstrap,
      run_bootstrap_iter,
      .options = furrr::furrr_options(seed = TRUE)
    )

    # Reset to sequential
    future::plan(future::sequential)

  } else {
    # Sequential
    for (b in 1:n_bootstrap) {
      bootstrap_estimates[b] <- run_bootstrap_iter(b)
    }
  }

  # Compute percentile CI
  alpha <- 1 - confidence_level
  ci <- quantile(bootstrap_estimates, probs = c(alpha/2, 1 - alpha/2), na.rm = TRUE)

  list(
    ci_lower = as.numeric(ci[1]),
    ci_upper = as.numeric(ci[2]),
    bootstrap_estimates = bootstrap_estimates
  )
}
