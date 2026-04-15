# Upstream Provenance — brainstorming

**Stage introduced:** Stage 5
**Adaptation type:** HEAVY REWRITE — structural reimplementation for Paperclip heartbeat model. Upstream content retained as conceptual anchor (clarifying-question-first, spec-before-plan gate, decomposition-on-scope-overflow); mechanism entirely replaced. Do not treat upstream changes as patches to apply.
**Last synced:** 2026-04-14
**Upstream base commit:** 9f04f0635114d09ca054778e2dd44942efd1c008
**Upstream source paths:**
- `skills/brainstorming/SKILL.md` (164 lines)
- `skills/brainstorming/spec-document-reviewer-prompt.md` (49 lines — NOT ported; Reviewer uses `code-review/reviewer-prompt.md`)
- `skills/brainstorming/visual-companion.md` (287 lines — DROPPED entirely; no browser in Docker)
- `skills/brainstorming/scripts/*` (DROPPED; visual-companion infrastructure)

## Merger map

| Upstream content | Destination in paperclipowers | Rationale |
|---|---|---|
| SKILL.md: "Overview" + HARD-GATE | `brainstorming/SKILL.md` § intro + HARD-GATE (retained; gate reworded to reference spec completeness instead of user approval) | Same structural intent; different approver |
| SKILL.md: "Checklist" (9 items inc. visual companion) | `brainstorming/SKILL.md` § When to Invoke + § The Process (flattened into three wake scenarios, visual-companion items dropped) | Heartbeat model has no TodoWrite; upstream's ordered checklist maps to per-wake branching |
| SKILL.md: "Process Flow" (graphviz) | Dropped | Graph rendered well in Claude Code but doesn't survive Paperclip runtime materialization; prose flow suffices |
| SKILL.md: "Understanding the idea" section | `brainstorming/SKILL.md` § First Wake + § Q&A Round | Same intent, adapted to comment-based Q&A |
| SKILL.md: "One question at a time" principle | Inverted in `brainstorming/SKILL.md` § First Wake + Q&A Round: "batch 2-3 per comment" | Heartbeat scheduler latency makes one-question-per-round prohibitively slow |
| SKILL.md: "Exploring approaches" | Dropped | Upstream pattern has PM proposing 2-3 technical approaches pre-design. For Paperclip, approach-level tradeoffs belong to the Tech Lead's plan (§3.1, Tech Lead role), not the PM's spec. |
| SKILL.md: "Presenting the design" + section-by-section approval | Collapsed into § Writing the Spec (one doc write, one status PATCH, Reviewer-gate approval) | Approval-per-section iteration is a synchronous-CLI artifact; async Paperclip gate is all-or-nothing |
| SKILL.md: "Spec Self-Review" | `brainstorming/SKILL.md` § Spec Quality Checklist | Retained as authoring discipline before PUT |
| SKILL.md: "User Review Gate" | Replaced by § Writing the Spec step 5 (PATCH to Reviewer, then board) — two-stage gate | Paperclip has no synchronous user; Reviewer gate is the first review, board is the second |
| SKILL.md: "Implementation" (invoke writing-plans) | Replaced by approval-gate handoff (Reviewer + board approve → board PATCHes to Tech Lead) | PM does not directly invoke Tech Lead; skills are per-agent, the pipeline routes via assignee |
| SKILL.md: "Visual Companion" (149-164) | DROPPED | No browser in Docker container (spec §4.1) |
| visual-companion.md (full file) | DROPPED | Browser-dependent |
| spec-document-reviewer-prompt.md | NOT ported | Reviewer already has `code-review/reviewer-prompt.md` which covers spec review as Trigger 1 |
| SKILL.md: "Key Principles" list | Dropped (absorbed into Red Flags + process) | Redundant |
| SKILL.md: "Working in existing codebases" | Dropped | PM's spec is feature-level, not codebase-navigation; Tech Lead's writing-plans handles codebase-fit decisions |

## Design deviations documented here (not in design spec)

1. **3-round Q&A cap with escalation.** Upstream has no max-round bound; Paperclip needs one because heartbeat cost + latency compounds. Cap at 3 rounds before either writing a spec with `## Open Questions` or escalating to `status: blocked`. Spec §6.1 mentions "3x rejection" loops; this is the analog for Q&A.
2. **`## Open Questions` and `## Non-Goals` sections are required.** Upstream's spec sections are advisory; Paperclip needs these explicit to make the Reviewer's scope-check actionable.
3. **Spec decomposition is a comment-level interaction, not an automatic checkbox.** Upstream's decomposition check is one of 9 checklist items completed silently; Paperclip surfaces it as an explicit board interaction (post comment proposing decomposition, wait for reply) because the decision is scope-critical.
4. **Reviewer mode uses `code-review/reviewer-prompt.md`, not the upstream `spec-document-reviewer-prompt.md`.** Upstream's separate reviewer prompt is redundant — `code-review`'s Trigger 1 (spec review) already handles this artifact with the same categorized-findings format. Stage 2 code-review skill was consolidated for exactly this purpose.

## Resolved design decisions

- **Drop visual companion entirely.** Spec §4.1 lists it as one of the five dropped items. Re-introducing it would require a headless-browser setup in the Paperclip container, which is out of scope across the entire paperclipowers roadmap.
- **Spec written to `spec` document, not a filesystem path.** Consistent with `planDocument` convention in `task-orchestration` (Stage 4) and the `../_shared/paperclip-conventions.md` document.
- **PM does NOT invoke `writing-plans` directly.** Skill invocation is per-agent; the Tech Lead runs `writing-plans`, not the PM. Pipeline routing via issue assignee is the handoff.

## Update procedure

When upstream changes `skills/brainstorming/`:

1. `scripts/check-upstream-drift.sh brainstorming`
2. If SKILL.md changed: read the diff, decide whether the change affects the rewritten `brainstorming/SKILL.md`. Most upstream changes won't — this is a greenfield rewrite, not a line-level port.
3. If a new design principle surfaces upstream that should apply to the PM (e.g., a new question-batching heuristic), integrate into `brainstorming/SKILL.md` as a new subsection.
4. If visual-companion.md or scripts change: ignore — we dropped these.

Drift risk: LOW. The upstream skill evolves for CLI UX; Paperclip PM mechanics are stable.
