# Simulation Result Generation Scripts

This directory contains scripts to generate tables and figures for the Biometrika paper from simulation results.

## Generated Outputs

### Tables (LaTeX)

All tables are written to `inst/paper/tables/`:

1. **table1_dgp_specs.tex** - DGP specifications (parameters, true ρ, PTE)
2. **table2_performance.tex** - Simulation performance (bias, SE, coverage)
3. **table3_timing.tex** - Computational timing information

### Figures (PDF)

All figures are written to `inst/paper/figures/`:

1. **figure1_histograms.pdf** - Histograms of ρ̂ with N(θ, σ²/n) overlay (4 panels)
2. **figure2_scatterplots.pdf** - Scatter plots of (ΔS(Q), ΔY(Q)) pairs (4 panels)

## Usage

### Generate All Tables

```bash
Rscript sims/scripts/generate_table1_dgps.R
Rscript sims/scripts/generate_table2_performance.R
Rscript sims/scripts/generate_table3_timing.R
```

**Runtime:** < 1 minute total

### Generate All Figures

```bash
# Figure 1: Uses existing simulation results (fast)
Rscript sims/scripts/generate_figure1_histograms.R

# Figure 2: Runs new simulations for scatter plots (slow)
Rscript sims/scripts/generate_figure2_scatterplots.R
```

**Runtime:**
- Figure 1: ~10 seconds
- Figure 2: ~15-20 minutes (runs 4 DGPs with adaptive M)

### Generate Everything

```bash
cd sims/scripts
for script in generate_*.R; do
  Rscript "$script"
done
```

## Requirements

### R Packages

- dplyr
- ggplot2
- patchwork
- yaml
- devtools

### Data Dependencies

- `cluster/results/combined_results.rds` - Required for Tables 2-3 and Figure 1
- `cluster/config/dgp_specifications.yaml` - Required for all scripts

## Output Verification

After running scripts, verify outputs:

```bash
# Check tables exist
ls -lh inst/paper/tables/

# Check figures exist
ls -lh inst/paper/figures/

# View table contents
cat inst/paper/tables/table2_performance.tex
```

## Integration with Paper

To include in LaTeX manuscript:

```latex
% Tables
\input{tables/table1_dgp_specs}
\input{tables/table2_performance}
\input{tables/table3_timing}

% Figures
\begin{figure}
  \centering
  \includegraphics[width=\textwidth]{figures/figure1_histograms.pdf}
  \caption{Distribution of correlation estimates...}
  \label{fig:histograms}
\end{figure}

\begin{figure}
  \centering
  \includegraphics[width=\textwidth]{figures/figure2_scatterplots.pdf}
  \caption{Treatment effect pairs across future studies...}
  \label{fig:scatterplots}
\end{figure}
```

## Script Details

### generate_table1_dgps.R

Reads `dgp_specifications.yaml` and formats DGP parameters as LaTeX table.

**Key features:**
- Handles NaN PTE for DGP5 (displays as "---")
- Formats numeric values consistently
- Includes descriptive DGP names

### generate_table2_performance.R

Extracts performance metrics from `combined_results.rds`.

**Metrics reported:**
- True correlation (ρ_true)
- Bias: mean(ρ̂) - ρ_true
- Empirical SE: sd(ρ̂)
- Estimated SE: mean(se_hat)
- Coverage: proportion of 95% CIs containing ρ_true

### generate_table3_timing.R

Extracts computational timing from `combined_results.rds`.

**Metrics reported:**
- Mean M (adaptive sample size)
- Mean runtime per replication (minutes)
- Total replications

### generate_figure1_histograms.R

Creates 4-panel histogram figure showing distribution of ρ̂ estimates.

**Features:**
- Overlays N(ρ_true, σ²/n) density (red curve)
- Vertical dashed line at ρ_true
- Publication-ready white background
- Uses serif fonts for consistency with paper

### generate_figure2_scatterplots.R

Runs one replication per DGP to generate (ΔS(Q), ΔY(Q)) pairs.

**Features:**
- Uses same adaptive M algorithm as main simulations
- Adds linear regression fit (red line)
- Annotates with estimated ρ̂
- Seeds chosen for good visualizations (10050, 10100, 10150, 10200)

**Note:** This script runs actual simulations (not just post-processing), so runtime is ~15-20 minutes.

## Troubleshooting

### "File not found" errors

Ensure you're running from project root:
```bash
# Should be in: /path/to/surrogate-transportability/
pwd
Rscript sims/scripts/generate_table1_dgps.R
```

### "could not find function" errors

Make sure package is loadable:
```R
devtools::load_all(".")
```

### Cairo/X11 warnings for Figure 1

These are harmless warnings about missing graphics libraries. Figure is still generated correctly using fallback device.

### Figure 2 takes too long

To reduce runtime, edit `generate_figure2_scatterplots.R`:
- Reduce `M_max` from 5000 to 2000
- Reduce `tolerance` from 0.01 to 0.02

This will give slightly less precise ρ̂ estimates but much faster generation.

## Version History

- **2026-05-27:** Initial scripts for Biometrika submission (Tier 1 deliverables)
