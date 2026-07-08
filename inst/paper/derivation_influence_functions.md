# Influence-Function Derivation for the TV-Ball Correlation Estimator

**Date:** 2026-07-08
**Status:** Reference derivation — code (`tv_ball_correlation_IF_adaptive.R`) and the proof
(`proof_asymptotic_normality.tex`) must both match this. Produced during Phase 1.5 of the
canonical-realignment effort (user decision: derive fresh, no prior trusted derivation).

---

## 1. Setup and estimand

Observed data `O = (X, A, S, Y)`, `A ∈ {0,1}`, finite covariate support `X ∈ {1,…,K}`
(after discretization). Write cell probabilities `p₀(k) = P₀(X=k)`, propensity
`e(k) = P(A=1 | X=k)`, and outcome regressions `μ_a^S(k) = E[S | A=a, X=k]`,
`μ_a^Y(k) = E[Y | A=a, X=k]`. Cell-level CATEs:
```
τ_S(k) = μ_1^S(k) − μ_0^S(k),   τ_Y(k) = μ_1^Y(k) − μ_0^Y(k).
```

A **future study** `Q` is a distribution on the same finite support with cell
probabilities `q_k`, drawn `Q ~ Uniform(U(P₀, λ; TV))`, `U = {Q : ½Σ_k|q_k − p₀(k)| ≤ λ}`,
under absolute continuity `Q ≪ P₀` (so `q_k = 0` wherever `p₀(k)=0`).

**Per-study treatment effects** (population reweighting — Q changes composition only):
```
Δ_S(Q) = Σ_k q_k τ_S(k),    Δ_Y(Q) = Σ_k q_k τ_Y(k).
```
Equivalently `Δ_S(Q) = E_{P₀}[ w(X) τ_S(X) ]` with density ratio `w(X) = q(X)/p₀(X)`.

**Target functional** (correlation across future studies, μ = uniform on the ball):
```
Θ(P₀, λ) = cor_μ( Δ_S(Q), Δ_Y(Q) ).
```

---

## 2. Influence function for a single Δ(Q), fixed Q

Because `q_k` is **fixed** (Q is an external target composition, not P₀ itself),
`Δ_S(Q) = Σ_k q_k τ_S(k)` depends on P₀ **only through the CATEs** `τ_S(k)`, not through
`p₀`. Its efficient influence function is therefore `Σ_k q_k ×` (EIF of `τ_S(k)`).

The EIF of a cell conditional mean `μ_1^S(k) = E[S|A=1,X=k]` contributed by observation `i` is
`𝟙{X_i=k}𝟙{A_i=1} / (p₀(k) e(k)) · (S_i − μ_1^S(k))`, and similarly for `μ_0^S(k)`.
Summing `Σ_k q_k(EIF[μ_1^S(k)] − EIF[μ_0^S(k)])` and using
`Σ_k q_k 𝟙{X_i=k}/p₀(k)(·) = w(X_i)(·)` gives the **per-study influence function**

```
ψ_S(O_i; Q) = w(X_i) [ A_i (S_i − μ_1^S(X_i)) / e(X_i)
                      − (1−A_i)(S_i − μ_0^S(X_i)) / (1−e(X_i))
                      + μ_1^S(X_i) − μ_0^S(X_i) ]
              − Δ_S(Q).                                              (★)
```

Three points, each a correction to the current code:

1. **Centering is the constant `−Δ_S(Q)`, NOT `−w(X_i)·Δ_S(Q)`.** Both have mean ≈ 0
   (since `E[w]=1`), but only the constant centering yields the correct per-observation IF
   and hence the correct variance. *(Current code subtracts `w_i·Δ_S_m` — bug.)*

2. **The whole AIPW score, including the plug-in `μ_1 − μ_0`, is multiplied by `w(X_i)`.**
   This is correct *for this estimand* and differs from the textbook DR-ATE IF (which has an
   un-reweighted `+(μ_1(X)−μ_0(X)−ψ)` covariate-augmentation term). The textbook form is for
   `E_{P₀}[τ(X)]`, where perturbing P₀ moves the covariate law; here the target law is the
   fixed external Q, so there is no P₀-covariate augmentation. *(The point estimator
   `(1/n)Σ_i w_i[AIPW score] ` is therefore CORRECT as coded; only the IF centering is wrong.)*

3. **Double robustness / Neyman orthogonality.** `E_{P₀}[ψ_S(O;Q)] = 0` when either `e` or
   `(μ_1^S, μ_0^S)` is correct, and `∂_η E[ψ_S] = 0` at the truth. With cross-fitting, the
   nuisance-estimation contribution is `o_p(n^{-1/2})` under `o_p(n^{-1/4})` product rates.

### RCT / importance-weighting special case

Under randomization with **known** propensity, the Hájek weighted difference in means
`Δ̂_S(Q) = Σw_iA_iS_i/Σw_iA_i − Σw_i(1−A_i)S_i/Σw_i(1−A_i)` has influence function

```
ψ_S(O_i; Q) = w(X_i) [ A_i (S_i − m_{S,1}) / ē_1
                      − (1−A_i)(S_i − m_{S,0}) / ē_0 ]              (★★)
```
where `m_{S,a}` are the weighted arm means and `ē_1 = E[wA]`, `ē_0 = E[w(1−A)]` are the
**average weights per arm** (estimated by `(1/n)Σ_i w_iA_i` and `(1/n)Σ_i w_i(1−A_i)`).

- The current code uses a **hard-coded factor of 2 and no `ē_a` denominator**. Since
  `2 = 1/ē_a` exactly when `e≡0.5` and weights average to 1 per arm, the code is
  **correct for a balanced RCT** (`A ~ Bernoulli(0.5)`, as in all 4 canonical DGPs) — which
  is why the reported RCT coverage was ≈ nominal. It is **wrong for `e ≠ 0.5`** or unbalanced
  designs. Replace `2·(…)` with `(…)/ē_a` using the actual per-arm average weights.

---

## 3. Delta method across studies (the functional layer)

`Θ = φ(Δ_S(Q_1),…,Δ_S(Q_M), Δ_Y(Q_1),…,Δ_Y(Q_M))` is the sample Pearson correlation of the
`M` pairs. **Correctly, Θ is a smooth function of five μ-moments**
`(E_μΔ_S, E_μΔ_Y, E_μΔ_S², E_μΔ_Y², E_μΔ_SΔ_Y)`; the proof's functional layer must be
reformulated this way (not as a fixed map `ℝ²→ℝ`). The per-study gradient
`∂φ/∂Δ_S(Q_m)` returned by `gradient_correlation_analytical` already equals the correct
partial derivative and carries the `1/(M s_S s_Y)` factor.

First-order expansion, using `Δ̂_S(Q_m) − Δ_S(Q_m) ≈ (1/n)Σ_i ψ_S(O_i; Q_m)`:
```
√n(Θ̂ − Θ_M) ≈ (1/√n) Σ_i Ψ(O_i),
Ψ(O_i) = Σ_m [ ∂φ/∂Δ_S(Q_m) · ψ_S(O_i; Q_m) + ∂φ/∂Δ_Y(Q_m) · ψ_Y(O_i; Q_m) ].
```
So `σ² = E[Ψ(O)²]`, `se = sqrt(σ̂²/n)` with `σ̂² = (1/n)Σ_i Ψ̂(O_i)²`. **This composition —
gradient (with its 1/M) dotted into the per-observation, un-divided-by-n IFs `ψ` — is
structurally correct as coded.** The bugs are only in the `ψ_S, ψ_Y` themselves (§2) and in
what is omitted (§4). `Θ_M` here is the correlation under the **empirical** measure `μ̂_M` of
the M sampled studies; see §4 for `Θ_M` vs `Θ`.

---

## 4. Two variance sources: estimation (√n) and MCMC (√M)

Decompose `√n(Θ̂ − Θ) = √n(Θ̂ − Θ_M) + √n(Θ_M − Θ)`.

- **Estimation term** `√n(Θ̂ − Θ_M) →_d N(0, σ²)` via §3 (conditional on the M studies).
- **MCMC term** `Θ_M − Θ = O_P(M^{-1/2})` by a **Markov-chain CLT** for the geometrically
  ergodic hit-and-run chain (NOT the i.i.d. CLT — that was a proof bug). Hence
  `√n(Θ_M − Θ) = O_P((n/M)^{1/2})`.

**Regime.** The claim `√n(Θ̂ − Θ) →_d N(0, σ²)` centered at the true `Θ` requires the MCMC
term to vanish, i.e. `n/M → 0` ⇒ **`n = o(M)`**, i.e. `M` must grow *faster* than `n`. This
is the **opposite** of the "M = o(n)" statement currently in the proof/outline, which is the
core theory bug. Two honest options for the paper:
  (a) require `M/n → ∞` (M large relative to n) and center at `Θ`; or
  (b) keep `M` moderate and state the **conditional** result: `√n(Θ̂ − Θ_M) →_d N(0,σ²)`,
      i.e. inference is for the M-study correlation, with an explicit `O_P(M^{-1/2})` bias to `Θ`.

For the **variance report**, add the MCMC contribution (or state the regime that makes it
negligible). Practically: since sims use `M ≈ 2100 ≫ n`-per-cell effective and large `n`, the
estimation term dominates, but the code should either (i) report the conditional SE and label
it as such, or (ii) add an `O(1/M)` MCMC-variance term. Recommended: report conditional SE
(option b) and document the regime — this matches what the estimator actually computes.

**Non-degeneracy.** All of the above requires `Var_μ(Δ_S) ≥ c₀ > 0` and `Var_μ(Δ_Y) ≥ c₀ > 0`
(else `∇φ` blows up like `Var^{-3/2}`). State this as an explicit assumption, not "implicit in
bounded gradient."

---

## 5. Concrete code changes implied (for `tv_ball_correlation_IF_adaptive.R`)

1. **AIPW IF** (currently `… + μ_1 − μ_0 − Δ_m` all inside `w_i·(…)`): change the centering
   from `w_i·Δ_m` to a constant `Δ_m`. I.e. `psi = w_i·[score + μ_1 − μ_0] − Δ_m`.
2. **RCT/IW IF** (currently `w_i·(2·A·(S−m1) − 2·(1−A)·(S−m0))`): replace the `2` with
   `1/ē_1` and `1/ē_0`, where `ē_1 = mean(w_i·A)`, `ē_0 = mean(w_i·(1−A))`. (Equals the
   current code when `e≡0.5`.)
3. **Propensity clipping** in external-nuisance mode: clip `e_hat` to `[0.01, 0.99]` before
   dividing (currently only validated ∈(0,1)).
4. **Zero-denominator guards** on `ē_1, ē_0` and on the AIPW means.
5. **Variance labeling / MCMC term** (§4): report the conditional SE and document the regime,
   or add the `O(1/M)` term. Do NOT claim unconditional `Θ` normality under `M=o(n)`.
6. **`M = o(n)` vs `M/n → ∞`:** align the adaptive-M target and any assertion with §4.

The delta-method composition (§3), the analytic gradient, the sampler (fixed in Phase 1.5a),
and the AIPW **point estimator** are correct and unchanged.
