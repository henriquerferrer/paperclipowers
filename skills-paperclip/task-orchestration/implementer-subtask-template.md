# Implementer Subtask Description Template

Use this template when authoring the `description` field of an implementation subtask. The Tech Lead substitutes the `{{placeholders}}` before POSTing. The resulting string becomes the full body of the subtask issue — the assignee agent reads it on its first heartbeat for this subtask.

This template replaces upstream `subagent-driven-development/implementer-prompt.md`, adapted for Paperclip's heartbeat model: no Task tool, no inline dispatch, no dialog with a human controller — this subtask IS the assignee's heartbeat context.

---

## Goal

{{One paragraph describing what the assignee will produce when this subtask succeeds. Match the slice's acceptance criteria from the plan.}}

## Context

- **Parent feature:** issue `{{parent-issue-id}}` — {{parent title}}
- **Plan section:** {{plan anchor or slice number}}
- **Upstream subtasks** (already terminal): {{list predecessor subtask ids + their outputs this subtask consumes. If this is the head of the chain, write "none — this is the chain head."}}
- **Architectural context:** {{anything the assignee needs that isn't obvious from the code — framework version, prior design decisions, known sharp edges in the module being touched}}

## Required test cases

{{Bulleted list of test cases the assignee must write and make pass. Each entry: test file path, test name, behaviour being asserted. Be specific — "adds a failing test for empty-string input" is not enough; "`src/parse.test.ts` — `it('returns null on empty string input')` — asserts `parse('')` returns `null`, not `undefined`" is.}}

(If this subtask is infrastructure or configuration rather than code, replace this section with **Required acceptance checks** — a bulleted list of concrete verifications the assignee must perform before declaring DONE.)

## Required implementation files

{{Paths of files to create or modify. Explicit paths reduce ambiguity and catch plan-vs-implementation drift.}}

- `{{path/1}}` — {{what to change here}}
- `{{path/2}}` — {{what to change here}}

## Workflow

Expected order of work inside your heartbeat:

1. Read the files listed above in full before editing. Understand the existing patterns.
2. If anything in this description is unclear or you encounter a question that blocks progress, post a single `@{{tech-lead-name}} NEEDS_CONTEXT — <your question>` comment on this issue and leave the status at `in_progress`. The Tech Lead will reply; you will re-wake on `issue_commented` and resume.
3. Follow TDD: write the failing test(s) from the "Required test cases" section first, then make them pass.
4. Run the full relevant test subset after each logical commit.
5. Self-review with fresh eyes (see "Self-review" below).
6. Post your terminal comment per the Notification Protocol and transition issue status.

**While you work:** if you encounter something unexpected or genuinely ambiguous, use the NEEDS_CONTEXT flow from step 2. It is always OK to pause and clarify. Do not guess. The Tech Lead (who assigned this subtask) is reachable through `@`-mention.

## Code Organization

- Follow the file structure from the plan and the "Required implementation files" list.
- Each file should have one clear responsibility with a well-defined interface.
- If a file is growing beyond the plan's intent, STOP and report DONE_WITH_CONCERNS — don't split on your own.
- In existing codebases, follow established patterns; don't restructure outside this subtask's scope.

## When You're In Over Your Head

It is always OK to stop and escalate. Bad work is worse than no work.

STOP and escalate (via `BLOCKED` or `NEEDS_CONTEXT` — see Notification Protocol) when:
- The subtask requires architectural decisions with multiple valid approaches.
- You need context beyond what this subtask provided and can't find clarity.
- You feel uncertain whether your approach is correct.
- You've been reading file after file without progress.

How to escalate: post the appropriate mention comment. Describe what you're stuck on, what you've tried, and what would unblock. The Tech Lead can provide context, reassign, or split the subtask.

## Self-review — before posting your terminal comment

Review with fresh eyes:

- **Completeness:** Everything in Goal + Required test cases implemented? Edge cases handled?
- **Quality:** Names clear (match what, not how)? Maintainable?
- **Discipline:** YAGNI — only what was requested? Existing patterns followed?
- **Testing:** Tests verify behaviour, not mocks? TDD followed? Comprehensive?

Fix anything found during self-review before posting the terminal comment.

## Exit criteria

All of the following must be true before you post `DONE`:

- All tests in the "Required test cases" section pass.
- The full relevant test subset (the module you modified) is green — no regressions.
- You made at least one commit; commits have meaningful messages.
- Self-review completed.
- No open questions that would change the implementation.

## Notification Protocol

When you reach a terminal state, post ONE comment on this issue mentioning `@{{tech-lead-name}}`, then transition this issue's status. Use one of these formats:

- **On success** (tests pass, implementation complete):
  `@{{tech-lead-name}} DONE — <one-sentence summary>. Commits: <sha1>[, <sha2>...].`
  Then set this issue status to `done`.

- **On success with concerns** (done but you have doubts about correctness, scope, or file size):
  `@{{tech-lead-name}} DONE_WITH_CONCERNS — <one-sentence summary>. Concerns: <what you're uncertain about>. Commits: <sha1>[, <sha2>...].`
  Then set this issue status to `done`. The Tech Lead will decide on follow-up.

- **On blocker** (cannot complete):
  `@{{tech-lead-name}} BLOCKED — <what's blocking>. Tried: <what you tried>. Need: <what would unblock>.`
  Then set this issue status to `blocked`.

- **On ambiguity** (need clarification before proceeding):
  `@{{tech-lead-name}} NEEDS_CONTEXT — <the question>.`
  Leave this issue at `in_progress` and wait for a reply comment (you will re-wake on `issue_commented`).

**Never @-mention yourself** in any of these comments — the self-mention would fire your own `issue_comment_mentioned` wake and create a loop.

Never silently produce work you're unsure about. Use DONE_WITH_CONCERNS whenever you completed the requested change but want the Tech Lead to verify a specific aspect.
