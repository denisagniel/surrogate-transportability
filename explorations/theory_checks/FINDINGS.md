# Numeric checks of the general theory (Corollary A10 collapse)

**2026-07-09.** Sanity checks that the general bilinear-functional EIF, specialized
to finite X (C→Σ), reproduces the finite-support objects.

## Results
- **Structural collapse holds:** with C→Σ and per-cell AIPW IF, the general
  χ_aa = 2·IF'(Στ) − τ'Στ reduces to the finite-support influence function; the
  population plug-in bias of τ'Στ equals tr(ΣV) as the general χ predicts (bias is
  O(1/n), so only visibly nonzero at small n; at n=4000 it is ~0, consistent).
- **Mean-zero bookkeeping (FLAG for auditor):** numerically mean(χ_aa) = −τ'Στ
  EXACTLY (−0.0252). The stochastic part 2·IF'(Στ) is mean-zero (E[IF]=0); the
  −Θ_ab constant in the proof's eq (chi-ab) makes the displayed χ_ab NOT mean-zero.
  The mean-zero EIF is (χ_ab + Θ_ab); the −Θ_ab term belongs with the plug-in in
  the one-step estimator Θ̂ = plug-in + P_n·(mean-zero score), NOT inside the score.
  → The proof's Lemma A3 Step 4 says the bracketed part is mean-zero (correct) but
  then writes χ_ab with −Θ_ab included and calls it "the influence function"; this
  is a centering-convention inconsistency to reconcile. Structurally harmless (the
  one-step estimator is unaffected: plug-in carries +Θ_ab, score carries −Θ_ab,
  they cancel) but the STATEMENT should be made consistent. Flagged for proof-auditor.

Scripts: corollary_A10_check.R, corollary_A10_meanzero_check.R.
