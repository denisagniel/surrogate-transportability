#!/bin/bash

# Check completeness of validation study replications
# Reports missing .rds files per scenario

if [ $# -lt 1 ]; then
    echo "Usage: bash check_completeness.sh <study_type> [results_dir]"
    echo ""
    echo "Study types:"
    echo "  covariate_shift    - 4 scenarios, 1000 reps each"
    echo "  selection_bias     - 4 scenarios, 1000 reps each"
    echo "  dirichlet_misspec  - 6 scenarios, 1000 reps each"
    echo ""
    echo "Optional: Specify results directory (defaults to sims/results/reps/<study_type>)"
    exit 1
fi

STUDY_TYPE=$1
RESULTS_DIR=${2:-"sims/results/reps/$STUDY_TYPE"}

# Define scenarios and expected counts
case $STUDY_TYPE in
    covariate_shift)
        SCENARIOS=("small" "moderate" "large" "extreme")
        EXPECTED_REPS=1000
        ;;
    selection_bias)
        SCENARIOS=("weak_outcome" "moderate_outcome" "strong_outcome" "moderate_responders")
        EXPECTED_REPS=1000
        ;;
    dirichlet_misspec)
        SCENARIOS=("very_sparse" "sparse" "uniform" "concentrated" "highly_concentrated" "very_concentrated")
        EXPECTED_REPS=1000
        ;;
    *)
        echo "ERROR: Unknown study type: $STUDY_TYPE"
        echo "Must be one of: covariate_shift, selection_bias, dirichlet_misspec"
        exit 1
        ;;
esac

echo "=========================================="
echo "Completeness Check: $STUDY_TYPE"
echo "=========================================="
echo "Results directory: $RESULTS_DIR"
echo ""

# Check if directory exists
if [ ! -d "$RESULTS_DIR" ]; then
    echo "ERROR: Results directory not found: $RESULTS_DIR"
    exit 1
fi

TOTAL_EXPECTED=0
TOTAL_FOUND=0
TOTAL_MISSING=0

# Check each scenario
for SCENARIO in "${SCENARIOS[@]}"; do
    echo "Scenario: $SCENARIO"
    echo "  Expected: $EXPECTED_REPS replications"

    # Count existing files
    PATTERN="${STUDY_TYPE}_${SCENARIO}_rep*.rds"
    FOUND_COUNT=$(find "$RESULTS_DIR" -name "$PATTERN" 2>/dev/null | wc -l | tr -d ' ')
    MISSING_COUNT=$((EXPECTED_REPS - FOUND_COUNT))

    echo "  Found:    $FOUND_COUNT"

    if [ $MISSING_COUNT -gt 0 ]; then
        echo "  Missing:  $MISSING_COUNT"

        # List specific missing replication numbers (first 10)
        echo -n "  Missing reps: "
        MISSING_LIST=""
        for ((i=1; i<=$EXPECTED_REPS; i++)); do
            REP_NUM=$(printf "%04d" $i)
            FILE="${RESULTS_DIR}/${STUDY_TYPE}_${SCENARIO}_rep${REP_NUM}.rds"
            if [ ! -f "$FILE" ]; then
                if [ -z "$MISSING_LIST" ]; then
                    MISSING_LIST="$i"
                else
                    MISSING_LIST="$MISSING_LIST,$i"
                fi
            fi
        done

        # Show first 10 missing
        echo "$MISSING_LIST" | cut -d',' -f1-10

        if [ $MISSING_COUNT -gt 10 ]; then
            echo "               (and $((MISSING_COUNT - 10)) more...)"
        fi
    else
        echo "  Status:   COMPLETE ✓"
    fi

    echo ""

    TOTAL_EXPECTED=$((TOTAL_EXPECTED + EXPECTED_REPS))
    TOTAL_FOUND=$((TOTAL_FOUND + FOUND_COUNT))
    TOTAL_MISSING=$((TOTAL_MISSING + MISSING_COUNT))
done

# Summary
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Total expected:  $TOTAL_EXPECTED"
echo "Total found:     $TOTAL_FOUND"
echo "Total missing:   $TOTAL_MISSING"

if [ $TOTAL_MISSING -eq 0 ]; then
    echo ""
    echo "Status: ALL COMPLETE ✓"
    echo ""
    echo "Ready to aggregate with:"
    echo "  Rscript sims/scripts/aggregate_results.R --study-type $STUDY_TYPE"
else
    COMPLETION_PCT=$((100 * TOTAL_FOUND / TOTAL_EXPECTED))
    echo "Completion: ${COMPLETION_PCT}%"
    echo ""
    echo "To resubmit missing replications:"
    echo "  bash sims/slurm/resubmit_failed.sh $STUDY_TYPE <scenario> <array_indices>"
    echo ""
    echo "Example:"
    echo "  bash sims/slurm/resubmit_failed.sh $STUDY_TYPE ${SCENARIOS[0]} \"1,5,10-15\""
fi

echo ""
