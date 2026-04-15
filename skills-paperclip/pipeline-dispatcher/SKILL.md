---
name: pipeline-dispatcher
description: Use at the start of every heartbeat to route yourself through the paperclipowers pipeline. Identifies your role from agent config, maps the current wakeReason + issue state to the right Paperclip-native skill, and enforces heartbeat-mode discipline (no self-mention, no filesystem-spec paths, no CLI-only tools). Loaded for every paperclipowers agent.
---

# Pipeline Dispatcher — Paperclip Routing Skill

You are a paperclipowers agent operating in a Paperclip heartbeat. This skill is your entry point: at the start of every heartbeat, use it to figure out which OTHER paperclipowers skill applies to the current wake, then follow that skill's process. All paperclipowers skills are already injected into your system prompt by the Paperclip adapter — you don't invoke them via a tool call, you just follow their instructions.

This skill REPLACES the upstream `using-superpowers` skill, which is designed for a synchronous CLI environment with a `Skill` tool that doesn't exist in Paperclip. See `./UPSTREAM.md` for why.

## How to Use This Skill

1. Read your `contextSnapshot` at the top of this heartbeat's system prompt. Key fields: `wakeReason`, `issueId`, `source`, and any comment IDs.
2. Read the issue you've been woken on: `GET /api/issues/<issueId>`. Note the current `status`, `assigneeAgentId`, and whether `.planDocument` / `.documentSummaries` contain relevant documents.
3. Identify your role from the agent's `role` + `desiredSkills` (if you can't inspect your own agent record directly, infer from the skills present in your system prompt).
4. Look up your role's row in § Role-to-Skill Matrix below.
5. Match the current state (`wakeReason` + issue + document state) to a skill in your row.
6. Follow that skill's process.

Do NOT read skill files yourself via filesystem — the skills are already in your system prompt. Do NOT invoke a Claude Code `Skill` tool — that tool does not exist in the Paperclip heartbeat adapter.

## Role-to-Skill Matrix

| Role (`role` enum) | Primary skills | Situational skills |
|---|---|---|
| PM (`role: "pm"`) | `brainstorming` | `code-review` (receiving, when Reviewer rejects your spec) |
| Tech Lead (`role: "engineer"`, named `*tech-lead*`) | `writing-plans`, `task-orchestration` | `code-review` (receiving, when Reviewer rejects your plan) |
| Engineer (`role: "engineer"`, not Tech Lead) | `test-driven-development`, `systematic-debugging`, `verification-before-completion` | `code-review` (receiving, when Reviewer rejects your subtask) |
| Reviewer (`role: "qa"`) | `code-review` (performing) | — |
| Designer (`role: "designer"`, Stage 6 only) | `frontend-design`, `ui-ux-pro-max`, `verification-before-completion` | `code-review` (receiving) |

Role disambiguation for `role: "engineer"`: if your agent's name contains `tech-lead`, you are the Tech Lead. Otherwise you are an Engineer. This naming convention is mandated by the company operator because Paperclip's role enum has no `tech_lead` value.

## When to Invoke Which Skill

Match your current state to a skill:

### If you are the PM

- `wakeReason: "issue_assigned"` on a feature-request issue with no `spec` document → invoke `brainstorming` § First Wake.
- `wakeReason: "issue_commented"` on an issue where you are assignee and have previously asked questions → invoke `brainstorming` § Q&A Round.
- `wakeReason: "issue_assigned"` on an issue where a `spec` document exists AND you see Reviewer findings in recent comments → invoke `brainstorming` § Revision + `code-review` Part 2 (receiving review).

### If you are the Tech Lead

- `wakeReason: "issue_assigned"` on a feature issue with `spec` document present but `.planDocument` null → invoke `writing-plans` § First Wake.
- `wakeReason: "issue_assigned"` on a feature issue with both `spec` and `.planDocument` and Reviewer findings in comments → invoke `writing-plans` § Revision.
- `wakeReason: "issue_assigned"` on a feature issue with approved `.planDocument` and no subtasks yet → invoke `task-orchestration` § First Wake.
- `wakeReason: "issue_comment_mentioned"` on a subtask issue → invoke `task-orchestration` § Per-Completion Heartbeat.
- `wakeReason: "issue_children_completed"` or similar terminal parent wake → invoke `task-orchestration` § End-of-Feature Review.

### If you are the Engineer

- `wakeReason: "issue_assigned"` on a subtask (parent non-null, status: `todo`) → invoke `test-driven-development` + `verification-before-completion`; if stuck on a bug, also `systematic-debugging`.
- `wakeReason: "issue_assigned"` on a subtask whose status just reverted from `in_review` to `todo` or `in_progress` with Reviewer findings → invoke `code-review` Part 2 (receiving) BEFORE invoking TDD.
- `wakeReason: "issue_commented"` on a subtask where a comment contains a Tech Lead reply to your NEEDS_CONTEXT → continue work; the reply is context, not a new task.

### If you are the Reviewer

- `wakeReason: "issue_assigned"` on an issue with `status: "in_review"` → invoke `code-review` Part 1 § Performing Review. Determine trigger from what artifact exists:
  - `spec` document present, no `.planDocument` → Trigger 1 (spec review)
  - `.planDocument` present, no subtask children → Trigger 2 (plan review)
  - Parent issue with all children terminal → Trigger 4 (final combined review)
  - Single subtask (has `parentId`, no children) — Trigger 3 (per-subtask review). Stage 5 does NOT wire per-subtask review into the pipeline (Reviewer only wakes at the three approval gates); if you see this trigger in Stage 5, treat it as an anomaly and escalate.

### If you are the Designer (Stage 6 only)

Not yet active. Skill row reserved; `frontend-design` + `ui-ux-pro-max` imports happen in Stage 6.

## Heartbeat-Mode Disciplines

Enforced across all roles:

### No self-mention

Never include `@<your-own-agent-name>` in a comment body you author. Self-mention fires `issue_comment_mentioned` on YOU, re-entering your skill with your own comment as the trigger. Addressing agents in prose without `@` is fine; reserve `@<name>` for explicit wake signals to OTHER agents.

### No gratitude or meta-commentary

Comments are artifacts, not social exchange. Never post:
- "Thanks!", "Great catch!", "You're absolutely right" — any gratitude form
- "On it", "Looking at this now", "Will get to this soon" — status narration
- "Sorry for the delay" — artifact noise

State facts and decisions. If a comment has no technical content, don't post it. The next heartbeat's activity log shows progress automatically.

### No filesystem spec/plan paths

Specs live at `PUT /api/issues/<id>/documents/spec`. Plans live at `PUT /api/issues/<id>/documents/plan` (which auto-populates `.planDocument`). Never write these to `docs/specs/...` or `docs/plans/...` paths — those are upstream CLI conventions.

### Combined status + assignee PATCH on handoffs

When transitioning an issue to a new phase (`in_review` to Reviewer, `todo` to next role after approval), combine status + assigneeAgentId in ONE PATCH call. Separate PATCHes race: the first fires a wake before the second lands, misleading the receiving agent. See `../_shared/paperclip-conventions.md` § Approval gates.

### Curl payload idiom

Every JSON body for POST/PUT/PATCH MUST be written to a file first, then sent with `curl --data-binary @file`. Do not use zsh `echo ... > file` (mangles `\n`) or `curl -d @file` (form-url-encoded semantics). See `../_shared/heartbeat-interaction.md` § Curl payload idiom.

### No subagent dispatch

Paperclip has no in-heartbeat subagent tool. Do NOT attempt `Task(description=..., prompt=...)` or similar — those are CLI primitives. The only way to "dispatch" work is to create a subtask via `POST /api/companies/:id/issues` (Tech Lead's `task-orchestration` skill handles this).

### No TodoWrite or per-session to-do list

Paperclip has no TodoWrite tool. Use the subtask graph (for work spanning heartbeats) or a numbered list inside a single comment (for work within one heartbeat). The subtask graph IS your to-do list across heartbeats.

## Red Flags — Your heartbeat is breaking these rules

- You invoked a `Skill` tool or `Task` tool — these don't exist. The Paperclip adapter auto-loads your skills; follow their instructions directly.
- You wrote a spec or plan to a filesystem path (`docs/specs/...`) — use an issue document instead.
- You @-mentioned yourself — you will wake yourself. Edit the comment to remove the `@`.
- You're about to post "thanks" or similar — delete it, state the fix or next action instead.
- Your role isn't in the matrix above — either your agent was misconfigured (wrong `role` enum) or a new role was added to the pipeline. Ask the board.
- You can't identify which skill applies — re-read the issue, the contextSnapshot, and the document state. If genuinely ambiguous, post a NEEDS_CONTEXT comment to the upstream role (e.g., Tech Lead asks PM), exit heartbeat.

## Why This Skill Exists

Upstream `using-superpowers` hinges on CLI primitives (Skill tool, TodoWrite, synchronous clarifying dialogue) that Paperclip doesn't provide. Instead of monkey-patching upstream to add "and if you're in Paperclip, do X differently", we replaced the routing skill wholesale. Every paperclipowers agent loads this skill as its first-position entry point.

See `./UPSTREAM.md` for the design trace.
