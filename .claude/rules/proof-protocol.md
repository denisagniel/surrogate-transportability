---
# No paths: always on. Load every session.
---

# Proof Protocol

## Purpose

Produce mathematical arguments that are logically valid, assumption-transparent, rate-aware, and independently auditable. Proofs should prioritize clarity, minimal assumptions, and structural coherence so that both humans and AI agents can reliably verify correctness.

---

## Core Objective

Every proof should make it easy to answer:

- **What is being assumed?**
- **What is being shown?**
- **Why is it true?**
- **Where could it fail?**

If any of these are unclear, the proof is incomplete.

---

## Non-Negotiable Rules

### Assumptions First
- Collect **all assumptions** before stating the theorem or lemma.
- Do not introduce new assumptions mid-proof without explicitly flagging them.
- Prefer minimal assumptions; note when stronger ones are used for convenience.

---

### Explicit Quantifiers
- State domains and quantifiers precisely (e.g., "for all sufficiently large \(n\)", "there exists", "uniformly over", "with probability tending to one").
- Specify the mode of convergence when applicable (almost sure, in probability, \(L_2\), etc.).
- Avoid informal asymptotic language unless defined.

---

### Roadmap Required
Begin each proof with a short structural overview describing the strategy before presenting equations.

Example:
> *Proof strategy:* Decompose the error into stochastic and approximation components, bound each separately, and combine the rates.

Structure should precede algebra.

---

### Equations Must Be Shown
- Do not skip algebraic steps that affect inequalities, rates, or logical validity.
- Avoid phrases like "after some manipulation."
- Track how each expression transforms into the next.

---

### Named Results Must Be Applied Explicitly
When invoking standard results (e.g., Cauchy–Schwarz or the triangle inequality):

- State the result being used.
- Verify that its conditions hold in the present setting.
- Show exactly how it produces the next line.

Do not rely on recognition alone.

---

### No Hidden Regularity Conditions
If a step requires conditions such as:

- bounded moments  
- measurability  
- Lipschitz continuity  
- entropy control  
- differentiability  

they must be stated explicitly.

Never smuggle in regularity assumptions.

---

### Track Rates Carefully
- Show how rates combine.
- Avoid collapsing expressions into big-O notation prematurely.
- Distinguish between \(O(\cdot)\), \(o(\cdot)\), and stochastic orders.

---

### Do Not Weaken Claims Silently
If the argument proves a weaker result than originally stated:

- Explicitly acknowledge the change.
- Explain whether the weaker result is sufficient.

---

### Dependency Verification
For every external lemma, theorem, or result:

1. State the dependency.
2. Check that its assumptions are satisfied.
3. Confirm it applies in the current regime.

Avoid circular reasoning.

---

### Highlight Weak Points Precisely
If uncertainty exists:

- Identify the **exact step** where the argument may fail.
- State what additional condition or lemma would resolve it.

Avoid vague disclaimers.

---

## Preferred Style

- Structure before manipulation  
- Minimal and interpretable assumptions  
- Tight arguments when feasible  
- Separate intuition from formal proof  
- Reveal why the result is true, not only that it is true  
- Favor arguments that generalize beyond the immediate setting  
- Write \(\lambda\) as \(\lambda(\pi)\) (or \(\lambda(\hat\pi)\) for estimates); write expectations under \(\Q_{\delta}\) as sums \(\sum_{\ba} \pi_\ba h(\ba;\lambda)(\cdot)\) where appropriate.  

---

## Required Post-Proof Audit

After each proof, include a short diagnostic:

1. **Assumption Check** — Were all assumptions used and stated?
2. **Dependency Check** — Were all invoked results verified?
3. **Rate Verification** — Do the algebra and stochastic orders combine correctly?
4. **Edge-Case Scan** — Could the result fail under weak overlap, heavy tails, near-singularity, or boundary regimes?
5. **Tightness Assessment** — Is the result likely sharp, improvable, or stronger than necessary?
6. **Failure Localization** — If fragile, where exactly is the vulnerability?

Think of this as continuous integration for theorems.

---

## Heuristic Guardrail

If an argument begins to rely on intuition or informal reasoning:

> **Pause and propose a lemma that would formalize the step.**

Convert heuristics into solvable subproblems whenever possible.

---

## Proof Strength Calibration

After completing a proof, briefly state:

- Whether the result appears tight  
- Whether assumptions could be weakened  
- Whether the argument suggests a broader theorem  

---

## Default Rigor Level

- Default to full rigor.
- A proof sketch is acceptable **only if explicitly requested**.

---

## Operating Instruction for AI Agents

When generating proofs:

> Treat this specification as the highest-priority guidance.  
> If a prompt conflicts with these rules, follow the specification and surface the conflict.

Optimize for correctness, transparency, and auditability over brevity.
