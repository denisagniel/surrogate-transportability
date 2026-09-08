---
paths:
  - "manuscript/**"
  - "inst/paper/**"
  - "latex/**/*.tex"
  - "**/*manuscript*.tex"
---

<!-- GENERATED from .claude/rules/paper-sequencing-gate.md by scripts/generate-omo-rules.sh — DO NOT EDIT -->

# Paper Writing Sequencing Gate

Ordering rules for manuscript work. Companion to [paper-protocol.md](paper-protocol.md), which
says what a good paper *is*; this file says in what order to do the work.

**This gate is not a copy of [grant-sequencing-gate.md](grant-sequencing-gate.md), and the
difference is deliberate.** A proposal is written once, so its gate is a linear pipeline. A
paper is revised roughly 20×, so a linear pipeline would be wrong for all but the first pass —
and a gate that is wrong most of the time gets ignored, which is how this framework's reviewers
came to be measured at zero invocations. **Every step below is therefore enterable
independently.** What is enforced is not a sequence but a set of preconditions.

---

## The three hard gates

Only three. `paper-protocol.md` establishes that only leakage (§1) and LaTeX correctness (§3)
are hard, and that a style deviation must never gate anything; this file adds one precondition
of its own. Everything else in this file is ordering advice.

1. **HARD GATE — an outline exists before a section is drafted.** Never invoke
   `/draft-paper-section` when `manuscript/outline.md` is absent. If it is missing, STOP and
   create it from `templates/paper-outline.md` first. Drafting without a content-distribution
   plan is how two sections come to own the same idea, and re-sectioning later costs more than
   outlining now.

2. **HARD GATE — the registries are updated in the same turn as the prose.** A skill that
   introduces a symbol, an assumption, a claim, or a numbered result updates
   `manuscript/notation.md` and/or `manuscript/claims.md` before the turn ends. A registry
   updated later is wrong in between, and the divergence is invisible to the next agent.

3. **HARD GATE — no provenance leakage, at any step.** The manuscript never references its own
   earlier drafts and never narrates a correction. This is `paper-protocol.md` §1. It is listed
   here as well because the *mechanism* is a sequencing failure: a reviewer's finding arrives
   in-band, the fix is applied the same turn, and the model explains the fix in the prose.
   Persist the review to `quality_reports/reviews/YYYY-MM-DD_<stem>.md` **first**, then edit the
   manuscript — the rationale has a home, so it does not end up in the paper. Measured
   incidence in this workspace before the contract existed: 21 `.tex` files across 8 projects,
   against 6.3% in published papers.

---

## Ordering, for a first draft

1. **Outline** — create `manuscript/outline.md` from `templates/paper-outline.md`. Fix the
   venue class here, using the ordered determination chain in `paper-protocol.md`, and state
   which step of the chain you used. A missing type declaration is a finding, not a cue to
   improvise — two reviewers once improvised different fallbacks and agreed only by luck.

2. **Seed the registries** — create `manuscript/notation.md` and `manuscript/claims.md` from
   their templates. `notation.md` row 1 is the estimand, because Constitution invariant #12
   requires the estimand be stated before estimation.

3. **Draft** — `/draft-paper-section`, one section at a time, each following the outline.
   Unlike the grant pipeline there is no fixed section order: draft methods before the
   introduction if the results are not settled, which for a methods paper is usual.

4. **Coherence** — `/coherence-check` once two or more sections exist, before editing begins.

5. **Edit** — `/edit-paper-with-context`. Never edit a paragraph in isolation from its
   surrounding context.

6. **Review** — `/review-paper` (or individual reviewers). Persist each report per gate 3,
   *then* apply fixes via `/edit-paper-with-context`.

7. **Verify** — `/compile-latex`. §3's compile-dependent checks (broken `\eqref`, orphan
   heading levels, unreferenced labels) cannot be confirmed without a compile, and a reviewer
   that skipped it must say so rather than imply it passed.

**If structure must change mid-draft:** stop drafting, update `outline.md`, then resume. Same
rule as the grant gate, same reason.

---

## Ordering, for a revision — the common case

Entry point depends on what changed. In every path, gates 2 and 3 still apply.

| What happened | Enter at | Also required |
|---|---|---|
| Reviewer (human or agent) returned findings | Persist the report, then step 5 | Re-run step 4 if changes span sections |
| A result changed or was added | Step 2 (registries), then step 5 | `claims.md` table 2 — a new result that is never claimed is work given away |
| A claim was overstated | Step 5, `claims.md` table 1 | Check the abstract; abstract inflation is the most common form |
| Structure is wrong | Step 1, then re-enter at 3 | Do not edit prose before the outline is fixed |
| Tightening for a length limit | Step 5 | Verify no claim lost its anchor in the cut |
| Preparing to submit | Step 6, then 7 | `claims.md` §3 reconciliation; `templates/project-types/paper-done-checklist.md` |

---

## What this gate does not do

- **It does not gate on style.** No step here may block a commit, a review sign-off, or a
  submission for a style deviation. Proof rigor has no upper bound of harm; prose conformity
  does.
- **It does not govern proofs.** Proofs inside a manuscript are governed by
  [proof-protocol.md](proof-protocol.md), which triggers on the same `latex/**/*.tex` glob.
  Both apply; neither overrides the other.
- **It does not require the refuted conventions.** See `paper-protocol.md`, "Explicitly NOT
  rules" — roadmap paragraphs, hedging verbs, named assumptions, related-work placement, and
  `\appendix` usage are author's choice, and no step here may be read as prescribing them.

---

## Most common failure modes

In rough order of observed frequency:

1. **Applying a reviewer finding and narrating it in the prose** — gate 3. The finding belongs
   in `quality_reports/reviews/`, the fix belongs in the manuscript, and the explanation
   belongs in neither.
2. **Drafting before an outline exists** — gate 1. Cheap to skip, expensive to unwind.
3. **Prose and registry diverging** — gate 2. The reverse direction rots fastest: a result gets
   proved, the turn feels finished, and `claims.md` table 2 never learns about it.
4. **Claims without anchors** — one real introduction packed five contribution claims with zero
   numbered-result anchors. `claims.md` table 1 exists to make this countable.
