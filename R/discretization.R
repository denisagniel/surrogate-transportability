#' Discretization Methods for Type-Level Minimax Inference
#'
#' Functions for discretizing observations into types (bins) for
#' type-level minimax inference.
#'
#' @name discretization
NULL

#' RF-Based Discretization via Treatment Effect Prediction
#'
#' Trains random forests on treatment effect estimates and discretizes
#' observations based on predicted effects.
#'
#' @param data Data frame with columns A, S, Y, and covariates
#' @param covariate_cols Character vector of covariate column names
#' @param ntree Number of trees in random forest
#' @param maxnodes Maximum terminal nodes in each tree
#' @param n_bins Number of bins per dimension for discretization
#'
#' @return Integer vector of bin assignments (length nrow(data))
#'
#' @details
#' Trains separate RFs on treated units to predict S and Y outcomes.
#' Then discretizes all observations based on (pred_S, pred_Y) predictions
#' into a 2D grid. This creates bins that capture treatment effect heterogeneity.
#'
#' @keywords internal
train_rf_partition <- function(data,
                                covariate_cols,
                                ntree = 500,
                                maxnodes = 10,
                                n_bins = 5) {

  if (!requireNamespace("randomForest", quietly = TRUE)) {
    stop("Package 'randomForest' is required for RF-based discretization. ",
         "Install with: install.packages('randomForest')")
  }

  # Extract covariates
  X_matrix <- as.matrix(data[, covariate_cols, drop = FALSE])

  # Train on TREATED units only (important for treatment effect estimation)
  treated_idx <- data$A == 1

  if (sum(treated_idx) < 10) {
    stop("Need at least 10 treated units for RF training")
  }

  rf_s <- randomForest::randomForest(
    x = X_matrix[treated_idx, , drop = FALSE],
    y = data$S[treated_idx],
    ntree = ntree,
    maxnodes = maxnodes
  )

  rf_y <- randomForest::randomForest(
    x = X_matrix[treated_idx, , drop = FALSE],
    y = data$Y[treated_idx],
    ntree = ntree,
    maxnodes = maxnodes
  )

  # Predict for ALL observations
  pred_s <- predict(rf_s, X_matrix)
  pred_y <- predict(rf_y, X_matrix)

  # Discretize predictions into 2D grid
  s_bins <- cut(
    pred_s,
    breaks = quantile(pred_s, probs = seq(0, 1, length.out = n_bins + 1)),
    labels = FALSE,
    include.lowest = TRUE
  )

  y_bins <- cut(
    pred_y,
    breaks = quantile(pred_y, probs = seq(0, 1, length.out = n_bins + 1)),
    labels = FALSE,
    include.lowest = TRUE
  )

  # Combine into single bin ID
  combined <- paste0(s_bins, "_", y_bins)
  as.integer(factor(combined))
}


#' Quantile-Based Discretization
#'
#' Discretizes observations by binning each covariate into quantiles
#' and combining into multi-dimensional bins.
#'
#' @param data Data frame with covariates
#' @param covariate_cols Character vector of covariate column names
#' @param n_bins Number of quantile bins per covariate
#'
#' @return Integer vector of bin assignments (length nrow(data))
#'
#' @details
#' Each covariate is binned into n_bins quantiles. The combination of
#' bins across all covariates creates J = n_bins^p types (where p is
#' number of covariates). This creates a regular grid in covariate space.
#'
#' @keywords internal
discretize_quantiles <- function(data, covariate_cols, n_bins = 3) {

  X_matrix <- as.matrix(data[, covariate_cols, drop = FALSE])

  # Bin each covariate
  bins_per_var <- apply(X_matrix, 2, function(x) {
    cut(x,
        breaks = quantile(x, probs = seq(0, 1, length.out = n_bins + 1)),
        labels = FALSE,
        include.lowest = TRUE)
  })

  # Combine into single bin ID
  bin_id <- apply(bins_per_var, 1, paste, collapse = "_")
  as.integer(factor(bin_id))
}


#' K-Means Clustering Discretization
#'
#' Discretizes observations via k-means clustering on covariates.
#'
#' @param data Data frame with covariates
#' @param covariate_cols Character vector of covariate column names
#' @param k Number of clusters (types)
#'
#' @return Integer vector of cluster assignments (length nrow(data))
#'
#' @details
#' Performs k-means clustering on scaled covariates. This creates bins
#' that are compact in covariate space (Euclidean distance). Unlike
#' quantile binning, k-means adapts to covariate distribution.
#'
#' @keywords internal
discretize_kmeans <- function(data, covariate_cols, k = 9) {

  X_matrix <- as.matrix(data[, covariate_cols, drop = FALSE])
  X_scaled <- scale(X_matrix)

  # Handle constant columns
  X_scaled[is.na(X_scaled)] <- 0

  km <- stats::kmeans(X_scaled, centers = k, nstart = 10)
  km$cluster
}


#' Discretize Data into Types
#'
#' Main interface for discretizing observations into types (bins).
#'
#' @param data Data frame with A, S, Y, and covariates
#' @param scheme Character: discretization scheme ("rf", "quantiles", "kmeans")
#' @param covariate_cols Character vector of covariate column names.
#'   If NULL, auto-detects all columns except A, S, Y
#' @param J_target Target number of types (used to set parameters)
#' @param ... Additional parameters passed to specific discretization functions
#'
#' @return List with:
#'   \item{bins}{Integer vector of bin assignments}
#'   \item{J}{Number of unique bins created}
#'   \item{scheme}{Scheme used}
#'
#' @details
#' This is the main interface for discretization. It:
#' - Auto-detects covariate columns if needed
#' - Selects and applies the appropriate discretization method
#' - Returns bins and metadata
#'
#' The J_target parameter is used to set scheme-specific parameters
#' (e.g., n_bins for quantiles, k for k-means).
#'
#' @examples
#' \dontrun{
#' data <- generate_study_data(n = 500)
#' result <- discretize_data(data, scheme = "rf", J_target = 16)
#' table(result$bins)  # Distribution of observations across bins
#' }
#'
#' @export
discretize_data <- function(data,
                             scheme = c("rf", "quantiles", "kmeans"),
                             covariate_cols = NULL,
                             J_target = 16,
                             ...) {

  scheme <- match.arg(scheme)

  # Auto-detect covariate columns
  if (is.null(covariate_cols)) {
    covariate_cols <- setdiff(names(data), c("A", "S", "Y"))
    if (length(covariate_cols) == 0) {
      stop("No covariate columns found. Data must have columns other than A, S, Y")
    }
  }

  # Validate covariate columns exist
  missing_cols <- setdiff(covariate_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Covariate columns not found in data: ", paste(missing_cols, collapse = ", "))
  }

  # Apply discretization
  bins <- switch(
    scheme,
    rf = {
      # For RF: J_target ≈ n_bins^2
      n_bins <- max(2, floor(sqrt(J_target)))
      train_rf_partition(data, covariate_cols, n_bins = n_bins, ...)
    },
    quantiles = {
      # For quantiles: J_target ≈ n_bins^p (p = number of covariates)
      p <- length(covariate_cols)
      n_bins <- max(2, floor(J_target^(1/p)))
      discretize_quantiles(data, covariate_cols, n_bins = n_bins, ...)
    },
    kmeans = {
      # For k-means: J = k directly
      discretize_kmeans(data, covariate_cols, k = J_target, ...)
    }
  )

  # Return results
  list(
    bins = bins,
    J = length(unique(bins)),
    scheme = scheme,
    covariate_cols = covariate_cols
  )
}


#' Compute Type Centroids for Wasserstein Distance
#'
#' Computes the centroid (mean covariate vector) for each type (bin)
#' in the discretized data. Used for constructing cost matrices in
#' Wasserstein minimax inference.
#'
#' @param data Data frame with covariate columns
#' @param bins Integer vector of bin assignments (length nrow(data))
#' @param covariate_cols Character vector of covariate column names
#'
#' @return Matrix (J x p) where J = number of unique bins, p = number of covariates.
#'   Each row is the centroid (mean) of covariates for observations in that bin.
#'
#' @details
#' For each bin j, computes:
#'
#' centroid_j = mean(X_i : i in bin j)
#'
#' These centroids define the "location" of each type in covariate space
#' and are used to construct the cost matrix C[i,j] = ||centroid_i - centroid_j||^2
#' for Wasserstein distance computation.
#'
#' **Properties:**
#' - Centroids preserve the relative locations of types in covariate space
#' - Empty bins are excluded from the result
#' - Row names indicate bin IDs
#'
#' **Use in Wasserstein minimax:**
#' 1. Discretize data into types (bins)
#' 2. Compute centroids for each type
#' 3. Construct cost matrix from centroids
#' 4. Use cost matrix in Wasserstein distance calculations
#'
#' @examples
#' \dontrun{
#' # Generate data
#' data <- generate_study_data(n = 500)
#'
#' # Discretize
#' disc <- discretize_data(data, scheme = "rf", J_target = 16)
#'
#' # Compute centroids
#' covariate_cols <- setdiff(names(data), c("A", "S", "Y"))
#' centroids <- compute_type_centroids(data, disc$bins, covariate_cols)
#'
#' # Check dimensions
#' nrow(centroids)  # Should be J (number of types)
#' ncol(centroids)  # Should be p (number of covariates)
#'
#' # Centroids can be used to construct cost matrix
#' C <- compute_type_cost_matrix(centroids, cost_function = "euclidean")
#' }
#'
#' @export
compute_type_centroids <- function(data, bins, covariate_cols) {

  # Validate inputs
  if (nrow(data) != length(bins)) {
    stop("Number of rows in data must match length of bins")
  }

  if (length(covariate_cols) == 0) {
    stop("covariate_cols must have at least one column")
  }

  # Check that covariate columns exist
  missing_cols <- setdiff(covariate_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Covariate columns not found in data: ", paste(missing_cols, collapse = ", "))
  }

  # Extract covariate matrix
  X_matrix <- as.matrix(data[, covariate_cols, drop = FALSE])

  # Get unique bins
  unique_bins <- sort(unique(bins))
  J <- length(unique_bins)
  p <- length(covariate_cols)

  # Initialize centroid matrix
  centroids <- matrix(NA, J, p)
  rownames(centroids) <- as.character(unique_bins)
  colnames(centroids) <- covariate_cols

  # Compute centroid for each bin
  for (i in 1:J) {
    bin_id <- unique_bins[i]
    bin_idx <- which(bins == bin_id)

    if (length(bin_idx) == 0) {
      warning(sprintf("Bin %d has no observations. Skipping.", bin_id))
      next
    }

    # Compute mean of covariates in this bin
    if (length(bin_idx) == 1) {
      # Single observation
      centroids[i, ] <- X_matrix[bin_idx, ]
    } else {
      # Multiple observations
      centroids[i, ] <- colMeans(X_matrix[bin_idx, , drop = FALSE])
    }
  }

  # Remove any rows with all NA (empty bins)
  centroids <- centroids[complete.cases(centroids), , drop = FALSE]

  centroids
}
