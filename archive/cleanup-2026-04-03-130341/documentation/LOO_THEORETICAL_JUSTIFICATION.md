# Theoretical Justification for Leave-One-Out in Dual Estimation

## The Core Issue

### Population Estimand

The Wasserstein dual at a point x is defined as:
```
φ(x) = -τ log E_{X'~P}[exp(-(h(X') + γC(x,X'))/τ)]
```

where:
- X' ~ P is an **independent** draw from the covariate distribution
- x is a fixed reference point
- The expectation is over X' ≠ x (independent samples)

Our target parameter is:
```
Ψ = E_{X~P}[φ(X)]
```

### Empirical Approximation (Current)

We approximate E_{X'~P} using the empirical distribution:
```
φ̂(X_j) = -τ log[(1/n) Σ_{i=1}^n exp(-(h(X_i) + γC(X_j,X_i))/τ)]
                              ↑ includes i=j
```

**Problem:** When i=j, we have:
- C(X_j, X_j) = 0 (distance to self)
- This term becomes exp(-h(X_j)/τ)
- **This is NOT a draw from the population** - it's using X_j to estimate its own expectation

### The Independence Violation

In the population:
- φ(x) involves E_{X'~P}[·] where **X' is independent of x**
- X' and x are separate random draws

In our empirical estimate:
- When j=i, we're using X_j to compute its own expectation
- This violates independence and creates **self-influence bias**

---

## Theoretical Justification for LOO

### 1. Cross-Validation Principle

**Standard result:** When estimating E[Y|X=x] using data {(X_i,Y_i)}, we should NOT use observation (X_j,Y_j) to predict at X=X_j.

**Applied here:** When estimating E_{X'~P}[g(x,X')] at x=X_j, we should not include X_i=X_j in the empirical average.

**LOO approach:**
```
φ̂_{(-j)}(X_j) = -τ log[(1/(n-1)) Σ_{i≠j} exp(-(h(X_i) + γC(X_j,X_i))/τ)]
                                    ↑ excludes i=j
```

This is the **cross-validated** estimate of the expectation.

---

### 2. U-Statistic Analogy

Our estimator has the structure:
```
Ψ̂ = (1/n) Σ_{j=1}^n φ̂(X_j)
where φ̂(X_j) involves Σ_{i=1}^n g(X_i, X_j)
```

This is similar to a **U-statistic**:
```
U = (1/n(n-1)) Σ_{i≠j} h(X_i, X_j)
```

**Key property of U-statistics:** Exclude diagonal terms (i=j) to obtain unbiased estimation.

**Theorem (Hoeffding 1948):** For a symmetric kernel h(·,·), the U-statistic excluding diagonal terms is an unbiased estimator of E[h(X,X')] where X,X' are i.i.d.

**Applied here:** Our dual involves pairs (X_i, X_j). Following U-statistic theory, we should exclude i=j.

---

### 3. Jackknife Bias Reduction

The LOO approach is a **jackknife estimator**:
```
φ̂_{(-j)}(X_j) = estimate of φ(X_j) using data with observation j removed
```

**Jackknife principle (Quenouille 1956, Tukey 1958):** Leave-one-out estimation reduces bias in non-linear functionals.

**General result:** For an estimator θ̂ with bias of order O(1/n), the jackknife estimator has bias of order O(1/n²).

**Applied here:**
- Standard estimator φ̂(X_j) has bias from self-influence
- Jackknife estimator φ̂_{(-j)}(X_j) eliminates first-order bias

---

### 4. Formal Bias Decomposition

Let's decompose the bias explicitly.

**True value:**
```
φ(X_j) = -τ log E_{X'~P}[exp(-(h(X') + γC(X_j,X'))/τ)]
```

**Empirical approximation:**
```
φ̂(X_j) = -τ log[(1/n) Σ_{i=1}^n exp(-(h(X_i) + γC(X_j,X_i))/τ)]
        = -τ log[(1/n)[exp(-h(X_j)/τ) + Σ_{i≠j} exp(-(h(X_i) + γC(X_j,X_i))/τ)]]
```

The i=j term contributes:
```
exp(-h(X_j)/τ)  [with C(X_j,X_j) = 0]
```

This is typically **larger** than other terms (because cost=0), so:
```
(1/n) Σ_{i=1}^n [...] > (1/(n-1)) Σ_{i≠j} [...]
```

Since φ = -τ log(·), and log is increasing:
```
φ̂(X_j) = -τ log(larger value) < -τ log(correct value)
```

**Result: Systematic negative bias** (exactly what we observed: -2% to -3%).

**LOO correction:** Excluding i=j removes the artificially large term, eliminating the bias.

---

### 5. Connection to Kernel Density Estimation

Similar issues arise in kernel density estimation. When estimating f(x) at an observed point X_j:

**Biased (includes j):**
```
f̂(X_j) = (1/n) Σ_{i=1}^n K((X_i - X_j)/h)
```
This includes K(0) which is typically large (the "spike" at the data point).

**Unbiased (LOO):**
```
f̂_{(-j)}(X_j) = (1/(n-1)) Σ_{i≠j} K((X_i - X_j)/h)
```

**Standard practice:** Use LOO for bandwidth selection and cross-validation in kernel methods.

---

## Mathematical Formalization

### Setup

Let X₁,...,Xₙ be i.i.d. from P. Define:
```
g(x,X') = exp(-(h(X') + γC(x,X'))/τ)
φ(x) = -τ log E_{X'~P}[g(x,X')]
Ψ = E_{X~P}[φ(X)]
```

### Empirical Estimator

```
φ̂(X_j) = -τ log[(1/n) Σ_{i=1}^n g(X_j, X_i)]
Ψ̂ = (1/n) Σ_{j=1}^n φ̂(X_j)
```

### Bias Analysis

**Lemma:** E[φ̂(X_j) | X_j = x] ≠ φ(x) due to including i=j term.

**Proof sketch:**
- E[(1/n) Σ_{i=1}^n g(x,X_i) | X_j = x]
- = (1/n)g(x,x) + (1/n)Σ_{i≠j} E[g(x,X_i)]
- = (1/n)exp(-h(x)/τ) + ((n-1)/n)E[g(x,X')]
- ≠ E[g(x,X')]

The first term (1/n)exp(-h(x)/τ) creates bias.

### LOO Estimator

```
φ̂_{(-j)}(X_j) = -τ log[(1/(n-1)) Σ_{i≠j} g(X_j, X_i)]
Ψ̂_{LOO} = (1/n) Σ_{j=1}^n φ̂_{(-j)}(X_j)
```

**Theorem:** E[φ̂_{(-j)}(X_j) | X_j = x] → φ(x) as n→∞

**Proof:**
- E[(1/(n-1)) Σ_{i≠j} g(x,X_i) | X_j = x]
- = E[g(x,X')] by i.i.d. and excluding j
- Therefore E[φ̂_{(-j)}(x)] = φ(x) + O(1/n) (from Jensen's inequality)

The LOO estimator has **asymptotically negligible bias**.

---

## Empirical Validation

Our tests show:

| Method | d=4, n=500 | d=5, n=500 |
|--------|------------|------------|
| Empirical | -2.06% bias | -2.79% bias |
| **LOO** | **+0.05% bias** | **+0.19% bias** |

The 45x and 14x bias reductions validate the theoretical prediction.

---

## Related Literature

1. **Hoeffding (1948):** "A class of statistics with asymptotically normal distribution"
   - U-statistics theory, excluding diagonal terms

2. **Quenouille (1956) / Tukey (1958):** Jackknife estimation
   - Leave-one-out for bias reduction

3. **Stone (1974):** "Cross-validatory choice and assessment of statistical predictions"
   - Cross-validation theory

4. **Efron & Tibshirani (1993):** "An Introduction to the Bootstrap"
   - Chapter on jackknife and cross-validation

5. **Chernozhukov et al. (2018):** "Double/debiased machine learning"
   - Cross-fitting to avoid overfitting bias (related principle)

---

## Summary

**The theoretical justification for LOO rests on four pillars:**

1. **Independence requirement:** E_{X'~P} should use X' independent of the reference point
2. **U-statistic theory:** Exclude diagonal terms for unbiased estimation of E[h(X,X')]
3. **Jackknife principle:** Leave-one-out reduces bias in non-linear functionals
4. **Cross-validation principle:** Don't test on training data

**All converge to the same conclusion:** When computing φ̂(X_j), exclude observation j from the empirical average.

**This is not an ad-hoc fix** - it's the application of well-established statistical principles (U-statistics, jackknife, cross-validation) to our specific estimation problem.

**The dramatic empirical improvement (45x bias reduction) confirms the theory.**
