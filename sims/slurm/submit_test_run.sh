#!/bin/bash

# Submit test runs for all validation studies (10 reps per scenario)
# Quick verification before full deployment

# Source O2 configuration
source sims/slurm/o2_config.sh

echo "=========================================="
echo "TEST RUN DEPLOYMENT"
echo "=========================================="
echo ""
echo "Running 10 replications per scenario"
echo "Reduced parameters for quick testing:"
echo "  - n-baseline: 300 (vs 1000 production)"
echo "  - n-bootstrap: 20 (vs 100 production)"
echo "  - n-mc-draws: 10 (vs 50 production)"
echo ""
echo "Expected runtime: 5-10 minutes per scenario"
echo "Total jobs: 140 (14 scenarios × 10 reps)"
echo ""

# Create logs directory
mkdir -p logs

# Counter for submitted jobs
TOTAL_JOBS=0

# Covariate shift scenarios
echo "Submitting Covariate Shift test jobs..."
for SCENARIO in small moderate large extreme; do
    JOB_ID=$(sbatch --export=STUDY_TYPE=covariate_shift,SCENARIO=$SCENARIO --parsable sims/slurm/test_validation.slurm)
    echo "  $SCENARIO: Job $JOB_ID"
    TOTAL_JOBS=$((TOTAL_JOBS + 1))
done
echo ""

# Selection bias scenarios
echo "Submitting Selection Bias test jobs..."
for SCENARIO in weak_outcome moderate_outcome strong_outcome moderate_responders; do
    JOB_ID=$(sbatch --export=STUDY_TYPE=selection_bias,SCENARIO=$SCENARIO --parsable sims/slurm/test_validation.slurm)
    echo "  $SCENARIO: Job $JOB_ID"
    TOTAL_JOBS=$((TOTAL_JOBS + 1))
done
echo ""

# Dirichlet scenarios
echo "Submitting Dirichlet Misspecification test jobs..."
for SCENARIO in very_sparse sparse uniform concentrated highly_concentrated very_concentrated; do
    JOB_ID=$(sbatch --export=STUDY_TYPE=dirichlet_misspec,SCENARIO=$SCENARIO --parsable sims/slurm/test_validation.slurm)
    echo "  $SCENARIO: Job $JOB_ID"
    TOTAL_JOBS=$((TOTAL_JOBS + 1))
done

echo ""
echo "=========================================="
echo "TEST RUN SUBMITTED"
echo "=========================================="
echo ""
echo "Total jobs submitted: $TOTAL_JOBS (140 replications)"
echo ""
echo "Monitor progress:"
echo "  squeue -u \$USER"
echo "  watch -n 10 'squeue -u \$USER | wc -l'"
echo ""
echo "Expected completion: 10-15 minutes"
echo ""
echo "After completion, check results:"
echo "  bash sims/slurm/check_completeness.sh covariate_shift"
echo "  bash sims/slurm/check_completeness.sh selection_bias"
echo "  bash sims/slurm/check_completeness.sh dirichlet_misspec"
echo ""
echo "If test successful, launch full run with:"
echo "  bash sims/slurm/submit_all_studies.sh"
