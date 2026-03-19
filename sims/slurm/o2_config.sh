#!/bin/bash

# O2 Environment Configuration for Surrogate Transportability Simulations
# Source this at the start of submission scripts

# ============================================
# O2 Storage Configuration
# ============================================
# O2 has limited home directory space. Use scratch for intermediate results.
# See: https://harvardmed.atlassian.net/wiki/spaces/O2/pages/2652045313/Scratch+Storage

# Scratch storage: 10 TB quota, 30-day auto-deletion after last access
# Use for: Individual replication .rds files (sims/results/reps/)
export O2_SCRATCH="/n/scratch3/users/${USER:0:1}/${USER}"

# Home directory: Limited space
# Use for: Final aggregated results, plots, summaries
export O2_HOME="${HOME}"

# ============================================
# Module Configuration
# ============================================

echo "Loading O2 environment..."

# Load R (prefer latest stable version)
# Available versions on O2: R/4.4.2, R/4.5.2
module load R/4.5.2

# Verify R loaded successfully
if ! command -v R &> /dev/null; then
    echo "ERROR: R module failed to load"
    exit 1
fi

echo "  R version: $(R --version | head -n 1)"

# ============================================
# R Library Path
# ============================================

# Set user library path for R packages
export R_LIBS_USER="${O2_HOME}/R/library"

# Create library directory if it doesn't exist
if [ ! -d "$R_LIBS_USER" ]; then
    echo "Creating R library directory: $R_LIBS_USER"
    mkdir -p "$R_LIBS_USER"
fi

echo "  R library: $R_LIBS_USER"

# ============================================
# Scratch Directory Setup
# ============================================

# Create scratch directories for results
if [ ! -d "$O2_SCRATCH" ]; then
    echo "Creating scratch directory: $O2_SCRATCH"
    mkdir -p "$O2_SCRATCH"
fi

# Create project scratch directories
PROJECT_SCRATCH="$O2_SCRATCH/surrogate-transportability"
mkdir -p "$PROJECT_SCRATCH/results/reps/covariate_shift"
mkdir -p "$PROJECT_SCRATCH/results/reps/selection_bias"
mkdir -p "$PROJECT_SCRATCH/results/reps/dirichlet_misspec"

echo "  Scratch storage: $PROJECT_SCRATCH"

# ============================================
# Verification
# ============================================

echo ""
echo "O2 environment configured successfully"
echo "=========================================="
echo "R version:        $(R --version | head -n 1 | awk '{print $3}')"
echo "R library:        $R_LIBS_USER"
echo "Scratch storage:  $PROJECT_SCRATCH"
echo "Home directory:   $O2_HOME"
echo "=========================================="
echo ""

# Export project scratch for use in SLURM scripts
export PROJECT_SCRATCH
