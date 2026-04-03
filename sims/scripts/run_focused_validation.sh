#!/bin/bash

#' Focused validation: key scenarios only
#' Targets extreme contrasts from each study for faster turnaround
#'
#' Strategy:
#' - Covariate shift: small (60/40) + extreme (90/10) = 2 scenarios × 200 reps
#' - Selection bias: weak + strong outcome = 2 scenarios × 200 reps
#' - Dirichlet misspec: very sparse (α=0.1) + very concentrated (α=10) = 2 scenarios × 200 reps
#' Total: 1,200 reps × 5 min/rep = 6,000 min = 100 hours (~4 days)

set -e

# Configuration
MAX_PARALLEL=1  # Sequential to avoid memory overload
LOG_DIR="logs/focused_validation"
OUTPUT_DIR="sims/results/focused"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$OUTPUT_DIR/covariate_shift"
mkdir -p "$OUTPUT_DIR/selection_bias"
mkdir -p "$OUTPUT_DIR/dirichlet_misspec"

echo "================================================================"
echo "FOCUSED VALIDATION (Key Scenarios Only)"
echo "================================================================"
echo ""
echo "Configuration:"
echo "  Max parallel jobs: $MAX_PARALLEL (sequential execution)"
echo "  Log directory: $LOG_DIR"
echo "  Output directory: $OUTPUT_DIR"
echo ""
echo "Studies (200 reps per scenario):"
echo "  Covariate shift: small + extreme (2 scenarios)"
echo "  Selection bias: weak + strong outcome (2 scenarios)"
echo "  Dirichlet misspec: very sparse + very concentrated (2 scenarios)"
echo ""
echo "Total: 1,200 replications"
echo "Estimated time: ~100 hours (~4 days) with 1 core"
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

echo "Starting focused validation at $(date)"
echo ""

# Study 1: Covariate Shift (200 reps × 2 scenarios = 400 reps)
echo "================================================================"
echo "STUDY 1: COVARIATE SHIFT (Key Scenarios)"
echo "================================================================"
echo ""

echo "Launching small scenario (60/40) - 200 reps..."
seq 1 200 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication covariate_shift small {} 200"
echo ""

echo "Launching extreme scenario (90/10) - 200 reps..."
seq 1 200 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication covariate_shift extreme {} 200"
echo ""

echo "Covariate shift complete. Elapsed: $(($(date +%s) - START_TIME))s"
echo ""

# Study 2: Selection Bias (200 reps × 2 scenarios = 400 reps)
echo "================================================================"
echo "STUDY 2: SELECTION BIAS (Key Scenarios)"
echo "================================================================"
echo ""

echo "Launching weak outcome-favorable scenario - 200 reps..."
seq 1 200 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication selection_bias weak_outcome {} 200"
echo ""

echo "Launching strong outcome-favorable scenario - 200 reps..."
seq 1 200 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication selection_bias strong_outcome {} 200"
echo ""

echo "Selection bias complete. Elapsed: $(($(date +%s) - START_TIME))s"
echo ""

# Study 3: Dirichlet Misspecification (200 reps × 2 scenarios = 400 reps)
echo "================================================================"
echo "STUDY 3: DIRICHLET MISSPECIFICATION (Key Scenarios)"
echo "================================================================"
echo ""

echo "Launching very sparse scenario (α=0.1) - 200 reps..."
seq 1 200 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication dirichlet_misspec very_sparse {} 200"
echo ""

echo "Launching very concentrated scenario (α=10.0) - 200 reps..."
seq 1 200 | xargs -P $MAX_PARALLEL -I {} bash -c "run_replication dirichlet_misspec very_concentrated {} 200"
echo ""

echo "Dirichlet misspecification complete. Elapsed: $(($(date +%s) - START_TIME))s"
echo ""

# Calculate total time
END_TIME=$(date +%s)
TOTAL_SECONDS=$((END_TIME - START_TIME))
TOTAL_HOURS=$((TOTAL_SECONDS / 3600))
REMAINING_SECONDS=$((TOTAL_SECONDS % 3600))
TOTAL_MINUTES=$((REMAINING_SECONDS / 60))

echo "================================================================"
echo "FOCUSED VALIDATION COMPLETE"
echo "================================================================"
echo ""
echo "Total time: ${TOTAL_HOURS}h ${TOTAL_MINUTES}m"
echo "Studies completed:"
echo "  - Covariate shift: 400 reps (small + extreme)"
echo "  - Selection bias: 400 reps (weak + strong)"
echo "  - Dirichlet misspec: 400 reps (very sparse + very concentrated)"
echo ""
echo "Total replications: 1,200"
echo ""
echo "Next steps:"
echo "  1. Aggregate results:"
echo "     Rscript sims/scripts/aggregate_results.R --study-type covariate_shift --results-dir sims/results/focused/covariate_shift"
echo "     Rscript sims/scripts/aggregate_results.R --study-type selection_bias --results-dir sims/results/focused/selection_bias"
echo "     Rscript sims/scripts/aggregate_results.R --study-type dirichlet_misspec --results-dir sims/results/focused/dirichlet_misspec"
echo ""
echo "  2. Generate combined report:"
echo "     Rscript sims/scripts/create_validation_report.R --results-dir sims/results/focused"
echo ""
echo "================================================================"
