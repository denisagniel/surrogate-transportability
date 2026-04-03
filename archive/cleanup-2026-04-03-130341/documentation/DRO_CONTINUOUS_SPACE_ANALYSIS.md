# How Does DRO Handle Continuous Covariate Spaces?

## The Core Issue

**Our discretization problem:**
- We bin continuous covariates into J types
- With J=16 types and n=250, each type has ~15 observations
- Type-level treatment effect estimates have RMSE ≈ 0.3
- Taking minimum amplifies noise → systematic bias

**Your question:** Standard DRO doesn't discretize. How do they handle continuous covariate spaces?

## Standard DRO (Risk Minimization Context)

### Classic Setup

In standard DRO for risk minimization:

```
min_θ max_{Q: d(Q,P_n)≤ε} E_Q[loss(θ, (X,Y))]
```

**Key properties:**
- Loss is defined at **observation level**: loss(θ, (x_i, y_i))
- No aggregation needed - each (x,y) pair has a loss
- No discretization required
- Works directly with n observations

### Wasserstein DRO

For Wasserstein balls with **linear functionals**:

```
min_{Q: W_2(Q,P_n)≤λ} E_Q[h(ω)]
```

Has **dual formulation** (Esfahani & Kuhn 2018):

```
sup_{γ≥0} { -γλ² + (1/n)Σᵢ min_j {h(ω_j) + γc(ω_i, ω_j)} }
```

**Properties:**
- Works directly with n observations (no discretization!)
- Cost c(ω_i, ω_j) uses covariate distance: c(x_i, x_j) = ||x_i - x_j||²
- Optimization is over single parameter γ
- **No discretization noise**

### TV-Ball DRO

For TV balls: Q = (1-λ)P_n + λP̃

For **linear functionals**, worst case is often at a **point mass**:
- Put all innovation mass on observation with min h(ω_i)
- Result: φ* = (1-λ)E_Pn[h] + λ·min_i h(ω_i)

**Again: no discretization!**

## Our Problem: Treatment Effect Functionals

### Why We're Different

Our functional is **concordance**: E[τ_S · τ_Y]

**Problem:** τ_S and τ_Y are **treatment effects**, not observation-level quantities:
- τ_S = E[S|A=1] - E[S|A=0]
- τ_Y = E[Y|A=1] - E[Y|A=0]

These require **aggregation** over observations to compute expectations.

### The Discretization Dilemma

**Why we discretized:**
1. Can't compute treatment effect for a single observation
2. Need groups to estimate E[Y|A=1] vs E[Y|A=0]
3. Discretizing creates groups → can estimate treatment effects per group
4. Then apply DRO at the **group level**

**The cost:**
- Small groups → noisy treatment effect estimates
- Selection of minimum group → winner's curse
- Systematic underestimation

## Principled Solutions (No Discretization)

### Option 1: Observation-Level Wasserstein with Treatment Effect Regression

**Approach:**
1. Model τ_S(x) and τ_Y(x) as **smooth functions** of covariates
2. Estimate via flexible regression (random forest, kernel regression, etc.)
3. For each Q in Wasserstein ball, compute: E_Q[τ_S(X) · τ_Y(X)]
4. Use Wasserstein dual with h(x_i) = τ_S(x_i) · τ_Y(x_i)

**Advantages:**
- No discretization (works with n observations)
- Uses Wasserstein geometry (natural for covariate shift)
- Principled: models what we believe (treatment effects vary smoothly with X)

**Implementation:**
```r
# Step 1: Estimate treatment effect functions
tau_s_fit <- fit_treatment_effect(data, outcome = "S", covariates = X)
tau_y_fit <- fit_treatment_effect(data, outcome = "Y", covariates = X)

# Step 2: Evaluate at each observation
h_i <- tau_s_fit(X_i) * tau_y_fit(X_i)  # concordance at each x_i

# Step 3: Wasserstein DRO dual
result <- wasserstein_dual_linear(h = h_i, cost_matrix = C, lambda_w = λ)
```

**Challenges:**
- Requires flexible treatment effect estimation (doubly robust? cross-fitting?)
- Need to validate that regression captures heterogeneity

### Option 2: Kernel-Based Local Treatment Effects

**Approach:**
1. For each x, estimate **local treatment effects** using kernel weights
2. τ_S(x) = Σ K_h(x, x_i) · S_i · A_i / Σ K_h(x, x_i) · A_i - [control analog]
3. Concordance h(x) = τ_S(x) · τ_Y(x)
4. Apply observation-level DRO

**Advantages:**
- Non-parametric (no model for τ(x))
- Natural bandwidth selection methods
- Still avoids discretization

**Challenges:**
- Bandwidth choice affects results
- May be noisy in sparse covariate regions
- Computationally expensive (kernel weights for each Q)

### Option 3: Semi-parametric Efficient Estimation + DRO

**Approach:**
1. Use **doubly robust** or **targeted learning** to estimate E[τ_S(X) · τ_Y(X)]
2. Get influence functions ψ_i for each observation
3. Apply DRO at observation level with h_i = ψ_i

**Advantages:**
- Statistically efficient (semiparametric efficiency)
- Principled inference framework
- Observation-level (no discretization)

**Challenges:**
- Requires careful implementation (nuisance function estimation)
- Unclear how influence functions interact with DRO reweighting

### Option 4: Use Wasserstein (We Already Have It!)

**Key insight:** Our Wasserstein implementation uses a **cost matrix** based on covariate distance.

Even though we discretize to J types, the Wasserstein geometry **preserves covariate space structure** via:
```
C[i,j] = ||centroid_i - centroid_j||²
```

This is fundamentally different from TV-ball, which treats types as **unordered categories**.

**Hypothesis:** Wasserstein should be more robust to discretization noise because:
- Cost matrix encodes that "nearby types are similar"
- Adversary pays a cost for shifting mass to distant types
- Regularizes the reweighting

**Test:** Does Wasserstein achieve proper coverage in our diagnostics?

## Recommendations

### Immediate (Diagnostic-Driven)

1. **Check if Wasserstein works correctly** (Diagnostic 5 tried but had errors)
   - If Wasserstein achieves 93-95% coverage → use it instead of TV-ball
   - Wasserstein geometry is more natural for continuous covariates anyway

2. **If Wasserstein also fails:**
   - Root cause is not TV vs Wasserstein geometry
   - Must be treatment effect estimation or something else

### Medium Term (Principled Fix)

3. **Implement Option 1: Treatment effect regression + observation-level Wasserstein**
   - Model τ_S(X), τ_Y(X) via flexible regression (random forest, kernel smoothing)
   - Evaluate at each observation: h_i = τ_S(x_i) · τ_Y(x_i)
   - Use n×n cost matrix C[i,j] = ||x_i - x_j||²
   - Solve Wasserstein dual (already have the solver!)

4. **Use cross-fitting** to avoid overfitting:
   - Split data: estimate τ(X) on half, evaluate on other half
   - Or use out-of-bag predictions from random forest

### Theoretical Clarity

5. **Clarify the estimand:**
   - Are we estimating E_F_λ[concordance] where F_λ is over **type compositions**?
   - Or E_F_λ[concordance] where F_λ is over **covariate distributions**?
   - These are different if types are defined by discrete characteristics vs continuous X

## Key Insight

**Standard DRO doesn't need discretization because the loss is defined at observation level.**

**Our challenge:** Treatment effects require aggregation → need groups.

**Solution:** Don't aggregate into discrete groups. Instead:
- Model treatment effects as smooth functions of X (regression)
- Estimate locally via kernels
- Use semiparametric methods

Then apply observation-level DRO (especially Wasserstein with cost matrix).

## Next Steps

1. **Fix Diagnostic 5** to test if Wasserstein works correctly
2. **If yes:** Switch primary method to Wasserstein (it's better suited for continuous covariates)
3. **If no:** Implement treatment effect regression + observation-level Wasserstein (Option 1)

---

**Bottom line:** You're right that we shouldn't rely on noisy discrete estimates. The DRO literature handles continuous spaces by working at the observation level. We need to do the same by modeling treatment effects as functions of covariates rather than discretizing.
