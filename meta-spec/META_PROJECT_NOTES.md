# Meta-Project Notes

Keep centralized notes on all projects worked on daily. These notes are intended to keep track of both the what and the why of all project work in a given day. The architecture is to have project-specific notes in project-specific folders, as well as a central notes repository that pulls from the project folders. 

## Location

**Default path:** `~/OneDrive-RANDCorporation/notes` (maintainer-specific; adopters should set their own path).

**Override:** Set `AGENT_ASSISTED_RESEARCH_META_NOTES` (or `WORK_LOG_PATH`) in your shell profile or `.env` to point to your meta-project notes directory if you use a different path.

## Recommended structure

```
notes/
├── daily/                    # Daily entry files (YYYY-MM-DD.md)
├── projects/
│   └── project-directories.md # Canonical list: project name → directory path
├── templates/                 # daily-entry.md, daily-entry-simple.md
├── SESSION_NOTES.md           # How session notes in each project feed daily notes
├── README.md                  # Workflow for daily notes
└── new-entry.sh               # Script to create today's daily entry
```

## How it works

- **Session notes** live **inside each project** at `<project_root>/session_notes/` (e.g. `session_notes/YYYY-MM-DD.md`). The workflow writes to them at the same three triggers as session logs (post-plan, incremental, end-of-session). See `.claude/rules/session-notes.md`.
- **Daily notes** are built from those session notes: for each project you worked on, read that project's `session_notes/` for the day and fill in the "Projects Worked On" sections of the daily note at the path above.
- **Project list:** `projects/project-directories.md` lists project names and their directory paths so you (or an agent) can resolve project names to paths when building daily notes or reading session notes.

## In agent-assisted-research-meta

This repo does **not** store daily notes or the project list. The `notes/` folder in agent-assisted-research-meta (if present) is only a pointer; see `notes/README.md`. When you clone agent-assisted-research-meta into a new project, set or use `AGENT_ASSISTED_RESEARCH_META_NOTES` so daily-note generation knows where to read and write.
