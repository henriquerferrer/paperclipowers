# Paperclipowers — Design Spec

**Date:** 2026-04-13
**Status:** Design approved, pending implementation planning
**Upstream:** Fork of [obra/superpowers](https://github.com/obra/superpowers) v5.0.7

---

## 1. Purpose

Paperclipowers is a Paperclip-native adaptation of the superpowers skills framework. It brings structured software development pipelines — brainstorm → spec → plan → implement → review → verify — to autonomous AI agents operating inside Paperclip.

The original superpowers is designed for synchronous CLI conversation (Claude Code, Cursor, Codex). Paperclip agents operate on an async heartbeat model: short execution windows triggered by events, communicating through issue comments and formal approvals. This fork adapts the skills to that model while preserving the discipline (TDD, verification, fresh-context review) that makes superpowers valuable.

## 2. Core Design Decisions

These are the load-bearing decisions. If any of these change, the rest of the design must be revisited.

### 2.1 Sequential vertical slices, not parallel

Research on AI multi-agent coordination (Cognition "Don't Build Multi-Agents", Anthropic's multi-agent research paper, arXiv 2503.13657 on failure modes) consistently shows that parallel AI agents working from a shared prose contract fail because:

- Ambiguous specs are filled in consistently-within-agent but inconsistently-across-agents
- No test fails, no type error raises — bugs are silent and surface at integration
- 42% of multi-agent failures trace to bad specifications, 37% to coordination breakdowns

Paperclipowers adopts the vertical slice pattern: one agent owns a feature end-to-end (backend + frontend with real data), sequentially. Parallelism is reserved for genuinely independent work across *different* features, not the two halves of one feature.

### 2.2 Concrete schemas in plans, not prose contracts

When contracts are used between agents (e.g., Tech Lead's plan handed to Engineer), they must be machine-verifiable: TypeScript types, OpenAPI/JSON Schema, exact function signatures. AI agents rationalize around prose; they cannot rationalize around a type-checked interface.

### 2.3 Real data from the start, no mocks

AI-generated mocks encode the AI's hallucinated guess at backend behavior. Frontends built on those mocks bake in wrong field names, nullability, pagination shapes, and edge-case handling. Evidence (Xano, LogRocket, Variant Systems on v0) shows backend-first or backend-inline yields "dramatically better" frontend quality for AI agents.

Full-Stack Engineer builds both layers together with real data. Designer polishes afterward against the working product.

### 2.4 Role separation for fresh-context review

Multi-agent code review catches 3x more bugs than self-review (diffray.ai, GitHub Copilot Rubber Duck, obra/superpowers). But diminishing returns kick in past 5-6 roles (Anthropic "Building Effective Agents", Addy Osmani). Reviewers at artifact boundaries (spec, plan, code) add value. Intermediate "orchestration reviewers" do not.

### 2.5 Per-agent tool isolation

Magic MCP costs credits on every call. ui-ux-pro-max adds 161 design rules the backend engineer doesn't need. LLMs perform worse with irrelevant tools in context. Per-agent MCP + skill isolation via Paperclip's existing `adapterConfig.cwd` + `.mcp.json` pattern keeps each agent focused.

## 3. The Pipeline — 6 Roles

### 3.1 Role definitions

| Role | Skills | MCPs | Responsibility |
|------|--------|------|----------------|
| **Product Manager** | `brainstorming` | — | Turn raw ideas into approved specs through Q&A |
| **Quality Reviewer** | `code-review` | — | Fresh-context review of specs and plans at approval gates |
| **Tech Lead** | `writing-plans`, `task-orchestration` | — | Write implementation plan with concrete schemas, decompose into vertical-slice subtasks |
| **Full-Stack Engineer** | `test-driven-development`, `systematic-debugging`, `verification-before-completion` | — | Build the entire vertical slice end-to-end with real data |
| **Designer / Frontend** | `ui-ux-pro-max`, `verification-before-completion` | 21st.dev Magic, Figma | *Optional per slice.* Polish working UI with design system reasoning and generated components |
| **Code Reviewer + QA** | `code-review`, `verification-before-completion` | — | Final review of combined output, run tests, verify acceptance criteria |

**Decomposition rule:** Tech Lead decomposes plans into *vertical slices* (each a complete feature from DB to UI), not *horizontal layers* (backend subtask + frontend subtask). Within a single slice, work is sequential and owned by one agent. Dependencies via `blockedByIssueIds` express cross-slice dependencies (e.g., "shared component library" blocks "user settings page"), not intra-slice ordering.

### 3.2 Feature flow

```
Board (you) creates issue with the ask
  ↓
PM: brainstorm via comments (2-3 Q&A rounds, batched questions per heartbeat)
  → writes spec to issue document (key: `spec`)
  → creates formal approval
  ↓
Quality Reviewer: reviews spec document with fresh context
  → comments findings, approval proceeds to you
  ↓
Board: approves spec (formal approval gate #1)
  ↓
Tech Lead: writes plan with concrete TS schemas, dependency annotations
  → saves to issue document (key: `plan`)
  → creates formal approval
  ↓
Quality Reviewer: reviews plan against spec
  → approval proceeds to you
  ↓
Board: approves plan (formal approval gate #2)
  ↓
Tech Lead: decomposes plan into Paperclip subtasks with blockedByIssueIds
  → assigns each subtask to appropriate role
  → flags subtasks that need Designer polish
  ↓
Full-Stack Engineer: implements each slice end-to-end
  → TDD loop internally, uses real data
  → Paperclip auto-wakes dependent subtasks on completion
  ↓
Designer (optional, if Tech Lead flagged):
  → polishes UI of completed slice
  → uses ui-ux-pro-max for design system decisions
  → uses Magic MCP to generate refined components
  → backend stays stable during this phase
  ↓
Code Reviewer + QA: combined review
  → reads git diff from base to HEAD
  → reviews against plan's acceptance criteria
  → runs full test suite, verifies E2E
  → if issues → back to Engineer/Designer with specific fixes
  → if pass → marks parent issue done, creates PR
  ↓
Board (you): review PR, merge (or auto-merge if fully trusted)
```

### 3.3 Board touchpoints

You interact with the pipeline at exactly these points:

1. **Issue creation** — the initial ask
2. **Brainstorm Q&A** — 2-3 comment replies during spec refinement
3. **Spec approval** — formal approval in the queue
4. **Plan approval** — formal approval in the queue
5. **PR review** — final check before merge (optional if you trust QA fully)

Everything else is autonomous. Escalations only reach you when the pipeline is genuinely stuck (see Section 6).

## 4. Repository Structure

```
paperclipowers/
├── skills/                          # Original superpowers, synced with upstream
│   ├── brainstorming/
│   ├── writing-plans/
│   ├── executing-plans/
│   ├── subagent-driven-development/
│   ├── dispatching-parallel-agents/
│   ├── test-driven-development/
│   ├── systematic-debugging/
│   ├── verification-before-completion/
│   ├── requesting-code-review/
│   ├── receiving-code-review/
│   ├── finishing-a-development-branch/
│   ├── using-git-worktrees/
│   ├── using-superpowers/
│   └── writing-skills/
│
├── skills-paperclip/                # Paperclip-native adaptations
│   ├── _shared/
│   │   ├── heartbeat-interaction.md      # How to post comments, exit heartbeat, resume
│   │   └── paperclip-conventions.md      # Issue documents, approvals, status transitions
│   │
│   ├── brainstorming/                    # PM skill — heavy rewrite
│   │   └── SKILL.md
│   ├── writing-plans/                    # Tech Lead skill — heavy rewrite, concrete schemas
│   │   └── SKILL.md
│   ├── task-orchestration/               # Tech Lead skill — NEW, Paperclip subtask creation
│   │   └── SKILL.md
│   ├── test-driven-development/          # Engineer — minimal adaptation
│   │   ├── SKILL.md
│   │   └── testing-anti-patterns.md
│   ├── systematic-debugging/             # Engineer — minimal adaptation
│   │   ├── SKILL.md
│   │   ├── root-cause-tracing.md
│   │   ├── defense-in-depth.md
│   │   └── condition-based-waiting.md
│   ├── verification-before-completion/   # All agents — near-zero changes
│   │   └── SKILL.md
│   ├── code-review/                      # Reviewer — merged requesting + receiving
│   │   ├── SKILL.md
│   │   └── reviewer-prompt.md
│   └── pipeline-dispatcher/              # All agents — NEW, replaces `using-superpowers`
│       └── SKILL.md                       # Meta-skill: tells each agent which paperclipowers skills are available and when to invoke them, in the Paperclip heartbeat model (no TodoWrite, no visual companion)
│
└── docs/
    └── specs/
        └── 2026-04-13-paperclipowers-design.md   # This document
```

### 4.1 What was removed from superpowers

- **`using-git-worktrees`** — Paperclip manages execution workspaces natively
- **`finishing-a-development-branch`** — Paperclip issue lifecycle handles merge decisions; skill is replaced by "create PR, set issue `in_review`"
- **`subagent-driven-development`** — Replaced by `task-orchestration` (creates real Paperclip subtasks with `blockedByIssueIds` instead of in-session subagent dispatch)
- **`dispatching-parallel-agents`** — Absorbed into `task-orchestration` (parallel = independent subtasks with no blocker relationships)
- **`executing-plans`** — Not needed (Paperclip's subtask lifecycle is the execution model)
- **`writing-skills`** — Meta skill, not relevant to agent work
- **`using-superpowers`** — Replaced by `pipeline-dispatcher` (Paperclip-native skill routing)
- **Visual companion** (5 files in brainstorming) — Browser-dependent, cannot run in Docker

### 4.2 External skill

Import `ui-ux-pro-max` from [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) into Paperclip company library, assign only to Designer agent. MIT licensed.

## 5. Adaptation Rules

These apply uniformly across all adapted skills.

### 5.1 Interaction model

| CLI superpowers pattern | Paperclip replacement |
|-------------------------|----------------------|
| "Ask the user and wait for response" | Post comment, exit heartbeat; comment wake triggers next heartbeat |
| "Create TodoWrite todos" | Create Paperclip subtasks (for work spanning heartbeats) or maintain list in issue comment (for single-heartbeat work) |
| "Dispatch subagent via Task tool" | Create Paperclip subtask assigned to appropriate role agent |
| Visual companion / browser URLs | Removed — no browser in container |
| "In this message" verification | "In this heartbeat execution" |
| Git worktree creation | Use Paperclip's execution workspace |
| "Merge / PR / keep / discard" prompt | Create PR, set issue status to `in_review` |
| "Which execution approach?" prompt | Removed — Tech Lead always uses task-orchestration |

### 5.2 Approval gate pattern

When a skill requires human approval of a deliverable:

1. Agent writes deliverable to issue document (`PUT /api/issues/{id}/documents/{key}`)
2. Agent creates formal approval (`POST /api/approvals` with document reference)
3. Agent sets issue status to `in_review`
4. Agent exits heartbeat
5. PM reassigns the issue to the Quality Reviewer agent (`PATCH /api/issues/{id}` with `assigneeAgentId`) before exiting the heartbeat — this triggers the Quality Reviewer's wake
6. Reviewer reads document, comments findings
7. If reviewer approves, approval proceeds to board
8. Board approves or rejects
9. On approval → original agent woken to continue
10. On rejection → original agent woken with feedback in comments

### 5.3 Comment-based Q&A pattern

For multi-turn questions (primarily brainstorming):

- Batch 2-3 related questions per comment (not one-per-message as in CLI)
- Prefer multiple-choice over open-ended
- Post comment, exit heartbeat
- Next heartbeat triggered by board's reply comment
- After 2-3 Q&A rounds, transition to design presentation

### 5.4 Context between agents

Agents share context through:

- **Issue description** — always visible
- **Comment thread** — full history visible
- **Issue documents** — `spec`, `plan` keys by convention
- **Parent issue chain** — ancestor issues, goal, project
- **Git history** — what prior subtasks produced

Agents do NOT share memory. Each heartbeat loads context fresh from these sources.

## 6. Error Handling & Escalation

### 6.1 Review rejection loops

- **Spec rejected by Quality Reviewer 3x:** PM posts summary, reassigns issue back to board with `status: blocked`
- **Plan rejected 3x:** Tech Lead reassigns back to board
- **Implementation rejected 3x:** Tech Lead reviews (may indicate bad plan), may escalate to board

### 6.2 Engineer blockers

- Spec ambiguity → escalate to PM via reassignment + comment
- Plan error → escalate to Tech Lead via reassignment + comment
- Architectural unknown → escalate to board
- Status set to `blocked` in all cases; reason in the comment

### 6.3 QA failure

- Creates bug subtask, blocks parent from being marked `done`
- Bug subtask goes through its own mini-pipeline

### 6.4 Designer breaks tests

- Caught by Code Reviewer in combined review
- Subtask routed back to Designer, not Engineer (Designer owns visual changes)

### 6.5 Budget enforcement

- 80% monthly budget → conservative mode (critical tasks only)
- 100% → auto-pause
- First lever for cost reduction: batch brainstorming questions, reduce Q&A rounds

## 7. Per-Agent Configuration

### 7.1 Skill assignment

Skills are company-library resources assigned per-agent via `POST /api/agents/{id}/skills/sync`. A single `paperclipowers` company skill library contains all Paperclip-native skills; each agent's `desiredSkills` list narrows to what they need.

### 7.2 MCP isolation

The Designer agent is the only role with MCP server access. Configuration:

```json
{
  "adapterType": "claude_local",
  "adapterConfig": {
    "cwd": "/paperclip/instances/default/workspaces/designer-<companyId>",
    "envBindings": {
      "MAGIC_API_KEY": { "type": "secret_ref", "secretId": "21st-dev-magic" }
    }
  },
  "desiredSkills": [
    "paperclipowers/frontend-design",
    "paperclipowers/verification-before-completion",
    "ui-ux-pro-max/ui-ux-pro-max"
  ]
}
```

During Stage 6 setup, the operator manually places a `.mcp.json` file in the Designer agent's `cwd` (one-time configuration). Claude Code auto-loads project-scoped MCP from cwd, scoping Magic MCP and Figma MCP to this agent only:

```json
{
  "mcpServers": {
    "@21st-dev/magic": {
      "command": "npx",
      "args": ["-y", "@21st-dev/magic@latest", "API_KEY=\"${MAGIC_API_KEY}\""]
    },
    "figma": {
      "command": "npx",
      "args": ["-y", "@figma/mcp@latest"]
    }
  }
}
```

Other agents' cwds have no `.mcp.json`, so Claude Code loads no MCP servers for them.

### 7.3 Secrets

21st.dev Magic API key goes into Paperclip's secret store with ID `21st-dev-magic`. Referenced via `secret_ref` on the Designer agent only.

## 8. Implementation Stages

Development proceeds in 7 stages to validate the approach incrementally before committing to full rewrite.

- **Stage 0 — Fork & setup** (complete as of this document): repo structure, directory layout
- **Stage 1 — Validate import path**: adapt `verification-before-completion` (near-zero changes), import into an existing company, assign to an existing agent, confirm injection works
- **Stage 2 — Engineer-layer skills**: adapt `test-driven-development`, `systematic-debugging`, `code-review`
- **Stage 3 — Validate Engineer end-to-end**: single Full-Stack Engineer agent in test company, small issue, confirm TDD+verification run correctly within heartbeats
- **Stage 4 — Upstream skills**: adapt `brainstorming` (comment-based Q&A, approval gates), `writing-plans` (concrete schemas, dependency annotations), build `task-orchestration` (NEW), build `pipeline-dispatcher` (NEW)
- **Stage 5 — Full pipeline test**: all 6 roles in test company, small real feature end-to-end; measure heartbeats, approvals, failure points
- **Stage 6 — Designer role**: import ui-ux-pro-max, set up 21st.dev account, configure `.mcp.json` isolation, test Magic MCP + Figma MCP on UI polish task
- **Stage 7 — Production rollout**: promote to one existing company, monitor costs and quality, refine

Each stage produces its own implementation plan. Stage completion requires working validation before proceeding.

## 9. Success Criteria

The adapted pipeline is successful when:

- A feature request from the board flows through all 6 roles autonomously with only the 5 defined board touchpoints
- No Q&A heartbeats are wasted due to unclear questions (≤3 rounds in brainstorming on average)
- Implementations match specs and plans without drift (verified by Quality Reviewer)
- QA catches any divergence before PR creation
- Token cost per feature is measurable and within budget tolerances
- Designer polish improves UI quality without breaking backend functionality
- Escalations reach the board only for genuine blockers, not routine work

## 10. Non-Goals

Explicitly out of scope for this design:

- Authoring new skills within Paperclip agents (use writing-skills locally if needed)
- Parallel frontend/backend implementation within a single feature
- Automatic skill updates from upstream obra/superpowers (manual port-over)
- Cross-company skill sharing (each company imports paperclipowers independently)
- Custom adapter development (use built-in `claude_local`)
- UI for managing the pipeline beyond Paperclip's existing interfaces

## 11. References

Research informing this design:

- Cognition: "Don't Build Multi-Agents" (https://cognition.ai/blog/dont-build-multi-agents)
- Anthropic: "Building Effective Agents" (https://www.anthropic.com/research/building-effective-agents)
- Anthropic: "How we built our multi-agent research system" (https://www.anthropic.com/engineering/multi-agent-research-system)
- Addy Osmani: "Code Agent Orchestra" (https://addyosmani.com/blog/code-agent-orchestra/)
- Xano: "Backend-First AI Development" (https://www.xano.com/blog/backend-first-development-the-smart-way-to-build-with-ai/)
- obra/superpowers skills v5.0.7 (https://github.com/obra/superpowers)
- arXiv 2503.13657: Multi-agent LLM failure modes
- Paperclip documentation: docs/start/, docs/api/, docs/guides/board-operator/
