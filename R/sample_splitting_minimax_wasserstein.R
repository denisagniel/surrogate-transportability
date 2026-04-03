#' Sample Splitting Minimax Inference with Provable Coverage
#'
#' Implements minimax inference for Wasserstein DRO using sample splitting
#' to eliminate post-selection bias. Provides provable asymptotic coverage
#' guarantees under stated regularity conditions.
#'
#' @name sample_splitting_minimax
NULL

#' Sample Splitting for Wasserstein Minimax with Coverage Guarantees
#'
#' Splits data into independent identification (D1) and inference (D2) samples.
#' D1 finds the worst-case region (optimal gamma*), D2 performs inference
#' in that region without selection bias.
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param covariates Character vector: covariate column names
#' @param lambda_w Numeric: Wasserstein ball radius
#' @param split_ratio Numeric in (0,1): proportion of data for D1 (default 0.5)
#' @param tau_method Character: method for estimating treatment effects
#'   ("kernel", "rf", "gam", "linear")
#' @param cross_fit Logical: use cross-fitting within each split?
#' @param cost_function Character: "euclidean" or "manhattan"
#' @param scale_covariates Logical: standardize covariates before computing distances?
#' @param seed Integer: random seed for split (NULL = no seed)
#'
#' @return List with:
#'   \item{phi_star}{Minimax concordance estimate (from D2)}
#'   \item{optimal_gamma_d1}{Optimal gamma found on D1}
#'   \item{optimal_gamma_d2}{Optimal gamma found on D2 (for comparison)}
#'   \item{concordance_d2}{Concordances in D2 (used for inference)}
#'   \item{n_d1}{Sample size in D1}
#'   \item{n_d2}{Sample size in D2}
#'   \item{split_ratio}{Split ratio used}
#'   \item{method}{Character: "sample_splitting"}
#'
#' @details
#' **Core Innovation:** Eliminate post-selection bias by splitting data.
#'
#' **Algorithm:**
#' 1. Split data: D1 (identification), D2 (inference) — independent samples
#' 2. D1: Find worst-case region → optimal dual variable γ* via Wasserstein DRO
#' 3. D2: Estimate concordance in that region (independent of D1 selection!)
#' 4. Bootstrap CI on D2 only (no selection bias)
#'
#' **Theoretical Guarantees (see methods/proofs/theorem1_sample_splitting.tex):**
#'
#' Under regularity conditions (smoothness, bounded moments, overlap):
#' - Consistency: φ̂_split →^p φ*(λ_w)
#' - Asymptotic normality: √n₂(φ̂_split - φ*) →^d N(0, σ²)
#' - Bootstrap validity: Bootstrap on D2 is consistent
#' - Coverage guarantee: P(φ* ∈ CI) → 1-α
#'
#' **Key Advantage:** D1 and D2 are independent, so no post-selection bias.
#' Standard M-estimation theory applies directly to D2.
#'
#' **Trade-off:** Lose half the data → wider CIs, less power.
#' But provable validity makes this worthwhile for inference.
#'
#' **Why This Works:**
#' - Selection (finding γ*) happens on D1
#' - Inference (estimating φ*) happens on D2
#' - D1 ⊥ D2 → selection doesn't affect D2 inference
#' - Classical bootstrap theory applies to D2
#'
#' **Comparison to alternatives:**
#' - No shrinkage needed (no ad-hoc tuning)
#' - No quantile selection (direct minimax estimand)
#' - No smoothing bias (exact minimum, not approximation)
#' - Cleanest theory (standard M-estimation)
#'
#' @references
#' van der Vaart, A. W., & Wellner, J. A. (1996). Weak Convergence and
#' Empirical Processes. Springer.
#'
#' Chernozhukov, V., et al. (2018). Double/debiased machine learning for
#' treatment and structural parameters. The Econometrics Journal.
#'
#' @examples
#' \dontrun{
#' # Generate example data
#' data <- generate_study_data(n = 500)
#'
#' # Sample splitting minimax (50-50 split)
#' result <- sample_splitting_minimax_wasserstein(
#'   data = data,
#'   covariates = c("X1", "X2"),
#'   lambda_w = 0.5,
#'   split_ratio = 0.5
#' )
#'
#' cat(sprintf("Minimax concordance: %.4f\n", result$phi_star))
#' cat(sprintf("Optimal gamma (D1): %.4f\n", result$optimal_gamma_d1))
#' cat(sprintf("Sample sizes: n1=%d, n2=%d\n", result$n_d1, result$n_d2))
#'
#' # Bootstrap CI (on D2 only)
#' ci_result <- bootstrap_ci_sample_splitting(
#'   data = data,
#'   covariates = c("X1", "X2"),
#'   lambda_w = 0.5,
#'   split_ratio = 0.5,
#'   n_bootstrap = 500,
#'   confidence_level = 0.95
#' )
#'
#' cat(sprintf("95%% CI: [%.4f, %.4f]\n",
#'             ci_result$ci_lower, ci_result$ci_upper))
#' }
#'
#' @export
sample_splitting_minimax_wasserstein <- function(data,
                                                  covariates,
                                                  lambda_w,
                                                  split_ratio = 0.5,
                                                  tau_method = c("kernel", "rf", "gam", "linear"),
                                                  cross_fit = TRUE,
                                                  cost_function = c("euclidean", "manhattan"),
                                                  scale_covariates = TRUE,
                                                  seed = NULL) {

  tau_method <- match.arg(tau_method)
  cost_function <- match.arg(cost_function)

  # Validate inputs
  if (!is.numeric(split_ratio) || split_ratio <= 0 || split_ratio >= 1) {
    stop("split_ratio must be in (0, 1)")
  }

  if (!is.numeric(lambda_w) || lambda_w < 0) {
    stop("lambda_w must be non-negative")
  }

  required_cols <- c("A", "S", "Y", covariates)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Required columns missing: ", paste(missing_cols, collapse = ", "))
  }

  n <- nrow(data)

  # Set seed for reproducible split
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Step 1: Split data into D1 (identification) and D2 (inference)
  split_result <- split_data(data, split_ratio = split_ratio)
  data_d1 <- split_result$d1
  data_d2 <- split_result$d2
  n_d1 <- nrow(data_d1)
  n_d2 <- nrow(data_d2)

  message(sprintf("Sample split: n1 = %d (identification), n2 = %d (inference)",
                  n_d1, n_d2))

  # Step 2: D1 - Identification phase (find optimal gamma*)
  message("D1: Finding worst-case region (optimal gamma*)...")
  d1_result <- identify_worst_case_d1(
    data = data_d1,
    covariates = covariates,
    lambda_w = lambda_w,
    tau_method = tau_method,
    cross_fit = cross_fit,
    cost_function = cost_function,
    scale_covariates = scale_covariates
  )

  optimal_gamma_d1 <- d1_result$optimal_gamma
  message(sprintf("  Optimal gamma* (D1): %.4f", optimal_gamma_d1))

  # Step 3: D2 - Inference phase (estimate concordance using gamma* from D1)
  message("D2: Estimating concordance in worst-case region...")
  d2_result <- infer_on_d2(
    data = data_d2,
    covariates = covariates,
    lambda_w = lambda_w,
    gamma_from_d1 = optimal_gamma_d1,
    tau_method = tau_method,
    cross_fit = cross_fit,
    cost_function = cost_function,
    scale_covariates = scale_covariates
  )

  phi_star <- d2_result$phi_star
  message(sprintf("  Minimax concordance (D2): %.4f", phi_star))

  # For comparison: optimal gamma on D2 (should be similar if n large)
  optimal_gamma_d2 <- d2_result$optimal_gamma_d2

  list(
    phi_star = phi_star,
    optimal_gamma_d1 = optimal_gamma_d1,
    optimal_gamma_d2 = optimal_gamma_d2,
    concordance_d2 = d2_result$concordance_d2,
    tau_s_d2 = d2_result$tau_s_d2,
    tau_y_d2 = d2_result$tau_y_d2,
    n_d1 = n_d1,
    n_d2 = n_d2,
    split_ratio = split_ratio,
    lambda_w = lambda_w,
    method = "sample_splitting",
    tau_method = tau_method,
    cross_fitted = cross_fit
  )
}


#' Split Data into D1 (Identification) and D2 (Inference)
#'
#' Randomly splits data into two independent samples for sample splitting.
#'
#' @param data Data frame to split
#' @param split_ratio Numeric: proportion for D1 (identification sample)
#'
#' @return List with d1 and d2 data frames
#'
#' @details
#' Creates a random split of the data. The split is stratified by treatment
#' if treatment is binary to maintain balance.
#'
#' @keywords internal
split_data <- function(data, split_ratio = 0.5) {

  n <- nrow(data)
  n_d1 <- floor(n * split_ratio)

  # Stratified split by treatment (if binary)
  if ("A" %in% names(data) && all(data$A %in% c(0, 1))) {
    # Stratify by treatment
    idx_treated <- which(data$A == 1)
    idx_control <- which(data$A == 0)

    n_treated <- length(idx_treated)
    n_control <- length(idx_control)

    n_d1_treated <- floor(n_treated * split_ratio)
    n_d1_control <- floor(n_control * split_ratio)

    d1_treated_idx <- sample(idx_treated, size = n_d1_treated, replace = FALSE)
    d1_control_idx <- sample(idx_control, size = n_d1_control, replace = FALSE)

    d1_idx <- c(d1_treated_idx, d1_control_idx)
    d2_idx <- setdiff(1:n, d1_idx)

  } else {
    # Simple random split
    d1_idx <- sample(1:n, size = n_d1, replace = FALSE)
    d2_idx <- setdiff(1:n, d1_idx)
  }

  list(
    d1 = data[d1_idx, ],
    d2 = data[d2_idx, ]
  )
}


#' Identify Worst-Case Region on D1 (Identification Sample)
#'
#' Finds optimal Wasserstein dual variable (gamma*) on identification sample.
#'
#' @param data Data frame (D1 identification sample)
#' @param covariates Character vector: covariate names
#' @param lambda_w Numeric: Wasserstein radius
#' @param tau_method Character: treatment effect estimation method
#' @param cross_fit Logical: use cross-fitting?
#' @param cost_function Character: distance metric
#' @param scale_covariates Logical: standardize covariates?
#'
#' @return List with optimal_gamma, concordance_d1, tau_s_d1, tau_y_d1
#'
#' @details
#' This is the identification phase. We estimate treatment effects and
#' find the worst-case perturbation (optimal gamma*) on D1.
#'
#' This gamma* will be used on D2 for inference, so D2 inference is
#' independent of D1 selection.
#'
#' @keywords internal
identify_worst_case_d1 <- function(data,
                                    covariates,
                                    lambda_w,
                                    tau_method,
                                    cross_fit,
                                    cost_function,
                                    scale_covariates) {

  n <- nrow(data)

  # Estimate treatment effects on D1
  tau_s_result <- estimate_treatment_effect_function(
    data = data,
    outcome = "S",
    covariates = covariates,
    method = tau_method,
    cross_fit = cross_fit
  )

  tau_y_result <- estimate_treatment_effect_function(
    data = data,
    outcome = "Y",
    covariates = covariates,
    method = tau_method,
    cross_fit = cross_fit
  )

  tau_s <- tau_s_result$tau_hat
  tau_y <- tau_y_result$tau_hat
  concordance <- tau_s * tau_y

  # Build cost matrix
  X <- as.matrix(data[, covariates, drop = FALSE])

  if (scale_covariates) {
    X <- scale(X)
  }

  if (cost_function == "euclidean") {
    cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2
  } else if (cost_function == "manhattan") {
    cost_matrix <- as.matrix(dist(X, method = "manhattan"))
  }

  # Solve Wasserstein DRO dual to find optimal gamma*
  dual_objective <- function(gamma) {
    obj_matrix <- matrix(concordance, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  opt_result <- optimize(
    f = dual_objective,
    interval = c(0, 100),
    maximum = TRUE,
    tol = 1e-6
  )

  list(
    optimal_gamma = opt_result$maximum,
    phi_star_d1 = opt_result$objective,
    concordance_d1 = concordance,
    tau_s_d1 = tau_s,
    tau_y_d1 = tau_y,
    cost_matrix_d1 = cost_matrix
  )
}


#' Inference on D2 Using Gamma* from D1
#'
#' Estimates concordance on inference sample D2 using the worst-case
#' region (gamma*) identified on D1.
#'
#' @param data Data frame (D2 inference sample)
#' @param covariates Character vector: covariate names
#' @param lambda_w Numeric: Wasserstein radius
#' @param gamma_from_d1 Numeric: optimal gamma found on D1
#' @param tau_method Character: treatment effect estimation method
#' @param cross_fit Logical: use cross-fitting?
#' @param cost_function Character: distance metric
#' @param scale_covariates Logical: standardize covariates?
#'
#' @return List with phi_star, concordance_d2, tau_s_d2, tau_y_d2
#'
#' @details
#' This is the inference phase. We estimate treatment effects and compute
#' the concordance on D2, using gamma* from D1.
#'
#' Since D1 and D2 are independent, there is NO selection bias here.
#' Standard inference theory applies.
#'
#' We also compute the optimal gamma on D2 for comparison/diagnostics.
#'
#' @keywords internal
infer_on_d2 <- function(data,
                        covariates,
                        lambda_w,
                        gamma_from_d1,
                        tau_method,
                        cross_fit,
                        cost_function,
                        scale_covariates) {

  n <- nrow(data)

  # Estimate treatment effects on D2
  tau_s_result <- estimate_treatment_effect_function(
    data = data,
    outcome = "S",
    covariates = covariates,
    method = tau_method,
    cross_fit = cross_fit
  )

  tau_y_result <- estimate_treatment_effect_function(
    data = data,
    outcome = "Y",
    covariates = covariates,
    method = tau_method,
    cross_fit = cross_fit
  )

  tau_s <- tau_s_result$tau_hat
  tau_y <- tau_y_result$tau_hat
  concordance <- tau_s * tau_y

  # Build cost matrix for D2
  X <- as.matrix(data[, covariates, drop = FALSE])

  if (scale_covariates) {
    X <- scale(X)
  }

  if (cost_function == "euclidean") {
    cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2
  } else if (cost_function == "manhattan") {
    cost_matrix <- as.matrix(dist(X, method = "manhattan"))
  }

  # Evaluate dual objective at gamma* from D1
  dual_objective <- function(gamma) {
    obj_matrix <- matrix(concordance, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix
    inner_mins <- apply(obj_matrix, 1, min)
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  phi_star <- dual_objective(gamma_from_d1)

  # For comparison: also find optimal gamma on D2
  opt_result_d2 <- optimize(
    f = dual_objective,
    interval = c(0, 100),
    maximum = TRUE,
    tol = 1e-6
  )

  list(
    phi_star = phi_star,
    optimal_gamma_d2 = opt_result_d2$maximum,
    phi_star_at_d2_gamma = opt_result_d2$objective,
    concordance_d2 = concordance,
    tau_s_d2 = tau_s,
    tau_y_d2 = tau_y,
    cost_matrix_d2 = cost_matrix
  )
}


#' Bootstrap Confidence Interval for Sample Splitting Minimax
#'
#' Computes bootstrap CI by resampling D2 only (no selection bias).
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param covariates Character vector: covariate names
#' @param lambda_w Numeric: Wasserstein radius
#' @param split_ratio Numeric: proportion for D1
#' @param tau_method Character: treatment effect estimation method
#' @param cross_fit Logical: use cross-fitting within splits?
#' @param cost_function Character: distance metric
#' @param scale_covariates Logical: standardize covariates?
#' @param n_bootstrap Integer: number of bootstrap samples
#' @param confidence_level Numeric: confidence level (default 0.95)
#' @param seed Integer: random seed for main split (NULL = no seed)
#' @param parallel Logical: use parallel processing?
#' @param verbose Logical: print progress?
#'
#' @return List with phi_star, ci_lower, ci_upper, bootstrap_estimates,
#'   n_d1, n_d2, optimal_gamma_d1
#'
#' @details
#' **Bootstrap Strategy:**
#' 1. Split original data once: D1, D2
#' 2. Find gamma* on D1 (fixed across bootstrap)
#' 3. Bootstrap D2 only (resample with replacement)
#' 4. For each bootstrap sample, estimate concordance using gamma* from D1
#' 5. Percentile CI from bootstrap distribution
#'
#' **Why this works:**
#' - Selection (gamma*) happens once on D1
#' - Bootstrap resamples D2 only
#' - Each bootstrap sample is independent of selection
#' - Standard bootstrap theory applies (no post-selection bias)
#'
#' @examples
#' \dontrun{
#' result <- bootstrap_ci_sample_splitting(
#'   data = mydata,
#'   covariates = c("X1", "X2"),
#'   lambda_w = 0.5,
#'   n_bootstrap = 500
#' )
#'
#' cat(sprintf("Estimate: %.4f\n", result$phi_star))
#' cat(sprintf("95%% CI: [%.4f, %.4f]\n",
#'             result$ci_lower, result$ci_upper))
#' }
#'
#' @export
bootstrap_ci_sample_splitting <- function(data,
                                           covariates,
                                           lambda_w,
                                           split_ratio = 0.5,
                                           tau_method = c("kernel", "rf", "gam", "linear"),
                                           cross_fit = TRUE,
                                           cost_function = c("euclidean", "manhattan"),
                                           scale_covariates = TRUE,
                                           n_bootstrap = 500,
                                           confidence_level = 0.95,
                                           seed = NULL,
                                           parallel = FALSE,
                                           verbose = TRUE) {

  tau_method <- match.arg(tau_method)
  cost_function <- match.arg(cost_function)

  if (verbose) {
    message("========================================")
    message("Sample Splitting Bootstrap CI")
    message("========================================")
    message(sprintf("n = %d", nrow(data)))
    message(sprintf("Split ratio: %.2f", split_ratio))
    message(sprintf("Lambda_w: %.3f", lambda_w))
    message(sprintf("Bootstrap samples: %d", n_bootstrap))
    message("")
  }

  # Step 1: Initial split (D1 for identification, D2 for inference)
  if (!is.null(seed)) {
    set.seed(seed)
  }

  split_result <- split_data(data, split_ratio = split_ratio)
  data_d1 <- split_result$d1
  data_d2 <- split_result$d2
  n_d1 <- nrow(data_d1)
  n_d2 <- nrow(data_d2)

  if (verbose) {
    message(sprintf("Initial split: n1=%d, n2=%d", n_d1, n_d2))
  }

  # Step 2: Find optimal gamma* on D1 (fixed for all bootstrap samples)
  if (verbose) {
    message("Identifying worst-case region on D1...")
  }

  d1_result <- identify_worst_case_d1(
    data = data_d1,
    covariates = covariates,
    lambda_w = lambda_w,
    tau_method = tau_method,
    cross_fit = cross_fit,
    cost_function = cost_function,
    scale_covariates = scale_covariates
  )

  optimal_gamma_d1 <- d1_result$optimal_gamma

  if (verbose) {
    message(sprintf("  Optimal gamma* (D1): %.4f", optimal_gamma_d1))
    message("")
  }

  # Step 3: Point estimate on D2
  if (verbose) {
    message("Computing point estimate on D2...")
  }

  d2_result <- infer_on_d2(
    data = data_d2,
    covariates = covariates,
    lambda_w = lambda_w,
    gamma_from_d1 = optimal_gamma_d1,
    tau_method = tau_method,
    cross_fit = cross_fit,
    cost_function = cost_function,
    scale_covariates = scale_covariates
  )

  phi_star <- d2_result$phi_star

  if (verbose) {
    message(sprintf("  Point estimate: %.4f", phi_star))
    message("")
    message(sprintf("Bootstrapping D2 (%d samples)...", n_bootstrap))
  }

  # Step 4: Bootstrap D2 only
  bootstrap_estimates <- numeric(n_bootstrap)

  run_bootstrap_iter <- function(b) {
    if (verbose && (b %% 50 == 0 || b == 1)) {
      message(sprintf("  Bootstrap %d/%d", b, n_bootstrap))
    }

    # Resample D2 with replacement
    boot_idx <- sample(1:n_d2, size = n_d2, replace = TRUE)
    boot_data_d2 <- data_d2[boot_idx, ]

    # Estimate on bootstrap sample using gamma* from D1
    boot_result <- tryCatch({
      infer_on_d2(
        data = boot_data_d2,
        covariates = covariates,
        lambda_w = lambda_w,
        gamma_from_d1 = optimal_gamma_d1,  # Fixed from D1
        tau_method = tau_method,
        cross_fit = FALSE,  # Faster for bootstrap
        cost_function = cost_function,
        scale_covariates = scale_covariates
      )
    }, error = function(e) {
      if (verbose) {
        message(sprintf("    Bootstrap %d failed: %s", b, conditionMessage(e)))
      }
      list(phi_star = NA)
    })

    boot_result$phi_star
  }

  # Run bootstrap (parallel or sequential)
  if (parallel && requireNamespace("furrr", quietly = TRUE) &&
      requireNamespace("future", quietly = TRUE)) {

    if (verbose) message("  Using parallel processing...")

    # Set up parallel
    slurm_cpus <- Sys.getenv("SLURM_CPUS_PER_TASK", unset = "")
    if (slurm_cpus != "") {
      n_workers <- as.integer(slurm_cpus)
    } else if (requireNamespace("parallelly", quietly = TRUE)) {
      n_workers <- parallelly::availableCores()
    } else {
      n_workers <- 2
    }
    future::plan(future::multisession, workers = n_workers)

    bootstrap_estimates <- furrr::future_map_dbl(
      1:n_bootstrap,
      run_bootstrap_iter,
      .options = furrr::furrr_options(seed = TRUE)
    )

    future::plan(future::sequential)

  } else {
    # Sequential
    for (b in 1:n_bootstrap) {
      bootstrap_estimates[b] <- run_bootstrap_iter(b)
    }
  }

  # Remove failed bootstrap samples
  bootstrap_estimates <- bootstrap_estimates[!is.na(bootstrap_estimates)]
  n_successful <- length(bootstrap_estimates)

  if (n_successful < n_bootstrap * 0.9) {
    warning(sprintf("Only %d/%d bootstrap samples successful",
                    n_successful, n_bootstrap))
  }

  # Step 5: Percentile CI
  alpha <- 1 - confidence_level
  ci <- quantile(bootstrap_estimates, probs = c(alpha/2, 1 - alpha/2), na.rm = TRUE)

  ci_lower <- as.numeric(ci[1])
  ci_upper <- as.numeric(ci[2])

  if (verbose) {
    message("")
    message("========================================")
    message("Results:")
    message(sprintf("  Point estimate: %.4f", phi_star))
    message(sprintf("  %g%% CI: [%.4f, %.4f]",
                    100 * confidence_level, ci_lower, ci_upper))
    message(sprintf("  CI width: %.4f", ci_upper - ci_lower))
    message(sprintf("  Bootstrap samples: %d/%d successful",
                    n_successful, n_bootstrap))
    message("========================================")
  }

  list(
    phi_star = phi_star,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    ci_width = ci_upper - ci_lower,
    bootstrap_estimates = bootstrap_estimates,
    n_bootstrap = n_bootstrap,
    n_successful = n_successful,
    confidence_level = confidence_level,
    optimal_gamma_d1 = optimal_gamma_d1,
    optimal_gamma_d2 = d2_result$optimal_gamma_d2,
    n_d1 = n_d1,
    n_d2 = n_d2,
    split_ratio = split_ratio,
    lambda_w = lambda_w,
    method = "sample_splitting",
    tau_method = tau_method
  )
}
