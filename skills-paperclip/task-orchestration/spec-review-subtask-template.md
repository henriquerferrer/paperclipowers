# Spec Review Subtask Description Template

**DORMANT — Stage 5 will activate this when the Reviewer agent is hired.** Do not use in Stage 4. The Tech Lead in Stage 4 does not create spec-review subtasks; per-subtask review is handled by the Reviewer agent via `code-review` trigger 3, which wakes on `issue_status_changed` rather than needing an explicit subtask. This template is preserved so Stage 5 can restore an explicit spec-compliance gate if the combined-trigger approach proves insufficient.

Use this template when authoring the `description` field of a spec-compliance-review subtask. The Tech Lead substitutes the `{{placeholders}}` before POSTing. The resulting string becomes the full body of the review subtask issue — the Reviewer agent reads it on its first heartbeat for this subtask.

This template replaces upstream `subagent-driven-development/spec-reviewer-prompt.md`, adapted for Paperclip's heartbeat model: the reviewer runs as a Paperclip subtask with its own assignee, not as a Task-tool dispatch.

---

## Goal

Verify that the implementation of subtask `{{implementer-subtask-id}}` — "{{implementer subtask title}}" — matches its specification. Nothing more, nothing less.

## Context

- **Parent feature:** issue `{{parent-issue-id}}` — {{parent title}}
- **Implementation subtask:** `{{implementer-subtask-id}}` — {{implementer subtask title}}
- **Plan section:** {{plan anchor or slice number}} — the requirements the implementation must match
- **Implementer's terminal comment:** see the mention comment on `{{implementer-subtask-id}}` starting `@{{tech-lead-name}} DONE ...` — that comment lists the commit SHAs and summary you will verify against.

### What was requested

{{Full text of the requirements that defined the implementation subtask — paste the Goal + Required test cases sections from the implementation subtask's description. The Reviewer must not have to read the implementation subtask issue to understand what was requested; bring it inline.}}

### What the implementer claims they built

{{Paste the implementer's `@{{tech-lead-name}} DONE ...` comment text verbatim. Include the commit SHAs.}}

## CRITICAL: Do not trust the implementer's report

The implementer's terminal comment may be incomplete, inaccurate, or optimistic. You MUST verify everything independently.

**DO NOT:**
- Take the implementer's word for what they implemented.
- Trust their claims about completeness.
- Accept their interpretation of requirements.

**DO:**
- Read the actual code they wrote (diff the commit SHAs listed in their comment).
- Compare actual implementation to requirements line by line.
- Check for missing pieces they claimed to implement.
- Look for extra features they didn't mention.

## Required acceptance checks

Read the implementation code and verify:

**Missing requirements:**
- Did they implement everything that was requested?
- Are there requirements they skipped or missed?
- Did they claim something works but didn't actually implement it?

**Extra / unneeded work:**
- Did they build things that weren't requested?
- Did they over-engineer or add unnecessary features?
- Did they add "nice to haves" that weren't in spec?

**Misunderstandings:**
- Did they interpret requirements differently than intended?
- Did they solve the wrong problem?
- Did they implement the right feature but in the wrong way?

Verify by reading code — not by trusting the implementer's terminal comment.

## Required implementation files for YOUR review

{{List the files the Reviewer should read to complete this review — typically the same files the implementer's subtask listed as "Required implementation files," plus any related tests.}}

## Workflow

1. Read the "What was requested" section above in full.
2. Fetch the implementer's commit diff: `git show {{implementer-head-sha}}` (or `git diff {{base-sha}}..{{implementer-head-sha}}`).
3. For each line of the requirements, verify the corresponding code exists and is correct. For each line of code not matching a requirement, flag it as Extra.
4. Run the test suite subset that corresponds to the changed module. Record whether all tests pass.
5. Draft the spec-compliance verdict.
6. Post your terminal comment per the Notification Protocol.

## Exit criteria

- Every requirement from "What was requested" has been checked against actual code and labelled present / missing / misimplemented.
- Every added file / function has been checked against the requirements and labelled required / extra.
- Tests were executed, not assumed — note the test command and pass count in your comment.
- The verdict is a clear Spec compliant / Issues found — not hedged.

## Notification Protocol

When you reach a terminal state, post ONE comment on this issue mentioning `@{{tech-lead-name}}`, then transition issue status:

- **Spec compliant:**
  `@{{tech-lead-name}} DONE — Spec compliant. All {{N}} requirements verified against commits {{sha1}}[,{{sha2}}...]. Test subset green ({{X}}/{{X}} passing).`
  Then set this issue status to `done`.

- **Issues found:**
  `@{{tech-lead-name}} DONE — Spec issues found. See structured report below.`
  followed by a categorized list:
  ```
  ### Missing
  - {{requirement}} — not implemented in {{file:line}}
  ### Extra
  - {{feature}} — added in {{file:line}}, not in spec
  ### Misimplemented
  - {{requirement}} — expected {{X}}, got {{Y}} at {{file:line}}
  ```
  Then set this issue status to `done`. The Tech Lead decides whether to reopen the implementation subtask or escalate.

- **Blocker:**
  `@{{tech-lead-name}} BLOCKED — <what's blocking>. Tried: <what you tried>. Need: <what would unblock>.`
  Then set this issue status to `blocked`.

- **Ambiguity:**
  `@{{tech-lead-name}} NEEDS_CONTEXT — <the question>.`
  Leave status at `in_progress` and wait for reply.

**Never @-mention yourself** in any of these comments.

A review that only lists issues without strengths is incomplete — include at least one `### Strengths` line in any Issues-found report, citing specific file:line references for things done well.
