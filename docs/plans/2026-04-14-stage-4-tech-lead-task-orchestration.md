# Stage 4 — Tech Lead + task-orchestration Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt `subagent-driven-development` (with concepts absorbed from `dispatching-parallel-agents`) into a new Paperclip-native `task-orchestration` skill under `skills-paperclip/task-orchestration/`, stand up a net-new `stage4-tech-lead` agent in the existing `Paperclipowers Test` company, and behaviourally validate that the skill produces a correct subtask chain with **unconditional progressive assignment** and that it handles the Stage 3 paused-target anomaly before Stage 5 brings the rest of the pipeline online.

**Architecture:** `task-orchestration` is a single-skill adaptation — one `SKILL.md` + one `UPSTREAM.md` + three prompt templates ported from upstream (`implementer-prompt.md`, `spec-reviewer-prompt.md`, `code-quality-reviewer-prompt.md` — all rewritten as Paperclip subtask-description templates rather than Task-tool dispatch scripts). The upstream `Task()` dispatch is replaced by `POST /api/companies/:id/issues` (subtask creation) + `PATCH /api/issues/:id { assigneeAgentId }` (progressive assignment). `TodoWrite` is replaced by the Paperclip subtask graph itself. The two-stage review-per-task pattern becomes a "Reviewer wakes on subtask `done`" trigger that Stage 5 will actually wire up — Stage 4 just encodes the hand-off point so the skill is ready for Stage 5.

The skill has three load-bearing rules the plan tests for:

1. **Every subtask chain emits progressive assignment unconditionally.** The first subtask in a chain is assigned at creation time; every subsequent subtask is created with `assigneeAgentId: null` and `blockedByIssueIds: [<predecessor>]`. The Tech Lead re-wakes when the predecessor terminates and only then sets the assignee. Spec §5.4 makes this mandatory until `sessionPolicy` lands post-Stage-5 (see Stage 3 results §Follow-ups unblocked by Stage 3 #4).
2. **Before every `PATCH … assigneeAgentId`, verify target agent `status !== "paused"`.** Stage 3 Anomaly 1 showed that assigning an issue to a paused agent silently drops the `issue_assigned` wake, and even after resume the wake does not re-queue unless the assignment is re-applied. The skill requires a `GET /api/agents/:id` probe before every assignee set; if the target is paused, the Tech Lead escalates rather than firing a dead PATCH.
3. **The Tech Lead wakes per subtask completion via the subtask's assignee commenting with an `@<tech-lead-name>` mention.** Paperclip's built-in `issue_children_completed` wake only fires when ALL children are terminal (`server/src/services/issues.ts:1347-1376` — `getWakeableParentAfterChildCompletion` requires `children.every(...)`), so it's unusable for per-subtask PATCH triggers. Instead, every subtask description this skill produces includes a "Notification protocol" section instructing the assignee to post a single `@<tech-lead>` comment on the subtask when it reaches `done`. That fires `issue_comment_mentioned` (`routes/issues.ts:2333`, contextSnapshot.wakeReason = `issue_comment_mentioned`) which wakes the Tech Lead with a resumable session (not in the reset list at `services/heartbeat.ts:715-730` — cheap follow-up wakes). The discipline lives in the *subtask description* (Tech Lead's output), not in the Engineer's frozen skills.

Behavioural validation reuses Stage 3's throwaway company, the stage1-tester Engineer agent (currently paused, with the four Engineer skills pinned), and the existing workspace (`/paperclip/instances/default/workspaces/cb7711f4…`). Stage 4 adds ONE net-new agent (`stage4-tech-lead`) and a fresh parent issue with a pre-written plan document (hand-authored by the Stage 4 executor — `writing-plans` is Stage 5's adaptation, not Stage 4's). The Tech Lead runs the full orchestration loop end-to-end for a three-subtask chain, and the plan includes a deliberate paused-target trap between subtasks 2 and 3 to exercise rule (2) above.

**Tech Stack:**
- `git` + GitHub (fork: `henriquerferrer/paperclipowers`, branch `paperclip-adaptation` — two commits ahead of last push: Stage 3 spec amendment `4ea4862` and results doc `9514dbc`)
- Paperclip HTTP API at `http://192.168.0.104:3100` (LAN-only; `authenticated` mode requires session cookie + matching `Origin:` header)
- `curl` + `jq` for API calls
- **JSON payloads:** `Write` tool to place file on disk with `\n` escape sequences inside string values, then `curl --data-binary @file` — NOT zsh `echo` + `-d @file` (Stage 3 Anomaly 2 confirmed this is what mangles newlines; Stage 4 plan writer verified the `\n`-escape form round-trips correctly)
- `ssh nas` for Docker-container filesystem inspection: `/usr/local/bin/docker exec paperclip sh -c '...'`
- Local clones: `/Users/henrique/custom-skills/paperclipowers/` (fork), `/Users/henrique/custom-skills/superpowers/` (upstream reference)

**Scope boundaries (what this plan does NOT do):**
- Does NOT modify any of the four frozen Engineer skills (`verification-before-completion`, `test-driven-development`, `systematic-debugging`, `code-review`) — Stage 2 froze them; Stage 4 only adds a new peer skill.
- Does NOT touch any Paperclip server code. No changes to wake logic (`routes/issues.ts`), session reset (`services/heartbeat.ts`), `listWakeableBlockedDependents`, or `getWakeableParentAfterChildCompletion`. Stage 4's mechanism selection is constrained to what today's server already fires.
- Does NOT adapt or build the other Stage 5 skills — `brainstorming` (PM), `writing-plans` (Tech Lead's second skill), `pipeline-dispatcher` (all agents). These remain in the spec §8 Stage 4 scope conceptually, but the user has narrowed the implementation Stage 4 to just `task-orchestration` so the progressive-assignment rule can be exercised in isolation before the rest of the pipeline lands. The plan for the parent issue in Task 10 is hand-authored by the Stage 4 executor — the skill does not yet consume a machine-generated plan document.
- Does NOT build or hire the PM, Quality Reviewer, Designer, or final Code Reviewer agents (Stage 5/6).
- Does NOT introduce the `sessionPolicy` per-agent flag (post-Stage-5 follow-up).
- Does NOT promote any skill to a real company (Stage 7).
- Does NOT remove Stage 2/3 test issues (`PAP-2` through `PAP-11`) or delete the Stage 3 task-counter workspace residue — they stay as evidence. Stage 4's issues start at `PAP-12` (or higher if there has been any test drift since the Stage 3 writer's final poll — the counter is monotonic per Stage 3 Anomaly 6).

**Reference documents (read before executing this plan):**
- Design spec (§5.4 amended in Stage 3): `docs/specs/2026-04-13-paperclipowers-design.md`
- Stage 3 plan: `docs/plans/2026-04-13-stage-3-engineer-end-to-end.md`
- Stage 3 results (captured IDs + six anomalies that constrain this plan): `docs/plans/2026-04-13-stage-3-results.md` — especially Anomaly 1 (paused agent + issue_assigned), Anomaly 2 (zsh echo + curl -d), Anomaly 3 (stale jq paths)
- Stage 2 results (template for Stage 4 results doc): `docs/plans/2026-04-13-stage-2-results.md`
- Upstream sources (read during Task 2, adapted in Task 3):
  - `skills/subagent-driven-development/SKILL.md`
  - `skills/subagent-driven-development/implementer-prompt.md`
  - `skills/subagent-driven-development/spec-reviewer-prompt.md`
  - `skills/subagent-driven-development/code-quality-reviewer-prompt.md`
  - `skills/dispatching-parallel-agents/SKILL.md` (concepts absorbed, not ported wholesale)
- Paperclip server mechanics verified by the Stage 4 plan writer (do not re-read to "confirm" — these are frozen for this plan; if they change in master, amend the plan):
  - `server/src/routes/issues.ts:1697-1723` — `issue_assigned` wake on assignee PATCH
  - `server/src/routes/issues.ts:1833-1859` — `issue_children_completed` wake gate
  - `server/src/services/issues.ts:1347-1376` — `getWakeableParentAfterChildCompletion` — **requires ALL children terminal**; unusable as per-subtask wake
  - `server/src/routes/issues.ts:2298-2317` — `issue_commented` wake (assignee)
  - `server/src/routes/issues.ts:2320-2346` — `issue_comment_mentioned` wake (arbitrary mentioned agent) ← the Tech Lead wake mechanism
  - `server/src/services/heartbeat.ts:715-730` — `shouldResetTaskSessionForWake`; `issue_comment_mentioned` is NOT in the reset list, so the Tech Lead resumes session on mention wakes (cheap)
  - `server/src/routes/agents.ts:1962-2004` — `/pause` and `/resume` endpoints
  - `server/src/routes/agents.ts:2089-2137` — `/wakeup` endpoint with `forceFreshSession`

**Live API path freeze (sampled 2026-04-14 during plan write — Stage 3 Anomaly 3 fix):**

| Purpose | Endpoint + path |
|---|---|
| Company basics | `GET /api/companies/:id` → `.id`, `.name`, `.issuePrefix`, `.issueCounter`, `.requireBoardApprovalForNewAgents`, `.features.companyDeletionEnabled` |
| Company skills (imported library) | `GET /api/companies/:id/skills` → array of `{ key, slug, sourceRef, sourceType, sourceLocator, fileInventory, attachedAgentCount, editable, … }` (**`sourceRef`, not `source.commit`**) |
| Agent basics | `GET /api/agents/:id` → `.id`, `.name`, `.role`, `.status`, `.adapterType`, `.adapterConfig` (includes `paperclipSkillSync.desiredSkills`), `.pauseReason`, `.pausedAt`, `.urlKey`. **`desiredSkills` is NOT at top level here.** |
| Agent skills view | `GET /api/agents/:id/skills` → `{ adapterType, supported, mode, desiredSkills: [keys], entries: [{ key, runtimeName, desired, managed, state, sourcePath, … }] }` |
| Agent role enum | Allowed: `ceo`, `cto`, `cmo`, `cfo`, `engineer`, `designer`, `pm`, `qa`, `devops`, `researcher`, `general`. **`tech_lead` is NOT valid** — Stage 4 uses `role: "engineer"` for the Tech Lead agent (same as stage1-tester — role is metadata only, does not gate behaviour). |
| Create agent | `POST /api/companies/:id/agents` with `{ name, role, adapterType, adapterConfig: { paperclipSkillSync: { desiredSkills: [...] } } }`. When board is the actor (cookie auth), agents created via this endpoint come back immediately `status: "idle"` with no hire-approval gate — `requireBoardApprovalForNewAgents: true` only gates agent-created-by-agent hires. |
| Delete agent | `DELETE /api/agents/:id` → returns `{ ok: true }` |
| Pause / resume | `POST /api/agents/:id/pause`, `POST /api/agents/:id/resume` → returns `{ id, status }` |
| Wakeup | `POST /api/agents/:id/wakeup` with optional `{ forceFreshSession: true, … }` → 403 if agent is `paused` (`{ "error": "Agent is not invokable in its current state", "details": { "status": "paused" } }`) |
| Create issue | `POST /api/companies/:id/issues` with `{ title, description, parentId?, assigneeAgentId? (null allowed), blockedByIssueIds?: [uuids], status? }` — returns full issue incl. `identifier` (e.g. `PAP-12`) |
| Issue detail | `GET /api/issues/:id` → top-level `.blockedBy: [{ id, identifier, title, status, priority, assigneeAgentId, assigneeUserId }]`, top-level `.blocks: [...]`, plus `.planDocument`, `.documentSummaries`, `.parentId`, `.status`, `.assigneeAgentId`. **`blockedBy` is NOT under `.relations`.** |
| List children of parent | `GET /api/companies/:id/issues?parentId=:uuid&limit=N` → `[{ identifier, status, … }]` in reverse-creation order |
| PATCH issue | `PATCH /api/issues/:id` with `{ assigneeAgentId, status, priority, … }` — setting `assigneeAgentId` fires `issue_assigned` wake when the value actually changes (from null or from another agent) |
| Heartbeat runs (list) | `GET /api/companies/:id/heartbeat-runs?agentId=:uuid&limit=N` → array of runs |
| Heartbeat run fields | `.id`, `.status`, `.startedAt`, `.finishedAt` (**not `completedAt`**), `.sessionIdBefore`, `.sessionIdAfter` (**not `adapterResult.params.sessionId`**), `.contextSnapshot.{wakeReason,source,issueId,taskId,paperclipWorkspace}`, `.usageJson.{cachedInputTokens,inputTokens,outputTokens,freshSession,sessionReused,sessionRotated,model,costUsd,provider}` (**not `.usage.cached_input` etc.**), `.resultJson.{result,total_cost_usd}` |
| Comments | `GET /api/issues/:id/comments?limit=N` and `POST /api/issues/:id/comments` with `{ body }` — `@agent-name` mentions resolved by `findMentionedAgents(companyId, body)` and wake the mentioned agents with `reason: "issue_comment_mentioned"` |
| Import skill library | `POST /api/companies/:id/skills/import` with the Paperclip URL-import shape (see Stage 2 plan Task 7 for the exact payload — reused verbatim in Stage 4 Task 7). **Use the parent-directory URL `…/tree/paperclip-adaptation/skills-paperclip` per Stage 2 Anomaly 2**, NOT the per-skill subdirectory. |

If the executor finds any of these paths wrong at runtime (e.g. Paperclip was upgraded), stop and fix the plan before proceeding — do not paper over drift by guessing the new shape.

**Captured identifiers reused from Stage 2/3:**
- `COMPANY_ID="02de212f-0ec4-4440-ac2f-0eb58cb2b2ad"` — `Paperclipowers Test` company, `issuePrefix: "PAP"`
- `AGENT_ID="cb7711f4-c785-491d-a21a-186b07d445e7"` — `stage1-tester`, role `engineer`, currently paused (Stage 3 Task 10 left it that way). Four Engineer skills already in its `desiredSkills`.
- `PAPERCLIP_API_URL="http://192.168.0.104:3100"`
- `WORKSPACE_CWD="/paperclip/instances/default/workspaces/cb7711f4-c785-491d-a21a-186b07d445e7"` — shared workspace, has Stage 3's task-counter git history
- Company skills already imported and pinned: `verification-before-completion`, `test-driven-development`, `systematic-debugging`, `code-review` — all at `sourceRef: "78598d564ba9f569c54f72df7b5deb58f7a15dd2"`

**New identifiers this plan creates (captured as env vars during execution):**
- `TECH_LEAD_AGENT_ID` — `stage4-tech-lead` agent UUID (Task 8)
- `TASK_ORCH_SKILL_KEY` — `henriquerferrer/paperclipowers/task-orchestration` (Task 7)
- `STAGE4_PARENT_ISSUE` — parent issue holding the hand-authored plan document (Task 10)
- `STAGE4_SUB_1`, `STAGE4_SUB_2`, `STAGE4_SUB_3` — the three subtasks the Tech Lead creates (Task 11)
- `STAGE4_RUN_TECH_LEAD_1`, `STAGE4_RUN_ENG_1`, `STAGE4_RUN_TECH_LEAD_2`, `STAGE4_RUN_ENG_2`, `STAGE4_RUN_TECH_LEAD_3_PAUSED`, `STAGE4_RUN_TECH_LEAD_4_REVIVED`, `STAGE4_RUN_ENG_3` — heartbeat run IDs captured per step, numbered by appearance

**Environment variables set throughout this plan (re-export in each terminal):**
- `PAPERCLIP_API_URL`, `PAPERCLIP_SESSION_COOKIE`, `COMPANY_ID`, `AGENT_ID`, `WORKSPACE_CWD` — sourced from `~/.paperclipowers-stage3.env` (Task 1 copies it to `~/.paperclipowers-stage4.env`)
- New Stage 4 vars above appended to the Stage 4 env file as each is captured

**File structure (all paths relative to `/Users/henrique/custom-skills/paperclipowers/`):**

```
skills-paperclip/
└── task-orchestration/                        (NEW — created in Tasks 3-5)
    ├── SKILL.md                               (~350 lines; ports subagent-driven-development + absorbs dispatching-parallel-agents concepts)
    ├── implementer-subtask-template.md        (ported from upstream implementer-prompt.md; rewritten as a subtask-description template)
    ├── spec-review-subtask-template.md        (ported from spec-reviewer-prompt.md)
    ├── code-quality-review-subtask-template.md  (ported from code-quality-reviewer-prompt.md)
    └── UPSTREAM.md                            (provenance metadata; merger-type adaptation)

docs/plans/
├── 2026-04-14-stage-4-tech-lead-task-orchestration.md  (this file)
└── 2026-04-14-stage-4-results.md              (NEW; written in Task 13)
```

No change to `scripts/check-upstream-drift.sh` — it auto-discovers any `skills-paperclip/*/UPSTREAM.md` (see script lines 70-78), so adding `task-orchestration/UPSTREAM.md` with the correct frontmatter is sufficient.

**Local harness env file to create in Task 1:** `~/.paperclipowers-stage4.env` (local only, not committed; mode 600).

---

## Task 1: Re-acquire auth, verify Stage 3 end-state is intact

**Files:** Read-only: `docs/plans/2026-04-13-stage-3-results.md`. Creates: `~/.paperclipowers-stage4.env`.

**Context:** Stage 3 left the auth cookie in `~/.paperclipowers-stage3.env`, the test company at `02de212f…` unchanged, `stage1-tester` paused with the four Engineer skills pinned to `78598d5`, and eleven issues (`PAP-1` through `PAP-11`) all terminal. Confirm this state is still what we think it is before starting Stage 4; re-auth if the cookie has gone stale (cookies on this Paperclip instance have lasted several days in prior stages but are not durable forever). If state has drifted from Stage 3's rollback snapshot, stop and reconcile before proceeding.

- [ ] **Step 1: Verify NAS reachability and container health**

```bash
curl -sfS http://192.168.0.104:3100/api/health | jq .
```

Expected: `{"status":"ok","version":"0.3.1","deploymentMode":"authenticated","deploymentExposure":"private","authReady":true,"bootstrapStatus":"ready","features":{"companyDeletionEnabled":false}}` (version string may change on a Paperclip upgrade — note if it does). If the request fails, verify LAN and containers:

```bash
ssh nas "/usr/local/bin/docker ps --format '{{.Names}} {{.Status}}' | grep paperclip"
```

Expected: two rows, both `Up ...` — `paperclip` (app) and `paperclip-db` (postgres).

- [ ] **Step 2: Source Stage 3 env file and test read auth**

```bash
source ~/.paperclipowers-stage3.env 2>/dev/null || true
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID" | jq '{id, name, issuePrefix, issueCounter}'
```

Expected:
```json
{"id":"02de212f-0ec4-4440-ac2f-0eb58cb2b2ad","name":"Paperclipowers Test","issuePrefix":"PAP","issueCounter":11}
```

`issueCounter` should be 11 (Stage 3 ended at PAP-11). If it's higher, other work has happened in the company since Stage 3 — note the drift in Stage 4 results but proceed; the counter is only used to predict issue identifiers and a drift doesn't break anything.

If 401 or cookie empty: refresh the cookie.
```
Open a browser, navigate to http://192.168.0.104:3100, log in, then in DevTools:
  Application → Cookies → http://192.168.0.104:3100 → copy the value of better-auth.session_token.
export PAPERCLIP_SESSION_COOKIE="better-auth.session_token=<paste-value>"
```
Re-run the check.

- [ ] **Step 3: Verify `stage1-tester` agent is still paused with four Engineer skills**

Use the verified paths from the live-API freeze table in the header.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq '{id, name, status, role, adapterType, pausedAt, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills}'
```

Expected:
```json
{
  "id": "cb7711f4-c785-491d-a21a-186b07d445e7",
  "name": "stage1-tester",
  "status": "paused",
  "role": "engineer",
  "adapterType": "claude_local",
  "pausedAt": "2026-04-13T22:33:34.947Z",
  "desiredSkills": [
    "paperclipai/paperclip/paperclip",
    "paperclipai/paperclip/paperclip-create-agent",
    "paperclipai/paperclip/paperclip-create-plugin",
    "paperclipai/paperclip/para-memory-files",
    "henriquerferrer/paperclipowers/verification-before-completion",
    "henriquerferrer/paperclipowers/test-driven-development",
    "henriquerferrer/paperclipowers/systematic-debugging",
    "henriquerferrer/paperclipowers/code-review"
  ]
}
```

If `status` is not `paused`, that is acceptable at this read — Task 11 manages pausing/resuming. But if `desiredSkills` has drifted (any of the four paperclipowers keys missing, or unknown keys appended), STOP and reconcile — Stage 4 needs the Engineer's skill set stable for the subtask-3 round.

- [ ] **Step 4: Verify the four paperclipowers skills are still in the company library pinned at `78598d5`**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.key | test("henriquerferrer/paperclipowers/")) | {key, slug, sourceRef}] | sort_by(.key)'
```

Expected: exactly four entries (no `task-orchestration` yet), all with `sourceRef: "78598d564ba9f569c54f72df7b5deb58f7a15dd2"`. If a fifth entry exists already (e.g. `task-orchestration` from a prior aborted Stage 4 attempt), delete it via `DELETE /api/companies/:id/skills/:skill-id` before proceeding — Stage 4 needs to import it cleanly.

- [ ] **Step 5: Sanity-check no in-progress heartbeat runs on `stage1-tester`**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=5" \
  | jq '[.[] | {id, status, startedAt, finishedAt, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId}]'
```

Expected: five most-recent runs, all `status` in `{succeeded, failed, cancelled}` (terminal). No `running` or `queued` entries. The most recent should be Stage 3's Run 3 (`3b7e2eee-ae1e-47c4-8b3b-6d354f8c7c9e` per Stage 3 results) or its cancellation when the agent was paused.

- [ ] **Step 6: Persist Stage 4 env file**

```bash
cp ~/.paperclipowers-stage3.env ~/.paperclipowers-stage4.env
chmod 600 ~/.paperclipowers-stage4.env
echo "# Appended as Stage 4 captures new identifiers" >> ~/.paperclipowers-stage4.env
ls -la ~/.paperclipowers-stage4.env
```

Expected: file exists, mode 600 (`-rw-------`), contains at minimum `PAPERCLIP_API_URL`, `PAPERCLIP_SESSION_COOKIE`, `COMPANY_ID`, `AGENT_ID`, `WORKSPACE_CWD`. Future terminals should `source ~/.paperclipowers-stage4.env`, not stage3.

- [ ] **Step 7: Verify the local git worktree is on `paperclip-adaptation` and matches origin**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git status --porcelain=v1 -b | head -5
git log --oneline origin/paperclip-adaptation..paperclip-adaptation
git log --oneline paperclip-adaptation..origin/paperclip-adaptation
```

Expected:
- `## paperclip-adaptation...origin/paperclip-adaptation [ahead 2]` (the two un-pushed commits are `4ea4862` spec amendment and `9514dbc` Stage 3 results per the user's briefing — confirm these two SHAs match)
- The "ahead" listing shows the two SHAs; "behind" listing is empty
- No uncommitted changes (empty porcelain output beyond the `##` branch line)

If "behind" is non-empty, `git pull --ff-only` first. If uncommitted changes exist, stash or commit them — Stage 4 needs a clean starting tree.

Optionally push the two commits now so origin is in sync before Stage 4 adds more commits:

```bash
git push origin paperclip-adaptation
```

This is optional; Task 6 will push again once Stage 4's new commits exist. If push fails (credential/auth), resolve before Task 6.

---

## Task 2: Research upstream, draft the adaptation map

**Files:** Read-only. Creates one working-notes file (not committed) for your own reference during Task 3.

**Context:** `task-orchestration` is a net-new skill per design spec §4.1, but it is not greenfield — it adapts `subagent-driven-development` (the primary source) and absorbs concepts from `dispatching-parallel-agents`. Stage 2's `code-review` adaptation (see `skills-paperclip/code-review/UPSTREAM.md`) is the closest structural precedent: a "greenfield derivative" where upstream text informs structure but the output is not a mechanical patch. Task 2 produces the mapping table before Task 3 writes the skill.

- [ ] **Step 1: Read upstream sources in full**

```bash
UPSTREAM=/Users/henrique/custom-skills/superpowers
wc -l "$UPSTREAM"/skills/subagent-driven-development/*.md
wc -l "$UPSTREAM"/skills/dispatching-parallel-agents/SKILL.md
```

Expected: four files under `subagent-driven-development/` (SKILL.md ~280 lines, three prompt templates), one SKILL.md under `dispatching-parallel-agents/` (~180 lines).

Read each file end-to-end. Do NOT skim. Note the exact section headings — Task 3 preserves most of them (adaptation is structural, not rewrite).

- [ ] **Step 2: Capture the upstream base commit SHA for UPSTREAM.md**

```bash
cd /Users/henrique/custom-skills/superpowers
UPSTREAM_SHA=$(git rev-parse HEAD)
echo "UPSTREAM_SHA=$UPSTREAM_SHA"
```

Record this value — it goes into `skills-paperclip/task-orchestration/UPSTREAM.md` in Task 4 under `**Upstream base commit:**`.

If the superpowers clone is not at the same commit Stage 2 used (`6f204930537670d9173aed20e96b699799ee6c31` per `skills-paperclip/code-review/UPSTREAM.md`), decide:
- Same commit → fine, use that SHA
- Newer commit → preferred; use the newer SHA. Future drift checks will compare correctly.

- [ ] **Step 3: Write the adaptation map to a scratch file**

Create `~/.paperclipowers-stage4-adaptation-map.md` (local only, not committed) with the exact mapping from upstream concepts → Paperclip equivalents. Use this table (copy verbatim and fill in):

```markdown
# task-orchestration adaptation map (Stage 4 scratch)

Upstream base: <SHA from Step 2>

## Concept mapping

| Upstream | Paperclip equivalent | Where encoded in SKILL.md |
|---|---|---|
| `Task(prompt)` dispatch | `POST /api/companies/:id/issues` creates a subtask; `PATCH /api/issues/:id { assigneeAgentId }` fires the wake | § The Process + § Progressive Assignment |
| Subagent's "full task text pasted into prompt" | Subtask `description` field (rendered as the body of the subtask issue) | § Subtask Description Template |
| `TodoWrite` task list | The subtask graph itself (parent with N child issues, chained by `blockedByIssueIds`) | § When to Invoke + § Creating the Subtask Graph |
| "Fresh subagent per task" | Progressive assignment (null assignee at creation → PATCH at predecessor-terminal → `issue_assigned` wake → `shouldResetTaskSessionForWake` returns true → fresh Claude session) | § Progressive Assignment (RULE 1) |
| "Two-stage review per task" | Subtask status transitions to `done` → Reviewer agent wakes (Stage 5 wires this up); Stage 4 encodes the hand-off point only | § Per-Subtask Review Hand-off |
| "Dispatch final code reviewer for entire implementation" | Parent issue transitions to `in_review` when all subtasks done → Reviewer agent wakes on `issue_status_changed` | § End-of-Feature Review |
| "Subagent reports DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT" | Subtask status transitions + `@tech-lead` mention comment body; statuses map: DONE → `done` + mention, BLOCKED → `blocked` + mention, NEEDS_CONTEXT → comment with question + `@tech-lead` mention and set to `blocked` | § Notification Protocol (in subtask description) |
| "Dispatching parallel agents" — independent failures across files | Multiple subtasks with NO `blockedByIssueIds` between them (parallelism by absence of dependency), each assigned to a different agent | § Parallelism via Independence (absorbed from dispatching-parallel-agents) |
| "Read plan, extract tasks, create TodoWrite" first step | Tech Lead's first heartbeat: read `GET /api/issues/:parent/documents/plan` (or parent issue description if plan document is absent — Stage 4 uses the description), decompose, create subtasks, exit heartbeat | § The Process + § First Wake |
| "Answer subagent questions before letting them proceed" | Engineer posts question as `@tech-lead` mention → Tech Lead wakes (`issue_comment_mentioned`) → posts clarification comment on subtask → Engineer re-wakes via `issue_commented` | § Q&A Protocol |
| "Review loops — reviewer found issues → implementer fixes → re-review" | Not implemented in Stage 4 (Reviewer is Stage 5). SKILL.md notes this as a Stage 5 follow-up. |
| "Never dispatch multiple implementation subagents in parallel (conflicts)" | Shared workspace = serial; distinct workspaces (Stage 6 Designer with its own cwd) = parallel OK. Stage 4's validation is all serial because only the Engineer's workspace exists. | § Red Flags |

## New concepts NOT in upstream (Paperclip-native)

1. **Progressive assignment** — entire section. No upstream analogue. Cite spec §5.4 amendment.
2. **Paused-target check** — pre-PATCH probe. No upstream analogue. Cite Stage 3 Anomaly 1.
3. **Notification protocol via @mention** — Tech Lead wake mechanism because `issue_children_completed` only fires on all-done. Cite `server/src/services/issues.ts:1347-1376`.
4. **Workspace sharing implications** — subtasks in a shared `cwd` must be serial (blockedByIssueIds); parallel requires distinct workspaces. Cite Stage 3 Anomaly 4 (cross-file test contamination).
5. **Role-based assignment heuristics** — map slice type (backend-only, frontend-only, full-stack, designer-polish) to the target agent's role. For Stage 4: only engineer-role agents exist, so heuristic is trivial; Stage 5 expands.

## Drop-from-upstream (do not port)

- `finishing-a-development-branch` final step — replaced by "parent → in_review" (spec §5.1)
- Git worktree creation advice — Paperclip execution workspaces replace worktrees (spec §4.1)
- "Controller dispatches Task()" procedural prose — Tech Lead is the controller; subtasks are Paperclip issues; no Task tool exists in heartbeat mode
- Code examples using `Task(...)` inline syntax — replaced by `curl` recipes
- "Which execution approach?" prompt — Tech Lead always uses task-orchestration (spec §5.1)
```

- [ ] **Step 4: Verify map covers everything in upstream SKILL.md**

```bash
grep -E "^#{1,3} " /Users/henrique/custom-skills/superpowers/skills/subagent-driven-development/SKILL.md
```

Expected: a list of headings (`When to Use`, `The Process`, `Model Selection`, `Handling Implementer Status`, `Prompt Templates`, `Example Workflow`, `Advantages`, `Red Flags`, `Integration`, …). For each, confirm it appears in the map table (either ported or explicitly dropped). If a heading isn't mapped, add a row.

Do the same for `dispatching-parallel-agents/SKILL.md`. Most of it maps to "§ Parallelism via Independence" — that's fine as a single merge point.

The scratch file is not committed. It's a working aid for Task 3.

---

## Task 3: Write `skills-paperclip/task-orchestration/SKILL.md`

**Files:** Creates `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/task-orchestration/SKILL.md`. Reads the scratch map from Task 2 and upstream sources.

**Context:** This is the load-bearing file. It must encode the three rules from the Architecture paragraph (progressive assignment unconditional; pre-PATCH paused check; @mention wake protocol) and must not contain any CLI-isms ("your human partner", "in this message", "ask the user", bare "TodoWrite" references, bare `Task()` examples). Use Stage 2's `code-review/SKILL.md` as the stylistic reference — Paperclip-native throughout, with explicit API-call recipes rather than CLI prose.

The skill is written in the second person (addressing the Tech Lead agent). All curl recipes it emits must follow the Write-to-file + `--data-binary @file` idiom (Stage 3 Anomaly 2).

- [ ] **Step 1: Create the skill directory**

```bash
cd /Users/henrique/custom-skills/paperclipowers
mkdir -p skills-paperclip/task-orchestration
ls -la skills-paperclip/task-orchestration/
```

Expected: empty directory created.

- [ ] **Step 2: Write SKILL.md with the full structure**

Use the `Write` tool (not `cat <<EOF` via Bash — avoids zsh escape-sequence issues even though this is markdown not JSON). The file must contain the following sections in order. Each section has required content; bracketed `[…]` items are placeholders YOU FILL IN during writing, not left as TODOs.

```markdown
---
name: task-orchestration
description: Use when decomposing an approved plan into Paperclip subtasks. Creates the subtask graph with unconditional progressive assignment, wakes per subtask completion via @mention, and gates every assignee PATCH on target-agent status.
---

# Task Orchestration

## Overview

You are the Tech Lead. Your plan is approved. Your job now is to decompose it into Paperclip subtasks, assign them to the right role-agents with the right dependency structure, and drive the chain to completion across multiple heartbeats.

You hand off work by creating Paperclip issues and setting their `assigneeAgentId` via the HTTP API. You do not run `Task(...)` — that is not available in heartbeat mode. Each subtask is a real Paperclip issue with its own lifecycle.

**Three rules are load-bearing. Violating any of them breaks the pipeline:**

1. **Every subtask chain emits progressive assignment.** Only the first subtask is assigned at creation. Every subsequent subtask is created with `assigneeAgentId: null` and `blockedByIssueIds: [<predecessor-id>]`. You set the assignee via `PATCH` only after the predecessor reaches terminal status. This is how paperclipowers enforces fresh Claude sessions per subtask — see spec §5.4.

2. **Before any `PATCH … assigneeAgentId`, verify the target agent is not paused.** If the target is paused, the `issue_assigned` wake is silently dropped and the subtask never runs (see Stage 3 Anomaly 1). You must escalate, not fire a dead PATCH.

3. **Every subtask description you write includes a Notification Protocol instructing the assignee to post an `@<your-name>` comment when the subtask reaches terminal status.** Paperclip's `issue_children_completed` wake only fires when ALL children are terminal — it is unusable as a per-subtask trigger. `@<your-name>` mention comments fire `issue_comment_mentioned`, which wakes you per completion with a resumable session.

[…continue with full content; the section outline follows…]

## When to Invoke

[Flow from plan-approval → first heartbeat → subtask-graph creation → per-completion wakes → parent → in_review]

## The Process

[Step-by-step, adapted from upstream "The Process" section. Ported from subagent-driven-development/SKILL.md lines 42-85 but rewritten for Paperclip semantics.]

## First Wake — Reading the Plan and Decomposing

[What the Tech Lead does on its first wake (wakeReason = issue_assigned, parent issue). Read the plan from issue description OR from a future plan document; decompose into subtasks; create the graph; exit heartbeat.]

## Creating the Subtask Graph

### Required fields per subtask

```
POST /api/companies/:company-id/issues
Body (JSON):
  title:           concise capability name
  description:     the full subtask brief (see § Subtask Description Template below)
  parentId:        <parent-issue-id>
  assigneeAgentId: <target-agent-id for subtask 1> | null for all others
  blockedByIssueIds: []                              for subtask 1
                     [<predecessor-subtask-id>]      for all others
  status:          "todo"
```

### curl recipe

Do NOT write JSON inline via zsh echo + `-d`. Always:

1. Write the JSON to a file using the Write tool (or a here-doc if you are in bash not zsh). String values must use `\n` escape sequences for newlines, not literal newlines (the JSON parser accepts the former; literal newlines inside strings are invalid JSON).
2. Submit with `curl --data-binary @file`.

```
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" \
  --data-binary @/tmp/subtask-N-payload.json
```

[Cite Stage 3 Anomaly 2 as the justification in a footnote.]

## Progressive Assignment — RULE 1

[Long section explaining the mechanic, the spec §5.4 amendment, and the skill's invariant: NEVER create a subtask (other than the first in a chain) with a non-null assignee. Include worked example: 3-subtask chain, subtask 1 assigned, 2 and 3 null, PATCH on completion. Cross-link to § Paused-Target Check.]

## Paused-Target Check — RULE 2

[Pre-PATCH probe:]

```
GET /api/agents/:target-id → .status
if .status === "paused":
  DO NOT PATCH. Options:
    (a) Post comment on target subtask: "Target agent {name} is paused. Escalating."
        + @mention board (or yourself if no board channel exists)
        Set target subtask status = "blocked"
        Set parent status = "blocked"
        Exit heartbeat
    (b) If you have authority to resume (check your agent permissions:
        GET /api/agents/self → .permissions.canResumeAgents, or equivalent),
        POST /api/agents/:target-id/resume, THEN PATCH assignee,
        AND post a status comment explaining the resume action.

Default to (a) unless the skill operator has explicitly granted (b).
if .status in {idle, running}: PATCH is safe.
if .status === "running" on a DIFFERENT issue: the scheduler will serialize per
    Stage 2 Anomaly 5. PATCH is safe but the wake will queue until the current
    run completes. Log this as a note but proceed.
```

[Cite Stage 3 Anomaly 1. Emphasize: this check is mandatory on EVERY PATCH,
including the first assignment of the FIRST subtask. Silent wake drops are the
failure mode we are preventing.]

## Notification Protocol — RULE 3

Every subtask description you write includes this section verbatim:

```markdown
## Notification Protocol

When you reach a terminal status on this subtask, post a single comment on THIS issue with one of these exact forms:

- On success: `@<tech-lead-name> DONE — <one-sentence summary>. Commits: <sha1>[, <sha2>...].`
- On blocker: `@<tech-lead-name> BLOCKED — <what's blocking>. Tried: <what you tried>. Need: <what would unblock>.`
- On ambiguity: `@<tech-lead-name> NEEDS_CONTEXT — <the question>.`

Then set issue status to `done` (success), `blocked` (blocker), or leave at `in_progress` with the comment posted (ambiguity).
```

[Explain the mechanic: `@<tech-lead-name>` mention fires `issue_comment_mentioned` wake (see `server/src/routes/issues.ts:2333`). Not in the reset list (`services/heartbeat.ts:715-730`), so the wake resumes the Tech Lead's session cheaply. Cite that `issue_children_completed` alone cannot be used because it requires ALL children terminal per `services/issues.ts:1367`.]

## Subtask Description Template

Use this template for every subtask you create. Required sections:

1. **Goal** — one paragraph, what the assignee produces
2. **Context** — parent issue link, predecessor subtask(s), what code/schema/docs to read first
3. **Required test cases** or **Required acceptance checks** — concrete, not prose
4. **Required implementation files** — exact paths
5. **Workflow** — ordered list of steps (the assignee's frozen skills will fill in TDD/debug/verification discipline)
6. **Exit criteria** — how the assignee knows the subtask is done
7. **Notification Protocol** — exact text from § Notification Protocol above

The full template body is at `./implementer-subtask-template.md`. Customize only sections 1-6; leave section 7 verbatim.

[Spec-review and code-quality-review hand-offs are Stage 5; their subtask templates live at `./spec-review-subtask-template.md` and `./code-quality-review-subtask-template.md` but are dormant until a Reviewer agent exists.]

## Per-Completion Heartbeat — Acting on `@mention` Wakes

[Flow: wake with contextSnapshot.wakeReason = issue_comment_mentioned → inspect the mentioning comment → identify which subtask just finished → check target agent status for the NEXT subtask → PATCH assignee → exit. If the mentioning comment was NEEDS_CONTEXT or BLOCKED, branch to Q&A or escalation.]

## Q&A Protocol

[When the Engineer posts a NEEDS_CONTEXT mention, you answer by posting a comment on the same subtask (without @-mentioning yourself again — that would self-wake). The Engineer's assignee-comment-wake (`issue_commented`) picks up your answer. Cross-link to spec §5.1.]

## End-of-Feature Review

[When the final subtask completes, PATCH the parent issue `status: "in_review"`. This triggers `issue_status_changed` wake on the Reviewer (Stage 5). Until Stage 5 exists, leave the parent in `in_review` and exit — the board will see it in the queue.]

## Parallelism via Independence

[Absorbed from dispatching-parallel-agents/SKILL.md. Two subtasks are parallelizable if and only if:
  1. Neither is in the other's `blockedByIssueIds` chain
  2. They target different workspaces (different agents' cwds), OR one agent ONLY and serialization is intended
Stage 4's validation is all-serial because only one Engineer agent exists. Stage 6 Designer parallelism waits on Designer's isolated cwd.]

## Model Selection

[Ported from upstream subagent-driven-development SKILL.md lines 87-100, but references Paperclip's per-issue `assigneeAdapterOverrides.model` (see `server/src/services/issues.ts` — the field is an object on each issue), not CLI model flags. Heuristics:
  - Mechanical implementation (1-2 files, clear spec) → cheap model
  - Integration/multi-file → standard model
  - Architecture/design → capable model
For Stage 4 validation, leave `assigneeAdapterOverrides` null — Paperclip falls back to the agent's default (`claude-opus-4-6[1m]` per Stage 2 baseline).]

## Red Flags

[Ported from upstream lines 234-265, with CLI-isms removed and Paperclip specifics added:
- NEVER assign a subtask (other than the first) at creation — RULE 1 violation
- NEVER PATCH assignee without checking target status — RULE 2 violation
- NEVER omit Notification Protocol from a subtask description — RULE 3 violation
- NEVER two subtasks on the same workspace without a blockedByIssueIds edge between them (Stage 3 Anomaly 4 cross-file state contamination proves why)
- NEVER create subtasks that re-wake yourself via their descriptions (@-mentioning yourself in a subtask body you created would loop)
- If a subtask has been stuck in `in_progress` across 3 of your wakes without the assignee responding → set status `blocked`, escalate to the board
- If the board rejects a plan 3 times, escalate (spec §6.1)]

## Integration

Required companion skills (when they exist):
- `writing-plans` (Stage 5) — produces the plan document this skill consumes
- Engineer-agent frozen skills (Stage 2) — what assignees use inside their subtask heartbeats
- Reviewer-agent skills (Stage 5) — what consumes `status: in_review` parent

This skill operates in the Paperclip heartbeat model — no CLI, no Task tool, no TodoWrite. See spec §5 "Adaptation Rules" for the full model.
```

Write the full file, not just the outline. Expected length: ~350-450 lines. Use the upstream text as a structural source but DO NOT leave any upstream sentence that mentions "Task tool", "TodoWrite", "your human partner", "in this message", "git worktree", "subagent" (without clarification), or "the user" (without clarification) — substitute Paperclip semantics.

- [ ] **Step 3: Write the three subtask-description templates**

Create `./implementer-subtask-template.md`, `./spec-review-subtask-template.md`, `./code-quality-review-subtask-template.md` under `skills-paperclip/task-orchestration/`.

`implementer-subtask-template.md` — adapts upstream `subagent-driven-development/implementer-prompt.md`. Structure: the template IS a subtask description template (not a Task-tool prompt). Sections: Goal, Context, Required test cases, Required implementation files, Workflow, Exit criteria, Notification Protocol. Include worked placeholder values in `{{curly}}` braces so the Tech Lead can substitute them.

`spec-review-subtask-template.md` — adapts upstream `spec-reviewer-prompt.md` into a Reviewer-role subtask description. Include a note at the top: "Dormant until Stage 5 Reviewer agent exists."

`code-quality-review-subtask-template.md` — adapts upstream `code-quality-reviewer-prompt.md` similarly. Same dormant note.

Each of the three files is 60-120 lines. The exact content follows upstream closely (mostly reviewer-role discipline text) with:
- "Your human partner" → "Reviewer" or role-specific
- "Task tool" references → "subtask assignee"
- Output format paths updated to Paperclip (comments on subtask, mention @tech-lead)

- [ ] **Step 4: Quick sanity check on SKILL.md structure**

```bash
cd /Users/henrique/custom-skills/paperclipowers/skills-paperclip/task-orchestration
wc -l SKILL.md implementer-subtask-template.md spec-review-subtask-template.md code-quality-review-subtask-template.md

# Frontmatter must parse
head -5 SKILL.md
grep -c "^---$" SKILL.md  # Expect: 2 (opening and closing of frontmatter)

# No CLI-isms
grep -nE "your human partner|in this message|Task\(|TodoWrite|ask the user|git worktree" SKILL.md ./*.md \
  && echo "CLI-ISMS FOUND — fix before proceeding" \
  || echo "CLI-ism grep clean"

# All three rules are present by keyword
for pat in "RULE 1" "RULE 2" "RULE 3" "Progressive Assignment" "Paused-Target Check" "Notification Protocol"; do
  grep -q "$pat" SKILL.md || { echo "MISSING: $pat"; false; }
done && echo "All rules present"
```

Expected: SKILL.md 350-450 lines, frontmatter parses (exactly 2 `---` lines), CLI-ism grep clean, all six rule-keywords present. Fix any failure before Task 4.

---

## Task 4: Write UPSTREAM.md provenance

**Files:** Creates `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/task-orchestration/UPSTREAM.md`.

**Context:** UPSTREAM.md is the drift-check hook — `scripts/check-upstream-drift.sh` auto-discovers it (see script lines 70-78) and parses `**Upstream base commit:**` plus `- \`skills/…\`` lines to compute what upstream paths to diff against. Task 4 writes the file with the same merger-derivative framing as Stage 2's `code-review/UPSTREAM.md` (because this is also a multi-source merger, not a mechanical substitution).

- [ ] **Step 1: Write UPSTREAM.md**

Use the Write tool. File body (template — substitute actual values for `<…>` items):

```markdown
# Upstream Provenance — task-orchestration

**Stage introduced:** Stage 4
**Adaptation type:** GREENFIELD DERIVATIVE — structural merger of `subagent-driven-development` (primary) and `dispatching-parallel-agents` (concepts), rewritten for Paperclip heartbeat + subtask-graph model. Do not treat upstream changes as patches to apply.
**Last synced:** 2026-04-14
**Upstream base commit:** <UPSTREAM_SHA captured in Task 2 Step 2>
**Upstream source paths (all merged or absorbed):**
- `skills/subagent-driven-development/SKILL.md`
- `skills/subagent-driven-development/implementer-prompt.md`
- `skills/subagent-driven-development/spec-reviewer-prompt.md`
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md`
- `skills/dispatching-parallel-agents/SKILL.md`

## Merger map

| Upstream content | Destination in paperclipowers |
|---|---|
| subagent-driven-development: "Overview" + "Core principle" | `task-orchestration/SKILL.md` § Overview (rewritten for Paperclip: Task tool → subtask creation via API) |
| subagent-driven-development: "When to Use" flowchart | `task-orchestration/SKILL.md` § When to Invoke (simplified — Tech Lead always orchestrates; no alternative-execution branch because Paperclip subtasks ARE the execution model) |
| subagent-driven-development: "The Process" flowchart | `task-orchestration/SKILL.md` § The Process (rewritten: "Dispatch implementer subagent" → "Create subtask + PATCH assignee"; review stages referenced as Stage 5 hand-offs) |
| subagent-driven-development: "Model Selection" | `task-orchestration/SKILL.md` § Model Selection (retargeted at Paperclip's `assigneeAdapterOverrides.model` field) |
| subagent-driven-development: "Handling Implementer Status" | `task-orchestration/SKILL.md` § Per-Completion Heartbeat (DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT map to status+mention comment forms in Notification Protocol) |
| subagent-driven-development: "Prompt Templates" pointer | `task-orchestration/SKILL.md` § Subtask Description Template (pointing at the three template files) |
| subagent-driven-development: "Example Workflow" | Dropped — too CLI-centric to adapt cleanly; Stage 4's results doc provides a worked Paperclip example |
| subagent-driven-development: "Advantages" | Dropped — self-congratulatory, not procedural |
| subagent-driven-development: "Red Flags" | `task-orchestration/SKILL.md` § Red Flags (adapted list; Paperclip-specific flags added — RULE 1/2/3 violations, shared-workspace parallelism, self-mention loops) |
| subagent-driven-development: "Integration" | `task-orchestration/SKILL.md` § Integration (Paperclip companion-skill list, not upstream skill list) |
| subagent-driven-development: implementer-prompt.md | `task-orchestration/implementer-subtask-template.md` (converted from Task-tool prompt to subtask-description template) |
| subagent-driven-development: spec-reviewer-prompt.md | `task-orchestration/spec-review-subtask-template.md` (same conversion; marked DORMANT until Stage 5 Reviewer exists) |
| subagent-driven-development: code-quality-reviewer-prompt.md | `task-orchestration/code-quality-review-subtask-template.md` (same; DORMANT) |
| dispatching-parallel-agents: "Identify Independent Domains" + "Dispatch in Parallel" | `task-orchestration/SKILL.md` § Parallelism via Independence (boiled down to: independence = no blockedByIssueIds edge + distinct workspaces) |
| dispatching-parallel-agents: "Common Mistakes" | Absorbed into § Red Flags |
| dispatching-parallel-agents: "Real Example from Session" | Dropped — debugging-specific and CLI-centric |

## Design deviations documented here (not in design spec)

1. **@mention-based per-completion wake.** The spec §3.2 flow shows "Paperclip auto-wakes dependent subtasks on completion." That phrase is load-bearing for the Engineer chain but does NOT address how the Tech Lead wakes per subtask completion. Task orchestration invents the `@<tech-lead>` mention pattern because Paperclip's `issue_children_completed` wake fires only when ALL children are terminal (`server/src/services/issues.ts:1347-1376`), making it unusable as a per-subtask trigger. This deviation should be raised as a spec clarification after Stage 4 validation confirms the pattern works.
2. **Paused-target pre-PATCH check.** Stage 3 Anomaly 1 exposed that `issue_assigned` wakes are silently dropped when the target agent is paused. The skill encodes a mandatory `GET /api/agents/:id` status probe before every assignee PATCH. No upstream analogue (CLI has no paused state).
3. **Subtask-description Notification Protocol section.** The upstream "subagent reports status" convention is implicit in the Task-tool response; Paperclip needs it explicit in the subtask description because the assignee runs in a separate heartbeat with no prior-conversation memory.

## Resolved design decisions

- **Stage 4 omits the Reviewer-review loop.** The upstream two-stage review (spec compliance, then code quality) is encoded structurally (§ End-of-Feature Review; § Per-Subtask Review Hand-off) but DORMANT — the two Reviewer templates are shipped but unused because the Reviewer agent doesn't exist until Stage 5. The hand-off points are committed now so Stage 5 just adds the Reviewer agent and flips the dormant paths live without changing the skill.
- **Progressive assignment is unconditional.** The skill has NO escape hatch — every subtask chain is created with null assignees except the first, regardless of whether the chain has 2 subtasks or 20. See spec §5.4 amendment.

## Update procedure

**Do not mechanically re-apply upstream patches to this skill.** It is a structural merger, not an edit. When upstream restructures any of the source files:

1. Run `scripts/check-upstream-drift.sh task-orchestration` to see what changed upstream.
2. Read the upstream changes as inputs to a re-evaluation, not as patches.
3. For each upstream change, decide: does it add substantive new content that should flow into our merged skill? If yes, port the idea (not the literal text) into the appropriate section.
4. Update this file's base SHA when the re-evaluation is complete.

**High drift risk.** Upstream's `subagent-driven-development` has restructured before (the split into three prompt files was a relatively recent change). Expect to re-evaluate on every major upstream release.
```

- [ ] **Step 2: Verify UPSTREAM.md parses for the drift-check script**

```bash
cd /Users/henrique/custom-skills/paperclipowers
./scripts/check-upstream-drift.sh task-orchestration 2>&1 | head -20
```

Expected: the script outputs `=== task-orchestration ===` with `Base: <sha>`, lists the five source paths, and reports drift status. If it says `⚠️ task-orchestration: UPSTREAM.md present but no base SHA parsed — skipping`, the `**Upstream base commit:**` line format is wrong — fix the line exactly to the template's format (`**Upstream base commit:** <sha>` with a single space between the marker and the SHA). Same for `⚠️ no source paths parsed` — source paths must be bullet list items in the exact form `` - `skills/…` ``.

If the script reports "DRIFT" on one of the five source paths, that's expected only if the local superpowers clone is at a different commit than `UPSTREAM_SHA`. In that case, re-run Task 2 Step 2 and update the base SHA in UPSTREAM.md.

---

## Task 5: CLI-ism grep and full-file audit

**Files:** Read-only of the new skill files.

**Context:** Stage 2 Anomaly 1 showed that a single-line CLI-ism substitution isn't exhaustive — upstream phrases can recur in multiple sites. Task 5 runs an extensive grep before anything is committed. Running it BEFORE commit avoids a rewrite-on-top commit in git history.

- [ ] **Step 1: Run CLI-ism grep across all Stage 4 skill files**

```bash
cd /Users/henrique/custom-skills/paperclipowers/skills-paperclip/task-orchestration
echo "=== CLI-ism patterns ==="
grep -nE "your human partner|in this message|ask the user|the user said|TodoWrite|Task\(|git worktree|human partner|dispatch subagent|run in the terminal|CLI session" ./*.md \
  | grep -v "^UPSTREAM.md:" \
  || echo "CLEAN"
```

Expected: `CLEAN` for SKILL.md and the three template files. UPSTREAM.md may legitimately quote upstream phrases in the merger-map table — that's why it's excluded from the grep (same treatment as `code-review/UPSTREAM.md`).

If any hit, read the context. Distinguish:
- Genuine CLI-ism → rewrite to Paperclip semantics
- Quoted reference (e.g., "upstream's `Task(…)` dispatch pattern" in a comparison paragraph) → wrap in backticks and add a clarifying phrase like "(upstream CLI mode only — not available in Paperclip heartbeats)"

Re-run grep after fixes. Loop until CLEAN.

- [ ] **Step 2: Frontmatter + markdown-structure sanity check**

```bash
cd /Users/henrique/custom-skills/paperclipowers/skills-paperclip/task-orchestration
for f in SKILL.md implementer-subtask-template.md spec-review-subtask-template.md code-quality-review-subtask-template.md UPSTREAM.md; do
  echo "=== $f ==="
  head -1 "$f"                        # Expect: --- (frontmatter) or # Heading
  wc -l "$f"
done
```

Expected:
- SKILL.md — first line `---`, length 350-450 lines
- implementer-subtask-template.md — first line `---` or `#`, length 60-120 lines
- spec-review-subtask-template.md — same shape, length 60-120 lines
- code-quality-review-subtask-template.md — same shape, length 60-120 lines
- UPSTREAM.md — first line `# Upstream Provenance — task-orchestration`, length 40-70 lines

If a file is dramatically shorter (<30 lines), content is missing — go back to Task 3/4 and fill in.

- [ ] **Step 3: Dry-run `ls -la` on the final directory layout**

```bash
ls -la /Users/henrique/custom-skills/paperclipowers/skills-paperclip/task-orchestration/
```

Expected: exactly five files (SKILL.md, three template files, UPSTREAM.md). If any executable-bit file is present (e.g. you accidentally chmod'd something), remove the +x bit — the skill has no scripts.

---

## Task 6: Commit and push the new skill to origin

**Files:** Modifies git state on branch `paperclip-adaptation`.

**Context:** The skill must be on `origin/paperclip-adaptation` before Task 7 can import it via Paperclip's URL-based importer (the importer walks the branch on GitHub, not the local checkout). The push is load-bearing.

- [ ] **Step 1: Stage the new skill directory**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git status --porcelain
git add skills-paperclip/task-orchestration/
git status --porcelain
```

Expected: before `add`, the five new files appear as `??` untracked; after `add`, as `A`. No other files modified.

- [ ] **Step 2: Commit with a message following Stage 2/3 conventions**

```bash
git commit -m "feat(paperclipowers): Stage 4 — task-orchestration skill for Tech Lead

Adapts subagent-driven-development as the primary source with
dispatching-parallel-agents concepts absorbed. Encodes three load-bearing
rules: unconditional progressive assignment (spec §5.4), pre-PATCH paused-
target check (Stage 3 Anomaly 1), and per-completion @mention wake protocol
(works around issue_children_completed's all-or-nothing gate).

Reviewer-role hand-offs (spec compliance + code quality) are shipped as
dormant templates under implementer/spec-review/code-quality-review — they
activate in Stage 5 when the Reviewer agent is hired.

No server-code changes. No changes to the four frozen Engineer skills."
```

Expected: new commit on `paperclip-adaptation`, clean working tree.

- [ ] **Step 3: Push to origin including the two pre-existing commits from the Stage 3 tail**

```bash
git log --oneline origin/paperclip-adaptation..paperclip-adaptation
git push origin paperclip-adaptation
```

Expected pre-push: three commits ahead (the two Stage 3 tail commits `4ea4862`, `9514dbc` + Stage 4's new commit). Post-push: zero commits ahead.

- [ ] **Step 4: Verify on GitHub that the branch has the new skill**

```bash
gh api repos/henriquerferrer/paperclipowers/contents/skills-paperclip/task-orchestration?ref=paperclip-adaptation \
  | jq '[.[] | .name]'
```

Expected: `["SKILL.md","UPSTREAM.md","code-quality-review-subtask-template.md","implementer-subtask-template.md","spec-review-subtask-template.md"]`. If 404 or missing files, re-verify the push and retry.

Capture the current commit SHA — it becomes the pin SHA for the skill import in Task 7:

```bash
STAGE4_PIN_SHA=$(git rev-parse HEAD)
echo "STAGE4_PIN_SHA=$STAGE4_PIN_SHA"
echo "export STAGE4_PIN_SHA=\"$STAGE4_PIN_SHA\"" >> ~/.paperclipowers-stage4.env
```

---

## Task 7: Import `task-orchestration` into the company skill library

**Files:** No local files. Paperclip API calls via curl.

**Context:** Paperclip's URL-importer pulls from `github.com/.../tree/<branch>/<parent-dir>` and walks the directory for each contained skill. Per Stage 2 Anomaly 2, we must use the **parent directory** `…/tree/paperclip-adaptation/skills-paperclip`, not the per-skill subdirectory `…/task-orchestration`. If we use the per-skill URL, `fileInventory` gets only `SKILL.md` and the four sibling files (templates + UPSTREAM.md) are silently dropped. Stage 4 imports the entire `skills-paperclip` directory again (overlaying the four already-imported skills) and verifies that only `task-orchestration` is *added* — the four existing skills should remain at their Stage 2 pin sourceRef (`78598d5`) unless the operator explicitly re-pins them.

We have two options for "overlaying":
- **Option A:** Re-import the full directory at `STAGE4_PIN_SHA`. This would re-pin the four Stage 2 skills to the new SHA, which is a change we don't want (we want the four Engineer skills frozen at `78598d5`).
- **Option B:** Import only the `task-orchestration` sub-tree at a per-skill URL, accepting the sibling-file-drop bug. Then the templates are missing at runtime — load-bearing wrong.
- **Option C:** Import the full parent directory but specify per-skill pinning. Paperclip's importer API must support this — TASK 7 STEP 1 probes whether it does.

Default plan: **Option A with a post-import re-pin of the four Engineer skills.** If the importer supports per-skill pinning in one payload, use that instead (discovered via Step 1).

- [ ] **Step 1: Probe the import API shape**

The Paperclip API exposes `POST /api/companies/:id/skills/import` (per Stage 2 plan Task 7). Probe its schema with an empty body to get the required fields:

```bash
source ~/.paperclipowers-stage4.env
curl -sS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" \
  --data-binary '{}' | jq .
```

Expected: a Zod `Validation error` listing required fields (likely `sourceUrl` or similar plus `ref`). Record the exact field names. If the error response suggests a per-skill option (e.g. `skillSlugFilter` or `skillPath`), prefer Option C; if it does not, proceed with Option A.

Alternatively read Stage 2's executed plan commit (`b631935`) to see the actual payload shape used in Stage 2 Task 7 — that payload is known to work:

```bash
cd /Users/henrique/custom-skills/paperclipowers
git show b631935 -- docs/plans/2026-04-13-stage-2-engineer-skills.md \
  | grep -A 30 "skills/import" | head -40
```

Use the Stage 2 shape as the starting point.

- [ ] **Step 2: Capture the current sourceRefs so we can restore them**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.key | test("henriquerferrer/paperclipowers/")) | {key, slug, id, sourceRef}] | sort_by(.key)' \
  > ~/.paperclipowers-stage4-skills-before-import.json
cat ~/.paperclipowers-stage4-skills-before-import.json
```

Expected: four entries, all at `78598d564ba9f569c54f72df7b5deb58f7a15dd2`. Keep this file — Step 5 restores the pins if Option A is used.

- [ ] **Step 3: Write the import payload to a file and submit**

Use the Write tool for the payload (Stage 3 Anomaly 2). Expected payload shape (refine using Step 1's findings):

Write to `/tmp/stage4-import-payload.json`:
```json
{
  "sourceUrl": "https://github.com/henriquerferrer/paperclipowers/tree/paperclip-adaptation/skills-paperclip",
  "ref": "<STAGE4_PIN_SHA>"
}
```

(Field names depend on Step 1's probe — adjust. `ref` may be `pinSha`, `commit`, or similar.)

Submit:

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" \
  --data-binary @/tmp/stage4-import-payload.json \
  | jq .
```

Expected: a response listing the imported skills, one of which has `slug: "task-orchestration"`. If the response has only `task-orchestration` (because the importer dedupes and skips already-imported skills), great — skip Step 5's re-pin.

If the response lists all five skills with new sourceRefs (confirming Option A's overlay behaviour), continue to Step 4.

- [ ] **Step 4: Verify `task-orchestration` is imported with full file inventory**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.slug == "task-orchestration") | {key, slug, sourceRef, fileInventoryCount: (.fileInventory | length), fileNames: [.fileInventory[].path]}]'
```

Expected: exactly one entry, `slug: "task-orchestration"`, `sourceRef: <STAGE4_PIN_SHA>`, `fileInventoryCount: 5`, file names containing SKILL.md and the three templates and UPSTREAM.md. If inventory shows only `["SKILL.md"]`, the import hit Stage 2 Anomaly 2 (subdirectory-URL bug) — fix the URL to the parent directory and re-run from Step 3.

Capture the skill key:

```bash
TASK_ORCH_SKILL_KEY=$(curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug == "task-orchestration") | .key')
echo "TASK_ORCH_SKILL_KEY=$TASK_ORCH_SKILL_KEY"
echo "export TASK_ORCH_SKILL_KEY=\"$TASK_ORCH_SKILL_KEY\"" >> ~/.paperclipowers-stage4.env
```

Expected: `henriquerferrer/paperclipowers/task-orchestration`.

- [ ] **Step 5: Restore the four Engineer skills' pin to `78598d5` (only if Option A changed them)**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.slug != "task-orchestration" and (.key | test("henriquerferrer/paperclipowers/"))) | {key, slug, sourceRef}] | sort_by(.key)'
```

If any of the four shows a `sourceRef` other than `78598d564ba9f569c54f72df7b5deb58f7a15dd2`, re-pin each by re-importing JUST that skill via its per-skill URL (accepting the Stage 2 Anomaly 2 file-drop IS fine here because we're only re-pinning existing entries — the importer should update the sourceRef without dropping already-materialized files, but verify this assumption by checking `fileInventoryCount` post-pin).

If per-skill re-pinning is not supported cleanly, accept the new pin. Document it in Stage 4 results as a pin drift and note that Stage 3's test of the four Engineer skills was at `78598d5` not the current pin.

- [ ] **Step 6: Verify materialization under the runtime directory**

```bash
ssh nas "/usr/local/bin/docker exec paperclip ls -la /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ 2>&1 | head -20"
```

Expected: five runtime directories matching `{verification-before-completion,test-driven-development,systematic-debugging,code-review,task-orchestration}--<hash>/` (each hash is a content digest). If `task-orchestration--<hash>/` is missing, the import didn't materialize — hit Paperclip's materialization trigger by adding the skill to an agent's `desiredSkills` (Task 8 does this; materialization may wait until then).

Inventory files inside the new runtime dir:

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  DIR=\$(ls -d /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/task-orchestration--*/ 2>/dev/null | head -1)
  if [ -n \"\$DIR\" ]; then
    echo \"runtime dir: \$DIR\"
    ls -la \"\$DIR\"
  else
    echo \"task-orchestration not yet materialized\"
  fi
'"
```

Expected at least after Task 8: five files (SKILL.md + three templates + UPSTREAM.md) with the content-hashed directory name. If missing now, check again in Task 8 Step 4.

---

## Task 8: Create the `stage4-tech-lead` agent

**Files:** No local files. Paperclip API calls.

**Context:** A net-new agent is required. Tech Lead has `task-orchestration` plus the four Paperclip-bundled skills (matching `stage1-tester`'s bundled set — they are required by the adapter for basic heartbeat operation per Stage 2 results). Tech Lead does NOT get the four Engineer skills — they are discipline for the Engineer role. Tech Lead's workspace (cwd) is its own agent-derived path; it shares no code with the Engineer's cwd, which is correct: Tech Lead only does API calls, not code changes, so no cwd overlap is needed.

The live-API probe during plan writing confirmed `POST /api/companies/:id/agents` with cookie auth bypasses the `requireBoardApprovalForNewAgents` gate (the operator IS the board). The probe also confirmed `role: "tech_lead"` is NOT a valid enum value; use `role: "engineer"` (same as stage1-tester — role is metadata only).

- [ ] **Step 1: Write the agent-creation payload**

Write to `/tmp/stage4-tech-lead-create.json`:
```json
{
  "name": "stage4-tech-lead",
  "role": "engineer",
  "adapterType": "claude_local",
  "adapterConfig": {
    "paperclipSkillSync": {
      "desiredSkills": [
        "paperclipai/paperclip/paperclip",
        "paperclipai/paperclip/paperclip-create-agent",
        "paperclipai/paperclip/paperclip-create-plugin",
        "paperclipai/paperclip/para-memory-files",
        "henriquerferrer/paperclipowers/task-orchestration"
      ]
    }
  }
}
```

Reason for the skill set: task-orchestration is the skill under test; the four `paperclipai/paperclip/*` skills are Paperclip-required bundled skills (same set stage1-tester has — they provide the agent's baseline create-agent/plugin/memory capabilities). No Engineer-role skills (TDD, systematic-debugging, etc.) because the Tech Lead doesn't write code.

Use `\n`-escape sequences if any string contains newlines (none do here — this payload is flat).

- [ ] **Step 2: Submit**

```bash
TECH_LEAD_RESP=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  --data-binary @/tmp/stage4-tech-lead-create.json)

echo "$TECH_LEAD_RESP" | jq '{id, name, role, status, adapterType, urlKey, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills}'

TECH_LEAD_AGENT_ID=$(echo "$TECH_LEAD_RESP" | jq -r '.id')
echo "TECH_LEAD_AGENT_ID=$TECH_LEAD_AGENT_ID"
test -n "$TECH_LEAD_AGENT_ID" && test "$TECH_LEAD_AGENT_ID" != "null" \
  || { echo "FAIL: agent create did not return an id"; exit 1; }

echo "export TECH_LEAD_AGENT_ID=\"$TECH_LEAD_AGENT_ID\"" >> ~/.paperclipowers-stage4.env
```

Expected:
- `status: "idle"` (board creates agents directly-ready, no pending-hire gate)
- `role: "engineer"`, `adapterType: "claude_local"`
- `desiredSkills` contains all five keys
- `urlKey: "stage4-tech-lead"`
- A new UUID in `id`

If the response has `status: "pending_hire_approval"` (or similar gated state), the `requireBoardApprovalForNewAgents` gate fired unexpectedly — check the company flag and the actor type. Either approve the hire via the approvals endpoint or adjust the company's approval flag. Document as an anomaly either way.

- [ ] **Step 3: Verify `task-orchestration` materialization under the Tech Lead's agent dir**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$TECH_LEAD_AGENT_ID/skills" \
  | jq '{desiredSkills, entries: [.entries[] | {key, runtimeName, state, required}]}'
```

Expected: `desiredSkills` contains the five keys from Step 1. `entries` has five objects, each with `state: "configured"` and a `runtimeName` matching the runtime directory (`task-orchestration--<hash>`, same hash as Task 7 Step 6 — content-addressed).

Re-check materialization:

```bash
ssh nas "/usr/local/bin/docker exec paperclip ls -la /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/task-orchestration--*/ 2>/dev/null"
```

Expected: 5 files listed (SKILL.md, three templates, UPSTREAM.md). If still zero files, materialization is lazy; it will happen on the first Tech Lead heartbeat (Task 11).

- [ ] **Step 4: Snapshot the Tech Lead's initial state**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$TECH_LEAD_AGENT_ID" \
  | jq '{id, name, role, status, adapterType, adapterConfig: {skillsCount: (.adapterConfig.paperclipSkillSync.desiredSkills | length), instructionsFilePath: .adapterConfig.instructionsFilePath}}' \
  > ~/.paperclipowers-stage4-tech-lead-initial.json
cat ~/.paperclipowers-stage4-tech-lead-initial.json
```

Expected: `status: "idle"`, skills count 5, instructionsFilePath populated. Save the file for Task 13's results doc.

---

## Task 9: Verify the Engineer is ready to receive Tech Lead's subtask assignments

**Files:** No local files. Paperclip API checks.

**Context:** When the Tech Lead creates subtask 1 with `assigneeAgentId: $AGENT_ID` (stage1-tester), the `issue_assigned` wake fires — BUT Stage 3 Anomaly 1 showed this wake is silently dropped if the target agent is paused. The Tech Lead's skill (RULE 2) requires a pre-PATCH check, so if the Engineer is paused when the Tech Lead runs, the Tech Lead should escalate rather than fire a dead wake. We want to test RULE 2's paused-handling later (Task 12), but we want subtask 1 to succeed normally — so the Engineer must be `idle` when the Tech Lead first runs (Task 11).

- [ ] **Step 1: Check current Engineer status**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq '{id, name, status, pausedAt}'
```

Expected: `status: "paused"` (Stage 3 rollback left it that way). If already `idle`, skip Step 2.

- [ ] **Step 2: Resume the Engineer**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/resume" \
  | jq '{id, status, pausedAt}'
```

Expected: `status: "idle"`, `pausedAt: null` (or unchanged if the field isn't cleared).

- [ ] **Step 3: Drain stray wakes — ensure no queued run for the Engineer**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=3" \
  | jq '[.[] | {id, status, startedAt, finishedAt, wakeReason: .contextSnapshot.wakeReason}]'
```

Expected: all three entries `status` in `{succeeded, failed, cancelled}`. If any `queued` or `running` is present, wait until it terminates (poll every 30s). An unexpected wake after resume would suggest a queued wake that was recovered — that's fine, let it run out; Stage 4 doesn't depend on the Engineer being idle RIGHT NOW, only during Task 11.

---

## Task 10: Author the parent issue with a hand-written plan document

**Files:** Writes JSON payload files to `/tmp/` (not committed). Creates one Paperclip issue via API.

**Context:** `writing-plans` (the skill that would normally produce a plan document) is NOT Stage 4's scope. The Stage 4 executor hand-writes a plan that the Tech Lead consumes. The plan is deliberately small and rigid so the Tech Lead's decomposition is deterministic: three capabilities, ordered, no ambiguity about parallelism.

To avoid contaminating the Stage 3 task-counter workspace with drift, the Stage 4 feature targets a NEW tiny CLI — `workspace-log` — a 3-subtask vertical slice:

1. `workspace-log init` — creates a fresh `workspace-log.json` with schema `{"entries":[]}`
2. `workspace-log note <text>` — appends an entry `{"ts": iso8601, "text": "..."}`
3. `workspace-log last [N]` — prints the last N entries (default 5)

Each is trivially implementable via TDD (Stage 3 already proved the Engineer's discipline holds for this shape). The point of Stage 4 is the orchestration, not the code.

The parent issue's description contains the plan document inline, formatted exactly the way the Tech Lead's task-orchestration skill expects (see SKILL.md § First Wake — Reading the Plan and Decomposing).

- [ ] **Step 1: Write the parent issue payload to a file**

The plan text below is what goes into the parent issue's `description` field. It is written from the board's perspective: "Here's an approved plan, Tech Lead. Decompose and execute." Pay attention to the **last section** — it explicitly names the three subtasks to emit and specifies progressive-assignment requirements so the Tech Lead's decomposition is testable, not ambiguous.

Save the following to `/tmp/stage4-parent-payload.json` via the Write tool. Note the `\n` escape sequences (literal backslash-n) — the server decodes them to newlines. Literal newlines inside JSON string values would make the JSON invalid (Stage 3 Anomaly 2).

```json
{
  "title": "Feature: workspace-log CLI (Stage 4 orchestration trial)",
  "description": "# workspace-log\n\nA three-command Node.js CLI for logging workspace activity. Persists to `workspace-log.json` in the current working directory.\n\n## Commands (in required subtask order)\n\n1. `workspace-log init` — create a fresh `workspace-log.json` with `{\"entries\":[]}`. Must not overwrite an existing file without `--force`.\n2. `workspace-log note <text>` — append an entry `{\"ts\":<iso8601>,\"text\":<text>}`. Fails clearly if `init` has not been run.\n3. `workspace-log last [N]` — print the last N entries (default 5), newest first.\n\n## Constraints\n\n- Node.js 20.x built-ins only. No npm deps. Use `node:test`, `node:fs/promises`, `node:path`.\n- Data file: `workspace-log.json` in the working directory.\n- Each subtask must have its own test file: `test/init.test.js`, `test/note.test.js`, `test/last.test.js`. Use a unique fixture filename per test file (e.g. `workspace-log.init.test.json`, `.note.test.json`, `.last.test.json`) to avoid Stage 3 Anomaly 4 cross-file state contamination.\n- All three commands dispatched from a single `bin/workspace-log.js` entry point.\n\n## Acceptance criteria\n\n- `node --test test/init.test.js test/note.test.js test/last.test.js` exits 0 at the end of subtask 3.\n- Git log shows three commits, one per subtask, in order.\n- Each subtask description includes the Notification Protocol (per task-orchestration skill RULE 3).\n\n## Decomposition directive for the Tech Lead\n\nThis plan is pre-decomposed into exactly **three sequential subtasks**, one per command above, in the listed order. Each subtask depends on its predecessor via `blockedByIssueIds`. The first subtask is assigned to the Engineer (`stage1-tester`) at creation; the second and third are created with `assigneeAgentId: null` per task-orchestration RULE 1 (progressive assignment). The Tech Lead PATCHes each assignee only after checking the target agent's status per RULE 2, and only after the predecessor reaches `done`.\n\nThe Engineer for this feature is `stage1-tester` (agent id available via `GET /api/companies/<company-id>/agents?role=engineer`). Do not second-guess this assignment — the role mapping is fixed for Stage 4.\n\nAt the end of subtask 3, PATCH the parent issue to `status: \"in_review\"` per § End-of-Feature Review."
}
```

- [ ] **Step 2: Create the parent issue**

```bash
source ~/.paperclipowers-stage4.env
STAGE4_PARENT_RESP=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" \
  --data-binary @/tmp/stage4-parent-payload.json)

echo "$STAGE4_PARENT_RESP" | jq '{id, identifier, title, status}'

STAGE4_PARENT_ISSUE=$(echo "$STAGE4_PARENT_RESP" | jq -r '.id')
echo "STAGE4_PARENT_ISSUE=$STAGE4_PARENT_ISSUE"
test -n "$STAGE4_PARENT_ISSUE" && test "$STAGE4_PARENT_ISSUE" != "null" \
  || { echo "FAIL: parent create did not return an id"; exit 1; }
echo "export STAGE4_PARENT_ISSUE=\"$STAGE4_PARENT_ISSUE\"" >> ~/.paperclipowers-stage4.env
```

Expected: identifier likely `PAP-12` (first free slot after Stage 3's PAP-11 — counter is monotonic so this may be higher if any test issues were created in between; do not hard-code). `status: "backlog"` or `"todo"` (server default). Newlines in the description should round-trip correctly:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_PARENT_ISSUE" \
  | jq -r '.description' | head -5
```

Expected: the description is rendered with real newlines separating `# workspace-log`, `A three-command …`, etc. If newlines are absent (all one line), Anomaly 2 recurred — fix the payload to use `\n` escape sequences in string values and re-create the issue.

---

## Task 11: Assign parent to Tech Lead; observe first heartbeat; verify subtask graph

**Files:** No local files. Paperclip API + Docker-container inspection.

**Context:** This is the first orchestration test. PATCHing `assigneeAgentId: $TECH_LEAD_AGENT_ID` on the parent fires `issue_assigned` (wake reason in the reset list) → Tech Lead starts with a fresh Claude session → reads the parent issue description → applies task-orchestration skill → creates three subtasks with progressive assignment.

**RULE 2 pre-check:** before we assign the parent, confirm the Tech Lead is idle. Before the Tech Lead issues its own PATCHes, it should run the same check on stage1-tester (Task 11 Step 6 verifies this happened).

- [ ] **Step 1: Verify Tech Lead is idle and no queued runs**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$TECH_LEAD_AGENT_ID" \
  | jq '{status, lastHeartbeatAt}'
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=3" \
  | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason}]'
```

Expected: `status: "idle"`, zero heartbeat runs (this is a new agent).

- [ ] **Step 2: PATCH parent issue to assign Tech Lead**

```bash
printf '{"assigneeAgentId":"%s"}' "$TECH_LEAD_AGENT_ID" > /tmp/stage4-parent-assign.json
curl -sfS -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_PARENT_ISSUE" \
  --data-binary @/tmp/stage4-parent-assign.json \
  | jq '{id, identifier, assigneeAgentId, status}'
```

Expected: `assigneeAgentId: $TECH_LEAD_AGENT_ID`. Wake is queued; scheduler consumes on next tick (~5-15s).

- [ ] **Step 3: Poll for Tech Lead's first heartbeat run to terminate**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason) \(.contextSnapshot.issueId)"')
  echo "$(date +%H:%M:%S)  $LATEST"
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  if [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; then
    STAGE4_RUN_TECH_LEAD_1=$(echo "$LATEST" | awk '{print $1}')
    break
  fi
  sleep 10
done
echo "STAGE4_RUN_TECH_LEAD_1=$STAGE4_RUN_TECH_LEAD_1"
echo "export STAGE4_RUN_TECH_LEAD_1=\"$STAGE4_RUN_TECH_LEAD_1\"" >> ~/.paperclipowers-stage4.env
```

Expected: run reaches `succeeded` in 90-240 seconds (fresh cached-input budget is larger because task-orchestration is a new skill — expect 300-600k cached input tokens on this first run). Wake reason is `issue_assigned` (matches the reset list — fresh Claude session confirmed).

If `failed`, read the run detail:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$STAGE4_RUN_TECH_LEAD_1" \
  | jq '{status, error, errorCode, exitCode, signal, stderrExcerpt, stdoutExcerpt: (.stdoutExcerpt | .[0:400])}'
```

Stop and investigate before continuing.

- [ ] **Step 4: Capture telemetry for Run 1**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$STAGE4_RUN_TECH_LEAD_1" \
  | jq '{id, status, startedAt, finishedAt, sessionIdBefore, sessionIdAfter, usageJson, resultJson, contextSnapshot: {wakeReason, source, issueId}}' \
  > ~/.paperclipowers-stage4-run-tech-lead-1.json
cat ~/.paperclipowers-stage4-run-tech-lead-1.json
```

Expected: `sessionIdBefore: null`, `sessionIdAfter: <new-uuid>` (fresh session), `usageJson.freshSession: true`, `usageJson.cachedInputTokens` in 300-600k range, `usageJson.model: "claude-opus-4-6[1m]"`.

- [ ] **Step 5: Verify exactly three subtasks were created**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues?parentId=$STAGE4_PARENT_ISSUE&limit=10" \
  | jq '[.[] | {identifier, title, status, assigneeAgentId, blockedByCount: "<see per-issue call below>"}] | sort_by(.identifier)' \
  > ~/.paperclipowers-stage4-subtasks-snapshot.json
cat ~/.paperclipowers-stage4-subtasks-snapshot.json
```

Expected: three entries, identifiers consecutive from the next-free slot. Titles reference `init`, `note`, `last` (or the Tech Lead's paraphrasing; the matching should be unambiguous on the Command-to-subtask-1/2/3 mapping from the parent description).

Capture the three IDs:

```bash
STAGE4_SUB_1=$(jq -r '.[0].identifier + " " + (.[0].id // empty)' ~/.paperclipowers-stage4-subtasks-snapshot.json | awk '{print $2}')
# If .id is missing from the snapshot, fetch again with .id included:
SUBTASKS=$(curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues?parentId=$STAGE4_PARENT_ISSUE&limit=10" \
  | jq 'sort_by(.identifier)')

STAGE4_SUB_1=$(echo "$SUBTASKS" | jq -r '.[0].id')
STAGE4_SUB_2=$(echo "$SUBTASKS" | jq -r '.[1].id')
STAGE4_SUB_3=$(echo "$SUBTASKS" | jq -r '.[2].id')
echo "STAGE4_SUB_1=$STAGE4_SUB_1"
echo "STAGE4_SUB_2=$STAGE4_SUB_2"
echo "STAGE4_SUB_3=$STAGE4_SUB_3"
test -n "$STAGE4_SUB_1" && test -n "$STAGE4_SUB_2" && test -n "$STAGE4_SUB_3" \
  || { echo "FAIL: expected three subtasks, got fewer"; exit 1; }
cat <<EOF >> ~/.paperclipowers-stage4.env
export STAGE4_SUB_1="$STAGE4_SUB_1"
export STAGE4_SUB_2="$STAGE4_SUB_2"
export STAGE4_SUB_3="$STAGE4_SUB_3"
EOF
```

- [ ] **Step 6: Verify RULE 1 (progressive assignment) on each subtask**

For each subtask:
```bash
for S in "$STAGE4_SUB_1" "$STAGE4_SUB_2" "$STAGE4_SUB_3"; do
  echo "=== $S ==="
  curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/issues/$S" \
    | jq '{identifier, status, assigneeAgentId, blockedBy: [.blockedBy[] | {identifier, status, id}]}'
done
```

Expected, EXACTLY:
- `STAGE4_SUB_1`: `assigneeAgentId: "$AGENT_ID"` (stage1-tester), `blockedBy: []`, `status: "todo"`
- `STAGE4_SUB_2`: `assigneeAgentId: null`, `blockedBy: [{id: $STAGE4_SUB_1, …}]`, `status: "todo"`
- `STAGE4_SUB_3`: `assigneeAgentId: null`, `blockedBy: [{id: $STAGE4_SUB_2, …}]`, `status: "todo"`

**If any subtask-2 or subtask-3 has a non-null `assigneeAgentId` — RULE 1 is violated. Stop; this is the load-bearing failure of the skill. Re-read Tech Lead's Run 1 logs, identify the reasoning gap, go back to Task 3 Step 2 to tighten SKILL.md language, and re-run from Task 5 (re-commit, re-import, re-create Tech Lead, re-run).** Do not try to "fix forward" by manually PATCHing subtask 2/3 to null — that would mask the real defect.

- [ ] **Step 7: Verify RULE 2 (paused-target check) was performed by the Tech Lead**

The Tech Lead should have issued `GET /api/agents/$AGENT_ID` before PATCHing subtask 1's assignee (that's the only PATCH required at creation time). There's no direct log of GET requests in heartbeat telemetry, but the run's stdout/tool-use log should show the check. Read the run detail's tool-use summary:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$STAGE4_RUN_TECH_LEAD_1/events?limit=200" \
  | jq '[.[] | select(.type | test("tool|bash|curl"))] | .[0:30]' \
  > ~/.paperclipowers-stage4-tech-lead-1-events.json
grep -iE "agents/$AGENT_ID|/api/agents/" ~/.paperclipowers-stage4-tech-lead-1-events.json | head -5
```

Expected: at least one event reading `/api/agents/<uuid>` where `<uuid>` matches `$AGENT_ID`. If no such read appears, RULE 2 was not enforced — document as an anomaly and sharpen SKILL.md § Paused-Target Check language for Stage 4.5 or Stage 5 iteration, but proceed (subtask 1's target was idle so the skill got the right answer by default).

- [ ] **Step 8: Verify RULE 3 (Notification Protocol) is embedded in every subtask description**

```bash
for S in "$STAGE4_SUB_1" "$STAGE4_SUB_2" "$STAGE4_SUB_3"; do
  echo "=== $S ==="
  curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/issues/$S" \
    | jq -r '.description' \
    | grep -iE "notification protocol|@stage4-tech-lead|@<tech-lead|done —" \
    | head -3
done
```

Expected: each subtask's description contains `Notification Protocol` heading AND a concrete `@stage4-tech-lead` mention instruction (or `@<tech-lead-name>` placeholder if the Tech Lead didn't substitute its own name — which would be a minor issue but not a blocker). Missing entirely = RULE 3 violation, stop and escalate.

- [ ] **Step 9: Verify the Tech Lead exited heartbeat (no self-loop)**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=5" \
  | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId}]'
```

Expected: exactly one run (the one captured above). If a second run is queued/running with `wakeReason: issue_assigned` or anything else, the Tech Lead may have self-woken (e.g. by @-mentioning itself in a subtask description) — investigate before proceeding.

---

## Task 12: Run subtask 1 end-to-end; observe Tech Lead's per-completion PATCH

**Files:** No local files. Paperclip API + Docker-container workspace inspection.

**Context:** Subtask 1 is assigned to the Engineer. The Engineer's `issue_assigned` wake is queued (from Task 11's subtask creation). The Engineer runs, implements `workspace-log init`, commits, posts a `@stage4-tech-lead DONE …` comment on subtask 1, marks it `done`. The mention fires `issue_comment_mentioned` → Tech Lead wakes → checks stage1-tester status (RULE 2) → PATCHes subtask 2's `assigneeAgentId = $AGENT_ID` → exits.

- [ ] **Step 1: Poll for subtask 1's Engineer heartbeat to terminate**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason) \(.contextSnapshot.issueId)"')
  echo "$(date +%H:%M:%S)  eng run: $LATEST"
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  ISSUE=$(echo "$LATEST" | awk '{print $4}')
  if [ "$ISSUE" = "$STAGE4_SUB_1" ] && { [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; }; then
    STAGE4_RUN_ENG_1=$(echo "$LATEST" | awk '{print $1}')
    break
  fi
  sleep 15
done
echo "STAGE4_RUN_ENG_1=$STAGE4_RUN_ENG_1"
echo "export STAGE4_RUN_ENG_1=\"$STAGE4_RUN_ENG_1\"" >> ~/.paperclipowers-stage4.env
```

Expected: succeeds in 90-180 seconds (similar to Stage 3's per-subtask cost).

- [ ] **Step 2: Verify Engineer posted a DONE mention comment on subtask 1**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_1/comments?limit=10" \
  | jq '[.[] | {id, createdAt, authorAgentId, body: (.body | .[0:200])}]' \
  > ~/.paperclipowers-stage4-sub-1-comments.json
jq -r '.[] | .body' ~/.paperclipowers-stage4-sub-1-comments.json | grep -iE "@stage4-tech-lead.+done" | head -1
```

Expected: at least one comment matching `@stage4-tech-lead DONE …`. If absent, the subtask description's Notification Protocol did not fire — subtask 1's status is still set to `done` (manual transition) but Tech Lead will not wake on mention. Skip to Step 4's fallback.

- [ ] **Step 3: Poll for Tech Lead's wake on the mention**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason) \(.contextSnapshot.issueId)"')
  echo "$(date +%H:%M:%S)  tech-lead run: $LATEST"
  ID=$(echo "$LATEST" | awk '{print $1}')
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  REASON=$(echo "$LATEST" | awk '{print $3}')
  if [ "$ID" != "$STAGE4_RUN_TECH_LEAD_1" ] && { [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; }; then
    STAGE4_RUN_TECH_LEAD_2=$ID
    break
  fi
  sleep 15
done
echo "STAGE4_RUN_TECH_LEAD_2=$STAGE4_RUN_TECH_LEAD_2"
echo "STAGE4_RUN_TECH_LEAD_2 wakeReason: $REASON"
echo "export STAGE4_RUN_TECH_LEAD_2=\"$STAGE4_RUN_TECH_LEAD_2\"" >> ~/.paperclipowers-stage4.env
```

Expected: the Tech Lead run finishes in 30-90 seconds, `wakeReason: "issue_comment_mentioned"`, `contextSnapshot.issueId: $STAGE4_SUB_1`. Because `issue_comment_mentioned` is NOT in the reset list, `sessionIdBefore == sessionIdAfter of Run 1` (session resumed) — verify:

```bash
jq -r '.sessionIdAfter' ~/.paperclipowers-stage4-run-tech-lead-1.json
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$STAGE4_RUN_TECH_LEAD_2" \
  | jq '{sessionIdBefore, sessionIdAfter, usageJson: {cachedInputTokens, freshSession, sessionReused, sessionRotated}}' \
  > ~/.paperclipowers-stage4-run-tech-lead-2.json
cat ~/.paperclipowers-stage4-run-tech-lead-2.json
```

Expected: `sessionIdBefore == Run 1's sessionIdAfter`, `freshSession: false`, `sessionReused: true`.

- [ ] **Step 4: Verify Tech Lead PATCHed subtask 2's assigneeAgentId**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_2" \
  | jq '{identifier, status, assigneeAgentId}'
```

Expected: `assigneeAgentId: $AGENT_ID` (stage1-tester). If still `null`, the Tech Lead failed to PATCH — check Run 2 events:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$STAGE4_RUN_TECH_LEAD_2/events?limit=100" \
  | jq '[.[] | select(.type | test("tool|bash")) | {type, content: (.content | .[0:300])}]' \
  | head -40
```

If the PATCH was issued but returned an error (e.g. 400 validation), document as an anomaly and manual-PATCH to continue the test:

```bash
# Fallback only if Tech Lead failed to PATCH and we want to continue validating later steps:
printf '{"assigneeAgentId":"%s"}' "$AGENT_ID" > /tmp/stage4-sub2-assign.json
curl -sfS -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_2" \
  --data-binary @/tmp/stage4-sub2-assign.json \
  | jq '{identifier, assigneeAgentId}'
```

Log this fallback in the Stage 4 results doc as a skill failure.

- [ ] **Step 5: Verify Tech Lead exited without self-looping**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=5" \
  | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason}]'
```

Expected: exactly two runs total so far (Run 1 issue_assigned, Run 2 issue_comment_mentioned). If more, investigate.

- [ ] **Step 6: Poll for Engineer's subtask 2 heartbeat to terminate**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason) \(.contextSnapshot.issueId)"')
  echo "$(date +%H:%M:%S)  eng run: $LATEST"
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  ISSUE=$(echo "$LATEST" | awk '{print $4}')
  if [ "$ISSUE" = "$STAGE4_SUB_2" ] && { [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; }; then
    STAGE4_RUN_ENG_2=$(echo "$LATEST" | awk '{print $1}')
    break
  fi
  sleep 15
done
echo "STAGE4_RUN_ENG_2=$STAGE4_RUN_ENG_2"
echo "export STAGE4_RUN_ENG_2=\"$STAGE4_RUN_ENG_2\"" >> ~/.paperclipowers-stage4.env
```

Expected: `wakeReason: "issue_assigned"`, session is fresh (Engineer's progressive-assignment fresh-session pattern from Stage 3). Confirm:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$STAGE4_RUN_ENG_2" \
  | jq '{sessionIdBefore, sessionIdAfter, usageJson: {freshSession, sessionReused}}'
```

Expected: `freshSession: true`, `sessionReused: false`. If not, Stage 3's progressive-assignment mechanic broke — unlikely since no server code changed, but document.

- [ ] **Step 7: Verify subtask 2 is done and the Engineer posted a DONE mention**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_2" \
  | jq '{identifier, status}'
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_2/comments?limit=10" \
  | jq '[.[] | {body: (.body | .[0:200])}]'
```

Expected: subtask 2 `status: "done"`, last comment matches `@stage4-tech-lead DONE …`.

DO NOT proceed to Task 13 yet — Task 13 intentionally injects a pause before the Tech Lead's subtask-3 PATCH, and that requires the Tech Lead's wake to be queued but not yet run. Move immediately to Task 13 before the scheduler picks up the Tech Lead's next wake.

---

## Task 13: Paused-target trap — validate RULE 2 escalation

**Files:** No local files. Paperclip API.

**Context:** This is the Stage 3 Anomaly 1 reproduction-and-verification trap. Subtask 2 is done; the Engineer just posted a `@stage4-tech-lead DONE …` mention comment; the Tech Lead's wake on `issue_comment_mentioned` is queued. BEFORE the Tech Lead's scheduler tick consumes the wake, we pause the Engineer. When the Tech Lead runs, its `GET /api/agents/$AGENT_ID` probe should see `status: "paused"` and trigger RULE 2 escalation (post a comment on subtask 3, set subtask 3 status `blocked`, set parent status `blocked` OR equivalent). The Tech Lead should NOT fire a PATCH that would be dropped.

This is a race — we have a narrow window between subtask-2-done and Tech-Lead-run. If we miss, the Tech Lead will run first, see the Engineer idle, PATCH, and subtask 3 will kick off normally. Plan for both outcomes: if we miss the race, manually re-set up the trap by pausing the Engineer AFTER the Tech Lead's next-idle state and re-wake via a dummy comment (see Step 5).

- [ ] **Step 1: Pause the Engineer immediately**

Do this within 10 seconds of subtask 2 reaching `done` (ideally within 5):

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/pause" \
  | jq '{id, status, pausedAt}'
```

Expected: `status: "paused"`. The `/pause` endpoint also cancels any in-flight Engineer run (`server/src/routes/agents.ts:1962-1983`). If the Engineer had already been woken by the subtask-3 PATCH when you paused (because the Tech Lead ran faster than you), the Engineer's in-flight run is cancelled — see Step 5 fallback.

- [ ] **Step 2: Poll for Tech Lead's next run to terminate**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason)"')
  echo "$(date +%H:%M:%S)  tech-lead run: $LATEST"
  ID=$(echo "$LATEST" | awk '{print $1}')
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  if [ "$ID" != "$STAGE4_RUN_TECH_LEAD_2" ] && { [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; }; then
    STAGE4_RUN_TECH_LEAD_3_PAUSED=$ID
    break
  fi
  sleep 10
done
echo "STAGE4_RUN_TECH_LEAD_3_PAUSED=$STAGE4_RUN_TECH_LEAD_3_PAUSED"
echo "export STAGE4_RUN_TECH_LEAD_3_PAUSED=\"$STAGE4_RUN_TECH_LEAD_3_PAUSED\"" >> ~/.paperclipowers-stage4.env
```

- [ ] **Step 3: Assess Tech Lead's behaviour — did it escalate or PATCH blindly?**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_3" \
  | jq '{identifier, status, assigneeAgentId}'
```

Three possible outcomes:

**(A) RULE 2 enforced — escalation path taken (SUCCESS):**
- `assigneeAgentId: null`
- `status: "blocked"` (or similar non-`todo` escalation status)
- A comment on subtask 3 exists with text matching "paused" or "blocked" or "escalat" and the Tech Lead's authorAgentId
- Optionally, the PARENT issue status is also `blocked` (indicates deep escalation)

Verify via comment grep:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_3/comments?limit=10" \
  | jq '[.[] | {authorAgentId, body: (.body | .[0:300])}]'
```

Expected: Tech Lead posted a comment explaining the block.

**(B) RULE 2 partially enforced — PATCH issued but queued for a paused agent (PARTIAL FAILURE):**
- `assigneeAgentId: $AGENT_ID`
- `status: "todo"` (no escalation)
- No Engineer heartbeat run will fire (confirmed by Step 4 polling)

This reproduces Stage 3 Anomaly 1 with the skill's pre-check missing or incorrectly conditioned. Document as an anomaly; the skill needs sharpening.

**(C) Race missed — Tech Lead ran first and PATCHed successfully, then we paused (NO TRAP TRIGGERED):**
- `assigneeAgentId: $AGENT_ID`
- `status: "todo"` (Engineer's heartbeat WAS starting before pause cancelled it)
- An Engineer run for subtask 3 exists with `status: "cancelled"` or short `finishedAt`

This is a test-procedure issue, not a skill issue. Go to Step 5.

- [ ] **Step 4: If outcome was (A), resume the Engineer and re-wake the Tech Lead**

```bash
# Resume Engineer
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/resume" \
  | jq '{id, status}'

# Re-wake Tech Lead by posting a revival comment on the parent, mentioning the Tech Lead.
# (Board posting a comment fires issue_commented on the parent's assignee, which IS the Tech Lead.)
printf '{"body":"Engineer resumed at %s. Please reconsider subtask %s assignment."}' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "<STAGE4_SUB_3 short form, e.g. the identifier PAP-N>" \
  > /tmp/stage4-revival-comment.json
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_PARENT_ISSUE/comments" \
  --data-binary @/tmp/stage4-revival-comment.json \
  | jq '{id, createdAt}'
```

Expected: Tech Lead wakes on `issue_commented`, runs, re-checks the Engineer (now idle), PATCHes subtask 3 assignee, exits.

Poll for the new Tech Lead run:

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason)"')
  ID=$(echo "$LATEST" | awk '{print $1}')
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  if [ "$ID" != "$STAGE4_RUN_TECH_LEAD_3_PAUSED" ] && { [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; }; then
    STAGE4_RUN_TECH_LEAD_4_REVIVED=$ID
    break
  fi
  sleep 10
done
echo "STAGE4_RUN_TECH_LEAD_4_REVIVED=$STAGE4_RUN_TECH_LEAD_4_REVIVED"
echo "export STAGE4_RUN_TECH_LEAD_4_REVIVED=\"$STAGE4_RUN_TECH_LEAD_4_REVIVED\"" >> ~/.paperclipowers-stage4.env

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_3" \
  | jq '{identifier, status, assigneeAgentId}'
```

Expected: subtask 3 now has `assigneeAgentId: $AGENT_ID`, `status: "todo"` (un-blocked).

- [ ] **Step 5: If outcome was (B), manually pause + re-create the trap; if (C), accept the miss and annotate the results doc**

**(B) recovery:**
1. PATCH subtask 3 back to `assigneeAgentId: null`, `status: "blocked"` to prevent dead wake
2. Document in Stage 4 results as "RULE 2 NOT ENFORCED — Tech Lead PATCHed a paused target"
3. Manually re-PATCH after resuming (same as Step 4)

**(C) recovery — retry the trap:**
1. Wait for the Engineer's cancelled subtask-3 run to be fully terminated
2. PATCH subtask 3 back to `assigneeAgentId: null, status: "todo"`
3. Pause the Engineer
4. POST a comment on subtask 3 mentioning the Tech Lead: `@stage4-tech-lead please re-check subtask assignment; engineer was paused after initial PATCH.`
5. Observe the Tech Lead's wake; assess A/B/C again

If the trap keeps missing the race despite two retries, record the outcome as "RULE 2 untested — race window too narrow to capture paused-target scenario; skill behaviour observed normal-path only" and proceed. This is a weaker result but still useful.

- [ ] **Step 6: Run subtask 3 to completion**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason) \(.contextSnapshot.issueId)"')
  echo "$(date +%H:%M:%S)  eng run: $LATEST"
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  ISSUE=$(echo "$LATEST" | awk '{print $4}')
  if [ "$ISSUE" = "$STAGE4_SUB_3" ] && { [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; }; then
    STAGE4_RUN_ENG_3=$(echo "$LATEST" | awk '{print $1}')
    break
  fi
  sleep 15
done
echo "STAGE4_RUN_ENG_3=$STAGE4_RUN_ENG_3"
echo "export STAGE4_RUN_ENG_3=\"$STAGE4_RUN_ENG_3\"" >> ~/.paperclipowers-stage4.env

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_SUB_3" \
  | jq '{identifier, status}'
```

Expected: subtask 3 `status: "done"`, Engineer posts DONE mention.

- [ ] **Step 7: Observe Tech Lead's end-of-feature action — PATCH parent to `in_review`**

Per task-orchestration § End-of-Feature Review, the Tech Lead should PATCH the parent `status: "in_review"` on the final subtask's completion mention.

```bash
# Poll for one more Tech Lead run on the final subtask's mention
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$TECH_LEAD_AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason)"')
  ID=$(echo "$LATEST" | awk '{print $1}')
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  if [ "$ID" != "$STAGE4_RUN_TECH_LEAD_4_REVIVED" ] && [ "$ID" != "$STAGE4_RUN_TECH_LEAD_3_PAUSED" ] \
      && { [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; }; then
    break
  fi
  sleep 10
done

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_PARENT_ISSUE" \
  | jq '{identifier, status, assigneeAgentId}'
```

Expected: parent `status: "in_review"`. If the Tech Lead did not make this final PATCH (still `todo` or stuck on an earlier status), document as an anomaly — the end-of-feature hand-off did not fire. Manually PATCH the parent to `in_review` to close out the test:

```bash
printf '{"status":"in_review"}' > /tmp/stage4-parent-final.json
curl -sfS -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE4_PARENT_ISSUE" \
  --data-binary @/tmp/stage4-parent-final.json \
  | jq '{identifier, status}'
```

- [ ] **Step 8: Snapshot the final workspace state**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  cd $WORKSPACE_CWD
  echo \"=== git log (since Stage 3 baseline) ===\"
  git log --oneline -20
  echo \"=== workspace-log files ===\"
  ls -la src/ bin/ test/ 2>/dev/null | grep -E \"(workspace-log|init|note|last)\"
  echo \"=== data file ===\"
  cat workspace-log.json 2>/dev/null || echo \"(no data file)\"
  echo \"=== test run ===\"
  node --test test/init.test.js test/note.test.js test/last.test.js 2>&1 | tail -15
'" | tee ~/.paperclipowers-stage4-workspace-final.txt
```

Expected: 3+ new commits on top of Stage 3's history (one per subtask); new test files exist; test run passes cleanly. If tests fail, document; the Engineer's code quality is not Stage 4's primary concern (Stage 3 validated those skills), but a failure suggests the orchestration produced poorly-scoped subtask descriptions — worth noting.

---

## Task 14: Evidence consolidation + Stage 4 results doc

**Files:** Creates `/Users/henrique/custom-skills/paperclipowers/docs/plans/2026-04-14-stage-4-results.md`. Reads `~/.paperclipowers-stage4-*.{json,txt}` snapshots captured across Tasks 11-13.

**Context:** Mirror the Stage 2/3 results structure: captured identifiers, per-rule behavioural evidence, heartbeat cost summary, cross-heartbeat observations, numbered anomalies, follow-ups for Stage 5. Do not fabricate — every number/SHA/ID in the doc must trace back to a local snapshot file.

- [ ] **Step 1: Full-file CLI-ism regression check across all paperclipowers skills**

Re-run the Stage 3 § "CLI-ism grep on the four paperclipowers skills" check, now extended to five skills (the four Engineer + task-orchestration):

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  RUNTIME=/paperclip/instances/default/skills/$COMPANY_ID/__runtime__
  for dir in \"\$RUNTIME\"/*/; do
    name=\$(basename \"\$dir\")
    echo \"=== \$name ===\"
    grep -rE \"your human partner|in this message|ask the user|TodoWrite|Task\(|git worktree\" \"\$dir\" --include=\"SKILL.md\" --include=\"*.md\" 2>/dev/null \
      | grep -v UPSTREAM.md \
      || echo \"  (clean)\"
  done
'" | tee ~/.paperclipowers-stage4-cli-ism-check.txt
```

Expected: `(clean)` for all five paperclipowers skill directories. Paperclip-bundled skills (the four `paperclipai/paperclip/*`) may have CLI-isms — expected and not our concern.

- [ ] **Step 2: Materialization inventory**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  RUNTIME=/paperclip/instances/default/skills/$COMPANY_ID/__runtime__
  for slug in verification-before-completion test-driven-development systematic-debugging code-review task-orchestration; do
    for dir in \"\$RUNTIME\"/\"\$slug\"--*; do
      name=\$(basename \"\$dir\")
      count=\$(find \"\$dir\" -type f | wc -l)
      echo \"\$name: \$count files\"
    done
  done
'" | tee ~/.paperclipowers-stage4-materialization.txt
```

Expected counts:
- verification-before-completion: 2 files
- test-driven-development: 3 files
- systematic-debugging: 7 files
- code-review: 3 files
- task-orchestration: 5 files (SKILL.md + three templates + UPSTREAM.md)

- [ ] **Step 3: Cost summary**

```bash
# Collect all Stage 4 run JSONs
for f in ~/.paperclipowers-stage4-run-*.json; do
  [ -f "$f" ] && jq '{id, status, durationMs: (((.finishedAt | fromdateiso8601) - (.startedAt | fromdateiso8601)) * 1000 | floor), cachedIn: .usageJson.cachedInputTokens, freshIn: .usageJson.inputTokens, out: .usageJson.outputTokens, wakeReason: .contextSnapshot.wakeReason, sessionIdAfter, freshSession: .usageJson.freshSession, sessionReused: .usageJson.sessionReused}' "$f"
done | jq -s . > ~/.paperclipowers-stage4-cost-summary.json
cat ~/.paperclipowers-stage4-cost-summary.json
```

Expected: 4-6 Tech Lead runs + 3 Engineer runs. Tech Lead's Run 1 cached_input should be in the 300-600k range (fresh session); subsequent Tech Lead runs should show `sessionReused: true` and similar cached tokens (they're resumed sessions within the same chain).

- [ ] **Step 4: Write the Stage 4 results doc**

Create `/Users/henrique/custom-skills/paperclipowers/docs/plans/2026-04-14-stage-4-results.md` with the structure below. Fill in each section from captured local snapshots. Do NOT fabricate — if a field was not captured, write "not captured" and log a follow-up. Follow Stage 2/3 results doc style for consistency.

Required sections, in order:

```markdown
# Stage 4 Validation Results

**Date completed:** 2026-04-14
**Outcome:** <SUCCESS | PARTIAL | FAILURE with reason>
**Tracking branch:** `paperclip-adaptation`
**Stage 4 commit range:** `<first-commit>..<last-commit>` (skill commit <sha>, results doc on top)
**Prior state:** Stage 3 commit `9514dbc`; four Engineer skills pinned at `78598d5`; agent `stage1-tester` paused; new Tech Lead agent to be created.

## Captured identifiers

| Field | Value |
|-------|-------|
| Tech Lead agent | `stage4-tech-lead` — `<TECH_LEAD_AGENT_ID>` |
| task-orchestration skill key | `henriquerferrer/paperclipowers/task-orchestration` |
| task-orchestration pin SHA | `<STAGE4_PIN_SHA>` |
| Parent issue | `PAP-<N>` — `<STAGE4_PARENT_ISSUE>` |
| Subtask 1 (init) | `PAP-<N+1>` — `<STAGE4_SUB_1>` |
| Subtask 2 (note) | `PAP-<N+2>` — `<STAGE4_SUB_2>` |
| Subtask 3 (last) | `PAP-<N+3>` — `<STAGE4_SUB_3>` |
| Tech Lead Run 1 (first heartbeat) | `<STAGE4_RUN_TECH_LEAD_1>` |
| Engineer Run 1 (subtask 1) | `<STAGE4_RUN_ENG_1>` |
| Tech Lead Run 2 (subtask 1 mention) | `<STAGE4_RUN_TECH_LEAD_2>` |
| Engineer Run 2 (subtask 2) | `<STAGE4_RUN_ENG_2>` |
| Tech Lead Run 3 (paused-target trap) | `<STAGE4_RUN_TECH_LEAD_3_PAUSED>` |
| Tech Lead Run 4 (revival) | `<STAGE4_RUN_TECH_LEAD_4_REVIVED>` |
| Engineer Run 3 (subtask 3) | `<STAGE4_RUN_ENG_3>` |

## Rule-by-rule verification

### RULE 1 — Progressive assignment unconditional

- Subtask 1 assigned at creation: <yes/no>, assigneeAgentId = `<value>`
- Subtask 2 null at creation: <yes/no>
- Subtask 3 null at creation: <yes/no>
- blockedByIssueIds chain correct: <yes/no, with edges listed>

Verdict: <PASS / FAIL>

### RULE 2 — Pre-PATCH paused-target check

- GET agent check issued before PATCH (evidence in run events): <yes/no, quote>
- Paused-target trap outcome (A/B/C per Task 13 Step 3): <A | B | C>
- If A: escalation comment quote + subtask 3 status set to <value>
- If B: PATCH fired despite paused target; wake dropped: <yes/no>
- If C: race missed; fallback retry <succeeded / missed again>

Verdict: <PASS / FAIL / NOT OBSERVED>

### RULE 3 — Notification Protocol embedded in every subtask

- Subtask 1 description has Notification Protocol section: <yes/no>
- Subtask 2: <yes/no>
- Subtask 3: <yes/no>
- Engineer followed the protocol on completion (posted @stage4-tech-lead DONE mention): <yes/no per subtask>

Verdict: <PASS / FAIL>

## Heartbeat cost summary

| Run | Agent | Subtask | Wake reason | Duration | Cached in | Fresh in | Out | SessionIdAfter | SessionReused |
|-----|-------|---------|-------------|----------|-----------|----------|-----|----------------|---------------|
| TL-1 | tech-lead | parent | issue_assigned | <ms> | <n> | <n> | <n> | `<sha>` | false |
| ENG-1 | engineer | sub-1 | issue_assigned | <ms> | <n> | <n> | <n> | `<sha>` | false |
| TL-2 | tech-lead | sub-1 | issue_comment_mentioned | <ms> | <n> | <n> | <n> | `<sha>` | true |
| ENG-2 | engineer | sub-2 | issue_assigned | <ms> | <n> | <n> | <n> | `<sha>` | false |
| TL-3 (paused trap) | tech-lead | sub-2 | issue_comment_mentioned | <ms> | <n> | <n> | <n> | `<sha>` | <true/false> |
| TL-4 (revived) | tech-lead | <where> | <reason> | <ms> | <n> | <n> | <n> | `<sha>` | <> |
| ENG-3 | engineer | sub-3 | issue_assigned | <ms> | <n> | <n> | <n> | `<sha>` | false |

**Totals:** <wall-clock sum>, <dollar cost sum from .usageJson.costUsd>, <token totals>. Model: `claude-opus-4-6[1m]` across all runs.

**Comparison vs Stage 3 per-heartbeat baselines:** <observations>. Tech Lead's first-wake cached_input is expected to be higher than an Engineer's because task-orchestration is a new skill being loaded alongside the four Paperclip-bundled skills. <state actual>.

## Cross-heartbeat observations

- Tech Lead fresh-session on first wake: <yes/no, sessionIdBefore null: <yes/no>>
- Tech Lead session resumption on subsequent mention wakes: <yes/no, sessionId chain>
- Engineer fresh-session on each subtask (progressive-assignment regression check vs Stage 3): <yes/no per subtask>
- Tech Lead performed GET /api/agents/<eng> before every PATCH assignee: <yes/no, count of probes vs PATCHes>
- Notification Protocol mentions fired `issue_comment_mentioned` wakes correctly: <yes/no>
- Any skill misfires (TDD skipped, self-mention loops, mishandled NEEDS_CONTEXT): <list>
- Workspace state at the end (git log head vs Stage 3 baseline): <delta>

## Anomalies / notes for Stage 5

(follow Stage 2/3 results' numbered anomaly format — list concrete issues and each's implication for Stage 5)

## Rollback state after Task 15

- Tech Lead agent status: <paused / idle / deleted>
- Engineer agent status: <paused / idle>
- Skills imported: 5 paperclipowers skills pinned (4 Engineer at `78598d5`, 1 task-orchestration at `<STAGE4_PIN_SHA>`)
- Issues left: `PAP-1` through `PAP-<final>`, parent in_review, subtasks all done (or whatever state was reached)
- Workspace git state: `<n>` new commits on top of Stage 3's three
- Local env file `~/.paperclipowers-stage4.env`: <kept / removed>
- Ready for Stage 5: <yes/no, why>

## Follow-ups unblocked by Stage 4

- (list — likely to include: "Reviewer agent hire", "writing-plans skill adaptation", "pipeline-dispatcher skill", "sessionPolicy per-agent flag post-Stage-5", and any skill language that needs sharpening based on observed Tech Lead behaviour)
```

- [ ] **Step 5: Verify the results doc is internally consistent**

Open the doc; spot-check that every UUID/SHA/number in the tables matches a value in a local `~/.paperclipowers-stage4-*.{json,txt}` snapshot. If any value is unknown, write "not captured" explicitly — do not leave a raw `<placeholder>`.

---

## Task 15: Rollback for Stage 5 reuse

**Files:** No local files. Paperclip API + git push.

**Context:** Leave state reusable for Stage 5. Stage 5 will reuse this company, the Tech Lead agent, the Engineer agent, and all imported skills. It adds PM, Quality Reviewer, Designer, final Code Reviewer agents (per spec §3.1 / §8) and the associated skills. Stage 4 does NOT delete anything.

- [ ] **Step 1: Pause the Tech Lead agent**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$TECH_LEAD_AGENT_ID/pause" \
  | jq '{id, status}'
```

Expected: `status: "paused"`.

- [ ] **Step 2: Ensure the Engineer is paused (same as Stage 3 rollback)**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" | jq '.status'
```

If not `"paused"`:
```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/pause" \
  | jq '{id, status}'
```

- [ ] **Step 3: Confirm no in-progress runs across both agents**

```bash
for A in "$TECH_LEAD_AGENT_ID" "$AGENT_ID"; do
  curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$A&limit=3" \
    | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason}]'
  echo "---"
done
```

Expected: all runs terminal. If any `running`/`queued`, wait; pause should have cancelled them.

- [ ] **Step 4: Commit the Stage 4 results doc**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add docs/plans/2026-04-14-stage-4-results.md
git commit -m "docs(paperclipowers): Stage 4 validation results

Captures task-orchestration skill behaviour end-to-end: subtask graph
creation from a hand-authored plan, progressive-assignment emission across
three subtasks, paused-target trap outcome, end-of-feature PATCH-to-in_review.
Records anomalies for Stage 5."
git push origin paperclip-adaptation
```

Expected: clean push.

- [ ] **Step 5: Keep the Stage 4 env file around**

```bash
ls -la ~/.paperclipowers-stage4.env
```

Expected: mode 600, contains Stage 2/3 identifiers + all Stage 4 captured vars. Stage 5 will source it. If unused for weeks, the cookie will go stale — refresh as needed.

- [ ] **Step 6: Final readiness check**

```bash
source ~/.paperclipowers-stage4.env
for A in "$TECH_LEAD_AGENT_ID" "$AGENT_ID"; do
  curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/agents/$A" \
    | jq '{name, status, desiredSkillsCount: (.adapterConfig.paperclipSkillSync.desiredSkills | length)}'
done

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.key | test("henriquerferrer/paperclipowers/")) | {key, sourceRef}] | sort_by(.key)'
```

Expected:
- `stage4-tech-lead`: `status: "paused"`, skills count 5
- `stage1-tester`: `status: "paused"`, skills count 8
- Five paperclipowers skills in the company library (four at `78598d5`, one at `STAGE4_PIN_SHA`)

Stage 5 starts from this end-state.

---

## Self-review checklist (for the executor)

After running Task 15, before declaring Stage 4 complete:

1. **Spec coverage:** Every item in the "Architecture" and "Goal" paragraphs is reflected in at least one task. Three rules, progressive assignment, paused-target trap, @mention wake, fresh results doc — all present.
2. **No placeholders:** Every `<…>` in Task 14's results-doc template is replaced with a real value or an explicit "not captured".
3. **Type consistency:** `TECH_LEAD_AGENT_ID`, `STAGE4_SUB_1`, `STAGE4_SUB_2`, `STAGE4_SUB_3`, `STAGE4_PARENT_ISSUE`, and all `STAGE4_RUN_*` identifiers are used identically everywhere (not renamed between tasks).
4. **Evidence > assertion:** Every verdict in the results doc is backed by a cited snapshot file or API response. No unsupported "it worked" claims.
5. **Scope respected:** No changes to the four frozen Engineer skills (grep `skills-paperclip/{verification-before-completion,test-driven-development,systematic-debugging,code-review}/` — unchanged since `78598d5`). No changes to `server/src/**`. No new agents besides `stage4-tech-lead`.

If any check fails, fix it before considering Stage 4 complete.
