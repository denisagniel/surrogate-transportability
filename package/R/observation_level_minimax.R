#' Observation-Level Minimax Inference (No Discretization)
#'
#' Minimax inference for surrogate transportability using observation-level
#' Wasserstein DRO without discretization. Treatment effects are modeled as
#' smooth functions of covariates.
#'
#' @name observation_level_minimax
NULL

#' Estimate Treatment Effect Functions via Flexible Regression
#'
#' Estimates conditional average treatment effects τ(x) = E[Y(1) - Y(0) | X=x]
#' using flexible regression methods.
#'
#' @param data Data frame with A, outcome (S or Y), and covariates
#' @param outcome Character: outcome variable name ("S" or "Y")
#' @param covariates Character vector: covariate column names
#' @param method Character: estimation method
#'   - "kernel": Local linear regression with kernel weights
#'   - "rf": Random forest (requires randomForest package)
#'   - "gam": Generalized additive model (requires mgcv package)
#'   - "linear": Linear model (E[Y|A,X] = α + τ·A + X'β)
#' @param bandwidth Numeric: bandwidth for kernel method (NULL = automatic)
#' @param cross_fit Logical: use cross-fitting to avoid overfitting?
#' @param n_folds Integer: number of folds for cross-fitting
#'
#' @return List with:
#'   \item{tau_hat}{Numeric vector: estimated treatment effect at each observation}
#'   \item{method}{Character: method used}
#'   \item{model}{Fitted model object (for inspection)}
#'   \item{cross_fitted}{Logical: was cross-fitting used?}
#'
#' @details
#' **Goal:** Estimate τ(x) = E[Y|A=1,X=x] - E[Y|A=0,X=x] without discretizing X.
#'
#' **Why flexible regression?**
#' - Treatment effects may vary nonlinearly with covariates
#' - Want to capture heterogeneity without binning
#' - Avoids discretization noise that causes bias
#'
#' **Cross-fitting (recommended):**
#' - Split data into K folds
#' - For fold k: fit model on other K-1 folds, predict on fold k
#' - Avoids overfitting (important for DRO downstream)
#' - Ensures τ̂(xᵢ) is independent of (Aᵢ, Yᵢ)
#'
#' **Methods:**
#'
#' 1. **Kernel (default):**
#'    - Local linear regression: fit τ + β(x-x₀) in neighborhood of x₀
#'    - Automatic bandwidth via rule of thumb
#'    - Non-parametric, adaptive to local smoothness
#'
#' 2. **Random Forest:**
#'    - Fit separate forests for E[Y|A=1,X] and E[Y|A=0,X]
#'    - Or single forest for E[Y|A,X] and difference predictions
#'    - Captures interactions automatically
#'
#' 3. **GAM:**
#'    - Smooth splines: E[Y|A,X] = α + τ·A + s₁(X₁) + s₂(X₂) + ...
#'    - Or allow treatment-covariate interactions: s(X₁,A) + s(X₂,A)
#'    - Interpretable smoothness
#'
#' 4. **Linear:**
#'    - E[Y|A,X] = α + τ·A + X'β
#'    - Fast, but assumes constant treatment effects (no heterogeneity)
#'    - Use only if you believe effects don't vary with X
#'
#' **For concordance functional:**
#' - Call this twice: once for S, once for Y
#' - Then compute h_i = τ_S(x_i) · τ_Y(x_i)
#' - Apply observation-level Wasserstein DRO to h
#'
#' @examples
#' \dontrun{
#' # Estimate treatment effects on S
#' tau_s_result <- estimate_treatment_effect_function(
#'   data = mydata,
#'   outcome = "S",
#'   covariates = c("X1", "X2"),
#'   method = "kernel",
#'   cross_fit = TRUE
#' )
#'
#' # Estimated effect at each observation
#' tau_s_hat <- tau_s_result$tau_hat
#' }
#'
#' @keywords internal
estimate_treatment_effect_function <- function(data,
                                                outcome,
                                                covariates,
                                                method = c("kernel", "rf", "gam", "linear"),
                                                bandwidth = NULL,
                                                cross_fit = TRUE,
                                                n_folds = 5) {

  method <- match.arg(method)

  # Validate inputs
  if (!outcome %in% names(data)) {
    stop(sprintf("Outcome '%s' not found in data", outcome))
  }
  if (!"A" %in% names(data)) {
    stop("Treatment variable 'A' not found in data")
  }
  missing_covs <- setdiff(covariates, names(data))
  if (length(missing_covs) > 0) {
    stop(sprintf("Covariates not found in data: %s", paste(missing_covs, collapse = ", ")))
  }

  n <- nrow(data)

  # Cross-fitting setup
  if (cross_fit) {
    fold_ids <- sample(rep(1:n_folds, length.out = n))
    tau_hat <- numeric(n)

    for (k in 1:n_folds) {
      train_idx <- which(fold_ids != k)
      test_idx <- which(fold_ids == k)

      # Fit on training, predict on test
      tau_hat[test_idx] <- fit_and_predict_tau(
        data_train = data[train_idx, ],
        data_test = data[test_idx, ],
        outcome = outcome,
        covariates = covariates,
        method = method,
        bandwidth = bandwidth
      )
    }

    return(list(
      tau_hat = tau_hat,
      method = method,
      model = NULL,  # Cross-fitted models not returned
      cross_fitted = TRUE
    ))

  } else {
    # No cross-fitting: fit on all data, predict in-sample
    tau_hat <- fit_and_predict_tau(
      data_train = data,
      data_test = data,
      outcome = outcome,
      covariates = covariates,
      method = method,
      bandwidth = bandwidth
    )

    # Also return model for inspection
    model_obj <- fit_tau_model(data, outcome, covariates, method, bandwidth)

    return(list(
      tau_hat = tau_hat,
      method = method,
      model = model_obj,
      cross_fitted = FALSE
    ))
  }
}


#' Fit and Predict Treatment Effect (Internal Helper)
#'
#' @keywords internal
fit_and_predict_tau <- function(data_train, data_test, outcome, covariates, method, bandwidth) {

  if (method == "linear") {
    # E[Y|A,X] = alpha + tau*A + X'beta
    # tau = coefficient on A
    formula_str <- sprintf("%s ~ A + %s", outcome, paste(covariates, collapse = " + "))
    fit <- lm(as.formula(formula_str), data = data_train)

    # Predict at A=1 and A=0
    data_test_a1 <- data_test
    data_test_a1$A <- 1
    mu1 <- predict(fit, newdata = data_test_a1)

    data_test_a0 <- data_test
    data_test_a0$A <- 0
    mu0 <- predict(fit, newdata = data_test_a0)

    return(mu1 - mu0)

  } else if (method == "kernel") {
    # Local linear regression for each test point
    X_train <- as.matrix(data_train[, covariates, drop = FALSE])
    X_test <- as.matrix(data_test[, covariates, drop = FALSE])
    A_train <- data_train$A
    Y_train <- data_train[[outcome]]

    # Automatic bandwidth if not provided
    if (is.null(bandwidth)) {
      # Silverman's rule of thumb for multivariate
      d <- ncol(X_train)
      bandwidth <- (4 / (d + 2))^(1 / (d + 4)) * nrow(X_train)^(-1 / (d + 4)) *
                   mean(apply(X_train, 2, sd))
    }

    n_test <- nrow(X_test)
    tau_hat <- numeric(n_test)

    for (i in 1:n_test) {
      # Kernel weights
      dists <- sqrt(rowSums((X_train - matrix(X_test[i, ], nrow = nrow(X_train), ncol = ncol(X_train), byrow = TRUE))^2))
      weights <- dnorm(dists / bandwidth)
      weights <- weights / sum(weights)

      # Weighted means
      idx_treated <- A_train == 1
      idx_control <- A_train == 0

      if (sum(weights[idx_treated]) > 0 && sum(weights[idx_control]) > 0) {
        mu1 <- weighted.mean(Y_train[idx_treated], weights[idx_treated])
        mu0 <- weighted.mean(Y_train[idx_control], weights[idx_control])
        tau_hat[i] <- mu1 - mu0
      } else {
        # Fallback: overall treatment effect
        tau_hat[i] <- mean(Y_train[idx_treated]) - mean(Y_train[idx_control])
      }
    }

    return(tau_hat)

  } else if (method == "rf") {
    # Random forest
    if (!requireNamespace("randomForest", quietly = TRUE)) {
      stop("Package 'randomForest' required for method='rf'")
    }

    # Separate forests for treated and control
    formula_str <- sprintf("%s ~ %s", outcome, paste(covariates, collapse = " + "))

    fit1 <- randomForest::randomForest(
      as.formula(formula_str),
      data = data_train[data_train$A == 1, ],
      ntree = 500
    )

    fit0 <- randomForest::randomForest(
      as.formula(formula_str),
      data = data_train[data_train$A == 0, ],
      ntree = 500
    )

    mu1 <- predict(fit1, newdata = data_test)
    mu0 <- predict(fit0, newdata = data_test)

    return(mu1 - mu0)

  } else if (method == "gam") {
    # Generalized additive model
    if (!requireNamespace("mgcv", quietly = TRUE)) {
      stop("Package 'mgcv' required for method='gam'")
    }

    # Build formula with smooth terms
    smooth_terms <- paste0("s(", covariates, ")", collapse = " + ")
    formula_str <- sprintf("%s ~ A + %s", outcome, smooth_terms)

    fit <- mgcv::gam(as.formula(formula_str), data = data_train)

    # Predict at A=1 and A=0
    data_test_a1 <- data_test
    data_test_a1$A <- 1
    mu1 <- predict(fit, newdata = data_test_a1)

    data_test_a0 <- data_test
    data_test_a0$A <- 0
    mu0 <- predict(fit, newdata = data_test_a0)

    return(mu1 - mu0)

  } else {
    stop(sprintf("Unknown method: %s", method))
  }
}


#' Fit Treatment Effect Model (for returning model object)
#'
#' @keywords internal
fit_tau_model <- function(data, outcome, covariates, method, bandwidth) {
  # This is called only when cross_fit = FALSE
  # Returns fitted model object for inspection
  # (Implementation parallel to fit_and_predict_tau but returns model)

  if (method == "linear") {
    formula_str <- sprintf("%s ~ A + %s", outcome, paste(covariates, collapse = " + "))
    return(lm(as.formula(formula_str), data = data))
  } else if (method == "rf") {
    formula_str <- sprintf("%s ~ A + %s", outcome, paste(covariates, collapse = " + "))
    return(randomForest::randomForest(as.formula(formula_str), data = data, ntree = 500))
  } else if (method == "gam") {
    smooth_terms <- paste0("s(", covariates, ")", collapse = " + ")
    formula_str <- sprintf("%s ~ A + %s", outcome, smooth_terms)
    return(mgcv::gam(as.formula(formula_str), data = data))
  } else {
    return(NULL)  # Kernel doesn't have a single model
  }
}


#' Observation-Level Wasserstein Minimax for Concordance
#'
#' Computes minimax concordance using observation-level Wasserstein DRO
#' without discretization. Treatment effects are estimated as smooth functions
#' of covariates.
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param covariates Character vector: covariate column names
#' @param lambda_w Numeric: Wasserstein ball radius
#' @param tau_method Character: method for estimating treatment effects
#'   (see \code{estimate_treatment_effect_function})
#' @param cross_fit Logical: use cross-fitting?
#' @param cost_function Character: "euclidean" or "manhattan"
#' @param scale_covariates Logical: standardize covariates before computing distances?
#'
#' @return List with:
#'   \item{phi_star}{Minimax concordance estimate}
#'   \item{optimal_gamma}{Optimal Wasserstein dual variable}
#'   \item{tau_s_hat}{Estimated treatment effects on S (length n)}
#'   \item{tau_y_hat}{Estimated treatment effects on Y (length n)}
#'   \item{concordance_i}{Estimated concordance at each observation (length n)}
#'   \item{cost_matrix}{n x n cost matrix}
#'   \item{method}{Character: "observation_level_wasserstein"}
#'
#' @details
#' **Algorithm:**
#'
#' 1. Estimate τ_S(X) via flexible regression
#' 2. Estimate τ_Y(X) via flexible regression
#' 3. Compute h_i = τ_S(x_i) · τ_Y(x_i) for each observation
#' 4. Build cost matrix C[i,j] = ||x_i - x_j||²
#' 5. Solve Wasserstein DRO dual:
#'    sup_{γ≥0} { -γλ_w² + (1/n)Σᵢ min_j {h_j + γC[i,j]} }
#'
#' **Advantages over discretization:**
#' - No binning → no discretization noise
#' - Preserves full covariate information
#' - Natural for continuous covariate spaces
#' - Treatment effects estimated smoothly
#'
#' **Compared to type-level approach:**
#' - Type-level: Bin into J types, estimate τ per type (noisy with small bins)
#' - Observation-level: Model τ(x) as smooth function, evaluate at each x_i
#'
#' **Cost matrix:**
#' - C[i,j] = ||x_i - x_j||² encodes covariate similarity
#' - Adversary pays a cost to shift mass to dissimilar observations
#' - Regularizes the reweighting naturally
#'
#' @examples
#' \dontrun{
#' result <- observation_level_minimax_wasserstein(
#'   data = mydata,
#'   covariates = c("age", "sex", "baseline_health"),
#'   lambda_w = 0.3,
#'   tau_method = "kernel",
#'   cross_fit = TRUE
#' )
#'
#' cat("Minimax concordance:", result$phi_star, "\n")
#' }
#'
#' @export
observation_level_minimax_wasserstein <- function(data,
                                                   covariates,
                                                   lambda_w,
                                                   tau_method = c("kernel", "rf", "gam", "linear"),
                                                   cross_fit = TRUE,
                                                   cost_function = c("euclidean", "manhattan"),
                                                   scale_covariates = TRUE) {

  tau_method <- match.arg(tau_method)
  cost_function <- match.arg(cost_function)

  n <- nrow(data)

  # Step 1: Estimate tau_S(X)
  message("Estimating treatment effects on S...")
  tau_s_result <- estimate_treatment_effect_function(
    data = data,
    outcome = "S",
    covariates = covariates,
    method = tau_method,
    cross_fit = cross_fit
  )

  # Step 2: Estimate tau_Y(X)
  message("Estimating treatment effects on Y...")
  tau_y_result <- estimate_treatment_effect_function(
    data = data,
    outcome = "Y",
    covariates = covariates,
    method = tau_method,
    cross_fit = cross_fit
  )

  tau_s_hat <- tau_s_result$tau_hat
  tau_y_hat <- tau_y_result$tau_hat

  # Step 3: Compute concordance at each observation
  concordance_i <- tau_s_hat * tau_y_hat

  # Step 4: Build cost matrix
  message("Computing cost matrix...")
  X <- as.matrix(data[, covariates, drop = FALSE])

  if (scale_covariates) {
    X <- scale(X)
  }

  # Cost matrix: C[i,j] = distance(x_i, x_j)^2
  if (cost_function == "euclidean") {
    cost_matrix <- as.matrix(dist(X, method = "euclidean"))^2
  } else if (cost_function == "manhattan") {
    cost_matrix <- as.matrix(dist(X, method = "manhattan"))
  }

  # Step 5: Solve Wasserstein DRO dual
  message("Solving Wasserstein DRO dual...")

  # Dual: sup_{gamma >= 0} g(gamma)
  # where g(gamma) = -gamma * lambda_w^2 + mean_i min_j {h_j + gamma * C[i,j]}
  # For each observation i (row), find min over j (cols): h[j] + gamma * C[i,j]

  dual_objective <- function(gamma) {
    # Matrix where element [i,j] = h[j] + gamma * C[i,j]
    obj_matrix <- matrix(concordance_i, nrow = n, ncol = n, byrow = TRUE) +
                  gamma * cost_matrix

    # For each i (row), find minimum over j (columns)
    inner_mins <- apply(obj_matrix, 1, min)

    # Dual objective: -gamma*lambda_w^2 + mean over i
    -gamma * lambda_w^2 + mean(inner_mins)
  }

  # Optimize over gamma >= 0
  opt_result <- optimize(
    f = dual_objective,
    interval = c(0, 100),
    maximum = TRUE,
    tol = 1e-6
  )

  phi_star <- opt_result$objective
  optimal_gamma <- opt_result$maximum

  message(sprintf("Minimax concordance: %.4f (gamma* = %.4f)", phi_star, optimal_gamma))

  list(
    phi_star = phi_star,
    optimal_gamma = optimal_gamma,
    tau_s_hat = tau_s_hat,
    tau_y_hat = tau_y_hat,
    concordance_i = concordance_i,
    cost_matrix = cost_matrix,
    method = "observation_level_wasserstein",
    tau_method = tau_method,
    cross_fitted = cross_fit,
    lambda_w = lambda_w
  )
}
