#' Compute Nuisance Diagnostics
#'
#' Assesses fit quality for nuisance function estimates using various metrics.
#'
#' @param predictions Numeric vector. Predicted values
#' @param observed Numeric vector. Observed values (same length as predictions)
#' @param metric Character. Diagnostic metric to compute:
#'   - "R2": R-squared (coefficient of determination)
#'   - "MSE": Mean squared error
#'   - "RMSE": Root mean squared error
#'   - "MAE": Mean absolute error
#'   Default: "R2"
#'
#' @return Numeric value of the specified metric
#'
#' @details
#' **Metrics:**
#' - R²: 1 - RSS/TSS, where RSS = sum of squared residuals, TSS = total sum of squares.
#'   Values close to 1 indicate good fit. Can be negative for very poor fits.
#' - MSE: mean((predicted - observed)²). Lower is better.
#' - RMSE: sqrt(MSE). Same units as the outcome. Lower is better.
#' - MAE: mean(|predicted - observed|). Robust to outliers. Lower is better.
#'
#' @examples
#' \dontrun{
#' # Simulate predictions and observed values
#' observed <- rnorm(100, mean = 5, sd = 2)
#' predictions <- observed + rnorm(100, sd = 0.5)  # Good fit
#'
#' # Compute R²
#' compute_nuisance_diagnostics(predictions, observed, "R2")
#'
#' # Compute RMSE
#' compute_nuisance_diagnostics(predictions, observed, "RMSE")
#' }
#'
#' @export
compute_nuisance_diagnostics <- function(predictions, observed,
                                          metric = c("R2", "MSE", "RMSE", "MAE")) {

  metric <- match.arg(metric)

  if (length(predictions) != length(observed)) {
    stop("predictions and observed must have the same length")
  }

  if (any(is.na(predictions)) || any(is.na(observed))) {
    warning("NA values detected in predictions or observed. Returning NA.")
    return(NA_real_)
  }

  residuals <- observed - predictions

  if (metric == "R2") {
    # R² = 1 - RSS/TSS
    RSS <- sum(residuals^2)
    TSS <- sum((observed - mean(observed))^2)

    if (TSS == 0) {
      warning("Total sum of squares is zero (constant observed values). Returning NA.")
      return(NA_real_)
    }

    R2 <- 1 - RSS / TSS
    return(R2)

  } else if (metric == "MSE") {
    MSE <- mean(residuals^2)
    return(MSE)

  } else if (metric == "RMSE") {
    MSE <- mean(residuals^2)
    RMSE <- sqrt(MSE)
    return(RMSE)

  } else if (metric == "MAE") {
    MAE <- mean(abs(residuals))
    return(MAE)
  }
}


#' Check Sample Size Adequacy
#'
#' Checks if sample size is adequate for the specified nuisance estimation method
#' given the number of covariates.
#'
#' @param n Integer. Sample size
#' @param d Integer. Number of covariates
#' @param method Character. Estimation method: "lm", "gam", "rf", or "kernel"
#'
#' @return List with components:
#'   \item{adequate}{Logical. TRUE if sample size is adequate}
#'   \item{threshold}{Numeric. Recommended minimum sample size (n_min = threshold * d)}
#'   \item{message}{Character. Descriptive message (empty if adequate)}
#'
#' @details
#' **Sample size thresholds (n ≥ threshold × d):**
#' - lm: 20d (linear regression needs ~20 observations per parameter)
#' - gam: 30d (smooth terms require more data)
#' - rf: 100d (random forests need large samples to avoid overfitting)
#' - kernel: 50d (local methods need dense neighborhoods)
#'
#' These are conservative rules of thumb. Actual requirements depend on:
#' - Signal-to-noise ratio (higher noise → more data needed)
#' - Treatment effect heterogeneity (more variation → more data needed)
#' - Covariate distribution (sparse regions → more data needed)
#'
#' @examples
#' \dontrun{
#' # Check adequacy for linear regression with 5 covariates
#' check_sample_size_adequacy(n = 100, d = 5, method = "lm")
#' # Returns: adequate = TRUE (100 >= 20*5)
#'
#' # Check adequacy for random forest with 10 covariates
#' check_sample_size_adequacy(n = 500, d = 10, method = "rf")
#' # Returns: adequate = FALSE (500 < 100*10), with warning message
#' }
#'
#' @export
check_sample_size_adequacy <- function(n, d, method) {

  thresholds <- c(
    "lm" = 20,
    "gam" = 30,
    "rf" = 100,
    "kernel" = 50
  )

  if (!method %in% names(thresholds)) {
    return(list(
      adequate = TRUE,
      threshold = 0,
      message = sprintf("Unknown method '%s'. No sample size check performed.", method)
    ))
  }

  multiplier <- thresholds[method]
  threshold <- as.numeric(multiplier * d)  # Remove names
  adequate <- n >= threshold

  if (!adequate) {
    message <- sprintf(
      "Sample size n=%d may be too small for method='%s' with d=%d covariates. Recommended: n >= %d (= %d × %d).",
      n, method, d, threshold, as.numeric(multiplier), d
    )
  } else {
    message <- ""
  }

  list(
    adequate = adequate,
    threshold = threshold,
    message = message
  )
}


#' Validate Method Availability
#'
#' Checks if required packages are installed for the specified nuisance
#' estimation method.
#'
#' @param method Character. Estimation method: "lm", "gam", "rf", or "kernel"
#'
#' @return List with components:
#'   \item{available}{Logical. TRUE if method is available (package installed)}
#'   \item{package}{Character. Required package name (NA if no package needed)}
#'   \item{message}{Character. Descriptive message (empty if available)}
#'
#' @details
#' **Package requirements:**
#' - lm: No additional packages (base R)
#' - kernel: No additional packages (base R)
#' - gam: Requires 'mgcv' package
#' - rf: Requires 'randomForest' package
#'
#' If a required package is not installed, the calling function should either:
#' 1. Fall back to a simpler method (e.g., lm), or
#' 2. Stop with an informative error message
#'
#' @examples
#' \dontrun{
#' # Check if GAM is available
#' validate_method_availability("gam")
#'
#' # Check if random forest is available
#' validate_method_availability("rf")
#' }
#'
#' @export
validate_method_availability <- function(method) {

  if (method == "gam") {
    if (!requireNamespace("mgcv", quietly = TRUE)) {
      return(list(
        available = FALSE,
        package = "mgcv",
        message = "Method 'gam' requires package 'mgcv' which is not installed. Install with: install.packages('mgcv')"
      ))
    }
  } else if (method == "rf") {
    if (!requireNamespace("randomForest", quietly = TRUE)) {
      return(list(
        available = FALSE,
        package = "randomForest",
        message = "Method 'rf' requires package 'randomForest' which is not installed. Install with: install.packages('randomForest')"
      ))
    }
  }

  # lm and kernel don't need additional packages
  list(
    available = TRUE,
    package = NA_character_,
    message = ""
  )
}
