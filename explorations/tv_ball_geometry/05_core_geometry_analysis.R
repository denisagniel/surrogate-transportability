# Phase 1: Core TV Ball Geometry Analysis
#
# Implements analyze_tv_ball_geometry() using hit-and-run sampling
# for uniform coverage of the TV ball

library(tidyverse)
library(surrogateTransportability)

source("explorations/tv_ball_geometry/01_hit_and_run_sampler.R")

#' Analyze TV ball geometry using hit-and-run sampling
#'
#' Generates M samples Q uniformly from B_λ(P₀), then for each:
#' - Generates future study data from Q
#' - Computes ΔS(Q), ΔY(Q)
#' - Computes φ(Q) for each functional
#' - Extracts distribution features
#'
#' @param current_data Data frame with current study (must have A, S, Y columns)
#' @param lambda TV ball radius (default: 0.3)
#' @param M Number of Q samples to draw (default: 5000)
#' @param n_future Future study size for each Q (default: 500)
#' @param functionals Character vector of functionals to compute:
#'   "correlation", "ppv", "concordance" (default: all three)
#' @param epsilon_s Threshold for PPV functional (default: 0)
#' @param epsilon_y Threshold for PPV functional (default: 0)
#' @param burn_in Hit-and-run burn-in iterations (default: 1000)
#' @param thin Hit-and-run thinning interval (default: 10)
#' @param seed Random seed (default: NULL)
#' @param verbose Print progress (default: TRUE)
#'
#' @return Tibble with M rows and columns:
#'   - m: sample index
#'   - Delta_S, Delta_Y: treatment effects
#'   - phi_correlation, phi_ppv, phi_concordance: within-study functionals
#'   - tv_to_P0: TV distance to baseline
#'   - entropy, max_mass, gini: distribution features
#'   - (optional) Q_data: nested list column with full Q distribution
#'
#' @export
analyze_tv_ball_geometry <- function(
  current_data,
  lambda = 0.3,
  M = 5000,
  n_future = 500,
  functionals = c("correlation", "ppv", "concordance"),
  epsilon_s = 0,
  epsilon_y = 0,
  burn_in = 1000,
  thin = 10,
  seed = NULL,
  verbose = TRUE
) {

  if (!is.null(seed)) set.seed(seed)

  # Validate inputs
  required_cols <- c("A", "S", "Y")
  if (!all(required_cols %in% names(current_data))) {
    stop("current_data must contain columns: A, S, Y")
  }

  n_current <- nrow(current_data)

  # Baseline distribution P₀ (empirical = uniform)
  P0 <- rep(1/n_current, n_current)

  if (verbose) {
    cat(sprintf("Analyzing TV ball geometry\n"))
    cat(sprintf("  TV ball radius λ = %.2f\n", lambda))
    cat(sprintf("  Samples M = %d\n", M))
    cat(sprintf("  Future study size = %d\n", n_future))
    cat(sprintf("  Current study size = %d\n", n_current))
    cat(sprintf("  Functionals: %s\n", paste(functionals, collapse = ", ")))
    cat(sprintf("\nStep 1: Sampling Q distributions (hit-and-run)\n"))
  }

  # Step 1: Sample Q distributions uniformly from B_λ(P₀)
  Q_samples <- hit_and_run_tv_ball(
    P0 = P0,
    lambda = lambda,
    n_samples = M,
    burn_in = burn_in,
    thin = thin,
    verbose = verbose
  )

  if (verbose) {
    cat(sprintf("\nStep 2: Generating future studies and computing functionals\n"))
    cat(sprintf("  (Processing %d samples)\n", M))
  }

  # Step 2: For each Q, generate study and compute functionals
  results_list <- vector("list", M)

  # Progress tracking
  progress_interval <- ifelse(M >= 100, floor(M / 10), max(1, floor(M / 5)))

  for (m in 1:M) {

    if (verbose && m %% progress_interval == 0) {
      cat(sprintf("    Processed %d / %d (%.1f%%)\n", m, M, 100 * m / M))
    }

    Q_m <- Q_samples[m, ]

    # Generate future study from Q_m
    # Sample indices according to Q_m (probability distribution)
    future_indices <- sample(
      seq_len(n_current),
      size = n_future,
      replace = TRUE,
      prob = Q_m
    )
    future_data <- current_data[future_indices, ]

    # Compute treatment effects ΔS(Q_m), ΔY(Q_m)
    Delta_S <- compute_treatment_effect(future_data, "S")
    Delta_Y <- compute_treatment_effect(future_data, "Y")

    # Compute functionals φ(Q_m)
    # For within-study functionals, we need to generate ANOTHER sample
    # from Q_m (independent from the one used to estimate ΔS, ΔY)
    # This is like sample splitting

    # Generate independent sample for functional computation
    functional_indices <- sample(
      seq_len(n_current),
      size = n_future,
      replace = TRUE,
      prob = Q_m
    )
    functional_data <- current_data[functional_indices, ]

    # Compute within-study correlation φ(Q)
    phi_correlation <- NA
    if ("correlation" %in% functionals) {
      # Within-study correlation: cor(S, Y | Q)
      # For simplicity, use empirical correlation in the sample
      treated <- functional_data$A == 1
      control <- functional_data$A == 0

      if (sum(treated) > 1 && sum(control) > 1) {
        # Estimate treatment effects via regression for within-study functional
        S_treated <- mean(functional_data$S[treated])
        S_control <- mean(functional_data$S[control])
        Y_treated <- mean(functional_data$Y[treated])
        Y_control <- mean(functional_data$Y[control])

        Delta_S_func <- S_treated - S_control
        Delta_Y_func <- Y_treated - Y_control

        # For within-study correlation, we compute cor(ΔS, ΔY) across bootstrap samples
        # This is expensive, so for exploration we'll use a simpler approach:
        # Correlation between S and Y within treated group (as proxy)
        if (sum(treated) > 2) {
          phi_correlation <- cor(functional_data$S[treated], functional_data$Y[treated])
        }
      }
    }

    # Compute PPV functional φ(Q)
    phi_ppv <- NA
    if ("ppv" %in% functionals) {
      # P(ΔY > ε_y | ΔS > ε_s)
      # For within-study, we bootstrap to get distribution of ΔS, ΔY
      n_boot <- 100
      boot_delta_s <- numeric(n_boot)
      boot_delta_y <- numeric(n_boot)

      for (b in 1:n_boot) {
        boot_idx <- sample(seq_len(nrow(functional_data)), replace = TRUE)
        boot_data <- functional_data[boot_idx, ]
        boot_delta_s[b] <- compute_treatment_effect(boot_data, "S")
        boot_delta_y[b] <- compute_treatment_effect(boot_data, "Y")
      }

      # PPV: P(boot_delta_y > epsilon_y | boot_delta_s > epsilon_s)
      exceed_s <- boot_delta_s > epsilon_s
      if (sum(exceed_s) > 0) {
        phi_ppv <- mean(boot_delta_y[exceed_s] > epsilon_y)
      }
    }

    # Compute concordance functional φ(Q)
    phi_concordance <- NA
    if ("concordance" %in% functionals) {
      # E[ΔS * ΔY]
      # Bootstrap to get distribution
      n_boot <- 100
      boot_products <- numeric(n_boot)

      for (b in 1:n_boot) {
        boot_idx <- sample(seq_len(nrow(functional_data)), replace = TRUE)
        boot_data <- functional_data[boot_idx, ]
        ds <- compute_treatment_effect(boot_data, "S")
        dy <- compute_treatment_effect(boot_data, "Y")
        boot_products[b] <- ds * dy
      }

      phi_concordance <- mean(boot_products)
    }

    # Compute distribution features
    tv_to_P0 <- tv_distance(Q_m, P0)

    # Entropy: -sum(Q log Q)
    Q_nonzero <- Q_m[Q_m > 1e-10]
    entropy <- -sum(Q_nonzero * log(Q_nonzero))

    # Max mass
    max_mass <- max(Q_m)

    # Gini coefficient
    sorted_Q <- sort(Q_m)
    n <- length(Q_m)
    gini <- (2 * sum((1:n) * sorted_Q)) / (n * sum(Q_m)) - (n + 1) / n

    # Store results
    results_list[[m]] <- tibble(
      m = m,
      Delta_S = Delta_S,
      Delta_Y = Delta_Y,
      phi_correlation = phi_correlation,
      phi_ppv = phi_ppv,
      phi_concordance = phi_concordance,
      tv_to_P0 = tv_to_P0,
      entropy = entropy,
      max_mass = max_mass,
      gini = gini
    )
  }

  # Combine results
  results <- bind_rows(results_list)

  if (verbose) {
    cat(sprintf("\nCompleted geometry analysis\n"))
    cat(sprintf("  Samples processed: %d\n", nrow(results)))
    cat(sprintf("  Mean TV distance: %.4f\n", mean(results$tv_to_P0)))
    cat(sprintf("  Mean across-study cor(ΔS, ΔY): %.4f\n",
                cor(results$Delta_S, results$Delta_Y)))
  }

  return(results)
}

#' Quick test of geometry analysis
#'
#' @param K dimension (types in current study)
#' @param lambda TV radius
#' @param M number of samples
test_geometry_analysis <- function(K = 50, lambda = 0.3, M = 500) {

  cat(sprintf("Testing geometry analysis: K=%d, λ=%.2f, M=%d\n\n", K, lambda, M))

  # Generate current study data with K types
  # Use simple DGP: treatment effects vary by type
  n_per_type <- 10
  n <- K * n_per_type

  types <- rep(1:K, each = n_per_type)
  A <- rbinom(n, 1, 0.5)

  # Treatment effects vary by type (create heterogeneity)
  # This creates structure: some types benefit more than others
  type_effect_S <- rnorm(K, mean = 0.5, sd = 0.3)
  type_effect_Y <- 0.7 * type_effect_S + rnorm(K, sd = 0.2)

  S <- type_effect_S[types] * A + rnorm(n, sd = 0.5)
  Y <- type_effect_Y[types] * A + 0.3 * S + rnorm(n, sd = 0.5)

  current_data <- tibble(
    type = types,
    A = A,
    S = S,
    Y = Y
  )

  cat("Generated current study data\n")
  cat(sprintf("  Sample size: %d\n", n))
  cat(sprintf("  Types: %d\n", K))
  cat(sprintf("  True correlation between type effects: %.3f\n",
              cor(type_effect_S, type_effect_Y)))

  # Run geometry analysis
  cat("\nRunning geometry analysis...\n")
  results <- analyze_tv_ball_geometry(
    current_data = current_data,
    lambda = lambda,
    M = M,
    n_future = 300,
    functionals = c("correlation", "concordance"),
    burn_in = 500,
    thin = 5,
    verbose = TRUE
  )

  # Analyze results
  cat("\n=== Results Summary ===\n")
  cat(sprintf("Across-study correlation: %.4f\n", cor(results$Delta_S, results$Delta_Y)))
  cat(sprintf("  (True type-level correlation: %.3f)\n", cor(type_effect_S, type_effect_Y)))

  cat(sprintf("\nTV distance statistics:\n"))
  cat(sprintf("  Mean: %.4f\n", mean(results$tv_to_P0)))
  cat(sprintf("  SD: %.4f\n", sd(results$tv_to_P0)))
  cat(sprintf("  Max: %.4f (ball radius: %.2f)\n", max(results$tv_to_P0), lambda))

  cat(sprintf("\nWithin-study functionals:\n"))
  if ("phi_correlation" %in% names(results)) {
    valid_corr <- results$phi_correlation[!is.na(results$phi_correlation)]
    if (length(valid_corr) > 0) {
      cat(sprintf("  Mean φ_correlation: %.4f\n", mean(valid_corr)))
    }
  }
  if ("phi_concordance" %in% names(results)) {
    valid_conc <- results$phi_concordance[!is.na(results$phi_concordance)]
    if (length(valid_conc) > 0) {
      cat(sprintf("  Mean φ_concordance: %.4f\n", mean(valid_conc)))
    }
  }

  # Quick plot
  p <- ggplot(results, aes(x = Delta_S, y = Delta_Y)) +
    geom_point(alpha = 0.3, size = 1) +
    geom_smooth(method = "lm", color = "red", se = TRUE) +
    labs(
      title = sprintf("Across-Study Correlation (K=%d, λ=%.2f)", K, lambda),
      subtitle = sprintf("Cor = %.3f", cor(results$Delta_S, results$Delta_Y)),
      x = expression(Delta[S](Q)),
      y = expression(Delta[Y](Q))
    ) +
    theme_minimal()

  print(p)

  invisible(results)
}

# Run test if interactive
if (interactive()) {
  test_results <- test_geometry_analysis(K = 50, lambda = 0.3, M = 500)
}
