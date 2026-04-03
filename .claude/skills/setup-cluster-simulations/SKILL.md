# Setup Cluster Simulations

Generate complete infrastructure for running R simulation studies on Harvard O2 cluster (or similar SLURM-based HPC systems).

---

## What This Skill Does

Creates production-ready O2/SLURM infrastructure for R simulations:

1. **R Script**: Command-line interface for single replication
2. **SLURM Batch Script**: Job array configuration with modules
3. **Launch Scripts**: Submit jobs (all configs, subset, quick test)
4. **Monitoring**: Progress tracking and status checks
5. **Result Combination**: Aggregate outputs from parallel jobs
6. **Documentation**: Complete README with deployment steps

**Output:** 6-8 files in `<simulation_dir>/slurm/` ready to deploy

---

## When to Use

- Running large-scale simulations (100+ replications)
- Need parallel execution on HPC cluster
- Working with O2 (Harvard) or similar SLURM systems
- Want reproducible, documented infrastructure

---

## Prerequisites

**Before invoking this skill:**

1. Have your simulation function ready (e.g., `run_simulation(dgp, n, method)`)
2. Know the parameter grid (DGPs, sample sizes, methods, etc.)
3. Decide output directory structure
4. Know which R packages your simulation needs
5. Have a project package (optional but recommended for library())

**Infrastructure assumes:**
- SLURM-based cluster (sbatch, squeue, scancel)
- R module system (module load gcc R)
- Scratch storage for intermediate results
- Git-based code transfer to cluster

---

## What I'll Ask You

When you invoke this skill, I'll need:

1. **Simulation function name**: e.g., `run_dml_simulation()`
2. **Parameter names and values**: e.g., `dgp = c("dgp1", "dgp2")`, `n = c(200, 500, 1000)`, `method = c("forest", "tree")`
3. **Project package name**: e.g., `optimaltrees` (or NULL if no package)
4. **Output directory**: Where results should go (e.g., `results/slurm_batches/`)
5. **Replications per job**: How many reps per SLURM array task (default: 10)
6. **Total replications**: Total number of Monte Carlo reps (e.g., 1000)
7. **Simulation directory**: Where simulation code lives (e.g., `doubletree/simulations/production/`)
8. **Additional R packages**: Dependencies beyond your project package

I'll also ask about:
- SLURM settings (memory, time, partition)
- Scratch directory preferences
- Module versions if you have constraints

---

## Files Generated

### 1. `slurm/run_single_replication.R`

Command-line R script for one replication.

**Key features:**
- Uses `optparse` for CLI arguments
- Loads project via `library()` (not devtools)
- Explicit `dest` parameters for all options
- Validates all required arguments
- Saves results to specified output file
- Proper error handling and exit codes

**Avoids common bugs:**
- ✅ No devtools::load_all() (doesn't work in module R)
- ✅ Explicit dest in optparse (fixes parsing of hyphenated args)
- ✅ Guards against sourcing scripts that run code
- ✅ Proper result structure (data frames, not lists)

---

### 2. `slurm/run_simulations.slurm`

SLURM batch script for job array.

**Job targeting:**
- Designed for jobs running 30 minutes to 2 hours
- Max 1000 jobs per array (SLURM limit)
- For >1000 simulations, generates multiple launch scripts

**Configuration:**
- Array indexing (e.g., 1-50 for 50 jobs, max 1000 per array)
- Memory allocation (default: 6G, tunable)
- Time limit (default: 1hr, range 30min-2hr for optimal job targeting)
- Partition (default: short, tunable)
- Module loading (gcc/14.2.0, R/4.4.2)
- Scratch directory setup
- Result copying to permanent storage

**Handles:**
- Zero-padded batch IDs (001, 002, etc.)
- Scratch vs permanent storage
- Module version compatibility
- File permissions and cleanup

---

### 3. `slurm/launch_all_simulations.sh`

Submit all simulation configurations.

**What it does:**
- Loops through parameter grid
- Submits one sbatch per configuration
- Prints job IDs for monitoring
- Estimates total time

---

### 4. `slurm/launch_subset.sh`

Submit subset of configurations (e.g., specific methods).

**Useful for:**
- Testing with fast methods first
- Re-running failed configurations
- Iterative development

---

### 5. `slurm/quick_test.sh`

Quick test with single config and few reps.

**Purpose:**
- Verify infrastructure works (30 seconds)
- Check package loading
- Validate results format
- Confirm file paths

**Runs before full deployment**

---

### 6. `slurm/check_progress.sh`

Monitor job completion.

**Shows:**
- Total jobs submitted
- Jobs completed
- Jobs running
- Jobs pending/failed
- Estimated completion time

**Usage:** `bash slurm/check_progress.sh` (run periodically)

---

### 7. `slurm/combine_results.R`

Aggregate results from all jobs.

**What it does:**
- Finds all batch result files
- Combines into single data frame
- Validates completeness
- Saves final results
- Reports summary statistics

**Handles:**
- Missing files (warns but continues)
- Different result structures (tries to combine gracefully)
- Large result sets (efficient binding)

---

### 8. `slurm/README_O2.md`

Complete deployment documentation.

**Covers:**
- Prerequisites and setup
- File structure
- Deployment steps (local test → push → O2 pull → run)
- Monitoring and debugging
- Result retrieval
- Common issues and solutions
- Module versions
- Package installation commands

---

## Usage Example

```bash
# Invoke skill (I'll ask you questions)
/setup-cluster-simulations

# After generation, test locally
cd <simulation_dir>/slurm
bash quick_test.sh

# Push to GitHub
git add -A
git commit -m "Add O2 simulation infrastructure"
git push

# On O2 cluster
git pull
cd <simulation_dir>/slurm

# Run quick test on O2
bash quick_test.sh

# Submit full job array
bash launch_all_simulations.sh

# Monitor progress
bash check_progress.sh

# After completion (~30 min - 2 hours depending on size)
Rscript combine_results.R

# Transfer results back
# (via git, scp, or pull from local)
```

---

## Common Pitfalls (Automatically Avoided)

### 1. devtools::load_all() Doesn't Work
**Problem:** Module R doesn't have devtools
**Solution:** Uses `library(your_package)` after R CMD INSTALL

### 2. optparse Parsing Fails
**Problem:** Hyphenated arguments need explicit `dest`
**Solution:** All options include `dest = "parameter_name"`

### 3. Sourcing Runs Main Code
**Problem:** Sourcing simulation script executes the main loop
**Solution:** Wraps main code in `if (!exists("RUN_MAIN_SIMULATION") || RUN_MAIN_SIMULATION)`

### 4. Batch File Pattern Wrong
**Problem:** `batch_${TASK_ID}_*.rds` doesn't match zero-padded names
**Solution:** Uses `printf "%03d"` for consistent padding

### 5. Result Structure Mismatch
**Problem:** Lists can't be combined with rbind
**Solution:** Converts results to data frames before binding

### 6. Module Version Mismatch
**Problem:** Cluster doesn't have requested module version
**Solution:** Checks available versions and uses compatible ones

### 7. Missing Data Files
**Problem:** Binary data files not in git repo
**Solution:** README reminds to verify data files exist

### 8. Scratch Storage Overflow
**Problem:** Too many results in scratch
**Solution:** Copies to permanent storage and cleans scratch

---

## Integration with Research Constitution

**Reproducibility (Constitution §6):**
- set.seed() at top of run_single_replication.R
- Complete parameter documentation
- All settings in README
- Git-based version control

**Simulation Invariants (Constitution §9 - Simulations):**
- Supports stress regime design (parameter grid)
- No quiet favoritism (all configs explicit)
- Results include convergence indicators
- Documentation includes DGP specification

---

## Customization After Generation

You may want to tune:

1. **Memory/time**: Edit SLURM script #SBATCH directives (default: 6G, 1hr)
2. **Partition**: Change from "short" to "medium" or "long"
3. **Module versions**: Currently hardcoded as gcc/14.2.0, R/4.4.2 (update if needed)
4. **Result format**: Customize combine_results.R for your structure
5. **Progress reporting**: Add email notifications to SLURM script
6. **Quick test settings**: Adjust replications or subset in quick_test.sh
7. **Job array size**: For >1000 simulations, multiple arrays are generated automatically

All files include comments marking customization points.

**Job sizing guidance:**
- Target: 30 minutes to 2 hours per job
- Too short (<30 min): overhead dominates, combine more reps per job
- Too long (>2 hr): risk of interruption, split into more jobs
- Max array size: 1000 jobs (SLURM limit)

---

## Related Protocols

- **Constitution §6**: Reproducibility requirements
- **Constitution §9**: Simulation design invariants
- **simulations skill**: For simulation design (use before this skill)
- **data-analysis skill**: For analyzing simulation results

---

## Example Projects

This infrastructure pattern is used in:

1. **global-scholars** (18,000 simulations)
   - 4 methods × 3 DGPs × 3 sample sizes × 500 reps
   - Runtime: ~30 minutes on O2
   - Files: doubletree/simulations/production/slurm/

2. **missing-data-did** (500 simulations)
   - 3 methods × 1 DGP × 500 reps
   - Runtime: ~2.5 minutes on O2
   - Files: application/slurm/

---

## After Deployment: Analysis Workflow

Once simulations complete:

```r
# Load combined results
results <- readr::read_rds("results/combined_simulations.rds")

# Analyze with data-analysis skill or custom code
# - Compute bias, RMSE, coverage
# - Create simulation tables
# - Generate convergence plots
# - Compare methods
```

---

## Prerequisites Checklist

Before invoking `/setup-cluster-simulations`, ensure:

- [ ] Simulation function implemented and tested locally
- [ ] Parameter grid designed (use /simulations for design phase)
- [ ] Project package installable (if using library())
- [ ] All data dependencies identified
- [ ] Output format decided (what gets saved per replication)
- [ ] O2 account and SSH access configured
- [ ] Git remote accessible from O2

---

## Workflow Integration

**Typical sequence:**

1. Design simulation study: `/simulations` → spec approved
2. Implement simulation function: R development
3. Test locally: small grid, few reps
4. Generate cluster infrastructure: `/setup-cluster-simulations` (this skill)
5. Test on O2: quick_test.sh (30 sec)
6. Deploy full study: launch_all_simulations.sh
7. Monitor: check_progress.sh
8. Combine results: combine_results.R
9. Analyze: `/data-analysis` or custom code

---

## Technical Details

**Module system assumptions:**
- Uses `module load` (Lmod or Environment Modules)
- Requires gcc and R modules
- Hardcoded versions: gcc/14.2.0, R/4.4.2

**SLURM directives:**
- `--array`: Job array indexing (max 1000 jobs per array; use multiple arrays for >1000)
- `--mem`: Memory per task (default 6G)
- `--time`: Time limit (default 1hr, target 30min-2hr range)
- `--partition`: Queue name (default "short")
- `--output`: Log file pattern

**File transfer:**
- Assumes git-based sync (GitHub or GitLab)
- Alternative: scp/rsync (README will document both)

**Storage tiers:**
- Scratch: `/n/scratch/users/<first>/<username>/` (temporary, fast)
- Home: `~/` (permanent, backed up)
- Results copied scratch → home after job completes

---

## Extensibility

Generated infrastructure can be extended with:

- **Email notifications**: Add `#SBATCH --mail-type=END,FAIL`
- **Dependency chains**: Use `--dependency=afterok:jobid`
- **GPU support**: Add `#SBATCH --gres=gpu:1`
- **Multi-node**: Add `#SBATCH --nodes=2`
- **Custom output**: Modify combine_results.R for your needs

All extensions documented in generated README.

---

## Maintenance

**When to regenerate:**
- Parameter grid changes significantly
- Switching to different cluster system
- Major R package version updates
- Need different SLURM settings

**When to edit in place:**
- Minor parameter tweaks
- Memory/time adjustments
- Partition changes
- Output format refinements

---

## Skill Metadata

- **Category**: workflow
- **Type**: implementation
- **Complexity**: medium
- **Time**: 10-15 minutes (with user input)
- **Prerequisites**: Simulation function ready, parameter grid designed
- **Outputs**: 6-8 files in slurm/ directory
- **Testing**: Includes quick_test.sh for verification
- **Institution-specific**: Harvard O2 cluster (adaptable to other SLURM systems)

---

## Version History

- **2026-04-01**: Initial implementation based on global-scholars and missing-data-did patterns
