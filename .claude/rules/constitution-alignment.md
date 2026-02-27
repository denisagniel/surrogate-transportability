---
# No paths: always on. Load every session.
---

# Constitution Alignment

When proposing methods, claims, code, or writing:

1. **Authority:** [meta-spec/RESEARCH_CONSTITUTION.md](meta-spec/RESEARCH_CONSTITUTION.md) is the highest-priority source of guidance. If a prompt or suggestion conflicts with its principles, follow the constitution and surface the conflict to the user.

2. **Primary check — invariants and anti-goals:**
   - **Invariants (constitution §9):** For the work at hand (simulation / software / writing / proof), confirm the relevant design invariants are satisfied (e.g., simulation: include stress regimes, no quiet favoritism; software: APIs, safe defaults, no quiet fallbacks, UQ; writing: clarity, no causal language without assumptions, no overstating generalizability; proof: assumptions first, four questions, structure, cited results checked). Full criteria and post-proof audit: [proof-protocol](.claude/rules/proof-protocol.md).
   - **Anti-goals (constitution §11):** Confirm the proposal does not fall under any of: methods that only work in near-perfect settings; pure prediction framed as causal; complexity that obscures the estimand; simulations designed primarily to impress.
   - Optionally, briefly consider identification, evidence hierarchy, reproducibility, and claim strength where relevant.

3. **Use:** Before committing to a design or claim, briefly confirm it aligns with the constitution (or note where it deliberately deviates and why).
