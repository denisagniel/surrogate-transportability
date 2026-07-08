#' Standard Package Wrappers for Traditional Surrogate Methods
#'
#' Provides wrappers for established CRAN packages (Rsurrogate, mediation, pseval)
#' to enable credible comparative evaluation. These wrappers convert our data format
#' to each package's expected format and extract key metrics.
#'
#' @section Rationale:
#' Using standard packages rather than custom implementations provides:
#' - Greater credibility for comparative studies
#' - Validation against established methods
#' - Alignment with practitioner workflows
#'
#' @section Packages:
#' - **Rsurrogate**: PTE and Prentice criteria (Alonso et al.)
#' - **mediation**: Causal mediation analysis (Tingley et al.)
#' - **pseval**: Principal stratification for time-to-event outcomes
#'
#' @name traditional_methods_standard
NULL


#' Compute PTE using Rsurrogate package
#'
#' Wrapper for Rsurrogate package to compute proportion of treatment effect (PTE).
#' Converts data to Rsurrogate format and extracts PTE estimate.
#'
#' @param data Tibble with columns A (treatment), S (surrogate), Y (outcome).
#'   Treatment A must be binary (0/1).
#' @param method Character. Rsurrogate method to use. Default: "freedman"
#'   for Freedman's formula. Other options depend on Rsurrogate API.
#'
#' @return List with elements:
#'   \item{pte}{PTE estimate}
#'   \item{se}{Standard error (if available)}
#'   \item{ci_lower}{Lower confidence bound (if available)}
#'   \item{ci_upper}{Upper confidence bound (if available)}
#'   \item{interpretation}{Whether PTE > 0.6 (common threshold)}
#'
#' @details
#' PTE measures proportion of treatment effect mediated through surrogate:
#'   PTE = (Indirect effect) / (Total effect)
#'
#' **Common interpretation:**
#' - PTE > 0.6: Good surrogate (captures >60% of effect)
#' - PTE 0.3-0.6: Moderate surrogate
#' - PTE < 0.3: Poor surrogate
#'
#' **Assumptions:**
#' - Treatment randomly assigned
#' - Surrogate measured post-treatment
#' - No unmeasured confounding for S→Y
#'
#' @section Package dependency:
#' Requires \code{Rsurrogate} package. Install with:
#' \code{install.packages("Rsurrogate")}
#'
#' @examples
#' \dontrun{
#' data <- generate_study_data(n = 500)
#' result_standard <- compute_pte_standard(data)
#' result_native <- compute_pte(data)
#' # Should agree closely
#' }
#'
#' @export
compute_pte_standard <- function(data, method = "freedman") {

  # Check package availability
  if (!requireNamespace("Rsurrogate", quietly = TRUE)) {
    stop(
      "Package 'Rsurrogate' required but not installed.\n",
      "Install with: install.packages('Rsurrogate')"
    )
  }

  # Validate input
  if (!all(c("A", "S", "Y") %in% names(data))) {
    stop("data must contain columns A, S, and Y")
  }

  if (!all(data$A %in% c(0, 1))) {
    stop("Treatment A must be binary (0/1) for Rsurrogate")
  }

  # Convert to format expected by Rsurrogate
  # Rsurrogate typically expects specific data structures
  # This is a placeholder - will need to verify Rsurrogate API

  tryCatch({
    # Separate data by treatment arm (Rsurrogate API requirement)
    # Ensure numeric vectors (not tibble columns)
    sone <- as.numeric(data$S[data$A == 1])   # Surrogate in treated
    szero <- as.numeric(data$S[data$A == 0])  # Surrogate in control
    yone <- as.numeric(data$Y[data$A == 1])   # Outcome in treated
    yzero <- as.numeric(data$Y[data$A == 0])  # Outcome in control

    # Compute R-squared (proportion of treatment effect explained)
    # using Rsurrogate::R.s.estimate
    result <- Rsurrogate::R.s.estimate(
      sone = sone,
      szero = szero,
      yone = yone,
      yzero = yzero,
      var = TRUE,        # Request variance estimate
      conf.int = TRUE,   # Request confidence interval
      type = method      # "freedman", "robust", or "model"
    )

    # Extract results (Rsurrogate returns list with R.s, R.s.var, conf.int)
    pte <- result$R.s
    se <- sqrt(result$R.s.var)

    # Confidence interval (Rsurrogate provides three versions)
    # Try normal CI first, fall back to quantile CI if NaN
    ci_normal <- result$conf.int.normal.R.s
    ci_quantile <- result$conf.int.quantile.R.s

    if (any(is.nan(ci_normal)) || any(is.infinite(ci_normal))) {
      # Use quantile CI as fallback
      ci_lower <- ci_quantile[1]
      ci_upper <- ci_quantile[2]
      ci_method <- "quantile"
    } else {
      # Use normal CI
      ci_lower <- ci_normal[1]
      ci_upper <- ci_normal[2]
      ci_method <- "normal"
    }

    list(
      pte = pte,
      se = se,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      ci_method = ci_method,
      interpretation = pte > 0.6,
      method = method,
      package = "Rsurrogate",
      full_result = result
    )

  }, error = function(e) {
    stop("Rsurrogate computation failed: ", e$message)
  })
}


#' Compute mediation effects using mediation package
#'
#' Wrapper for mediation package to perform causal mediation analysis.
#' Uses the standard Imai/Tingley/Yamamoto approach.
#'
#' @param data Tibble with columns A (treatment), S (mediator/surrogate),
#'   Y (outcome), and optionally covariates.
#' @param covariates Character vector of covariate names to adjust for.
#'   Default: NULL (no adjustment).
#' @param boot Logical. Whether to use bootstrap for inference. Default: TRUE.
#' @param sims Integer. Number of bootstrap/simulation iterations. Default: 1000.
#'
#' @return List with elements:
#'   \item{acme}{Average causal mediation effect (indirect effect)}
#'   \item{ade}{Average direct effect}
#'   \item{total_effect}{Total effect}
#'   \item{prop_mediated}{Proportion mediated (ACME / Total)}
#'   \item{acme_ci}{Confidence interval for ACME}
#'   \item{prop_mediated_ci}{Confidence interval for proportion mediated}
#'   \item{interpretation}{Whether proportion mediated > 0.6}
#'
#' @details
#' Implements the Imai et al. (2010) causal mediation framework:
#' - **ACME**: Average Causal Mediation Effect (indirect through S)
#' - **ADE**: Average Direct Effect (not through S)
#' - **Total = ACME + ADE**
#' - **Proportion mediated = ACME / Total**
#'
#' **Common interpretation:**
#' - Proportion mediated > 0.6: Good surrogate
#' - Proportion mediated 0.3-0.6: Moderate surrogate
#' - Proportion mediated < 0.3: Poor surrogate
#'
#' **Assumptions:**
#' - Sequential ignorability (no unmeasured confounding)
#' - Treatment → Mediator → Outcome causal structure
#' - No treatment-mediator interaction (unless specified)
#'
#' @section Package dependency:
#' Requires \code{mediation} package. Install with:
#' \code{install.packages("mediation")}
#'
#' @references
#' Imai, K., Keele, L., & Tingley, D. (2010). A general approach to causal
#' mediation analysis. Psychological Methods, 15(4), 309-334.
#'
#' @examples
#' \dontrun{
#' data <- generate_study_data(n = 500)
#' result_standard <- compute_mediation_standard(data, sims = 500)
#' result_native <- compute_mediation_effects(data)
#' # Compare proportion mediated
#' }
#'
#' @export
compute_mediation_standard <- function(data,
                                       covariates = NULL,
                                       boot = FALSE,
                                       sims = 1000) {

  # Check package availability
  if (!requireNamespace("mediation", quietly = TRUE)) {
    stop(
      "Package 'mediation' required but not installed.\n",
      "Install with: install.packages('mediation')"
    )
  }

  # Validate input
  if (!all(c("A", "S", "Y") %in% names(data))) {
    stop("data must contain columns A, S, and Y")
  }

  tryCatch({
    # Build formulas
    if (!is.null(covariates)) {
      # Check covariates exist in data
      missing_covariates <- setdiff(covariates, names(data))
      if (length(missing_covariates) > 0) {
        stop("Covariates not found in data: ", paste(missing_covariates, collapse = ", "))
      }

      covariate_str <- paste(covariates, collapse = " + ")
      mediator_fmla <- as.formula(paste("S ~ A +", covariate_str), env = parent.frame())
      outcome_fmla <- as.formula(paste("Y ~ A + S +", covariate_str), env = parent.frame())
    } else {
      mediator_fmla <- as.formula("S ~ A", env = parent.frame())
      outcome_fmla <- as.formula("Y ~ A + S", env = parent.frame())
    }

    # Fit mediator model
    mediator_model <- lm(mediator_fmla, data = data)

    # Fit outcome model
    outcome_model <- lm(outcome_fmla, data = data)

    # Perform mediation analysis
    mediation_result <- mediation::mediate(
      model.m = mediator_model,
      model.y = outcome_model,
      treat = "A",
      mediator = "S",
      boot = boot,
      sims = sims
    )

    # Extract key quantities
    acme <- mediation_result$d0  # Average causal mediation effect (control)
    ade <- mediation_result$z0   # Average direct effect (control)
    total_effect <- mediation_result$tau.coef  # Total effect
    prop_mediated <- mediation_result$n0  # Proportion mediated (control)

    # Confidence intervals
    acme_ci <- mediation_result$d0.ci
    prop_mediated_ci <- mediation_result$n0.ci

    list(
      acme = acme,
      ade = ade,
      total_effect = total_effect,
      prop_mediated = prop_mediated,
      acme_ci = acme_ci,
      prop_mediated_ci = prop_mediated_ci,
      interpretation = prop_mediated > 0.6,
      package = "mediation",
      full_result = mediation_result
    )

  }, error = function(e) {
    stop("mediation package computation failed: ", e$message)
  })
}


#' Compute principal stratification analysis using pseval
#'
#' Wrapper for pseval package to evaluate time-to-event surrogates using
#' principal stratification framework.
#'
#' @param data Tibble with time-to-event structure:
#'   - A: treatment (binary 0/1)
#'   - S: surrogate (post-treatment, often binary or continuous)
#'   - Y_time: time to event
#'   - Y_event: event indicator (1 = event occurred, 0 = censored)
#' @param s_model_formula Formula for surrogate model. Default: S ~ A.
#' @param y_model_formula Formula for outcome model. Default depends on Y type.
#'
#' @return List with principal stratification estimates and diagnostics.
#'
#' @details
#' **Principal Stratification:**
#' Defines strata based on potential surrogate values S(0), S(1):
#' - Always: S(0) = 1, S(1) = 1
#' - Never: S(0) = 0, S(1) = 0
#' - Helped: S(0) = 0, S(1) = 1
#' - Harmed: S(0) = 1, S(1) = 0
#'
#' **Key assumptions:**
#' - **Monotonicity**: No "harmed" stratum (treatment never harms surrogate)
#' - **Exclusion restriction**: Treatment affects outcome ONLY through surrogate
#'
#' **When these assumptions fail:**
#' pseval estimates may be biased. This is a key comparison point: does
#' TV ball method work when pseval's assumptions are violated?
#'
#' @section Package dependency:
#' Requires \code{pseval} package. Install with:
#' \code{install.packages("pseval")}
#'
#' @section Time-to-Event Data:
#' This function is specifically for time-to-event outcomes (survival data).
#' For continuous outcomes, use \code{compute_pte_standard} or
#' \code{compute_mediation_standard}.
#'
#' @references
#' Gilbert, P. B., & Hudgens, M. G. (2008). Evaluating candidate principal
#' surrogate endpoints. Biometrics, 64(4), 1146-1154.
#'
#' @examples
#' \dontrun{
#' # Time-to-event data
#' data <- generate_time_to_event_study(n = 500)
#' result <- compute_ps_standard(data)
#' }
#'
#' @export
compute_ps_standard <- function(data,
                                s_model_formula = S ~ A,
                                y_model_formula = NULL) {

  # Check package availability
  if (!requireNamespace("pseval", quietly = TRUE)) {
    stop(
      "Package 'pseval' required but not installed.\n",
      "Install with: install.packages('pseval')"
    )
  }

  # Validate input
  required_cols <- c("A", "S", "Y_time", "Y_event")
  if (!all(required_cols %in% names(data))) {
    stop("data must contain columns: A, S, Y_time, Y_event")
  }

  if (!all(data$A %in% c(0, 1))) {
    stop("Treatment A must be binary (0/1)")
  }

  if (!all(data$Y_event %in% c(0, 1))) {
    stop("Event indicator Y_event must be binary (0/1)")
  }

  tryCatch({
    # pseval implementation (API to be verified after installation)
    # Typically requires survival object and principal stratification setup

    warning(
      "pseval wrapper is a placeholder. ",
      "Needs verification of pseval API after package installation."
    )

    list(
      causal_effect_helped = NA_real_,
      causal_effect_always = NA_real_,
      proportion_helped = NA_real_,
      assumptions_met = NA,
      package = "pseval (placeholder)",
      note = "Wrapper needs pseval API verification"
    )

  }, error = function(e) {
    stop("pseval computation failed: ", e$message)
  })
}


#' Compare native and standard package implementations
#'
#' Validation function to compare our native implementations with standard
#' CRAN packages. Used to verify correctness and understand differences.
#'
#' @param data Tibble with study data (A, S, Y)
#' @param methods Character vector. Which methods to compare: "pte", "mediation".
#'   Default: both.
#' @param tolerance Numeric. Tolerance for agreement. Default: 0.05 (5% relative difference).
#'
#' @return Tibble with comparison results showing:
#'   - method: Which method was compared
#'   - native_estimate: Our implementation
#'   - standard_estimate: Standard package
#'   - difference: Absolute difference
#'   - relative_difference: Relative difference (%)
#'   - agree: Whether estimates agree within tolerance
#'
#' @details
#' This function is for **validation** purposes. It helps ensure our native
#' implementations are correct by comparing to established packages.
#'
#' **Expected agreement:**
#' - PTE: Should agree closely (same formula)
#' - Mediation: Should agree closely (same approach)
#' - Small differences acceptable due to: numerical precision, bootstrap variation
#'
#' **What to do if they disagree:**
#' 1. Check data preparation (format conversion)
#' 2. Check formula specification
#' 3. Investigate which is correct (theory)
#' 4. Document any known differences
#'
#' @examples
#' \dontrun{
#' data <- generate_study_data(n = 500)
#' comparison <- compare_native_vs_standard(data)
#' print(comparison)
#' }
#'
#' @export
compare_native_vs_standard <- function(data,
                                       methods = c("pte", "mediation"),
                                       tolerance = 0.05) {

  results <- list()

  # PTE comparison
  if ("pte" %in% methods) {
    native_pte <- compute_pte(data)
    standard_pte_result <- compute_pte_standard(data)
    standard_pte <- standard_pte_result$pte

    results$pte <- tibble::tibble(
      method = "PTE",
      native_estimate = native_pte,
      standard_estimate = standard_pte,
      difference = abs(native_pte - standard_pte),
      relative_difference = abs(native_pte - standard_pte) / abs(native_pte),
      agree = abs(native_pte - standard_pte) / abs(native_pte) < tolerance
    )
  }

  # Mediation comparison
  if ("mediation" %in% methods) {
    native_mediation <- compute_mediation_effects(data)
    standard_mediation <- compute_mediation_standard(data, sims = 500)

    results$mediation <- tibble::tibble(
      method = "Mediation (proportion)",
      native_estimate = native_mediation$proportion_mediated,
      standard_estimate = standard_mediation$prop_mediated,
      difference = abs(native_mediation$proportion_mediated - standard_mediation$prop_mediated),
      relative_difference = abs(native_mediation$proportion_mediated - standard_mediation$prop_mediated) /
                           abs(native_mediation$proportion_mediated),
      agree = abs(native_mediation$proportion_mediated - standard_mediation$prop_mediated) /
             abs(native_mediation$proportion_mediated) < tolerance
    )
  }

  # Combine results
  dplyr::bind_rows(results)
}


#' Validate method availability
#'
#' Check which standard packages are installed and available for use.
#'
#' @return Named logical vector indicating which packages are available:
#'   \item{Rsurrogate}{Available for PTE}
#'   \item{mediation}{Available for mediation analysis}
#'   \item{pseval}{Available for principal stratification}
#'
#' @details
#' Use this function to check which comparative methods are available before
#' running large simulation studies. Simulations can adapt to use available
#' packages.
#'
#' @examples
#' availability <- validate_method_availability()
#' if (availability["mediation"]) {
#'   # Run mediation comparisons
#' }
#'
#' @export
validate_method_availability <- function() {
  c(
    Rsurrogate = requireNamespace("Rsurrogate", quietly = TRUE),
    mediation = requireNamespace("mediation", quietly = TRUE),
    pseval = requireNamespace("pseval", quietly = TRUE)
  )
}
