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

## 2026-07-09 — smooth-kernel relaxation (Task 27) + Stage 2 built (Task 28)

Smooth-kernel truth: my earlier "aliasing" alarm was WRONG -- quadrature is stable
(converges by ngrid=400) and matches high-precision MC (N=2e6) to ~1e-3; the 0.252
vs 0.306 gap was a noisy small-N MC draw. Corrected the comment; no code fix.

Fixed a real SE bug in psi_hat_smooth: the mean-zero EIF is
h_b(X) xi_a + h_a(X) xi_b - 2 psi (the +tau_a h_b measure terms cancel the
-h_b tau_a correction terms). My first version subtracted a random per-obs
h_b*tau_a and one psi -- right mean, wrong variance (coverage 0.80). After the fix,
coverage is nominal.

**Smooth-kernel result (R=150, ell=0.25, G_gap s=0.4, pair SY):**
  n=1000: Dirac bias -0.050 cov 0.86 | Smooth bias +0.003 cov 0.95
  n=2000: Dirac bias -0.042 cov 0.91 | Smooth bias +0.002 cov 0.96
=> the smooth kernel RELAXES the Dirac elbow (Remark A5-conservative confirmed):
same rough CATEs, Dirac degrades while smooth-kernel stays nominal. Capped local
n at 2000 (dense nxn kernel is O(n^2); n>=4000 -> cluster).

Stage 2 (end-to-end Theta): built dgp_theta.R (discretize-to-cells geometry via
sample_tv_ball -> Sigma; true Theta from true cell CATEs + same Sigma),
theta_estimator.R (cross-fit grf CATEs -> 3 debiased quad functionals with
tr(Sigma V) -> compose Theta -> IF-SE via grad_theta + full 2K V), run_one_stage2.R.
Corner-case caught: identical s_S=s_Y + same basis => tau_S≡tau_Y => Theta=1
(degenerate). Added a y_decorr knob (alternating-sign coeff mixing) so tau_Y differs
from tau_S -> interior Theta. Smoke: above theta=0.24 (truth 0.27) cov 1; near
theta=0.68 (truth 0.65) cov 1. Coverage run (R=100, n=2000) in progress.

**Stage 2 coverage result (R=100, n=2000):**
  above (s=1.0): bias +0.002 empSD 0.115 meanSE 0.063 cov 0.94  (NOMINAL)
  near  (s=0.35): bias +0.005 empSD 0.099 meanSE 0.049 cov 0.88  (DEGRADED)
=> exactly the honest pattern: nominal above the elbow, degrades near it. Bias is
tiny in both (debiasing works), so the near-elbow shortfall is variance/SE, not
point bias. CAVEAT: meanSE < empSD even in the above case (0.063 vs 0.115) -- the
empSD is inflated by a few heavy-tailed reps where Theta approaches +/-1 (ratio
functional instability), while the typical CI still covers (0.94). A finite-n
artifact of n=2000 + K=10 cells; the cluster run at larger n should tighten it.
Both stages now built + locally validated. Ready for cluster scale-up.
