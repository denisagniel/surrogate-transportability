#' Validate lambda parameter
#'
#' Internal validation function to ensure lambda is a valid single numeric value in [0, 1].
#'
#' @param lambda Numeric value to validate.
#' @param arg_name Character. Name of the argument (for error messages). Default: "lambda".
#'
#' @return Invisibly returns lambda if valid; otherwise stops with informative error.
#'
#' @keywords internal
#' @noRd
validate_lambda <- function(lambda, arg_name = "lambda") {
  if (!is.numeric(lambda)) {
    stop(sprintf("%s must be numeric, got %s", arg_name, class(lambda)[1]))
  }

  if (length(lambda) != 1) {
    stop(sprintf("%s must be a single value, got length %d", arg_name, length(lambda)))
  }

  if (is.na(lambda)) {
    stop(sprintf("%s cannot be NA", arg_name))
  }

  if (lambda < 0 || lambda > 1) {
    stop(sprintf("%s must be in [0, 1], got %.3f", arg_name, lambda))
  }

  invisible(lambda)
}


#' Validate lambda grid
#'
#' Internal validation function to ensure lambda_grid is a valid numeric vector
#' with all values in [0, 1].
#'
#' @param lambda_grid Numeric vector to validate.
#' @param arg_name Character. Name of the argument (for error messages). Default: "lambda_grid".
#'
#' @return Invisibly returns lambda_grid if valid; otherwise stops with informative error.
#'
#' @keywords internal
#' @noRd
validate_lambda_grid <- function(lambda_grid, arg_name = "lambda_grid") {
  if (!is.numeric(lambda_grid)) {
    stop(sprintf("%s must be numeric, got %s", arg_name, class(lambda_grid)[1]))
  }

  if (length(lambda_grid) == 0) {
    stop(sprintf("%s must have at least one value", arg_name))
  }

  if (any(is.na(lambda_grid))) {
    stop(sprintf("%s cannot contain NA values", arg_name))
  }

  if (any(lambda_grid < 0) || any(lambda_grid > 1)) {
    invalid_vals <- lambda_grid[lambda_grid < 0 | lambda_grid > 1]
    stop(sprintf(
      "%s must have all values in [0, 1], found: %s",
      arg_name,
      paste(head(invalid_vals, 3), collapse = ", ")
    ))
  }

  invisible(lambda_grid)
}


#' Validate confidence level
#'
#' Internal validation function to ensure confidence level is valid.
#'
#' @param confidence_level Numeric value to validate.
#' @param arg_name Character. Name of the argument (for error messages).
#'
#' @return Invisibly returns confidence_level if valid; otherwise stops with informative error.
#'
#' @keywords internal
#' @noRd
validate_confidence_level <- function(confidence_level, arg_name = "confidence_level") {
  if (!is.numeric(confidence_level)) {
    stop(sprintf("%s must be numeric, got %s", arg_name, class(confidence_level)[1]))
  }

  if (length(confidence_level) != 1) {
    stop(sprintf("%s must be a single value, got length %d", arg_name, length(confidence_level)))
  }

  if (is.na(confidence_level)) {
    stop(sprintf("%s cannot be NA", arg_name))
  }

  if (confidence_level <= 0 || confidence_level >= 1) {
    stop(sprintf("%s must be in (0, 1), got %.3f", arg_name, confidence_level))
  }

  invisible(confidence_level)
}


#' Validate threshold
#'
#' Internal validation function to ensure threshold is valid.
#'
#' @param threshold Numeric value to validate.
#' @param arg_name Character. Name of the argument (for error messages).
#'
#' @return Invisibly returns threshold if valid; otherwise stops with informative error.
#'
#' @keywords internal
#' @noRd
validate_threshold <- function(threshold, arg_name = "threshold") {
  if (!is.numeric(threshold)) {
    stop(sprintf("%s must be numeric, got %s", arg_name, class(threshold)[1]))
  }

  if (length(threshold) != 1) {
    stop(sprintf("%s must be a single value, got length %d", arg_name, length(threshold)))
  }

  if (is.na(threshold)) {
    stop(sprintf("%s cannot be NA", arg_name))
  }

  # Threshold can be any numeric value (no range restriction)
  invisible(threshold)
}
