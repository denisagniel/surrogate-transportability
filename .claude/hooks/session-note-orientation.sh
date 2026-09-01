#!/bin/bash
# UserPromptSubmit hook — ensure today's session record exists, and say so once.
#
# WHY UserPromptSubmit AND NOT SessionStart
#
# `SessionStart` is the intuitive choice and it is the wrong one. omo's claude-code-hooks
# module declares `SessionStart` in its ClaudeHooksConfig type and ships NO handler for it
# (verified 2026-09-01: handler modules exist for PreToolUse, PostToolUse, PreCompact, Stop and
# UserPromptSubmit only). A `SessionStart` entry therefore validates and silently does nothing
# under omo, which is the primary runtime here. `UserPromptSubmit` is implemented in both
# runtimes, so this hook fires in both.
#
# That near-miss is the reason for the standing rule: config-schema acceptance is not
# implementation evidence. Probe an event before depending on it.
#
# WHY THIS REPLACED A Stop HOOK
#
# Enforcement used to be a `Stop` hook that counted responses, then blocked and told the agent
# to append to `max(glob('*.md'), key=mtime)` in quality_reports/session_logs/. Wrong in
# principle: it measured mtime freshness rather than content, the agent producing the signal was
# the one being audited, and end-of-session blocking trains letter-compliance. It also always
# named work that had already finished, and formed a feedback loop with pre-compact.sh that
# wrote 393 stray markers into 124 files across 14 projects.
#
# The empirical finding that motivates this design: session_notes/ survived with zero automation
# and a dead downstream consumer, because it is READ at the start of the next session. So make
# the file present and say where it is. A read cannot be gamed; a counter can.
#
# STATELESS BY DESIGN
#
# No counter, no /tmp state file. Output is emitted only when this hook CREATES today's record,
# which happens at most once per project per day. Every later prompt finds the file and stays
# silent. Stale state was a contributing factor in the mechanism this replaces; there is none here.
#
# Full context:
#   missing-data-did/quality_reports/plans/2026-09-01_session-logging-architecture-remediation.md

set -uo pipefail

INPUT=$(cat)

# cwd comes from the hook payload; fall back to CLAUDE_PROJECT_DIR then $PWD. python3 is used
# rather than jq because this hook must not depend on jq being installed — jq was absent from
# this machine until 2026-09-01, which silently disabled every hook that shelled out to it.
CWD=""
if command -v python3 >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | python3 -c '
import json,sys
try:
    print((json.load(sys.stdin) or {}).get("cwd") or "")
except Exception:
    print("")
' 2>/dev/null) || CWD=""
fi
[ -n "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

NOTES_DIR="$CWD/session_notes"

# No session_notes/ means this project does not use the convention. Creating the directory would
# impose it on an unrelated repo, so do nothing.
[ -d "$NOTES_DIR" ] || exit 0

TODAY=$(date '+%Y-%m-%d')
NOTE="$NOTES_DIR/$TODAY.md"

[ -e "$NOTE" ] && exit 0

if ! printf '# Session Notes — %s\n\n## %s — <stem or short description>\n\n**Goal.** \n\n**What happened.** \n\n**Next.** \n' \
     "$TODAY" "$(date '+%H:%M')" > "$NOTE" 2>/dev/null; then
  echo "session-note-orientation.sh: could not create $NOTE" >&2
  exit 1
fi

echo "Created today's session record: session_notes/$TODAY.md — the single session record."
echo "Append at post-plan, on each decision, and before compaction."
echo "quality_reports/session_logs/ is retired and frozen."

# Workspace clutter scan, folded in from workspace-check.sh.template, which shipped for months
# as a .template with activation instructions naming an event that does not exist
# ("onSessionStart") and a value shape the runtime does not accept. It was never activated in
# any project, so it never once flagged anything — Rplots.pdf has been sitting in a project root
# untouched. Running it HERE, inside the once-per-day branch, gives it a live home without
# paying for a find() on every prompt.
CLUTTER=$(find "$CWD" -maxdepth 2 \
  \( -name "test_*.R" -o -name "test_*.py" -o -name "scratch_*.R" -o -name "temp_*.R" \
     -o -name "debug_*.R" -o -name "try_*.R" -o -name "*_old.*" -o -name "*_backup.*" \
     -o -name "*_copy.*" -o -name "Rplots.pdf" -o -name "*.Rout" -o -name ".DS_Store" \) \
  ! -path "*/tests/*" ! -path "*/test/*" ! -path "*/renv/*" 2>/dev/null | wc -l | tr -d ' ')

if [ "${CLUTTER:-0}" -gt 10 ]; then
  echo ""
  echo "Workspace clutter: $CLUTTER stray items at depth <=2 (test_/scratch_/temp_/debug_ scripts,"
  echo "*_old/*_backup/*_copy, Rplots.pdf, *.Rout, .DS_Store). Consider /cleanup-workspace —"
  echo "it archives with a manifest and deletes nothing."
fi

exit 0
