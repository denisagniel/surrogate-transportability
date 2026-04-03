#!/bin/bash
# Simple progress check for sample splitting validation

OUTPUT="/private/tmp/claude-1141097072/-Users-dagniel-RAND-rprojects-surrogates-surrogate-transportability/tasks/b2zfmp2ub.output"

echo "========================================"
echo "Sample Splitting Validation Progress"
echo "========================================"
echo ""

# Show last 30 lines
tail -n 30 "$OUTPUT"

echo ""
echo "========================================"

# Check if complete
if grep -q "VALIDATION COMPLETE" "$OUTPUT"; then
    echo "STATUS: ✓ COMPLETE"
else
    echo "STATUS: ⏳ Running (est. 25-30 min total)"
fi

echo ""
echo "To watch live: tail -f $OUTPUT"
