#!/bin/bash

#' Parallel execution of validation studies (Option B: Breadth)
#' Runs 9 replications simultaneously to maximize throughput
#'
#' Coverage strategy:
#' - Covariate shift: 4 scenarios × 500 reps = 2,000 reps (~19 hours)
#' - Selection bias: 4 scenarios × 500 reps = 2,000 reps (~19 hours)
#' - Dirichlet misspec: 6 scenarios × 300 reps = 1,800 reps (~16 hours)
#' Total: ~54 hours of compute

set -e

# Configuration
MAX_PARALLEL=1  # Sequential execution to avoid memory overload
LOG_DIR="logs/parallel_validation"
OUTPUT_DIR="sims/results/reps"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$OUTPUT_DIR/covariate_shift"
mkdir -p "$OUTPUT_DIR/selection_bias"
mkdir -p "$OUTPUT_DIR/dirichlet_misspec"

echo "================================================================"
echo "PARALLEL VALIDATION EXECUTION (Option B: Breadth)"
echo "================================================================"
echo ""
echo "Configuration:"
echo "  Max parallel jobs: $MAX_PARALLEL (sequential execution to avoid memory overload)"
echo "  Log directory: $LOG_DIR"
echo "  Output directory: $OUTPUT_DIR"
echo ""
echo "Studies:"
echo "  Covariate shift: 4 scenarios × 500 reps = 2,000 reps"
echo "  Selection bias: 4 scenarios × 500 reps = 2,000 reps"
echo "  Dirichlet misspec: 6 scenarios × 300 reps = 1,800 reps"
echo ""
echo "Estimated time: ~486 hours with $MAX_PARALLEL core (sequential execution)"
echo ""
echo "================================================================"
echo ""

# Function to run a single replication
run_replication() {
    local STUDY_TYPE=$1
    local SCENARIO=$2
    local REP=$3
    local N_REPS=$4

    local LOG_FILE="$LOG_DIR/${STUDY_TYPE}_${SCENARIO}_rep$(printf %04d $REP).log"

    # Add lambda parameter for dirichlet_misspec
    local LAMBDA_ARG=""
    if [ "$STUDY_TYPE" = "dirichlet_misspec" ]; then
        LAMBDA_ARG="--lambda 0.2"
    fi

    Rscript sims/scripts/run_single_replication.R \
        --study-type "$STUDY_TYPE" \
        --scenario "$SCENARIO" \
        --replication "$REP" \
        --output-dir "$OUTPUT_DIR/$STUDY_TYPE" \
        --n-baseline 1000 \
        --n-true-studies 500 \
        --n-baseline-resamples 100 \
        --n-bootstrap 100 \
        --n-mc-draws 50 \
        $LAMBDA_ARG \
        > "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        echo "[$STUDY_TYPE/$SCENARIO] Rep $REP/$N_REPS complete"
    else
        echo "[$STUDY_TYPE/$SCENARIO] Rep $REP/$N_REPS FAILED (see $LOG_FILE)"
        return 1
    fi
}

export -f run_replication
export LOG_DIR OUTPUT_DIR

# Track start time
START_TIME=$(date +%s)

echo "Starting validation studies at $(date)"
echo ""

# Study 1: Covariate Shift (500 reps per scenario)
echo "================================================================"
echo "STUDY 1: COVARIATE SHIFT VALIDATION"
echo "================================================================"
echo ""

COVARIATE_SCENARIOS=("small" "moderate" "large" "extreme")
for SCENARIO in "${COVARIATE_SCENARIOS[@]}"; do
    echo "Launching $SCENARIO scenario (500 reps)..."
    seq 1 500 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication covariate_shift $SCENARIO {} 500"
    echo ""
done

echo "Covariate shift complete. Elapsed: $(($(date +%s) - START_TIME))s"
echo ""

# Study 2: Selection Bias (500 reps per scenario)
echo "================================================================"
echo "STUDY 2: SELECTION BIAS VALIDATION"
echo "================================================================"
echo ""

SELECTION_SCENARIOS=("weak_outcome" "moderate_outcome" "strong_outcome" "moderate_responders")
for SCENARIO in "${SELECTION_SCENARIOS[@]}"; do
    echo "Launching $SCENARIO scenario (500 reps)..."
    seq 1 500 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication selection_bias $SCENARIO {} 500"
    echo ""
done

echo "Selection bias complete. Elapsed: $(($(date +%s) - START_TIME))s"
echo ""

# Study 3: Dirichlet Misspecification (300 reps per scenario)
echo "================================================================"
echo "STUDY 3: DIRICHLET MISSPECIFICATION VALIDATION"
echo "================================================================"
echo ""

DIRICHLET_SCENARIOS=("very_sparse" "sparse" "uniform" "concentrated" "highly_concentrated" "very_concentrated")
for SCENARIO in "${DIRICHLET_SCENARIOS[@]}"; do
    echo "Launching $SCENARIO scenario (300 reps)..."
    seq 1 300 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication dirichlet_misspec $SCENARIO {} 300"
    echo ""
done

echo "Dirichlet misspecification complete. Elapsed: $(($(date +%s) - START_TIME))s"
echo ""

# Calculate total time
END_TIME=$(date +%s)
TOTAL_SECONDS=$((END_TIME - START_TIME))
TOTAL_HOURS=$((TOTAL_SECONDS / 3600))
REMAINING_SECONDS=$((TOTAL_SECONDS % 3600))
TOTAL_MINUTES=$((REMAINING_SECONDS / 60))

echo "================================================================"
echo "ALL VALIDATION STUDIES COMPLETE"
echo "================================================================"
echo ""
echo "Total time: ${TOTAL_HOURS}h ${TOTAL_MINUTES}m"
echo "Studies completed:"
echo "  - Covariate shift: 2,000 reps"
echo "  - Selection bias: 2,000 reps"
echo "  - Dirichlet misspec: 1,800 reps"
echo ""
echo "Next steps:"
echo "  1. Aggregate results:"
echo "     Rscript sims/scripts/aggregate_results.R --study-type covariate_shift"
echo "     Rscript sims/scripts/aggregate_results.R --study-type selection_bias"
echo "     Rscript sims/scripts/aggregate_results.R --study-type dirichlet_misspec"
echo ""
echo "  2. Generate combined report:"
echo "     Rscript sims/scripts/create_validation_report.R"
echo ""
echo "================================================================"
