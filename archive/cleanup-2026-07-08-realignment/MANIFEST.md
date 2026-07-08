# Cleanup Manifest: 2026-07-08 (canonical realignment)

**Project:** surrogate-transportability
**Context:** Phase 5 of the canonical-realignment effort. These root-level status
and planning docs are pre-canonical (March--May 2026), superseded by the realigned
paper/package and the master plan
(`quality_reports/plans/2026-07-08_canonical-realignment-master-plan.md`).
Nothing deleted; all recoverable here and in git history.

## Archived → documentation/

| File | Why archived |
|------|--------------|
| `DEPRECATIONS.md` | May-1 "keep-but-flag" deprecation roadmap; superseded by the delete-off-canonical decision + Phase 3. |
| `DEPRECATION_EXECUTIVE_SUMMARY.md` | Summary of the above; superseded. |
| `IMPLEMENTATION_GUIDE.md` | May-1 step-by-step for the keep-but-flag plan; superseded. |
| `SLIDES_VS_PAPER_VS_PACKAGE.md` | May-1 alignment comparison; predates the final slides + realignment; superseded by the master plan §1 canonical spec. |
| `QUICK_START_LAMBDA_SENSITIVITY.md` | Old lambda-sensitivity quick start tied to the deleted `sims/` infra; superseded by `simulations/canonical-validation/`. |
| `READY_FOR_CLUSTER.md` | Old cluster-readiness notes for the deleted ad-hoc `cluster/` infra; superseded by Phase 2.5. |
| `SIMULATION_IMPLEMENTATION_STATUS.md` | Status of the old (pre-fix) simulation study; superseded. |
| `package-README.md` | Stale duplicate package README describing the old multi-method package. |

## Recovery

`git mv archive/cleanup-2026-07-08-realignment/documentation/<file> <file>` (or copy),
or recover from git history before this commit.
