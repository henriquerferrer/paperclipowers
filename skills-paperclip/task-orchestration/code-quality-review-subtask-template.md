# Code Quality Review Subtask Description Template

**DORMANT — Stage 5 will activate this when the Reviewer agent is hired.** Do not use in Stage 4. In Stage 4, per-subtask code quality review is combined with spec review under `code-review` trigger 3, which wakes on `issue_status_changed`. This template is preserved so Stage 5 can restore an explicit two-stage gate (spec compliance first, then code quality) if the combined trigger proves insufficient.

Use this template when authoring the `description` field of a code-quality-review subtask. The Tech Lead substitutes `{{placeholders}}` before POSTing; the resulting string becomes the subtask body the Reviewer reads.

**Only create a code-quality-review subtask after the corresponding spec-review subtask has terminated with "Spec compliant."** Running it earlier wastes review capacity on code that may be torn out.

Replaces upstream `subagent-driven-development/code-quality-reviewer-prompt.md`, adapted for Paperclip's heartbeat model.

---

## Goal

Verify that the implementation of subtask `{{implementer-subtask-id}}` — "{{implementer subtask title}}" — is well-built: clean, tested, maintainable. Spec compliance has already been verified in subtask `{{spec-review-subtask-id}}`; your job now is code quality.

## Context

- **Parent feature:** issue `{{parent-issue-id}}` — {{parent title}}
- **Implementation subtask:** `{{implementer-subtask-id}}` — {{implementer subtask title}}
- **Spec review subtask (already passed):** `{{spec-review-subtask-id}}`
- **Base SHA:** {{base-sha}} — commit immediately before the implementation subtask's work began
- **Head SHA:** {{implementer-head-sha}} — implementer's last commit
- **What was implemented:** {{one-sentence summary from the implementer's terminal comment, or a short paraphrase}}

### Files changed in this slice

{{List of files created or modified. You can compute this from `git diff --stat {{base-sha}}..{{implementer-head-sha}}`; paste it here so the Reviewer doesn't have to re-derive it.}}

## Required acceptance checks

In addition to standard code quality concerns (naming, complexity, error handling, duplication, test coverage), verify:

**Responsibility and structure:**
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Does the implementation follow the file structure from the plan?

**File size discipline:**
- Did this change create new files that are already large, or significantly grow existing files? (Don't flag pre-existing file sizes — focus on what THIS change contributed.)

**Test quality:**
- Do tests verify behaviour, not mock interactions?
- Do tests cover the edge cases implied by the requirements?

**Error paths and consistency:**
- Are error conditions handled with enough context to debug?
- Do new names and patterns match nearby existing code?

## Required implementation files for YOUR review

{{List the files the Reviewer should read. Typically the same set as the implementation subtask touched, plus any tests.}}

## Workflow

1. Fetch the diff: `git diff {{base-sha}}..{{implementer-head-sha}}`. Read every changed file in full.
2. Run the test subset for the changed module. Record pass/fail counts.
3. Work through the Required acceptance checks, category by category. Collect findings.
4. Categorize by Severity (below).
5. Draft the structured review.
6. Post your terminal comment per the Notification Protocol.

## Severity taxonomy

- **Critical** — bugs, security issues, data loss risks, broken functionality. Implementation must be reopened before parent advances.
- **Important** — architectural problems, missing tests, poor error handling. Should be fixed before merge; Tech Lead may accept as tech-debt if plan deferred them.
- **Minor** — style, local optimization, docs. Do not block the chain.

## Exit criteria

- Every changed file read end-to-end, not just hunks.
- Test subset executed — note the command and pass count.
- Findings categorized per Severity.
- At least one `### Strengths` entry (file:line of something done well).
- Clear Approved / Fixes required verdict — no hedging.

## Notification Protocol

When you reach a terminal state, post ONE comment on this issue mentioning `@{{tech-lead-name}}`, then transition issue status.

- **Approved or Fixes required** (both use status `done`; Tech Lead reads the verdict to decide whether to reopen the implementation):
  `@{{tech-lead-name}} DONE — Code quality <approved|fixes required>.`
  followed by:
  ```
  ### Strengths
  - {{file:line}} — {{what was done well}}
  ### Issues
  #### Critical (Must Fix)
  - {{file:line}} — {{description}}
  #### Important (Should Fix)
  - {{file:line}} — {{description}}
  #### Minor (Nice to Have)
  - {{file:line}} — {{description}}
  ### Assessment
  Ready to merge: Yes | No | With fixes
  Reasoning: {{one sentence}}
  ```
  Then set this issue status to `done`.

- **Blocker:**
  `@{{tech-lead-name}} BLOCKED — <what's blocking>. Tried: <what you tried>. Need: <what would unblock>.`
  Then set this issue status to `blocked`.

- **Ambiguity:**
  `@{{tech-lead-name}} NEEDS_CONTEXT — <the question>.`
  Leave status at `in_progress` and wait for reply.

**Never @-mention yourself** in any of these comments.

Report rules: categorize by actual severity (not everything is Critical); use `file:line` references; explain WHY each issue matters; acknowledge strengths; give a clear verdict ("Looks good" is not a verdict).
