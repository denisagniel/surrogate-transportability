#' Functional Paradigms in Surrogate Transportability
#'
#' @name functional-paradigms
#' @description
#' This package supports two distinct paradigms for evaluating surrogate
#' quality under transportability uncertainty. Understanding which paradigm
#' to use is essential for correct interpretation of results.
#'
#' @section Across-Study Functionals (Primary Framework):
#'
#' **Scientific Question:** "Will studies with large surrogate effects also
#' have large outcome effects?"
#'
#' **Setup:**
#' \enumerate{
#'   \item Generate M future studies Q₁, Q₂, ..., Q_M from F_λ
#'   \item Each Q_m yields **one treatment effect pair**:
#'     \itemize{
#'       \item Δ_S(Q_m) = E_Qm[S(1) - S(0)] (scalar)
#'       \item Δ_Y(Q_m) = E_Qm[Y(1) - Y(0)] (scalar)
#'     }
#'   \item Compute functional **across** the M pairs
#' }
#'
#' **Example - Correlation:**
#' \deqn{\phi(F_\lambda) = \text{Cor}(\{\Delta_S(Q_1), \ldots, \Delta_S(Q_M)\},
#'                                     \{\Delta_Y(Q_1), \ldots, \Delta_Y(Q_M)\})}
#'
#' **Interpretation:** Measures how correlated treatment effects are **between**
#' different future studies. High correlation means: if I observe a large
#' surrogate effect in one study, the outcome effect in **that study** is also
#' likely to be large.
#'
#' **Use cases:**
#' \itemize{
#'   \item Study-to-study transportability assessment
#'   \item Planning multi-site trials or meta-analyses
#'   \item External validity across populations or settings
#'   \item Regulatory decisions based on surrogate endpoints
#' }
#'
#' **Functions:**
#' \itemize{
#'   \item \code{\link{functional_correlation}} - Correlation across studies
#'   \item \code{\link{functional_ppv}} - Positive predictive value across studies
#'   \item \code{\link{functional_npv}} - Negative predictive value across studies
#'   \item \code{\link{functional_concordance}} - Expected product across studies
#'   \item \code{\link{functional_probability}} - Joint probability across studies
#'   \item \code{\link{surrogate_inference_minimax}} - Minimax inference framework
#' }
#'
#' **This is the primary framework discussed in the methods paper.**
#'
#' @section Within-Study Functionals (Alternative Framework):
#'
#' **Scientific Question:** "Within a single future study, do individuals with
#' large outcome treatment effects also have large surrogate treatment effects?"
#'
#' **Setup:**
#' \enumerate{
#'   \item Generate M future studies Q₁, Q₂, ..., Q_M from F_λ
#'   \item For **each** Q_m individually:
#'     \itemize{
#'       \item Estimate individual-level treatment effects τ_S(Xi), τ_Y(Xi)
#'       \item Compute within-study functional φ(Q_m)
#'     }
#'   \item Aggregate across M values (e.g., min, mean)
#' }
#'
#' **Example - CATE Covariance:**
#' \deqn{\phi(Q_m) = \text{Cov}_{Q_m}(\tau_S(X), \tau_Y(X))}
#' \deqn{\phi_{\text{worst}} = \min_{m} \phi(Q_m)}
#'
#' **Interpretation:** Measures treatment effect heterogeneity **within** a
#' single study. High covariance means: patients with large τ_Y(X) also tend
#' to have large τ_S(X) in that study.
#'
#' **Use cases:**
#' \itemize{
#'   \item Personalized treatment decisions based on surrogate
#'   \item Subgroup analysis and treatment effect heterogeneity
#'   \item Understanding individual-level surrogate-outcome relationship
#'   \item Precision medicine applications
#' }
#'
#' **Functions:**
#' \itemize{
#'   \item \code{\link{functional_cate_covariance}} - Covariance of CATEs
#'   \item (Additional within-study functionals to be implemented)
#' }
#'
#' **This framework is complementary and addresses different questions.**
#'
#' @section Key Differences:
#'
#' | Aspect | Across-Study | Within-Study |
#' |--------|--------------|--------------|
#' | **Question** | Study-to-study transportability | Individual heterogeneity |
#' | **Input per Q** | One scalar pair (Δ_S, Δ_Y) | Individual data (Xi, τ(Xi)) |
#' | **Aggregation** | Across M studies | Within each study, then across |
#' | **Estimand** | φ(F_λ) = f({Δ(Q₁),...,Δ(Q_M)}) | φ_min = min_m φ(Q_m) |
#' | **Example** | Cor({Δ_S(Qi)}, {Δ_Y(Qi)}) | min_m Cov_Qm(τ_S(X), τ_Y(X)) |
#' | **Paper focus** | Primary | Complementary |
#'
#' @section When to Use Which:
#'
#' **Use across-study functionals if:**
#' \itemize{
#'   \item Primary interest is transportability to new populations/settings
#'   \item Planning to use surrogate in future trials or meta-analyses
#'   \item Want to know if surrogate predicts outcomes **study-to-study**
#'   \item Following the main methods paper framework
#' }
#'
#' **Use within-study functionals if:**
#' \itemize{
#'   \item Interest in individual-level treatment effect heterogeneity
#'   \item Planning personalized treatment decisions within a study
#'   \item Want to know if surrogate predicts outcomes **person-to-person**
#'   \item Conducting subgroup analysis or precision medicine
#' }
#'
#' **Both can be used together** for comprehensive assessment:
#' \itemize{
#'   \item Across-study: Does surrogate work in new settings?
#'   \item Within-study: Does surrogate work for patient selection?
#' }
#'
#' @section Relationship Between Paradigms:
#'
#' Both paradigms:
#' \itemize{
#'   \item Use the same innovation approach (F_λ framework)
#'   \item Generate future studies via Q = (1-λ)P₀ + λP̃
#'   \item Assess robustness over TV ball of radius λ
#' }
#'
#' Key difference is **what we compute** for each Q:
#' \itemize{
#'   \item Across-study: One summary statistic (Δ_S, Δ_Y)
#'   \item Within-study: Full individual-level analysis with covariates
#' }
#'
#' The paradigms are **not directly comparable**:
#' \itemize{
#'   \item Across-study correlation of 0.8 ≠ within-study correlation of 0.8
#'   \item Different denominators (study variance vs. individual variance)
#'   \item Different scientific interpretations
#' }
#'
#' @section Implementation Notes:
#'
#' **Across-study functionals:**
#' \itemize{
#'   \item Input: Data frame with columns \code{delta_s}, \code{delta_y}
#'   \item Each row = one future study
#'   \item Fast (simple statistics on M scalars)
#'   \item Example: \code{functional_correlation(treatment_effects)}
#' }
#'
#' **Within-study functionals:**
#' \itemize{
#'   \item Input: Data frame with columns \code{A}, \code{S}, \code{Y}, covariates
#'   \item Full study data for each Q
#'   \item Slower (nuisance estimation required)
#'   \item Example: \code{functional_cate_covariance(data, covariates)}
#' }
#'
#' **Error prevention:** Functions will detect and warn if you pass the wrong
#' input type (e.g., raw data to across-study function).
#'
#' @examples
#' \dontrun{
#' # ============================================
#' # ACROSS-STUDY PARADIGM
#' # ============================================
#'
#' # Generate current study data
#' current_data <- generate_study_data(n = 500, seed = 123)
#'
#' # Generate M future studies
#' future_studies <- generate_multiple_future_studies(
#'   current_data,
#'   n_future_studies = 100,
#'   lambda = 0.3
#' )
#'
#' # Extract treatment effect PAIRS (one per study)
#' treatment_effects <- extract_treatment_effects(future_studies)
#' # Result: data frame with 100 rows, columns: delta_s, delta_y
#'
#' # Compute correlation ACROSS the 100 studies
#' cor_across <- functional_correlation(treatment_effects)
#' # Interpretation: "Studies with large Δ_S tend to have large Δ_Y"
#'
#' # Compute PPV ACROSS studies
#' ppv_across <- functional_ppv(treatment_effects,
#'                               epsilon_s = 0.2,
#'                               epsilon_y = 0.1)
#' # Interpretation: "If Δ_S > 0.2 in a study, prob that Δ_Y > 0.1 in that study"
#'
#'
#' # ============================================
#' # WITHIN-STUDY PARADIGM
#' # ============================================
#'
#' # Use the SAME innovation approach, but analyze differently
#'
#' # Option 1: Analyze one future study
#' one_future_study <- generate_future_study(current_data, lambda = 0.3)
#'
#' # Compute CATE covariance WITHIN this single study
#' cov_within <- functional_cate_covariance(
#'   data = one_future_study$future_data,
#'   covariates = c("X1", "X2")
#' )
#' # Interpretation: "Within this study, individuals with large τ_Y(X)
#' #                  tend to have large τ_S(X)"
#'
#' # Option 2: Worst-case over multiple future studies (minimax)
#' # Generate M studies
#' M <- 100
#' cate_covs <- numeric(M)
#' for (m in 1:M) {
#'   future_m <- generate_future_study(current_data, lambda = 0.3)
#'   result_m <- functional_cate_covariance(
#'     data = future_m$future_data,
#'     covariates = c("X1", "X2")
#'   )
#'   cate_covs[m] <- result_m$phi
#' }
#'
#' # Worst-case within-study covariance
#' cov_worst <- min(cate_covs)
#' # Interpretation: "Even in the worst future study (within λ=0.3 of P₀),
#' #                  the within-study CATE covariance is at least X"
#'
#'
#' # ============================================
#' # COMPARISON
#' # ============================================
#'
#' cat("Across-study correlation:", cor_across, "\n")
#' cat("Worst-case within-study covariance:", cov_worst, "\n")
#' # These are NOT directly comparable (different questions!)
#' }
#'
#' @seealso
#' **Across-study functions:**
#' \code{\link{functional_correlation}},
#' \code{\link{functional_ppv}},
#' \code{\link{functional_concordance}},
#' \code{\link{surrogate_inference_minimax}}
#'
#' **Within-study functions:**
#' \code{\link{functional_cate_covariance}}
#'
#' **Data generation:**
#' \code{\link{generate_future_study}},
#' \code{\link{generate_multiple_future_studies}}
#'
#' @references
#' See the methods paper for detailed discussion of the across-study functional
#' framework and its theoretical properties.
NULL
