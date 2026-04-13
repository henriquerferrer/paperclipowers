# Upstream Provenance — test-driven-development

**Stage introduced:** Stage 2
**Adaptation type:** Mechanical substitutions (5 total across 2 files)
**Last synced:** 2026-04-13
**Upstream base commit:** 6f204930537670d9173aed20e96b699799ee6c31
**Upstream source paths:**
- `skills/test-driven-development/SKILL.md`
- `skills/test-driven-development/testing-anti-patterns.md`

## Edits applied

### SKILL.md

1. **Line 24** — "Exceptions (ask your human partner):" → "Exceptions (escalate to Tech Lead via reassignment + comment):"
2. **Line 346** ("When Stuck" table, "Don't know how to test" row) — "Ask your human partner." → "Set `status: blocked` and reassign to Tech Lead with comment..."
3. **Line 371** ("Final Rule") — "No exceptions without your human partner's permission." → "No exceptions without Tech Lead approval via reassignment + comment..."

### testing-anti-patterns.md

4. **Line 37** — "**your human partner's correction:**" → "**Self-check question:**"
5. **Line 259** — "**your human partner's question:**" → "**Self-check question:**"

## Update procedure

Run `scripts/check-upstream-drift.sh test-driven-development`. If upstream changed any of the substituted lines, merge manually. If upstream added new content referencing "your human partner," apply the same substitution pattern. If upstream restructured sections, review before porting.

Low-to-moderate drift risk. Upstream commits on TDD in recent months have been minor polish, not structural changes.
