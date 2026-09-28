#!/bin/bash
# =============================================================================
# submit.sh -- mint a run-id, preflight, and submit the "lambda-sweep" array(s)
# =============================================================================
# Run ON O2 (a login node is fine -- sbatch only queues). Mirrors
# simulations/canonical-validation/slurm/submit.sh, plus:
#
#   * REP SCOPE. This study declares TOTAL_REPS = 40 but executes reps 1-20, and
#     reps 1-20 are NOT a contiguous unit range (see run_replication.R header).
#     REP_FROM/REP_TO come from config/sizing.env, are exported to the array, and
#     are recorded in the scratch dir's REP_SCOPE file so combine.R can verify
#     that the result set was produced under the scope it is being asked to
#     assert coverage for.
#
#   * --smoke N. Submits a REAL sbatch array of N one-unit tasks against a
#     throwaway smoke run-id, to measure per-unit wall time ON THE CLUSTER.
#     This is mandatory before sizing: canonical-validation's own history shows
#     local profiling underestimated real O2 per-unit cost by ~3.8x (local median
#     61.4 s/unit vs 191.8-254.6 s/unit observed on O2), which is the difference
#     between a 3-hour task and a timeout. Never size from a local number.
#
# Usage:
#   bash slurm/submit.sh                # full run, from config/sizing.env
#   bash slurm/submit.sh --smoke 8      # real-array timing probe, 8 x 1 unit
#   bash slurm/submit.sh --dry-run      # print the plan, submit nothing
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
STUDY_NAME="lambda-sweep"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDY_DIR="$(dirname "${SLURM_DIR}")"

SMOKE_N=0
DRY_RUN=0
while (( $# )); do
  case "$1" in
    --smoke)   SMOKE_N="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# =============================================================================
# PREFLIGHT (S3): fail loudly BEFORE launching the array.
# =============================================================================
preflight_fail() { echo "PREFLIGHT FAILED: $*" >&2; exit 1; }

# (a) Required staged input files. lambda-sweep is self-contained: DGP params and
# the lambda=0.3 reference rho live in the package, and the interior-regime truth
# is computed in closed form by R/cell_cates.R. No staged .rds inputs.
REQUIRED_INPUTS=(
)
for f in ${REQUIRED_INPUTS[@]+"${REQUIRED_INPUTS[@]}"}; do
  [[ -e "${f}" ]] || preflight_fail "required input not found: ${f}"
done

# (b) Science files must all be present -- run_replication.R sources five of them
# and _code_hash.R hashes the same five.
for f in config/grid.R R/cell_cates.R R/dgp.R R/estimators.R R/run_one.R; do
  [[ -f "${STUDY_DIR}/${f}" ]] || preflight_fail "missing study source: ${f}"
done

# (c) optparse checked ONCE here rather than N times inside the array.
Rscript -e 'if (!requireNamespace("optparse", quietly=TRUE)) stop("optparse not installed for this R"); cat("preflight: optparse OK\n")' \
  || preflight_fail "optparse missing from ${R_LIBS_USER}"

# (d) Installed-package freshness. A forgotten rebuild means the cluster runs
# STALE code. Verify the project package is installed, is at least as new as the
# working tree's DESCRIPTION, and actually exposes the functions this study calls.
PKG_NAME="surrogateTransportability"
PKG_MIN_VERSION=$(grep -m1 '^Version:' "${STUDY_DIR}/../../DESCRIPTION" 2>/dev/null | sed 's/^Version:[[:space:]]*//')
Rscript -e "
  pkg <- '${PKG_NAME}'; want <- '${PKG_MIN_VERSION}'
  if (!requireNamespace(pkg, quietly = TRUE))
    stop(sprintf('project package %s is NOT installed on this node -- R CMD INSTALL it first.', pkg))
  if (nzchar(want) && utils::packageVersion(pkg) < want)
    stop(sprintf('installed %s %s < working-tree %s -- rebuild/reinstall before submitting.', pkg, utils::packageVersion(pkg), want))
  need <- c('tv_ball_correlation_IF_adaptive','sample_tv_ball','canonical_dgp_params','generate_dgp_data')
  miss <- need[!vapply(need, function(f) exists(f, where = asNamespace(pkg), inherits = FALSE), logical(1))]
  if (length(miss)) stop(sprintf('installed %s lacks: %s', pkg, paste(miss, collapse=', ')))
  cat(sprintf('preflight: %s %s OK (all %d required functions present)\n', pkg, utils::packageVersion(pkg), length(need)))
" || preflight_fail "project package '${PKG_NAME}' missing, stale, or incomplete (see message above)."
echo "Preflight OK."

# --- Load sizing / rep scope --------------------------------------------------
SIZING_ENV="${STUDY_DIR}/config/sizing.env"
ROWS=""
if (( SMOKE_N > 0 )); then
  # A smoke probe needs no sizing file -- that is the point: it EXISTS to produce
  # the number sizing is computed from. One unit per task, generous wall time.
  REP_FROM=1; REP_TO=20
  REPS_PER_JOB=1
  TOTAL_TASKS="${SMOKE_N}"
  TOTAL_UNITS="${SMOKE_N}"
  MAX_ARRAY_SIZE=1000; MAX_CONCURRENT_JOBS=10000; CONCURRENCY_CAP="${SMOKE_N}"
  WALLTIME="0-01:00:00"     # deliberately loose: an unsized probe must not time out
  MEM_GB=4

  # Choose the probe rows DELIBERATELY, not contiguously. The rep-filtered table is
  # ordered config-major, so tasks 1..8 sliced contiguously would ALL be config 1
  # (dgp1 at the smallest lambda) and would size the array off one corner of the
  # grid. Instead straddle both axes that plausibly drive cost: the cheap stress
  # DGP (dgp5) and the expensive one (dgp1, ~1.6x dgp5 locally), at the smallest
  # and largest lambda. Sizing then uses the MAXIMUM observed cost, not a mean
  # over an unrepresentative corner.
  ROWS=$(Rscript -e "
    source('${STUDY_DIR}/config/grid.R')
    ut <- unit_table()
    t  <- ut[ut\$rep_id >= ${REP_FROM} & ut\$rep_id <= ${REP_TO}, ]
    t  <- t[order(t\$unit), ]
    t\$row <- seq_len(nrow(t))
    lam <- range(LAMBDA_GRID)
    # one row per (dgp, extreme lambda) cell, rep 1; recycled if --smoke N is larger
    want <- expand.grid(dgp = c('dgp1','dgp2','dgp4','dgp5'), lambda = lam,
                        stringsAsFactors = FALSE)
    idx <- vapply(seq_len(nrow(want)), function(i) {
      h <- t\$row[t\$dgp == want\$dgp[i] & abs(t\$lambda - want\$lambda[i]) < 1e-12 & t\$rep_id == 1L]
      if (!length(h)) stop('no row for ', want\$dgp[i], ' lambda ', want\$lambda[i])
      h[1]
    }, numeric(1))
    idx <- unique(idx)
    n <- min(${SMOKE_N}, length(idx))
    cat(paste(idx[seq_len(n)], collapse = ','))
  ") || preflight_fail "could not compute smoke probe rows"
  # Honour the real count in case fewer distinct cells exist than --smoke asked for.
  TOTAL_TASKS=$(awk -F, '{print NF}' <<< "${ROWS}")
  TOTAL_UNITS="${TOTAL_TASKS}"
  CONCURRENCY_CAP="${TOTAL_TASKS}"
  echo "Smoke probe rows (grid-straddling, rep 1): ${ROWS}"
else
  [[ -f "${SIZING_ENV}" ]] || preflight_fail "${SIZING_ENV} not found. Size from a REAL O2 smoke run first: bash slurm/submit.sh --smoke 8"
  # shellcheck disable=SC1090
  source "${SIZING_ENV}"
  : "${TOTAL_TASKS:?}" "${REPS_PER_JOB:?}" "${MAX_ARRAY_SIZE:?}" \
    "${MAX_CONCURRENT_JOBS:?}" "${CONCURRENCY_CAP:?}" "${WALLTIME:?}" "${MEM_GB:?}" \
    "${REP_FROM:?}" "${REP_TO:?}" "${TOTAL_UNITS:?}"
fi

# Cross-check the declared unit count against what the grid actually yields for
# this rep scope, so a hand-edited sizing.env cannot silently under-cover.
ACTUAL_UNITS=$(Rscript -e "
  source('${STUDY_DIR}/config/grid.R')
  ut <- unit_table()
  cat(sum(ut\$rep_id >= ${REP_FROM} & ut\$rep_id <= ${REP_TO}))
")
if (( SMOKE_N == 0 )) && [[ "${ACTUAL_UNITS}" != "${TOTAL_UNITS}" ]]; then
  preflight_fail "sizing.env TOTAL_UNITS=${TOTAL_UNITS} but grid x reps ${REP_FROM}-${REP_TO} yields ${ACTUAL_UNITS}. Re-run profile_timing.R."
fi

# --- Run identity -------------------------------------------------------------
GIT_SHA="$(git -C "${STUDY_DIR}" rev-parse --short HEAD 2>/dev/null || echo nogit)"
RUN_ID="$(date '+%Y%m%d-%H%M%S')_${GIT_SHA}"
(( SMOKE_N > 0 )) && RUN_ID="smoke-${RUN_ID}"

# Scratch: intermediate task files + logs (NOT backed up). Home holds only the
# final combined result (written later by combine.R).
SCRATCH_ROOT="/n/scratch/users/${HMS_ID:0:1}/${HMS_ID}/${PROJECT_NAME}/${STUDY_NAME}"
SCRATCH_DIR="${SCRATCH_ROOT}/${RUN_ID}"
LOG_DIR="${SCRATCH_DIR}/logs"

echo "=============================================================="
echo " study        : ${STUDY_NAME}   (project ${PROJECT_NAME})"
echo " run-id       : ${RUN_ID}$( (( SMOKE_N > 0 )) && echo '   [SMOKE TIMING PROBE]')"
echo " rep scope    : reps ${REP_FROM}-${REP_TO} of TOTAL_REPS declared in grid.R"
echo " total tasks  : ${TOTAL_TASKS}  (${REPS_PER_JOB} units/task, ${TOTAL_UNITS} units)"
echo " scratch      : ${SCRATCH_DIR}"
echo " logs         : ${LOG_DIR}   (also ./logs/latest)"
echo " --time ${WALLTIME}  --mem ${MEM_GB}G  concurrency %${CONCURRENCY_CAP}"
echo "=============================================================="

if (( DRY_RUN == 1 )); then
  echo "--dry-run: nothing submitted."
  exit 0
fi

mkdir -p "${SCRATCH_DIR}" "${LOG_DIR}"

# Record the study source-code hash so combine.R can detect stale code, and the
# rep scope so it can detect a mid-run rescope. ONE definition of the hash lives
# in slurm/_code_hash.R -- do not inline a second copy here.
Rscript "${SLURM_DIR}/_code_hash.R" "${STUDY_DIR}" > "${SCRATCH_DIR}/GRID_HASH"
printf 'REP_FROM=%s\nREP_TO=%s\nTOTAL_UNITS=%s\nREPS_PER_JOB=%s\nTOTAL_TASKS=%s\n' \
  "${REP_FROM}" "${REP_TO}" "${TOTAL_UNITS}" "${REPS_PER_JOB}" "${TOTAL_TASKS}" \
  > "${SCRATCH_DIR}/REP_SCOPE"

# Point logs/latest at this run (convenient log discovery from the study dir).
mkdir -p "${STUDY_DIR}/logs"
ln -sfn "${LOG_DIR}" "${STUDY_DIR}/logs/latest"

# --- Chunk into arrays of <= MAX_ARRAY_SIZE, submit in throttled waves --------
ARRAYS_PER_WAVE=$(( MAX_CONCURRENT_JOBS / MAX_ARRAY_SIZE ))
if (( ARRAYS_PER_WAVE < 1 )); then ARRAYS_PER_WAVE=1; fi

submitted=0
offset=0
wave_index=0
arrays_in_wave=0
prev_wave_last_jobid=""
this_wave_last_jobid=""
declare -a JOB_IDS=()

while (( offset < TOTAL_TASKS )); do
  remaining=$(( TOTAL_TASKS - offset ))
  chunk=$(( remaining < MAX_ARRAY_SIZE ? remaining : MAX_ARRAY_SIZE ))
  cap=$(( CONCURRENCY_CAP < chunk ? CONCURRENCY_CAP : chunk ))

  dep_args=()
  if (( arrays_in_wave == 0 )) && [[ -n "${prev_wave_last_jobid}" ]]; then
    dep_args=(--dependency=afterany:"${prev_wave_last_jobid}")
  fi

  # Shell-exported, then a PLAIN --export=ALL. The combined --export=ALL,KEY=value
  # form is CANCELLED BY ROOT on O2 within seconds with NO output written at all.
  # Do not collapse this back into the flag.
  export STUDY_DIR="${STUDY_DIR}"
  export SCRATCH_DIR="${SCRATCH_DIR}"
  export REPS_PER_JOB="${REPS_PER_JOB}"
  export ARRAY_OFFSET="${offset}"
  export REP_FROM="${REP_FROM}"
  export REP_TO="${REP_TO}"
  export ROWS="${ROWS}"
  jobid=$(sbatch --parsable \
    --array=1-"${chunk}"%"${cap}" \
    --time="${WALLTIME}" \
    --mem="${MEM_GB}G" \
    --output="${LOG_DIR}/task_%A_%a.out" \
    --error="${LOG_DIR}/task_%A_%a.err" \
    ${dep_args[@]+"${dep_args[@]}"} \
    --export=ALL \
    "${SLURM_DIR}/array.slurm")

  JOB_IDS+=("${jobid}")
  this_wave_last_jobid="${jobid}"
  echo "  submitted array job ${jobid}: global tasks $((offset+1))-$((offset+chunk)) (%${cap})"

  offset=$(( offset + chunk ))
  submitted=$(( submitted + chunk ))
  arrays_in_wave=$(( arrays_in_wave + 1 ))

  if (( arrays_in_wave >= ARRAYS_PER_WAVE )); then
    prev_wave_last_jobid="${this_wave_last_jobid}"
    wave_index=$(( wave_index + 1 ))
    arrays_in_wave=0
    echo "  --- wave ${wave_index} full (${ARRAYS_PER_WAVE} arrays); next wave waits on ${prev_wave_last_jobid} ---"
  fi
done

echo "Submitted ${submitted} tasks across ${#JOB_IDS[@]} array job(s)."

if (( SMOKE_N > 0 )); then
  cat <<EOF

SMOKE PROBE submitted. When it finishes, size the real array from its REAL timings:
  bash slurm/monitor.sh ${RUN_ID}
  Rscript slurm/profile_timing.R --study-dir . --from-smoke-dir ${SCRATCH_DIR} --target-hours 2
  bash slurm/submit.sh
EOF
  exit 0
fi

# --- Write MANIFEST.md --------------------------------------------------------
{
  echo "# Run Manifest -- ${STUDY_NAME}"
  echo
  echo "- run-id: \`${RUN_ID}\`"
  echo "- git SHA: \`${GIT_SHA}\`"
  echo "- code hash: \`$(cat "${SCRATCH_DIR}/GRID_HASH")\`"
  echo "- submitted: $(date '+%F %T %Z')"
  echo "- rep scope: reps ${REP_FROM}-${REP_TO} (of TOTAL_REPS declared in config/grid.R)"
  echo "- total tasks: ${TOTAL_TASKS} (${REPS_PER_JOB} units/task, ${TOTAL_UNITS} units)"
  echo "- --time: ${WALLTIME}   --mem: ${MEM_GB}G   concurrency: %${CONCURRENCY_CAP}"
  echo "- scratch dir: \`${SCRATCH_DIR}\`"
  echo "- log dir: \`${LOG_DIR}\` (also \`./logs/latest\`)"
  echo "- SLURM job ids: ${JOB_IDS[*]}"
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
