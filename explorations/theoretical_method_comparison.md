# When Do Different Surrogate Evaluation Approaches Diverge?

**Goal:** Identify scenarios where PTE, mediation, principal stratification, meta-analysis, and our correlation functionals give different answers about surrogate quality.

## Setup: Binary DGP

All variables binary: X (baseline), A (treatment), S (surrogate), Y (outcome)

Potential outcomes: S(0), S(1), Y(0), Y(1)

Joint distribution: P(X, S(0), S(1), Y(0), Y(1))

## Summary of Approaches

### 1. PTE (Proportion of Treatment Effect Explained)
$$\text{PTE} = 1 - \frac{E[Y(1) - Y(0) \mid S(1) = S(0)]}{E[Y(1) - Y(0)]}$$

**Interpretation:** Fraction of treatment effect eliminated when surrogate doesn't change.

**Good surrogate:** PTE ≈ 1 (small effect when S constant)

### 2. Mediation Analysis
$$\text{NIE} = E[Y(1, S(1)) - Y(1, S(0))]$$
$$\text{NDE} = E[Y(1, S(0)) - Y(0, S(0))]$$
$$\text{Proportion Mediated} = \frac{\text{NIE}}{\text{NIE} + \text{NDE}}$$

**Interpretation:** How much effect operates through S pathway?

**Good surrogate:** Large NIE relative to total effect.

### 3. Principal Stratification
Effects within strata: $E[Y(1) - Y(0) \mid S(0) = s_0, S(1) = s_1]$

**Interpretation:** Treatment effects by surrogate response pattern.

**Good surrogate:** Systematic variation by stratum; effect concentrated in strata where S changes.

### 4. Meta-Analysis (Traditional)
Model heterogeneity: $\theta_{\text{study}} \sim N(\mu, \tau^2)$

**Interpretation:** Between-study variance in effects.

**Good surrogate (implicit):** S explains between-study heterogeneity.

### 5. Our Correlation Functional
$$\rho(S_0, S_1; Y_0, Y_1) \text{ or } P(S_0, S_1 \mid Y_0, Y_1) \text{ or } E[S_0, S_1 \mid Y_0, Y_1]$$

**Interpretation:** Joint distribution structure; how S-Y relationship varies.

**Good surrogate:** Strong correlation structure that bounds across-study variation.

## Key Differences: What Each Method Captures

| Method | Focus | Question Answered |
|--------|-------|-------------------|
| PTE | Within-study mechanism | "Is effect mediated by S in this study?" |
| Mediation | Causal pathway decomposition | "How much operates through vs. outside S?" |
| Principal Strat | Within-study heterogeneity | "Does effect vary by S response pattern?" |
| Meta-Analysis | Between-study variation | "How much do effects vary across existing studies?" |
| **Our Approach** | **Transportability bounds** | **"How much could effects vary in future studies?"** |

## Scenarios Where Methods Diverge

### Scenario 1: Surrogate Changes but Doesn't Affect Outcome

**DGP:**
- $A \to S$: Treatment affects surrogate, $P(S(1) = 1) > P(S(0) = 1)$
- $S \not\to Y$: Surrogate doesn't affect outcome, $P(Y \mid S = 1) \approx P(Y \mid S = 0)$
- $A \to Y$: Direct treatment effect exists

**What Each Method Says:**

- **PTE:**
  - Denominator: $E[Y(1) - Y(0)] \neq 0$ ✓
  - Numerator: $E[Y(1) - Y(0) \mid S(1) = S(0)]$ also $\neq 0$ (direct effect)
  - PTE ≈ 0 → **Poor surrogate** ✓

- **Mediation:**
  - NIE ≈ 0 (no effect through S)
  - NDE ≠ 0 (all direct)
  - Proportion mediated ≈ 0 → **Poor surrogate** ✓

- **Prentice Criteria:**
  - Criterion 1: A → Y ✓
  - Criterion 2: A → S ✓
  - Criterion 3: S → Y (conditional on A) ✗ **FAILS**
  - Criterion 4: No direct effect ✗ **FAILS**
  - → **Poor surrogate** ✓

- **Our Correlation:**
  - $\rho(S_0, Y_0)$ ≈ 0 (weak association)
  - $\rho(S_1, Y_1)$ ≈ 0 (weak association)
  - → **Poor surrogate** ✓

**Verdict:** All methods agree - poor surrogate.

---

### Scenario 2: Strong Surrogate, but Non-Monotone Effect Modification

**DGP:**
- $Y(a) = f(S(a), a)$ where effect of S on Y depends on a
- Example: $E[Y(a) \mid S(a) = s] = \beta_0 + \beta_a \cdot a + \beta_s \cdot s + \beta_{as} \cdot a \cdot s$
- With $\beta_{as} < 0$ (negative interaction)

**Specific numbers:**
- $E[Y(0) \mid S(0) = 0] = 0.2$
- $E[Y(0) \mid S(0) = 1] = 0.6$ (S increases Y under control)
- $E[Y(1) \mid S(1) = 0] = 0.5$ (treatment helps when S = 0)
- $E[Y(1) \mid S(1) = 1] = 0.7$ (treatment helps less when S = 1)

**Principal Stratification:**

Four strata, suppose:

| Stratum | $S(0)$ | $S(1)$ | $P(\text{stratum})$ | $E[Y(1) - Y(0) \mid \text{stratum}]$ |
|---------|--------|--------|---------------------|--------------------------------------|
| 1 | 0 | 0 | 0.3 | 0.3 |
| 2 | 0 | 1 | 0.2 | 0.1 |
| 3 | 1 | 0 | 0.1 | 0.0 |
| 4 | 1 | 1 | 0.4 | 0.1 |

**What Each Method Says:**

- **PTE:**
  - Focus on strata 1 & 4 (where $S(1) = S(0)$)
  - If most probability is in stratum 4 with moderate effect, PTE might look good
  - But misses the heterogeneity!

- **Mediation:**
  - NIE depends on cross-world $Y(1, S(0))$
  - With interaction, NIE ≠ simple function of main effects
  - Could be misleading if interaction not accounted for

- **Principal Stratification:**
  - Clearly shows heterogeneity: effect is 0.3 in stratum 1 but 0.0 in stratum 3
  - **Reveals the problem** ✓

- **Our Correlation:**
  - $\rho(S_0, Y_0) \neq \rho(S_1, Y_1)$ (different under control vs. treatment)
  - Signals that S-Y relationship changes with treatment
  - This is a **transportability concern**: if future study has different treatment regime, S-Y relationship changes

**Verdict:**
- PTE might miss the heterogeneity
- Mediation averages over it
- Principal strat reveals it
- **Our approach: uniquely signals transportability concern**

---

### Scenario 3: Surrogate Quality Depends on Baseline Covariate X

**DGP:**
- S is good surrogate for $X = 0$: $Y(a) \approx g(S(a))$ when $X = 0$
- S is poor surrogate for $X = 1$: large direct effect when $X = 1$

**Example:**
- When $X = 0$: $E[Y(a) \mid S(a) = s, X = 0] = 0.1 + 0.6s$ (S dominates)
- When $X = 1$: $E[Y(a) \mid S(a) = s, X = 1] = 0.3 + 0.2s + 0.3a$ (large direct effect)

**What Each Method Says:**

- **PTE (unconditional):**
  - Averages over $X$, might show moderate PTE
  - Misses that quality varies by $X$

- **PTE (conditional on X):**
  - PTE($X = 0$) ≈ 1 (excellent)
  - PTE($X = 1$) ≈ 0.4 (poor)
  - **Reveals heterogeneity** ✓

- **Mediation (conditional):**
  - Similarly can reveal $X$-specific effects

- **Our Approach:**
  - Can compute $\rho(S_0, S_1; Y_0, Y_1 \mid X)$
  - Shows different correlation structure by $X$
  - **But crucially:** also answers "If future study has different $X$ distribution, how much can effects vary?"
  - This is our unique contribution: not just heterogeneity, but **transportability bounds**

**Verdict:**
- All methods can reveal $X$-specific heterogeneity if applied conditionally
- **Our approach adds:** bounds on variation when target study has different $X$ distribution

---

### Scenario 4: The Transportability Scenario (Our Unique Contribution)

**Setup:**
- Source study: measure joint $(S(0), S(1), Y(0), Y(1))$ distribution $P_0$
- Target study: different population with distribution $Q$
- Model: $Q = (1 - \lambda) P_0 + \lambda \tilde{P}$ for unknown $\tilde{P}$

**Source Study Data:**
- Strong S-Y association: $\rho(S_0, Y_0) = 0.7$
- PTE = 0.85 (excellent surrogate)
- NIE / TE = 0.80 (excellent surrogate)

**Question:** Will S be a good surrogate in the target study?

**Traditional Approaches:**
- **PTE in source:** 0.85 → looks great!
- **Mediation in source:** 80% mediated → looks great!
- **Meta-analysis:** If we have multiple source studies, can estimate $\tau^2$
  - But this assumes future studies are "similar" to past studies
  - Doesn't bound worst-case

**Our Approach:**
- Compute $\rho(S_0, S_1; Y_0, Y_1)$ functionals
- These functionals bound how much S-Y relationship can change across $Q$ distributions
- Example: if $P(S_0 \leq s_0, S_1 \leq s_1 \mid Y_0 = 0, Y_1 = 1)$ is concentrated, then even in worst-case $\tilde{P}$, S still predicts Y

**Key Insight:**
- Traditional methods evaluate S in **observed** studies
- Our approach bounds S performance in **unobserved** future studies
- The correlation functional captures **joint (S,Y) potential outcome structure** which constrains possible mechanisms

**Mathematical Connection:**

In the mixture model $Q = (1-\lambda)P_0 + \lambda\tilde{P}$:

$$E_Q[Y(1)] - E_Q[Y(0)] = (1-\lambda)(E_{P_0}[Y(1)] - E_{P_0}[Y(0)]) + \lambda(E_{\tilde{P}}[Y(1)] - E_{\tilde{P}}[Y(0)])$$

Traditional methods tell us about $E_{P_0}[Y(1) - Y(0)]$ and decompositions thereof.

Our functionals bound the range of $E_{\tilde{P}}[Y(1) - Y(0)]$ by using the **joint distribution constraints**.

For example, if $\rho_{P_0}(S_1, Y_1)$ is high AND this correlation structure is "stable" (in a sense we define via the functionals), then $\rho_{\tilde{P}}(S_1, Y_1)$ can't be too different.

---

### Scenario 5: Mediation Works, But Wrong Mechanism

**DGP:**
- Treatment → Surrogate → Outcome (indirect path)
- Treatment → Outcome (direct path)
- Both paths exist, NIE is moderate

**But:** The indirect path operates through a mechanism **different** from what we think.

**Example:**
- We think: A → S (biomarker) → Y (clinical outcome) via biological pathway
- Reality: A → S via biology, but A → Y via separate pathway
- S and Y are correlated due to common cause of A, not S → Y

**In observed data:**
- Can't distinguish this without additional assumptions
- Mediation analysis shows NIE > 0
- Looks like S mediates

**For transportability:**
- If the "common cause" structure changes in target population, S-Y correlation breaks
- Traditional mediation: doesn't flag this
- **Our approach:** by examining **joint potential outcome structure**, can reveal if S-Y association is "fragile"

**Specifically:**
- If $P(S_0, S_1 \mid Y_0, Y_1)$ shows weak dependence, this signals fragility
- If conditioning on Y doesn't meaningfully constrain S distribution, then S isn't structurally tied to Y

---

## Summary: When Do Methods Diverge?

### They Agree When:
1. ✓ Surrogate is clearly bad (Scenario 1)
2. ✓ Surrogate is clearly perfect (Prentice criterion 4 holds exactly)
3. ✓ Simple, homogeneous, monotone effects

### They Diverge When:
1. ✗ **Effect modification / interaction** (Scenario 2)
   - Principal strat reveals it most clearly
   - Our correlation signals transportability concern

2. ✗ **Heterogeneity by subgroup** (Scenario 3)
   - All methods can detect if applied conditionally
   - Our approach additionally bounds cross-population variation

3. ✗ **Transportability to new populations** (Scenario 4) ⭐ **OUR UNIQUE CONTRIBUTION**
   - Traditional: evaluate surrogate in observed studies
   - Ours: bound surrogate performance in unobserved future studies

4. ✗ **Wrong mechanism** (Scenario 5)
   - Mediation shows indirect effect, but might be spurious
   - Our joint distribution functionals can reveal fragility

## The Core Distinction

**Traditional methods ask:** "Is S a good surrogate in THIS study (or these observed studies)?"

**Our approach asks:** "Will S be a good surrogate in FUTURE studies with unknown population composition Q?"

### Mathematical Formulation:

**Traditional:**
- Characterize $P_0(S, Y \mid \text{treatment})$
- Good surrogate ⟺ strong association, mediation, etc. **within $P_0$**

**Ours:**
- Given $P_0$, bound performance under $Q = (1-\lambda)P_0 + \lambda\tilde{P}$
- Good surrogate ⟺ **joint potential outcome structure** constrains variation across Q
- Use $\rho(S_0, S_1; Y_0, Y_1)$, $P(S_0, S_1 \mid Y_0, Y_1)$, etc. to bound this variation

## Implications for Paper

### Theoretical Development:
1. Show that traditional methods (PTE, mediation, principal strat) measure **within-study** properties
2. Show that these don't directly bound **across-study** (transportability) properties
3. Show that our functionals provide explicit transportability bounds via the mixture model

### Simulations:
1. Scenario 2 (effect modification): Show principal strat and our functionals reveal it; PTE misses it
2. Scenario 4 (transportability): Show traditional methods look good in source, but fail in target; our bounds correctly flag concern
3. Scenario 5 (fragile mechanism): Show our joint distribution diagnostics reveal fragility

### Connection to Meta-Analysis:
- Meta-analysis estimates $\tau^2$ from **observed** studies
- Implicitly assumes future studies drawn from same population
- Our approach: explicitly model **unobserved** future study as mixture
- Provides **worst-case bounds**, not just estimated variance

## Open Questions

1. Can we formalize "stability" of correlation structure?
   - What does it mean for $\rho(S_0, S_1; Y_0, Y_1)$ to be "robust"?

2. Can we connect our functionals to Prentice criteria?
   - Prentice criterion 4 ⟺ some specific correlation structure?

3. Can we derive PTE from our functionals?
   - PTE uses specific principal stratum; can we express in terms of our probability functional?

4. What's the relationship to causal mediation under effect modification?
   - VanderWeele's work on mediation with interactions

5. How do our bounds compare to prediction intervals in meta-analysis?
   - $\tau^2$ based on observed; ours based on potential outcome structure

## Next Steps

1. ✅ Work out Scenarios 2, 4, 5 analytically for binary DGP
2. ⬜ Derive explicit formulas connecting traditional methods to our functionals
3. ⬜ Prove: under what conditions do traditional methods coincide with ours?
4. ⬜ Develop "transportability diagnostic" based on our functionals
5. ⬜ Simulation studies for each divergence scenario
