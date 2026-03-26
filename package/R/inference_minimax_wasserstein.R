#' @importFrom stats quantile sd cor weighted.mean dnorm
NULL

#' Minimax Inference for Surrogate Transportability (Wasserstein Ball)
#'
#' Computes worst-case (minimax) bounds for surrogate quality over a
#' Wasserstein ball of distributions. Uses RF-ensemble type-level approach
#' adapted for Wasserstein constraints.
#'
#' @param current_data Data frame with columns A (treatment), S (surrogate), Y (outcome)
#' @param lambda_w Numeric: Wasserstein ball radius controlling covariate shift magnitude
#' @param functional_type Character: "correlation", "probability", "conditional_mean", "ppv", or "npv"
#'
#' @param discretization_schemes Character vector: which schemes to use in ensemble.
#'   Default: c("rf", "quantiles", "kmeans"). RF requires randomForest package.
#' @param covariate_cols Character vector of covariate column names.
#'   If NULL, auto-detects all columns except A, S, Y
#' @param J_target Integer: target number of types for discretization
#'
#' @param n_innovations Integer: number of Wasserstein perturbations per scheme
#' @param cost_function Character: "euclidean" (default) or "mahalanobis" for cost matrix
#' @param sampling_method Character: "normal" (default), "dirichlet", or "uniform" for sampling directions
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
#'   \item{phi_star_lower}{Same as phi_star (for consistency with TV-ball API)}
#'   \item{best_scheme}{Which discretization scheme achieved minimum}
#'   \item{schemes_summary}{Tibble with results per scheme}
#'   \item{all_schemes}{Detailed results per scheme (if verbose = TRUE)}
#'   \item{ci_lower}{Bootstrap CI lower bound (if n_bootstrap > 0)}
#'   \item{ci_upper}{Bootstrap CI upper bound (if n_bootstrap > 0)}
#'   \item{lambda_w}{Lambda_w parameter used}
#'   \item{functional_type}{Functional type}
#'   \item{n}{Sample size}
#'   \item{call}{Function call}
#'
#' @details
#' This function implements Wasserstein ball minimax inference as an alternative
#' to the total variation (TV) ball approach. Key differences:
#'
#' **Wasserstein vs TV constraints:**
#' - **TV-ball:** TV(Q, P₀) ≤ λ — allows arbitrary distributional changes
#' - **Wasserstein ball:** W₂(Q, P₀) ≤ λ_W — constrains covariate shift magnitude
#'
#' **When to use Wasserstein:**
#' - Pure covariate shift scenarios (X distribution changes, not causal structure)
#' - Structured population differences (geographic, demographic)
#' - Need interpretable distance in covariate space
#' - Want tighter bounds than TV when covariate shift is the main concern
#'
#' **When to use TV:**
#' - Selection on unobservables or confounding
#' - Arbitrary distributional changes including causal structure
#' - More conservative, robust to all types of distribution shift
#'
#' **Algorithm:**
#' 1. Discretize data into types using multiple schemes (RF, quantiles, k-means)
#' 2. Compute type centroids in covariate space
#' 3. Construct cost matrix: C[i,j] = ||centroid_i - centroid_j||²
#' 4. For each scheme:
#'    - Sample type distributions q satisfying W₂(q, p₀) ≤ λ_W
#'    - Map to observation weights and compute treatment effects
#'    - Compute functional from treatment effect distribution
#' 5. Take MINIMUM across all schemes (ensemble estimate)
#'
#' **Interpretation of lambda_w:**
#' λ_W directly measures the "amount" of covariate shift. For standardized covariates,
#' λ_W = 0.5 represents moderate shift, λ_W = 1.0 represents large shift.
#' Compare to TV λ which has less direct interpretation.
#'
#' @references
#' Esfahani & Kuhn (2018). "Data-driven distributionally robust optimization".
#' Mathematical Programming.
#'
#' Blanchet & Murthy (2019). "Quantifying distributional model risk via optimal transport".
#' Mathematics of Operations Research.
#'
#' @seealso
#' \code{\link{surrogate_inference_minimax}} for TV-ball version
#'
#' @examples
#' \dontrun{
#' # Generate example data
#' data <- generate_study_data(n = 1000)
#'
#' # Wasserstein minimax with default settings
#' result <- surrogate_inference_minimax_wasserstein(
#'   data,
#'   lambda_w = 0.5
#' )
#' cat(sprintf("Wasserstein minimax correlation: %.3f\n", result$phi_star))
#'
#' # Compare to TV-ball
#' result_tv <- surrogate_inference_minimax(data, lambda = 0.3)
#' cat(sprintf("TV minimax correlation: %.3f\n", result_tv$phi_star))
#'
#' # With bootstrap CI
#' result_ci <- surrogate_inference_minimax_wasserstein(
#'   data,
#'   lambda_w = 0.5,
#'   n_bootstrap = 100,
#'   confidence_level = 0.95
#' )
#' cat(sprintf("95%% CI: [%.3f, %.3f]\n",
#'             result_ci$ci_lower, result_ci$ci_upper))
#'
#' # PPV functional with Mahalanobis cost
#' result_ppv <- surrogate_inference_minimax_wasserstein(
#'   data,
#'   lambda_w = 0.5,
#'   functional_type = "ppv",
#'   cost_function = "mahalanobis",
#'   epsilon_s = 0.5,
#'   epsilon_y = 0.5
#' )
#' }
#'
#' @export
surrogate_inference_minimax_wasserstein <- function(
  current_data,
  lambda_w,
  functional_type = c("correlation", "probability", "conditional_mean", "ppv", "npv",
                      "concordance"),

  # Discretization parameters
  discretization_schemes = c("rf", "quantiles", "kmeans"),
  covariate_cols = NULL,
  J_target = 16,

  # Innovation parameters
  n_innovations = 2000,
  cost_function = c("euclidean", "mahalanobis"),
  sampling_method = c("normal", "dirichlet", "uniform"),

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
  cost_function <- match.arg(cost_function)
  sampling_method <- match.arg(sampling_method)

  # Store function call
  call <- match.call()

  # Set seed if provided
  if (!is.null(seed)) set.seed(seed)

  n <- nrow(current_data)

  # Validate inputs
  if (!is.numeric(lambda_w) || length(lambda_w) != 1 || lambda_w < 0) {
    stop("lambda_w must be a single non-negative numeric value")
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
    message("Wasserstein Ball Minimax Inference")
    message("========================================")
    message(sprintf("Sample size: n = %d", n))
    message(sprintf("Lambda_W: %.3f", lambda_w))
    message(sprintf("Functional: %s", functional_type))
    message(sprintf("Cost function: %s", cost_function))
    message(sprintf("Sampling method: %s", sampling_method))
    message(sprintf("Schemes: %s", paste(discretization_schemes, collapse = ", ")))
    message(sprintf("Target types: J = %d", J_target))
    message(sprintf("Innovations per scheme: M = %d", n_innovations))
    message("")
  }

  # Main estimation via ensemble
  result <- estimate_minimax_ensemble_wasserstein(
    data = current_data,
    lambda_w = lambda_w,
    schemes = discretization_schemes,
    covariate_cols = covariate_cols,
    J_target = J_target,
    M = n_innovations,
    functional_type = functional_type,
    cost_function = cost_function,
    sampling_method = sampling_method,
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

    bootstrap_result <- bootstrap_minimax_ci_wasserstein(
      current_data = current_data,
      lambda_w = lambda_w,
      functional_type = functional_type,
      discretization_schemes = discretization_schemes,
      covariate_cols = covariate_cols,
      J_target = J_target,
      n_innovations = n_innovations,
      cost_function = cost_function,
      sampling_method = sampling_method,
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
    message(sprintf("  Wasserstein minimax estimate: %.4f", result$phi_star))
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
    lambda_w = lambda_w,
    functional_type = functional_type,
    cost_function = cost_function,
    sampling_method = sampling_method,
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


#' Bootstrap Confidence Interval for Wasserstein Minimax Estimate
#'
#' Computes percentile bootstrap CI by resampling data.
#'
#' @inheritParams surrogate_inference_minimax_wasserstein
#'
#' @return List with ci_lower, ci_upper, bootstrap_estimates
#' @keywords internal
bootstrap_minimax_ci_wasserstein <- function(current_data,
                                              lambda_w,
                                              functional_type,
                                              discretization_schemes,
                                              covariate_cols,
                                              J_target,
                                              n_innovations,
                                              cost_function,
                                              sampling_method,
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
    result <- estimate_minimax_ensemble_wasserstein(
      data = bootstrap_data,
      lambda_w = lambda_w,
      schemes = discretization_schemes,
      covariate_cols = covariate_cols,
      J_target = J_target,
      M = n_innovations,
      functional_type = functional_type,
      cost_function = cost_function,
      sampling_method = sampling_method,
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
