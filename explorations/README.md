# Explorations

Research sandbox for experimental analyses, quick prototypes, and exploratory work.

See [.claude/rules/exploration-folder-protocol.md](../.claude/rules/exploration-folder-protocol.md) and
[.claude/rules/exploration-fast-track.md](../.claude/rules/exploration-fast-track.md) for usage guidelines.

## When to use explorations/
- Testing new simulation scenarios before adding to sims/
- Prototyping package functions before integration
- Ad-hoc analyses and diagnostic checks
- Experimental visualizations
- Exploring referee comments or new ideas
- Quick proof-of-concept implementations

## Organization
- Work here is ephemeral and not tracked in git (see .gitignore)
- Production code lives in package/ or sims/
- Successful explorations get promoted to package or simulation scripts
- Failed explorations can be deleted or archived

## Fast-track Protocol
For quick iterations on exploratory code, see `.claude/rules/exploration-fast-track.md`:
- Fast iteration cycle for experimental work
- Quality bar can be lower than production code (60-70/100 acceptable)
- Focus on learning and discovery, not polish

## Moving to Production
When an exploration is successful:
1. **For R functions:** Refactor and add to package/R/ with roxygen2 documentation
2. **For simulations:** Add to sims/scripts/ and sims/config/scenarios.yaml
3. **For analyses:** Document in session_notes/ and methods/
4. **For visualizations:** Integrate into sims/ with RAND style (randplot)

## Current Explorations
(Add active exploration directories and their purposes here)
