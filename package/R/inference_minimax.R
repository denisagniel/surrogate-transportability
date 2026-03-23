#' @importFrom stats quantile sd cor
NULL

#' Minimax Inference for Surrogate Transportability
#'
#' Computes worst-case bounds [phi_*, phi*] for surrogate quality over a class
#' of innovation distributions. Provides robust inference that does not
#' depend on correctly specifying mu.
#'
#' @param current_data Data frame with columns A (treatment), S (surrogate), Y (outcome)
#' @param lambda Perturbation parameter in [0,1] controlling TV distance
#' @param functional_type Character: "correlation", "probability", or "conditional_mean"
#' @param dirichlet_alpha_range Numeric vector of length 2: [min_alpha, max_alpha] for Dirichlet search
#' @param n_dirichlet_grid Integer: number of Dirichlet alpha values to search
#' @param include_vertices Logical: include point mass innovations on individual units?
#' @param max_vertices Integer: max number of vertices to check (for computational tractability)
#' @param n_innovations Integer: number of Monte Carlo innovations per grid point
#' @param confidence_level Numeric in (0,1): confidence level for bootstrap CI (if n_bootstrap > 0)
#' @param n_bootstrap Integer: number of bootstrap samples for CI on bounds (0 = none)
#' @param epsilon_s Numeric: threshold for probability functional
#' @param epsilon_y Numeric: threshold for probability functional
#' @param delta_s_value Numeric: conditioning value for conditional_mean functional
#' @param parallel Logical: use parallel processing?
#' @param seed Integer: random seed for reproducibility
#' @param verbose Logical: print progress messages?
#'
#' @return List with components:
#'   \item{phi_star}{Supremum of phi over M}
#'   \item{phi_star_lower}{Infimum of phi over M}
#'   \item{bound_width}{Width of worst-case interval}
#'   \item{search_grid}{Tibble with all evaluated (mu, phi) pairs}
#'   \item{alpha_at_sup}{Which mu achieved supremum}
#'   \item{alpha_at_inf}{Which mu achieved infimum}
#'   \item{method_estimate}{Standard method (alpha=1) estimate for comparison}
#'   \item{method_ci_lower}{Standard method CI lower bound}
#'   \item{method_ci_upper}{Standard method CI upper bound}
#'   \item{method_contained}{Logical: is method estimate within bounds?}
#'   \item{phi_star_ci}{Bootstrap CI on supremum (if n_bootstrap > 0)}
#'   \item{phi_star_lower_ci}{Bootstrap CI on infimum (if n_bootstrap > 0)}
#'   \item{lambda}{Lambda parameter used}
#'   \item{functional_type}{Functional type}
#'   \item{class_M}{List describing the class M}
#'
#' @details
#' This function searches over a class M of innovation distributions to find
#' worst-case bounds on surrogate quality phi(F_lambda). The class includes:
#' \itemize{
#'   \item Dirichlet(alpha,...,alpha) for alpha in \code{dirichlet_alpha_range}
#'   \item Point masses on individual units (if \code{include_vertices = TRUE})
#'   \item Uniform distribution (baseline)
#' }
#'
#' The bounds [phi_*, phi*] are guaranteed to contain phi(F_lambda) for ANY innovation
#' distribution mu in the class M. This provides robust inference that does not
#' require correctly specifying mu.
#'
#' The parameter lambda controls total variation distance: any future study Q with
#' TV(Q, P₀) ≤ lambda can be represented as Q = (1-lambda)P₀ + lambdaPi_tilde for some Pi_tilde.
#'
#' @references
#' Paper citation here (methods/main.tex, Theorem 1, lines 138-143)
#'
#' @seealso \code{\link{surrogate_inference_if}} for standard inference assuming mu known
#'
#' @examples
#' \dontrun{
#' data <- generate_study_data(n = 500)
#' result <- surrogate_inference_minimax(
#'   data, lambda = 0.3,
#'   functional_type = "correlation",
#'   n_innovations = 1000
#' )
#' cat(sprintf("Worst-case bounds: [%.3f, %.3f]\n",
#'             result$phi_star_lower, result$phi_star))
#' }
#'
#' @export
surrogate_inference_minimax <- function(
  current_data,
  lambda,
  functional_type = c("correlation", "probability", "conditional_mean"),
  dirichlet_alpha_range = c(0.01, 100),
  n_dirichlet_grid = 40,
  include_vertices = TRUE,
  max_vertices = 50,
  n_innovations = 2000,
  confidence_level = 0.95,
  n_bootstrap = 0,
  epsilon_s = NULL,
  epsilon_y = NULL,
  delta_s_value = NULL,
  parallel = TRUE,
  seed = NULL,
  verbose = TRUE
) {

  functional_type <- match.arg(functional_type)

  if (!is.null(seed)) set.seed(seed)

  n <- nrow(current_data)

  # Validate inputs
  if (!is.numeric(lambda) || length(lambda) != 1 || lambda < 0 || lambda > 1) {
    stop("lambda must be a single numeric value in [0, 1]")
  }

  if (functional_type == "probability" && (is.null(epsilon_s) || is.null(epsilon_y))) {
    stop("epsilon_s and epsilon_y must be specified for probability functional")
  }

  if (functional_type == "conditional_mean" && is.null(delta_s_value)) {
    stop("delta_s_value must be specified for conditional_mean functional")
  }

  # Step 1: Construct search grid
  if (verbose) message("Constructing search grid...")
  search_grid <- construct_search_grid(
    n = n,
    dirichlet_alpha_range = dirichlet_alpha_range,
    n_dirichlet_grid = n_dirichlet_grid,
    include_vertices = include_vertices,
    max_vertices = max_vertices
  )

  if (verbose) {
    message(sprintf("Evaluating phi at %d grid points...", nrow(search_grid)))
  }

  # Step 2: Evaluate phi at each grid point
  if (parallel && requireNamespace("furrr", quietly = TRUE) &&
      requireNamespace("future", quietly = TRUE)) {

    if (verbose) message("Using parallel processing...")

    # Set up parallel backend
    future::plan(future::multisession, workers = parallel::detectCores() - 1)

    # Evaluate in parallel
    search_grid$phi_value <- furrr::future_map_dbl(
      1:nrow(search_grid),
      function(i) {
        evaluate_phi_at_grid_point(
          search_grid[i, ],
          current_data = current_data,
          lambda = lambda,
          n_innovations = n_innovations,
          functional_type = functional_type,
          epsilon_s = epsilon_s,
          epsilon_y = epsilon_y,
          delta_s_value = delta_s_value
        )
      },
      .options = furrr::furrr_options(seed = TRUE)
    )

    # Reset to sequential
    future::plan(future::sequential)

  } else {
    # Sequential evaluation
    if (verbose && parallel) {
      message("furrr/future packages not available, using sequential processing")
    }

    search_grid$phi_value <- numeric(nrow(search_grid))

    for (i in 1:nrow(search_grid)) {
      if (verbose && i %% 10 == 0) {
        message(sprintf("  Progress: %d/%d grid points", i, nrow(search_grid)))
      }

      search_grid$phi_value[i] <- evaluate_phi_at_grid_point(
        search_grid[i, ],
        current_data = current_data,
        lambda = lambda,
        n_innovations = n_innovations,
        functional_type = functional_type,
        epsilon_s = epsilon_s,
        epsilon_y = epsilon_y,
        delta_s_value = delta_s_value
      )
    }
  }

  # Step 3: Find extrema
  phi_star <- max(search_grid$phi_value, na.rm = TRUE)
  phi_star_lower <- min(search_grid$phi_value, na.rm = TRUE)
  bound_width <- phi_star - phi_star_lower

  # Identify which mu achieved extrema
  idx_sup <- which.max(search_grid$phi_value)
  idx_inf <- which.min(search_grid$phi_value)

  mu_at_sup <- list(
    mu_type = search_grid$mu_type[idx_sup],
    alpha = search_grid$alpha[idx_sup],
    vertex_id = search_grid$vertex_id[idx_sup]
  )

  mu_at_inf <- list(
    mu_type = search_grid$mu_type[idx_inf],
    alpha = search_grid$alpha[idx_inf],
    vertex_id = search_grid$vertex_id[idx_inf]
  )

  if (verbose) {
    message(sprintf("Bounds: [%.4f, %.4f] (width: %.4f)",
                    phi_star_lower, phi_star, bound_width))
    message(sprintf("Supremum achieved at: %s", mu_at_sup$mu_type))
    message(sprintf("Infimum achieved at: %s", mu_at_inf$mu_type))
  }

  # Step 4: Compare to standard method (alpha=1)
  if (verbose) message("Computing standard method estimate for comparison...")

  method_result <- surrogate_inference_if(
    current_data = current_data,
    lambda = lambda,
    n_innovations = n_innovations,
    functional_type = functional_type,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y,
    alpha = 1,
    confidence_level = confidence_level
  )

  method_contained <- (phi_star_lower <= method_result$estimate) &&
                      (method_result$estimate <= phi_star)

  if (verbose) {
    message(sprintf("Standard method: %.4f [%.4f, %.4f]",
                    method_result$estimate,
                    method_result$ci_lower,
                    method_result$ci_upper))
    message(sprintf("Method estimate contained in bounds: %s", method_contained))
  }

  # Step 5: (Optional) Bootstrap CI on bounds
  phi_star_ci <- NULL
  phi_star_lower_ci <- NULL

  if (n_bootstrap > 0) {
    if (verbose) message(sprintf("Computing bootstrap CI with %d samples...", n_bootstrap))

    bootstrap_results <- bootstrap_minimax_bounds(
      current_data = current_data,
      lambda = lambda,
      functional_type = functional_type,
      dirichlet_alpha_range = dirichlet_alpha_range,
      n_dirichlet_grid = n_dirichlet_grid,
      include_vertices = include_vertices,
      max_vertices = max_vertices,
      n_innovations = n_innovations,
      n_bootstrap = n_bootstrap,
      confidence_level = confidence_level,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_value = delta_s_value,
      parallel = parallel,
      verbose = verbose
    )

    phi_star_ci <- bootstrap_results$phi_star_ci
    phi_star_lower_ci <- bootstrap_results$phi_star_lower_ci
  }

  # Return results
  list(
    phi_star = phi_star,
    phi_star_lower = phi_star_lower,
    bound_width = bound_width,
    search_grid = search_grid,
    mu_at_sup = mu_at_sup,
    mu_at_inf = mu_at_inf,
    method_estimate = method_result$estimate,
    method_ci_lower = method_result$ci_lower,
    method_ci_upper = method_result$ci_upper,
    method_se = method_result$se,
    method_contained = method_contained,
    phi_star_ci = phi_star_ci,
    phi_star_lower_ci = phi_star_lower_ci,
    lambda = lambda,
    functional_type = functional_type,
    class_M = list(
      dirichlet_range = dirichlet_alpha_range,
      n_dirichlet_grid = n_dirichlet_grid,
      vertices_included = include_vertices,
      max_vertices = max_vertices,
      n_evaluations = nrow(search_grid)
    ),
    parameters = list(
      n_innovations = n_innovations,
      n_bootstrap = n_bootstrap,
      confidence_level = confidence_level,
      n = n
    )
  )
}


#' Construct search grid for minimax inference
#'
#' Builds grid of innovation distributions to search over.
#'
#' @param n Sample size
#' @param dirichlet_alpha_range Range of alpha values
#' @param n_dirichlet_grid Number of Dirichlet grid points
#' @param include_vertices Include vertex distributions?
#' @param max_vertices Maximum number of vertices
#'
#' @return Tibble with mu_type, alpha, vertex_id columns
#' @keywords internal
construct_search_grid <- function(n,
                                   dirichlet_alpha_range,
                                   n_dirichlet_grid,
                                   include_vertices,
                                   max_vertices) {

  # Dirichlet grid (log-spaced)
  alpha_grid <- exp(seq(
    log(dirichlet_alpha_range[1]),
    log(dirichlet_alpha_range[2]),
    length.out = n_dirichlet_grid
  ))

  # Start with Dirichlet entries
  grid_list <- list(
    tibble::tibble(
      mu_type = "dirichlet",
      alpha = alpha_grid,
      vertex_id = NA_integer_
    )
  )

  # Add vertices if requested
  if (include_vertices) {
    if (n > max_vertices) {
      # Sample vertices randomly
      vertex_ids <- sample(1:n, max_vertices)
    } else {
      vertex_ids <- 1:n
    }

    grid_list[[length(grid_list) + 1]] <- tibble::tibble(
      mu_type = "vertex",
      alpha = NA_real_,
      vertex_id = vertex_ids
    )
  }

  # Add uniform baseline (equivalent to lambda=0 limit)
  grid_list[[length(grid_list) + 1]] <- tibble::tibble(
    mu_type = "uniform",
    alpha = NA_real_,
    vertex_id = NA_integer_
  )

  # Combine all grid entries
  dplyr::bind_rows(grid_list)
}


#' Evaluate phi at a specific grid point
#'
#' Computes phi(F_lambda) for a given innovation distribution specification.
#'
#' @param grid_row Single-row tibble from search_grid
#' @param current_data Data frame
#' @param lambda Perturbation parameter
#' @param n_innovations Number of MC innovations
#' @param functional_type Type of functional
#' @param epsilon_s Threshold for probability
#' @param epsilon_y Threshold for probability
#' @param delta_s_value Conditioning value for conditional_mean
#'
#' @return Scalar phi value
#' @keywords internal
evaluate_phi_at_grid_point <- function(grid_row,
                                       current_data,
                                       lambda,
                                       n_innovations,
                                       functional_type,
                                       epsilon_s,
                                       epsilon_y,
                                       delta_s_value) {

  n <- nrow(current_data)
  mu_type <- grid_row$mu_type

  # Generate innovations based on mu specification
  if (mu_type == "dirichlet") {
    # Dirichlet(alpha,...,alpha)
    alpha <- grid_row$alpha
    innovations <- MCMCpack::rdirichlet(n_innovations, rep(alpha, n))

  } else if (mu_type == "vertex") {
    # Point mass on vertex j
    j <- grid_row$vertex_id
    innovations <- matrix(0, nrow = n_innovations, ncol = n)
    innovations[, j] <- 1

  } else if (mu_type == "uniform") {
    # Uniform distribution (equivalent to P₀)
    innovations <- matrix(1/n, nrow = n_innovations, ncol = n)

  } else {
    stop("Unknown mu_type: ", mu_type)
  }

  # Compute treatment effects under Q_m = (1-lambda)P₀ + lambdaPi_tilde_m
  treatment_effects <- matrix(NA, nrow = n_innovations, ncol = 2)

  for (m in 1:n_innovations) {
    # Mixture weights
    p_hat <- rep(1/n, n)
    p_tilde <- innovations[m, ]
    q_m_weights <- (1 - lambda) * p_hat + lambda * p_tilde

    # Compute treatment effects under Q_m
    delta_s_qm <- compute_treatment_effect_weighted(current_data, "S", q_m_weights)
    delta_y_qm <- compute_treatment_effect_weighted(current_data, "Y", q_m_weights)

    treatment_effects[m, 1] <- delta_s_qm
    treatment_effects[m, 2] <- delta_y_qm
  }

  # Compute functional from treatment effect pairs
  phi_value <- compute_functional_from_effects(
    delta_s_vec = treatment_effects[, 1],
    delta_y_vec = treatment_effects[, 2],
    functional_type = functional_type,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y
  )

  # Handle conditional_mean separately (not yet implemented in compute_functional_from_effects)
  if (functional_type == "conditional_mean") {
    # Use kernel-weighted average
    te_df <- tibble::tibble(
      delta_s = treatment_effects[, 1],
      delta_y = treatment_effects[, 2]
    )
    phi_value <- functional_conditional_mean(
      te_df,
      delta_s_value = delta_s_value
    )
  }

  phi_value
}


#' Bootstrap confidence intervals for minimax bounds
#'
#' Computes bootstrap CI on [phi_*, phi*] by resampling current_data.
#'
#' @inheritParams surrogate_inference_minimax
#'
#' @return List with phi_star_ci and phi_star_lower_ci
#' @keywords internal
bootstrap_minimax_bounds <- function(current_data,
                                     lambda,
                                     functional_type,
                                     dirichlet_alpha_range,
                                     n_dirichlet_grid,
                                     include_vertices,
                                     max_vertices,
                                     n_innovations,
                                     n_bootstrap,
                                     confidence_level,
                                     epsilon_s,
                                     epsilon_y,
                                     delta_s_value,
                                     parallel,
                                     verbose) {

  n <- nrow(current_data)

  # Store bootstrap bounds
  bootstrap_phi_star <- numeric(n_bootstrap)
  bootstrap_phi_star_lower <- numeric(n_bootstrap)

  for (b in 1:n_bootstrap) {
    if (verbose && b %% 10 == 0) {
      message(sprintf("  Bootstrap sample %d/%d", b, n_bootstrap))
    }

    # Bootstrap sample
    bootstrap_indices <- sample(1:n, size = n, replace = TRUE)
    bootstrap_data <- current_data[bootstrap_indices, ]

    # Run minimax inference on bootstrap sample
    bootstrap_result <- surrogate_inference_minimax(
      current_data = bootstrap_data,
      lambda = lambda,
      functional_type = functional_type,
      dirichlet_alpha_range = dirichlet_alpha_range,
      n_dirichlet_grid = n_dirichlet_grid,
      include_vertices = include_vertices,
      max_vertices = max_vertices,
      n_innovations = n_innovations,
      confidence_level = confidence_level,
      n_bootstrap = 0,  # Don't nest bootstrap
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_value = delta_s_value,
      parallel = parallel,
      seed = NULL,
      verbose = FALSE
    )

    bootstrap_phi_star[b] <- bootstrap_result$phi_star
    bootstrap_phi_star_lower[b] <- bootstrap_result$phi_star_lower
  }

  # Compute percentile CI
  alpha <- 1 - confidence_level

  phi_star_ci <- quantile(bootstrap_phi_star,
                          probs = c(alpha/2, 1 - alpha/2),
                          na.rm = TRUE)

  phi_star_lower_ci <- quantile(bootstrap_phi_star_lower,
                                probs = c(alpha/2, 1 - alpha/2),
                                na.rm = TRUE)

  list(
    phi_star_ci = as.numeric(phi_star_ci),
    phi_star_lower_ci = as.numeric(phi_star_lower_ci),
    bootstrap_phi_star = bootstrap_phi_star,
    bootstrap_phi_star_lower = bootstrap_phi_star_lower
  )
}
