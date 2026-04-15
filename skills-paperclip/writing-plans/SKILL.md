---
name: writing-plans
description: Use when the Tech Lead has been assigned an issue with an approved spec document and no plan document. Writes a vertical-slice implementation plan with concrete schemas per slice and blockedByIssueIds dependency annotations, saves to planDocument on the issue, and hands off to Reviewer before board approval.
---

# Writing Plans — Tech Lead Skill

You are the Tech Lead. You have been assigned a feature issue whose `spec` document has already been approved (by the Reviewer + board). Your job is to author a concrete implementation plan — a vertical-slice decomposition with TypeScript/JSON schemas — save it to the issue's `plan` document, and hand off for approval before you start orchestrating.

This is the Paperclip adaptation of upstream `writing-plans`. Sibling skills: `task-orchestration` (runs after this one, consumes the plan's slice decomposition); `code-review` (the Reviewer's skill, evaluates your plan). See `../_shared/heartbeat-interaction.md` and `../_shared/paperclip-conventions.md` for the base conventions.

<HARD-GATE>
Do NOT decompose into subtasks, do NOT invoke task-orchestration, do NOT create any child issues until (1) you have written the plan to the `plan` document AND (2) it has been approved via the status+assignee gate (Reviewer → board → back to you with `status: in_progress`).
</HARD-GATE>

## When to Invoke

You wake on one of three signals:

1. **`issue_assigned`, feature issue with `spec` document present but `planDocument` null** — first wake after board approves the spec. Read the spec, write the plan. See § First Wake.
2. **`issue_assigned`, feature issue with both `spec` and `planDocument` present** — Reviewer or board bounced the plan back with findings. Revise. See § Revision.
3. **`issue_assigned`, feature issue with approved plan (status: in_progress, assignee: you)** — board has approved the plan. Stop using this skill; invoke `task-orchestration` instead. (The pipeline-dispatcher handles this routing.)

## The Process

### First Wake

1. Read the issue description (the board's original ask) and the `spec` document: `GET /api/issues/<id>/documents/spec`.
2. Read any ancestor issues (`.parentId` chain) for broader context.
3. Check the workspace: `git log --oneline -10` in your cwd to see what prior work exists. For the first feature in a fresh workspace, this may be empty.
4. Identify the vertical slices. A slice is a complete feature cut that produces working, testable software on its own (spec §2.1). For a small feature (≤3 slices), a linear chain works. For larger features, structure as a DAG using `blockedByIssueIds` candidate edges — one slice's output becomes another's input.
5. For each slice, draft the concrete schemas that will be its input/output contract (see § Concrete Schemas).
6. Draft the plan document content (see § Plan Document Structure).
7. Self-review against the Plan Quality Checklist (one pass, fix inline).
8. Write the plan: `PUT /api/issues/<issue-id>/documents/plan` with `{"format": "markdown", "body": "<plan content>", "title": "<feature> — Plan"}`. Use the curl `--data-binary @file` idiom.
9. PATCH the issue with ONE call: `{"status": "in_review", "assigneeAgentId": "<reviewer-agent-id>"}`. Combining fields is load-bearing (Stage 4 Anomaly 1).
10. Post a one-sentence announcement comment on the issue (no `@` mentions — assignee PATCH fires the proper wake).
11. Exit heartbeat.

### Revision

Analog of brainstorming's revision flow. Read Reviewer findings, revise the `plan` document via PUT (creates a new revision), PATCH back to `{"status": "in_review", "assigneeAgentId": "<reviewer-id>"}`. See `code-review` Part 2 for receiving-review discipline.

## Concrete Schemas — The Contract

Every slice in your plan must declare its concrete inputs and outputs. This is the difference between a Paperclip plan and an upstream CLI plan: the Engineer, running on a fresh Claude session in a separate heartbeat, cannot interrogate you for clarifications efficiently. The schema IS the contract. If the schema is wrong, the Engineer builds the wrong thing.

**Format (required for every slice):**

````markdown
### Slice N: <Short imperative title>

**Depends on slices:** [M, K] or "none"
**needsDesignPolish:** false

**Inputs:**
```ts
// TypeScript-flavor types; JSON Schema or any concrete type language acceptable
interface SliceNInput {
  foo: string;               // constraint: non-empty
  bar: number | null;        // nullable: yes
  items: Array<{ id: string; count: number }>;
}
```

**Outputs:**
```ts
interface SliceNOutput {
  persistedId: string;       // what the Engineer produces + stores
  computedFoo: number;
}
// OR, for filesystem outputs:
// - Creates: src/features/foo/index.ts exporting `handleFoo(input: SliceNInput): Promise<SliceNOutput>`
// - Creates: src/features/foo/foo.test.ts with N test cases
```

**Acceptance criteria:**
- <testable statement — specific enough to become a test>
- <testable statement>
- All tests in `<test-file-path>` pass
- Workspace `git status` clean before commit; commits squashed to one
````

Use TypeScript type syntax even for non-TS projects — it's a universal contract language. For Python projects, the Engineer translates at implementation time (TypedDict, dataclass, Pydantic) — that's cheap.

**`needsDesignPolish` flag.** Stage 5: always `false`. Stage 6 (Designer integration): set `true` on UI-surface slices where a design-polish follow-up should be scheduled after the Engineer's implementation lands. `task-orchestration` reads this flag per slice and creates a follow-up Designer subtask only when `true`. Stage 5 hardcodes `false` because the Designer agent doesn't exist yet.

## Plan Document Structure

The plan document written to the `plan` issue-document uses this structure:

```markdown
# <Feature Name> — Implementation Plan

## Overview

<1 paragraph — what this plan builds, aligned with the spec's Purpose.>

## Architecture

<2-3 sentences on the approach. Decisions at the architecture level: framework choices, data-flow shape, integration boundaries.>

## File Structure

<Bulleted list of new files, modified files. One line each. Cite the responsibility of each file — what it does and what other files depend on it.>

## Vertical Slices

### Slice 1: <Title>
<Full concrete schema block per § Concrete Schemas>

### Slice 2: <Title>
<...>

### Slice N: <Title>
<...>

## Cross-slice Testing

<Any integration tests that span multiple slices. Single-slice tests live in each slice's acceptance criteria; this section is for end-to-end validation.>

## Rollback

<How to undo the whole feature if needed. For most features: "git revert the subtask commits". For migration-touching features: explicit rollback steps.>
```

No inline code for the Engineer to copy-paste — that's `task-orchestration`'s domain when it creates subtask descriptions. The plan's job is to scope each slice's contract, not to write the implementation.

**Scope:** 300-2000 words total. Longer than the spec, shorter than the upstream CLI plans (which double as implementation manuals for a fresh engineer with no prior context). The Engineer gets the full slice schema via `task-orchestration`'s subtask description, not via the plan document directly.

## Plan Quality Checklist

Self-review before PUT:

1. **Spec coverage** — every Success Criterion from the `spec` document maps to exactly one slice's acceptance criteria. No orphan success criteria, no slices unmoored from the spec.
2. **Slice independence** — each slice produces working, testable software on its own. If Slice 2 can't pass its tests without Slice 3 being implemented, merge them or rewire the dependency.
3. **Schema concreteness** — every slice has non-prose Inputs and Outputs blocks. "A user object" is not a schema; `{id: string; email: string; createdAt: string}` is.
4. **Dependency annotations** — `Depends on slices: [M, K]` present on every slice. Empty list OK for the head of a chain; explicit is better than implicit.
5. **Acceptance criteria testable** — each criterion is specific enough to become a concrete test assertion. "Works correctly" is not testable.
6. **needsDesignPolish present** — every slice declares the flag explicitly, even if `false`. Missing flag = Task 7 task-orchestration will fail on the decomposition step.
7. **No implementation code** — you're writing the Tech Lead contract, not the Engineer's implementation. Resist the urge to prototype in the plan.
8. **Cross-slice tests specified** — any test that spans multiple slices is called out in the Cross-slice Testing section, not in any individual slice.

If a check fails, fix inline. No need for a second review pass.

## Scope Check

If the spec covers multiple independent subsystems despite the PM's decomposition check, STOP. You cannot compress three features into one plan cleanly. Post a comment on the issue:

```
The approved spec describes <N> independent subsystems:

1. <name> — could be its own plan
2. <name> — could be its own plan
...

Proceeding with a single plan would produce a subtask graph too large to orchestrate coherently. Options:

A. Split the spec into <N> child issues before planning (PM re-opens the spec)
B. I write a minimal "skeleton" plan covering shared infrastructure, then <N> follow-up plans per subsystem
C. Proceed with one plan anyway (I'll flag in the plan's Scope section that this may need post-implementation refactoring)

Which?
```

PATCH issue back to `{"status": "in_progress", "assigneeAgentId": "<board-id>"}`, exit heartbeat. Wait for the board's decision.

## Red Flags — STOP

- Writing implementation code in the plan document. The plan is a contract, not a scaffold.
- Leaving schema fields typed as `any` or prose-only (`"the user data"`). Concrete, or bail and ask the PM.
- Creating subtasks in this heartbeat. That's `task-orchestration`'s job, after plan approval.
- @-mentioning yourself in the announcement comment — self-wake loop.
- Separate PATCHes for status and assignee — race. Combine.
- Writing the plan to a filesystem path (`docs/plans/...`) — that's upstream CLI. Use the `plan` issue document.
- Skipping `needsDesignPolish` on any slice — Task 7 task-orchestration reads this flag; missing = decomposition fails.
- Authoring a plan with a single slice if the feature actually has ≥2 vertical slices. Compressing slices hides dependencies.

## Integration

**Companion Paperclip skills:**

- `pipeline-dispatcher` — routes you into this skill when the feature reaches the plan phase.
- `task-orchestration` — consumes your plan on the NEXT wake (after board approves), reads `.planDocument.body`, decomposes into subtasks. Your plan's slice granularity and `needsDesignPolish` flags are its inputs.
- `code-review` (Reviewer mode) — evaluates your plan via the same structured-findings format as code review. Trigger 2 (plan review) in their skill.

**Companion upstream concepts (dropped from this adaptation):**

- Bite-sized TDD steps per task — Paperclip plan is a contract; the Engineer's heartbeat follows `test-driven-development` discipline, but step-by-step TDD narration lives in subtask descriptions (task-orchestration's job), not the plan.
- "Subagent-driven" / "Inline execution" choice — `task-orchestration` is the only execution path in Paperclip.
- Task-level "git commit" steps in plan — the Engineer commits per subtask; plan doesn't narrate commits.

## Execution Model Reminder

Your output is a plan document on an issue. You do NOT create subtasks, do NOT write implementation code, do NOT run the Engineer's tests. All of those live in downstream heartbeats handled by different agents (Engineer) or your own later heartbeats after plan approval (you invoking `task-orchestration`).
