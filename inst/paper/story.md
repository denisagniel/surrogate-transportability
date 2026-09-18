# Paper Story — `Evaluating Surrogate Transportability via Local Geometric Analysis`

**Instance path:** `inst/paper/story.md`
**Governed by:** `.claude/rules/paper-protocol.md`
**Status:** draft as of 2026-09-18

## Framing

A surrogate marker earns its keep only if what it says in the study where it was validated is
still true in the next study, where the population, the covariate distribution, or the pattern of
effect modification will be different. Every established validation criterion measures something
else. Prentice's criteria, the proportion of treatment effect, within-study correlation, principal
stratification, and causal mediation are all functionals of the *observed* study's distribution:
they quantify how tightly surrogate and outcome are coupled in the data at hand, and then assume
that coupling travels. PTE assumes the mediated share is stable; mediation assumes the pathway
structure persists; principal stratification assumes the stratum definitions carry over. The one
family of methods that does not assume transportability — trial-level meta-analysis — measures it
directly by correlating surrogate and outcome treatment effects across studies that actually
happened, which is exactly why it is unavailable when it is most wanted: it needs on the order of
five to ten completed trials that measured both endpoints, which novel treatments and novel
surrogates by definition do not have. The causal transportability literature formalizes *when* a
causal quantity can be carried between populations, but its object is identification from
multiple heterogeneous sources, not estimation of a transportability quantity from one study.
Parast's 2025 tutorial names the transport of surrogate knowledge from one study to another as an
open problem in the field.

The gap is therefore not a missing estimator but a missing estimand: with a single study, there is
no stated quantity that means "this surrogate transports," and so nothing to be $\sqrt n$-consistent
for. Any candidate has to make the future study itself the random object, which forces two
commitments the within-study literature never has to make — which future studies count as
plausible, and how the plausible ones are weighted — and then has to survive the fact that the data
contain no observations from any of them. That combination is what is unsolved: not surrogate
validation, and not transportability, but a transportability *functional* that a single study
identifies and that admits ordinary influence-function inference, with the class of admissible
futures written down as part of the estimand rather than smuggled in as an assumption.

## Contribution

This paper makes the future study a draw from a probability measure supported on a *local
geometry* — a ball of radius $\lambda$ in total variation (or $\chi^2$, or $L_2$) around the
observed study distribution — so that a surrogate-quality functional of the across-study
distribution of treatment effects, primarily the correlation of the surrogate and outcome effects
across studies, becomes a well-defined estimand identified by the current study alone, with the
class of admissible futures and their weighting stated explicitly in $\lambda$ and in the choice of
distance. It then delivers $\sqrt n$-consistent, asymptotically normal inference for that estimand
via hit-and-run sampling of the geometry, deterministic reweighting of the observed data inside
each sampled study, and a two-stage influence-function argument — plus closed forms showing that in
two of the three $\lambda$ regimes the estimand collapses to an object a stratum-level
meta-analysis would have reported.

## Scope boundary

- **Only compositional futures.** Future studies are restricted to reweightings of the observed
  covariate support ($\mathcal{Q} \ll \mathbb{P}_0$), and the reweighting is a function of $X$
  alone, so the conditional average treatment effects given $X$ are frozen across studies. Studies
  that differ for reasons other than covariate composition — unmeasured study-level factors that
  change the conditional effects, or genuinely new covariate values — are outside the estimand.
  The paper states this as a scope declaration under a definitional reading and as an untestable
  causal assumption under an interpretive one; it does not claim to test or relax it from one study.
- **Conditional on the sampled geometry.** Inference treats the Monte Carlo draws (equivalently,
  the reweighting-covariance kernel) as fixed inputs, and reported intervals target the estimand at
  the empirical Monte Carlo measure. A fully unconditional theory that also differentiates the
  geometry's own dependence on the observed distribution is deferred.
- **Finite or discretized covariates for the implemented theory.** The computable machinery, the
  software, and the numerical studies all live on a finite covariate space; continuous covariates
  must be discretized, and asymptotics with growing support are not pursued.
- **The general layer is theory only.** The extension to continuous covariates and to arbitrary
  smooth functionals of the across-study effect distribution is proved but not implemented and not
  exercised by the simulation study.
- **No applied data analysis.** Evidence is analytic plus simulation; there is no worked
  application to real trial data, and the finite-sample performance table is reserved for output
  from a cluster re-validation of the corrected estimator rather than reported from the earlier run.
- **Left open.** Data-driven or decision-theoretic choice of $\lambda$; non-smooth functionals;
  time-to-event and longitudinal surrogates; small-sample behavior, alternative geometries, and
  $\lambda$-profile sensitivity, which are named as in-progress rather than settled.

## Major claims

- **S1:** Whether a surrogate transports is not a property of the study you have — it is a property
  of a *distribution over the studies you might get next*. Making that distribution explicit, as a
  uniform draw from a ball of stated radius around the observed study, converts an assumption the
  existing criteria leave implicit into a written part of the estimand, and makes the resulting
  quantity identifiable from a single study. The radius plays the role of a design parameter, like
  a significance level: it is chosen and reported, not estimated.

- **S2:** That estimand admits ordinary root-$n$ inference. The estimator — sample correlation of
  the effect pairs across sampled future studies, each pair obtained by deterministically
  reweighting the observed data rather than resampling it — is root-$n$ consistent and
  asymptotically normal, with an influence function assembled in two stages: one for estimating the
  treatment effects inside each sampled study, one for the smooth aggregation of those effects into
  the correlation. Both sources of error are carried explicitly, the sampling error in the data and
  the Monte Carlo error in the number of sampled studies, rather than one being assumed away; the
  unconditional statement requires the number of sampled studies to grow faster than the sample.

- **S3:** The same machinery covers observational studies, and the trial case is a consequence of
  it rather than a separate derivation. With cross-fitted augmented inverse probability weighting,
  the reweighted estimating equation remains orthogonal to the nuisance functions, so first-order
  error in the propensity score and outcome regressions does not propagate into the transportability
  estimate; the randomized-trial, importance-weighting estimator falls out as an exact corollary of
  the observational theorem.

- **S4:** For small enough radii the construction has a closed form that removes the machinery
  entirely. So long as the radius is small enough that no covariate stratum can be reweighted to
  zero mass, the across-study correlation equals — exactly, and independently of both the radius and
  the observed study's covariate composition — the ordinary unweighted correlation of the
  conditional average treatment effects across covariate strata. That is precisely the number a
  meta-analysis would report if each covariate stratum were treated as its own study, so in this
  regime the construction is a rigorous single-study stand-in for an analysis that normally requires
  many studies. The identical closed form reappears at the opposite extreme, once the ball covers
  the whole simplex, by a separate symmetry argument — so the reduction is not an artifact of small
  radii, and only the intermediate range genuinely depends on the radius and on composition.

- **S5:** Where the closed form ends, its failure is predictable in advance and for free. The rate
  *and direction* at which the correlation first departs from its interior value, as the radius
  grows past the smallest stratum's mass, is exactly the classical influence function of the Pearson
  correlation evaluated at that smallest stratum's standardized effects. Whether widening the class
  of admissible futures will help or hurt the assessment therefore reduces to whether the rarest
  covariate stratum is a concordant or discordant contributor — computable from the observed
  distribution and the two effect functions alone, before any Monte Carlo sampling is run.

- **S6:** The whole family of transportability functionals turns out to rest on one statistical
  object. Every load-bearing moment — means, variances, and the cross-moment, hence correlation,
  variance explained, mean squared prediction error, and concordance alike — is a linear or bilinear
  functional of the two conditional-effect surfaces against a fixed covariance kernel induced by the
  reweighting. Estimability of the whole framework therefore inherits the known theory for quadratic
  functionals of a regression function: with continuous covariates there is a smoothness threshold
  below which no root-$n$, asymptotically normal estimator exists, and what removes that threshold
  in the implemented case is the kernel having finite rank — not the covariate space being finite
  per se.

- **S7:** Transportability and mediation are different questions and the numerical studies show them
  disagreeing in three distinct ways, each a case where the mediation-based answer is misleading or
  simply unavailable. A surrogate can post a middling proportion of treatment effect — nothing that
  would disqualify it — while its across-study correlation is strongly *negative*, because effect
  modification acts in opposite directions on surrogate and outcome. It can post a low proportion of
  treatment effect and still transport nearly perfectly, because weak mediation coexists with effect
  modification that scales both effects together. And the proportion of treatment effect can be
  undefined outright, when the overall outcome effect is near zero, while the across-study
  correlation remains well defined and near one.
