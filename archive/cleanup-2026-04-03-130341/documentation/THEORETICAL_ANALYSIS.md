# Theoretical Analysis: Can We Prove Adaptive Shrinkage Works?

**Date:** March 31, 2026
**Question:** Do we have theory, or just empirical evidence?

---

## Current Status: Empirical Only

**What we've shown empirically:**
- 93% coverage in simulations (100 reps, one DGP)
- 25% RMSE improvement over fixed (250 reps, 5 DGPs)
- Selection rules work correctly (1,620 reps, 8 DGPs)

**What we LACK:**
- Theoretical proof of coverage
- Convergence rates
- Optimality of adaptive rules
- Minimal assumptions

**The gap:** Simulations suggest it works, but no theoretical guarantee.

---

## What Theory Would We Need?

### 1. Selection Bias Characterization

**Need to prove:**
```
E[min_i(h_est[i])] < E[min_i(h_true[i])]
```
under what conditions and by how much?

**Challenges:**
- Distribution of minimum of correlated normal RVs (not simple)
- Dependence structure from shared covariates
- Non-asymptotic bounds needed (finite n)

**Feasibility:** Difficult. Extreme value theory applies but:
- Requires independence (we have dependence)
- Asymptotic results (we need finite-sample)
- Complex to characterize exactly

### 2. Shrinkage Correction Theory

**Need to prove:**
```
Bias(shrunk estimator) < Bias(naive estimator)
```
with explicit bounds.

**Related work:**
- James-Stein theory: Shrinkage dominates for ≥3 parameters
- But that's for means, not minimax
- Our setting: minimize over shrunk vs unshrunk

**Challenges:**
- James-Stein is for estimation, not optimization
- Min operation non-linear (not just averaging)
- Adaptive selection adds complexity

**Feasibility:** Moderate. Could adapt James-Stein framework but:
- Would need new results for min operation
- Adaptive selection complicates analysis
- Likely only asymptotic results

### 3. Optimal Shrinkage Derivation

**Need to derive:**
```
α*(noise, signal) = argmin_α MSE(shrinkage_α(h))
```

**Challenges:**
- Optimal α depends on unknown quantities
- Would need to estimate (noise, signal) consistently
- Error in estimation affects optimality

**Feasibility:** Low without strong assumptions.
- Could derive oracle optimal α (if knew truth)
- But adaptive rule uses estimates → second-order effects
- Optimality claims hard to prove

### 4. Coverage Guarantees

**Need to prove:**
```
P(truth ∈ CI) ≥ 1 - α + o(1)
```
under stated assumptions.

**Requirements:**
- Asymptotic normality of estimator
- Consistent variance estimation
- Uniform inference (over DGPs)

**Challenges:**
- Bootstrap CI (not analytical)
- Adaptive selection breaks standard theory
- DRO adds distributional robustness layer

**Feasibility:** Very difficult.
- Post-selection inference literature relevant but complex
- Would need selective inference framework
- Likely only asymptotic results with strong regularity

---

## Theoretical Alternatives with Existing Guarantees

### Option 1: Sample Splitting

**Approach:**
1. Split sample: (D1, D2)
2. Use D1 to find worst-case region
3. Use D2 for clean inference (no selection)

**Theory:** Classical
- Independent samples → standard inference
- Coverage guaranteed under regularity
- Well-understood

**Cons:**
- Lose half the data (power loss)
- D1/D2 split arbitrary
- Less efficient

**Empirical performance:** Likely worse than adaptive (but has theory)

### Option 2: Conservative Quantile Instead of Minimum

**Approach:**
```
φ*(α) = α-quantile of concordance distribution
```
Instead of minimum (0-quantile), use 5th or 10th percentile.

**Theory:**
- Quantile estimation well-studied
- Asymptotic normality under conditions
- Coverage proofs exist

**Implementation:**
```r
# Instead of: min over Wasserstein ball
# Use: α-quantile (e.g., α = 0.05)
```

**Pros:**
- Clean theory (no selection bias from extremes)
- Still conservative (not worst-case, but near-worst)
- Inference straightforward

**Cons:**
- Different estimand (not minimax)
- May be too conservative or not conservative enough
- How to choose α?

### Option 3: Smooth Minimum (LogSumExp)

**Approach:**
```
φ_smooth = -log(mean(exp(-h_i / τ))) × τ
```
As τ → 0, converges to min. For τ > 0, smooth approximation.

**Theory:**
- Differentiable (standard M-estimation)
- Asymptotic normality possible
- Bootstrap valid

**Pros:**
- Avoids hard minimum (smooth)
- Still approximates minimax
- Tuning parameter τ controls smoothness

**Cons:**
- Not exactly minimax
- Need to choose τ (bias-variance tradeoff)
- Theory requires regularity conditions

### Option 4: Bayesian DRO

**Approach:**
1. Put prior on (τ_S, τ_Y)
2. Compute posterior given data
3. Posterior of φ* accounts for uncertainty
4. Credible interval

**Theory:**
- Bayesian credible intervals
- Frequentist coverage under prior calibration
- Uncertainty quantification natural

**Pros:**
- Principled uncertainty propagation
- Can prove coverage under assumptions
- No ad-hoc corrections

**Cons:**
- Prior choice matters
- Computationally intensive
- May not improve over frequentist in finite samples

### Option 5: Robust M-Estimation

**Approach:**
```
φ_robust = mean(ψ(h_i))
```
where ψ is robust loss (e.g., Huber, Tukey bisquare).

**Theory:**
- M-estimation theory well-developed
- Asymptotic normality
- Robust to outliers

**Pros:**
- Established theory (van der Vaart, Huber)
- Downweights extremes (like shrinkage)
- Inference straightforward

**Cons:**
- Not minimax (different estimand)
- Tuning constant choice affects results
- May be too conservative

---

## Hybrid: Theoretically-Justified Shrinkage

### Idea: Use Theory to Guide Shrinkage

**Can we derive optimal shrinkage from first principles?**

**James-Stein for extremes:**
```
h_i ~ N(θ_i, σ²)
θ̂_JS = mean(h) + (1 - (p-2)σ²/RSS) × (h - mean(h))
```

**Adaptation for DRO:**
1. Estimate σ² from data
2. Compute James-Stein shrinkage
3. Use shrunk estimates in DRO
4. Theory: Shrinkage reduces MSE (proven)

**What we can prove:**
- E[MSE(shrunk)] < E[MSE(unshrunk)] for p ≥ 3
- Reduction in estimation error

**What we CANNOT prove (easily):**
- How shrinkage affects min operation
- Coverage of resulting CI
- Optimality for DRO setting

**Feasibility:** Medium
- Could write down James-Stein version
- Simulation evidence would support
- But full coverage proof still hard

---

## Recommended Path Forward

### Option A: Develop Partial Theory for Adaptive Shrinkage

**What we can prove:**
1. Selection bias exists (heuristic argument, not formal)
2. Shrinkage reduces estimation error (James-Stein)
3. Empirical coverage via extensive simulation

**Manuscript framing:**
- "Empirically validated adaptive method"
- "Motivated by shrinkage theory"
- "Extensive simulation evidence"
- Acknowledge limitation: "Formal coverage proof remains open"

**Pros:** Use what we've developed
**Cons:** Not fully rigorous

### Option B: Pivot to Theoretically Guaranteed Method

**Design new method with provable properties:**

1. **Sample splitting** (cleanest theory)
2. **Conservative quantile** (good balance)
3. **Smooth minimum** (differentiable, standard theory)

**Then:**
- Prove coverage under regularity conditions
- Derive convergence rates
- Compare empirically to adaptive

**Pros:** Rigorous, publishable in top journals
**Cons:** May perform worse empirically, more work

### Option C: Combine Empirical + Asymptotic Theory

**Hybrid approach:**
1. Prove asymptotic coverage (n → ∞)
2. Show finite-sample performance via simulation
3. Provide practical guidance

**Asymptotic result (feasible):**
```
Under regularity:
√n(φ̂* - φ*) →^d N(0, Σ)
⇒ CI has asymptotic coverage
```

**Would need:**
- Regularity conditions on DGP
- Consistency of bootstrap
- Standard M-estimation theory

**Pros:** Partial theory + empirical validation
**Cons:** Asymptotic only (not finite-sample)

---

## My Recommendation: Option B + Theoretical Comparison

**Step 1: Implement theoretically-grounded alternatives**
- Sample splitting
- Conservative quantile (α = 0.05, 0.10)
- Smooth minimum (τ = 0.1, 0.5)

**Step 2: Prove coverage for each**
- Write down regularity conditions
- Prove asymptotic coverage
- Derive rates if possible

**Step 3: Empirical comparison**
- Test all methods on our 8 DGP scenarios
- Compare:
  - Coverage (does theory hold in practice?)
  - Power (CI width)
  - RMSE
  - Computational cost

**Step 4: Recommend based on theory + practice**
- Best theoretical guarantee: Sample splitting
- Best empirical: Adaptive shrinkage
- Best balance: Conservative quantile or smooth minimum

**Manuscript:**
- Present multiple methods
- Theory for 2-3 approaches
- Empirical comparison shows trade-offs
- Practical guidance on which to use when

---

## Specific Theoretical Results We Could Prove

### Theorem 1: Sample Splitting Coverage (Easy)

**Statement:**
Under regularity conditions (continuity, variance bounded):
```
P(φ* ∈ CI_split) → 1 - α
```

**Proof sketch:**
- D1, D2 independent
- D2 inference standard (no selection)
- Bootstrap valid under conditions
- Standard asymptotic theory

### Theorem 2: Conservative Quantile Coverage (Medium)

**Statement:**
Let φ̂_α = α-quantile of {h_shrunk}. Under regularity:
```
P(φ* ∈ CI(φ̂_α)) → 1 - α'
```
where α' depends on α and DGP.

**Proof sketch:**
- Quantile estimation theory (Serfling)
- Bootstrap for quantiles (valid)
- Show φ̂_α → φ_α in probability
- Coverage follows

### Theorem 3: Smooth Minimum Asymptotic Normality (Medium)

**Statement:**
Let φ̂_τ = -τ log(mean(exp(-h/τ))). Under regularity:
```
√n(φ̂_τ - φ_τ) →^d N(0, σ²_τ)
```

**Proof sketch:**
- M-estimation framework
- Differentiability of φ_τ
- Delta method
- Bootstrap consistent

### Theorem 4: Shrinkage Reduces MSE (Medium, for our setting)

**Statement:**
For h_i ~ N(θ_i, σ²) with p ≥ 3:
```
E[||θ̂_shrink - θ||²] < E[||θ̂_naive - θ||²]
```

**Adaptation needed:**
- Apply to concordances (not means)
- Show improvement carries through to min operation
- Quantify reduction

---

## Questions to Answer

1. **How much theory do you want?**
   - Full proofs (months of work)
   - Partial results + simulation (weeks)
   - Heuristic motivation only (current)

2. **Which approach to prioritize?**
   - Stick with adaptive (best empirically)
   - Pivot to theory-backed (rigor)
   - Test both (comprehensive)

3. **Target journal?**
   - Top stats (need theory): Annals, JRSS-B, Biometrika
   - Applied/methods (empirical OK): Biometrics, Biostatistics
   - Computation (simulation-heavy): JCGS, CSDA

4. **Timeline?**
   - Quick solution (adaptive + asymptotic theory): 1-2 weeks
   - Rigorous solution (full theory + proofs): 2-3 months
   - Comprehensive (multiple methods + theory): 1 month

---

## Next Steps

**Immediate:**
1. Decide on approach (A, B, or C)
2. If B: Design theoretically-grounded alternatives
3. If A or C: Develop partial theory for adaptive

**Tomorrow (if Option B):**
1. Implement sample splitting
2. Implement conservative quantile
3. Implement smooth minimum
4. Test all on our scenarios
5. Write up theoretical results

**This week:**
1. Complete empirical comparison
2. Draft theoretical results
3. Assess which method to recommend

What's your preference?
