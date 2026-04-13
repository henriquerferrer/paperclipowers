# Upstream Provenance — verification-before-completion

**Stage introduced:** Stage 1 (line 22), Stage 2 (line 111 — patched during Stage 2 behavioral validation after leak detection)
**Adaptation type:** Mechanical substitutions (2 lines)
**Last synced:** 2026-04-13
**Upstream base commit:** 6f204930537670d9173aed20e96b699799ee6c31
**Upstream source paths:**
- `skills/verification-before-completion/SKILL.md`

## Edits applied

1. **SKILL.md line 22** — replaced "in this message" with "in this heartbeat execution" (design spec §5.1).
2. **SKILL.md line 111** — replaced "- your human partner said \"I don't believe you\" - trust broken" with "- Reviewer or board posted \"I don't believe you\" comment - trust broken". Discovered during Stage 2 runtime CLI-ism grep; Stage 1's adaptation scope missed this bullet in the "Why This Matters" failure-memories list.

## Update procedure

When upstream changes `skills/verification-before-completion/`, run `scripts/check-upstream-drift.sh verification-before-completion`. If changes occur outside line 22, inspect and re-port manually. If only the substituted line changed, reapply the substitution.

This skill has low drift risk — upstream is mostly model-agnostic and the single adaptation is trivially re-appliable.
