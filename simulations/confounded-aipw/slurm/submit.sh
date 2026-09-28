#!/bin/bash
# =============================================================================
# submit.sh -- mint a run-id, preflight, and submit the confounded-aipw arrays
# =============================================================================
# Run ON O2 (a login node is fine -- sbatch only queues). Mirrors
# simulations/lambda-sweep/slurm/submit.sh, plus:
#
#   * PER-STRATUM ARRAYS. config/grid.R's stratum_of() splits the grid by n into
#     small_n (n=250/500/2000; the `smalln` block plus most of `ngrid`),
#     large_n (n=10000; `agreement` + `confounded`), and xlarge_n (n=40000; the
#     rest of `ngrid`). Per-unit cost differs by ~4 orders of magnitude
#     top-to-bottom, so ONE global reps_per_job would either time out the
#     large/xlarge cells or waste wall clock per small_n task. Each stratum
#     gets its own array with its own REPS_PER_JOB/--time/--mem, read from
#     config/sizing.tsv. Strata are read from the grid at runtime (never
#     hardcoded here), so a future stratum_of() change does not require
#     editing this script. Global task ids stay contiguous across strata so
#     task_NNNNNN.rds cannot collide in the shared scratch dir.
#
#   * --smoke. Submits a REAL sbatch array per stratum, one unit per task,
#     against a throwaway smoke run-id, to measure per-unit wall time and peak
#     RSS ON THE CLUSTER. This is mandatory before sizing: canonical-validation's
#     own history shows local profiling underestimated real O2 per-unit cost by
#     ~3.8x (local median 61.4 s/unit vs 191.8-254.6 s/unit observed on O2), and
#     lambda-sweep's 8-unit smoke probe still underestimated its own full run's
#     q0.9 by 1.4x and its max by 3.1x. Never size from a local number, and never
#     drop the safety factor.
#
# Usage:
#   bash slurm/submit.sh                      # full run, from config/sizing.tsv
#   bash slurm/submit.sh --smoke              # real per-stratum timing probes
#   bash slurm/submit.sh --dry-run            # print the plan, submit nothing
#   bash slurm/submit.sh --stratum large_n    # restrict to one stratum
# =============================================================================

# --- Login-node environment bootstrap ----------------------------------------
# This launcher runs on a LOGIN node and calls Rscript below. `module` is a bash
# function Lmod `export -f`s into the environment, so it is INHERITED: present for
# a human at an interactive prompt, ABSENT under `ssh host 'bash -s'`. Without
# this, agent-driven submission dies at "Rscript: command not found" while the
# identical command works when typed by hand. Must precede `set -euo pipefail`:
# /etc/profile.d/* scripts reference unset variables and return non-zero.
#
# Deliberately NO `module purge` here, unlike the job script: purging on a login
# node would silently drop modules a human had loaded in their own session.
set +eu
if ! command -v module >/dev/null 2>&1; then
  for profile_script in /etc/profile.d/lmod.sh /etc/profile.d/modules.sh /etc/profile; do
    [ -r "${profile_script}" ] && . "${profile_script}" && break
  done
fi
set -euo pipefail
if command -v module >/dev/null 2>&1; then
  module load gcc/14.2.0 2>/dev/null || module load gcc || true
  module load R/4.4.2   2>/dev/null || module load R   || true
fi
command -v Rscript >/dev/null 2>&1 || {
  echo "ERROR: Rscript not on PATH after module bootstrap -- cannot run preflight." >&2
  echo "       (Non-interactively this is the inherited-\`module\` problem.)" >&2
  exit 1
}
# Pinned and EXPORTED, not inherited: --export=ALL would otherwise propagate the
# submitting shell's R_LIBS_USER into every task.
export R_LIBS_USER="${R_LIBS_USER:-${HOME}/R/x86_64-pc-linux-gnu-library/4.4}"

HMS_ID="dma12"
PROJECT_NAME="surrogate-transportability"
STUDY_NAME="confounded-aipw"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"

SMOKE=0
DRY_RUN=0
ONLY_STRATUM=""
while (( $# )); do
  case "$1" in
    --smoke)   SMOKE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --stratum) ONLY_STRATUM="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# =============================================================================
# PREFLIGHT: fail loudly BEFORE launching any array.
# =============================================================================
preflight_fail() { echo "PREFLIGHT FAILED: $*" >&2; exit 1; }

# (a) Required staged input files. confounded-aipw is self-contained: the DGP
# specs, the exact reference rho_true and the closed-form rho_iw_limit all come
# from the installed package (confounded_dgp_params / iw_limit_from_cates). No
# staged .rds inputs.
REQUIRED_INPUTS=(
)
for f in ${REQUIRED_INPUTS[@]+"${REQUIRED_INPUTS[@]}"}; do
  [[ -e "${f}" ]] || preflight_fail "required input not found: ${f}"
done

# (b) Science files must all be present -- run_replication.R sources four of them
# and _code_hash.R hashes the same four.
for f in config/grid.R R/dgp.R R/estimators.R R/run_one.R; do
  [[ -f "${STUDY_DIR}/${f}" ]] || preflight_fail "missing study source: ${f}"
done

# (c) optparse checked ONCE here rather than N times inside the arrays.
Rscript -e 'if (!requireNamespace("optparse", quietly=TRUE)) stop("optparse not installed for this R"); cat("preflight: optparse OK\n")' \
  || preflight_fail "optparse missing from ${R_LIBS_USER}"

# (d) Installed-package freshness. A forgotten rebuild means the cluster runs
# STALE code. The four functions below are the ones this study added to the
# package surface (see MANIFEST.md); if any is absent, the install predates the
# study and every unit would die identically.
PKG_NAME="surrogateTransportability"
PKG_MIN_VERSION=$(grep -m1 '^Version:' "${STUDY_DIR}/../../DESCRIPTION" 2>/dev/null | sed 's/^Version:[[:space:]]*//')
Rscript -e "
  pkg <- '${PKG_NAME}'; want <- '${PKG_MIN_VERSION}'
  if (!requireNamespace(pkg, quietly = TRUE))
    stop(sprintf('project package %s is NOT installed on this node -- R CMD INSTALL it first.', pkg))
  if (nzchar(want) && utils::packageVersion(pkg) < want)
    stop(sprintf('installed %s %s < working-tree %s -- rebuild/reinstall before submitting.', pkg, utils::packageVersion(pkg), want))
  need <- c('tv_ball_correlation_IF_adaptive','sample_tv_ball','canonical_dgp_params',
            'generate_dgp_data','confounded_dgp_params','crossfit_nuisances_once',
            'canonical_cates','true_rho_from_cates','iw_limit_from_cates')
  miss <- need[!vapply(need, function(f) exists(f, where = asNamespace(pkg), inherits = FALSE), logical(1))]
  if (length(miss)) stop(sprintf('installed %s lacks: %s', pkg, paste(miss, collapse=', ')))
  cat(sprintf('preflight: %s %s OK (all %d required functions present)\n', pkg, utils::packageVersion(pkg), length(need)))
" || preflight_fail "project package '${PKG_NAME}' missing, stale, or incomplete (see message above)."

# (e) The AIPW arm's nuisance fitters must be installed for this R.
Rscript -e 'for (p in c("mgcv","ranger")) if (!requireNamespace(p, quietly=TRUE)) stop(sprintf("%s not installed for this R (needed by the AIPW arm)", p)); cat("preflight: mgcv + ranger OK\n")' \
  || preflight_fail "mgcv/ranger missing from ${R_LIBS_USER}"
echo "Preflight OK."

MAX_ARRAY_SIZE=1000
MAX_CONCURRENT_JOBS=10000

# --- Build the per-stratum plan ----------------------------------------------
# Arrays are parallel-indexed: PS_NAME[i] PS_UNITS[i] PS_RPJ[i] PS_TASKS[i]
# PS_TIME[i] PS_MEM[i] PS_ROWS[i] PS_BASE[i]
declare -a PS_NAME=() PS_UNITS=() PS_RPJ=() PS_TASKS=() PS_TIME=() PS_MEM=() PS_ROWS=() PS_BASE=()

SIZING_TSV="${STUDY_DIR}/config/sizing.tsv"

if (( SMOKE == 1 )); then
  # A smoke probe needs no sizing file -- that is the point: it EXISTS to produce
  # the numbers sizing is computed from. One unit per task, generous wall time and
  # memory so an UNSIZED probe cannot die of either.
  #
  # Strata are discovered from the grid, not hardcoded, so a stratum_of() change
  # (like adding xlarge_n for this study's n=40000 cells) is picked up here
  # automatically instead of silently smoke-probing nothing for it.
  #
  # --mem/--time defaults below are deliberately loose, not a sizing claim, per
  # stratum. large_n: the estimator allocates several n x M_final
  # influence-function matrices (2 * 10000 * 1500 * 8 B = 240 MB at the M_MAX in
  # config/grid.R for just two of them) and the AIPW arm additionally holds
  # ranger forests, so the real figure is unknown until measured -- which is
  # what run_replication.R's VmHWM read does. xlarge_n (n=40000, this study's
  # largest cell) scales those same matrices ~4x by n; small_n and any other
  # stratum get a smaller, cheaper default.
  STRATA_LIST=$(Rscript -e "
    suppressPackageStartupMessages(library(surrogateTransportability))
    source('${STUDY_DIR}/R/dgp.R'); source('${STUDY_DIR}/config/grid.R')
    cat(unique(stratum_of(GRID)), sep=' ')") \
    || preflight_fail "could not enumerate strata from config/grid.R"
  for s in ${STRATA_LIST}; do
    [[ -n "${ONLY_STRATUM}" && "${s}" != "${ONLY_STRATUM}" ]] && continue
    rows=$(Rscript "${SLURM_DIR}/smoke_rows.R" "${STUDY_DIR}" "${s}") \
      || preflight_fail "could not compute smoke probe rows for stratum ${s}"
    n=$(awk -F, '{print NF}' <<< "${rows}")
    PS_NAME+=("${s}"); PS_UNITS+=("${n}"); PS_RPJ+=(1); PS_TASKS+=("${n}")
    PS_ROWS+=("${rows}")
    case "${s}" in
      large_n)  PS_TIME+=("0-02:00:00"); PS_MEM+=(8) ;;
      xlarge_n) PS_TIME+=("0-06:00:00"); PS_MEM+=(16) ;;
      *)        PS_TIME+=("0-00:45:00"); PS_MEM+=(4) ;;
    esac
    echo "Smoke probe stratum ${s}: ${n} unit(s), rows ${rows}"
  done
  (( ${#PS_NAME[@]} > 0 )) || preflight_fail "no strata matched (check --stratum against config/grid.R's stratum_of())"
else
  [[ -f "${SIZING_TSV}" ]] || preflight_fail "${SIZING_TSV} not found. Size from a REAL O2 smoke run first:
    bash slurm/submit.sh --smoke
    Rscript slurm/profile_timing.R --study-dir . --from-smoke-dir <smoke scratch> --target-hours 2"
  # sizing.tsv columns: stratum total_units reps_per_job total_tasks walltime mem_gb secs_per_unit
  while IFS=$'\t' read -r s units rpj tasks wt mem _rest; do
    [[ "${s}" == "stratum" || -z "${s}" ]] && continue
    [[ -n "${ONLY_STRATUM}" && "${s}" != "${ONLY_STRATUM}" ]] && continue
    PS_NAME+=("${s}"); PS_UNITS+=("${units}"); PS_RPJ+=("${rpj}"); PS_TASKS+=("${tasks}")
    PS_TIME+=("${wt}"); PS_MEM+=("${mem}"); PS_ROWS+=("")
  done < "${SIZING_TSV}"
  (( ${#PS_NAME[@]} > 0 )) || preflight_fail "no stratum rows parsed from ${SIZING_TSV}"

  # Cross-check the declared unit counts against what the grid actually yields,
  # so a hand-edited sizing.tsv cannot silently under-cover a stratum.
  for i in "${!PS_NAME[@]}"; do
    actual=$(Rscript -e "
      suppressPackageStartupMessages(library(surrogateTransportability))
      source('${STUDY_DIR}/R/dgp.R'); source('${STUDY_DIR}/config/grid.R')
      ut <- unit_table(); cat(sum(stratum_of(ut) == '${PS_NAME[$i]}'))")
    if [[ "${actual}" != "${PS_UNITS[$i]}" ]]; then
      preflight_fail "sizing.tsv says stratum ${PS_NAME[$i]} has ${PS_UNITS[$i]} units but the grid yields ${actual}. Re-run profile_timing.R."
    fi
  done
fi

# Assign contiguous GLOBAL task-id bases so task_NNNNNN.rds is unique across the
# strata's separate arrays.
TOTAL_TASKS=0
TOTAL_UNITS=0
for i in "${!PS_NAME[@]}"; do
  PS_BASE+=("${TOTAL_TASKS}")
  TOTAL_TASKS=$(( TOTAL_TASKS + PS_TASKS[i] ))
  TOTAL_UNITS=$(( TOTAL_UNITS + PS_UNITS[i] ))
done

# --- Run identity -------------------------------------------------------------
GIT_SHA="$(git -C "${STUDY_DIR}" rev-parse --short HEAD 2>/dev/null || echo nogit)"
RUN_ID="$(date '+%Y%m%d-%H%M%S')_${GIT_SHA}"
(( SMOKE == 1 )) && RUN_ID="smoke-${RUN_ID}"

# Scratch: intermediate task files + logs (NOT backed up). Home holds only the
# final combined result (written later by combine.R).
SCRATCH_ROOT="/n/scratch/users/${HMS_ID:0:1}/${HMS_ID}/${PROJECT_NAME}/${STUDY_NAME}"
SCRATCH_DIR="${SCRATCH_ROOT}/${RUN_ID}"
LOG_DIR="${SCRATCH_DIR}/logs"

echo "=============================================================="
echo " study        : ${STUDY_NAME}   (project ${PROJECT_NAME})"
echo " run-id       : ${RUN_ID}$( (( SMOKE == 1 )) && echo '   [SMOKE TIMING PROBE]')"
echo " total        : ${TOTAL_TASKS} task(s), ${TOTAL_UNITS} unit(s)"
echo " scratch      : ${SCRATCH_DIR}"
echo " logs         : ${LOG_DIR}   (also ./logs/latest)"
printf ' %-10s %7s %6s %7s %5s %14s %6s\n' stratum units rpj tasks base --time --mem
for i in "${!PS_NAME[@]}"; do
  printf ' %-10s %7s %6s %7s %5s %14s %5sG\n' \
    "${PS_NAME[$i]}" "${PS_UNITS[$i]}" "${PS_RPJ[$i]}" "${PS_TASKS[$i]}" \
    "${PS_BASE[$i]}" "${PS_TIME[$i]}" "${PS_MEM[$i]}"
done
echo "=============================================================="

if (( DRY_RUN == 1 )); then
  echo "--dry-run: nothing submitted."
  exit 0
fi

mkdir -p "${SCRATCH_DIR}" "${LOG_DIR}"

# Record the study source-code hash so combine.R can detect stale code. ONE
# definition of the hash lives in slurm/_code_hash.R -- no second inline copy.
Rscript "${SLURM_DIR}/_code_hash.R" "${STUDY_DIR}" > "${SCRATCH_DIR}/GRID_HASH"

# Record the STRATUM SCOPE this run was submitted under. combine.R and
# retry_failed.sh read these rather than today's (possibly re-profiled)
# config/sizing.tsv, because the task -> unit mapping is a function of
# (stratum, reps_per_job, task_base) and re-deriving it from a mutated sizing file
# would remap tasks onto different units and surface as an unexplained coverage
# failure.
{
  printf 'TOTAL_UNITS=%s\nTOTAL_TASKS=%s\nSTRATA=%s\n' \
    "${TOTAL_UNITS}" "${TOTAL_TASKS}" "${PS_NAME[*]}"
  printf 'SMOKE=%s\n' "${SMOKE}"
} > "${SCRATCH_DIR}/SCOPE.env"
{
  printf 'stratum\ttotal_units\treps_per_job\ttotal_tasks\ttask_base\n'
  for i in "${!PS_NAME[@]}"; do
    printf '%s\t%s\t%s\t%s\t%s\n' "${PS_NAME[$i]}" "${PS_UNITS[$i]}" \
      "${PS_RPJ[$i]}" "${PS_TASKS[$i]}" "${PS_BASE[$i]}"
  done
} > "${SCRATCH_DIR}/SCOPE.tsv"

# Point logs/latest at this run (convenient log discovery from the study dir).
mkdir -p "${STUDY_DIR}/logs"
ln -sfn "${LOG_DIR}" "${STUDY_DIR}/logs/latest"

# --- Submit one array per stratum, chunked at <= MAX_ARRAY_SIZE ---------------
declare -a JOB_IDS=()
submitted=0
for i in "${!PS_NAME[@]}"; do
  s="${PS_NAME[$i]}"
  stratum_tasks="${PS_TASKS[$i]}"
  base="${PS_BASE[$i]}"
  chunk_offset=0
  while (( chunk_offset < stratum_tasks )); do
    remaining=$(( stratum_tasks - chunk_offset ))
    chunk=$(( remaining < MAX_ARRAY_SIZE ? remaining : MAX_ARRAY_SIZE ))
    cap=$(( MAX_ARRAY_SIZE < chunk ? MAX_ARRAY_SIZE : chunk ))

    # Shell-exported, then a PLAIN --export=ALL. The combined
    # --export=ALL,KEY=value form is CANCELLED BY ROOT on O2 within seconds with
    # NO output written at all. Do not collapse this back into the flag.
    export STUDY_DIR="${STUDY_DIR}"
    export SCRATCH_DIR="${SCRATCH_DIR}"
    export REPS_PER_JOB="${PS_RPJ[$i]}"
    export ARRAY_OFFSET=$(( base + chunk_offset ))
    export STRATUM="${s}"
    export TASK_BASE="${base}"
    export ROWS="${PS_ROWS[$i]}"
    jobid=$(sbatch --parsable \
      --array=1-"${chunk}"%"${cap}" \
      --time="${PS_TIME[$i]}" \
      --mem="${PS_MEM[$i]}G" \
      --output="${LOG_DIR}/task_%A_%a.out" \
      --error="${LOG_DIR}/task_%A_%a.err" \
      --export=ALL \
      "${SLURM_DIR}/array.slurm")

    JOB_IDS+=("${jobid}")
    echo "  submitted array ${jobid}: stratum ${s}, global tasks $((base+chunk_offset+1))-$((base+chunk_offset+chunk)) (%${cap}, --time ${PS_TIME[$i]}, --mem ${PS_MEM[$i]}G)"
    chunk_offset=$(( chunk_offset + chunk ))
    submitted=$(( submitted + chunk ))
  done
done

echo "Submitted ${submitted} tasks across ${#JOB_IDS[@]} array job(s)."

if (( SMOKE == 1 )); then
  cat <<EOF

SMOKE PROBE submitted. When it finishes, size EACH STRATUM from its REAL timings:
  bash slurm/monitor.sh ${RUN_ID}
  Rscript slurm/profile_timing.R --study-dir . --from-smoke-dir ${SCRATCH_DIR} --target-hours 2
  bash slurm/submit.sh
EOF
  exit 0
fi

# --- Write MANIFEST.submitted.md ---------------------------------------------
{
  echo "# Run Manifest -- ${STUDY_NAME}"
  echo
  echo "- run-id: \`${RUN_ID}\`"
  echo "- git SHA (package): \`${GIT_SHA}\`"
  echo "- code hash: \`$(cat "${SCRATCH_DIR}/GRID_HASH")\`"
  echo "- submitted: $(date '+%F %T %Z')"
  echo "- total: ${TOTAL_TASKS} tasks, ${TOTAL_UNITS} units"
  echo "- scratch dir: \`${SCRATCH_DIR}\`"
  echo "- log dir: \`${LOG_DIR}\` (also \`./logs/latest\`)"
  echo "- SLURM job ids: ${JOB_IDS[*]}"
  echo
  echo "| stratum | units | units/task | tasks | task base | --time | --mem |"
  echo "|---|---|---|---|---|---|---|"
  for i in "${!PS_NAME[@]}"; do
    echo "| ${PS_NAME[$i]} | ${PS_UNITS[$i]} | ${PS_RPJ[$i]} | ${PS_TASKS[$i]} | ${PS_BASE[$i]} | ${PS_TIME[$i]} | ${PS_MEM[$i]}G |"
  done
  echo
  echo "## Next steps"
  echo '```bash'
  echo "bash slurm/monitor.sh                 # watch progress / find failed tasks"
  echo "Rscript slurm/combine.R --run-id ${RUN_ID} \\"
  echo "  --scratch-dir ${SCRATCH_DIR} --study-dir ${STUDY_DIR}"
  echo "bash slurm/clean.sh                   # remove superseded runs when done"
  echo '```'
} > "${STUDY_DIR}/MANIFEST.submitted.md"

echo "Wrote ${STUDY_DIR}/MANIFEST.submitted.md (merge into MANIFEST.md)"
echo "Monitor with: bash slurm/monitor.sh"
