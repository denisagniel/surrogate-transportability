#!/usr/bin/env Rscript
#' Comprehensive Diagnostics for TV-Ball Minimax Coverage Failure
#'
#' Runs 6 systematic diagnostic tests on worst-case scenario:
#' n=250, low_het_high_cor, λ=0.4 (29% coverage currently)
#'
#' Each diagnostic tests a specific hypothesis about root cause

library(tidyverse)
library(here)

# Load package
devtools::load_all(here("package"))

cat("========================================\n")
cat("TV-Ball Minimax Coverage Diagnostics\n")
cat("========================================\n\n")

# ============================================
# CONFIGURATION
# ============================================

# Worst setting from full simulation
WORST_SETTING <- list(
  n = 250,
  scenario = "low_het_high_cor",
  lambda = 0.4,
  J = 16,
  rho = 0.9,
  cv = 0.1
)

N_REPS <- 100  # Replications per diagnostic (quick for diagnosis)

cat("Testing worst setting:\n")
cat("  n =", WORST_SETTING$n, "\n")
cat("  scenario =", WORST_SETTING$scenario, "\n")
cat("  lambda =", WORST_SETTING$lambda, "\n")
cat("  J =", WORST_SETTING$J, "\n")
cat("  rho =", WORST_SETTING$rho, "(correlation between tau_s and tau_y)\n")
cat("  cv =", WORST_SETTING$cv, "(coefficient of variation)\n")
cat("  replications =", N_REPS, "\n\n")

# ============================================
# DATA GENERATION WITH KNOWN TRUE TYPES
# ============================================

generate_data_with_true_types <- function(n, J, rho, cv, seed) {
  set.seed(seed)

  # Generate treatment effects for J true types
  tau_y <- rnorm(J, mean = 0.5, sd = cv)
  tau_s <- rho * tau_y + sqrt(1 - rho^2) * rnorm(J, sd = cv)

  # Type probabilities (uniform)
  pi_types <- rep(1/J, J)

  # Generate data with known type assignments
  true_types <- sample(1:J, size = n, replace = TRUE, prob = pi_types)
  A <- rbinom(n, 1, 0.5)
  X <- rnorm(n)

  S <- tau_s[true_types] * A + 0.3 * X + rnorm(n, sd = 0.5)
  Y <- tau_y[true_types] * A + 0.2 * X + rnorm(n, sd = 0.4)

  data <- tibble(type = true_types, A = A, X = X, S = S, Y = Y)

  # True values
  true_concordance_p0 <- sum(pi_types * tau_s * tau_y)
  concordances <- tau_s * tau_y
  true_min_concordance <- min(concordances)

  list(
    data = data,
    true_types = true_types,
    tau_s = tau_s,
    tau_y = tau_y,
    pi_types = pi_types,
    true_concordance_p0 = true_concordance_p0,
    true_min_concordance = true_min_concordance
  )
}

# ============================================
# DIAGNOSTIC 1: TRUE TYPES vs DISCRETIZED
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 1: True Types vs Discretized\n")
cat("========================================\n")
cat("Hypothesis: Discretization mismatch causes underestimation\n\n")

run_diagnostic_1 <- function() {
  cat("Running", N_REPS, "replications...\n")

  results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 10 == 0) cat("  Rep", rep, "/", N_REPS, "\n")

    dgp <- generate_data_with_true_types(
      WORST_SETTING$n, WORST_SETTING$J,
      WORST_SETTING$rho, WORST_SETTING$cv,
      seed = rep
    )

    true_minimax <- (1 - WORST_SETTING$lambda) * dgp$true_concordance_p0 +
                    WORST_SETTING$lambda * dgp$true_min_concordance

    # A. WITH DISCRETIZATION (current approach)
    est_disc <- tryCatch({
      surrogate_inference_minimax(
        current_data = dgp$data,
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance",
        discretization_schemes = c("rf", "quantiles", "kmeans"),
        J_target = WORST_SETTING$J,
        n_bootstrap = 100,
        confidence_level = 0.95,
        parallel = FALSE,  # Disable parallel to avoid FutureInterruptError
        verbose = FALSE
      )
    }, error = function(e) {
      cat("  ERROR in discretized for rep", rep, ":", conditionMessage(e), "\n")
      NULL
    })

    # Validate result (check is.list BEFORE accessing elements!)
    if (!is.null(est_disc)) {
      if (!is.list(est_disc)) {
        cat("  WARNING: result is not a list for rep", rep, "- skipping\n")
        est_disc <- NULL
      } else if (is.null(est_disc$phi_star) || is.null(est_disc$ci_lower)) {
        cat("  WARNING: missing required fields for rep", rep, "- skipping\n")
        est_disc <- NULL
      }
    }

    # B. WITH TRUE TYPES (no discretization)
    est_true <- tryCatch({
      # Use estimate_minimax_single_scheme with known types
      result <- estimate_minimax_single_scheme(
        data = dgp$data,
        bins = dgp$true_types,
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance"
      )

      # Bootstrap CI manually for true types
      bootstrap_estimates <- numeric(100)
      for (b in 1:100) {
        boot_idx <- sample(1:nrow(dgp$data), replace = TRUE)
        boot_data <- dgp$data[boot_idx, ]
        boot_types <- dgp$true_types[boot_idx]
        boot_est <- estimate_minimax_single_scheme(
          data = boot_data,
          bins = boot_types,
          lambda = WORST_SETTING$lambda,
          functional_type = "concordance"
        )
        bootstrap_estimates[b] <- boot_est$phi_value
      }

      ci <- quantile(bootstrap_estimates, c(0.025, 0.975), na.rm = TRUE)

      # Return structured result
      list(
        phi_star = result$phi_value,
        ci_lower = as.numeric(ci[1]),
        ci_upper = as.numeric(ci[2])
      )
    }, error = function(e) {
      cat("  ERROR in true types for rep", rep, ":", conditionMessage(e), "\n")
      NULL
    })

    if (is.null(est_disc) || is.null(est_true)) {
      return(NULL)
    }

    # Create result tibble with error handling
    tryCatch({
      # Extract values explicitly to see which one fails
      val_est_disc <- est_disc$phi_star
      val_ci_lower_disc <- est_disc$ci_lower
      val_ci_upper_disc <- est_disc$ci_upper
      val_est_true <- est_true$phi_star
      val_ci_lower_true <- est_true$ci_lower
      val_ci_upper_true <- est_true$ci_upper
      val_truth <- true_minimax
      val_truth_p0 <- dgp$true_concordance_p0

      tibble(
        rep = rep,
        est_disc = val_est_disc,
        ci_lower_disc = val_ci_lower_disc,
        ci_upper_disc = val_ci_upper_disc,
        est_true = val_est_true,
        ci_lower_true = val_ci_lower_true,
        ci_upper_true = val_ci_upper_true,
        truth = val_truth,
        truth_p0 = val_truth_p0,
        covered_disc = (val_truth >= val_ci_lower_disc & val_truth <= val_ci_upper_disc),
        covered_true = (val_truth >= val_ci_lower_true & val_truth <= val_ci_upper_true)
      )
    }, error = function(e) {
      cat("  ERROR creating tibble for rep", rep, ":", conditionMessage(e), "\n")
      cat("    est_disc names:", paste(names(est_disc), collapse=", "), "\n")
      cat("    est_true names:", paste(names(est_true), collapse=", "), "\n")
      return(NULL)
    })
  })

  results <- results %>% filter(!is.na(rep))

  summary <- list(
    coverage_disc = mean(results$covered_disc, na.rm = TRUE),
    coverage_true = mean(results$covered_true, na.rm = TRUE),
    bias_disc = mean(results$est_disc - results$truth, na.rm = TRUE),
    bias_true = mean(results$est_true - results$truth, na.rm = TRUE),
    mean_est_disc = mean(results$est_disc, na.rm = TRUE),
    mean_est_true = mean(results$est_true, na.rm = TRUE),
    mean_truth = mean(results$truth, na.rm = TRUE),
    n_reps = nrow(results),
    results = results
  )

  cat("\nRESULTS:\n")
  cat("  Discretized: coverage =", round(summary$coverage_disc, 3),
      "| bias =", round(summary$bias_disc, 4),
      "| mean est =", round(summary$mean_est_disc, 4), "\n")
  cat("  True types:  coverage =", round(summary$coverage_true, 3),
      "| bias =", round(summary$bias_true, 4),
      "| mean est =", round(summary$mean_est_true, 4), "\n")
  cat("  Truth mean:", round(summary$mean_truth, 4), "\n\n")

  if (summary$coverage_true > 0.90 && summary$coverage_disc < 0.70) {
    cat("*** DIAGNOSIS: Discretization mismatch is the ROOT CAUSE ***\n\n")
  } else if (abs(summary$coverage_true - summary$coverage_disc) < 0.05) {
    cat("*** DIAGNOSIS: Discretization is NOT the issue (both similar) ***\n\n")
  } else {
    cat("*** DIAGNOSIS: Partial improvement, but not full fix ***\n\n")
  }

  summary
}

diag_1 <- run_diagnostic_1()

# ============================================
# DIAGNOSTIC 2: INDIVIDUAL SCHEMES vs ENSEMBLE
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 2: Individual Schemes vs Ensemble\n")
cat("========================================\n")
cat("Hypothesis: Ensemble minimum amplifies errors\n\n")

run_diagnostic_2 <- function() {
  cat("Running", N_REPS, "replications...\n")

  results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 10 == 0) cat("  Rep", rep, "/", N_REPS, "\n")

    dgp <- generate_data_with_true_types(
      WORST_SETTING$n, WORST_SETTING$J,
      WORST_SETTING$rho, WORST_SETTING$cv,
      seed = rep + 10000  # Different seed from diagnostic 1
    )

    true_minimax <- (1 - WORST_SETTING$lambda) * dgp$true_concordance_p0 +
                    WORST_SETTING$lambda * dgp$true_min_concordance

    # Test each scheme individually
    schemes_to_test <- c("rf", "quantiles", "kmeans")
    scheme_results <- list()

    for (scheme in schemes_to_test) {
      est <- tryCatch({
        surrogate_inference_minimax(
          current_data = dgp$data,
          lambda = WORST_SETTING$lambda,
          functional_type = "concordance",
          discretization_schemes = scheme,  # Single scheme
          J_target = WORST_SETTING$J,
          n_bootstrap = 100,
          confidence_level = 0.95,
          parallel = FALSE,  # Disable parallel
          verbose = FALSE
        )
      }, error = function(e) NULL)

      if (!is.null(est)) {
        scheme_results[[scheme]] <- list(
          estimate = est$phi_star,
          ci_lower = est$ci_lower,
          ci_upper = est$ci_upper,
          covered = (true_minimax >= est$ci_lower & true_minimax <= est$ci_upper)
        )
      }
    }

    # Also test ensemble
    est_ensemble <- tryCatch({
      surrogate_inference_minimax(
        current_data = dgp$data,
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance",
        discretization_schemes = schemes_to_test,  # All schemes
        J_target = WORST_SETTING$J,
        n_bootstrap = 100,
        confidence_level = 0.95,
        parallel = FALSE,  # Disable parallel
        verbose = FALSE
      )
    }, error = function(e) NULL)

    if (is.null(est_ensemble)) return(NULL)

    # Extract values explicitly before tibble creation
    val_est_ensemble <- est_ensemble$phi_star
    val_ci_lower_ensemble <- est_ensemble$ci_lower
    val_ci_upper_ensemble <- est_ensemble$ci_upper
    val_covered_ensemble <- (true_minimax >= val_ci_lower_ensemble & true_minimax <= val_ci_upper_ensemble)

    tibble(
      rep = rep,
      est_rf = if("rf" %in% names(scheme_results)) scheme_results$rf$estimate else NA_real_,
      covered_rf = if("rf" %in% names(scheme_results)) scheme_results$rf$covered else NA,
      est_quantiles = if("quantiles" %in% names(scheme_results)) scheme_results$quantiles$estimate else NA_real_,
      covered_quantiles = if("quantiles" %in% names(scheme_results)) scheme_results$quantiles$covered else NA,
      est_kmeans = if("kmeans" %in% names(scheme_results)) scheme_results$kmeans$estimate else NA_real_,
      covered_kmeans = if("kmeans" %in% names(scheme_results)) scheme_results$kmeans$covered else NA,
      est_ensemble = val_est_ensemble,
      covered_ensemble = val_covered_ensemble,
      truth = true_minimax
    )
  })

  results <- results %>% filter(!is.na(rep))

  summary <- list(
    coverage_rf = mean(results$covered_rf, na.rm = TRUE),
    coverage_quantiles = mean(results$covered_quantiles, na.rm = TRUE),
    coverage_kmeans = mean(results$covered_kmeans, na.rm = TRUE),
    coverage_ensemble = mean(results$covered_ensemble, na.rm = TRUE),
    mean_est_rf = mean(results$est_rf, na.rm = TRUE),
    mean_est_quantiles = mean(results$est_quantiles, na.rm = TRUE),
    mean_est_kmeans = mean(results$est_kmeans, na.rm = TRUE),
    mean_est_ensemble = mean(results$est_ensemble, na.rm = TRUE),
    mean_truth = mean(results$truth, na.rm = TRUE),
    n_reps = nrow(results),
    results = results
  )

  cat("\nRESULTS:\n")
  cat("  RF:        coverage =", round(summary$coverage_rf, 3),
      "| mean est =", round(summary$mean_est_rf, 4), "\n")
  cat("  Quantiles: coverage =", round(summary$coverage_quantiles, 3),
      "| mean est =", round(summary$mean_est_quantiles, 4), "\n")
  cat("  K-means:   coverage =", round(summary$coverage_kmeans, 3),
      "| mean est =", round(summary$mean_est_kmeans, 4), "\n")
  cat("  Ensemble:  coverage =", round(summary$coverage_ensemble, 3),
      "| mean est =", round(summary$mean_est_ensemble, 4), "\n")
  cat("  Truth mean:", round(summary$mean_truth, 4), "\n\n")

  if (max(summary$coverage_rf, summary$coverage_quantiles, summary$coverage_kmeans, na.rm = TRUE) > 0.90 &&
      summary$coverage_ensemble < 0.70) {
    cat("*** DIAGNOSIS: Ensemble minimum IS the ROOT CAUSE ***\n\n")
  } else if (all(c(summary$coverage_rf, summary$coverage_quantiles, summary$coverage_kmeans) < 0.70, na.rm = TRUE)) {
    cat("*** DIAGNOSIS: All schemes fail; ensemble is NOT the issue ***\n\n")
  } else {
    cat("*** DIAGNOSIS: Mixed results; partial issue with ensemble ***\n\n")
  }

  summary
}

diag_2 <- run_diagnostic_2()

# ============================================
# DIAGNOSTIC 3: INCREASING J
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 3: Effect of Number of Types (J)\n")
cat("========================================\n")
cat("Hypothesis: J=16 is too coarse; need more types\n\n")

run_diagnostic_3 <- function() {
  J_values <- c(16, 32, 64)
  n_reps_per_J <- 50  # Fewer reps per J value

  cat("Testing J values:", paste(J_values, collapse=", "), "\n")
  cat("Replications per J:", n_reps_per_J, "\n\n")

  all_results <- list()

  for (J_test in J_values) {
    cat("Testing J =", J_test, "...\n")

    results <- map_dfr(1:n_reps_per_J, function(rep) {
      dgp <- generate_data_with_true_types(
        WORST_SETTING$n, J_test,
        WORST_SETTING$rho, WORST_SETTING$cv,
        seed = rep + 20000 + J_test * 1000
      )

      true_minimax <- (1 - WORST_SETTING$lambda) * dgp$true_concordance_p0 +
                      WORST_SETTING$lambda * dgp$true_min_concordance

      est <- tryCatch({
        surrogate_inference_minimax(
          current_data = dgp$data,
          lambda = WORST_SETTING$lambda,
          functional_type = "concordance",
          discretization_schemes = "quantiles",  # Use one scheme for speed
          J_target = J_test,
          n_bootstrap = 100,
          confidence_level = 0.95,
          parallel = FALSE,  # Disable parallel
          verbose = FALSE
        )
      }, error = function(e) NULL)

      if (is.null(est)) return(NULL)

      # Extract values explicitly before tibble creation
      val_estimate <- est$phi_star
      val_ci_lower <- est$ci_lower
      val_ci_upper <- est$ci_upper
      val_covered <- (true_minimax >= val_ci_lower & true_minimax <= val_ci_upper)

      tibble(
        J = J_test,
        rep = rep,
        estimate = val_estimate,
        ci_lower = val_ci_lower,
        ci_upper = val_ci_upper,
        truth = true_minimax,
        covered = val_covered
      )
    })

    results <- results %>% filter(!is.na(rep))
    all_results[[as.character(J_test)]] <- results
  }

  combined <- bind_rows(all_results)

  summary <- combined %>%
    group_by(J) %>%
    summarise(
      coverage = mean(covered, na.rm = TRUE),
      mean_estimate = mean(estimate, na.rm = TRUE),
      mean_truth = mean(truth, na.rm = TRUE),
      bias = mean(estimate - truth, na.rm = TRUE),
      n_reps = n()
    )

  cat("\nRESULTS:\n")
  print(summary, n = Inf)
  cat("\n")

  if (summary %>% filter(J == max(J)) %>% pull(coverage) > 0.90) {
    cat("*** DIAGNOSIS: Increasing J FIXES the issue ***\n\n")
  } else if (all(summary$coverage < 0.70)) {
    cat("*** DIAGNOSIS: J is NOT the issue (all fail) ***\n\n")
  } else {
    cat("*** DIAGNOSIS: Increasing J helps but doesn't fully fix ***\n\n")
  }

  list(summary = summary, results = combined)
}

diag_3 <- run_diagnostic_3()

# ============================================
# DIAGNOSTIC 4: CLOSED-FORM vs SAMPLING
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 4: Closed-Form vs Sampling\n")
cat("========================================\n")
cat("Hypothesis: Bug in closed-form implementation\n\n")

run_diagnostic_4 <- function() {
  cat("Running", N_REPS, "replications...\n")

  results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 10 == 0) cat("  Rep", rep, "/", N_REPS, "\n")

    dgp <- generate_data_with_true_types(
      WORST_SETTING$n, WORST_SETTING$J,
      WORST_SETTING$rho, WORST_SETTING$cv,
      seed = rep + 30000
    )

    true_minimax <- (1 - WORST_SETTING$lambda) * dgp$true_concordance_p0 +
                    WORST_SETTING$lambda * dgp$true_min_concordance

    # A. CLOSED-FORM (current)
    # The estimate_minimax_single_scheme uses closed-form for concordance
    est_closed <- tryCatch({
      result <- estimate_minimax_single_scheme(
        data = dgp$data,
        bins = dgp$true_types,  # Use true types to isolate formula issue
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance"
      )
      result$phi_value
    }, error = function(e) NA_real_)

    # B. SAMPLING (brute force check)
    # Manually compute via sampling to verify what the answer should be
    est_sampling <- tryCatch({
      type_stats <- compute_type_level_effects(dgp$data, dgp$true_types)

      # Generate many Dirichlet innovations and compute minimum
      M <- 5000
      innovations <- MCMCpack::rdirichlet(M, rep(1, type_stats$J))

      concordances <- numeric(M)
      for (m in 1:M) {
        # Type-level mixture weights
        q_m <- (1 - WORST_SETTING$lambda) * type_stats$p0 + WORST_SETTING$lambda * innovations[m, ]

        # Concordance under Q_m
        concordances[m] <- sum(q_m * type_stats$tau_s * type_stats$tau_y)
      }

      # Minimax is minimum over all Q
      min(concordances)
    }, error = function(e) NA_real_)

    # C. THEORETICAL (from true parameters)
    est_theoretical <- true_minimax

    tibble(
      rep = rep,
      est_closed = est_closed,
      est_sampling = est_sampling,
      est_theoretical = est_theoretical,
      truth = true_minimax,
      diff_closed_truth = est_closed - true_minimax,
      diff_sampling_truth = est_sampling - true_minimax
    )
  })

  results <- results %>% filter(!is.na(rep))

  summary <- list(
    mean_closed = mean(results$est_closed, na.rm = TRUE),
    mean_sampling = mean(results$est_sampling, na.rm = TRUE),
    mean_theoretical = mean(results$est_theoretical, na.rm = TRUE),
    mean_truth = mean(results$truth, na.rm = TRUE),
    bias_closed = mean(results$diff_closed_truth, na.rm = TRUE),
    bias_sampling = mean(results$diff_sampling_truth, na.rm = TRUE),
    correlation_closed_sampling = cor(results$est_closed, results$est_sampling, use = "complete.obs"),
    n_reps = nrow(results),
    results = results
  )

  cat("\nRESULTS:\n")
  cat("  Closed-form: mean =", round(summary$mean_closed, 4),
      "| bias =", round(summary$bias_closed, 4), "\n")
  cat("  Sampling:    mean =", round(summary$mean_sampling, 4),
      "| bias =", round(summary$bias_sampling, 4), "\n")
  cat("  Theoretical: mean =", round(summary$mean_theoretical, 4), "\n")
  cat("  Correlation (closed vs sampling):", round(summary$correlation_closed_sampling, 3), "\n\n")

  if (abs(summary$bias_closed) > 0.02 && abs(summary$bias_sampling) < 0.01) {
    cat("*** DIAGNOSIS: Closed-form implementation HAS A BUG ***\n\n")
  } else if (abs(summary$bias_closed - summary$bias_sampling) < 0.01) {
    cat("*** DIAGNOSIS: Closed-form is correct (matches sampling) ***\n\n")
  } else {
    cat("*** DIAGNOSIS: Both biased; issue is elsewhere ***\n\n")
  }

  summary
}

diag_4 <- run_diagnostic_4()

# ============================================
# DIAGNOSTIC 5: TV-BALL vs WASSERSTEIN
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 5: TV-Ball vs Wasserstein\n")
cat("========================================\n")
cat("Hypothesis: Issue is specific to TV-ball\n\n")

run_diagnostic_5 <- function() {
  cat("Running", N_REPS, "replications...\n")
  cat("NOTE: Wasserstein has different λ scale (need to map)\n\n")

  results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 10 == 0) cat("  Rep", rep, "/", N_REPS, "\n")

    dgp <- generate_data_with_true_types(
      WORST_SETTING$n, WORST_SETTING$J,
      WORST_SETTING$rho, WORST_SETTING$cv,
      seed = rep + 40000
    )

    # A. TV-BALL (current, known to fail)
    est_tv <- tryCatch({
      surrogate_inference_minimax(
        current_data = dgp$data,
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance",
        discretization_schemes = c("rf", "quantiles", "kmeans"),
        J_target = WORST_SETTING$J,
        n_bootstrap = 100,
        confidence_level = 0.95,
        parallel = FALSE,  # Disable parallel
        verbose = FALSE
      )
    }, error = function(e) NULL)

    # B. WASSERSTEIN
    # Use comparable λ_W (needs investigation)
    est_wass <- tryCatch({
      surrogate_inference_minimax_wasserstein(
        current_data = dgp$data,
        lambda_W = WORST_SETTING$lambda,  # May need adjustment
        functional_type = "concordance",
        discretization_schemes = c("rf", "quantiles", "kmeans"),
        J_target = WORST_SETTING$J,
        n_bootstrap = 100,
        confidence_level = 0.95,
        verbose = FALSE
      )
    }, error = function(e) NULL)

    if (is.null(est_tv) || is.null(est_wass)) return(NULL)

    # Extract values explicitly before tibble creation
    val_est_tv <- est_tv$phi_star
    val_ci_lower_tv <- est_tv$ci_lower
    val_ci_upper_tv <- est_tv$ci_upper
    val_est_wass <- est_wass$phi_star
    val_ci_lower_wass <- est_wass$ci_lower
    val_ci_upper_wass <- est_wass$ci_upper

    tibble(
      rep = rep,
      est_tv = val_est_tv,
      ci_lower_tv = val_ci_lower_tv,
      ci_upper_tv = val_ci_upper_tv,
      est_wass = val_est_wass,
      ci_lower_wass = val_ci_lower_wass,
      ci_upper_wass = val_ci_upper_wass
    )
  })

  results <- results %>% filter(!is.na(rep))

  summary <- list(
    mean_tv = mean(results$est_tv, na.rm = TRUE),
    mean_wass = mean(results$est_wass, na.rm = TRUE),
    sd_tv = sd(results$est_tv, na.rm = TRUE),
    sd_wass = sd(results$est_wass, na.rm = TRUE),
    n_reps = nrow(results),
    results = results
  )

  cat("\nRESULTS:\n")
  cat("  TV-ball:     mean =", round(summary$mean_tv, 4),
      "| sd =", round(summary$sd_tv, 4), "\n")
  cat("  Wasserstein: mean =", round(summary$mean_wass, 4),
      "| sd =", round(summary$sd_wass, 4), "\n\n")

  cat("NOTE: Wasserstein and TV-ball have different scales.\n")
  cat("This diagnostic checks if Wasserstein has similar issues.\n\n")

  summary
}

diag_5 <- run_diagnostic_5()

# ============================================
# DIAGNOSTIC 6: POINT ESTIMATE vs CI CONSTRUCTION
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 6: Point Estimate vs CI Width\n")
cat("========================================\n")
cat("Hypothesis: Point estimate is fine, CI too narrow\n\n")

run_diagnostic_6 <- function() {
  cat("Running", N_REPS, "replications...\n")

  results <- map_dfr(1:N_REPS, function(rep) {
    if (rep %% 10 == 0) cat("  Rep", rep, "/", N_REPS, "\n")

    dgp <- generate_data_with_true_types(
      WORST_SETTING$n, WORST_SETTING$J,
      WORST_SETTING$rho, WORST_SETTING$cv,
      seed = rep + 50000
    )

    true_minimax <- (1 - WORST_SETTING$lambda) * dgp$true_concordance_p0 +
                    WORST_SETTING$lambda * dgp$true_min_concordance

    est <- tryCatch({
      surrogate_inference_minimax(
        current_data = dgp$data,
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance",
        discretization_schemes = c("rf", "quantiles", "kmeans"),
        J_target = WORST_SETTING$J,
        n_bootstrap = 200,  # More bootstrap for CI analysis
        confidence_level = 0.95,
        parallel = FALSE,  # Disable parallel
        verbose = FALSE
      )
    }, error = function(e) NULL)

    if (is.null(est)) return(NULL)

    # Extract values explicitly before tibble creation
    val_estimate <- est$phi_star
    val_ci_lower <- est$ci_lower
    val_ci_upper <- est$ci_upper

    # Check if truth is within ±1.96 SE of estimate
    # (approximation if CI is correctly calibrated)
    ci_width <- val_ci_upper - val_ci_lower
    se_approx <- ci_width / (2 * 1.96)
    z_score <- (val_estimate - true_minimax) / se_approx

    tibble(
      rep = rep,
      estimate = val_estimate,
      ci_lower = val_ci_lower,
      ci_upper = val_ci_upper,
      truth = true_minimax,
      ci_width = ci_width,
      se_approx = se_approx,
      z_score = z_score,
      covered = (true_minimax >= val_ci_lower & true_minimax <= val_ci_upper),
      truth_below_ci = (true_minimax < val_ci_lower),
      truth_above_ci = (true_minimax > val_ci_upper)
    )
  })

  results <- results %>% filter(!is.na(rep))

  summary <- list(
    coverage = mean(results$covered, na.rm = TRUE),
    pct_truth_below = mean(results$truth_below_ci, na.rm = TRUE),
    pct_truth_above = mean(results$truth_above_ci, na.rm = TRUE),
    mean_z_score = mean(results$z_score, na.rm = TRUE),
    sd_z_score = sd(results$z_score, na.rm = TRUE),
    mean_estimate = mean(results$estimate, na.rm = TRUE),
    mean_truth = mean(results$truth, na.rm = TRUE),
    mean_ci_width = mean(results$ci_width, na.rm = TRUE),
    n_reps = nrow(results),
    results = results
  )

  cat("\nRESULTS:\n")
  cat("  Coverage:", round(summary$coverage, 3), "\n")
  cat("  Truth below CI:", round(summary$pct_truth_below, 3), "\n")
  cat("  Truth above CI:", round(summary$pct_truth_above, 3), "\n")
  cat("  Mean Z-score:", round(summary$mean_z_score, 2),
      "(should be ~0 if well-calibrated)\n")
  cat("  SD Z-score:", round(summary$sd_z_score, 2),
      "(should be ~1 if well-calibrated)\n")
  cat("  Mean estimate:", round(summary$mean_estimate, 4), "\n")
  cat("  Mean truth:", round(summary$mean_truth, 4), "\n")
  cat("  Mean CI width:", round(summary$mean_ci_width, 4), "\n\n")

  if (abs(summary$mean_estimate - summary$mean_truth) < 0.01 && summary$coverage < 0.70) {
    cat("*** DIAGNOSIS: Point estimate is unbiased; CI is too narrow ***\n\n")
  } else if (abs(summary$mean_z_score) > 2) {
    cat("*** DIAGNOSIS: Point estimate is BIASED (not a CI width issue) ***\n\n")
  } else {
    cat("*** DIAGNOSIS: Mixed issue (bias and CI width) ***\n\n")
  }

  summary
}

diag_6 <- run_diagnostic_6()

# ============================================
# DIAGNOSTIC 7: OBSERVATION-LEVEL vs TYPE-LEVEL
# ============================================

cat("========================================\n")
cat("DIAGNOSTIC 7: Observation-Level vs Type-Level\n")
cat("========================================\n")
cat("Hypothesis: J-dimensional approximation is fundamentally inadequate\n")
cat("(Tests if discretization approach itself is the bottleneck)\n\n")

run_diagnostic_7 <- function() {
  n_reps_d7 <- 30  # Fewer reps (observation-level is SLOW)

  cat("Running", n_reps_d7, "replications...\n")
  cat("NOTE: Observation-level uses n-dimensional Dirichlet (SLOW but no discretization)\n\n")

  results <- map_dfr(1:n_reps_d7, function(rep) {
    if (rep %% 5 == 0) cat("  Rep", rep, "/", n_reps_d7, "\n")

    dgp <- generate_data_with_true_types(
      WORST_SETTING$n, WORST_SETTING$J,
      WORST_SETTING$rho, WORST_SETTING$cv,
      seed = rep + 60000
    )

    true_minimax <- (1 - WORST_SETTING$lambda) * dgp$true_concordance_p0 +
                    WORST_SETTING$lambda * dgp$true_min_concordance

    # A. TYPE-LEVEL (J-dimensional, current approach)
    est_type <- tryCatch({
      surrogate_inference_minimax(
        current_data = dgp$data,
        lambda = WORST_SETTING$lambda,
        functional_type = "concordance",
        discretization_schemes = c("rf", "quantiles", "kmeans"),
        J_target = WORST_SETTING$J,
        n_bootstrap = 100,
        confidence_level = 0.95,
        parallel = FALSE,  # Disable parallel
        verbose = FALSE
      )
    }, error = function(e) NULL)

    # B. OBSERVATION-LEVEL (n-dimensional, no discretization)
    # This is the "true" continuous approach used in validation
    est_obs <- tryCatch({
      n <- nrow(dgp$data)

      # Generate n-dimensional Dirichlet innovations
      M <- 1000  # Same as validation
      innovations_n_dim <- MCMCpack::rdirichlet(M, rep(1, n))

      # Compute concordance for each innovation
      concordances <- numeric(M)

      for (m in 1:M) {
        # Type-level mixture (but with n dimensions)
        p0 <- rep(1/n, n)
        p_tilde <- innovations_n_dim[m, ]
        q_m <- (1 - WORST_SETTING$lambda) * p0 + WORST_SETTING$lambda * p_tilde

        # Compute treatment effects under Q_m via reweighting
        treated_idx <- dgp$data$A == 1
        control_idx <- dgp$data$A == 0

        if (sum(q_m[treated_idx]) > 0 && sum(q_m[control_idx]) > 0) {
          delta_s <- sum(q_m[treated_idx] * dgp$data$S[treated_idx]) / sum(q_m[treated_idx]) -
                     sum(q_m[control_idx] * dgp$data$S[control_idx]) / sum(q_m[control_idx])

          delta_y <- sum(q_m[treated_idx] * dgp$data$Y[treated_idx]) / sum(q_m[treated_idx]) -
                     sum(q_m[control_idx] * dgp$data$Y[control_idx]) / sum(q_m[control_idx])

          concordances[m] <- delta_s * delta_y
        }
      }

      # Minimax is minimum over all Q
      phi_obs <- min(concordances, na.rm = TRUE)

      # Bootstrap CI for observation-level
      bootstrap_estimates_obs <- numeric(50)  # Fewer bootstrap (already slow)
      for (b in 1:50) {
        boot_idx <- sample(1:n, replace = TRUE)
        boot_data <- dgp$data[boot_idx, ]
        n_boot <- nrow(boot_data)

        # Same process on bootstrap sample
        M_boot <- 500  # Even fewer for bootstrap
        innov_boot <- MCMCpack::rdirichlet(M_boot, rep(1, n_boot))

        conc_boot <- numeric(M_boot)
        for (m in 1:M_boot) {
          p0_boot <- rep(1/n_boot, n_boot)
          q_m_boot <- (1 - WORST_SETTING$lambda) * p0_boot + WORST_SETTING$lambda * innov_boot[m, ]

          treated_boot <- boot_data$A == 1
          control_boot <- boot_data$A == 0

          if (sum(q_m_boot[treated_boot]) > 0 && sum(q_m_boot[control_boot]) > 0) {
            delta_s_boot <- sum(q_m_boot[treated_boot] * boot_data$S[treated_boot]) / sum(q_m_boot[treated_boot]) -
                           sum(q_m_boot[control_boot] * boot_data$S[control_boot]) / sum(q_m_boot[control_boot])

            delta_y_boot <- sum(q_m_boot[treated_boot] * boot_data$Y[treated_boot]) / sum(q_m_boot[treated_boot]) -
                           sum(q_m_boot[control_boot] * boot_data$Y[control_boot]) / sum(q_m_boot[control_boot])

            conc_boot[m] <- delta_s_boot * delta_y_boot
          }
        }

        bootstrap_estimates_obs[b] <- min(conc_boot, na.rm = TRUE)
      }

      ci_obs <- quantile(bootstrap_estimates_obs, c(0.025, 0.975), na.rm = TRUE)

      list(
        phi_star = phi_obs,
        ci_lower = as.numeric(ci_obs[1]),
        ci_upper = as.numeric(ci_obs[2])
      )
    }, error = function(e) {
      cat("  ERROR in observation-level for rep", rep, ":", conditionMessage(e), "\n")
      NULL
    })

    if (is.null(est_type) || is.null(est_obs)) {
      return(NULL)
    }

    # Extract values explicitly before tibble creation
    val_est_type <- est_type$phi_star
    val_ci_lower_type <- est_type$ci_lower
    val_ci_upper_type <- est_type$ci_upper
    val_est_obs <- est_obs$phi_star
    val_ci_lower_obs <- est_obs$ci_lower
    val_ci_upper_obs <- est_obs$ci_upper
    val_covered_type <- (true_minimax >= val_ci_lower_type & true_minimax <= val_ci_upper_type)
    val_covered_obs <- (true_minimax >= val_ci_lower_obs & true_minimax <= val_ci_upper_obs)

    tibble(
      rep = rep,
      est_type = val_est_type,
      ci_lower_type = val_ci_lower_type,
      ci_upper_type = val_ci_upper_type,
      est_obs = val_est_obs,
      ci_lower_obs = val_ci_lower_obs,
      ci_upper_obs = val_ci_upper_obs,
      truth = true_minimax,
      covered_type = val_covered_type,
      covered_obs = val_covered_obs
    )
  })

  results <- results %>% filter(!is.na(rep))

  summary <- list(
    coverage_type = mean(results$covered_type, na.rm = TRUE),
    coverage_obs = mean(results$covered_obs, na.rm = TRUE),
    bias_type = mean(results$est_type - results$truth, na.rm = TRUE),
    bias_obs = mean(results$est_obs - results$truth, na.rm = TRUE),
    mean_est_type = mean(results$est_type, na.rm = TRUE),
    mean_est_obs = mean(results$est_obs, na.rm = TRUE),
    mean_truth = mean(results$truth, na.rm = TRUE),
    correlation_type_obs = cor(results$est_type, results$est_obs, use = "complete.obs"),
    n_reps = nrow(results),
    results = results
  )

  cat("\nRESULTS:\n")
  cat("  Type-level (J=16):    coverage =", round(summary$coverage_type, 3),
      "| bias =", round(summary$bias_type, 4),
      "| mean est =", round(summary$mean_est_type, 4), "\n")
  cat("  Observation-level:    coverage =", round(summary$coverage_obs, 3),
      "| bias =", round(summary$bias_obs, 4),
      "| mean est =", round(summary$mean_est_obs, 4), "\n")
  cat("  Truth mean:", round(summary$mean_truth, 4), "\n")
  cat("  Correlation (type vs obs):", round(summary$correlation_type_obs, 3), "\n\n")

  if (summary$coverage_obs > 0.90 && summary$coverage_type < 0.70) {
    cat("*** DIAGNOSIS: J-dimensional approximation IS FUNDAMENTALLY INADEQUATE ***\n")
    cat("    Observation-level works but type-level fails.\n")
    cat("    → FIX: Use observation-level for small n, OR increase J dramatically\n\n")
  } else if (abs(summary$coverage_obs - summary$coverage_type) < 0.10) {
    cat("*** DIAGNOSIS: Both fail similarly; J-dimensional is NOT the bottleneck ***\n")
    cat("    → Issue is elsewhere (formula, CI, etc.)\n\n")
  } else {
    cat("*** DIAGNOSIS: Partial improvement with observation-level ***\n")
    cat("    → J-dimensional contributes to problem but isn't sole cause\n\n")
  }

  summary
}

cat("WARNING: Diagnostic 7 is SLOW (observation-level uses n-dimensional Dirichlet)\n")
cat("Estimating runtime: ~1-2 hours for 30 reps\n")
cat("Skip if time-constrained (diagnostics 1-6 provide most info)\n\n")

# Optionally run Diagnostic 7
RUN_DIAGNOSTIC_7 <- Sys.getenv("RUN_DIAGNOSTIC_7", "TRUE")

if (RUN_DIAGNOSTIC_7 == "TRUE") {
  diag_7 <- run_diagnostic_7()
} else {
  cat("Skipping Diagnostic 7 (set RUN_DIAGNOSTIC_7=TRUE to enable)\n\n")
  diag_7 <- list(
    skipped = TRUE,
    message = "Set RUN_DIAGNOSTIC_7=TRUE to run this diagnostic"
  )
}

# ============================================
# SAVE ALL RESULTS
# ============================================

cat("========================================\n")
cat("Saving all diagnostic results...\n")
cat("========================================\n\n")

all_diagnostics <- list(
  settings = WORST_SETTING,
  n_reps = N_REPS,
  d1_true_types = diag_1,
  d2_schemes = diag_2,
  d3_increasing_J = diag_3,
  d4_closed_form_vs_sampling = diag_4,
  d5_tv_vs_wasserstein = diag_5,
  d6_ci_construction = diag_6,
  d7_obs_vs_type = diag_7,
  timestamp = Sys.time()
)

saveRDS(all_diagnostics, here("sims/results/coverage_diagnostics.rds"))

cat("Results saved to: sims/results/coverage_diagnostics.rds\n\n")

# ============================================
# SUMMARY TABLE
# ============================================

cat("========================================\n")
cat("SUMMARY TABLE\n")
cat("========================================\n\n")

summary_table <- tribble(
  ~Diagnostic, ~Key_Result, ~Coverage, ~Mean_Estimate, ~Interpretation,

  "1. Discretized types", "Current approach",
  diag_1$coverage_disc, diag_1$mean_est_disc,
  if(diag_1$coverage_disc < 0.70) "FAILS" else "OK",

  "1. True types", "No discretization",
  diag_1$coverage_true, diag_1$mean_est_true,
  if(diag_1$coverage_true > 0.90) "FIXES" else "FAILS",

  "2. RF only", "Single scheme",
  diag_2$coverage_rf, diag_2$mean_est_rf,
  if(diag_2$coverage_rf > 0.90) "FIXES" else "FAILS",

  "2. Quantiles only", "Single scheme",
  diag_2$coverage_quantiles, diag_2$mean_est_quantiles,
  if(diag_2$coverage_quantiles > 0.90) "FIXES" else "FAILS",

  "2. Ensemble", "Min across schemes",
  diag_2$coverage_ensemble, diag_2$mean_est_ensemble,
  if(diag_2$coverage_ensemble < 0.70) "FAILS" else "OK",

  "4. Closed-form", "Current implementation",
  NA_real_, diag_4$mean_closed,
  if(abs(diag_4$bias_closed) < 0.01) "UNBIASED" else "BIASED",

  "4. Sampling", "Brute force check",
  NA_real_, diag_4$mean_sampling,
  if(abs(diag_4$bias_sampling) < 0.01) "UNBIASED" else "BIASED",

  "7. Type-level (J=16)", "Current approach",
  if(!is.null(diag_7$coverage_type)) diag_7$coverage_type else NA_real_,
  if(!is.null(diag_7$mean_est_type)) diag_7$mean_est_type else NA_real_,
  if(!is.null(diag_7$skipped) && diag_7$skipped) "SKIPPED" else "BASELINE",

  "7. Observation-level", "No discretization (slow)",
  if(!is.null(diag_7$coverage_obs)) diag_7$coverage_obs else NA_real_,
  if(!is.null(diag_7$mean_est_obs)) diag_7$mean_est_obs else NA_real_,
  if(!is.null(diag_7$coverage_obs) && diag_7$coverage_obs > 0.90) "✓ FIXES" else if(!is.null(diag_7$skipped) && diag_7$skipped) "SKIPPED" else "✗ FAILS"
)

print(summary_table, n = Inf)

cat("\n========================================\n")
cat("DIAGNOSTIC COMPLETE\n")
cat("========================================\n\n")

cat("Next steps:\n")
cat("1. Review diagnostic results above\n")
cat("2. Identify which diagnostic(s) show improvement\n")
cat("3. Implement targeted fix based on evidence\n")
cat("4. Run validation subset (4,800 reps)\n")
cat("5. Full re-run of Studies 1 and 2\n\n")
