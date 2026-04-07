# TV Ball Geometry Analysis

**Exploration of local structure and across-study patterns in the TV ball B_λ(P₀)**

**Status:** PLANNED (ready to implement)

---

## Quick Start

See the comprehensive plan: [`../tv_ball_geometry_analysis.md`](../tv_ball_geometry_analysis.md)

## Research Questions

1. **Across-study correlation:** Do ΔS(Q) and ΔY(Q) covary as Q varies in B_λ?
2. **Local geometries:** Are there subregions where φ(Q) is systematically high?
3. **Predictive features:** What characteristics of Q predict good surrogate quality?

## Key Insight

This differs from the minimax framework:
- **Minimax:** Worst/best case bounds (adversarial)
- **This exploration:** Discovering patterns and structure (constructive)

Both are valuable - minimax for decision-making, geometry for understanding.

## Implementation Phases

1. **Core function** (`01_core_geometry_analysis.R`) - Generate samples, compute features
2. **Features** (`02_feature_extraction.R`) - Extract distribution characteristics
3. **Across-study** (`03_across_study_correlation.R`) - Analyze covariation
4. **Geometries** (`04_find_local_geometries.R`) - Clustering and prediction
5. **Full analysis** (`05_run_full_analysis.R`) - End-to-end pipeline
6. **Interpretation** (`06_interpretation.md`) - Written findings

## Expected Time

12-16 hours total, can split across 3-4 work sessions

## Files

```
explorations/tv_ball_geometry/
├── README.md                          # This file
├── 01_core_geometry_analysis.R        # To be created
├── 02_feature_extraction.R            # To be created
├── 03_across_study_correlation.R      # To be created
├── 04_find_local_geometries.R         # To be created
├── 05_run_full_analysis.R             # To be created
├── 06_interpretation.md               # To be created
├── results/                           # Generated data (gitignored)
└── figures/                           # Generated plots (gitignored)
```

## Next Steps

Start with Phase 1 to get basic functionality working, then evaluate whether patterns emerge before investing in detailed geometry analysis.
