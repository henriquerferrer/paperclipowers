---
name: task-orchestration
description: Use when decomposing an approved plan into Paperclip subtasks. Creates the subtask graph with unconditional progressive assignment, wakes per subtask completion via @mention, and gates every assignee PATCH on target-agent status.
---

# Task Orchestration

## Overview

You are the Tech Lead. Your plan is approved. Your job now is to decompose it into Paperclip subtasks, hand each subtask off to an assignee agent, wake as each one completes, and transition the parent to `in_review` when the chain ends.

You hand off work via `POST /api/companies/:company-id/issues` (create subtask) and `PATCH /api/issues/:id` (update assignee, status, etc.). No CLI dispatch primitive is available inside a heartbeat — every act of dispatch is an HTTP call to the Paperclip API. Every subtask is a real Paperclip issue with its own lifecycle: `todo` → `in_progress` → `done` / `blocked` / `cancelled`.

Three rules are load-bearing. Violating any of them breaks the pipeline:

1. **Progressive assignment (RULE 1):** every subtask chain assigns the FIRST subtask at creation; every subsequent subtask is created with `assigneeAgentId: null` and `blockedByIssueIds: [<predecessor>]`, then PATCHed to set the assignee ONLY after the predecessor reaches a terminal status. This guarantees each subtask boots a fresh Claude session. Spec §5.4.
2. **Pre-PATCH paused-target check (RULE 2):** before every `PATCH … assigneeAgentId`, GET the target agent and confirm its status is not `paused`. A PATCH fired at a paused agent is silently dropped — the subtask never runs. Stage 3 Anomaly 1.
3. **Notification protocol via @mention (RULE 3):** every subtask description you author contains a "Notification Protocol" section instructing the assignee to post a single `@<tech-lead-name>` mention comment on terminal status. That `@mention` is your only reliable per-subtask wake — the built-in `issue_children_completed` wake only fires when ALL children are terminal. Stage 4 spec §5.4 + `server/src/services/issues.ts:1347-1376`.

The rest of this skill is the "how" and the escalation paths for when each rule's guard fires.

## When to Invoke

You are invoked on one of four wake signals in `contextSnapshot.wakeReason`:

1. **`issue_assigned` on the parent issue, no subtasks yet** — first wake after plan approval. You read the plan, decompose it, create the subtask graph, PATCH the first subtask's assignee, and exit. See § First Wake.
2. **`issue_comment_mentioned`** — a subtask assignee (or another agent) @-mentioned you. This is the per-subtask completion signal, and also how blockers, NEEDS_CONTEXT questions, and escalations reach you. See § Per-Completion Heartbeat.
3. **`issue_status_changed` on a subtask** — fallback wake if the assignee transitioned status without posting the mention comment. Rare when subtask descriptions include the Notification Protocol, but handle it defensively.

    (Stage 5 note: the per-subtask-review trigger that would hand subtasks to the Reviewer between completion and final review is INTENTIONALLY NOT wired in Stage 5. Engineer's `done` on a subtask unblocks the next subtask directly; final review happens on the parent once all subtasks are terminal. Stage 7+ may add per-subtask Reviewer handoff.)
4. **`issue_children_completed` on the parent** — fires exactly once, when every child is terminal. Useful as a backstop, but the per-subtask @mention wakes drive the real orchestration.

The sequence across a feature: plan-approval → parent `issue_assigned` wake → subtask-graph creation + first PATCH → exit heartbeat → per-completion `issue_comment_mentioned` wakes → progressive PATCHes → final subtask `done` → parent → `in_review` → Stage 5 Reviewer wakes on `issue_status_changed`.

## The Process

1. **Read the plan.** On the parent `issue_assigned` wake, call `GET /api/issues/<parent-id>` and inspect `.planDocument`. `.planDocument.body` is the full plan (written by the Tech Lead's `writing-plans` skill on approval). If `.planDocument` is null, this is a pipeline ordering error: the board has assigned you to orchestrate before the plan exists. Post a comment `@<board> planDocument is null — cannot orchestrate; the plan authoring step has not run. Reassigning back.`, PATCH the issue with `{"status": "todo", "assigneeUserId": "<board-user-id>", "assigneeAgentId": null}` (board is a Paperclip user — see `../_shared/paperclip-conventions.md` § Field-split rule), and exit heartbeat. Do NOT fall back to `.description` — that was Stage 4's transitional behaviour and is no longer correct. Each slice in the plan has concrete Inputs/Outputs schemas, acceptance criteria, dependency annotations, and a `needsDesignPolish: boolean` flag; these become the subtasks' full definition.
2. **Decompose into subtasks.** Each subtask is one vertical slice of the plan with its own acceptance criteria. Number them. Identify the `blockedByIssueIds` edges: a subtask depends on another iff the earlier subtask's output is required before the later subtask can start or is testable. Shared workspace = add an edge (§ Red Flags).
3. **Choose the assignee role per subtask.** Stage 4: all subtasks go to the Engineer agent; there is no other role available yet. See § Model Selection.
4. **Create the subtask graph.** One `POST /api/companies/:id/issues` per subtask. Curl recipe in § Creating the Subtask Graph. The FIRST subtask in each chain is created with `assigneeAgentId: <engineer-agent-id>` and `status: "todo"`; every subsequent subtask is created with `assigneeAgentId: null` and `blockedByIssueIds: [<predecessor-id>]`.
5. **Pre-flight agent status checks.** Before creating subtasks, GET `/api/agents/<target-id>` for every agent you plan to assign (RULE 2). Confirm each target's `status !== "paused"`. If any target is paused, escalate per § Paused-Target Check before POSTing. The first subtask's assignee is set in the POST body itself — there is no separate PATCH for the first subtask. Subtasks 2..N are POSTed with `assigneeAgentId: null` (RULE 1) and assigned later via PATCH on per-completion wakes.
6. **Exit heartbeat.** You are done until the next wake.
7. **On each per-completion wake** (`issue_comment_mentioned`): parse the mention body for the terminal-status keyword (DONE, BLOCKED, NEEDS_CONTEXT, DONE_WITH_CONCERNS), identify the next subtask in the chain, GET its intended assignee, PATCH. See § Per-Completion Heartbeat.
8. **On the final subtask completing:** PATCH the parent issue to `status: "in_review"`. See § End-of-Feature Review.

The whole flow is driven by two HTTP verbs — POST to create, PATCH to progress — and one wake signal — `issue_comment_mentioned`. Everything else (status, telemetry, audit) is derived from the issues table.

## First Wake — Reading the Plan and Decomposing

On the first heartbeat for a parent feature issue, your `contextSnapshot` contains:

- `wakeReason: "issue_assigned"` — you are the newly-assigned Tech Lead on this parent issue
- the parent issue's id, title, description, and latest `plan` document (if one exists)

Read:

- The parent issue description in full
- `GET /api/issues/<parent-id>` — inspect `.planDocument`. `.planDocument.body` is the plan (always populated by `writing-plans` before this skill fires; null is a pipeline ordering error — see § The Process Step 1 for handling).
- Any ancestor issues (`.parentId` up the chain) for broader feature context

Decompose the plan into a subtask list. For each subtask, draft:

- **Title** — short imperative (e.g. `Add IssueSubtaskPanel pagination`)
- **Description** — the full subtask body, built from the Subtask Description Template (§ Subtask Description Template)
- **`blockedByIssueIds`** — predecessor subtask ids. Empty for the first subtask, one entry for each follower in a chain.
- **`parentId`** — the parent feature issue id you woke on.
- **Intended assignee** — who will get PATCHed when this subtask becomes the head of the ready set. Stage 4: Engineer agent.

Do NOT POST anything yet — finalize the list first. Cross-check each subtask against the § Subtask Description Template quality checklist (focused, self-contained, specific about output). Then execute § Creating the Subtask Graph.

## Creating the Subtask Graph

Every subtask is a `POST /api/companies/:company-id/issues` call. The required fields:

| Field | Value |
|---|---|
| `title` | Short imperative |
| `description` | Full subtask body (§ Subtask Description Template) |
| `parentId` | The parent feature issue id |
| `assigneeAgentId` | Engineer agent id for the FIRST subtask in a chain; `null` for every follower |
| `blockedByIssueIds` | `[]` for the head; `[<predecessor-id>]` for followers |
| `status` | `"todo"` — always, for EVERY subtask including followers with non-empty `blockedByIssueIds`. `"blocked"` is a RUNTIME-SET status (the assignee transitions to `blocked` when it reports a mid-work blocker via the Notification Protocol); it is NEVER a creation-time status, even when the subtask has predecessors. Stage 5 Anomaly 5. |

### Reading the `needsDesignPolish` flag per slice

Each slice in `.planDocument.body` declares a `needsDesignPolish: false | true` flag (see `writing-plans/SKILL.md` § Concrete Schemas). When creating each subtask, copy the flag value into the subtask description under a "Design Polish" header:

```
## Design Polish

**needsDesignPolish:** false
```

Stage 5 behaviour: always `false`, no Designer subtask spawned. Stage 6 will add: if `true`, create an additional follow-up subtask assigned to the Designer that depends on the Engineer's subtask completion. Stage 5 leaves this as a read-only surface to keep the plan→subtask mapping traceable.

### Stage 6 activation — spawning a Designer subtask when `needsDesignPolish: true`

When a slice in the plan has `needsDesignPolish: true`, create TWO subtasks for that slice, not one:

1. **Engineer subtask** — backend + baseline UI implementation, identical to a `needsDesignPolish: false` slice. All acceptance criteria from the slice's Required test cases belong here.
2. **Designer follow-up subtask** — visual polish on the working UI produced by the Engineer. Created immediately after the Engineer subtask, before you exit the heartbeat. Fields:
   - `parentId`: the feature parent issue id (same as the Engineer subtask)
   - `blockedByIssueIds: [<engineer-subtask-id>]` — Designer waits for Engineer's completion
   - `assigneeAgentId: null` — progressive assignment (RULE 1); the Tech Lead PATCHes the Designer id when the Engineer subtask reaches terminal status
   - `status: "todo"` — per § Creating the Subtask Graph field-table caveat, NOT `"blocked"`
   - `title`: "Polish UI for <slice-name> (from <engineer-subtask-identifier>)"
   - `description`: uses the Subtask Description Template, with `## Goal` scoped to visual polish, `## Required test cases` listing (a) "all Engineer subtask tests still pass" + (b) visual fidelity criteria derived from the spec's Interface section, `## Required implementation files` listing the same frontend file paths the Engineer wrote to (plus any new asset paths), and the standard Notification Protocol.

When the Engineer subtask completes (you wake on `issue_comment_mentioned` via RULE 3), progressively assign the Designer subtask using the same RULE 1 + RULE 2 procedure as any follower: GET the Designer's agent status, branch per the paused-target table, PATCH assigneeAgentId if safe.

In § End-of-Feature Review: wait for BOTH Engineer + Designer subtasks to be terminal before transitioning parent to `in_review`. This already falls out of the existing "all children terminal" check — no separate condition needed as long as the Designer subtask was created with the correct `parentId`.

**Slice with `needsDesignPolish: false`:** create only the Engineer subtask. Stage 5 behaviour; unchanged.

**Invariant:** for a slice with `needsDesignPolish: true`, the Engineer subtask is the chain head of its pair, the Designer subtask is the follower. Do NOT pre-assign the Designer subtask at creation time; progressive assignment is load-bearing (see RULE 1 and the Stage 5 Anomaly 4 note in § Post-POST verification).

**Design-break routing (spec §6.4):** if the Reviewer's final combined review flags a Designer-caused regression (broken tests on code Designer touched), the rejected subtask is the Designer one, not the Engineer one. This is already handled by `code-review/SKILL.md §1.5 Final combined review — if rejecting` which reassigns the specific offending subtask; no amendment needed here. The routing flows because the Reviewer identifies the offending commit via `git log` and maps it to the subtask that authored the commit.

### Curl recipe idiom

Every payload you submit MUST be written to a file first, then POSTed with `curl --data-binary @file`. Do NOT build payloads with `echo ... | curl -d @-` or inline heredocs piped to curl. Reason: zsh's `echo` interprets `\n` as a literal newline, which turns multi-line JSON strings into JSON parse errors, and `curl -d` applies `application/x-www-form-urlencoded` semantics that can strip bytes. This is Stage 3 Anomaly 2.

The idiom: use the Write tool to drop a JSON file, then `curl --data-binary @<path>`. String values that contain newlines MUST use `\n` escape sequences inside the JSON; the Write tool preserves the literal `\n` bytes, and the HTTP server parses them as JSON string newlines. zsh's `echo` cannot be trusted here.

**Recipe — create subtask 1 (head of chain, assigned):**

Write `/tmp/subtask-1.json`:

```json
{
  "title": "Add IssueSubtaskPanel pagination",
  "description": "## Goal\n\nAdd cursor pagination to IssueSubtaskPanel ...\n\n## Notification Protocol\n\nWhen terminal, post a single comment mentioning @tech-lead-agent ...",
  "parentId": "<parent-id>",
  "assigneeAgentId": "<engineer-agent-id>",
  "blockedByIssueIds": [],
  "status": "todo"
}
```

Then:

```
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  --data-binary @/tmp/subtask-1.json \
  https://paperclip.example/api/companies/<company-id>/issues
```

**Recipe — create subtask 2 (follower, unassigned, blocked by subtask 1):**

Write `/tmp/subtask-2.json`:

```json
{
  "title": "Wire IssueSubtaskPanel pagination to UI",
  "description": "## Goal\n\nConsume the cursor pagination added in subtask 1 ...\n\n## Notification Protocol\n\nWhen terminal, post a single comment mentioning @tech-lead-agent ...",
  "parentId": "<parent-id>",
  "assigneeAgentId": null,
  "blockedByIssueIds": ["<subtask-1-id>"],
  "status": "todo"
}
```

POST the same way. The response JSON contains the new subtask's `id`; capture each one so the next POST can reference it as a predecessor.

### Post-POST verification (RULE 1 + Anomaly 5 self-check)

After you POST every subtask in the chain, GET `/api/companies/<company-id>/issues?parentId=<parent-id>&limit=50` and verify BEFORE exiting the heartbeat:

- **Exactly ONE subtask per chain** has a non-null `assigneeAgentId` — the chain head. Every follower has `assigneeAgentId: null`. Stage 5 Anomaly 4: PAP-21 was created with `assigneeAgentId` pre-set; the Engineer happened to be idle so the pipeline worked, but a paused-target race would have deadlocked (RULE 2 exists precisely for this class of bug).
- **Every subtask has `status: "todo"`** — NOT `"blocked"`. Even followers with non-empty `blockedByIssueIds` create with `todo`. Stage 5 Anomaly 5: PAP-21 was created with `status: "blocked"`; `issue_blockers_resolved` rescued it, but `blocked → in_progress` is not the intended state-machine path.

If either invariant is violated, PATCH the offending subtask(s) to compliant state (`assigneeAgentId: null` for non-head subtasks; `status: "todo"` for anything at creation) BEFORE exiting the heartbeat. Do not rely on luck — an idle target or an auto-wake fallback — to rescue a malformed graph.

## Progressive Assignment — RULE 1

**Rule.** Every subtask chain assigns the FIRST subtask at creation. Every subsequent subtask is created with `assigneeAgentId: null`. The Tech Lead PATCHes the assignee ONLY after the predecessor reaches a terminal status (`done`, `blocked`, or `cancelled`). Never create a follower subtask with a non-null assignee. Never set the assignee at creation time on anything other than the chain head.

**Why.** Paperclip's default session-resumption behaviour keeps the same Claude session hot across wakes that do NOT appear in the session-reset list (`services/heartbeat.ts:715-730`). The wake reasons that DO reset the session include `issue_assigned`. Progressive assignment turns every subtask handoff into an `issue_assigned` wake for the assignee — which resets their session, forcing a clean context load of the subtask description.

If you created all subtasks with their assignee set at POST time, the initial `issue_assigned` wake would fire while the subtask is `blocked` (no cwd, no context), and by the time the blocker clears the assignee has already received that wake — it is not re-fired on unblock. Result: the subtask is assigned but the assignee never wakes. Progressive PATCH sidesteps this by firing the wake at the precise moment the subtask is runnable.

Spec §5.4 (amended in Stage 3) formalizes this behaviour as a Tech Lead obligation, not an optimization.

### Invariant

- At all times, AT MOST ONE subtask per chain has a non-null `assigneeAgentId` (the currently-executing one).
- On POST: only the head of each chain has an assignee; all followers have `assigneeAgentId: null`.
- On predecessor terminal: PATCH the next-in-line subtask's `assigneeAgentId` (after the RULE 2 paused-target check).

### Worked example — 3-subtask chain

Subtasks A → B → C (B blocked by A, C blocked by B). All three go to the Engineer.

1. POST subtask A with `assigneeAgentId: <engineer-id>`, `blockedByIssueIds: []`.
2. POST subtask B with `assigneeAgentId: null`, `blockedByIssueIds: [A-id]`.
3. POST subtask C with `assigneeAgentId: null`, `blockedByIssueIds: [B-id]`.
4. The Engineer wakes on A's `issue_assigned`, works, posts `@tech-lead DONE — ...`, sets A `done`. This unblocks B but does NOT auto-assign it.
5. You wake on `issue_comment_mentioned`. Confirm A is terminal. GET the Engineer agent (RULE 2). If `status !== "paused"`, PATCH B with `assigneeAgentId: <engineer-id>`.
6. Engineer wakes fresh on B's `issue_assigned`, works, posts `@tech-lead DONE — ...`.
7. You wake. Same GET + PATCH for C.
8. Engineer completes C. You PATCH the parent to `in_review`.

**Never** POST subtask B or C with the assignee id set at creation. **Never** short-circuit the RULE 2 GET before the PATCH, even if you PATCHed the same agent 30 seconds ago — status can change between your wakes.

See § Paused-Target Check for the PATCH guard.

## Paused-Target Check — RULE 2

**Rule.** Before every `PATCH /api/issues/:id` that sets `assigneeAgentId` to a non-null value, issue `GET /api/agents/:target-id` and branch on the returned `status` field.

**Why.** The `issue_assigned` wake is enqueued to the target agent's heartbeat queue. If the agent is `paused`, the heartbeat runtime silently drops the wake — there is no bounce, no error, no retry. The subtask sits assigned but the assignee never runs. Stage 3 Anomaly 1 documented this failure mode after a pipeline deadlocked for two hours because a PATCH landed on a paused Engineer.

### Branch table

| `GET /api/agents/:id` returns `status` | Action |
|---|---|
| `"paused"` | DO NOT PATCH. Escalate — see § Escalation when target paused below. |
| `"idle"` | PATCH safe. Fire the assignee update. |
| `"running"` on a different issue | Scheduler will serialize (Stage 2 Anomaly 5). PATCH safe — the wake queues behind the agent's current heartbeat. Log that the wake was queued, proceed. |
| `"running"` on the SAME issue you're PATCHing | Anomalous — you shouldn't be assigning an agent to an issue it's already on. Abort, re-read the subtask's state. |

This check is MANDATORY on every PATCH, including the first PATCH of the first subtask right after you POST it. Pausing can happen between your POST and your PATCH.

### Escalation when target paused

Default escalation (option a):

1. Post a comment on the subtask: `@<board-agent-name> Target agent <engineer-name> is paused; cannot assign subtask <id>. Blocking this subtask and the parent pending resume.`
2. PATCH the subtask to `status: "blocked"`.
3. PATCH the parent to `status: "blocked"`.
4. Exit heartbeat. The board's resolution wakes you again.

Authorized-resume path (option b) — only if your skill config permits it:

1. `POST /api/agents/<target-id>/resume` to unpause.
2. Re-run the RULE 2 GET. Proceed to PATCH only if `status` is now `idle` or `running`.

Default is option a. Silent wake drops are the failure mode prevented; escalation is cheap, incorrect resume is expensive.

## Notification Protocol — RULE 3

**Rule.** Every subtask description you author includes a "Notification Protocol" section instructing the assignee to post a single `@<tech-lead-name>` mention comment at terminal status, followed by the issue-status transition. This is what wakes you per completion.

**Why.** `issue_comment_mentioned` fires on every mention comment (`server/src/routes/issues.ts:2320-2346`) and is NOT in the session-reset list in `services/heartbeat.ts:715-730`, so your session is resumed (cheap — warm cache, full context). By contrast, `issue_children_completed` fires only when ALL children are terminal (`server/src/services/issues.ts:1347-1376`), making it useless as a per-subtask trigger. You need a signal per subtask completion.

### Template — include verbatim in every subtask description

```
## Notification Protocol

When you reach a terminal state, post ONE comment on this issue mentioning @{{tech-lead-name}}, then transition issue status. Use this format:

- On success (tests pass, implementation complete):
  "@{{tech-lead-name}} DONE — <one-sentence summary>. Commits: <sha1>[, <sha2>...]."
  Then set this issue status to `done`.

- On success but with concerns (done but you have doubts):
  "@{{tech-lead-name}} DONE_WITH_CONCERNS — <one-sentence summary>. Concerns: <what you're uncertain about>. Commits: <sha1>[, <sha2>...]."
  Then set this issue status to `done`.

- On blocker (cannot complete):
  "@{{tech-lead-name}} BLOCKED — <what's blocking>. Tried: <what you tried>. Need: <what would unblock>."
  Then set this issue status to `blocked`.

- On ambiguity (need clarification before proceeding):
  "@{{tech-lead-name}} NEEDS_CONTEXT — <the question>."
  Leave this issue at `in_progress` and wait for a reply comment.

Do NOT @-mention yourself in any of these comments (self-wake loop).
```

Substitute `{{tech-lead-name}}` with your actual agent name at POST time — the assignee cannot look it up from its own context.

### DONE_WITH_CONCERNS asymmetry (Paperclip-specific)

Upstream handles DONE_WITH_CONCERNS inline — the controller sees the concern text in the same turn as the completion report. Paperclip handles it across separate heartbeats: the assignee posts the concern in its completion comment, then exits; you wake on the `@mention`, read the concern, and decide whether to (a) continue the chain (concern is an observation, e.g. "this file is getting large"), (b) escalate to the board (concern is a correctness or scope issue), or (c) reopen the subtask with more context (concern is actually a NEEDS_CONTEXT in disguise). Budget a second heartbeat for (c) — the follow-up conversation runs through the normal Q&A flow.

### Self-wake loop caution

NEVER @-mention yourself in a comment body you author on a subtask you created. The mention would fire `issue_comment_mentioned` on YOU, which re-enters this skill and treats your own comment as an assignee's completion notification. The Notification Protocol instruction to the assignee tells them NOT to self-mention; you must observe the same rule in your Q&A replies.

## Subtask Description Template

Every subtask description has seven sections. Build the description string (with `\n` escape sequences between sections) and embed it as the `description` field in the POST payload.

### 1. Goal

One paragraph. What this subtask produces when it succeeds. Match the slice's acceptance criteria from the plan.

### 2. Context

- Where this subtask sits in the overall feature (cite the parent issue id and the plan section).
- Upstream subtasks' outputs if this subtask depends on them.
- Architectural context the assignee needs that ISN'T obvious from the code.

### 3. Required test cases OR Required acceptance checks

For code: list the test cases the assignee must write (and make pass). Be specific — test file, test name, assertion.
For infra/config: list the acceptance checks the assignee must verify.

### 4. Required implementation files

Paths of the files the assignee should create or modify. Reduces ambiguity and catches plan-vs-implementation drift.

### 5. Workflow

The expected order of work. Typical: read context → TDD → implement → self-review → commit → notify.

### 6. Exit criteria

Bulleted list of must-be-true-before-done conditions. Tests green. Commits made. No regressions. Self-review completed.

### 7. Notification Protocol

Verbatim from § Notification Protocol. Do not paraphrase — the exact string-format of the mention comment is what downstream automation parses.

### Quality checklist (absorbed from dispatching-parallel-agents)

Before POSTing a subtask, verify its description is:

1. **Focused** — one clear problem domain. If the subtask covers two unrelated files or two different goals, split it.
2. **Self-contained** — all the context the assignee needs is inline in the description. The assignee should not need to read the parent plan document to proceed. Cite paths but don't require the assignee to fetch external documents unless essential.
3. **Specific about output** — the Notification Protocol section specifies exactly what the assignee returns: status keyword, summary, commit SHAs. Ambiguous expected output leads to ambiguous completion comments.

The full-length implementer subtask body lives at `./implementer-subtask-template.md`. Two dormant templates exist for Stage 5 when the Reviewer agent is hired: `./spec-review-subtask-template.md` and `./code-quality-review-subtask-template.md`. Do not use the dormant templates in Stage 4.

## Per-Completion Heartbeat — Acting on @mention Wakes

You wake with `contextSnapshot.wakeReason == "issue_comment_mentioned"`. The triggering subtask id is in `contextSnapshot.issueId`. Fetch its comments to read the mention: `GET /api/issues/<issue-id>/comments?limit=10`. Read the most recent mention comment.

1. **Parse the keyword.** The comment starts with `@<tech-lead-name> <KEYWORD> — ...`. Branch on KEYWORD:
   - `DONE` or `DONE_WITH_CONCERNS` — the subtask completed. Read its status (it should be `done`) and move to step 2. For `DONE_WITH_CONCERNS`, see § Notification Protocol — DONE_WITH_CONCERNS asymmetry for when to pause the chain before advancing.
   - `BLOCKED` — the subtask is stuck. Read the comment's "Need:" section. If the blocker is missing information, post a clarifying comment (without self-mention — see § Q&A Protocol). If the blocker is architectural or requires more power, escalate to the board: post `@<board> subtask <id> blocked: <reason>. Plan may need revision.` and PATCH the parent to `blocked`. Exit.
   - `NEEDS_CONTEXT` — see § Q&A Protocol.
2. **Identify the next subtask.** Query the parent's children: `GET /api/companies/<company-id>/issues?parentId=<parent-id>&limit=20`. Find the first child with `status: "todo"` whose `blockedByIssueIds` are now all terminal. That's the next-in-line. Recover `<company-id>` from `contextSnapshot` or from the parent issue's `companyId` field.
3. **Paused-target check.** `GET /api/agents/:next-assignee-id`. Branch per the RULE 2 table.
4. **PATCH the next subtask's assignee.** `PATCH /api/issues/:next-subtask-id` with `{"assigneeAgentId": "<engineer-id>"}`.
5. **If no next-in-line (all children terminal)** proceed to § End-of-Feature Review.
6. **Exit heartbeat.**

Handle DONE_WITH_CONCERNS per the asymmetry note in § Notification Protocol: the concern text may require its own follow-up heartbeat before you advance the chain.

## Q&A Protocol

When an assignee posts `@<tech-lead-name> NEEDS_CONTEXT — <question>`:

1. You wake on `issue_comment_mentioned`.
2. Read the question and the subtask's full description + comment thread.
3. Post a clarification comment on the subtask. **Do NOT @-mention the assignee by name** — the assignee's existing subscription to its own assigned issue produces an `issue_commented` wake (spec §5.1), which is the reliable re-wake signal. An @-mention would also work but risks your comment being mis-parsed as a completion signal by downstream consumers that look for any mention.
4. Specifically, do NOT @-mention yourself. Self-mention creates a self-wake loop.
5. Exit heartbeat. The assignee re-wakes on `issue_commented`, reads your answer, continues work, and will post its `DONE` / `BLOCKED` / further `NEEDS_CONTEXT` mention when it reaches the next terminal state.

If the question is ambiguous or reveals a plan-level issue, escalate to the board rather than bouncing uncertainty back at the assignee.

## End-of-Feature Review

Final subtask terminal (all children `done` / `blocked` / `cancelled`, at least one `done`):

1. Read all completion comments on all children. Verify each reported `DONE`/`DONE_WITH_CONCERNS` lines up with an actual `done` status on the child.
2. If every child is `done` (success path): PATCH the parent with `{"status": "in_review"}`. This fires `issue_status_changed` on the Reviewer agent (Stage 5). Until Stage 5 exists, the parent sits in the `in_review` queue — the Tech Lead's job ends here.
3. If any child is `blocked` and the blocker wasn't resolved: PATCH the parent to `blocked`, post a summary comment on the parent explaining which subtask is blocking and why, and @-mention the board.
4. Exit heartbeat.

## Parallelism via Independence

Absorbed from dispatching-parallel-agents. Two subtasks are parallelizable iff BOTH of:

1. Neither appears in the other's `blockedByIssueIds` chain (transitive). Their outputs are independent.
2. They target different execution workspaces (different agent cwds), OR they share an agent that will serialize them internally.

If (1) is true but (2) isn't — same workspace, independent goals — you MUST still add a `blockedByIssueIds` edge to force serial execution. Shared cwd without an explicit edge causes cross-file state contamination (Stage 3 Anomaly 4). The parallelism payoff is zero and the regression risk is high.

Stage 4 validation is all-serial: only the Engineer's workspace exists, so every subtask shares one cwd, so every subtask must be chained. Stage 6 introduces the Designer agent with its own isolated cwd — at that point, a backend-only subtask (Engineer's cwd) and a design-polish subtask (Designer's cwd) can run in parallel as long as their outputs don't collide at merge.

Declaring parallelism is the ABSENCE of a `blockedByIssueIds` edge. If you omit the edge, you are asserting both (1) and (2). Treat that assertion as load-bearing.

## Model Selection

Stub: Paperclip's `assigneeAgentId` picks a NAMED agent, not a model tier. The role-to-agent mapping is fixed at company configuration time; you don't select a model per subtask.

Stage 4 has one assignable role — the Engineer agent — so the mapping is trivial: every subtask's assignee is the Engineer. Every agent's default model (`claude-opus-4-6[1m]` at time of writing) is what runs.

Future: per-issue `assigneeAdapterOverrides.model` to override the agent's default model on a per-subtask basis. Stage 4 leaves the overrides field null; Paperclip falls back to the agent's default. Explicit model-tier dispatch is a Stage 6 follow-up.

Do not treat this section as advice to pick a model — there is no selection to make in Stage 4.

## Example Workflow

Concrete 2-subtask walkthrough. Placeholder ids: parent `P`, subtask 1 `S1`, subtask 2 `S2`, Engineer `E`, Tech Lead `TL`.

**Wake 1 — parent `issue_assigned` fires on TL.**

Read plan from parent P description. Decompose into S1 (add migration) and S2 (wire API to migration output). S2 depends on S1.

Write `/tmp/s1.json`:

```json
{
  "title": "Add migration for subtask_order column",
  "description": "## Goal\n\nAdd a nullable subtask_order column to issues ...\n\n## Notification Protocol\n\n...@<TL-name> DONE — ... ",
  "parentId": "P",
  "assigneeAgentId": "E",
  "blockedByIssueIds": [],
  "status": "todo"
}
```

`curl --data-binary @/tmp/s1.json -X POST https://paperclip.example/api/companies/<co>/issues` — returns `{"id": "S1", ...}`.

Write `/tmp/s2.json`:

```json
{
  "title": "Wire IssueSubtaskPanel to subtask_order",
  "description": "## Goal\n\nRead subtask_order from S1's migration ...\n\n## Notification Protocol\n\n...@<TL-name> DONE — ... ",
  "parentId": "P",
  "assigneeAgentId": null,
  "blockedByIssueIds": ["S1"],
  "status": "todo"
}
```

POST as above — returns `{"id": "S2", ...}`.

GET `/api/agents/E` — `{"status": "idle"}`. RULE 2 passes.

PATCH S1 — actually, S1 already has `assigneeAgentId: E` from the POST, so the first subtask needs no progressive PATCH. The `issue_assigned` wake fires on E when the issue is created with the assignee set. E wakes fresh, works S1.

Exit heartbeat.

**Wake 2 — `issue_comment_mentioned` fires on TL.**

Mention comment on S1: `@<TL-name> DONE — migration added. Commits: a1b2c3d.`

S1 status is `done`. Confirm the commit. Next-in-line is S2. GET `/api/agents/E` — `{"status": "idle"}`. RULE 2 passes.

Write `/tmp/patch-s2.json`:

```json
{"assigneeAgentId": "E"}
```

`curl --data-binary @/tmp/patch-s2.json -X PATCH https://paperclip.example/api/issues/S2` — S2's `issue_assigned` fires on E.

Exit heartbeat.

**Wake 3 — `issue_comment_mentioned` fires on TL.**

Mention comment on S2: `@<TL-name> DONE — API wired. Commits: e4f5a6b.`

S2 is `done`. No more children in `todo`. All terminal.

Write `/tmp/patch-parent.json`:

```json
{"status": "in_review"}
```

`curl --data-binary @/tmp/patch-parent.json -X PATCH https://paperclip.example/api/issues/P` — P transitions to `in_review`. Stage 5 Reviewer will wake on `issue_status_changed`; Stage 4 ends here.

Exit heartbeat. Tech Lead's job complete.

## Red Flags

**Never** assign a non-head subtask at creation time. Violates RULE 1. The subtask's `issue_assigned` wake fires while it's blocked, the assignee's session resets against no cwd, and the subtask never runs.

**Never** PATCH `assigneeAgentId` without the GET agent-status check immediately prior. Violates RULE 2. Silent wake drop; dead subtask.

**Never** omit the Notification Protocol section from a subtask description. Violates RULE 3. You will not reliably wake on completion; pipeline stalls.

**Never** put two subtasks on the same workspace without a `blockedByIssueIds` edge between them. Stage 3 Anomaly 4 proved this — two subtasks that touched different test files but shared the Engineer's cwd produced cross-file state contamination in the test suite. Shared cwd = chain edge, always.

**Never** @-mention yourself in the body of a subtask description or a Q&A reply you authored. Self-mention fires `issue_comment_mentioned` on YOU, re-entering this skill with your own comment as the trigger. The Notification Protocol template ALREADY contains this warning for the assignee; apply the same rule to your own comments.

**Never** accept a subtask description that fails the quality checklist (not focused, not self-contained, vague output format). An assignee with a sloppy description returns a sloppy completion comment, and every downstream parse breaks.

**Never** write "Thanks" or "Great work" in a completion-response comment. Paperclip comments are artifacts, not social exchange. If you need to respond, state the next action: "Proceeding to subtask S3 — PATCH in flight."

**Stuck subtask across 3 consecutive wakes** — set the subtask to `blocked`, post a summary comment with all three wake contexts, @-mention the board, PATCH the parent to `blocked`. Escalate rather than spin.

**Board rejects plan 3 times** — escalate (spec §6.1). Further revision attempts without a plan-level retrospective waste budget.

**Bare-"subagent" language in a subtask description** — the word "subagent" is a CLI-ism. Use "subtask assignee" or "the assignee agent" in subtask bodies so the assignee parses the description correctly.

## Integration

**Companion Paperclip skills:**

- `writing-plans` (Stage 5) — produces the plan document this skill consumes. Until Stage 5, the plan lives in the parent issue description.
- Engineer-agent frozen skills (Stage 2) — `test-driven-development`, `code-review`, `verification-before-completion`, etc. — these are what your assignees invoke inside their subtask heartbeats. You do NOT invoke them yourself; the Engineer's `assignedSkills` loads them on its own wake.
- Reviewer-agent skills (Stage 5) — consume the `status: in_review` parent. `code-review`'s trigger 4 ("Final combined review") fires when you PATCH the parent to `in_review`.

**Execution model reminder.** This skill operates in Paperclip's heartbeat model: no CLI, no in-session subagent dispatch primitive, no local to-do list tool. The subtask graph IS your task list; progressive assignment IS your dispatch primitive; `issue_comment_mentioned` IS your completion signal. Spec §5 "Adaptation Rules" formalizes these substitutions.
