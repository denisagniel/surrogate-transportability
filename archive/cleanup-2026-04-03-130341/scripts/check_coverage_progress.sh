#!/bin/bash
# Monitor coverage validation progress

OUTPUT_FILE="/private/tmp/claude-1141097072/-Users-dagniel-RAND-rprojects-surrogates-surrogate-transportability/tasks/b9w4oob5w.output"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Output file not found. Process may not have started yet."
    exit 1
fi

echo "=== COVERAGE VALIDATION PROGRESS ==="
echo ""

# Check if still running
if ps aux | grep -q "[c]overage_validation.R"; then
    echo "Status: RUNNING"
else
    echo "Status: COMPLETED or FAILED"
fi

echo ""
echo "Last few lines:"
tail -20 "$OUTPUT_FILE" | grep -v "^Warning" | grep -v "^──" | grep -v "^✔" | grep -v "^✖"

echo ""
echo "Replications completed:"
grep -c "Replication.*---" "$OUTPUT_FILE" || echo "0"

echo ""
echo "Current replication:"
tail -50 "$OUTPUT_FILE" | grep "Replication" | tail -1

echo ""
echo "==================================="
