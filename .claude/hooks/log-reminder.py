#!/usr/bin/env python3
"""RETIRED 2026-09-01 - this hook is no longer wired and does nothing.

It was a Stop hook that counted agent responses since `quality_reports/session_logs/`
changed mtime, then blocked and told the agent to append to
`max(glob('*.md'), key=mtime)`. Three defects made it actively harmful:

1. WRONG DIRECTORY. It watched `quality_reports/session_logs/`, while the maintained
   session record is `session_notes/YYYY-MM-DD.md`. Measured compliance across the
   workspace: 1 of ~15 projects had the two streams in sync.

2. WRONG FILE, ALWAYS. Selecting by mtime names whatever was written LAST, which by
   construction is work that already finished - never the current session. It cannot
   name the current session's file, because no such file exists in that directory.

3. SELF-PERPETUATING. Its `reminded` flag cleared only when `session_logs/` mtime
   changed. Declining the wrong target left mtime untouched, so the identical wrong
   reminder returned next session. Complying was the only thing that silenced it.

It also formed a closed feedback loop with pre-compact.sh, which appended a compaction
marker to the same mtime-latest file - each hook reinforcing the other's wrong target.
Damage before removal: 393 stray markers across 124 session-log files in 14 projects.

Both hooks fired under BOTH runtimes: Claude Code natively, and omo via its
claude-code-hooks module, which reads .claude/settings.json and dispatches Stop.

Replacement (plan Stage 2): context injection at first user message via
`UserPromptSubmit` - implemented in both runtimes - reading or stubbing today's
session_notes file. NOT `SessionStart`: omo's config type accepts it but ships no
handler, so wiring it there is a silent no-op.

Diagnosis and remediation plan:
  missing-data-did/quality_reports/plans/2026-09-01_session-logging-architecture-remediation.md

Kept as a stub rather than deleted so the retirement is discoverable from the path that
~20 framework and project files still reference. Safe to delete once Stage 2 lands.
"""

import sys

if __name__ == "__main__":
    sys.exit(0)
