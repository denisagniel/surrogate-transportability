#!/bin/bash
# PreCompact hook — display the context-survival checklist before compaction.
#
# HISTORY / WHY THIS LOOKS LIKE THIS
#
# Until 2026-09-01 this hook also APPENDED a compaction marker to the session log it
# picked via `ls -t "$LOG_DIR"/*.md | head -1` — the most recently MODIFIED file, which
# has nothing to do with the current session. That was destructive and wrong:
#
#   1. It wrote session-A markers into session-B's log, because mtime-latest is whatever
#      finished last, not what is being worked on now.
#   2. Its own append refreshed that file's mtime, making it a permanent attractor. One
#      file accumulated 26 markers from 26 unrelated compaction events.
#   3. log-reminder.py (Stop hook) independently selected the same mtime-latest file and
#      told the agent to append there — so the two hooks formed a closed feedback loop,
#      each reinforcing the other's wrong target.
#
# Measured damage before removal: 393 markers across 124 session-log files in 14 projects.
#
# Diagnosis and remediation plan:
#   missing-data-did/quality_reports/plans/2026-09-01_session-logging-architecture-remediation.md
#
# RULE: this hook does not write to any file. A PreCompact hook cannot know which session
# record is current, so it must not guess. It informs the agent and exits.
#
# Fires under BOTH runtimes: Claude Code natively, and omo via its claude-code-hooks
# module (which reads .claude/settings.json and dispatches PreCompact). Verified 2026-09-01.
#
# NO jq DEPENDENCY — DELIBERATE. jq is NOT INSTALLED on this machine (verified 2026-09-01:
# absent from PATH, /opt/homebrew/bin, /usr/local/bin, /usr/bin). That is the real reason
# every marker this hook ever wrote rendered its trigger as literally "()" — `jq -r` was
# not running at all, so TRIGGER was always empty. It was never a jq `//` semantics issue.
# Any hook here that shells out to jq is silently inert: see notify.sh (degraded messages)
# and protect-files.sh (reads .tool_name via jq, gets "", exits 0 — so it has never blocked
# a single write). Both still affected as of this writing; tracked separately.
#
# The trigger label is cosmetic. The checklist is the job. So a missing parser degrades the
# label and still prints the checklist — it does not abort the hook. Failing loud matters
# for real faults, not for an unavailable decoration.

set -uo pipefail

INPUT=$(cat)

# Best-effort trigger extraction. python3 first (present), jq second (currently absent),
# then an explicit "unavailable" — never silently blank, never a bare "()".
TRIGGER="unavailable"
if command -v python3 >/dev/null 2>&1; then
  PARSED=$(printf '%s' "$INPUT" | python3 -c '
import json,sys
try:
    v=(json.load(sys.stdin) or {}).get("trigger") or ""
except Exception:
    v=""
print(v.strip() or "unknown")
' 2>/dev/null) && [ -n "$PARSED" ] && TRIGGER="$PARSED"
elif command -v jq >/dev/null 2>&1; then
  PARSED=$(printf '%s' "$INPUT" | jq -r 'if (.trigger // "") == "" then "unknown" else .trigger end' 2>/dev/null) \
    && [ -n "$PARSED" ] && TRIGGER="$PARSED"
fi

echo "=== CONTEXT COMPRESSION IMMINENT (trigger: $TRIGGER) ==="
echo ""
echo "Context Survival Checklist:"
echo "  [ ] MEMORY.md updated with [LEARN] entries"
echo "  [ ] Today's session record current (last 10 minutes)"
echo "  [ ] Active plan saved to quality_reports/plans/"
echo "  [ ] Open questions documented"
echo ""
echo "Append to today's session record NOW if it is stale — this hook will not do it"
echo "for you, and it cannot tell which file is yours."
echo ""

exit 0
