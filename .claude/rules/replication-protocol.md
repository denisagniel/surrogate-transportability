---
paths:
  - "scripts/**"
  - "analysis/**"
  - "README*"
  - "**/replication*"
---

# Replication Package Protocol

**Core principle:** Reproducibility is infrastructure (constitution). A replication package is ready when an independent researcher can reproduce the paper's results (or a clearly scoped subset) using code, data or access instructions, and a README.

This protocol defines what "replication package ready" means for the [paper-done checklist](../../templates/project-types/paper-done-checklist.md) and [preprint protocol](preprint-protocol.md).

---

## Checklist: Replication Package Ready

### Code

- [ ] Analysis scripts (and simulation code or R package if any) under version control
- [ ] One documented way to run: master script or ordered steps in README
- [ ] Follow [r-code-conventions.md](r-code-conventions.md) for R coding standards

### Data

- [ ] Data included in the package, or clear access instructions in README
- [ ] License and any restrictions documented

### README

- [ ] Run instructions (how to reproduce main results)
- [ ] Software environment: R version, key packages (with versions), or equivalent for other stacks

### Fidelity (when project has simulations or an R package)

- [ ] Follow [code-paper-package-alignment.md](code-paper-package-alignment.md): paper, simulation code, and package agree; each verifies the others

---

## Integration

- **Paper done:** "Reproducibility: replication package ready or clearly scoped" — use this checklist to confirm "ready."
- **Preprint:** "Replication package ready" — same definition; apply this protocol when preparing the preprint.
