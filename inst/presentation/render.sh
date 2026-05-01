#!/bin/bash
# Render the presentation slides

QUARTO="/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto"

cd "$(dirname "$0")"
$QUARTO render slides.qmd

echo ""
echo "Slides rendered successfully!"
echo "Open: $(pwd)/slides.html"
