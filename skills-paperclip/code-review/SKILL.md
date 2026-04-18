---
name: code-review
description: Use when you are assigned an issue to review (as Reviewer) or when you have been reassigned an issue with review findings (as Engineer or Designer). Covers all four review triggers (spec, plan, per-subtask diff, final combined diff), posting categorized findings, and evaluating received feedback without performative agreement.
---

# Code Review

## Overview

Code review in Paperclip serves a single Reviewer role across four trigger points, plus reviewee discipline when feedback comes back. At any given moment you are in one of two positions:

- **Performing review** — reading an artifact (spec document, plan document, per-subtask code diff, or final combined code diff) and posting categorized findings as comments on the issue
- **Receiving review** — evaluating feedback on technical merit, pushing back when wrong, implementing when right

This skill covers both. The reviewer's checklist and output format live in the companion `reviewer-prompt.md` in this directory.

**Core principle:** Review early, review often. Evaluate feedback on technical merit, not social pressure.

## When to Invoke

**If you are the Reviewer, you wake on one of four triggers:**

1. **Spec review** — the PM has written a `spec` document and created an approval. Read the spec against the parent issue's ask, post findings, the approval proceeds to the board.
2. **Plan review** — the Tech Lead has written a `plan` document and created an approval. Read the plan against the approved spec (schemas concrete? vertical slicing sound? acceptance criteria testable?), post findings, the approval proceeds to the board.
3. **Per-subtask code review** — an Engineer (or Designer) has marked a subtask `done`. Read that subtask's git diff against the plan's acceptance criteria for that slice, post findings, and either approve (parent moves closer to complete, dependent subtasks become unblocked) or reject (reassign to the subtask's last assignee with specific fixes).
4. **Final combined review** — all subtasks are done and the parent feature issue has reached `in_review`. Read the full base→HEAD diff, run the test suite end-to-end, verify against the full plan's acceptance criteria, then either approve (create PR, mark parent done) or reject (identify which subtask introduced the problem, reassign that subtask with findings).

Same Reviewer agent handles all four triggers — each heartbeat wake is a fresh context load, so separate triggers never share stale state.

**If you are the reviewee** (Engineer or Designer):
- You have been reassigned an issue whose status changed from `in_review` back to `in_progress` or `todo`
- New comments on your issue contain review findings
- A comment explicitly references categories (Critical / Important / Minor) with file:line references

## Part 1: Performing Review

### 1.1 Read Full Context Before Evaluating

Before posting anything:
- Read the issue description and full comment thread
- If reviewing a spec or plan, fetch the issue document: `GET /api/issues/{id}/documents/{key}` where key is `spec` or `plan`
- If reviewing code, read the plan document first (to know the acceptance criteria) then compute the git diff range
- Read ancestor issues (parent, grandparent) for context on the broader feature goal

**Never** post findings based on only the issue title or a partial read. Fresh-context review is the whole point — but "fresh context" means new perspective, not incomplete information.

### 1.2 Compute the Review Range

For code review:

```bash
BASE_SHA=$(git rev-parse <merge-base-or-plan-starting-commit>)
HEAD_SHA=$(git rev-parse HEAD)
git diff --stat $BASE_SHA..$HEAD_SHA
git diff $BASE_SHA..$HEAD_SHA
```

The base SHA is typically:
- The commit at which the Tech Lead's plan was approved (if recorded in a comment or the plan document)
- The parent feature branch's base if this is a full-feature review
- `HEAD~1` if reviewing the most recent subtask's diff

For spec/plan review: no diff — read the full document. Compare it against the parent issue's ask and any ancestor constraints.

### 1.3 Use the Reviewer Checklist

Open `reviewer-prompt.md` in this directory. It has the full checklist covering Code Quality / Architecture / Testing / Requirements / Production Readiness, plus the output format. Follow it item by item — do not skip sections.

### 1.4 Post Structured Findings

Post your findings as a comment on the issue, using the exact format in `reviewer-prompt.md`:

```
### Strengths
[Specific positives with file:line refs]

### Issues

#### Critical (Must Fix)
[Bugs, security issues, data loss risks, broken functionality]

#### Important (Should Fix)
[Architecture problems, missing features, poor error handling, test gaps]

#### Minor (Nice to Have)
[Code style, optimization opportunities, documentation improvements]

### Recommendations
[Process or quality improvements]

### Assessment
**Ready to merge:** Yes / No / With fixes
**Reasoning:** [1-2 sentences]
```

**Critical rules:**
- Categorize by actual severity. Not everything is Critical.
- Be specific. `file:line` references, not vague regions.
- Explain WHY each issue matters.
- Acknowledge strengths. A review that only lists issues is incomplete.
- Give a clear verdict. "Looks good" is not a verdict.

### 1.5 Approval Gate Outcome

**Every approval routes through the board — never PATCH directly to the next role.** Spec §5.2 (amended in Stage 5) formalizes the board as the cross-check gate. See `../_shared/paperclip-conventions.md` § Approval gates for the canonical flow.

There is no `POST /api/approvals/{id}/approve` endpoint for spec/plan/code review. Paperclip's `approvals` table supports only `hire_agent`, `approve_ceo_strategy`, `budget_override_required` (`packages/shared/src/constants.ts:203`). Use the status+assignee PATCH pattern below.

**Spec or plan review (triggers 1-2) — if approving:**
- Post a comment on the issue with your structured findings, ending with a final line exactly: `APPROVED — <one-sentence summary>`. **Do NOT @-mention the board in any form** (no `@<board-name>`, no `@board`, no `@operator`, no `@<anything-that-might-be-the-board>`). The board is a Paperclip USER (cookie-auth human operator), not an agent — there is no correct `@<board>` identifier from your context, and Stage 6.5 A13 showed Reviewers substituting the Engineer's agent name as the `<board-name>` placeholder. That mis-mention fired a spurious `issue_comment_mentioned` wake on the Engineer, and Stage 6.5 A14 documented the Engineer then PATCHing the parent forward as if acting on board authority — bypassing the board gate twice in one pipeline run. The board's signal is the `assigneeUserId` PATCH in the next step, which routes the issue into the board's human-facing queue.
- PATCH the issue in ONE call: `{"status": "todo", "assigneeUserId": "<board-user-id>", "assigneeAgentId": null}`. All three fields combined — separate PATCHes race. **Field choice is load-bearing:** the board is a Paperclip USER (cookie-auth operator), not an agent, so `assigneeUserId` takes the better-auth user-id; `assigneeAgentId` must be `null` (the server validates it as a UUID, which the board's user-id is not — using `assigneeAgentId` here 400s). See `../_shared/paperclip-conventions.md` § Approval gates § Field-split rule.
- Exit heartbeat. The board wakes on `issue_assigned` (triggered by the `assigneeUserId` PATCH, NOT by any @-mention — the @-mention is forbidden by the rule above), reads the findings + the `APPROVED` comment, and PATCHes forward to the next role (Tech Lead after spec approval, Engineer-or-orchestrator after plan approval). Do NOT PATCH directly to the next role — that bypasses the board's cross-check (Stage 5 Anomaly 3 was three skipped gates for this reason).

**Spec or plan review — if rejecting:**
- Post your findings comment using the `reviewer-prompt.md` format with explicit Critical / Important items.
- PATCH the issue back to the original author in ONE call: `{"status": "todo", "assigneeAgentId": "<original-author-id>"}`. Original author is the PM for spec rejections, the Tech Lead for plan rejections.
- Exit heartbeat. Author wakes on `issue_assigned`, revises the document, re-submits (which re-triggers your review via the same approval gate).

**Per-subtask code review (trigger 3) — if approving** (Stage 7+; Stage 5-6 does not exercise per-subtask review):
- Post the findings comment with `Ready to merge: Yes`.
- PATCH the subtask: `{"status": "done"}`. The Notification Protocol's `issue_comment_mentioned` wake on the Tech Lead handles downstream unblocking; do NOT touch dependent subtasks' assignees yourself — that is the orchestrator's job.

**Per-subtask code review — if rejecting:**
- Post your findings comment FIRST (before the PATCHes below). The reviewee will read this comment on their next heartbeat's initial context load.
- Use the **two-PATCH null-then-reassign idiom**, NOT a single `{status: in_progress, assigneeAgentId: <last-assignee-id>}` PATCH. **Stage 6.5 Anomaly 12:** a single PATCH that writes the same assignee-id the subtask already carries does NOT fire `issue_assigned` — Paperclip's wake subsystem fires only on an actual assignee-id change, and writing the same value is a no-op from the wake engine's perspective. When the Engineer finished the subtask, their `{status: done}` PATCH left `assigneeAgentId` pointing at themselves; a naive `{status: in_progress, assigneeAgentId: <engineer-id>}` rejection is a same-assignee write that drops silently. Run 1 of Stage 6.5 stalled for 6 minutes on exactly this until an operator unassign→reassign nudge forced the wake.
- **PATCH #1** — re-open the subtask and clear the assignee in one call: `{"status": "in_progress", "assigneeAgentId": null}`. This transitions the status and unassigns; no wake fires here (assigned → null does not trigger `issue_assigned`).
- **PATCH #2** — reassign to the reviewee: `{"assigneeAgentId": "<last-assignee-id>"}` (Engineer, or Designer if visual changes caused the regression). The null → `<last-assignee-id>` transition is a real assignee change and fires `issue_assigned` on the reviewee, forcing a fresh session per spec §5.4.
- Issue both PATCHes back-to-back in the same heartbeat; HTTP sequential ordering is sufficient — no sleep between them is needed. Do NOT combine the two into a single PATCH call that writes the same assignee-id already present (that is precisely the silent-drop case).
- A complementary server-side fix (Paperclip PR candidate) would be to fire an `issue_status_changed` wake on any `todo/in_progress` transition even when assignee is unchanged; the skill-level two-PATCH idiom is portable against today's Paperclip and does not require server changes.

**Final combined review (trigger 4) — if approving:**
- Post a comment: `APPROVED — final combined review complete. <one-sentence summary>. Ready to merge.` **Do NOT @-mention the board** (same rule and reasoning as spec/plan approval — Stage 6.5 A13/A14; the `assigneeUserId` PATCH below is the board's signal, not an @-mention).
- PATCH the parent in ONE call: `{"status": "todo", "assigneeUserId": "<board-user-id>", "assigneeAgentId": null}`. Field-split rule applies — see `paperclip-conventions.md` § Field-split rule. The board wakes on `issue_assigned`, verifies the review, then owns the PR / merge step and the transition to `done`. Do NOT mark the parent `done` yourself — the board's touchpoint on PR merge is the final gate. Stage 5 Anomaly 3 included a Reviewer marking the parent `done` directly; that stripped the final board gate.

**Final combined review — if rejecting:**
- Identify which subtask introduced the failing behavior — use `git log` to find the offending commit, map commits to subtasks via the commit-message convention or the subtask's branch.
- Re-open that subtask using the **same two-PATCH null-then-reassign idiom** as per-subtask rejection above. The offending subtask is currently `done` with `assigneeAgentId` = its completing Engineer/Designer, so a single `{status: in_progress, assigneeAgentId: <same-id>}` PATCH would hit the same Stage 6.5 Anomaly 12 silent-drop. **PATCH #1:** `{"status": "in_progress", "assigneeAgentId": null}` on the offending subtask. **PATCH #2:** `{"assigneeAgentId": "<original-assignee-id>"}`.
- Do NOT PATCH the parent's status yourself while a child is being re-worked. The parent stays in `in_review`; when the re-opened subtask completes, the final-review wake re-fires on you.

**For any trigger — if finding architectural issues** that indicate the plan itself is wrong:
- Escalate to the Tech Lead via reassignment, not back to the Engineer.
- Comment explaining why this is a plan-level issue, not an implementation-level issue.

**Red flag — skipping the board.** If you catch yourself PATCHing directly to the Tech Lead after spec approval, the Engineer after plan approval, or marking the parent `done` yourself after final approval: STOP. You are bypassing the board. Post the `APPROVED` comment (no @-mention — see the rule above; Stage 6.5 A13/A14) and PATCH to the board with `assigneeUserId` instead. This is Stage 5 Anomaly 3 — the pre-amendment skill text said "proceeds to the next approver (board)" but the imperative "Call the approval endpoint" misled the model into short-circuiting. Three skipped gates in one pipeline run. The board's gate is what catches Reviewer misjudgments (e.g., approving a low-quality spec); stripping it is invisible risk.

## Part 2: Receiving Review Feedback

### 2.1 The Response Pattern

When you wake up to find review findings in your issue comments:

```
1. READ: Complete feedback without reacting. Read every comment in the thread.
2. UNDERSTAND: Restate each finding in your own words (in your head, or in a comment if genuinely unclear).
3. VERIFY: Check the claims against the actual codebase. Does the reviewer's file:line reference exist? Is the issue real?
4. EVALUATE: Is the suggested change technically sound for THIS codebase, THIS stack, THIS task's scope?
5. RESPOND: Technical acknowledgment or reasoned pushback via issue comment.
6. IMPLEMENT: One item at a time. Verify each fix before moving to the next.
```

### 2.2 Forbidden Responses

**NEVER** post or think:
- "You're absolutely right!"
- "Great point!" / "Excellent feedback!"
- "Thanks for catching that!" / ANY gratitude expression
- "Let me implement that now" (before verification)

**INSTEAD:**
- Restate the technical requirement in a comment ("I'll add input validation to `parseConfig` — the null-byte case on line 42 was missed because the regex only checks for whitespace.")
- Ask clarifying questions in a comment if truly unclear
- Push back with technical reasoning via comment if you believe the reviewer is wrong
- Or just start working — actions speak, and the commit will show the fix

**Why no gratitude:** In an async pipeline, gratitude is noise. The code IS the acknowledgment. Comments should carry technical content only.

### 2.3 Handling Unclear Feedback

```
IF any finding is unclear:
  STOP — do not implement anything yet
  Post a single comment asking for clarification on ALL unclear items
  Set status: blocked if the clarifications must come before any progress

WHY: Items may be related. Partial understanding = wrong implementation.
```

**Example:**

> Reviewer comment: "Issues 1, 2, and 3 as listed above — please fix."
> You understand issues 1 and 3 clearly. Issue 2 is ambiguous.
>
> ❌ WRONG: implement 1 and 3 now, ask about 2 later
> ✅ RIGHT: Post a single comment: "Working on 1 and 3 after confirmation. On issue 2: is `X` meant to refer to the `Y` function in `bar.ts`, or the newer `Y2` helper in `baz.ts`? My read is `Y2`, but confirm before I touch it."

### 2.4 YAGNI Check

```
IF a reviewer suggests "implementing properly" or "adding X for robustness":
  grep the codebase for actual usage of the thing being improved

  IF unused: Post a comment — "Grepped the codebase; nothing calls this endpoint. Removing it (YAGNI) instead of hardening unused code — flag if you disagree."
  IF used: Then implement the improvement
```

**Why:** In Paperclip, both you and the reviewer report to the board. If the feature isn't needed, hardening it wastes work. The reviewer's job is to catch quality issues, not to grow scope.

### 2.5 Implementation Order

For multi-item feedback:

```
1. Resolve anything unclear FIRST (Section 2.3)
2. Then implement in this order:
   - Blocking issues (breaks functionality, security risks)
   - Simple fixes (typos, imports, renames)
   - Complex fixes (refactoring, logic changes)
3. Run tests after each fix
4. Verify no regressions before committing
5. Commit each logical group separately with a clear message
```

### 2.6 When to Push Back

Push back — via a comment on the issue — when:
- The suggested change would break existing functionality (show the test that would fail)
- The reviewer lacks full context (explain the constraint they missed, e.g., "this file is also called from X which requires the old signature")
- It violates YAGNI (unused feature — see Section 2.4)
- It's technically incorrect for this codebase's stack (cite the version/platform)
- A legacy/compatibility constraint exists (link the original decision)
- It conflicts with the Tech Lead's plan (flag it as a plan-level issue; reassign to Tech Lead, not to the reviewer)

**How to push back:**
- Use technical reasoning. Reference tests, types, constraints, or prior decisions.
- Be specific. "I disagree" is not pushback; "I disagree because `foo.test.ts:42` proves the current behavior is correct" is.
- Ask specific questions if you need more information.
- If the disagreement is architectural, reassign to the Tech Lead rather than hashing it out with the reviewer.

### 2.7 Acknowledging Correct Feedback

When feedback is right:

✅ Just fix it. The commit shows you heard.
✅ If you need to comment, state the fix: "Added null check at `parseConfig.ts:42`. Test added at `parseConfig.test.ts:115`."
✅ "Good catch on the race condition — the fix is using a single atomic transaction at `db.ts:88`."

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!"
❌ ANY gratitude expression

**If you catch yourself about to write "Thanks":** Delete it. State the fix instead.

### 2.8 Correcting Your Own Pushback

If you pushed back and then verified the reviewer was right:

✅ "You were right — I checked `foo.ts:42` and it does hit the null-path. Implementing the fix."
✅ "Verified; my initial reading missed that `bar.ts:100` calls this with nullable input. Fixing now."

❌ Long apology
❌ Defending why you pushed back
❌ Over-explaining

State the correction factually in a single comment, then move on.

## Part 3: Comment Thread Etiquette

- **Reply in the issue's comment thread** — don't open a new top-level comment for each back-and-forth
- **Reference line numbers** in your codebase — `foo.ts:42` — not in your comment text
- **One logical topic per comment** — if you have three different responses, consider three comments or one comment with numbered sections
- **Link to the specific document revision** if the document has changed since the review — issue documents are versioned
- **No meta-commentary** — don't post "I'll look at this tomorrow" or "on it" in comments; just start work and the next heartbeat's activity log will show progress

## Red Flags — STOP

If you catch yourself:
- Performatively agreeing before verifying
- Implementing without reading the full context
- Batching fixes without testing each one
- Arguing social tone rather than technical substance
- Ignoring a Critical finding because "I'm sure it's fine"
- Skipping the reviewer checklist because "I've done this before"
- Marking a review complete without running the test suite (for QA)
- Writing "thanks" anywhere

**All of these mean:** stop, return to the relevant section's procedure.

## The Bottom Line

**Reviewer:** read fully, categorize by real severity, be specific, give a clear verdict.

**Reviewee:** verify before implementing, push back with technical reasoning, no performative agreement.

Mocks are tools. Comments are artifacts. Reviews are artifacts. Actions are the only acknowledgment.

## See Also

- `reviewer-prompt.md` — the reviewer's checklist and output format (open it when performing review)
- `test-driven-development` — for adding the test that proves a fix works (Part 2, Section 2.5)
- `verification-before-completion` — evidence before claiming done after fixing review issues
- `systematic-debugging` — when a review finding points to an apparent symptom whose root cause is elsewhere
