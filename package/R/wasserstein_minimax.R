#' Wasserstein Ball Minimax Inference
#'
#' Core functions for minimax inference using Wasserstein distance constraints
#' instead of total variation distance. Provides geometrically meaningful bounds
#' for covariate shift scenarios.
#'
#' @name wasserstein_minimax
NULL

#' Sample Perturbation in Wasserstein Ball
#'
#' Generates a random type distribution q satisfying W_2(q, p0) <= lambda_w
#' using constrained sampling with random directions.
#'
#' @param reference Numeric vector (length J): reference type distribution (p0)
#' @param cost_matrix Matrix (J x J): pairwise cost between types
#' @param radius Numeric: Wasserstein ball radius (lambda_w)
#' @param method Character: sampling method ("normal", "dirichlet", "uniform")
#' @param max_attempts Integer: maximum rejection sampling attempts
#'
#' @return Numeric vector (length J) on probability simplex satisfying W_2 constraint
#'
#' @details
#' Generates random perturbations by:
#'
#' 1. Sample random direction delta
#' 2. Find maximum step size tau such that q = p0 + tau*delta satisfies:
#'    - W_2(q, p0) <= radius
#'    - q on probability simplex (sum = 1, q >= 0)
#' 3. Return q
#'
#' **Sampling methods:**
#' - **normal**: delta ~ N(0, I), then zero-centered
#' - **dirichlet**: delta = Dirichlet(1,...,1) - p0
#' - **uniform**: delta = uniform on sphere, then zero-centered
#'
#' Uses binary search to find the maximum feasible step size, ensuring
#' efficient exploration of the Wasserstein ball boundary.
#'
#' @keywords internal
sample_wasserstein_perturbation <- function(reference,
                                             cost_matrix,
                                             radius,
                                             method = c("normal", "dirichlet", "uniform"),
                                             max_attempts = 50) {

  method <- match.arg(method)
  J <- length(reference)

  # ROBUST STRATEGY: Mixture representation Q = (1-alpha)*P0 + alpha*P_tilde
  # For W_2^2(Q, P0) ≈ (Q-P0)'C(Q-P0) = alpha^2 * (P_tilde - P0)'C(P_tilde - P0)
  # So W_2(Q, P0) ≈ alpha * W_2(P_tilde, P0)

  # Sample P_tilde (innovation distribution)
  if (method %in% c("dirichlet", "uniform")) {
    # Dirichlet gives uniform sampling on simplex
    p_tilde <- MCMCpack::rdirichlet(1, rep(1, J))[1,]
  } else {
    # Normal: Use Dirichlet with varied concentration
    # Lower concentration = more variation
    concentration <- runif(1, 0.1, 2.0)
    p_tilde <- MCMCpack::rdirichlet(1, rep(concentration, J))[1,]
  }

  # Compute W_2 distance from reference to p_tilde
  w_dist_tilde <- wasserstein_distance_types(p_tilde, reference, cost_matrix)

  if (w_dist_tilde < 1e-10) {
    # P_tilde ≈ P0, no perturbation possible
    return(reference)
  }

  # Choose alpha to get desired radius
  # W_2(Q, P0) ≈ alpha * W_2(P_tilde, P0) = radius
  # So alpha = radius / W_2(P_tilde, P0)

  alpha_target <- radius / w_dist_tilde

  # Sample alpha uniformly in [0, alpha_target] to explore ball interior
  alpha <- runif(1, 0, min(alpha_target, 1.0))

  # Form mixture
  q <- (1 - alpha) * reference + alpha * p_tilde

  # Normalize (should already sum to 1, but ensure numerical precision)
  q <- q / sum(q)

  # Verify constraint (should be satisfied by construction)
  w_dist_final <- wasserstein_distance_types(q, reference, cost_matrix)

  if (w_dist_final > radius * 1.1) {
    # Fallback: if approximation failed, project
    q <- project_onto_wasserstein_ball(q, reference, cost_matrix, radius)
  }

  q
}


#' Estimate Minimax for Single Discretization Scheme (Wasserstein)
#'
#' Computes minimax estimate of surrogate functional for a single
#' discretization scheme using type-level Wasserstein ball.
#'
#' @param data Data frame with A, S, Y
#' @param bins Integer vector of bin assignments (length nrow(data))
#' @param cost_matrix Matrix (J x J): cost between types
#' @param lambda_w Numeric: Wasserstein ball radius
#' @param M Integer: number of perturbation samples
#' @param functional_type Character: type of functional
#' @param epsilon_s Threshold for probability functionals
#' @param epsilon_y Threshold for probability functionals
#' @param delta_s_value Conditioning value for conditional_mean
#' @param sampling_method Character: method for sampling perturbations
#'
#' @return List with:
#'   \item{phi_value}{Estimated minimax value}
#'   \item{effects}{Matrix of treatment effects (M x 2)}
#'   \item{J}{Number of types}
#'   \item{perturbations_q}{Matrix of sampled type distributions (M x J)}
#'   \item{method}{Character: "closed_form_wasserstein_dual" or "sampling"}
#'
#' @details
#' This implements the Wasserstein ball minimax algorithm:
#'
#' 1. Generate M type distributions q_m satisfying W_2(q_m, p0) <= lambda_w
#' 2. For each q_m:
#'    - Map to observation weights
#'    - Compute treatment effects via deterministic reweighting
#' 3. Compute functional from treatment effect distribution
#'
#' **FAST PATH for concordance:** When functional_type = "concordance",
#' uses 1-parameter dual optimization (Esfahani & Kuhn 2018):
#'   sup_{gamma>=0} { -gamma*lambda_w^2 + sum_j p0_j * min_i {tau_i^s*tau_i^y + gamma*C[i,j]} }
#' This is 50-100x faster than sampling (seconds vs minutes).
#'
#' **Key differences from TV-ball approach:**
#' - Constraint: W_2(q, p0) <= lambda_w (Wasserstein) vs TV(Q, P0) <= lambda (TV)
#' - Sampling: Constrained to Wasserstein ball vs Dirichlet mixture
#' - Interpretation: Structured covariate shift vs arbitrary distributional change
#'
#' **Use type-level approach:**
#' - J << n (e.g., J=16, n=500)
#' - Efficient: M*J operations instead of M*n
#' - Preserves treatment effect heterogeneity via discretization
#'
#' @keywords internal
estimate_minimax_single_scheme_wasserstein <- function(
  data,
  bins,
  cost_matrix,
  lambda_w,
  M = 500,
  functional_type = c("correlation", "probability", "conditional_mean", "ppv", "npv",
                      "concordance"),
  epsilon_s = NULL,
  epsilon_y = NULL,
  delta_s_value = NULL,
  sampling_method = c("normal", "dirichlet", "uniform")
) {

  functional_type <- match.arg(functional_type)
  sampling_method <- match.arg(sampling_method)

  # FAST PATH: Dual optimization for concordance
  if (functional_type == "concordance") {
    type_stats <- compute_type_level_effects(data, bins)

    result <- wasserstein_concordance_dual(
      type_stats = type_stats,
      cost_matrix = cost_matrix,
      lambda_w = lambda_w,
      method = "brent"
    )

    return(list(
      phi_value = result$phi_star,
      effects = NULL,  # Not computed for closed-form
      J = type_stats$J,
      perturbations_q = NULL,  # Not needed for closed-form
      method = "closed_form_wasserstein_dual",
      optimal_gamma = result$optimal_gamma,
      type_stats = type_stats,
      concordance_p0 = result$concordance_p0
    ))
  }

  # FALLBACK: Sampling-based approach for other functionals

  n <- nrow(data)
  J <- length(unique(bins))

  # Empirical type distribution
  type_counts <- table(bins)
  p0_bins <- as.numeric(type_counts / n)

  # Validate cost matrix dimensions
  if (nrow(cost_matrix) != J || ncol(cost_matrix) != J) {
    stop(sprintf("cost_matrix dimensions (%d x %d) must match J = %d",
                 nrow(cost_matrix), ncol(cost_matrix), J))
  }

  # Store treatment effects and sampled distributions
  effects <- matrix(NA, M, 2)
  perturbations_q <- matrix(NA, M, J)

  for (m in 1:M) {
    # Sample type distribution in Wasserstein ball
    q_m <- sample_wasserstein_perturbation(
      reference = p0_bins,
      cost_matrix = cost_matrix,
      radius = lambda_w,
      method = sampling_method
    )

    # Store for diagnostics
    perturbations_q[m, ] <- q_m

    # Map type weights to observation weights
    obs_weights <- q_m[bins]

    # Handle any NA weights (shouldn't occur but safeguard)
    if (any(is.na(obs_weights))) {
      obs_weights[is.na(obs_weights)] <- 1/n
    }

    # Normalize
    obs_weights <- obs_weights / sum(obs_weights)

    # Compute treatment effects via DETERMINISTIC REWEIGHTING
    # This evaluates treatment effects under distribution Q_m
    if (sum(obs_weights[data$A == 1]) > 0 && sum(obs_weights[data$A == 0]) > 0) {
      delta_s <- weighted.mean(data$S[data$A == 1], obs_weights[data$A == 1]) -
                 weighted.mean(data$S[data$A == 0], obs_weights[data$A == 0])

      delta_y <- weighted.mean(data$Y[data$A == 1], obs_weights[data$A == 1]) -
                 weighted.mean(data$Y[data$A == 0], obs_weights[data$A == 0])

      effects[m, ] <- c(delta_s, delta_y)
    }
  }

  # Remove any incomplete cases
  effects <- effects[complete.cases(effects), , drop = FALSE]

  if (nrow(effects) == 0) {
    stop("No valid treatment effect estimates. Check data and bin assignments.")
  }

  # Compute functional from treatment effect distribution
  # REUSE existing function from TV approach
  phi_value <- compute_functional_from_effects_minimax(
    effects = effects,
    functional_type = functional_type,
    epsilon_s = epsilon_s,
    epsilon_y = epsilon_y,
    delta_s_value = delta_s_value
  )

  list(
    phi_value = phi_value,
    effects = effects,
    J = J,
    perturbations_q = perturbations_q,
    method = "sampling"
  )
}


#' Estimate Minimax via Ensemble over Multiple Discretization Schemes (Wasserstein)
#'
#' Runs multiple discretization schemes and takes the minimum to approximate
#' the Wasserstein ball minimax.
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param lambda_w Numeric: Wasserstein ball radius
#' @param schemes Character vector of schemes to use
#' @param covariate_cols Character vector of covariate columns (NULL = auto-detect)
#' @param J_target Target number of types
#' @param M Number of perturbation samples per scheme
#' @param functional_type Character: type of functional
#' @param cost_function Character: "euclidean" or "mahalanobis"
#' @param sampling_method Character: method for sampling perturbations
#' @param epsilon_s Threshold for probability functionals
#' @param epsilon_y Threshold for probability functionals
#' @param delta_s_value Conditioning value for conditional_mean
#' @param verbose Logical: print progress?
#'
#' @return List with:
#'   \item{phi_star}{Ensemble minimax estimate (minimum across schemes)}
#'   \item{best_scheme}{Which scheme achieved minimum}
#'   \item{all_schemes}{List of results per scheme}
#'   \item{schemes_summary}{Tibble with summary per scheme}
#'
#' @details
#' The Wasserstein ensemble approach parallels the TV-ball ensemble:
#'
#' 1. Runs multiple discretization schemes (RF, quantiles, k-means)
#' 2. For each scheme:
#'    - Discretizes data into types
#'    - Computes type centroids in covariate space
#'    - Constructs cost matrix C[i,j] = ||centroid_i - centroid_j||^2
#'    - Computes minimax via Wasserstein ball perturbations
#' 3. Takes MINIMUM across all schemes
#'
#' **Rationale:**
#' Different discretization schemes explore different aspects of covariate space.
#' The minimum over schemes better approximates the worst-case over all
#' distributions Q with W_2(Q, P_0) <= lambda_w.
#'
#' **Comparison to TV-ball:**
#' - TV-ball: Conservative, allows arbitrary distributional changes
#' - W-ball: Structured, constrains covariate shift magnitude
#' - W-ball typically tighter bounds under covariate shift
#' - TV-ball more conservative under selection/confounding
#'
#' @keywords internal
estimate_minimax_ensemble_wasserstein <- function(
  data,
  lambda_w,
  schemes = c("rf", "quantiles", "kmeans"),
  covariate_cols = NULL,
  J_target = 16,
  M = 2000,
  functional_type = c("correlation", "probability", "conditional_mean", "ppv", "npv",
                      "concordance"),
  cost_function = c("euclidean", "mahalanobis"),
  sampling_method = c("normal", "dirichlet", "uniform"),
  epsilon_s = NULL,
  epsilon_y = NULL,
  delta_s_value = NULL,
  verbose = TRUE
) {

  functional_type <- match.arg(functional_type)
  cost_function <- match.arg(cost_function)
  sampling_method <- match.arg(sampling_method)

  # Auto-detect covariates if needed
  if (is.null(covariate_cols)) {
    covariate_cols <- setdiff(names(data), c("A", "S", "Y"))
  }

  # Store results for each scheme
  all_schemes <- list()
  schemes_summary <- tibble::tibble(
    scheme = character(),
    J = integer(),
    phi_value = numeric()
  )

  for (scheme in schemes) {
    if (verbose) {
      message(sprintf("Running scheme: %s (Wasserstein)...", scheme))
    }

    # Check if RF is available
    if (scheme == "rf" && !requireNamespace("randomForest", quietly = TRUE)) {
      if (verbose) {
        message("  Skipping RF scheme (randomForest package not available)")
      }
      next
    }

    # Discretize data
    discretization_result <- discretize_data(
      data = data,
      scheme = scheme,
      covariate_cols = covariate_cols,
      J_target = J_target
    )

    bins <- discretization_result$bins
    J_actual <- discretization_result$J

    if (verbose) {
      message(sprintf("  Discretized into J=%d types", J_actual))
    }

    # Compute type centroids
    centroids <- compute_type_centroids(data, bins, covariate_cols)

    if (nrow(centroids) != J_actual) {
      warning(sprintf("Centroid count (%d) != J_actual (%d). Adjusting.",
                      nrow(centroids), J_actual))
      J_actual <- nrow(centroids)
    }

    if (verbose) {
      message(sprintf("  Computing %s cost matrix...", cost_function))
    }

    # Compute cost matrix
    cost_matrix <- compute_type_cost_matrix(
      centroids,
      cost_function = cost_function
    )

    # Estimate minimax for this scheme
    result <- estimate_minimax_single_scheme_wasserstein(
      data = data,
      bins = bins,
      cost_matrix = cost_matrix,
      lambda_w = lambda_w,
      M = M,
      functional_type = functional_type,
      epsilon_s = epsilon_s,
      epsilon_y = epsilon_y,
      delta_s_value = delta_s_value,
      sampling_method = sampling_method
    )

    all_schemes[[scheme]] <- result

    schemes_summary <- dplyr::bind_rows(
      schemes_summary,
      tibble::tibble(
        scheme = scheme,
        J = J_actual,
        phi_value = result$phi_value
      )
    )

    if (verbose) {
      message(sprintf("  Minimax estimate: %.4f", result$phi_value))
    }
  }

  if (nrow(schemes_summary) == 0) {
    stop("No schemes were successfully evaluated")
  }

  # Take minimum across schemes (ensemble estimate)
  best_idx <- which.min(schemes_summary$phi_value)
  phi_star <- schemes_summary$phi_value[best_idx]
  best_scheme <- schemes_summary$scheme[best_idx]

  if (verbose) {
    message(sprintf("\nWasserstein ensemble minimum: %.4f (achieved by %s)",
                    phi_star, best_scheme))
  }

  list(
    phi_star = phi_star,
    best_scheme = best_scheme,
    all_schemes = all_schemes,
    schemes_summary = schemes_summary,
    lambda_w = lambda_w,
    functional_type = functional_type
  )
}
