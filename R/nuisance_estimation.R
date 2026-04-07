#' Estimate Treatment Effects with Flexible Methods
#'
#' Estimates treatment effects τ(X) = E[Y|A=1,X] - E[Y|A=0,X] using various
#' regression methods with optional cross-fitting.
#'
#' @param data Data frame containing outcome, treatment, and covariates
#' @param outcome Character. Name of outcome column (e.g., "S" or "Y")
#' @param covariates Character vector. Names of covariate columns
#' @param method Character. Estimation method: "lm" (linear regression),
#'   "gam" (generalized additive model), "rf" (random forest), or
#'   "kernel" (local linear regression). Default: "lm"
#' @param cross_fit Logical. Use K-fold cross-fitting? Default: TRUE
#' @param K Integer. Number of folds for cross-fitting. Default: 5
#' @param bandwidth Numeric. Bandwidth for kernel method. If NULL, uses
#'   Silverman's rule. Default: NULL
#' @param return_diagnostics Logical. Return fit diagnostics? Default: TRUE
#'
#' @details
#' Treatment effects are estimated by fitting regression models for E[Y|A,X]
#' and predicting at A=1 and A=0 for each observation.
#'
#' **Methods:**
#' - **lm:** Linear regression. Fast, works well when τ(X) is approximately
#'   linear. Requires n ≥ 20d. Formula: Y ~ A + X₁ + X₂ + ...
#' - **gam:** Generalized additive model via mgcv::gam(). Flexible smooth terms.
#'   Handles moderate nonlinearity. Requires n ≥ 30d. Formula: Y ~ A + s(X₁) + s(X₂) + ...
#' - **rf:** Random forest via randomForest package. Nonparametric, handles
#'   interactions. Requires n ≥ 100d to avoid overfitting. Fits separate
#'   forests for A=1 and A=0.
#' - **kernel:** Local linear regression with Gaussian kernel. Automatic bandwidth
#'   via Silverman's rule. Requires n ≥ 50d.
#'
#' **Cross-fitting:** When cross_fit=TRUE, data is split into K folds. For each
#' fold k, the model is fit on folds ≠k and predictions made on fold k. This
#' reduces overfitting bias in doubly robust estimators.
#'
#' **Package dependencies:**
#' - gam method requires mgcv package
#' - rf method requires randomForest package
#' If package is not available, function warns and falls back to lm.
#'
#' @return List with components:
#'   \item{tau_hat}{Numeric vector of length n. Treatment effect τ(Xᵢ) for each observation}
#'   \item{mu1_hat}{Numeric vector of length n. Conditional mean E[Y|A=1,Xᵢ]}
#'   \item{mu0_hat}{Numeric vector of length n. Conditional mean E[Y|A=0,Xᵢ]}
#'   \item{method}{Character. Method used (may differ from input if fallback occurred)}
#'   \item{cross_fitted}{Logical. Whether cross-fitting was used}
#'   \item{diagnostics}{List (if return_diagnostics=TRUE) containing:
#'     \itemize{
#'       \item R_squared: Overall R² (only if cross_fit=FALSE)
#'       \item cv_R_squared: Cross-validated R² (only if cross_fit=TRUE)
#'       \item n_train: Training sample size
#'       \item n_test: Test sample size
#'       \item method_warnings: Character vector of any warnings
#'     }
#'   }
#'
#' @examples
#' \dontrun{
#' # Generate test data
#' data <- data.frame(
#'   A = rbinom(200, 1, 0.5),
#'   S = rnorm(200),
#'   Y = rnorm(200),
#'   X1 = rnorm(200),
#'   X2 = rnorm(200)
#' )
#'
#' # Linear regression (default)
#' result_lm <- estimate_treatment_effects(
#'   data, outcome = "S", covariates = c("X1", "X2")
#' )
#'
#' # GAM with cross-fitting
#' result_gam <- estimate_treatment_effects(
#'   data, outcome = "Y", covariates = c("X1", "X2"),
#'   method = "gam", cross_fit = TRUE, K = 5
#' )
#'
#' # Random forest without cross-fitting
#' result_rf <- estimate_treatment_effects(
#'   data, outcome = "S", covariates = c("X1", "X2"),
#'   method = "rf", cross_fit = FALSE
#' )
#' }
#'
#' @export
estimate_treatment_effects <- function(data,
                                        outcome,
                                        covariates,
                                        method = "lm",
                                        cross_fit = TRUE,
                                        K = 5,
                                        bandwidth = NULL,
                                        return_diagnostics = TRUE) {

  # Validate inputs
  if (!outcome %in% names(data)) {
    stop(sprintf("Outcome '%s' not found in data", outcome))
  }
  if (!"A" %in% names(data)) {
    stop("Treatment column 'A' not found in data")
  }

  missing_covs <- setdiff(covariates, names(data))
  if (length(missing_covs) > 0) {
    stop(sprintf("Covariates not found in data: %s",
                 paste(missing_covs, collapse = ", ")))
  }

  n <- nrow(data)
  d <- length(covariates)
  warnings_vec <- character(0)

  # Validate method availability and sample size
  method_avail <- validate_method_availability(method)
  if (!method_avail$available) {
    warnings_vec <- c(warnings_vec, method_avail$message)
    warning(method_avail$message, " Falling back to 'lm'.")
    method <- "lm"
  }

  if (return_diagnostics) {
    size_check <- check_sample_size_adequacy(n, d, method)
    if (!size_check$adequate) {
      warnings_vec <- c(warnings_vec, size_check$message)
      warning(size_check$message)
    }
  }

  # Initialize output vectors
  tau_hat <- numeric(n)
  mu1_hat <- numeric(n)
  mu0_hat <- numeric(n)

  if (cross_fit) {
    # K-fold cross-fitting
    fold_ids <- sample(rep(1:K, length.out = n))

    for (k in 1:K) {
      test_idx <- which(fold_ids == k)
      train_idx <- which(fold_ids != k)

      train_data <- data[train_idx, ]
      test_data <- data[test_idx, ]

      # Fit and predict on this fold
      fold_result <- fit_and_predict_single_method(
        train_data, test_data, outcome, covariates, method, bandwidth
      )

      tau_hat[test_idx] <- fold_result$tau
      mu1_hat[test_idx] <- fold_result$mu1
      mu0_hat[test_idx] <- fold_result$mu0
    }

    # Cross-validated R²
    if (return_diagnostics) {
      # Compute R² on observed outcomes vs predicted
      A <- data$A
      Y_obs <- data[[outcome]]
      Y_pred <- ifelse(A == 1, mu1_hat, mu0_hat)
      cv_R_squared <- 1 - sum((Y_obs - Y_pred)^2) / sum((Y_obs - mean(Y_obs))^2)

      diagnostics <- list(
        cv_R_squared = cv_R_squared,
        n_train = round(n * (K - 1) / K),
        n_test = round(n / K),
        method_warnings = warnings_vec
      )
    } else {
      diagnostics <- NULL
    }

  } else {
    # No cross-fitting: fit on all data
    result <- fit_and_predict_single_method(
      data, data, outcome, covariates, method, bandwidth
    )

    tau_hat <- result$tau
    mu1_hat <- result$mu1
    mu0_hat <- result$mu0

    # In-sample R²
    if (return_diagnostics) {
      A <- data$A
      Y_obs <- data[[outcome]]
      Y_pred <- ifelse(A == 1, mu1_hat, mu0_hat)
      R_squared <- 1 - sum((Y_obs - Y_pred)^2) / sum((Y_obs - mean(Y_obs))^2)

      diagnostics <- list(
        R_squared = R_squared,
        n_train = n,
        n_test = n,
        method_warnings = warnings_vec
      )
    } else {
      diagnostics <- NULL
    }
  }

  list(
    tau_hat = tau_hat,
    mu1_hat = mu1_hat,
    mu0_hat = mu0_hat,
    method = method,
    cross_fitted = cross_fit,
    diagnostics = diagnostics
  )
}


#' Fit and Predict Treatment Effects (Internal)
#'
#' Fits regression model on training data and predicts treatment effects on test data.
#' Supports lm, gam, rf, and kernel methods.
#'
#' @param train_data Training data
#' @param test_data Test data
#' @param outcome Outcome variable name
#' @param covariates Covariate names
#' @param method Method name
#' @param bandwidth Bandwidth for kernel (optional)
#'
#' @return List with tau, mu1, mu0 vectors
#' @keywords internal
fit_and_predict_single_method <- function(train_data, test_data, outcome,
                                           covariates, method, bandwidth) {

  if (method == "lm") {
    # Linear regression: E[Y|A,X] = α + τ*A + X'β
    formula_str <- sprintf("%s ~ A + %s", outcome, paste(covariates, collapse = " + "))
    fit <- lm(as.formula(formula_str), data = train_data)

    # Predict at A=1
    test_a1 <- test_data
    test_a1$A <- 1
    mu1 <- as.numeric(predict(fit, newdata = test_a1))

    # Predict at A=0
    test_a0 <- test_data
    test_a0$A <- 0
    mu0 <- as.numeric(predict(fit, newdata = test_a0))

    tau <- mu1 - mu0

  } else if (method == "gam") {
    # Generalized additive model with smooth terms
    smooth_terms <- paste0("s(", covariates, ")", collapse = " + ")
    formula_str <- sprintf("%s ~ A + %s", outcome, smooth_terms)

    fit <- mgcv::gam(as.formula(formula_str), data = train_data)

    # Predict at A=1 and A=0
    test_a1 <- test_data
    test_a1$A <- 1
    mu1 <- as.numeric(predict(fit, newdata = test_a1))

    test_a0 <- test_data
    test_a0$A <- 0
    mu0 <- as.numeric(predict(fit, newdata = test_a0))

    tau <- mu1 - mu0

  } else if (method == "rf") {
    # Random forest: separate forests for A=1 and A=0
    formula_str <- sprintf("%s ~ %s", outcome, paste(covariates, collapse = " + "))

    # Fit on treated
    fit1 <- randomForest::randomForest(
      as.formula(formula_str),
      data = train_data[train_data$A == 1, ],
      ntree = 500
    )

    # Fit on control
    fit0 <- randomForest::randomForest(
      as.formula(formula_str),
      data = train_data[train_data$A == 0, ],
      ntree = 500
    )

    # Predict on test data
    mu1 <- as.numeric(predict(fit1, newdata = test_data))
    mu0 <- as.numeric(predict(fit0, newdata = test_data))

    tau <- mu1 - mu0

  } else if (method == "kernel") {
    # Local linear regression with Gaussian kernel
    X_train <- as.matrix(train_data[, covariates, drop = FALSE])
    X_test <- as.matrix(test_data[, covariates, drop = FALSE])
    A_train <- train_data$A
    Y_train <- train_data[[outcome]]

    # Automatic bandwidth if not provided (Silverman's rule)
    if (is.null(bandwidth)) {
      d <- ncol(X_train)
      bandwidth <- (4 / (d + 2))^(1 / (d + 4)) * nrow(X_train)^(-1 / (d + 4)) *
                   mean(apply(X_train, 2, sd))
    }

    n_test <- nrow(X_test)
    mu1 <- numeric(n_test)
    mu0 <- numeric(n_test)

    for (i in 1:n_test) {
      # Compute kernel weights for observation i
      dists <- sqrt(rowSums((X_train - matrix(X_test[i, ], nrow = nrow(X_train),
                                               ncol = ncol(X_train), byrow = TRUE))^2))
      weights <- dnorm(dists / bandwidth)
      weights <- weights / sum(weights)

      # Weighted means for treated and control
      idx_treated <- A_train == 1
      idx_control <- A_train == 0

      if (sum(weights[idx_treated]) > 0) {
        mu1[i] <- weighted.mean(Y_train[idx_treated], weights[idx_treated])
      } else {
        # Fallback: overall mean for treated
        mu1[i] <- mean(Y_train[idx_treated])
      }

      if (sum(weights[idx_control]) > 0) {
        mu0[i] <- weighted.mean(Y_train[idx_control], weights[idx_control])
      } else {
        # Fallback: overall mean for control
        mu0[i] <- mean(Y_train[idx_control])
      }
    }

    tau <- mu1 - mu0

  } else {
    stop(sprintf("Unknown method: %s", method))
  }

  list(tau = tau, mu1 = mu1, mu0 = mu0)
}


#' Validate Method Availability (Internal)
#'
#' Checks if required packages are available for the specified method.
#'
#' @param method Method name ("lm", "gam", "rf", "kernel")
#'
#' @return List with 'available' (logical) and 'message' (character)
#' @keywords internal
validate_method_availability <- function(method) {
  if (method == "gam") {
    if (!requireNamespace("mgcv", quietly = TRUE)) {
      return(list(
        available = FALSE,
        package = "mgcv",
        message = "Method 'gam' requires package 'mgcv' which is not installed."
      ))
    }
  } else if (method == "rf") {
    if (!requireNamespace("randomForest", quietly = TRUE)) {
      return(list(
        available = FALSE,
        package = "randomForest",
        message = "Method 'rf' requires package 'randomForest' which is not installed."
      ))
    }
  }

  list(available = TRUE, package = NA, message = "")
}


#' Check Sample Size Adequacy (Internal)
#'
#' Checks if sample size is adequate for the specified method.
#'
#' @param n Sample size
#' @param d Number of covariates
#' @param method Method name
#'
#' @return List with 'adequate' (logical), 'threshold' (numeric), 'message' (character)
#' @keywords internal
check_sample_size_adequacy <- function(n, d, method) {
  thresholds <- c(
    "lm" = 20,
    "gam" = 30,
    "rf" = 100,
    "kernel" = 50
  )

  if (!method %in% names(thresholds)) {
    return(list(adequate = TRUE, threshold = 0, message = ""))
  }

  threshold <- thresholds[method] * d
  adequate <- n >= threshold

  if (!adequate) {
    message <- sprintf(
      "Sample size n=%d may be too small for method='%s' with d=%d covariates (recommended: n >= %d).",
      n, method, d, threshold
    )
  } else {
    message <- ""
  }

  list(adequate = adequate, threshold = threshold, message = message)
}
