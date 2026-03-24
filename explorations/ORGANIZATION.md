# Explorations Directory Organization

**Purpose:** Research sandbox for experimental work, diagnostic scripts, and archived validation studies.

---

## Directory Structure

### `validation-archive/`

**Key validation scripts that proved the type-level approach:**

- **`validate_rf_ensemble_theory.R`** - Empirical validation showing <2% approximation error
  - Tests linear, step function, and smooth nonlinear treatment effects
  - Validates convergence as n → ∞
  - Proves ensemble outperforms single schemes

- **`multi_discretization_minimax.R`** - Tests ensemble across multiple discretization schemes
  - Compares RF, quantiles, k-means
  - Shows ensemble minimum approximates TV-ball minimax

**Status:** These scripts validated the approach. Results incorporated into package.

---

### `diagnostics/`

**Diagnostic and test scripts from development:**

Organized by purpose:

#### Validation Tests
- `diagnose_correlation_issue.R` - Identified reweighting problem
- `diagnose_approximation_error.R` - Analyzed discretization error
- `diagnose_k100_failure.R` - Debugged K=100 case
- `diagnose_na_issues.R` - Fixed NA handling

#### Method Comparisons
- `compare_reweighting_vs_bootstrap.R` - Compared approaches
- `test_independent_samples_approach.R` - Validated independent sampling
- `test_covariate_vs_independent_samples.R` - Covariate shift analysis

#### DGP Testing
- `test_better_dgp.R` - DGP design exploration
- `test_corrected_dgp.R` - No-mediation DGP validation
- `test_poor_surrogate.R` - Weak surrogate testing
- `test_uncorrelated_surrogate.R` - Bad surrogate testing

#### Bootstrap/Calibration
- `test_bootstrap_fix.R` - Bootstrap implementation
- `test_bootstrap_k_equals_n.R` - K=n bootstrap
- `test_all_calibration_methods.R` - Calibration approaches
- `test_percentile_ci.R` - Percentile CI validation
- `test_sample_splitting_calibration.R` - Sample splitting

#### Innovation/Randomness
- `test_fixed_randomness_k4.R` - Fixed randomness hypothesis
- `test_innovation_mismatch.R` - Identified obs-level vs type-level issue
- `test_covariate_innovations.R` - Covariate-based innovations
- `test_sensitivity_to_k.R` - Sensitivity to discretization level

#### Functional Testing
- `test_npv_functional.R` - NPV functional implementation
- `test_ppv_npv_validation.R` - PPV/NPV validation
- `test_correlation_range.R` - Correlation functional range

#### Other
- `analyze_calibration_results.R` - Results analysis
- `check_true_minimax.R` - Ground truth verification
- `prototype_reweighting_fixes.R` - Early prototype
- `quick_test_under_model_corrected.R` - Quick validation
- `run_all_simulations.R` - Batch runner

**Status:** Historical development scripts. Not needed for production use.

---

### PNG Files

Diagnostic plots from development (moved to `diagnostics/`):
- `approximation_error_by_correlation.png`
- `convergence_ensemble_to_minimax.png`
- `correlation_recovery_comparison.png`
- `k100_*.png` - K=100 diagnostics
- `minimax_by_correlation_comparison.png`
- `multi_discretization_*.png`
- `variance_*.png`

---

## Usage Guidelines

**Do:**
- Use this directory for experimental work
- Archive working validation scripts here
- Document findings in session notes

**Don't:**
- Put production code here (belongs in `package/` or `sims/`)
- Leave undocumented scripts
- Mix exploration with validated methods

---

## Related Directories

- **`sims/scripts/`** - Formal validation suite for paper claims
- **`package/tests/`** - Unit and integration tests
- **`session_notes/`** - Documentation of findings
