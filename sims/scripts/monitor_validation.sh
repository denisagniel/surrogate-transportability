#!/bin/bash

#' Monitor progress of parallel validation studies
#' Run this periodically to check status without interrupting execution

OUTPUT_DIR="sims/results/reps"

echo "================================================================"
echo "VALIDATION PROGRESS MONITOR"
echo "================================================================"
echo "$(date)"
echo ""

# Count completed replications by study type and scenario
count_reps() {
    local STUDY_TYPE=$1
    local SCENARIO=$2
    local EXPECTED=$3

    local COUNT=$(ls "$OUTPUT_DIR/$STUDY_TYPE/${STUDY_TYPE}_${SCENARIO}_rep"*.rds 2>/dev/null | wc -l)
    local PCT=$((COUNT * 100 / EXPECTED))

    printf "  %-30s: %4d / %4d (%3d%%)\n" "$SCENARIO" $COUNT $EXPECTED $PCT
}

# Covariate Shift (500 reps each)
echo "Covariate Shift (target: 2,000 reps)"
count_reps "covariate_shift" "small" 500
count_reps "covariate_shift" "moderate" 500
count_reps "covariate_shift" "large" 500
count_reps "covariate_shift" "extreme" 500
COVARIATE_TOTAL=$(ls "$OUTPUT_DIR/covariate_shift/"*.rds 2>/dev/null | wc -l)
echo "  Total: $COVARIATE_TOTAL / 2000"
echo ""

# Selection Bias (500 reps each)
echo "Selection Bias (target: 2,000 reps)"
count_reps "selection_bias" "weak_outcome" 500
count_reps "selection_bias" "moderate_outcome" 500
count_reps "selection_bias" "strong_outcome" 500
count_reps "selection_bias" "moderate_responders" 500
SELECTION_TOTAL=$(ls "$OUTPUT_DIR/selection_bias/"*.rds 2>/dev/null | wc -l)
echo "  Total: $SELECTION_TOTAL / 2000"
echo ""

# Dirichlet Misspecification (300 reps each)
echo "Dirichlet Misspecification (target: 1,800 reps)"
count_reps "dirichlet_misspec" "very_sparse" 300
count_reps "dirichlet_misspec" "sparse" 300
count_reps "dirichlet_misspec" "uniform" 300
count_reps "dirichlet_misspec" "concentrated" 300
count_reps "dirichlet_misspec" "highly_concentrated" 300
count_reps "dirichlet_misspec" "very_concentrated" 300
DIRICHLET_TOTAL=$(ls "$OUTPUT_DIR/dirichlet_misspec/"*.rds 2>/dev/null | wc -l)
echo "  Total: $DIRICHLET_TOTAL / 1800"
echo ""

# Overall progress
GRAND_TOTAL=$((COVARIATE_TOTAL + SELECTION_TOTAL + DIRICHLET_TOTAL))
GRAND_TARGET=5800
GRAND_PCT=$((GRAND_TOTAL * 100 / GRAND_TARGET))

echo "================================================================"
echo "OVERALL PROGRESS: $GRAND_TOTAL / $GRAND_TARGET replications ($GRAND_PCT%)"
echo "================================================================"

# Check for recent failures
echo ""
echo "Recent failures (last 10):"
tail -n 10 logs/parallel_validation/*FAILED* 2>/dev/null || echo "  No failures logged"

echo ""
echo "Refresh with: bash sims/scripts/monitor_validation.sh"
