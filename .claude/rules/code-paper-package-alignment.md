---
# Load when: paper has simulation code and/or an R package. Referenced by paper-done checklist, simulations skill, r-reviewer.
---

# Code–Paper–Package Alignment (Three-Way Fidelity)

When a project has **simulation code** and/or an **R package** alongside a paper, ensure all three agree and are used to verify each other. The paper is the source of truth for what was done and what the software does; the code and package must match it (package may do more, never less).

## 1. Simulation code ↔ paper (theory)

- **Same estimand, assumptions, and design** as in the paper (e.g. same DGP equations, parameters, regimes).
- Every design choice described in the paper has a **corresponding, identifiable piece** of simulation code.
- Simulation code is the implementation of what the paper describes in words/math.

**Check:** For each “we simulate …” or “DGP (3.1)” in the paper, locate the matching function or block in the simulation script. Confirm parameter names and equations match.

## 2. Simulation DGPs and results ↔ paper (reporting)

- Every DGP or regime **reported** in the paper is the one **actually run** in code (no “we ran X” when code runs Y).
- Every number, figure, or table from simulations in the paper **comes from** the simulation code (same seeds/specs, or documented differences).
- No selective reporting: regimes and metrics discussed in the paper have matching code, and reported values match code output (or discrepancies are explicit).

**Check:** For each simulation table or figure in the paper, trace it to a script and confirm the reported values can be reproduced from that script (or document why not).

## 3. Package ↔ paper

- The package implements **at least** what the paper describes (method, estimand, key options, default behavior where the paper specifies it).
- It may do **more**; it must not do **less** than the paper. The paper is the **minimum spec** for the package.
- Any claim “we do X” or “the estimator is implemented in …” in the paper must be implementable and implemented in the package.

**Check:** For each method or estimator the paper claims to provide, confirm the package exposes it (same definition, same defaults where stated). Flag any paper claim with no matching package behavior.

## 4. Feedback loop

- Use all three to **check each other**: paper says “we simulate DGP (3.1)” → simulation code contains that DGP; paper reports “Table 2” → table produced (or reproducible) from the simulation script; paper says “implemented in package X” → package X has that behavior.
- When in doubt: **run code and compare to paper**; **read paper and check code and package**.

**Check:** After editing any one of paper, simulation code, or package, re-verify the affected dimensions above so the triad stays aligned.
