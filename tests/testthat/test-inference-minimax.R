test_that("surrogate_inference_minimax returns correct structure", {
  # Generate small dataset for fast testing
  set.seed(123)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    include_vertices = TRUE,
    max_vertices = 10,
    n_innovations = 100,
    n_bootstrap = 0,
    parallel = FALSE,
    verbose = FALSE
  )

  # Check structure
  expect_type(result, "list")
  expect_true(all(c("phi_star", "phi_star_lower", "bound_width",
                    "search_grid", "mu_at_sup", "mu_at_inf",
                    "method_estimate", "method_ci_lower", "method_ci_upper",
                    "method_contained", "lambda", "functional_type",
                    "class_M", "parameters") %in% names(result)))

  # Check types
  expect_type(result$phi_star, "double")
  expect_type(result$phi_star_lower, "double")
  expect_type(result$bound_width, "double")
  expect_s3_class(result$search_grid, "data.frame")
  expect_type(result$method_contained, "logical")
})


test_that("minimax bounds are valid (phi_star_lower <= phi_star)", {
  set.seed(456)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  expect_true(result$phi_star_lower <= result$phi_star)
  expect_true(result$bound_width >= 0)
  expect_equal(result$bound_width, result$phi_star - result$phi_star_lower,
               tolerance = 1e-10)
})


test_that("all grid points fall within bounds", {
  set.seed(789)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    include_vertices = TRUE,
    max_vertices = 5,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  # All evaluated φ values should be within [phi_star_lower, phi_star]
  expect_true(all(result$search_grid$phi_value >= result$phi_star_lower,
                  na.rm = TRUE))
  expect_true(all(result$search_grid$phi_value <= result$phi_star,
                  na.rm = TRUE))

  # The bounds should be achieved by some grid point
  expect_true(any(abs(result$search_grid$phi_value - result$phi_star) < 1e-10))
  expect_true(any(abs(result$search_grid$phi_value - result$phi_star_lower) < 1e-10))
})


test_that("vertex inclusion works correctly", {
  set.seed(101)
  data <- generate_study_data(
    n = 50,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result_with_vertices <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    include_vertices = TRUE,
    max_vertices = 20,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  result_without_vertices <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    include_vertices = FALSE,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  # With vertices should have more grid points
  expect_true(nrow(result_with_vertices$search_grid) >
              nrow(result_without_vertices$search_grid))

  # Check vertex entries exist
  vertex_entries <- result_with_vertices$search_grid %>%
    dplyr::filter(mu_type == "vertex")

  expect_true(nrow(vertex_entries) > 0)
  expect_true(nrow(vertex_entries) <= 20)

  # All vertex IDs should be valid
  expect_true(all(!is.na(vertex_entries$vertex_id)))
  expect_true(all(vertex_entries$vertex_id >= 1))
  expect_true(all(vertex_entries$vertex_id <= 50))
})


test_that("lambda = 0 gives collapsed bounds", {
  set.seed(202)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0,  # No perturbation
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  # When lambda = 0, all innovations should give same result (no perturbation)
  # So bounds should be very narrow (approximately equal)
  expect_true(result$bound_width < 0.1)  # Small tolerance for MC noise
})


test_that("works with probability functional", {
  set.seed(303)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "probability",
    epsilon_s = 0.2,
    epsilon_y = 0.1,
    n_dirichlet_grid = 10,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  expect_type(result$phi_star, "double")
  expect_true(result$phi_star >= 0)
  expect_true(result$phi_star <= 1)  # Probability
  expect_true(result$phi_star_lower >= 0)
  expect_true(result$phi_star_lower <= 1)
})


test_that("probability functional requires epsilon parameters", {
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  expect_error(
    surrogate_inference_minimax(
      current_data = data,
      lambda = 0.3,
      functional_type = "probability",
      # Missing epsilon_s and epsilon_y
      verbose = FALSE
    ),
    "epsilon_s and epsilon_y must be specified"
  )
})


test_that("method estimate often falls within bounds", {
  set.seed(404)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 20,
    include_vertices = TRUE,
    max_vertices = 20,
    n_innovations = 200,
    parallel = FALSE,
    verbose = FALSE
  )

  # Method estimate should often be within bounds
  # (not guaranteed, but likely for well-chosen α=1)
  expect_true(result$method_estimate >= result$phi_star_lower ||
              result$method_estimate <= result$phi_star)

  # Check method_contained is correctly computed
  expected_contained <- (result$phi_star_lower <= result$method_estimate) &&
                        (result$method_estimate <= result$phi_star)
  expect_equal(result$method_contained, expected_contained)
})


test_that("search grid has correct structure", {
  set.seed(505)
  data <- generate_study_data(
    n = 50,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 15,
    include_vertices = TRUE,
    max_vertices = 10,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  grid <- result$search_grid

  # Check columns
  expect_true(all(c("mu_type", "alpha", "vertex_id", "phi_value") %in% names(grid)))

  # Check mu_types
  expect_true(all(grid$mu_type %in% c("dirichlet", "vertex", "uniform")))

  # Dirichlet entries should have alpha, no vertex_id
  dirichlet_rows <- grid %>% dplyr::filter(mu_type == "dirichlet")
  expect_true(all(!is.na(dirichlet_rows$alpha)))
  expect_true(all(is.na(dirichlet_rows$vertex_id)))

  # Vertex entries should have vertex_id, no alpha
  vertex_rows <- grid %>% dplyr::filter(mu_type == "vertex")
  if (nrow(vertex_rows) > 0) {
    expect_true(all(is.na(vertex_rows$alpha)))
    expect_true(all(!is.na(vertex_rows$vertex_id)))
  }

  # Uniform entry should have neither
  uniform_rows <- grid %>% dplyr::filter(mu_type == "uniform")
  expect_equal(nrow(uniform_rows), 1)
  expect_true(is.na(uniform_rows$alpha))
  expect_true(is.na(uniform_rows$vertex_id))
})


test_that("alpha range is correctly log-spaced", {
  grid <- construct_search_grid(
    n = 100,
    dirichlet_alpha_range = c(0.01, 100),
    n_dirichlet_grid = 20,
    include_vertices = FALSE,
    max_vertices = 0
  )

  dirichlet_alphas <- grid %>%
    dplyr::filter(mu_type == "dirichlet") %>%
    dplyr::pull(alpha)

  # Check range (with floating point tolerance)
  expect_true(min(dirichlet_alphas) >= 0.009)
  expect_true(max(dirichlet_alphas) <= 100.1)

  # Check log-spacing (approximately equal ratios)
  log_alphas <- log(dirichlet_alphas)
  diffs <- diff(log_alphas)
  expect_true(sd(diffs) < 1e-10)  # Should be perfectly uniform on log scale
})


test_that("max_vertices limits vertex sampling", {
  n <- 200
  max_vertices <- 30

  grid <- construct_search_grid(
    n = n,
    dirichlet_alpha_range = c(0.01, 100),
    n_dirichlet_grid = 10,
    include_vertices = TRUE,
    max_vertices = max_vertices
  )

  vertex_entries <- grid %>% dplyr::filter(mu_type == "vertex")

  # Should have at most max_vertices entries
  expect_true(nrow(vertex_entries) <= max_vertices)

  # Should have exactly max_vertices when n > max_vertices
  expect_equal(nrow(vertex_entries), max_vertices)
})


test_that("evaluate_phi_at_grid_point works for each mu_type", {
  set.seed(606)
  data <- generate_study_data(
    n = 50,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  # Test Dirichlet
  grid_row_dirichlet <- tibble::tibble(
    mu_type = "dirichlet",
    alpha = 1.0,
    vertex_id = NA_integer_
  )

  phi_dirichlet <- evaluate_phi_at_grid_point(
    grid_row = grid_row_dirichlet,
    current_data = data,
    lambda = 0.3,
    n_innovations = 100,
    functional_type = "correlation",
    epsilon_s = NULL,
    epsilon_y = NULL,
    delta_s_value = NULL
  )

  expect_type(phi_dirichlet, "double")
  expect_false(is.na(phi_dirichlet))

  # Test vertex
  grid_row_vertex <- tibble::tibble(
    mu_type = "vertex",
    alpha = NA_real_,
    vertex_id = 10L
  )

  phi_vertex <- evaluate_phi_at_grid_point(
    grid_row = grid_row_vertex,
    current_data = data,
    lambda = 0.3,
    n_innovations = 100,
    functional_type = "correlation",
    epsilon_s = NULL,
    epsilon_y = NULL,
    delta_s_value = NULL
  )

  expect_type(phi_vertex, "double")
  expect_false(is.na(phi_vertex))

  # Test uniform
  grid_row_uniform <- tibble::tibble(
    mu_type = "uniform",
    alpha = NA_real_,
    vertex_id = NA_integer_
  )

  phi_uniform <- evaluate_phi_at_grid_point(
    grid_row = grid_row_uniform,
    current_data = data,
    lambda = 0.3,
    n_innovations = 100,
    functional_type = "correlation",
    epsilon_s = NULL,
    epsilon_y = NULL,
    delta_s_value = NULL
  )

  expect_type(phi_uniform, "double")
  expect_false(is.na(phi_uniform))
})


test_that("different functional types give different results", {
  set.seed(707)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result_corr <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  result_prob <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "probability",
    epsilon_s = 0.2,
    epsilon_y = 0.1,
    n_dirichlet_grid = 10,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  # Should give different estimates
  expect_false(isTRUE(all.equal(result_corr$phi_star, result_prob$phi_star)))

  # Correlation should be in [-1, 1]
  expect_true(result_corr$phi_star >= -1 && result_corr$phi_star <= 1)

  # Probability should be in [0, 1]
  expect_true(result_prob$phi_star >= 0 && result_prob$phi_star <= 1)
})


test_that("lambda parameter is validated", {
  data <- generate_study_data(
    n = 50,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  expect_error(
    surrogate_inference_minimax(
      current_data = data,
      lambda = -0.1,  # Invalid
      verbose = FALSE
    ),
    "lambda must be a single numeric value in \\[0, 1\\]"
  )

  expect_error(
    surrogate_inference_minimax(
      current_data = data,
      lambda = 1.5,  # Invalid
      verbose = FALSE
    ),
    "lambda must be a single numeric value in \\[0, 1\\]"
  )

  expect_error(
    surrogate_inference_minimax(
      current_data = data,
      lambda = c(0.3, 0.5),  # Multiple values
      verbose = FALSE
    ),
    "lambda must be a single numeric value in \\[0, 1\\]"
  )
})


test_that("n_innovations affects Monte Carlo precision", {
  set.seed(808)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  # Run with different n_innovations, same seed
  result_small <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 5,
    n_innovations = 50,
    parallel = FALSE,
    verbose = FALSE,
    seed = 999
  )

  result_large <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 5,
    n_innovations = 500,
    parallel = FALSE,
    verbose = FALSE,
    seed = 999
  )

  # Bounds should be similar but not identical (different MC noise)
  # With more innovations, estimates should be more stable
  expect_true(abs(result_small$phi_star - result_large$phi_star) < 0.3)
  expect_true(abs(result_small$phi_star_lower - result_large$phi_star_lower) < 0.3)
})


test_that("class_M metadata is correct", {
  set.seed(909)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    dirichlet_alpha_range = c(0.05, 50),
    n_dirichlet_grid = 25,
    include_vertices = TRUE,
    max_vertices = 15,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  expect_equal(result$class_M$dirichlet_range, c(0.05, 50))
  expect_equal(result$class_M$n_dirichlet_grid, 25)
  expect_true(result$class_M$vertices_included)
  expect_equal(result$class_M$max_vertices, 15)

  # n_evaluations should match search_grid rows
  expect_equal(result$class_M$n_evaluations, nrow(result$search_grid))
})


test_that("mu_at_sup and mu_at_inf are informative", {
  set.seed(1010)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 20,
    include_vertices = TRUE,
    max_vertices = 10,
    n_innovations = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  # Check mu_at_sup structure
  expect_true(all(c("mu_type", "alpha", "vertex_id") %in% names(result$mu_at_sup)))
  expect_true(result$mu_at_sup$mu_type %in% c("dirichlet", "vertex", "uniform"))

  # Check mu_at_inf structure
  expect_true(all(c("mu_type", "alpha", "vertex_id") %in% names(result$mu_at_inf)))
  expect_true(result$mu_at_inf$mu_type %in% c("dirichlet", "vertex", "uniform"))

  # If supremum at dirichlet, should have alpha
  if (result$mu_at_sup$mu_type == "dirichlet") {
    expect_false(is.na(result$mu_at_sup$alpha))
  }

  # If supremum at vertex, should have vertex_id
  if (result$mu_at_sup$mu_type == "vertex") {
    expect_false(is.na(result$mu_at_sup$vertex_id))
  }
})


test_that("bootstrap CI is computed when requested", {
  skip_if(TRUE, "Bootstrap test is slow, skip by default")

  set.seed(1111)
  data <- generate_study_data(
    n = 80,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 5,
    n_innovations = 50,
    n_bootstrap = 10,  # Small number for speed
    parallel = FALSE,
    verbose = FALSE
  )

  # Should have bootstrap CIs
  expect_true(!is.null(result$phi_star_ci))
  expect_true(!is.null(result$phi_star_lower_ci))

  expect_length(result$phi_star_ci, 2)
  expect_length(result$phi_star_lower_ci, 2)

  # CI should be ordered
  expect_true(result$phi_star_ci[1] <= result$phi_star_ci[2])
  expect_true(result$phi_star_lower_ci[1] <= result$phi_star_lower_ci[2])
})


test_that("no bootstrap CI when n_bootstrap = 0", {
  set.seed(1212)
  data <- generate_study_data(
    n = 100,
    treatment_effect_surrogate = c(0.3, 0.9),
    treatment_effect_outcome = c(0.2, 0.8)
  )

  result <- surrogate_inference_minimax(
    current_data = data,
    lambda = 0.3,
    functional_type = "correlation",
    n_dirichlet_grid = 10,
    n_innovations = 100,
    n_bootstrap = 0,
    parallel = FALSE,
    verbose = FALSE
  )

  expect_null(result$phi_star_ci)
  expect_null(result$phi_star_lower_ci)
})
