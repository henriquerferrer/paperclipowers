# Paperclip Conventions — Issue Lifecycle, Documents, Approvals

Reference for paperclipowers skills. Not a skill itself. Cite this file from any adapted SKILL.md that consumes Paperclip issue/document/approval semantics.

## Issue status lifecycle

Issues flow through these status values:

- `backlog` — unassigned or not yet ready to start (default on creation unless set). **Does not fire `issue_assigned` wake on assignment.** Stage 4 Anomaly 1.
- `todo` — ready to start, assigned or unassigned. Assignment PATCH on a `todo` issue fires `issue_assigned`.
- `in_progress` — assignee is working; any subsequent comments or assignment changes fire their normal wake reasons.
- `in_review` — deliverable written, awaiting review. Assignee typically the Reviewer after the author's PATCH.
- `done` — terminal, successful.
- `blocked` — terminal for this wake, waiting on external unblock.
- `cancelled` — terminal, abandoned.

**Invariant for Stage 5 skills:** when transitioning from `in_progress` → `in_review`, always combine the status change with an assignee change in ONE PATCH. Two sequential PATCHes race: the first fires a wake before the second lands, and the receiving agent's first wake sees the wrong assignee.

**Invariant for parent assignment:** when assigning a parent issue that sits in `backlog`, always include `status: "todo"` in the same PATCH. Otherwise the assignment PATCH doesn't fire the wake. Stage 4 Anomaly 1.

## Issue documents

Documents are versioned, typed attachments on an issue. Created via `PUT /api/issues/:id/documents/:key` with body `{format: "markdown", body, title}`. Paperclipowers uses two conventional keys:

- `spec` — the product spec, authored by the PM in the brainstorming phase. Appears in `.documentSummaries[]` on the issue; full body accessible via `GET /api/issues/:id/documents/spec`.
- `plan` — the implementation plan, authored by the Tech Lead in the writing-plans phase. **Auto-populates the top-level `.planDocument` field** on the issue with the full inline body. Appears in `.documentSummaries[]` too.

Other keys are allowed but not used by Stage 5 skills. Revisions are auto-tracked — each PUT creates a new revision visible via `GET /api/issues/:id/documents/:key/revisions`.

## Approval gates (spec §5.2 amendment)

Paperclip's `approvals` table only supports three types: `hire_agent`, `approve_ceo_strategy`, `budget_override_required` (`/app/packages/shared/src/constants.ts:203`). There is NO spec/plan document approval type. Stage 5 uses the status+assignee PATCH pattern instead:

1. Author writes deliverable to issue document.
2. Author PATCHes issue: `{"status": "in_review", "assigneeAgentId": "<reviewer-id>"}` in ONE call.
3. Author exits heartbeat.
4. Reviewer wakes on `issue_assigned` (fresh session — per-issue session keying, see `heartbeat-interaction.md`), reads the document, posts findings as a comment (use `code-review` skill's format).
5. Reviewer's last act is a PATCH: `{"status": "todo", "assigneeAgentId": "<next-role-id>"}` where next-role is the board on approval or the original author on rejection.
6. The board (or original author) wakes on `issue_assigned`, reads the findings, either comments approval + PATCHes forward or comments rejection + PATCHes back.

The board's role is a reviewer-of-reviewers: the board's cookie-auth PATCH is the final decision. In the end-to-end pipeline, the board's touchpoints are: initial issue creation, spec approval (after Reviewer findings), plan approval (after Reviewer findings), PR merge (after Reviewer final combined review).

## Subtask graph

Subtasks are issues with a `parentId` and optional `blockedByIssueIds`. Stage 4's `task-orchestration` skill owns the orchestration mechanics. Quick reference:

- First subtask in a chain: create with `assigneeAgentId: <engineer-id>`, `blockedByIssueIds: []`, `status: "todo"`.
- Follower subtasks: create with `assigneeAgentId: null`, `blockedByIssueIds: [<predecessor-id>]`, `status: "todo"`. PATCHed to set the assignee only when the predecessor reaches a terminal status. Progressive assignment is load-bearing; see `task-orchestration/SKILL.md` RULE 1.

## Comment-triggered wakes

- `issue_assigned`: fires when `assigneeAgentId` changes to a non-null value (from null OR from another agent). Resets Claude session (`shouldResetTaskSessionForWake`).
- `issue_comment_mentioned`: fires when a comment body contains `@<agent-name>` matching the target agent's name. Does NOT reset session unless cross-issue session keying makes the mention land on a new (agent, issue) pair.
- `issue_commented`: fires on the assignee when someone else comments on their assigned issue (no mention required). Does NOT reset session.
- `issue_blockers_resolved`: fires on the assignee when all `blockedByIssueIds` reach terminal status. Does NOT reset session. Only relevant when `assigneeAgentId` is already set on the unblocked issue — if null, the wake is suppressed (`listWakeableBlockedDependents` filter).
- `issue_status_changed`: fires when status transitions. Reaches the assignee.
- `issue_children_completed`: fires on the parent's assignee when ALL children reach terminal status. Stage 4 `task-orchestration` does NOT rely on this for per-subtask orchestration (use mention wakes instead); only a backstop.

Always verify at plan-write time by reading `/app/server/src/routes/issues.ts` in the container if a wake behaviour seems off — server code is the source of truth.