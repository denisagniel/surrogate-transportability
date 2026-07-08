---
name: canonical-pipeline-bugs
description: Correctness bugs found in the canonical estimator/proof during the 2026-07-08 audit, and the fix-first decision
metadata:
  type: project
---

The 2026-07-08 Phase-1 correctness audit (`quality_reports/2026-07-08_canonical-correctness-audit.md`) found the canonical pipeline itself is buggy — it is NOT yet a correct implementation of [[canonical-method-spec]]:

- **Sampler (CRITICAL):** `sample_tv_ball` / `find_feasible_range_tv` in `R/tv_ball_sampling.R` does NOT sample uniformly on the TV ball — it grid-quantizes the hit-and-run chord (1000-pt grid) with a hard-coded `seq(-10,10)` fallback. Biases sampled Q and ρ̂ itself.
- **AIPW (CRITICAL):** in `tv_ball_correlation_IF_adaptive.R`, the whole AIPW score (incl. mu1−mu0) is multiplied by the importance weight and plain-averaged — not doubly robust; AIPW branch doesn't self-normalize weights while the RCT branch does.
- **Variance (HIGH):** RCT/IW influence function has a spurious ×2 and omits arm-probability denominators (inconsistent with the AIPW branch); SE omits the MCMC (√M) term; `M=o(n)` never enforced.
- **Proof (3 CRITICAL):** i.i.d. CLT applied to a dependent MCMC chain; √n+√M combination never actually done (unconditional claim needs n=o(M), opposite of stated M=o(n)); correlation treated as φ:ℝ²→ℝ when it's a functional of 5 moments of μ.
- **DGP:** true ρ values (0.69,−0.88,1.0,1.0) VERIFIED correct and 0/0-PTE genuine — BUT paper Table 1 misstates simulated params (γ_A=1.0 not 0.5; non-uniform X `[.05,.25,.40,.25,.05]` not uniform; omits β_SX). Authoritative params live in `cluster/config/dgp_specifications.yaml`. Config DGP ids are 1,2,4,5 (no dgp3); slides renumber to 1–4.

**Decisions (2026-07-08):** FIX FIRST — inserted Phase 1.5 before any deletion/manuscript work. Salvage-check deprecated samplers before deleting them. DERIVE the influence functions fresh (no trusted written derivation exists) and make both code and the revised proof match it. Reported coverage numbers (93–99.9%) are suspect until re-validated after fixes.

**PHASE 1.5 DONE (2026-07-08):** all bugs fixed on branch `canonical-realignment`; reference = `inst/paper/derivation_influence_functions.md`. Sampler rewritten to analytic exact chord + validated vs rejection oracle. AIPW centering fixed (point estimator was already correct; RCT ×2 was correct only for balanced designs). Proof revised (Markov-chain CLT, n=o(M) rate, 5-moment functional) and re-audited clean; main.tex now compiles (fixed pre-existing missing `\newtheorem{assumption}`/`enumerate`/paragraph-in-proof). Calibration validated at n=3000 (SE/SD=0.97). **STILL OPEN:** full 4-DGP validation at n=10,000 must be re-run on the CLUSTER (infeasible locally ~432 days) to confirm Table-2 coverage; DGP Table-1 param mismatch fixed in Phase 4. Salvage-check found NO correct hit-and-run in deprecated code (all copies share the same grid bug) — safe to delete them all in Phase 3; a correct rejection oracle lives in explorations/tv_ball_geometry/.

Estimator dependency closure (Q5): `tv_ball_correlation_IF_adaptive` → only `sample_tv_ball` + `gradient_correlation_analytical`; nuisances fit inline. So `nuisance_estimation.R`, `propensity_score.R`, `inference_influence_function.R`, `compute_treatment_effects.R`, `discretization.R`, `analytical_variance.R` are orphaned (deletion candidates, correcting plan §2.1).
