# LOO Investigation - Conclusion

**Date:** 2026-04-02
**Status:** LOO not recommended for this application

---

## What We Tested

Implemented Leave-One-Out (LOO) estimation for the Wasserstein dual to eliminate self-influence bias.

### LOO Approach

Exclude observation j when computing expectation at X_j:
```r
# Standard: includes j
m_j = (1/n) Σ_{i=1}^n exp(-(h(X_i) + γC(X_j,X_i))/τ)

# LOO: excludes j
m_j = (1/(n-1)) Σ_{i≠j} exp(-(h(X_i) + γC(X_j,X_i))/τ)
```

---

## Results

### With Oracle Nuisances (Perfect h) ✓

LOO works **excellently** when h is known:

| d | n | Empirical Bias | LOO Bias | Improvement |
|---|---|----------------|----------|-------------|
| 4 | 500 | -2.06% | **+0.05%** | **45.8x better** |
| 5 | 500 | -2.79% | **+0.19%** | **14.4x better** |

**Conclusion:** LOO eliminates dual bias when nuisances are perfect.

### With Estimated Nuisances (Cross-Fitted h) ✗

LOO **fails** with estimated nuisances:

| d | n | Expected Coverage | LOO Coverage | Change |
|---|---|-------------------|--------------|--------|
| 4 | 500 | ~94% | 94% | No change |
| 5 | 500 | ~78% | **84%** | +6% (modest) |
| 5 | 1000 | ~92% | **82%** | **-10% (worse!)** |

**Key finding:** LOO gives **positive bias** (~+5%) instead of eliminating negative bias, and **degrades** coverage at larger sample sizes.

---

## Why LOO Fails with Cross-Fitted Nuisances

### The Interaction Problem

1. **Cross-fitting already removes self-influence for nuisances:**
   - h(X_j) is estimated WITHOUT using j's outcome data
   - Observations are already "held out" for nuisance estimation

2. **LOO for dual creates mismatch:**
   - LOO excludes h(X_j) entirely from dual computation
   - But h(X_j) was validly estimated using cross-fitting
   - Excluding it loses information

3. **Result:** Double-penalty from both cross-fitting AND LOO

### Empirical Evidence

- **Oracle h + LOO:** -2.79% → +0.19% bias ✓ (works great)
- **Cross-fitted h + LOO:** Creates +5.83% positive bias ✗ (makes things worse)
- **Coverage degrades** with larger n when using LOO (shouldn't happen)

---

## Theoretical Insight

**U-statistic theory applies when:**
- Estimating E[h(X, X')] for **independent** X and X'
- Both X and X' are "unknowns" being estimated from data

**Our setting:**
- X_j is a **fixed reference point** (covariate value)
- h(X_j) is already estimated via cross-fitting (without j's outcomes)
- Adding LOO for the dual creates **redundant** hold-out

**Conclusion:** Cross-fitting + LOO is "double cross-validation" which over-corrects.

---

## Final Recommendation

### ✅ DO: Use Larger Sample Sizes

**Validated solution:**

| d | Required n | Coverage |
|---|-----------|----------|
| ≤3 | 500 | 94-98% |
| 4 | 1000 | 98% |
| 5 | 1000 | 92-95% |

**Rule of thumb:** n ≥ 200d

### ❌ DON'T: Use LOO with Cross-Fitted Nuisances

LOO is theoretically sound for oracle nuisances but empirically fails when combined with cross-fitting.

---

## Alternative Solutions That Work

1. **Increase n to 1000:** Works well for d≤5 ✓
2. **Use flexible models (GAM/RF):** Reduces nuisance bias ✓
3. **Both:** Best performance ✓

---

## What We Learned

1. **Dual bias is real:** Contributes 30% of total bias for d≥4
2. **LOO eliminates it... with oracle h:** -2.79% → +0.19% bias
3. **But fails with estimated h:** Creates +5.83% positive bias
4. **Cross-fitting ≠ standard estimation:** Different hold-out structure
5. **Simpler solution works:** Just use n≥1000

---

## Files Created

1. `test_improved_dual_estimation.R` - LOO validation with oracle h
2. `test_loo_implementation.R` - LOO with estimated h (showed problems)
3. `LOO_THEORETICAL_JUSTIFICATION.md` - Theory (valid for oracle case)
4. `check_inner_if_term.md` - Implementation considerations

**Note:** LOO implementation was reverted after testing showed it doesn't work with cross-fitted nuisances.

---

## Bottom Line

**LOO is not the solution for our problem.** The simpler approach—using larger sample sizes (n≥1000 for d≥4)—works better and is empirically validated.

The investigation was valuable because it:
- Confirmed dual bias is a real issue (30% of total)
- Showed why naive LOO doesn't work here
- Validated that n≥1000 is the right solution
