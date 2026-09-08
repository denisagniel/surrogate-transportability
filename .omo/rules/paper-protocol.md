---
paths:
  - "manuscript/**"
  - "inst/paper/**"
  - "latex/**/*.tex"
  - "**/*manuscript*.tex"
---

<!-- GENERATED from .claude/rules/paper-protocol.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Paper Protocol

## Purpose

The written spec that both paper **writers** and paper **reviewers** read, so that
"good paper" means the same thing on both sides. This is what makes the proof pair work:
`proof-writer` and `proof-auditor` are not independently excellent, they share
`proof-protocol.md`. Papers had no equivalent.

Scope: manuscripts for methods and applied statistics papers. Proofs inside a manuscript
are governed by [proof-protocol.md](proof-protocol.md), which triggers on the same
`latex/**/*.tex` glob — both apply, and neither overrides the other.

## Worked examples cite one manuscript

Where a rule below names a line number as `M:NN`, `M` is
`rprojects/opioids/cantor-taylor_correcting-moud/paper2-methods/manuscript/main.tex`
(775 lines), used because it exhibits both the defects and the exemplary passage. Every
`M:NN` in this file was verified against that file on 2026-09-05. **If you cite a new line
number here, open the file first** — two of the original citations, inherited from a plan
document, did not survive checking.

## The measurement rule — read before adding anything here

**Every rule in this file was measured against real published papers, and any rule added
later must be too.** The instrument is
`explorations/2026-09-04_paper-protocol-corpus-study/`: an 875-paper sampling frame
(`frame.json`, arXiv `jr:` prefix, confirmed `journal_ref`) with 206 measured across seven
venues (`rows.json`), reported by `summarize.py`.

This is not ceremony. Nine conventions were proposed for this file from a reading of four
manuscripts. **Measurement refuted three of them outright** — including a rule against
roadmap paragraphs, which turned out to be a majority practice — and forced a fourth to be
reframed. A protocol built on unmeasured intuition would have made three manuscripts worse
in the name of rigor.

**Two things a new rule must clear:**

1. **A frequency in the corpus.** If it cannot be measured, it is a preference, not a rule.
2. **A spread check.** `summarize.py` prints the max venue-level gap per convention. **A
   gap ≥ 40 points means a pooled frequency describes no actual venue and MUST NOT be
   prescribed** — at any level of aggregation, until you have shown that some grouping
   actually explains the spread (see next section).

## Authored writing commitments — the one exemption to the measurement rule

The section above governs **conventions**: claims about what published papers do. It does
not govern the author's own standing commitments, which are normative by authorship rather
than by frequency. The measurement rule exists to stop an agent *inventing* a convention
and enforcing it as if the field agreed; it was never meant to let a corpus overrule the
author. Both are cases of not making things up.

These were promoted here on 2026-09-07 from the author's research identity document
(§9 "Design Invariants", **Writing invariants**), which ~16 projects hold as a real file
under varying section numbering. They are restated here, in a framework-owned file, so that
no rule depends on a project-local document's structure. See
[meta-governance.md](meta-governance.md) for why that is now forbidden.

**Promoted, because they are not already covered elsewhere:**

- **Clarity is the north star.** Where rigor and clarity appear to conflict, the resolution
  is almost always that the rigorous statement has not yet been written clearly enough.
- **Explain assumptions and mathematical conditions intuitively, not only formally.** State
  what an assumption rules out, in words, near where it is introduced. Examples often carry
  more than a restatement does. The canonical instance is the local exemplar at `M:89–125`
  (see "The canonical assumption exemplar is local, not imported" below).

**Not promoted, because they are already Constitution invariant 12** — "no causal language
without assumptions nearby" and "avoid overstating generalizability" are that invariant's
first two clauses. Cite invariant 12, do not restate it here. Two authorities for one rule
is the defect this promotion exists to remove.

**Status: drafting guidance, never a blocking finding.** These are unmeasured by
construction, so a reviewer must not report them as deviations — see "Never block on style".
They tell a writer what to aim at; they do not license a reviewer to gate.

## Venue class, and when it helps

Determine the project's class before reviewing or drafting. Try these in order and **state
which one you used**:

1. **A `**Type:**` line in the project's governance file** (`CLAUDE.md` / `AGENTS.md`) —
   the declaration `scripts/validate-structure.sh` reads.
2. **A requirements spec** under `quality_reports/specs/` naming the target outlet.
3. **Governance prose** that names the paper's type without the canonical formatting.
4. **Nothing found → class is `unknown`.** Apply only the always-apply rules, and
   **report the missing declaration as a finding** — it is a governance defect, not a
   detail to work around.

| Declared type | Class |
|---|---|
| Methods / causal inference | **methods-theory** |
| Applied statistics, Applied (medical/subject) | **applied** |
| R package + paper | inherit from the paper's target |

**Why a chain and not just step 1.** Step 1 alone was the original instruction, and it
failed on the first manuscript it was used against: `cantor-taylor_correcting-moud/CLAUDE.md`
has `**Project:**` and `**Branch:**` but no `**Type:**` line. Two reviewers run on that file
independently improvised different fallbacks — one used prose at `CLAUDE.md:129`, the other a
requirements spec — and reached the same class by luck rather than by rule. Both flagged the
gap, which is the behaviour this chain now specifies instead of leaving to invention. A
health-services paper could as easily have been improvised into `applied`, which would have
suppressed the assumption-environment rule that legitimately applies to it.

**Class conditioning is not a universal fix, and assuming it is would repeat the pooling
error one level up.** Measured on 206 papers, class explains the spread for *some*
conventions and not others:

- **Formal assumption environments — class explains it.** methods-theory 47.7% (42/88)
  vs applied 9.0% (8/89), and the within-class spread is modest (Biometrika 60%, AOS 46%,
  JRSS-B 37%). Conditioning on class is legitimate here.
- **Roadmap paragraphs — class does NOT explain it.** methods-theory 39.8% vs applied
  52.8% looks like a mild class effect, but *within* methods-theory the range is
  **Biometrika 7%, AOS 54%, JRSS-B 60%** — a 53-point spread inside a single class. The
  signal is journal house style, not class. So the class average is as misleading as the
  pooled one, and this convention is not prescribable at either level.

**Rule: before conditioning on class, check that the within-class spread is small. If it
is not, state the range and prescribe nothing.**

## Rules that always apply

These four cleared the spread check — every venue agrees within ≤21 points — so they hold
regardless of class.

### 1. No provenance leakage. A paper has no earlier drafts, only its argument.

Never reference this document's own prior versions, review history, or your own corrections
inside the manuscript. Prohibited in prose: "an earlier version claimed", "the remediated
theory", "previously we over-claimed", "note to self", bare `TODO`.

Measured: **6.3% of published papers (13/206)**, every venue ≤11%. In this workspace:
**21 `.tex` files across 8 projects**, including publishable `main.tex` and `theory.tex`.
That differential is the single largest gap between local practice and published practice
found in the study.

The cause is structural, so the fix is structural: reviewer findings arrive in-band and get
explained into the prose. Audit rationale has a home now —
`quality_reports/reviews/YYYY-MM-DD_<stem>.md`. Put it there. See
[../../quality_reports/reviews/README.md](../../quality_reports/reviews/README.md).

**The distinction:** explaining *why* a choice was made is good writing. Referencing the
document's own history is not. "We assume $W$ is observed because …" is right. "An earlier
version did not require this" is not. **Provenance, not justification.**

### 2. Use real sectioning, not run-in bold pseudo-headers.

`\textbf{Some phrase.}` at the start of a paragraph, used as a structural device. Use
`\paragraph{}` or a real `\subsection{}`.

Measured: **median 0 across all 206 papers**; only 7.3% have three or more, and no venue
exceeds 17%. For contrast, `M` has **14** — outside the range of every
venue measured, not just the average.

### 3. LaTeX correctness is not style, and is never optional.

These are defects regardless of venue, class, or taste. **The line numbers below are
examples of patterns, not a checklist — scan for each pattern everywhere, do not stop at the
cited instance.** When this section named only `M:44`, both reviewers correctly found a
second identical defect at `M:334` that no framework document had recorded. That
generalization is the expected behaviour.

- **`\label` must be inside the equation environment.** `\end{align}\label{theta}` puts
  the label outside, so `\eqref{theta}` silently resolves to the wrong number.
  (`M:44`; the same defect recurs at `M:334`, breaking `\ref{thetahat}` at `M:387` and
  `M:426`.)
- **One appendix mechanism per document.** A `\section{Appendix}` used as a body heading
  *before* the real `\appendix` produces two different things both called "appendix",
  numbered on different schemes — the body one takes an ordinary section number, the real
  ones take letters. (`M:617` is a body section titled "Appendix" holding an extension;
  the genuine `\appendix` is at `M:682`, with true appendices from `M:687`.) The
  consequence is user-visible: a label defined in the pre-`\appendix` section renders as
  "Appendix 9.1" while every sibling cross-reference renders as a letter.
- **No orphan heading levels.** A `\subsubsection` directly under a `\section` numbers as
  `3.0.1` in the `article` class.
- **Every label is referenced and every reference resolves.** An unreferenced `\label` is
  usually a sign of orphaned content.
- Every `\cite` key resolves; no undefined references; no overfull hbox > 10pt. **These
  three require a compile** — a static read cannot confirm them, so a reviewer who did not
  compile must say so rather than report this bullet as passed.

Unlike everything else in this file, these have a correct answer that does not depend on
readership.

### 4. Numbered results are the anchors for contribution claims.

A contribution paragraph that asserts N things should point at the numbered theorems,
propositions, or sections that deliver them. Median 3 theorem-family environments per
paper — the anchors generally exist; the claim just fails to cite them.
(`M:47` opens the contribution paragraph; its claims are not anchored to numbered results.)

This is a claim-traceability rule, and it is the paper-level expression of
`RESEARCH_CONSTITUTION.md` invariant 12.

## Class-conditioned rules

### Formal assumption environments — methods-theory only

A methods-theory paper stating identifying conditions should state them in numbered
assumption environments before the result that uses them, per
[proof-protocol.md](proof-protocol.md) §Assumptions First. Measured 47.7% in
methods-theory against 9.0% in applied — for an applied paper, prose conditions are the
norm and formal environments are the deviation.

**Naming them (`\begin{assumption}[Consistency]`) is optional and must never be
required.** Of the 42 methods-theory papers that state assumptions, only **4 (9.5%)** name
all of them. Suggest it as an aid to the reader; do not flag its absence.

## Explicitly NOT rules

Listed so they are not re-invented. Each was proposed, measured, and rejected. **Flagging
any of these is a false positive.**

| Proposed rule | Measured | Status |
|---|---|---|
| No roadmap paragraph ("the rest of this paper is organized as follows") | **49%** overall; Biometrika 7%, JRSS-A 67% — gap 60 | **NOT A RULE.** Majority practice, and unprescribable at any aggregation. Author's choice. |
| No hedging ("aims to", "seeks to", "attempts to") | **31%**, range 20–41% across venues | **NOT A RULE.** Normal published register. |
| Every assumption carries a `[Name]` | **16%** of papers that state assumptions name all of them (9/57) | **NOT A RULE.** Optional aid only. |
| Related-work heading is misplaced | Only **25%** have one *at all*; gap 50 (JRSS-A 0%, AOS 50%). All 51 that have one use `subsection` | **NOT A RULE.** Its presence is the minority choice; position is not the issue. If present, `subsection` matches practice. |
| `\appendix` usage indicates quality | **42%**, gap 41 | **NOT A RULE.** Only the *broken-level* case in §3 is a defect. |

## Descriptive baselines

Orientation, not targets. Deviating is not a finding.

| | Median (206 papers) |
|---|---|
| Introduction paragraphs | 9 |
| Top-level sections | 10 |
| "we \<verb\>" in introduction | 2 |
| Theorem-family environments | 3 |
| Run-in pseudo-headers | 0 |

## The canonical assumption exemplar is local, not imported

`M:89–125` **exceeds** the Biometrika papers sampled, and is the
pattern to hold other manuscripts to:

- each assumption tied to the specific bias term it eliminates (Δ₁, Δ₂, Δ₃);
- one blanket unverifiability statement covering every $W$-involving assumption, rather
  than repeated hedging;
- plausibility walked per application;
- **necessity proved by counterexample**, with a stated reason for keeping one assumption
  separate;
- a leading special case for transparency.

Do not "improve" this toward a generic template. Where a reviewer's suggestion would move
a manuscript away from this pattern, the suggestion is wrong.

## Constraint on any tooling built against this protocol

**Never hardcode `\begin{assumption}`.** The 206-paper sample uses at least 12 distinct
environment names for assumption-like content — `assum`, `assump`, `asmp`, `asump`,
`Assmp`, `condition`, `cond`, `condi`, `Cond`, `hyp`, `assumptioniden`,
`manualassumption`. This study's own first-pass regex matched only
`(assumption|condition)` and undercounted by 22 instances, reporting 0% where the true
figure was 15%. A checker that hardcodes one name will silently under-report — Constitution
#1 applied to our own instruments.

## Never block on style

A style deviation must never gate a commit, a review sign-off, or a submission. Proof rigor
has no upper bound of harm — a wrong theorem stays wrong. Prose conformity does: past a
low threshold, enforcing it costs the author's voice and buys nothing a reader values.

Only §3 (LaTeX correctness) and §1 (leakage) are hard. Everything else in this file is
advisory, and a reviewer who reports §2 or a baseline deviation as a blocking finding has
misread this protocol. The authored writing commitments are advisory in the strongest
sense — they are unmeasured by construction, so they are drafting aims, not review criteria.

## Operating instruction for AI agents

1. Read the project's `**Type:**` line and fix the class before reviewing or drafting.
2. Apply §1–§4 always. Apply the class-conditioned section only if the class is known.
3. Do not report anything from "Explicitly NOT rules". If you believe one should be a
   rule, measure it against `rows.json` and the spread check first, then amend this file
   — argument alone is not sufficient, because argument alone already produced three
   wrong rules.
4. Do not report the **authored writing commitments** as findings either. They are drafting
   aims. If a manuscript reads unclearly you may say so as advice; do not score it.
5. When reporting, separate **LaTeX correctness** (§3, always actionable) from **advisory**
   findings, so the author can triage.
6. State what you did not check. A protocol section you skipped is not a section that
   passed.
