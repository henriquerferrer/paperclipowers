# Upstream Provenance — verification-before-completion

**Stage introduced:** Stage 1
**Adaptation type:** Mechanical substitution (1 line)
**Last synced:** 2026-04-13
**Upstream base commit:** 6f204930537670d9173aed20e96b699799ee6c31
**Upstream source paths:**
- `skills/verification-before-completion/SKILL.md`

## Edits applied

1. **SKILL.md line 22** — replaced "in this message" with "in this heartbeat execution" (design spec §5.1).

## Update procedure

When upstream changes `skills/verification-before-completion/`, run `scripts/check-upstream-drift.sh verification-before-completion`. If changes occur outside line 22, inspect and re-port manually. If only the substituted line changed, reapply the substitution.

This skill has low drift risk — upstream is mostly model-agnostic and the single adaptation is trivially re-appliable.
