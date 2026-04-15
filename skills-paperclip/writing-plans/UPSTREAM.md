# Upstream Provenance — writing-plans

**Stage introduced:** Stage 5
**Adaptation type:** HEAVY REWRITE — Paperclip plan is a contract (consumed by task-orchestration + Reviewer), not a step-by-step scaffold for a CLI engineer.
**Last synced:** 2026-04-14
**Upstream base commit:** 3f80f1c769d8a172ee9803d049253f15fbe4895b
**Upstream source paths:**
- `skills/writing-plans/SKILL.md` (152 lines)
- `skills/writing-plans/plan-document-reviewer-prompt.md` (49 lines — NOT ported; Reviewer uses `code-review/reviewer-prompt.md`)

## Merger map

| Upstream content | Destination in paperclipowers | Rationale |
|---|---|---|
| SKILL.md: "Overview" | `writing-plans/SKILL.md` § intro (rewritten: "concrete contract, not bite-sized CLI steps") | Same intent; different consumption model |
| SKILL.md: "Scope Check" | `writing-plans/SKILL.md` § Scope Check (adapted to comment back to board) | CLI has user-dialogue; Paperclip has issue comments + assignee PATCH |
| SKILL.md: "File Structure" section | `writing-plans/SKILL.md` § Plan Document Structure > File Structure subsection | Retained as authoring guidance |
| SKILL.md: "Bite-Sized Task Granularity" | DROPPED from writing-plans, moved to task-orchestration's subtask templates | Bite-sized steps are the Engineer's lens; plan-level granularity is slice-level |
| SKILL.md: "Plan Document Header" | `writing-plans/SKILL.md` § Plan Document Structure § Overview + Architecture | Distilled |
| SKILL.md: "Task Structure" (full TDD/commit per task) | DROPPED | Task-level TDD narration lives in Engineer's skills (test-driven-development) + task-orchestration subtask templates |
| SKILL.md: "No Placeholders" | `writing-plans/SKILL.md` § Plan Quality Checklist (item 3: schema concreteness; item 5: testable acceptance) | Same anti-pattern guard, restated for schema discipline |
| SKILL.md: "Self-Review" | `writing-plans/SKILL.md` § Plan Quality Checklist | Retained |
| SKILL.md: "Execution Handoff" / "Subagent-Driven vs Inline" | Replaced by § Integration (task-orchestration is the only path) | Paperclip subtask graph IS the execution model |
| SKILL.md: "Save plans to docs/superpowers/plans/..." | Replaced by `PUT /api/issues/<id>/documents/plan` | Plan lives on the issue |
| plan-document-reviewer-prompt.md | NOT ported | Reviewer uses code-review/reviewer-prompt.md (Trigger 2: plan review) |

## Design deviations documented here (not in design spec)

1. **Concrete schemas per slice are REQUIRED.** Spec §2.2 called for "concrete TypeScript/JSON schemas"; this skill enforces it as a checklist item. A plan without concrete schemas is rejected at self-review.
2. **`needsDesignPolish: boolean` per slice.** Stage 6 hook baked into Stage 5 output. Stage 5 plans hardcode `false`; the field is present so `task-orchestration` can parse it without a schema migration when Stage 6 flips it live on UI slices.
3. **Plan document consumption:** the Tech Lead's NEXT heartbeat (on board approval) reads `.planDocument.body` via `task-orchestration`. Upstream's plan is read by a human; Paperclip's plan is read by a skill.
4. **No inline code per task.** Upstream's plan has full code blocks per step (the Engineer's implementation narrated); Paperclip's plan stops at slice schemas. The subtask description (task-orchestration) expands to concrete test cases and implementation hints.
5. **Scope-overflow comment instead of brainstorming-decomposition pointer.** If the spec slipped through PM's decomposition check, Tech Lead flags it back to the board rather than re-invoking brainstorming. Tech Lead does not run PM skills.

## Resolved design decisions

- **Plan lives on the issue, not the filesystem.** Consistent with the `spec` document convention.
- **Stage 6 Designer integration is a flag, not a structural rewrite.** Plans emitted in Stage 5 have `needsDesignPolish: false` on every slice; Stage 6 flips the flag per-slice and hires the Designer. No Stage 5 skill changes needed for Stage 6.

## Update procedure

When upstream changes `skills/writing-plans/`:

1. `scripts/check-upstream-drift.sh writing-plans`
2. Schema-contract discipline (concrete types) is NOT negotiable — don't absorb upstream changes that weaken it.
3. If upstream adds a new plan-section type (e.g., "rollback narration"), integrate into `writing-plans/SKILL.md` § Plan Document Structure.
4. Ignore upstream changes to bite-sized TDD steps or execution-handoff — those concepts live elsewhere in paperclipowers.

Drift risk: MEDIUM. Upstream evolves for CLI-engineer UX; schema-discipline keeps Paperclip plans machine-consumable and must not erode.
