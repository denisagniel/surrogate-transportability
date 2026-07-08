# SUMMARY (Draft for Biometrika-style paper)

**Word count target:** 200 words max

---

Surrogate endpoints validated in one study may not predict treatment effects reliably in future studies with different populations. Existing methods—mediation analysis, principal stratification, and proportion of treatment effect—evaluate surrogates within a single study and implicitly assume transportability. Meta-analysis directly assesses cross-study variation but requires multiple completed trials. We propose a framework for evaluating surrogate transportability from a single study by modeling the distribution of hypothetical future studies as random probability measures within a local geometry around the observed study. We sample future study distributions via Markov chain Monte Carlo, compute treatment effects using importance weighting, and estimate functionals such as the correlation of treatment effects across sampled studies. Under regularity conditions, our estimators are root-n consistent and asymptotically normal. The framework extends to observational studies via cross-fitted augmented inverse probability weighting, where Neyman orthogonality under reweighting eliminates first-order nuisance bias. Simulations demonstrate correct coverage and reveal cases where proportion of treatment effect misleads—including opposite-signed effect modification, weak mediation with perfect transportability, and settings where proportion of treatment effect is undefined. The approach provides a principled basis for assessing surrogate quality without requiring multiple studies.

---

**Word count:** 181 words

**Key elements included:**
- Problem: surrogates may not transport
- Gap: existing methods assume transportability
- Method: local geometry + MCMC sampling + importance weighting
- Theory: root-n consistency, asymptotic normality, extension to observational
- Results: correct coverage, identifies PTE failures
- Impact: single-study evaluation

**Notes:**
- No citations (standard for Biometrika summaries)
- Formal mathematical language
- Emphasizes theory (root-n, asymptotic normality)
- Mentions key technical innovations (AIPW, Neyman orthogonality)
- Highlights when PTE misleads (core narrative)

**Questions for approval:**
1. Is the emphasis correct (theory-first, then practical implications)?
2. Should we mention specific geometries (TV ball) or keep general?
3. Should we emphasize correlation functional more explicitly?
4. Any key points missing?
