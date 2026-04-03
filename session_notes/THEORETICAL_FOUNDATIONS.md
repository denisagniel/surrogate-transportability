# Theoretical Foundations: What Should We Estimate?

## From the Methods Paper

### The Estimand

The paper defines:
- **Space Ω**: Outcome space Ω = X × {0,1} × S × Y (covariates, treatment, surrogate, outcome)
- **Innovation distribution μ**: A probability distribution over M₁(Ω) (space of all probability measures on Ω)
- **Future study Q**: Q = (1-λ)P₀ + λP̃ where P̃ ~ μ
- **Estimand**: φ(F_λ) = E_μ[φ(Q)]

### Key Assumption (Finite Support)

From methods/main.tex line 213:

> "Assumption (Finite support): The outcome space Ω has finite support. Equivalently, the observed data naturally partitions into a finite number of cells (e.g., based on observed covariate values, treatment, surrogate, and outcome levels)."

Under finite support:
- M₁(Ω) is a (k-1)-simplex where k = |Ω|
- Natural choice: μ = Dirichlet(1,...,1) over k dimensions
- This is "uniform on the simplex, treating all probability vectors equally"

### The Critical Question: What is k?

The paper says: "the observed data naturally partitions into a finite number of cells"

**But HOW to partition?** The paper deliberately leaves this open!

## Three Interpretations

### 1. Observation-Level (Current Package)

**Partition**: Each of n observations is its own cell
- k = n
- μ = Dirichlet(1,...,1) over n dimensions
- P̃ is a draw from the n-dimensional simplex

**Interpretation**: Future studies can reweight any individual observation

**Issues**:
- When true heterogeneity is at type-level (k << n), this is too fine-grained
- For K=4 with n=1000, we have 250 observations per type
- Dirichlet(1,...,1) over 1000 dims keeps proportions near 1/1000 for each obs
- Type proportions stay constrained near baseline → underestimates variation

### 2. Type-Level (Ground Truth in Validations)

**Partition**: Cells are latent types/subgroups
- k = K (number of types)
- μ = Dirichlet(1,...,1) over K dimensions
- P̃ specifies weights on types

**Interpretation**: Future studies differ in TYPE COMPOSITION

**Advantages**:
- Matches transportability intuition (populations vary in who they enroll)
- Treatment effects vary by type
- Captures the right level of heterogeneity

**Issues**:
- Types often not observed!
- User must specify type variable

### 3. Covariate-Level (Our Empirical Solution)

**Partition**: Cells are covariate bins
- k = J (number of bins from discretizing X)
- μ = Dirichlet(1,...,1) over J dimensions
- P̃ specifies weights on covariate bins

**Interpretation**: Future studies differ in COVARIATE DISTRIBUTION

**Advantages**:
- Uses observable covariates (no need to know K)
- Intermediate between obs-level and type-level
- Natural when types are defined by covariates

**Issues**:
- Requires J ≈ K to capture type-level heterogeneity
- When K >> J, loses information (K=100 failure)
- Choice of binning affects results

## What Does Asymptotic Theory Say?

From the paper's setup:

### Standard Regime (Fixed k)

If k is fixed:
- √n(φ̂_n - φ(F_λ)) → N(0, σ²)
- Variance comes from estimating P₀
- This is what the paper proves (Proposition 1)

**Applies to**:
- Type-level with fixed K
- Covariate-level with fixed J
- NOT observation-level (k = n → ∞)

### Growing Support (k → ∞)

The paper notes (Remark, line 213):

> "The asymptotic theory extends to growing support k=k_n under additional rate conditions, but we do not pursue that here."

For k → ∞:
- Need k = o(n) for consistency
- Variance includes discretization error
- Requires more sophisticated theory

**Would apply to**:
- Observation-level (k = n): VIOLATES k = o(n)!
- Fine covariate binning (k ~ n^(1/3)): Could work

## Theoretical Diagnosis of Our Problem

### Why K=4 Works with Covariate-Level

- True structure: K = 4 types
- Covariate binning: J ~ 9 bins
- J > K: Adequate resolution
- Dirichlet over J=9 creates enough variation in type proportions
- ✓ Method estimates correct target

### Why K=100 Fails with Covariate-Level

- True structure: K = 100 types
- Covariate binning: J ~ 25 bins (with 2 covariates)
- J << K: Insufficient resolution
- Each bin contains ~4 types
- Dirichlet over J=25 doesn't capture fine-grained type heterogeneity
- ✗ Method estimates WRONG target (average over coarse bins, not true types)

**Moreover**: Even type-level only achieves 64% at K=100 (not 100%)
- This suggests weak correlation (ρ=0.67) + small sample per type (10 obs/type)
- Bootstrap noise dominates
- Fundamental limitation, not implementation issue

## What Should We Implement?

### Theoretical Guideline

The "correct" approach depends on the TRUE data-generating mechanism:

**If data is naturally partitioned into K types:**
- Innovation distribution should be over TYPE proportions
- k = K is the right dimensionality
- Use type-level innovations

**If types are not observed:**
- Approximate with covariate bins
- Choose J to match estimated K (or use criterion like BIC)
- k = J with J ≈ K̂

**If no clear type structure:**
- Intermediate binning based on covariates
- Bias-variance trade-off: finer J → more flexibility but more noise

### Practical Recommendation

Implement a **hierarchy**:

```r
if (type_variable_provided) {
  # Use type-level innovations
  K <- length(unique(data$type))
  innovations <- rdirichlet(M, rep(alpha, K))

} else if (covariates_provided) {
  # Use covariate-level innovations
  # Choose J adaptively (e.g., J ~ min(K̂, n/10, 50))
  covariate_bins <- discretize(X, n_bins = choose_bins(n, X))
  J <- length(unique(covariate_bins))
  innovations <- rdirichlet(M, rep(alpha, J))

} else {
  # Fallback: Observation-level (conservative)
  # Note: This underestimates variation for small K
  innovations <- rdirichlet(M, rep(alpha, n))
}
```

### Addressing Variance Calibration

Given our empirical findings:

**For K ≤ 20**: Covariate-level works well
- Correlation: 95-100% recovery
- Variance: 140-180% recovery (too high)
- Use exponent calibration: alpha = 1/inflation^k for k ~ 1.2-1.5

**For K ≥ 50**: Both approaches struggle
- Weak correlation + small n/K → bootstrap noise
- May need parametric approach or accept limitations
- Document as known limitation

## Convergence Question

**What should converge to what?**

### If using Type-Level (k = K fixed)

As n → ∞:
- φ̂_n(λ) → φ(F_λ) where F_λ has innovations over K types
- √n(φ̂_n - φ(F_λ)) → N(0, σ²)
- Variance σ² from influence function (paper's Proposition 1)

**This is the target we WANT to match**

### If using Covariate-Level (k = J fixed)

As n → ∞:
- φ̂_n(λ) → φ(F_λ^J) where F_λ^J has innovations over J bins
- If J ≥ K and bins align with types: φ(F_λ^J) ≈ φ(F_λ)
- If J << K: φ(F_λ^J) ≠ φ(F_λ) (WRONG TARGET!)

**This is what we're actually estimating**

### If using Observation-Level (k = n → ∞)

Requires k = o(n) for standard theory:
- k = n VIOLATES this
- Could work if treated as k_n = n with special theory
- But empirically: constrains variation for small K

## Bottom Line

**From theory**: The "right" μ is over the partition that captures relevant heterogeneity
- If heterogeneity is at type-level (K types), use k = K
- If types not observed, approximate with covariate bins k = J ≈ K
- Observation-level (k = n) is too fine for small K

**Our empirical findings confirm this**:
- K=4: J~9 works, n=1000 doesn't
- K=100: J~25 fails because J << K

**Solution**: Allow type-level innovations when types known, covariate-level otherwise, with adaptive J selection.

## Questions for Further Investigation

1. **Adaptive binning**: How to choose J from data? (BIC, cross-validation, information criteria)

2. **Growing k theory**: Does k ~ n^(1/3) with appropriate rates give correct asymptotics?

3. **Variance calibration**: Should we calibrate based on ESTIMATED K̂ rather than observed J?

4. **Weak correlation regime**: Is K=100 failure fundamental (weak signal + small groups) or fixable?

5. **Parametric alternative**: For large K, would model-based (regression) approach work better?
