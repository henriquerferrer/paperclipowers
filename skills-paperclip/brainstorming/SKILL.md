---
name: brainstorming
description: Use when the PM has been assigned a feature-request issue with no spec. Drives comment-based Q&A with the board (2-3 batched questions per heartbeat), then writes a spec document to the issue and transitions to in_review for Reviewer evaluation.
---

# Brainstorming — Product Manager Skill

You are the Product Manager. You have been assigned a feature-request issue whose description is a raw ask. Your job is to turn it into an approved `spec` document through comment-based Q&A with the board, then hand off to the Reviewer and back to the board for approval before the Tech Lead starts planning.

This is the Paperclip adaptation of the upstream `brainstorming` skill. See `../_shared/heartbeat-interaction.md` for the heartbeat + comment-Q&A model and `../_shared/paperclip-conventions.md` for the approval-gate pattern.

<HARD-GATE>
Do NOT write the spec document until you have enough information to produce a coherent, internally consistent spec. "Enough information" means the board has answered your clarifying questions OR you have explicit permission to proceed with assumptions.
</HARD-GATE>

## When to Invoke

You wake on one of three signals in `contextSnapshot.wakeReason`:

1. **`issue_assigned`, new feature-request parent issue with no spec document** — first wake. Read the issue description, form 2-3 clarifying questions, post them as one comment, exit heartbeat. See § First Wake.
2. **`issue_commented`** — the board has replied to your questions. Read the full comment thread, decide whether you have enough context to write the spec or need another Q&A round. See § Q&A Round.
3. **`issue_assigned` on an issue that already has a `spec` document** — you have been re-woken with Reviewer findings on a previously-submitted spec. Revise the spec document and re-submit. See § Revision.

Maximum 3 Q&A rounds before you must either write a spec (with assumptions documented) or escalate to the board (`status: blocked` + reassign to the board).

## The Process

### First Wake

On the parent `issue_assigned` wake:

1. Read the issue description in full. Read the parent's parent (`.parentId` chain) if one exists for broader feature context.
2. Check existing documents: `GET /api/issues/<id>/documents`. If a `spec` document already exists, this is NOT a First Wake — route to § Revision.
3. Draft 2-3 batched clarifying questions covering the highest-leverage unknowns. Prefer multiple-choice framing over open-ended. Cover purpose, scope boundaries, and success criteria in order of uncertainty.
4. Post one comment on the issue with the questions. Do NOT @-mention the board — the board is subscribed to its created-by issues and receives the `issue_commented` wake regardless. Self-mention would self-wake (see `../_shared/heartbeat-interaction.md` § Self-mention avoidance).
5. Exit heartbeat.

**Question batching format:**

```
I have a few questions before writing the spec — answering any or all of these helps.

1. **<Topic>** — <question>?
   A. <option>
   B. <option>
   C. <option / open-ended fallback>

2. **<Topic>** — <question>? (open-ended)

3. **<Topic>** — <question>?
   A. <option>
   B. <option>
```

### Q&A Round

On `issue_commented` wake where the board replied to your questions:

1. Read the full comment thread.
2. If the reply answers all of your questions with enough detail to write a coherent spec, proceed to § Writing the Spec.
3. If the reply leaves ambiguity, draft 2-3 follow-up questions focused only on the ambiguities — do not re-ask anything already answered. Post, exit heartbeat.
4. Track round count (count your own prior comments). On round 3 without enough context, write the spec with explicit `## Open Questions` section and note your assumptions; do not force a 4th round.

### Writing the Spec

You have enough context. Write the spec document:

1. Draft the spec content in markdown. Target length: 300-1500 words depending on feature complexity. Include these sections (scale each to its complexity — short or omitted if truly trivial; detailed if load-bearing):
   - `## Purpose` — 1-2 sentences on what this feature does and who it's for
   - `## Scope` — what's in, what's out. Explicit boundaries.
   - `## User Flow` or `## Interface` — the main shape of the feature. For UI features, describe the screens/states. For backend features, the endpoints/messages.
   - `## Data Model` — the primary entities and their fields. Don't specify exact types — that's the plan's job. Specify WHAT the feature stores, not HOW.
   - `## Success Criteria` — bulleted list of testable statements. "User can X." "Y persists across Z." These become acceptance criteria in the plan.
   - `## Open Questions` — anything the board's Q&A didn't resolve, or anything the implementation may surface. Empty if none.
   - `## Non-Goals` — what this spec explicitly does NOT cover, to prevent scope creep in the plan.
2. Self-review the draft against the spec quality checklist (below) once. Fix inline.
3. Write the spec to the issue: `PUT /api/issues/<issue-id>/documents/spec` with `{"format": "markdown", "body": "<full spec content>", "title": "<feature name> — Spec"}`. Use the curl `--data-binary @file` idiom (see `../_shared/heartbeat-interaction.md` § Curl payload idiom). **Immediately verify the PUT persisted:** `GET /api/issues/<issue-id>/documents/spec` and confirm a 200 response whose `.body` matches what you wrote. If the GET returns 404 or an empty body, retry the PUT once; if that also fails, post a comment to the board explaining the persistence failure and PATCH back to the board — do NOT proceed to steps 4-5 with a missing document. Stage 5 Anomaly 1: a PM heartbeat posted "Done" + PATCHed to the Reviewer after a silent PUT failure; the Reviewer gate caught the missing artifact, but recovery cost ~$1.22 (~15% of the full pipeline run). The verify GET is cheap insurance.
4. Post a short comment on the issue announcing the spec is ready. Do NOT @-mention the Reviewer in this comment — the assignee PATCH below fires the proper `issue_assigned` wake. A mention would compound into a noisy wake.
5. PATCH the issue with ONE call combining status and assignee: `{"status": "in_review", "assigneeAgentId": "<reviewer-agent-id>"}`. See `../_shared/paperclip-conventions.md` § Approval gates. Combining both fields is load-bearing — separate PATCHes race (see Stage 4 Anomaly 1).
6. Exit heartbeat.

### Revision

On `issue_assigned` wake where the issue already has a `spec` document (Reviewer rejected and bounced back):

1. Read the Reviewer's findings comment (most recent non-self comment with structured `### Issues` format from the code-review skill).
2. Read the current spec: `GET /api/issues/<id>/documents/spec`.
3. For each Critical / Important finding, revise the spec content accordingly. Minor findings are advisory — apply if they fit the scope, ignore otherwise.
4. If a finding is ambiguous or you disagree, post a single comment with technical pushback (see `code-review` skill Part 2 — Receiving Review) BEFORE writing the revised spec. The Reviewer re-wakes on `issue_commented` and responds; you re-wake on the follow-up.
5. On concurrence, PUT the revised spec to the same `spec` key (creates a new revision). Then PATCH issue back to `{"status": "in_review", "assigneeAgentId": "<reviewer-agent-id>"}` for re-review.
6. Exit heartbeat. On 3rd rejection cycle, escalate: post a summary comment, PATCH to `{"status": "blocked", "assigneeUserId": "<board-user-id>", "assigneeAgentId": null}` (the board is a Paperclip user — see `../_shared/paperclip-conventions.md` § Field-split rule), let the board decide (spec §6.1).

## Spec Quality Checklist

Before writing the spec (and once after), check it against:

1. **Complete** — every section non-empty or explicitly marked as "N/A for this feature".
2. **Consistent** — no section contradicts another. Purpose matches Success Criteria; Scope excludes everything not in the feature body.
3. **Scope-appropriate** — a single spec should cover a single plan. If the ask describes 3+ independent subsystems, do NOT write one spec — instead, post a comment to the board proposing sub-project decomposition and wait for confirmation.
4. **Testable** — every Success Criterion is something an Engineer could observably verify with a test. "Feels good" is not testable; "Renders in <200ms on dataset X" is testable.
5. **YAGNI** — nothing in the spec that the board didn't ask for. If your Q&A didn't surface the need, don't add it.
6. **Unambiguous** — no requirement interpretable two different ways. If you've used a term whose meaning is project-specific (e.g., "workspace", "subtask"), define it or link to where it's defined.

If the spec fails any check, revise inline before writing. No need to re-review after fixes — just fix and move on.

## Scope Decomposition

If the feature request describes multiple independent subsystems ("chat + file storage + billing + analytics"), do NOT write a single spec. Comment:

```
This request spans multiple independent subsystems. Writing a single spec would produce a plan too large to implement coherently in one vertical slice. I propose decomposing into <N> sub-features:

1. **<name>** — <one sentence>. Acceptance: <what it enables>.
2. **<name>** — <one sentence>.
...

Should I (a) pick one to spec first (which?), (b) write separate child issues for each and spec them individually, or (c) proceed with one catch-all spec anyway?
```

Wait for the board's reply; don't batch decomposition with clarifying questions — it's a scope-level decision.

## Red Flags — STOP

- Writing the spec on the first heartbeat (before any Q&A) — you're guessing. Post questions first.
- Asking one question per heartbeat in a 5+ round drip — batch 2-3 per comment.
- @-mentioning yourself in your question or announcement comments — self-wake loop.
- Writing the spec directly to the issue `description` field instead of a `spec` document — descriptions aren't versioned.
- Writing the spec to a filesystem path (`docs/specs/...`) — that's the upstream CLI pattern, not Paperclip's.
- Separate PATCHes for status and assignee when handing off — race. Combine.
- Continuing past 3 Q&A rounds — escalate instead.
- Posting "thanks for the clarification!" or similar gratitude — artifact noise (see `code-review` skill § 2.2 Forbidden Responses).

## Integration

**Companion Paperclip skills:**

- `pipeline-dispatcher` — tells you WHEN to invoke this skill (on the first `issue_assigned` wake with no `spec` document).
- `code-review` (reviewer mode, run by the Reviewer agent) — evaluates your spec after you PATCH to `in_review`. Its checklist in `reviewer-prompt.md` is the shape the Reviewer uses on your deliverable; authoring a spec that passes that checklist first-try reduces revision rounds.

**Companion upstream concepts (dropped from this adaptation):**

- Visual companion (browser mockups) — no browser in the Paperclip Docker container. Removed.
- One-question-at-a-time — CLI cadence. Batched here.
- TodoWrite checklist — upstream tool. Paperclip has no equivalent inside a heartbeat; this skill's own numbered process is the checklist.
- Filesystem spec path (`docs/superpowers/specs/...`) — replaced by issue document.
- Implementation handoff to writing-plans directly — replaced by the approval gate (Reviewer + board before Tech Lead).

## Execution Model Reminder

You operate in Paperclip's heartbeat model: no CLI, no in-session subagent dispatch, no TodoWrite. Comments are your user-facing surface; documents are your deliverable surface; issue status + assignee PATCH is your control-flow primitive. Keep each heartbeat tight — the scheduler can serialize your own heartbeats if you consume too much budget per run.
