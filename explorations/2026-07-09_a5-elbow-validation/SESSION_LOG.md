# Session log — A5 elbow validation

## 2026-07-09 — kickoff

Goal: empirically validate Theorem A + the A5 elbow (`s_S+s_Y>d/2`) for the
newly-promoted general theory. Plan approved
(`~/.claude/plans/precious-tickling-pebble.md`). Two stages: (1) isolate the elbow
with a fixed Dirac kernel + fixed-smoothness sieve CATE learner; (2) end-to-end Θ
coverage via discretize-to-cells geometry + cross-fit grf.

Decisions locked at plan time:
- Stage 1 learner = fixed-smoothness sieve (grf would mask the elbow); grf only in Stage 2.
- Local-first (R=200); wire SLURM only if the local signal is clean.
- Dirac kernel first (sharp elbow), then smooth kernel (relaxed).

Env: R 4.5.1; grf, mgcv, ranger, randplot all available.

## 2026-07-09 — threshold-gap finding (pre-build)

Rate analysis (confirmed numerically) surfaced a real gap between what the paper
claims and what the estimator attains:
- The A5 elbow `s_S+s_Y>d/2` is the functional's information-theoretic limit,
  attained ONLY by higher-order-IF (HOIF) estimators (this is what the Robins/
  Kennedy citations establish).
- Theorem A builds a FIRST-ORDER one-step estimator. Its C-S remainder
  `‖τ̂_S−τ_S‖·‖τ̂_Y−τ_Y‖` is `o(n^{-1/2})` iff `s_S/(2s_S+d)+s_Y/(2s_Y+d)>1/2`,
  i.e. (equal case) `s_S+s_Y>d` — NOT `>d/2`.
- ⇒ Lemma A5 / Theorem A / the A5 assumption conflate the two. The auditor's
  item-4 PASS checked the remainder FORM + Cauchy-Schwarz but accepted the
  `iff s>d/2` inference, which does not follow for a first-order estimator.

User decision: **validate the first-order boundary (`s_S+s_Y>d`) and fix the
paper** (state `>d` for the one-step estimator; note `>d/2` is the HOIF limit).
Revised Stage 1 design points to straddle BOTH boundaries, with G_gap sitting in
the gap (`d/2 < sum=0.8 < d=1`) as the empirical evidence. Paper fix to follow
after the sim confirms the gap.

## 2026-07-09 — estimator built + smoke-tested; moved to O2

Built the Stage 1 pieces: `R/dgp_smooth.R` (cosine-series CATE, closed-form psi
truth, validated vs MC), `R/pseudo_outcome.R` (AIPW pseudo-outcome + oracle-rate
cosine sieve, c_J=2.0), `R/bilinear_estimator.R` (one-step 5-fold cross-fit
debiased + plug-in comparator + IF-SE), `R/run_one_stage1.R`, `R/kernel_smooth.R`
(smooth-kernel variant; quadrature-truth needs a finer grid — Nyquist aliasing at
ngrid=400 for J=200, TODO Task 27).

Smoke tests (scripts 00/01/01b): pseudo-outcome mean=ATE and E[xi|X]=tau ✓;
estimator≈truth ✓; SE calibration ~1 at A_above ✓; debiasing removes plug-in bias
on the DIAGONAL E[tau^2] (plug-in bias strictly +, grows with roughness) ✓.

**Memory incident:** an R=200 mclapply run (9 workers x 16000x200 matrices) hogged
laptop RAM; user flagged it, I killed both bg jobs (TaskStop). The R=5 probe that
had already written stage1_results.rds is too noisy to conclude (coverage in 0.2
steps) but directionally right: B_below broken, A_above/D2_above converging.

**Decision: move to O2.** Built full SLURM infra in slurm/ mirroring
canonical-validation (run_replication.R, array.slurm, submit.sh, combine.R,
monitor.sh, clean.sh, profile_timing.R, README_O2.md). Fixed a grid double-count
(estimator was a grid dim but run_one emits both). Grid = 90 configs x 1000 reps
= 90000 units; sizing.env: 60 tasks x 1500 reps/job, 1.5h walltime, 4G. Validated
the exact cluster code path serially (task 1 + mid-grid task 40): correct schema,
atomic write, idempotent skip, submit/combine code-hash match. Ready to git push +
sbatch on O2. Local heavy runs avoided from here on.
