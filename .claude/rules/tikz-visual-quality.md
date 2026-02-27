---
paths:
  - "latex/**/*.tex"
  - "Figures/**/*.tex"
---

# TikZ Visual Quality Standards

**Every TikZ diagram must be visually polished before it is considered complete.** Applies to manuscript figures and, when present, slide figures.

## Label Positioning

- Labels must NEVER overlap with curves, lines, dots, braces, or other labels
- When two labels are near the same vertical position, stagger them
- Group labels: right of final data point
- Axis labels: at arrow tips
- Annotation labels: adjacent to braces/arrows, outside data area
- Use consistent font size

## Visual Semantics

- **Solid dots/lines** = observed outcomes, realized paths
- **Hollow circles/dashed lines** = counterfactual outcomes, unrealized paths
- Use consistent colors for semantic meaning (positive, negative, neutral)
- Define colors in your document theme or use consistent semantic colors for reuse

### Line Weights
- Axes: `thick`
- Data lines: `thick`
- Annotation arrows: `thick` (NOT `very thick`)
- Grid/reference lines: `dashed, gray!40`

## Spacing and Proportions

- Standard scale: `[scale=1.1]` for full-width diagrams
- Dot radius: `4pt` for data points
- Minimum 0.2 units between any label and nearest graphical element
- Axes extend beyond all data points

## Checklist

```
[ ] No label-label overlaps
[ ] No label-curve overlaps
[ ] Consistent dot style (solid=observed, hollow=counterfactual)
[ ] Consistent line style (solid=observed, dashed=counterfactual)
[ ] Color semantics correct
[ ] Arrow annotations point FROM label TO feature
[ ] Axes extend beyond all data points
[ ] Labels legible at figure size in the manuscript (or at presentation size for slides)
```
