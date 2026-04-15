# Upstream Provenance — pipeline-dispatcher

**Stage introduced:** Stage 5
**Adaptation type:** GREENFIELD — no line-level port. Replaces upstream `using-superpowers` wholesale because the underlying mechanism (Skill tool invocation, TodoWrite checklist) doesn't exist in Paperclip's heartbeat adapter.
**Last synced:** 2026-04-14
**Upstream base commit:** 8b1669269c51835168c98fd435a7af1e5f15ec12
**Upstream source paths (conceptually replaced, not ported):**
- `skills/using-superpowers/SKILL.md` (117 lines)

## Merger map

| Upstream content | Destination in paperclipowers | Rationale |
|---|---|---|
| using-superpowers: "Invoke relevant skills BEFORE any response" | `pipeline-dispatcher/SKILL.md` § How to Use This Skill (skills are pre-loaded, routing is the action) | CLI Claude must call `Skill` tool to load; Paperclip adapter pre-loads all desiredSkills into system prompt |
| using-superpowers: "Red Flags" + rationalization guards | Replaced by § Heartbeat-Mode Disciplines | Original guards target CLI-Claude rationalization ("I remember this skill" etc.); Paperclip agents rationalize differently (e.g., trying to invoke tools that don't exist) |
| using-superpowers: "Process skills first" priority | Replaced by § Role-to-Skill Matrix | Priority emerges from role, not skill category |
| using-superpowers: "Skill Types" (Rigid vs Flexible) | Dropped | Not actionable at dispatch time; the skill itself indicates its own rigidity |
| using-superpowers: Graphviz flow diagram | Dropped | Prose routing is sufficient |
| using-superpowers: "How to Access Skills" platform table | Dropped | Paperclip has one access model: adapter-injected |
| using-superpowers: "User Instructions" priority clause | Dropped | Paperclip has no synchronous user; board comments substitute |

## Design deviations documented here (not in design spec)

1. **Role disambiguation by agent name when `role: "engineer"` is overloaded.** Paperclip's role enum has no `tech_lead`, so Stage 4 used `role: "engineer"` for the Tech Lead. This skill's matrix disambiguates by agent name contains `tech-lead`. Spec §7 doesn't mandate a naming convention; this skill codifies one as an operator agreement.
2. **Stage 6 Designer row is reserved, not active.** Written in now because the skill is versioned; flipping it live in Stage 6 is a skill revision, not a rewrite.
3. **Reviewer's Trigger 3 (per-subtask review) is intentionally unwired in Stage 5.** The Reviewer wakes only at spec / plan / final-combined gates; per-subtask review is a Stage 7+ decision (scope simplification to prove the pipeline before adding per-slice review overhead).

## Resolved design decisions

- **Skills are adapter-injected, not tool-invoked.** Consistent with the Paperclip `claude_local` adapter's skill-materialization mechanism (confirmed at Stage 1 Task 4 runtime paths).
- **One dispatcher skill, all roles.** Alternative was per-role dispatcher skills; rejected as unnecessary duplication — the role matrix is small enough to live in one file.

## Update procedure

When upstream changes `skills/using-superpowers/`:

1. `scripts/check-upstream-drift.sh using-superpowers` (reports against the greenfield base; always non-zero diff after upstream change)
2. Read the diff. Most upstream changes will be about CLI mechanics (new tool, new invocation syntax) — not applicable.
3. If upstream adds a new discipline (e.g., a new anti-pattern for skill invocation), evaluate whether a Paperclip analog exists and integrate into § Heartbeat-Mode Disciplines.
4. If upstream adds a new skill category (Rigid/Flexible/something), evaluate skipping — Paperclip's skill-type taxonomy isn't surfaced at dispatch.

Drift risk: HIGH but IRRELEVANT. Upstream evolves for Claude Code CLI behaviour; Paperclip's routing model is stable. Check drift for awareness, rarely port.
