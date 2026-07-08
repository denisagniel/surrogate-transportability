#' Estimate Propensity Scores with Flexible Methods
#'
#' Estimates propensity scores e(X) = P(A=1|X) using various methods with
#' optional cross-fitting. This is a key component of doubly robust estimators.
#'
#' @param data Data frame containing treatment and covariates
#' @param covariates Character vector. Names of covariate columns. If NULL or
#'   empty, assumes randomized trial and returns constant propensity = mean(A).
#' @param method Character. Estimation method: "logistic" (logistic regression),
#'   "gam" (generalized additive model), or "rf" (random forest). Default: "logistic"
#' @param cross_fit Logical. Use K-fold cross-fitting? Default: TRUE
#' @param K Integer. Number of folds for cross-fitting. Default: 5
#' @param trim Numeric vector of length 2. Lower and upper bounds for trimming
#'   extreme propensities. Default: c(0.01, 0.99) to avoid numerical instability.
#' @param return_diagnostics Logical. Return fit diagnostics? Default: TRUE
#'
#' @details
#' Propensity scores are estimated by fitting models for P(A=1|X). When covariates
#' are absent or NULL, the function returns mean(A) for all observations (appropriate
#' for randomized trials).
#'
#' **Methods:**
#' - **logistic:** Logistic regression. Fast, works well when e(X) is approximately
#'   linear on logit scale. Formula: A ~ X₁ + X₂ + ...
#' - **gam:** Generalized additive model via mgcv::gam(). Flexible smooth terms.
#'   Formula: A ~ s(X₁) + s(X₂) + ...
#' - **rf:** Random forest via randomForest package. Nonparametric, handles
#'   interactions automatically.
#'
#' **Cross-fitting:** When cross_fit=TRUE, data is split into K folds. For each
#' fold k, the model is fit on folds ≠k and predictions made on fold k. This
#' reduces overfitting bias.
#'
#' **Trimming:** Extreme propensity scores (very close to 0 or 1) can cause
#' numerical instability in inverse probability weighting. The trim parameter
#' bounds propensities to [trim[1], trim[2]].
#'
#' @return List with components:
#'   \item{e_hat}{Numeric vector of length n. Propensity score e(Xᵢ) for each observation}
#'   \item{method}{Character. Method used}
#'   \item{cross_fitted}{Logical. Whether cross-fitting was used}
#'   \item{trimmed}{Logical. Whether any values were trimmed}
#'   \item{diagnostics}{List (if return_diagnostics=TRUE) containing:
#'     \itemize{
#'       \item n_trimmed_lower: Number of values trimmed at lower bound
#'       \item n_trimmed_upper: Number of values trimmed at upper bound
#'       \item range_before_trim: Range of propensities before trimming
#'       \item range_after_trim: Range of propensities after trimming
#'     }
#'   }
#'
#' @examples
#' \dontrun{
#' # Generate test data
#' data <- data.frame(
#'   A = rbinom(200, 1, 0.5),
#'   X1 = rnorm(200),
#'   X2 = rnorm(200)
#' )
#'
#' # Logistic regression with cross-fitting (default)
#' ps_result <- estimate_propensity_score(
#'   data, covariates = c("X1", "X2")
#' )
#'
#' # GAM without cross-fitting
#' ps_gam <- estimate_propensity_score(
#'   data, covariates = c("X1", "X2"),
#'   method = "gam", cross_fit = FALSE
#' )
#'
#' # Randomized trial (no covariates)
#' ps_rct <- estimate_propensity_score(data, covariates = NULL)
#' }
#'
#' @export
estimate_propensity_score <- function(data,
                                      covariates = NULL,
                                      method = c("logistic", "gam", "rf"),
                                      cross_fit = TRUE,
                                      K = 5,
                                      trim = c(0.01, 0.99),
                                      return_diagnostics = TRUE) {

  method <- match.arg(method)

  # Validate inputs
  if (!"A" %in% names(data)) {
    stop("Treatment column 'A' not found in data")
  }

  n <- nrow(data)

  # If no covariates, return constant propensity (randomized trial)
  if (is.null(covariates) || length(covariates) == 0) {
    e_hat <- rep(mean(data$A), n)
    return(list(
      e_hat = e_hat,
      method = "constant",
      cross_fitted = FALSE,
      trimmed = FALSE,
      diagnostics = if (return_diagnostics) list(
        n_trimmed_lower = 0,
        n_trimmed_upper = 0,
        range_before_trim = range(e_hat),
        range_after_trim = range(e_hat)
      ) else NULL
    ))
  }

  # Check covariates exist
  missing_covs <- setdiff(covariates, names(data))
  if (length(missing_covs) > 0) {
    stop(sprintf("Covariates not found in data: %s",
                 paste(missing_covs, collapse = ", ")))
  }

  # Initialize output
  e_hat <- numeric(n)

  if (cross_fit) {
    # K-fold cross-fitting
    fold_ids <- sample(rep(1:K, length.out = n))

    for (k in 1:K) {
      test_idx <- which(fold_ids == k)
      train_idx <- which(fold_ids != k)

      train_data <- data[train_idx, ]
      test_data <- data[test_idx, ]

      # Fit and predict on this fold
      e_hat[test_idx] <- fit_and_predict_propensity(
        train_data, test_data, covariates, method
      )
    }

  } else {
    # No cross-fitting: fit on all data
    e_hat <- fit_and_predict_propensity(
      data, data, covariates, method
    )
  }

  # Store pre-trim range for diagnostics
  range_before_trim <- range(e_hat)

  # Trim extreme propensities
  n_trimmed_lower <- sum(e_hat < trim[1])
  n_trimmed_upper <- sum(e_hat > trim[2])
  e_hat <- pmax(trim[1], pmin(trim[2], e_hat))

  # Store post-trim range
  range_after_trim <- range(e_hat)

  # Diagnostics
  diagnostics <- if (return_diagnostics) {
    list(
      n_trimmed_lower = n_trimmed_lower,
      n_trimmed_upper = n_trimmed_upper,
      range_before_trim = range_before_trim,
      range_after_trim = range_after_trim
    )
  } else {
    NULL
  }

  list(
    e_hat = e_hat,
    method = method,
    cross_fitted = cross_fit,
    trimmed = (n_trimmed_lower > 0 || n_trimmed_upper > 0),
    diagnostics = diagnostics
  )
}


#' Fit and Predict Propensity Scores (Internal)
#'
#' Fits propensity score model on training data and predicts on test data.
#'
#' @param train_data Training data
#' @param test_data Test data
#' @param covariates Covariate names
#' @param method Method name
#'
#' @return Numeric vector of propensity scores for test data
#' @keywords internal
fit_and_predict_propensity <- function(train_data, test_data, covariates, method) {

  if (method == "logistic") {
    # Logistic regression: P(A=1|X)
    formula_str <- sprintf("A ~ %s", paste(covariates, collapse = " + "))
    fit <- glm(as.formula(formula_str), data = train_data, family = binomial())

    e_hat <- as.numeric(predict(fit, newdata = test_data, type = "response"))

  } else if (method == "gam") {
    # Generalized additive model with smooth terms
    if (!requireNamespace("mgcv", quietly = TRUE)) {
      warning("mgcv package not available. Falling back to logistic regression.")
      return(fit_and_predict_propensity(train_data, test_data, covariates, "logistic"))
    }

    smooth_terms <- paste0("s(", covariates, ")", collapse = " + ")
    formula_str <- sprintf("A ~ %s", smooth_terms)

    fit <- mgcv::gam(as.formula(formula_str), data = train_data, family = binomial())

    e_hat <- as.numeric(predict(fit, newdata = test_data, type = "response"))

  } else if (method == "rf") {
    # Random forest for propensity scores
    if (!requireNamespace("randomForest", quietly = TRUE)) {
      warning("randomForest package not available. Falling back to logistic regression.")
      return(fit_and_predict_propensity(train_data, test_data, covariates, "logistic"))
    }

    formula_str <- sprintf("A ~ %s", paste(covariates, collapse = " + "))

    # Ensure A is a factor for classification
    train_data$A <- as.factor(train_data$A)

    fit <- randomForest::randomForest(
      as.formula(formula_str),
      data = train_data,
      ntree = 500
    )

    # Predict probability of A=1
    e_hat <- as.numeric(predict(fit, newdata = test_data, type = "prob")[, "1"])

  } else {
    stop(sprintf("Unknown method: %s", method))
  }

  e_hat
}
