#!/bin/bash

# Master script: Submit all three validation studies to SLURM
# Total: 5,800 replications across 14 scenarios

echo "=========================================="
echo "VALIDATION STUDY DEPLOYMENT"
echo "=========================================="
echo ""
echo "Total replications: 14,000"
echo "  - Covariate shift:     4,000 (4 scenarios × 1,000 reps)"
echo "  - Selection bias:      4,000 (4 scenarios × 1,000 reps)"
echo "  - Dirichlet misspec:   6,000 (6 scenarios × 1,000 reps)"
echo ""
echo "Starting deployment..."
echo ""

# Submit covariate shift
echo "Step 1/3: Covariate Shift"
bash sims/slurm/submit_all_covariate_shift.sh
sleep 2

# Submit selection bias
echo ""
echo "Step 2/3: Selection Bias"
bash sims/slurm/submit_all_selection_bias.sh
sleep 2

# Submit Dirichlet misspecification
echo ""
echo "Step 3/3: Dirichlet Misspecification"
bash sims/slurm/submit_all_dirichlet_misspec.sh

echo ""
echo "=========================================="
echo "ALL STUDIES SUBMITTED"
echo "=========================================="
echo ""
echo "Quick monitoring:"
echo "  squeue -u \$USER"
echo "  watch -n 30 'squeue -u \$USER | wc -l'"
echo ""
echo "Detailed progress:"
echo "  bash sims/slurm/check_completeness.sh covariate_shift"
echo "  bash sims/slurm/check_completeness.sh selection_bias"
echo "  bash sims/slurm/check_completeness.sh dirichlet_misspec"
echo ""
echo "Expected completion time (with 100-200 cores):"
echo "  Wall time: 12-20 hours"
echo "  Core hours: ~1,400 hours total"
echo ""
echo "After completion, aggregate results with:"
echo "  Rscript sims/scripts/aggregate_results.R --study-type covariate_shift"
echo "  Rscript sims/scripts/aggregate_results.R --study-type selection_bias"
echo "  Rscript sims/scripts/aggregate_results.R --study-type dirichlet_misspec"
echo "  Rscript sims/scripts/create_validation_report.R"
