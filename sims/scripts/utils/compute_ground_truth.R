#' Compute Ground Truth for Transportability
#'
#' Functions to determine whether a surrogate is truly transportable based on
#' the data generating process parameters.

library(tibble)
library(dplyr)

#' Compute true transportability from treatment effects
#'
#' Determines whether a surrogate is truly transportable based on the
#' correlation between treatment effects across types.
#'
#' @param tau_s Numeric vector. Treatment effects on surrogate by type.
#' @param tau_y Numeric vector. Treatment effects on outcome by type.
#' @param threshold Numeric. Correlation threshold for transportability. Default: 0.6.
#' @return Logical. TRUE if truly transportable, FALSE otherwise.
#'
#' @details
#' Ground truth definition:
#' - **Truly transportable:** cor(tau_s, tau_y) > threshold across plausible future studies
#' - **Not transportable:** cor(tau_s, tau_y) < threshold in some plausible future studies
#'
#' We use the population-level correlation between type-specific treatment effects
#' as the ground truth. This represents the "true" relationship that would be
#' observed if we could see all possible future studies.
#'
#' @examples
#' tau_s <- c(0.3, 0.5, 0.7, 0.9)
#' tau_y <- c(0.2, 0.4, 0.6, 0.8)
#' is_truly_transportable(tau_s, tau_y)
#'
#' @export
is_truly_transportable <- function(tau_s, tau_y, threshold = 0.6) {
  if (length(tau_s) != length(tau_y)) {
    stop("tau_s and tau_y must have the same length")
  }

  # Correlation between treatment effects
  cor_effects <- cor(tau_s, tau_y)

  # Transportable if high correlation
  cor_effects > threshold
}


#' Compute traditional method prediction
#'
#' Predicts whether traditional method would classify as transportable.
#'
#' @param data Tibble with study data
#' @param method Character. Which traditional method.
#' @param threshold Numeric. Classification threshold.
#' @return Logical. TRUE if traditional would classify as transportable.
#'
#' @export
traditional_predicts_transportable <- function(data,
                                               method = c("correlation", "pte", "mediation"),
                                               threshold = NULL) {
  method <- match.arg(method)

  # Set default thresholds
  if (is.null(threshold)) {
    threshold <- switch(method,
                       "correlation" = 0.5,
                       "pte" = 0.6,
                       "mediation" = 0.6)
  }

  # Load traditional methods
  source(here::here("package/R/traditional_methods.R"))

  # Classify
  classify_traditional(data, method = method, threshold = threshold)
}


#' Compute confusion matrix elements
#'
#' Determines which cell of the confusion matrix this scenario belongs to.
#'
#' @param is_transportable Logical. Ground truth.
#' @param predicted_transportable Logical. Method prediction.
#' @return Character. One of "TP", "FP", "FN", "TN".
#'
#' @export
confusion_matrix_cell <- function(is_transportable, predicted_transportable) {
  if (is.na(predicted_transportable)) {
    return(NA_character_)
  }

  if (is_transportable && predicted_transportable) {
    return("TP")  # True Positive
  } else if (!is_transportable && predicted_transportable) {
    return("FP")  # False Positive
  } else if (is_transportable && !predicted_transportable) {
    return("FN")  # False Negative
  } else {
    return("TN")  # True Negative
  }
}


#' Compute classification metrics
#'
#' Calculates sensitivity, specificity, accuracy, etc. from predictions.
#'
#' @param ground_truth Logical vector. True transportability status.
#' @param predictions Logical vector. Predicted transportability status.
#' @return Tibble with classification metrics.
#'
#' @details
#' Computes:
#' - **Sensitivity (TPR):** P(predict transportable | truly transportable)
#' - **Specificity (TNR):** P(predict not transportable | not transportable)
#' - **False Positive Rate:** P(predict transportable | not transportable)
#' - **False Negative Rate:** P(predict not transportable | truly transportable)
#' - **Accuracy:** P(correct classification)
#' - **Precision (PPV):** P(truly transportable | predict transportable)
#'
#' @examples
#' ground_truth <- c(TRUE, TRUE, FALSE, FALSE)
#' predictions <- c(TRUE, FALSE, FALSE, TRUE)
#' compute_classification_metrics(ground_truth, predictions)
#'
#' @export
compute_classification_metrics <- function(ground_truth, predictions) {
  # Remove NAs
  valid_idx <- !is.na(predictions) & !is.na(ground_truth)
  ground_truth <- ground_truth[valid_idx]
  predictions <- predictions[valid_idx]

  if (length(predictions) == 0) {
    return(tibble(
      sensitivity = NA_real_,
      specificity = NA_real_,
      fpr = NA_real_,
      fnr = NA_real_,
      accuracy = NA_real_,
      precision = NA_real_,
      n_total = 0,
      n_positive = 0,
      n_negative = 0
    ))
  }

  # Compute confusion matrix elements
  tp <- sum(ground_truth & predictions)
  fp <- sum(!ground_truth & predictions)
  fn <- sum(ground_truth & !predictions)
  tn <- sum(!ground_truth & !predictions)

  n_positive <- tp + fn
  n_negative <- fp + tn
  n_total <- length(predictions)

  # Compute metrics
  sensitivity <- if (n_positive > 0) tp / n_positive else NA_real_
  specificity <- if (n_negative > 0) tn / n_negative else NA_real_
  fpr <- if (n_negative > 0) fp / n_negative else NA_real_
  fnr <- if (n_positive > 0) fn / n_positive else NA_real_
  accuracy <- (tp + tn) / n_total
  precision <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_

  tibble(
    sensitivity = sensitivity,
    specificity = specificity,
    fpr = fpr,
    fnr = fnr,
    accuracy = accuracy,
    precision = precision,
    n_total = n_total,
    n_positive = n_positive,
    n_negative = n_negative,
    tp = tp,
    fp = fp,
    fn = fn,
    tn = tn
  )
}


#' Compute ROC curve points
#'
#' Generates points for ROC curve by varying classification threshold.
#'
#' @param ground_truth Logical vector. True transportability.
#' @param scores Numeric vector. Continuous scores (higher = more likely transportable).
#' @param thresholds Numeric vector. Thresholds to evaluate. If NULL, uses quantiles of scores.
#' @return Tibble with threshold, TPR, FPR for each threshold.
#'
#' @examples
#' ground_truth <- c(TRUE, TRUE, FALSE, FALSE)
#' scores <- c(0.9, 0.7, 0.4, 0.2)
#' roc <- compute_roc_curve(ground_truth, scores)
#'
#' @export
compute_roc_curve <- function(ground_truth, scores, thresholds = NULL) {
  # Remove NAs
  valid_idx <- !is.na(scores) & !is.na(ground_truth)
  ground_truth <- ground_truth[valid_idx]
  scores <- scores[valid_idx]

  if (is.null(thresholds)) {
    # Use quantiles of scores as thresholds
    thresholds <- quantile(scores, probs = seq(0, 1, by = 0.05), na.rm = TRUE)
    thresholds <- unique(thresholds)
  }

  # Compute TPR and FPR for each threshold
  results <- list()

  for (i in seq_along(thresholds)) {
    thresh <- thresholds[i]
    predictions <- scores > thresh

    metrics <- compute_classification_metrics(ground_truth, predictions)

    results[[i]] <- tibble(
      threshold = thresh,
      tpr = metrics$sensitivity,
      fpr = metrics$fpr,
      tnr = metrics$specificity,
      fnr = metrics$fnr
    )
  }

  bind_rows(results)
}


#' Compute AUC (Area Under ROC Curve)
#'
#' Calculates AUC using trapezoidal rule.
#'
#' @param roc_curve Tibble from compute_roc_curve with columns fpr and tpr.
#' @return Numeric. AUC value in [0, 1].
#'
#' @examples
#' ground_truth <- c(TRUE, TRUE, FALSE, FALSE)
#' scores <- c(0.9, 0.7, 0.4, 0.2)
#' roc <- compute_roc_curve(ground_truth, scores)
#' auc <- compute_auc(roc)
#'
#' @export
compute_auc <- function(roc_curve) {
  # Sort by FPR
  roc_curve <- roc_curve %>% arrange(fpr)

  # Trapezoidal rule
  fpr <- roc_curve$fpr
  tpr <- roc_curve$tpr

  auc <- 0
  for (i in 2:length(fpr)) {
    # Trapezoid area
    width <- fpr[i] - fpr[i-1]
    height <- (tpr[i] + tpr[i-1]) / 2
    auc <- auc + width * height
  }

  auc
}


#' Summarize classification performance by method
#'
#' Creates summary table of classification metrics across methods.
#'
#' @param results_df Tibble with columns: method, ground_truth, prediction
#' @return Tibble with metrics by method.
#'
#' @export
summarize_classification_by_method <- function(results_df) {
  results_df %>%
    group_by(method) %>%
    summarize(
      metrics = list(compute_classification_metrics(ground_truth, prediction)),
      .groups = "drop"
    ) %>%
    tidyr::unnest(metrics)
}
