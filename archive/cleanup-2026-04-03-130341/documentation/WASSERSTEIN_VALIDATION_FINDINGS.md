# Wasserstein Implementation - Critical Validation Findings

**Date:** 2026-03-25
**Status:** ⚠️ CRITICAL ISSUE FOUND - DO NOT COMMIT

---

## Executive Summary

Pre-commit validation revealed a **fundamental mathematical issue** with the Wasserstein ball minimax implementation:

**The approximation W₂²(q, p₀) ≈ (q-p₀)'C(q-p₀) is invalid because the cost matrix C is not positive semi-definite.**

This causes:
- All W₂ distances to be computed as 0
- No exploration of the Wasserstein ball
- Minimax estimates equivalent to just using p₀ (no perturbation)

---

## Root Cause Analysis

### The Problem

The cost matrix is defined as:
```
C[i,j] = ||centroid_i - centroid_j||²
```

Where centroids are mean covariate vectors for each type.

**Issue**: This matrix is **not guaranteed to be positive semi-definite (PSD)**.

### Evidence

Testing on actual data shows:
```
Cost matrix eigenvalues:
  [1]  24.21  (positive)
  [2]   0.00  (zero)
  [3]   0.00  (zero)
  [4]  -1.36  (NEGATIVE!)
  [5]  -9.44  (NEGATIVE!)
```

Consequence:
```
(q-p₀)'C(q-p₀) = -0.081  (negative!)
W₂ = sqrt(max(0, -0.081)) = 0  (truncated to zero)
```

### Why This Happens

A matrix of pairwise squared distances is PSD **only** when the points can be isometrically embedded in Euclidean space. This is not always true for:
- Arbitrary sets of points in ℝᵖ
- Centroids from clustering algorithms
- Type representatives from discretization

The quadratic approximation (q-p₀)'C(q-p₀) assumes C is a **kernel matrix** (Gram matrix), which requires PSD property.

---

## Impact Assessment

### What Works
✅ Unit tests pass (194/194) - they test code structure, not mathematical correctness
✅ API is well-designed and consistent
✅ Documentation is complete
✅ Code is clean and maintainable

### What Doesn't Work
❌ W₂ distance always returns 0
❌ No exploration of Wasserstein ball
❌ Perturbations are trivial (q ≈ p₀)
❌ Minimax estimates are meaningless

### Validation Results
- **Test 1** (Basic functionality): ✓ PASS (runs without error)
- **Test 2** (Constraint satisfaction): ✓ PASS (trivially - all distances are 0)
- **Test 3** (W vs TV comparison): ✓ PASS (runs, but W estimates are wrong)
- **Tests 4-8**: ✓ PASS (all run, but estimates are incorrect)

**Critical**: All tests pass structurally, but the **mathematical foundation is broken**.

---

## Why Tests Didn't Catch This

1. **Constraint satisfaction test** passes because W₂ = 0 ≤ λ_W (vacuous truth)
2. **No ground truth validation** - we didn't compare to true W₂ distances
3. **Comparison with TV** shows differences, but doesn't validate correctness
4. **Edge cases** test code paths, not mathematical validity

---

## The Correct Wasserstein Distance

To compute W₂ correctly, we need to solve the optimal transport problem:

```
W₂²(q, p₀) = min_{π} Σᵢⱼ πᵢⱼ Cᵢⱼ

subject to:
  Σⱼ πᵢⱼ = p₀ᵢ  (marginal constraint)
  Σᵢ πᵢⱼ = qⱼ   (marginal constraint)
  πᵢⱼ ≥ 0      (non-negativity)
```

This is a **linear programming problem**. Solutions:

1. **Exact**: Use LP solver (e.g., `lpSolve`, `Rglpk`) - slow for M=2000 iterations
2. **Approximate**: Sinkhorn iterations with entropic regularization - faster but approximate
3. **Package**: Use `transport` package - well-tested but adds dependency

---

## Options Going Forward

### Option 1: Fix with Proper OT Solver (Recommended for correctness)

**Approach**: Replace approximation with actual OT solver

**Pros:**
- Mathematically correct
- Publications use correct method
- Can validate properly

**Cons:**
- Slower (LP solve for each sample)
- Adds dependencies (`transport` or `lpSolve`)
- Significant rework needed

**Timeline**: 3-5 days to implement and validate

### Option 2: Use Sinkhorn Approximation

**Approach**: Entropic-regularized OT via Sinkhorn iterations

**Pros:**
- Much faster than exact LP
- Good approximation for small ε
- Pure R implementation possible

**Cons:**
- Still approximate (but better than current)
- Needs tuning of regularization parameter ε
- More complex implementation

**Timeline**: 2-3 days

### Option 3: Abandon Wasserstein, Use TV-Ball (Pragmatic)

**Approach**: Remove Wasserstein implementation, document why

**Pros:**
- TV-ball approach is validated and working
- No additional work needed
- Can focus on comparative studies with working method

**Cons:**
- Wastes implementation effort
- Misses opportunity for geometrically meaningful bounds
- Academic interest in Wasserstein for DRO

**Timeline**: Immediate

### Option 4: Hybrid Approach (Research Direction)

**Approach**: Use different geometry that's computationally tractable

**Examples:**
- f-divergences (KL, χ²) with closed-form minimax
- Moment constraints instead of Wasserstein
- φ-divergence balls

**Pros:**
- Could be novel contribution
- Computational efficiency
- Mathematical rigor

**Cons:**
- Research project, not implementation fix
- Uncertain timeline
- May not provide desired interpretation

**Timeline**: Unknown (research)

---

## Recommendation

**For immediate purposes (paper submission deadline):**

1. **Do not commit** the Wasserstein implementation as-is
2. **Use TV-ball approach** which is validated and working
3. **Document** Wasserstein as future work in paper

**For longer-term (post-submission):**

1. **Implement proper OT solver** using `transport` package
2. **Validate carefully** against known ground truth
3. **Publish as extension** or methodological paper

---

## Lessons Learned

### Testing Best Practices

1. **Validate against ground truth**, not just structural tests
2. **Check mathematical properties** (PSD matrices, distance axioms)
3. **Test on simple cases** where answer is known
4. **Compare to reference implementations** (e.g., `transport` package)

### Implementation Best Practices

1. **Literature review** of existing implementations
2. **Prototype on toy examples** before full implementation
3. **Mathematical proofs** before coding
4. **Expert review** of key algorithms

---

## Next Steps

**Immediate (pre-commit):**
- [ ] Decide on Option 1, 2, or 3
- [ ] If Option 3: Remove Wasserstein code, update session notes
- [ ] If Option 1/2: Implement proper OT, re-validate
- [ ] Update validation scripts to catch this issue

**If proceeding with fix:**
- [ ] Implement proper W₂ computation
- [ ] Add ground truth tests
- [ ] Validate against `transport` package
- [ ] Re-run full validation suite
- [ ] Document computational cost trade-offs

---

## Conclusion

This validation process **successfully caught a critical bug** before it was committed to the codebase. The Wasserstein implementation has:

✅ Clean, well-documented code
✅ Consistent API design
✅ Comprehensive testing structure
❌ **Fundamentally broken mathematics**

The proper fix requires either:
- Implementing actual optimal transport (slow but correct)
- Pivoting to a different approach (pragmatic)

**The validation process worked as intended** by catching this before it entered production code.
