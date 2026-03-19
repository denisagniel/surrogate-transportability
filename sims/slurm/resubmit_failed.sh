#!/bin/bash

# Resubmit specific failed or missing replications
# Usage: ./resubmit_failed.sh <study_type> <scenario> <array_indices>

if [ $# -lt 3 ]; then
    echo "Usage: bash resubmit_failed.sh <study_type> <scenario> <array_indices>"
    echo ""
    echo "Examples:"
    echo "  bash resubmit_failed.sh covariate_shift small \"1,5,10\""
    echo "  bash resubmit_failed.sh selection_bias weak_outcome \"1-10,42\""
    echo "  bash resubmit_failed.sh dirichlet_misspec sparse \"15-20\""
    echo ""
    echo "Array indices can be:"
    echo "  - Single numbers: \"1,5,10\""
    echo "  - Ranges: \"1-10\""
    echo "  - Mixed: \"1,5,10-15,42\""
    exit 1
fi

STUDY_TYPE=$1
SCENARIO=$2
ARRAY_INDICES=$3

# Determine SLURM script based on study type
case $STUDY_TYPE in
    covariate_shift)
        SLURM_SCRIPT="sims/slurm/covariate_shift_validation.slurm"
        ;;
    selection_bias)
        SLURM_SCRIPT="sims/slurm/selection_bias_validation.slurm"
        ;;
    dirichlet_misspec)
        SLURM_SCRIPT="sims/slurm/dirichlet_misspecification.slurm"
        ;;
    *)
        echo "ERROR: Unknown study type: $STUDY_TYPE"
        echo "Must be one of: covariate_shift, selection_bias, dirichlet_misspec"
        exit 1
        ;;
esac

# Check if SLURM script exists
if [ ! -f "$SLURM_SCRIPT" ]; then
    echo "ERROR: SLURM script not found: $SLURM_SCRIPT"
    exit 1
fi

echo "=========================================="
echo "Resubmitting Failed Replications"
echo "=========================================="
echo "Study:    $STUDY_TYPE"
echo "Scenario: $SCENARIO"
echo "Indices:  $ARRAY_INDICES"
echo "Script:   $SLURM_SCRIPT"
echo ""

# Submit job with specific array indices
JOB_ID=$(sbatch --export=SCENARIO=$SCENARIO --array=$ARRAY_INDICES --parsable $SLURM_SCRIPT)

echo "Job submitted: $JOB_ID"
echo ""
echo "Monitor with:"
echo "  squeue -j $JOB_ID"
echo "  scontrol show job $JOB_ID"
echo ""
echo "Check completion with:"
echo "  bash sims/slurm/check_completeness.sh $STUDY_TYPE"
