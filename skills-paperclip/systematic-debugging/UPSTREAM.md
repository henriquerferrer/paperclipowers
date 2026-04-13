# Upstream Provenance — systematic-debugging

**Stage introduced:** Stage 2
**Adaptation type:** Mechanical substitutions + one small section rewrite
**Last synced:** 2026-04-13
**Upstream base commit:** 6f204930537670d9173aed20e96b699799ee6c31
**Upstream source paths:**
- `skills/systematic-debugging/SKILL.md`
- `skills/systematic-debugging/root-cause-tracing.md` (verbatim)
- `skills/systematic-debugging/defense-in-depth.md` (verbatim)
- `skills/systematic-debugging/condition-based-waiting.md` (verbatim)
- `skills/systematic-debugging/condition-based-waiting-example.ts` (verbatim)
- `skills/systematic-debugging/find-polluter.sh` (+ 6-line Paperclip context comment)

## Edits applied

### SKILL.md

1. **Line 211** (Phase 4.5 escalation) — "Discuss with your human partner before attempting more fixes" → "Set `status: blocked`, reassign the subtask to the Tech Lead... Tech Lead may re-open with a more capable model via `assigneeAdapterOverrides.model`..." (encodes model-selection escalation semantics per design spec §5.1 + Paperclip feature commit `e4e56091`).
2. **Lines 234-243** — replaced entire "your human partner's Signals You're Doing It Wrong" section with "Signals from Inbound Comments" describing patterns visible in issue comment threads.
3. **Line 179** — cross-reference rewritten: `superpowers:test-driven-development` → `test-driven-development` (slug-only, portable).
4. **Lines 287-288** — two cross-references in the "Related skills" list rewritten to slug-only form.

### find-polluter.sh

5. **After line 4** — inserted 6-line comment block noting non-JS test-runner adaptation and multi-heartbeat bisection handling.

## Verbatim files (no edits)

- root-cause-tracing.md
- defense-in-depth.md
- condition-based-waiting.md
- condition-based-waiting-example.ts

If upstream edits any of these, the update is a simple `cp` from upstream — no re-adaptation needed.

## Update procedure

Run `scripts/check-upstream-drift.sh systematic-debugging`. For the verbatim files, any upstream change copies through. For SKILL.md, inspect whether upstream edits collide with the substituted regions. The "Signals from Inbound Comments" section is the most fragile — if upstream restructures that section, re-design the Paperclip-adapted equivalent.

Moderate drift risk. The section rewrite is substantial enough that a major upstream change there would require human review.
