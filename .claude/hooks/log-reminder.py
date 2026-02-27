#!/usr/bin/env python3
"""
Log reminder hook - runs when stopping a Claude session.
Reminds about updating session logs and notes.
"""
import sys
from datetime import datetime

def main():
    """Print reminder about session logging."""
    date_str = datetime.now().strftime("%Y-%m-%d")

    print("\n📝 Session Logging Reminder:")
    print(f"   • Update session log in quality_reports/session_logs/")
    print(f"   • Update session note in session_notes/{date_str}.md")
    print(f"   • Save [LEARN] entries to MEMORY.md if corrected")
    return 0

if __name__ == "__main__":
    sys.exit(main())
