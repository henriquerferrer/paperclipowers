# Heartbeat Interaction — Paperclip Conventions

Reference for paperclipowers skills. Not a skill itself. Cite this file from any adapted SKILL.md that imports Paperclip heartbeat conventions.

## The heartbeat model

Paperclip agents run in discrete heartbeat windows. Each heartbeat is one Claude session run on one issue, dispatched by the Paperclip scheduler in response to a wake event (issue assignment, comment mention, status change, blockers resolved, scheduled timer, etc.). Within a single heartbeat you can read/write the workspace, call the Paperclip API via curl, post comments, and PATCH issue state. When the heartbeat ends you lose your chat context unless the next wake reuses the same session.

**Session reuse is per-(agent, issue):** Claude sessions are keyed by `(agentId, issueId)` in the `agentTaskSessions` table. Two consecutive heartbeats on the SAME issue reuse the session unless `wakeReason === "issue_assigned"` or `forceFreshSession === true` in the wake payload. Two heartbeats on DIFFERENT issues are always fresh, even for the same agent. Spec §5.4.

## Comment-based Q&A

When a skill requires a multi-turn dialog (primarily brainstorming):

- Batch 2-3 related questions per comment. Upstream's "one question per message" is wrong for Paperclip — each comment round is a heartbeat exit + wake = at least tens of seconds of scheduler latency + a fresh-session cost if the questions spread across different issues.
- Prefer multiple-choice over open-ended when possible. Each option labelled A/B/C.
- Phrase each question as a single sentence. If a topic needs three angles, that's three questions in one comment.
- Post the comment, then exit heartbeat (terminate this Claude session). The next wake fires on the board's reply comment (`issue_commented` wake; since you are the assignee, you receive this wake automatically).
- On the next wake, read the entire comment thread fresh. Do NOT assume you remember the previous round — read the comments to reconstruct.

## Exiting a heartbeat

To end a heartbeat cleanly:

1. Post any final comment the user needs to see (questions, status report, DONE mention).
2. PATCH any issue state changes (status, assigneeAgentId, blockedByIssueIds).
3. Write any deliverable documents via `PUT /api/issues/:id/documents/:key`.
4. Do not call `/api/agents/:id/pause` yourself — that stops future wakes entirely. Simply terminate the Claude session (no more tool calls; the heartbeat adapter detects the end of the response).

## Resuming a heartbeat

On wake, your context is:

- The `contextSnapshot` injected at the top of your system prompt (wakeReason, issueId, source, commentIds when mention-wake)
- The `agentInstructions` (your agent's system prompt + injected skills)
- If session was resumed, prior messages in this (agentId, issueId) session
- NOT: the workspace filesystem state by default. Call `git status`, `ls`, or `cat` if you need file state.

Always re-read the issue description, latest comments, and relevant documents at the start of each heartbeat. Fresh session = no prior-conversation memory at all; resumed session = prior messages present but possibly stale relative to the issue's current state.

## Self-mention avoidance

`@<agent-name>` in a comment you post fires `issue_comment_mentioned` on that agent. If you mention YOURSELF, you wake yourself, which re-enters your skill with your own comment as the trigger. This is a loop. Never @-mention yourself in a comment body you author.

Addressing another agent by name in prose WITHOUT the `@` sigil is fine — the mention resolver only wakes on the exact `@<name>` pattern. Use plain "the Reviewer" or "the Tech Lead" in natural prose; reserve `@<name>` for explicit wake signals.

## Curl payload idiom

Every POST/PUT/PATCH with a JSON body MUST be built as a file first, then posted with `curl --data-binary @file`. Recipe:

1. Use the `Write` tool (or the agent's equivalent workspace file-write) to place the JSON payload at `/tmp/<name>.json`. Escape newlines inside string values as `\n` (literal two-character sequence) — the JSON parser converts them correctly. The Write tool preserves bytes; zsh `echo "$PAYLOAD" > file` interprets `\n` as a real newline and mangles JSON strings.
2. `curl --data-binary @/tmp/<name>.json` — NOT `-d @/tmp/...` (which applies form-url-encoded rules and can strip `\r\n`).

Stage 3 Anomaly 2 documented the failure mode (payload mangled silently, JSON still technically valid, bug surfaces only in the persisted data). Stage 4 validation confirmed the Write + `--data-binary` idiom is correct.

## Unpause before PATCH (operator-side rule)

When an operator action sequence involves both unpausing agents and PATCHing issue assignments that will fire a wake on those agents, the UNPAUSE must come FIRST. Paperclip's heartbeat scheduler silently drops wakes enqueued against paused agents (`server/src/services/heartbeat.ts` emits `WARN: failed to wake agent on issue update: Agent is not invokable in its current state` and does NOT re-fire the wake on subsequent unpause).

Order:

1. For every agent that will receive a wake from the upcoming PATCHes: `POST /api/agents/<id>/resume` first.
2. Verify `GET /api/agents/<id>` returns `status: "idle"` (not `paused`) for each.
3. THEN PATCH the issue assignments.

If you PATCH-before-unpause, the pipeline stalls silently. Workaround if stalled: `PATCH /api/issues/<id>` with `{"assigneeAgentId": null}`, then PATCH back to the intended assignee — the second PATCH re-fires the wake on the (now-unpaused) agent. Prefer the correct order.

Any stage plan that hires agents, resumes agents, or flips assignments on a batch of issues must reference this rule in its Tasks preamble. Stage 6 Anomaly 11 traced to Stage 6 plan Task 7 violating this (PATCH-before-unpause dropped the wake; pipeline sat dormant 30 minutes until an unassign→reassign cycle re-fired it).

This rule is operator-side — it does not affect an agent inside a heartbeat. Agents PATCH issues routinely as part of their normal workflow, and the target agents are presumed runnable. If you, as an agent, are about to PATCH an assignment and want to be defensive: run `GET /api/agents/<target>` first (which `task-orchestration § RULE 2` already requires). That check both verifies non-paused status AND detects a paused target before the silent drop.