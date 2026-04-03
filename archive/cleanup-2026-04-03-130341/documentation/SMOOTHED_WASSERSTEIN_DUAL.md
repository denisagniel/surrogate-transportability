# Smoothed Wasserstein Dual: Complete IF Derivation

**Date:** April 1, 2026
**Status:** Theoretical derivation

---

## The Problem with Hard Minimum

**Standard Wasserstein dual (Esfahani & Kuhn 2018):**
```
φ*(λ_w) = sup_{γ≥0} { -γλ_w² + ∑_{j=1}^J p₀_j min_i{h_i + γC[i,j]} }
```

**Issue:** The `min_i{...}` operation creates **selection bias** when h_i = τ_S^i × τ_Y^i are estimated from data.

Even though this is a "closed-form" solution, it suffers from the same selection problem as taking min over treatment effects directly.

---

## Solution: Smooth Approximation

**Replace hard minimum with smooth minimum:**
```
min_i{x_i} ≈ -τ log(∑_i exp(-x_i/τ))
```

**Smoothed Wasserstein dual:**
```
g_τ(γ) = -γλ_w² + ∑_{j=1}^J p₀_j · φ_τ^j(γ)
```

where:
```
φ_τ^j(γ) = -τ log(∑_{i=1}^J exp(-(h_i + γC[i,j])/τ))
```

**Key properties:**
- As τ → 0: φ_τ^j(γ) → min_i{h_i + γC[i,j]} (recovers exact solution)
- For τ > 0: Smooth and differentiable
- Can derive influence function

**Optimal dual variable:**
```
γ*(τ) = argmax_{γ≥0} g_τ(γ)
```

**Minimax estimate:**
```
φ*(λ_w, τ) = g_τ(γ*(τ))
```

---

## Influence Function Derivation

### Step 1: IF for h_i (Concordances)

For h_i = τ_S^i × τ_Y^i where these are type-level treatment effects:

```
IF_{h_i}(O) = (I_i(X)/π_i) · [τ_S^i · IF_τY(O) + τ_Y^i · IF_τS(O)]
```

where:
- I_i(X) = 1{X ∈ type i}
- π_i = P(X ∈ type i)
- IF_τS(O), IF_τY(O) are efficient IFs for treatment effects

### Step 2: IF for φ_τ^j(γ)

The smooth minimum at type j for fixed γ:
```
φ_τ^j(γ) = -τ log(∑_{i=1}^J exp(-(h_i + γC[i,j])/τ))
```

**Pathwise derivative:**
```
∂φ_τ^j/∂h_i = w_i^j(γ)
```

where:
```
w_i^j(γ) = exp(-(h_i + γC[i,j])/τ) / ∑_k exp(-(h_k + γC[k,j])/τ)
```

**Influence function:**
```
IF_{φ_τ^j}(O; γ) = ∑_{i=1}^J w_i^j(γ) · IF_{h_i}(O)
```

### Step 3: IF for g_τ(γ)

The dual objective for fixed γ:
```
g_τ(γ) = -γλ_w² + ∑_{j=1}^J p₀_j · φ_τ^j(γ)
```

**Influence function:**
```
IF_{g_τ}(O; γ) = ∑_{j=1}^J p₀_j · IF_{φ_τ^j}(O; γ)
                = ∑_{j=1}^J p₀_j ∑_{i=1}^J w_i^j(γ) · IF_{h_i}(O)
```

### Step 4: IF for γ*(τ)

This is where it gets tricky. We need the IF for:
```
γ*(τ) = argmax_{γ≥0} g_τ(γ)
```

**Implicit function theorem approach:**

At the optimum, the first-order condition holds:
```
∂g_τ/∂γ|_{γ=γ*} = 0  (if interior solution)
```

The IF for γ* can be derived using the implicit function theorem:
```
IF_{γ*}(O) = -[∂²g_τ/∂γ²|_{γ=γ*}]^{-1} · [∂/∂γ IF_{g_τ}(O; γ)|_{γ=γ*}]
```

This requires:
1. Second derivative of g_τ(γ) at optimum (Hessian)
2. Derivative of the IF with respect to γ

**Complexity:** This is doable but algebraically intensive.

### Step 5: IF for φ*(λ_w, τ)

Finally, by the chain rule:
```
IF_{φ*}(O) = [∂g_τ/∂γ|_{γ=γ*}] · IF_{γ*}(O) + IF_{g_τ}(O; γ*)
```

But since ∂g_τ/∂γ|_{γ=γ*} = 0 (first-order condition), this simplifies to:
```
IF_{φ*}(O) = IF_{g_τ}(O; γ*(τ))
```

**This is the key simplification!** We don't need the IF for γ* - it cancels out at the optimum.

---

## Complete IF Formula

Putting it all together:

```
IF_{φ*}(O) = ∑_{j=1}^J p₀_j ∑_{i=1}^J w_i^j(γ*) · IF_{h_i}(O)
```

where:
- γ* is the optimal dual variable (computed numerically)
- w_i^j(γ*) are the softmax weights at the optimum
- IF_{h_i}(O) are the IFs for concordances

**Centering:** Since each IF_{h_i}(O) has mean zero and we're taking weighted sums, IF_{φ*}(O) also has mean zero.

---

## Implementation Algorithm

**Step 1: Estimate smoothed Wasserstein minimax**
```r
1. Discretize data into J types
2. Estimate τ_S^j, τ_Y^j for each type
3. Compute h_j = τ_S^j × τ_Y^j
4. Compute cost matrix C
5. For grid of γ values, compute g_τ(γ)
6. Find γ* = argmax g_τ(γ)
7. φ* = g_τ(γ*)
```

**Step 2: Compute influence function**
```r
For each observation O_i:
  1. Compute IF_τS(O_i) for surrogate effect
  2. Compute IF_τY(O_i) for outcome effect
  3. For each type k:
     IF_{h_k}(O_i) = (I_k(X_i)/π_k) × [τ_S^k·IF_τY(O_i) + τ_Y^k·IF_τS(O_i)]
  4. Compute softmax weights w_i^j(γ*) at optimum
  5. IF_{φ*}(O_i) = ∑_j p₀_j ∑_k w_k^j(γ*) · IF_{h_k}(O_i)
```

**Step 3: Variance and CI**
```r
σ²= (1/n) ∑_i IF_{φ*}(O_i)²
SE = √(σ²/n)
CI = φ* ± z_{α/2} · SE
```

---

## Advantages Over Alternatives

### vs. Hard minimum Wasserstein dual:
- ✅ Smooth (no selection bias)
- ✅ Has well-defined IF
- ~ Approximation for small τ (but converges to exact)

### vs. Sample splitting:
- ✅ Uses full sample (not n/2)
- ✅ Works with flexible methods
- ✅ More efficient

### vs. Bootstrap only:
- ✅ Explicit IF (theoretical transparency)
- ✅ Faster (no resampling)
- ✅ Can analyze variance decomposition

---

## Theoretical Guarantees

**Theorem (Smoothed Wasserstein Minimax Inference):**

Under regularity conditions:
1. **Consistency:** φ̂* →^p φ*
2. **Asymptotic normality:** √n(φ̂* - φ*) →^d N(0, σ²)
3. **Variance formula:** σ² = Var[IF_{φ*}(O)]
4. **CI coverage:** P(φ* ∈ CI) → 1-α

**Proof sketch:**
1. φ̂* is a smooth functional of empirical distribution
2. IF exists by construction (derived above)
3. Apply functional CLT (van der Vaart)
4. Consistency of variance estimator (standard)

---

## Next Steps

1. **Implement smoothed dual** (2-3 hours)
   - Modify wasserstein_concordance_dual.R to use smooth minimum
   - Add tau parameter for smoothing

2. **Implement IF computation** (2-3 hours)
   - Code up the IF formula
   - Test that E[IF] = 0

3. **Test coverage** (1 hour)
   - Oracle nuisances first
   - Then with estimated nuisances
   - Verify 95% coverage

4. **Write theorem and proof** (1 day)
   - State regularity conditions precisely
   - Complete proof with all details
   - Post-proof audit per constitution

**Timeline:** 2 days for complete implementation + testing + proof

---

## Parameters

**τ (smoothing):** Controls approximation quality
- Small τ (0.01): Close to exact minimum
- Moderate τ (0.1): Good balance
- Recommend: τ = 0.1 × sd(h_i)

**λ_w (Wasserstein radius):** Controls robustness level
- λ_w = 0.3: Mild covariate shift
- λ_w = 0.5: Moderate shift
- λ_w = 1.0: Strong shift
