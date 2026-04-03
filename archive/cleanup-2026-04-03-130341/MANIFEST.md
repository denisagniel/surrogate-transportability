# Cleanup Manifest: 2026-04-03 13:03:41

**Project:** surrogate-transportability
**Archived:** 216 files, 2 directories

---

## Summary

- Test/diagnostic scripts: 63 files
- Markdown documentation: 72 files
- Result files (.rds/.png/.log): 57 files
- Shell scripts: 9 files
- Reference PDFs/text: 4 files
- Directories: refs/, test_sample_size_results/

**Total workspace impact:** Reduced root clutter from 253+ untracked files to organized archive

---

## Archived Categories

### Test/Diagnostic Scripts (63 files)
**Location:** `test_scripts/`

Exploratory R scripts not in proper `tests/` directory:
- test_*.R (45 files) - Test scripts for various implementations
- debug_*.R (4 files) - Debug scripts
- diagnose_*.R (6 files) - Diagnostic scripts
- validate_*.R (2 files) - Validation scripts
- phase2_*.R (3 files) - Phase 2 analysis scripts
- Other: adaptive_*, quick_*, coverage_*, summarize_*, diagnostic_5_*

**Why archived:** Exploratory work, not part of formal test suite (`package/tests/testthat/`)

**Examples:**
- test_observed_h_only.R → Observation-level EIF testing
- test_smooth_minimum_oracle.R → Oracle smooth minimum validation
- debug_diag4_replicate.R → Replication debugging
- diagnose_coverage_failure.R → Coverage investigation
- phase2_robustness_testing.R → Phase 2 robustness checks

---

### Markdown Documentation (72 files)
**Location:** `documentation/`

Status reports, summaries, and implementation notes:
- Implementation summaries (15+ files): IMPLEMENTATION_*.md, CONCORDANCE_*.md, SMOOTH_MINIMUM_*.md
- Findings/results (12+ files): FINDINGS_*.md, VALIDATION_RESULTS.md, PRELIMINARY_*.md
- Method comparisons (8+ files): METHODS_COMPARISON_*.md, COMPARISON_*.md
- Theoretical notes (10+ files): THEORETICAL_*.md, EIF_*.md, NESTED_EXPECTATION_*.md
- Diagnostic guides (6+ files): DIAGNOSTIC_*.md
- Session summaries (5+ files): SESSION_SUMMARY_*.md
- Status trackers (4+ files): PACKAGE_FUNCTIONS_STATUS.md, ALL_STUDIES_STATUS.md
- LaTeX backups: methods/main_backup_*.tex, methods/main_new.tex, methods/section5_revised.tex
- Sims documentation: sims/DGP_SCENARIOS.md, sims/VALIDATION_FRAMEWORK_SUMMARY.md

**Why archived:** Historical documentation that clutters root directory. Active docs should be in:
- `session_notes/` for session progress
- `quality_reports/` for formal reports
- `sims/` for simulation documentation (organized by study)

**Examples:**
- IMPLEMENTATION_COMPLETE_2026-04-02.md → Implementation milestone marker
- COMPARISON_EXECUTIVE_SUMMARY.md → Method comparison results
- LOO_THEORETICAL_JUSTIFICATION.md → Leave-one-out theoretical notes
- DIAGNOSTIC_FRAMEWORK.md → Diagnostic protocol (superseded)
- WASSERSTEIN_SIMULATION_STUDY_DESIGN.md → Simulation design notes

---

### Result Files (57 files)
**Location:** `results/`

Generated outputs from analysis runs:
- **.rds files (36 files):** Saved R objects with simulation/analysis results
  - test_*_results.rds (20+ files)
  - nested_*_results.rds (5 files)
  - phase2_*_results.rds (4 files)
  - observation_level_*_results.rds (2 files)
  - *_wasserstein_*_results.rds (2 files)
  - Other: concordance_*, loo_*, smooth_minimum_*, etc.

- **.png files (8 files):** Diagnostic plots
  - phase2_bias_distribution.png
  - phase2_robustness_heatmap.png
  - test_cross_fitting_bias.png
  - test_cross_fitting_rmse.png
  - etc.

- **.log files (13 files):** Run output logs
  - comparison_*.log (7 files)
  - diagnostic_run.log
  - multi_discretization_run.log
  - phase2_robustness_output.log
  - quick_test_J.log

**Why archived:** Generated outputs should be in `sims/results/` or `package/validation/` for organized storage

**Examples:**
- nested_SYX2_results.rds → Nested expectation validation results
- concordance_EIF_results.rds → Concordance EIF comparison
- high_dimensional_coverage_results.rds → High-dim coverage study
- phase2_bias_distribution.png → Phase 2 bias diagnostic plot

---

### Shell Scripts (9 files)
**Location:** `scripts/`

Progress monitoring and job management scripts:
- check_*_progress.sh (5 files) - Monitor simulation progress
- run_studies_1_and_2.sh - Launch studies
- prepare_for_cluster.sh - Cluster setup
- test_sample_size_effect_slurm.sh - SLURM job script

**Why archived:** Should be in `sims/scripts/` or proper scripts directory

---

### Reference Files (4 files)
**Location:** `refs/`

PDFs and text files:
- Rplots.pdf - Default R graphics output
- *.txt files - Text summaries

---

### Directories (2)
**Location:** Root of archive

- **refs/** - Reference papers directory (already organized, moved intact)
- **test_sample_size_results/** - Sample size effect study outputs

---

## Recovery Instructions

### Recover individual file

```bash
# Find in manifest (shows original context)
# Copy from archive
cp archive/cleanup-2026-04-03-130341/test_scripts/test_observed_h_only.R \
   package/tests/testthat/test-observation-level.R
```

### Recover entire category

```bash
# Recover all test scripts (if needed for reference)
cp -r archive/cleanup-2026-04-03-130341/test_scripts/* explorations/legacy-tests/
```

### Recover specific results

```bash
# Recover phase 2 results
cp archive/cleanup-2026-04-03-130341/results/phase2_*_results.rds sims/results/phase2/
```

---

## Project Organization Recommendations

### Proper locations for common file types:

**Test/diagnostic scripts:**
- Formal tests → `package/tests/testthat/test-*.R`
- Validation scripts → `package/validation/`
- Exploratory scripts → `explorations/diagnostics/`

**Documentation:**
- Session notes → `session_notes/YYYY-MM-DD.md`
- Quality reports → `quality_reports/session_logs/`
- Method notes → `methods/notes/` or `methods/README.md`
- Simulation docs → `sims/README.md` or `sims/design/`

**Results:**
- Simulation results → `sims/results/study_name/`
- Package validation → `package/validation/results/`
- Plots/figures → `methods/figures/` (for paper) or `sims/figures/`

**Scripts:**
- Analysis scripts → `sims/scripts/`
- Cluster scripts → `sims/slurm/` or `sims/cluster/`
- Utility scripts → `scripts/` (if generally useful)

**References:**
- Papers/PDFs → `refs/` or `methods/refs/`

---

## .gitignore Additions Recommended

Add these to `.gitignore` to prevent re-accumulation:

```gitignore
# R temporary files
*.Rout
Rplots.pdf
.RData
.Rhistory

# Build/log files
*.log
*.aux
*.bbl

# Result files at root (should be in results/)
/*.rds
/*.png

# System files
.DS_Store

# Test scripts at root (should be in tests/ or explorations/)
/test_*.R
/debug_*.R
/diagnose_*.R
/validate_*.R
```

---

## Archive Statistics

| Category | Count |
|----------|-------|
| Test/diagnostic scripts | 63 |
| Markdown documentation | 72 |
| Result files (.rds/.png/.log) | 57 |
| Shell scripts | 9 |
| Reference files | 4 |
| Directories | 2 |
| **Total** | **216 files + 2 dirs** |

**Disk space:** Archive is self-contained and can be compressed for long-term storage

---

## Notes

- Nothing was deleted - everything is recoverable
- Archive is dated to allow multiple cleanups without conflict
- Original directory structure is preserved within categories
- session_notes/ and package/ left untouched (proper locations)
- explorations/ left in place (already organized)

---

## Next Cleanup

Recommended cleanup frequency: Every 1-2 months or when >50 clutter files accumulate

To check current clutter:
```bash
find . -maxdepth 1 -type f \( -name "test_*.R" -o -name "*.md" \) | wc -l
```
