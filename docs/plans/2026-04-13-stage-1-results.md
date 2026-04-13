# Stage 1 Validation Results

**Date completed:** 2026-04-13
**Outcome:** SUCCESS — full fork → adapt → import → assign → run loop validated end-to-end.

## Captured identifiers

| Field | Value |
|-------|-------|
| Company (throwaway) | `Paperclipowers Test` — id `02de212f-0ec4-4440-ac2f-0eb58cb2b2ad`, prefix `PAP` |
| Imported skill id | `0701da9f-d823-4add-906e-f8b7355d32e0` |
| Imported skill key | `henriquerferrer/paperclipowers/verification-before-completion` |
| Pinned commit (GitHub sourceRef) | `a5d82e7b7679a8fd26932866f86271d6d98425b4` |
| Tracking branch | `paperclip-adaptation` |
| Hired agent | `stage1-tester` — id `cb7711f4-c785-491d-a21a-186b07d445e7`, adapterType `claude_local`, role `engineer` |
| Hire approval | `23805e52-bef1-4aaf-b973-71986558488d` (approved by board) |
| Trigger issue | `PAP-1` — id `34b955cd-d3f4-4d34-a49e-74d3dc4bee7e` |
| Heartbeat run | `08b0dfdd-afe0-4f45-bf09-ae5abd462460` — status `succeeded`, exitCode 0, duration ~40s |
| Model used at runtime | `claude-opus-4-6[1m]` (via subscription billing) |
| Heartbeat cost | $0.25 (13 fresh input tokens, 183k cached input, 1.5k output) |

## Evidence (each maps to an acceptance criterion)

### (1) Adapted skill present on GitHub, single-line delta from upstream

`diff` between upstream `skills/verification-before-completion/SKILL.md` and adapted `skills-paperclip/verification-before-completion/SKILL.md` on commit `d0a8466`:

```
22c22
< If you haven't run the verification command in this message, you cannot claim it passes.
---
> If you haven't run the verification command in this heartbeat execution, you cannot claim it passes.
```

Confirmed at: `https://github.com/henriquerferrer/paperclipowers/blob/paperclip-adaptation/skills-paperclip/verification-before-completion/SKILL.md`

### (2) Skill imported via `POST /api/companies/:id/skills/import` with pinned `sourceRef`

Import response (Task 5) returned 201 with:
- `sourceType`: `github`
- `sourceRef`: `a5d82e7b7679a8fd26932866f86271d6d98425b4` (full commit SHA pinned at import time)
- `metadata.repoSkillDir`: `skills-paperclip/verification-before-completion`
- `trustLevel`: `markdown_only`
- Stored `markdown` field contained the adapted `"in this heartbeat execution"` phrase

### (3) Agent's `desiredSkills` includes the skill after hire + board approval

`GET /api/agents/cb7711f4-c785-491d-a21a-186b07d445e7` after approval:

```
status: idle
adapterType: claude_local
desiredSkills: [
  'paperclipai/paperclip/paperclip',                            # Paperclip-bundled
  'paperclipai/paperclip/paperclip-create-agent',               # Paperclip-bundled
  'paperclipai/paperclip/paperclip-create-plugin',              # Paperclip-bundled
  'paperclipai/paperclip/para-memory-files',                    # Paperclip-bundled
  'henriquerferrer/paperclipowers/verification-before-completion' # our skill
]
```

### (4) Runtime materialization with adapted content intact

Path inside Docker container (confirmed via `ssh nas` + `docker exec paperclip ...`):

```
/paperclip/instances/default/skills/02de212f-0ec4-4440-ac2f-0eb58cb2b2ad/__runtime__/verification-before-completion--e427485e4d/SKILL.md
```

Content checks:
- `grep -c "in this heartbeat execution"` → **1** (adapted content present)
- `grep -c "in this message"` → **0** (upstream CLI-ism absent)
- Frontmatter (`name`, `description`) intact

### (5) Behavioral signal — agent applied the skill

Heartbeat run completed with this final message on PAP-1:

> "**PAP-1** is done. Ran `date`, got `Mon Apr 13 17:18:08 WEST 2026`, and marked the task complete with evidence. No other tasks in my inbox — heartbeat complete."

This is exactly the `verification-before-completion` discipline: ran the command, captured the output, cited it as evidence, then claimed done. Without the skill, the agent could have trivially said "task complete" without running `date` at all.

Issue PAP-1 final state: `status: done`, `completedAt: 2026-04-13T16:18:19.906Z`.

## Rollback (Task 8) — validated

- `DELETE /api/companies/:id/skills/:skillId` → **HTTP 200**, returns the deleted skill row.
- `GET /api/companies/:id/skills` → 4 remaining (bundled only); our skill gone.
- `GET /api/agents/:id` → `desiredSkills` auto-pruned from 5 → 4. Our skill key cleanly removed without leaving a zombie reference. This is the load-bearing assertion: deleting a skill also cleans up per-agent assignments, so uninstalling paperclipowers in a real company won't leave dangling state.
- Runtime directory `/paperclip/instances/default/skills/{companyId}/__runtime__/` emptied on next materialization.
- Agent paused via `POST /api/agents/:id/pause` (status now `paused`) so it won't wake on timers while the throwaway company lingers.
- Local env file `~/.paperclipowers-stage1.env` removed.

Company itself remains on the instance (`companyDeletionEnabled: false` for this build); it's inert — no skill assigned, agent paused, one `done` issue. Safe to ignore until Paperclip adds company deletion to the API.

## Anomalies / notes for Stage 2

- **Runtime skill materialization path is centralized, not per-workspace.** Paperclip puts runtime skills at `/paperclip/instances/default/skills/{companyId}/__runtime__/{slug}--{hash}/SKILL.md` and symlinks/mounts them in during heartbeat — NOT at `$HOME/.claude/skills/` inside the workspace cwd. The Stage 1 plan assumed the latter based on reading `claude-local/src/server/skills.ts`; the actual placement is driven by adapter-utils. Stage 2 plans should reference `/paperclip/instances/default/skills/` when verifying runtime injection.
- **Per-agent `desiredSkills` auto-includes 4 Paperclip-bundled skills** (`paperclip`, `paperclip-create-agent`, `paperclip-create-plugin`, `para-memory-files`). Stage 5+ needs to decide whether Engineer/Designer/etc. agents should inherit all four or be scoped tighter via adapter overrides.
- **Company creation required an `issuePrefix` hint**, and the server auto-normalized `PWT` → `PAP` (likely because `PWT` collided with reserved patterns or length limits). No blocker, just noting it.
- **Agent hire on this company required board approval** (`requireBoardApprovalForNewAgents: true` is on by default). Plans assuming one-shot hire need to handle the approval loop explicitly — payload contains `approval.id`, and `POST /api/approvals/:id/approve` must be called before the agent transitions out of `pending_approval`.
- **Company deletion is disabled on this instance** (`companyDeletionEnabled: false` from `/api/health`). Task 8 cleanup deletes the skill and relies on the throwaway company sitting idle; formal archive is not available via the HTTP API on this build. Stage 2+ rollback plans should not assume DELETE `/api/companies/:id` works.
- **Auth in production-ish mode is session-cookie based, not bearer-token.** `better-auth.session_token` cookie + matching `Origin:` header (enforced by `board-mutation-guard` middleware) is required for mutations. For scripted automation in later stages, the `paperclipai auth login` flow (board API key via CLI challenge) is the cleaner path.
- **Heartbeat cost on a trivial task was $0.25.** Almost all tokens were cached (183k cached vs 13 fresh), driven by the agent's system prompt + bundled skills + our one new skill. Cost scales with prompt size, not task complexity for tiny tasks — Stage 5 pipeline costs will be dominated by heartbeat count, not per-task work.
