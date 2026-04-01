# Nuisance Term Derivation: Concordance vs Nested

## Case 1: Concordance E[h(X)] with Estimated h = τ_S(X) × τ_Y(X)

**Estimand:**
```
Ψ = E[h(X)] = E[τ_S(X) × τ_Y(X)]
```

**Empirical estimator:**
```
Ψ̂ = (1/n) Σᵢ h(Xᵢ) = (1/n) Σᵢ τ̂_S(Xᵢ) × τ̂_Y(Xᵢ)
```

**IF when h is estimated:**

For a functional Ψ[P, θ] where θ are nuisance parameters:
```
IF(O) = [∂Ψ/∂P](O) + E_X[∂Ψ/∂θ(X)] × IF_θ(O)
```

For concordance:
- ∂Ψ/∂P at observation i: h(Xᵢ) - E[h(X)]
- ∂Ψ/∂τ_S(Xᵢ): ∂/∂τ_S(Xᵢ) [(1/n) Σⱼ τ_S(Xⱼ) × τ_Y(Xⱼ)] = (1/n) × τ_Y(Xᵢ)
- ∂Ψ/∂τ_Y(Xᵢ): ∂/∂τ_Y(Xᵢ) [(1/n) Σⱼ τ_S(Xⱼ) × τ_Y(Xⱼ)] = (1/n) × τ_S(Xᵢ)

Wait, but the working formula doesn't have explicit (1/n) factors. Let me reconsider.

Actually, for the IF of E[h(X)] where h(X) = f(τ_S(X), τ_Y(X)):

```
IF(O) = h(X) - E[h(X)] + ∂h(X)/∂τ_S(X) × IF_τ_S(O) + ∂h(X)/∂τ_Y(X) × IF_τ_Y(O)
```

This is evaluated at observation i, so:
```
IF(Oᵢ) = h(Xᵢ) - Ψ̂ + τ_Y(Xᵢ) × IF_τ_S(Oᵢ) + τ_S(Xᵢ) × IF_τ_Y(Oᵢ)
```

**Key insight:** The derivatives ∂h(Xᵢ)/∂τ_S(Xᵢ) and ∂h(Xᵢ)/∂τ_Y(Xᵢ) are LOCAL derivatives at point i, not global derivatives of Ψ.

---

## Case 2: Nested E_X[φ(X)] with Estimated h in φ

**Estimand:**
```
Ψ = E_X[φ(X)] where φ(X) = -τ log m(X)
m(X) = E_{X'}[exp(-(h(X') + γC(X,X'))/τ)]
```

**Empirical estimator:**
```
Ψ̂ = (1/n) Σⱼ φ(Xⱼ)
φ(Xⱼ) = -τ log m̂(Xⱼ)
m̂(Xⱼ) = (1/n) Σᵢ g(Xⱼ, Xᵢ)
where g(x, x') = exp(-(h(x') + γC(x,x'))/τ)
```

**IF structure (from NESTED_EXPECTATION_EIF_CORRECT.md):**

When h is FIXED (known):
```
IF(Oₖ) = [φ(Xₖ) - Ψ̂] + [-τ Σⱼ (g(Xⱼ,Xₖ)/m̂(Xⱼ))/n + τ]
       = [outer term] + [inner term]
```

When h is ESTIMATED, we need to add nuisance correction. The question is: **what form does it take?**

---

## Derivation of Nuisance Term for Nested Case

When h(Xₖ) changes by δ, how does Ψ̂ change?

Ψ̂ = (1/n) Σⱼ φ(Xⱼ) where φ(Xⱼ) = -τ log m̂(Xⱼ)

m̂(Xⱼ) = (1/n) Σᵢ g(Xⱼ, Xᵢ) where g(Xⱼ, Xᵢ) depends on h(Xᵢ)

So h(Xₖ) affects m̂(Xⱼ) for ALL j through the term g(Xⱼ, Xₖ).

**Step 1:** Derivative of g with respect to h(Xₖ):
```
∂g(Xⱼ, Xₖ)/∂h(Xₖ) = ∂/∂h(Xₖ) [exp(-(h(Xₖ) + γC(Xⱼ,Xₖ))/τ)]
                     = (-1/τ) × g(Xⱼ, Xₖ)
```

**Step 2:** Derivative of m̂(Xⱼ) with respect to h(Xₖ):
```
∂m̂(Xⱼ)/∂h(Xₖ) = (1/n) × ∂g(Xⱼ, Xₖ)/∂h(Xₖ)
                  = (1/n) × (-1/τ) × g(Xⱼ, Xₖ)
```

**Step 3:** Derivative of φ(Xⱼ) with respect to h(Xₖ):
```
∂φ(Xⱼ)/∂h(Xₖ) = ∂/∂h(Xₖ) [-τ log m̂(Xⱼ)]
                = -τ × (1/m̂(Xⱼ)) × ∂m̂(Xⱼ)/∂h(Xₖ)
                = -τ × (1/m̂(Xⱼ)) × (1/n) × (-1/τ) × g(Xⱼ, Xₖ)
                = (1/n) × g(Xⱼ, Xₖ) / m̂(Xⱼ)
                = (1/n) × W[k,j]   where W[k,j] = softmax weight
```

**Step 4:** Derivative of Ψ̂ with respect to h(Xₖ):
```
∂Ψ̂/∂h(Xₖ) = ∂/∂h(Xₖ) [(1/n) Σⱼ φ(Xⱼ)]
            = (1/n) Σⱼ ∂φ(Xⱼ)/∂h(Xₖ)
            = (1/n) Σⱼ [(1/n) × W[k,j]]
            = (1/n²) Σⱼ W[k,j]
```

**Step 5:** Nuisance term in IF:
```
Nuisance term = ∂Ψ̂/∂h(Xₖ) × IF_h(Xₖ)
              = (1/n²) × [Σⱼ W[k,j]] × IF_h(Xₖ)
```

---

## Comparison: Current Code vs Correct Formula

**Current code (test_nested_crossfit_linear.R, line 136):**
```r
term3 <- (1/n) * sum(W[k, ]) * IF_h_k
```

**Correct formula (derived above):**
```r
term3 <- (1/n^2) * sum(W[k, ]) * IF_h_k
# OR equivalently:
term3 <- mean(W[k, ]) * IF_h_k / n
```

**The error:** Missing a factor of **(1/n)**.

---

## Why This Explains the Failure

- Current code: term3 is **n times too large**
- If IF has three terms: IF = term1 + term2 + term3_wrong
- term3_wrong = n × term3_correct
- This inflates the IF values, which inflates Var(IF)
- But we're seeing Var(IF) is **too small** (ratio 0.36-0.42)

**Wait, this doesn't match!** If term3 is too large, variance should be too large, not too small.

Let me reconsider the sign...

Actually, looking at the concordance formula:
```
IF = h(Xᵢ) - Ψ̂ + τ_Y(Xᵢ) × IF_τ_S(Oᵢ) + τ_S(Xᵢ) × IF_τ_Y(Oᵢ)
```

The nuisance terms are ADDED. They contribute positively to the IF variance.

For nested case, the nuisance term should also be added (assuming the derivation is correct).

**Hypothesis:** Maybe the nuisance term needs a DIFFERENT scaling entirely. Let me look at the concordance case more carefully.
