#!/bin/bash
# Monitor progress of sample splitting coverage validation

echo "=========================================="
echo "Sample Splitting Coverage Validation"
echo "=========================================="
echo ""

OUTPUT_FILE="/private/tmp/claude-1141097072/-Users-dagniel-RAND-rprojects-surrogates-surrogate-transportability/tasks/b2zfmp2ub.output"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Output file not found. Job may have completed or failed."
    exit 1
fi

# Show last 50 lines
echo "Last 50 lines of output:"
echo "----------------------------------------"
tail -n 50 "$OUTPUT_FILE"
echo ""
echo "----------------------------------------"
echo ""

# Count replications completed by looking for "Replication X/100" pattern
baseline_count=$(grep "Replication.*100" "$OUTPUT_FILE" | grep -B 5 "BASELINE" | tail -1 | grep -o "Replication [0-9]*/100" | grep -o "[0-9]*/" | tr -d '/' || echo "0")
strong_count=$(grep "Replication.*100" "$OUTPUT_FILE" | grep -B 5 "STRONG" | tail -1 | grep -o "Replication [0-9]*/100" | grep -o "[0-9]*/" | tr -d '/' || echo "0")

# Simple approach: count how many DGPs have been started
dgps_completed=$(grep -c "^--- RESULTS ---" "$OUTPUT_FILE" 2>/dev/null || echo "0")
current_dgp=$(grep "^====.*====$" "$OUTPUT_FILE" | tail -1)

echo "Progress Summary:"
echo "  Current DGP: $current_dgp"
echo "  DGPs completed: $dgps_completed/5"

# Get last replication number
last_rep=$(grep "Replication [0-9]*/100" "$OUTPUT_FILE" | tail -1 || echo "Not started")
echo "  Last replication: $last_rep"
echo ""

# Check if completed
if grep -q "SAMPLE SPLITTING COVERAGE VALIDATION COMPLETE" "$OUTPUT_FILE"; then
    echo "✓ Validation COMPLETE!"
    echo ""
    echo "Results saved to: sims/results/sample_splitting_coverage_validation.rds"
else
    echo "⏳ Still running..."
    echo ""
    echo "Estimated time:"
    if [ "$dgps_completed" -gt 0 ]; then
        remaining=$((5 - $dgps_completed))
        echo "  DGPs remaining: $remaining"
        echo "  Est. ~5-6 minutes per DGP"
        echo "  Total remaining: ~$((remaining * 5)) minutes"
    else
        echo "  ~25-30 minutes total for all 5 DGPs"
    fi
fi

echo ""
echo "To view full output:"
echo "  tail -f $OUTPUT_FILE"
echo ""
echo "To re-run this progress check:"
echo "  bash check_sample_splitting_progress.sh"
