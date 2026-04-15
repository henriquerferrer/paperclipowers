# Stage 5 — Full Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the full paperclipowers pipeline online end-to-end. Adapt three upstream skills (`brainstorming` → PM, `writing-plans` → Tech Lead's second skill, `using-superpowers` → new `pipeline-dispatcher` for every role), hire two new agents (PM at `role: "pm"`, Reviewer at `role: "qa"`), update the two existing agents' skill sets, then run a small real feature request through all four roles (PM → Tech Lead → Engineer → Reviewer) with approval gates at the spec, plan, and final-combined-review touchpoints. Designer deferred to Stage 6 but structurally hooked (per-slice `needsDesignPolish: boolean` flag in the plan schema, Stage 5 hardcodes `false`).

**Architecture:** Three skill authorings plus two agent hires plus a behavioural validation pass. `brainstorming/SKILL.md` is a heavy rewrite: the CLI one-question-at-a-time dialog becomes batched comment Q&A (2-3 questions per heartbeat), the design-approval step writes the spec to `PUT /api/issues/:id/documents/spec` and transitions the issue to `status: in_review` + reassigns to the Reviewer, and the ~280 lines of Visual Companion guidance are dropped (no browser in the Docker container). `writing-plans/SKILL.md` rewrites the upstream engineer-oriented plan format into a Tech Lead contract: concrete TypeScript/JSON schemas per slice (spec §2.2), per-slice `needsDesignPolish` flag (Stage 6 hook), dependency edges expressed as `blockedByIssueIds` candidates, plan written to `PUT /api/issues/:id/documents/plan` (auto-populates top-level `.planDocument` on the issue), approval gate via status+assignee PATCH, on approval hands off to `task-orchestration`. `pipeline-dispatcher/SKILL.md` is a greenfield skill replacing `using-superpowers`: per-role skill routing in the heartbeat model (no Skill tool invocation, no `TodoWrite`, no `Task()` dispatch — skills are already injected into the system prompt by the adapter; the dispatcher tells each role WHICH of its injected skills applies given the current `wakeReason` + issue state).

Approval gates throughout the pipeline use `status: in_review` + assignee PATCH, not `POST /api/approvals` — confirmed live at plan-write time: `APPROVAL_TYPES = ["hire_agent", "approve_ceo_strategy", "budget_override_required"]` at `/app/packages/shared/src/constants.ts:203`. No spec/plan approval type exists and adding one would require Paperclip server changes (out of scope per design spec §10). The spec §5.2 wording is therefore amended in Task 2 of this plan so that implementation can follow the actual API.

The single Reviewer role (`role: "qa"`) handles all three review artifacts — spec review, plan review, final combined diff — via the Stage 2-adapted `code-review` skill's four-trigger structure (already consolidated in Stage 2 results). The same Reviewer agent wakes fresh on each triggering issue (per-issue session keying, confirmed at `/app/server/src/services/heartbeat.ts:693-716` and the Stage 4 Anomaly 4 analysis in this plan's header), so "fresh context" is preserved without needing two separate reviewer agents.

Behavioural validation reuses the throwaway `Paperclipowers Test` company, both existing agents (`stage1-tester` Engineer, `stage4-tech-lead` Tech Lead — both paused at Stage 4 end), and the Engineer's workspace with its Stage 3/4 git history. Stage 5 adds two net-new agents, five net-new or updated issues, and a small feature chosen to exercise every pipeline phase without running up token cost (target: a CLI command that extends the `workspace-log` or `task-counter` utilities Stage 3/4 established). The plan includes explicit observation steps per phase so Stage 5 results are reproducible.

**Tech Stack:**
- `git` + GitHub (fork: `henriquerferrer/paperclipowers`, branch `paperclip-adaptation` — currently at `d08f1f9` which is Stage 4 plan; two commits since last Stage 4 push: `17df7271` (skill) and `b7e6587` (Stage 4 results doc), `d08f1f9` (Stage 4 plan doc))
- Paperclip HTTP API at `http://192.168.0.104:3100` (LAN-only; `authenticated` mode, session cookie + matching `Origin:` header required on mutations)
- `curl` + `jq` for API calls; `ssh nas` + `docker exec paperclip ...` for container inspection
- **JSON payloads:** `Write` tool to place file on disk with `\n` escape sequences inside string values, then `curl --data-binary @file`. Do NOT use zsh `echo ... > file` (mangles `\n`) or `curl -d @file` (form-url-encoded semantics). Stage 3 Anomaly 2 + Stage 4 Anomaly 5.
- Upstream reference: `/Users/henrique/custom-skills/paperclipowers/skills/` (synced from obra/superpowers v5.0.7). DO NOT edit; read-only for porting.

**Scope boundaries (what this plan does NOT do):**
- Does NOT hire a Designer agent, import `ui-ux-pro-max`, or configure Magic/Figma MCP. All of these are Stage 6 per design spec §8. Stage 5 leaves a hook in `writing-plans`: every slice in the generated plan carries a boolean `needsDesignPolish`, hardcoded `false` by the PM/Tech Lead in Stage 5 output, read but unused by `task-orchestration` until Stage 6 flips it live.
- Does NOT touch Paperclip server code. No changes to wake logic, session reset policy, the approval table/types, or any route. If Stage 5 validation surfaces a server bug (e.g., mention-wake session keying confuses per-issue vs per-agent sessions in unexpected ways), the fix lives in a future upstream contribution, not here.
- Does NOT introduce the `sessionPolicy` per-agent flag (post-Stage-5 follow-up carried from Stage 3 + Stage 4).
- Does NOT add a new approval type for spec/plan approval. Amending the Paperclip approval enum would require a database migration + middleware change; out of scope. Spec §5.2 amendment in Task 2 documents the workaround (status+assignee PATCH).
- Does NOT remove Stage 1-4 artifacts from the test company. Prior issues (`PAP-1..PAP-17`) and the Engineer's task-counter/workspace-log git history stay as evidence. Stage 5 issues start at `PAP-18` or higher.
- Does NOT promote any paperclipowers skill to a real (non-throwaway) company. Stage 7 handles that.
- Does NOT attempt to fix Stage 4 Anomaly 4 server-side. The per-issue session keying is documented in the spec §5.4 amendment (Task 2) as the actual server behaviour; cost budget treats cross-issue mention wakes as fresh sessions.

**Reference documents (read before executing this plan):**
- Design spec: `docs/specs/2026-04-13-paperclipowers-design.md` — especially §3 (6 roles), §5 (adaptation rules), §8 (stages). §5.2 will be amended in Task 2; §5.4 amended in Task 2.
- Stage 4 plan (structural template for this one): `docs/plans/2026-04-14-stage-4-tech-lead-task-orchestration.md`
- Stage 4 results (6 anomalies this plan must handle): `docs/plans/2026-04-14-stage-4-results.md`
- Stage 3 results (Anomalies 1-6 still in force): `docs/plans/2026-04-13-stage-3-results.md`
- Stage 2 results (Reviewer-role consolidation decision): `docs/plans/2026-04-13-stage-2-results.md`
- Stage 4 task-orchestration skill: `skills-paperclip/task-orchestration/SKILL.md` — especially § First Wake (plan reading), § Subtask Description Template (the dormant review templates Stage 5 activates)
- Stage 2 code-review skill: `skills-paperclip/code-review/SKILL.md` — four triggers already encoded; Stage 5 only activates them
- Upstream sources (read during Task 4-6, adapted inline):
  - `skills/brainstorming/SKILL.md` (164 lines)
  - `skills/brainstorming/spec-document-reviewer-prompt.md` (49 lines — concept-only, not ported; Reviewer uses `code-review/reviewer-prompt.md`)
  - `skills/brainstorming/visual-companion.md` (287 lines — dropped entirely; no browser in container)
  - `skills/writing-plans/SKILL.md` (152 lines)
  - `skills/writing-plans/plan-document-reviewer-prompt.md` (49 lines — concept-only, not ported)
  - `skills/using-superpowers/SKILL.md` (117 lines — replaced wholesale by `pipeline-dispatcher`, not a substitution port)

**Paperclip server mechanics verified at plan-write time (frozen for this plan; if Paperclip upgrades and these drift, amend the plan before executing):**
- `/app/server/src/services/heartbeat.ts:693-716` — `shouldResetTaskSessionForWake` + `describeSessionResetReason`. Session reset fires on POSITIVE conditions: `forceFreshSession === true` OR `wakeReason === "issue_assigned"`. Everything else preserves session at the heartbeat layer. **BUT**: `deriveTaskKey` (same file, lines ~660-680) keys sessions by `contextSnapshot.issueId`, so a mention on a DIFFERENT issue than the agent's last session finds no prior sessionId in the per-issue `agentTaskSessions` table → `freshSession: true` even though the reset path didn't fire. This is per-issue session isolation, not a bug. Stage 4 Anomaly 4 explained by this design, not a regression.
- `/app/server/src/routes/issues.ts` — `issue_assigned` wake fires on assignee PATCH when the value changes; `issue_comment_mentioned` fires on each mention comment resolved by `findMentionedAgents(companyId, body)`; `issue_children_completed` fires ONLY when all children terminal (unchanged from Stage 4).
- `/app/packages/shared/src/constants.ts:203` — `APPROVAL_TYPES = ["hire_agent", "approve_ceo_strategy", "budget_override_required"]`. Confirmed no spec/plan approval type exists.
- `/app/packages/shared/src/validators/approval.ts` — `createApprovalSchema` requires `type ∈ APPROVAL_TYPES`. Confirmed no way to create a spec/plan approval through the public API.

**Live API path freeze (sampled 2026-04-14 during plan write):**

| Purpose | Endpoint + path |
|---|---|
| Company basics | `GET /api/companies/:id` → `.id`, `.name`, `.issuePrefix`, `.issueCounter` (currently 17), `.requireBoardApprovalForNewAgents` |
| Company agents list | `GET /api/companies/:id/agents` → array; each agent has `.adapterConfig.paperclipSkillSync.desiredSkills: [keys]` (NOT top-level `desiredSkills`) |
| Company skills list | `GET /api/companies/:id/skills` → each has `.key`, `.slug`, `.sourceRef`, `.attachedAgentCount` |
| Company approvals | `GET /api/companies/:id/approvals?status=pending` → list; `POST /api/companies/:id/approvals` creates approvals of one of three types only (hire_agent, approve_ceo_strategy, budget_override_required). **NOT usable for spec/plan approval.** |
| Approval detail | `GET /api/approvals/:id` → full approval; `POST /api/approvals/:id/approve` + `POST /api/approvals/:id/reject` + `POST /api/approvals/:id/request-revision` are decision endpoints |
| Agent detail | `GET /api/agents/:id` → `.id`, `.name`, `.role`, `.status`, `.adapterType`, `.adapterConfig.paperclipSkillSync.desiredSkills`, `.pausedAt` |
| Agent skills view | `GET /api/agents/:id/skills` → `{ supported, mode, desiredSkills, entries: [{ key, runtimeName, desired, managed, state, sourcePath }] }` |
| Agent role enum (LIVE PROBE at plan-write) | Allowed: `ceo`, `cto`, `cmo`, `cfo`, `engineer`, `designer`, `pm`, `qa`, `devops`, `researcher`, `general`. **PM → `pm` ✓; Reviewer → `qa` (closest match; `reviewer` is NOT a valid enum value); Tech Lead stays `engineer` (Stage 4 fallback; `tech_lead` NOT valid).** |
| Create agent | `POST /api/companies/:id/agents` with `{ name, role, adapterType: "claude_local", adapterConfig: { paperclipSkillSync: { desiredSkills: [keys] } } }`. When board is the actor (cookie auth), returns `status: "idle"` immediately — `requireBoardApprovalForNewAgents: true` only gates agent-created-by-agent hires. |
| Delete agent | `DELETE /api/agents/:id` → `{ ok: true }` |
| Pause/resume agent | `POST /api/agents/:id/pause` / `POST /api/agents/:id/resume` → `{ id, status }` |
| Wakeup agent | `POST /api/agents/:id/wakeup` with optional `{ forceFreshSession, wakeReason, issueId }` → 403 if `paused` |
| Create issue | `POST /api/companies/:id/issues` with `{ title, description, parentId?, assigneeAgentId?, blockedByIssueIds?, status? }` → returns full issue incl. `.identifier` |
| Issue detail | `GET /api/issues/:id` → top-level `.planDocument` (full body inline when a doc with `key: "plan"` exists; null otherwise), `.documentSummaries: [{ key, title, latestRevisionId, ... }]` (no body), `.blockedBy: [...]`, `.blocks: [...]`, `.parentId`, `.status`, `.assigneeAgentId`, `.description` |
| PUT document on issue | `PUT /api/issues/:id/documents/:key` with `{ format: "markdown", body, title }` → returns full doc incl. `.latestRevisionId`. Required fields on PUT: `format`, `body`. Title optional but recommended. Confirmed live: **key `"plan"` auto-populates the top-level `.planDocument` on the issue; other keys (e.g. `"spec"`) appear only in `.documentSummaries[]`.** |
| List documents on issue | `GET /api/issues/:id/documents` → array with body inlined |
| Delete document | `DELETE /api/issues/:id/documents/:key` → `{ ok: true }` |
| List children | `GET /api/companies/:id/issues?parentId=:uuid&limit=N` |
| PATCH issue | `PATCH /api/issues/:id` with combinations of `{ assigneeAgentId, status, parentId, blockedByIssueIds, priority, ... }`. **Stage 4 Anomaly 1: combine `assigneeAgentId + status: "todo"` in one PATCH when assigning a backlog parent — assignment alone on a `status: "backlog"` issue does NOT fire `issue_assigned`.** |
| Heartbeat runs | `GET /api/companies/:id/heartbeat-runs?agentId=:uuid&limit=N` → `.id, .status, .startedAt, .finishedAt, .sessionIdBefore, .sessionIdAfter, .contextSnapshot.{wakeReason,source,issueId,...}, .usageJson.{cachedInputTokens,inputTokens,outputTokens,freshSession,sessionReused,model,costUsd}, .resultJson.{result,total_cost_usd}` |
| Issue comments | `GET /api/issues/:id/comments?limit=N` / `POST /api/issues/:id/comments` with `{ body }`. `@agent-name` mentions in `body` wake mentioned agents with `reason: "issue_comment_mentioned"` (Stage 4 RULE 3). |
| Skill library import | `POST /api/companies/:id/skills/import` with the URL-import shape (Stage 2 Task 7 payload, reused). **Use the parent-directory URL `…/tree/paperclip-adaptation/skills-paperclip` per Stage 2 Anomaly 2**, NOT per-skill subdirectories. |
| Skill delete from library | `DELETE /api/companies/:id/skills/:skillId` → `{ ok: true }` (auto-prunes agent assignments) |

If the executor finds any of these paths wrong at runtime, stop and fix the plan — do not paper over drift by guessing the new shape.

**Captured identifiers reused from Stage 1-4:**
- `PAPERCLIP_API_URL="http://192.168.0.104:3100"` (LAN-only)
- `COMPANY_ID="02de212f-0ec4-4440-ac2f-0eb58cb2b2ad"` — `Paperclipowers Test`, `issuePrefix: "PAP"`, current `issueCounter: 17`
- `ENGINEER_AGENT_ID="cb7711f4-c785-491d-a21a-186b07d445e7"` — `stage1-tester`, `role: "engineer"`, currently paused. Four Engineer skills in desiredSkills; Task 11 adds `pipeline-dispatcher`.
- `TECH_LEAD_AGENT_ID="416f7693-e5e2-49f2-9c9d-5f645c8a476f"` — `stage4-tech-lead`, `role: "engineer"` (no `tech_lead` enum), currently paused. One skill (`task-orchestration`) in desiredSkills; Task 11 adds `writing-plans` + `pipeline-dispatcher`.
- `WORKSPACE_CWD_ENGINEER="/paperclip/instances/default/workspaces/cb7711f4-c785-491d-a21a-186b07d445e7"` — Engineer's workspace, has Stage 3 task-counter + Stage 4 workspace-log git history.
- Five paperclipowers skills in the company library, all at `sourceRef: "17df7271cd41be5e093dd4f72d14baaefc385f18"` (Stage 4 end). Byte-identical content since `78598d5` for the four Engineer skills per Stage 4 Anomaly 4.

**New identifiers this plan creates (captured as env vars during execution):**
- `PM_AGENT_ID` — `stage5-pm` UUID (Task 9)
- `REVIEWER_AGENT_ID` — `stage5-reviewer` UUID (Task 10)
- `BRAINSTORMING_SKILL_KEY="henriquerferrer/paperclipowers/brainstorming"` (Task 8)
- `WRITING_PLANS_SKILL_KEY="henriquerferrer/paperclipowers/writing-plans"` (Task 8)
- `DISPATCHER_SKILL_KEY="henriquerferrer/paperclipowers/pipeline-dispatcher"` (Task 8)
- `STAGE5_PIN_SHA` — commit SHA of the Stage 5 skill commit on `paperclip-adaptation` (captured in Task 8)
- `STAGE5_PARENT_ISSUE` — the feature-request parent the board creates in Task 13
- `STAGE5_SPEC_REVIEW_RUN`, `STAGE5_PLAN_REVIEW_RUN`, `STAGE5_FINAL_REVIEW_RUN` — heartbeat run IDs for the three Reviewer triggers (Task 14)
- `STAGE5_SUB_1..N` — subtask IDs the Tech Lead creates in the orchestration phase (Task 14)
- Each heartbeat run ID captured inline as it appears, numbered by phase (`_PM_1`, `_PM_2`, `_TL_PLAN_1`, `_ENG_1`, etc.)

**File structure (all paths relative to `/Users/henrique/custom-skills/paperclipowers/`):**

```
skills-paperclip/
├── _shared/                                 (populated in Task 3 — currently empty)
│   ├── heartbeat-interaction.md             (NEW — comment Q&A, exit heartbeat, resume)
│   └── paperclip-conventions.md             (NEW — status+assignee approval gate, self-mention avoidance)
├── brainstorming/                            (NEW — Task 4)
│   ├── SKILL.md                             (heavy rewrite of upstream; ~220 lines)
│   └── UPSTREAM.md                          (provenance + merger map)
├── writing-plans/                            (NEW — Task 5)
│   ├── SKILL.md                             (heavy rewrite; concrete schemas + planDocument write + approval gate; ~280 lines)
│   └── UPSTREAM.md
├── pipeline-dispatcher/                      (NEW — Task 6)
│   ├── SKILL.md                             (greenfield; per-role skill routing in heartbeat model; ~180 lines)
│   └── UPSTREAM.md                          (derivative provenance against using-superpowers)
├── task-orchestration/                       (UPDATED — Task 7)
│   └── SKILL.md                             (remove "falls back to .description" branch — plan now always in .planDocument)
└── [existing skills unchanged: code-review, systematic-debugging, test-driven-development, verification-before-completion]

docs/
├── specs/
│   └── 2026-04-13-paperclipowers-design.md  (AMENDED in Task 2 — §5.2 approval gate, §5.4 session keying, §8 Stage 5 scope)
└── plans/
    ├── 2026-04-14-stage-5-pipeline.md       (this file)
    └── 2026-04-14-stage-5-results.md        (NEW — written in Task 15)
```

`scripts/check-upstream-drift.sh` auto-discovers any `skills-paperclip/*/UPSTREAM.md` — the three new UPSTREAM.md files integrate automatically if their frontmatter matches the existing format.

**Local harness env file to create in Task 1:** `~/.paperclipowers-stage5.env` (local only, not committed; mode 600). Copied from `~/.paperclipowers-stage4.env` at Task 1 Step 6, then appended to throughout.

---

## Task 1: Re-acquire auth, verify Stage 4 end-state, re-sample live API

**Files:** Read-only: `docs/plans/2026-04-14-stage-4-results.md`. Creates: `~/.paperclipowers-stage5.env`.

**Context:** Stage 4 left the company with 2 agents (both paused), 5 skills imported at `17df7271`, issues PAP-1..PAP-17 all terminal (PAP-14 `in_review`, rest `done`). The Stage 4 env file at `~/.paperclipowers-stage4.env` is the source of truth for cookie + IDs. Re-auth if the cookie has gone stale. Re-sample the six live-API fields Stage 4 captured so this plan's header table is trustworthy at execution time (Stage 3 Anomaly 3: jq paths drift between stages).

- [ ] **Step 1: Verify NAS reachability and container health**

```bash
curl -sfS http://192.168.0.104:3100/api/health | jq .
```

Expected: `{"status":"ok","version":"0.3.1","deploymentMode":"authenticated","deploymentExposure":"private","authReady":true,"bootstrapStatus":"ready","bootstrapInviteActive":false,"features":{"companyDeletionEnabled":false}}`. If the request fails:

```bash
ssh nas "/usr/local/bin/docker ps --format '{{.Names}} {{.Status}}' | grep paperclip"
```

Expected: `paperclip Up ...` and `paperclip-db Up ...`. If either is missing, restart before proceeding.

- [ ] **Step 2: Source Stage 4 env file and test read auth**

```bash
source ~/.paperclipowers-stage4.env
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID" | jq '{id, name, issuePrefix, issueCounter}'
```

Expected:
```json
{"id":"02de212f-0ec4-4440-ac2f-0eb58cb2b2ad","name":"Paperclipowers Test","issuePrefix":"PAP","issueCounter":17}
```

`issueCounter` may have drifted higher if any test creation happened between Stage 4 and Stage 5 execution — note the actual value, don't expect exactly 17.

If 401: refresh cookie via browser DevTools (`better-auth.session_token` at `http://192.168.0.104:3100`), re-export, rerun.

- [ ] **Step 3: Verify both agents are paused and skill sets match Stage 4 end-state**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq '[.[] | {id, name, status, role, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills | length}]'
```

Expected:
```json
[
  {"id":"416f7693-e5e2-49f2-9c9d-5f645c8a476f","name":"stage4-tech-lead","status":"paused","role":"engineer","desiredSkills":5},
  {"id":"cb7711f4-c785-491d-a21a-186b07d445e7","name":"stage1-tester","status":"paused","role":"engineer","desiredSkills":8}
]
```

(Tech Lead: 4 bundled + `task-orchestration` = 5. Engineer: 4 bundled + 4 paperclipowers Engineer skills = 8.) If either agent is not paused, that's acceptable now — Task 13 pauses/resumes as part of the end-to-end test. If skill counts have drifted, STOP and reconcile.

- [ ] **Step 4: Verify skill library still has 5 paperclipowers skills pinned at `17df7271`**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.key | test("henriquerferrer/paperclipowers/")) | {key, slug, sourceRef}] | sort_by(.key)'
```

Expected: 5 entries, all `sourceRef: "17df7271cd41be5e093dd4f72d14baaefc385f18"`: `brainstorming`/`pipeline-dispatcher`/`writing-plans` NOT yet in library (Task 8 imports them). Four Engineer skills + `task-orchestration` = 5.

- [ ] **Step 5: Re-sample approvals endpoint shape (confirm Stage 5 plan-header assumption)**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/approvals?status=pending" | jq 'length'
```

Expected: `0` or a small number (most company approvals from Stages 1-4 resolved). The result isn't important — what matters is that this endpoint is live and the 404 from `/api/approvals` (Stage 5 plan-write probe) is confirmed as a mis-path. Now probe the create shape:

```bash
printf '{"type":"invalid_type","payload":{}}' > /tmp/approval-probe.json
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/approval-probe.json \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/approvals" | head -c 400
rm /tmp/approval-probe.json
```

Expected: 400 validation error listing allowed `options: ["hire_agent","approve_ceo_strategy","budget_override_required"]`. This confirms the spec §5.2 amendment in Task 2 is necessary (no `approve_spec` / `approve_plan` type available).

- [ ] **Step 6: Re-probe role enum allowed values**

```bash
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data '{"name":"stage5-enum-probe","role":"reviewer","adapterType":"claude_local"}' \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" | jq '.details[0].options // .error'
```

Expected: `["ceo","cto","cmo","cfo","engineer","designer","pm","qa","devops","researcher","general"]`. Confirms `reviewer` is NOT a valid role and `pm` + `qa` + `engineer` are, matching the plan header. If the enum has changed (new roles added, existing ones removed), amend Tasks 9-10 accordingly before proceeding.

No probe agent to clean up — the 400 response didn't create one.

- [ ] **Step 7: Persist Stage 5 env file**

```bash
cp ~/.paperclipowers-stage4.env ~/.paperclipowers-stage5.env
chmod 600 ~/.paperclipowers-stage5.env
cat >> ~/.paperclipowers-stage5.env <<'EOF'
# --- Stage 5 additions below ---
EOF
ls -la ~/.paperclipowers-stage5.env
```

Expected: file exists, mode `-rw-------`. All subsequent steps source this, not stage4.

- [ ] **Step 8: Verify local git worktree clean and on `paperclip-adaptation`**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git status --porcelain=v1 -b
git log --oneline -5
```

Expected: branch `paperclip-adaptation`, clean tree, most-recent commit `d08f1f9 docs(paperclipowers): commit Stage 4 implementation plan` (Stage 4 closing commit). If commits have landed since, `git pull --ff-only origin paperclip-adaptation`. If uncommitted changes exist, stash before proceeding.

- [ ] **Step 9: Append Stage 4 identifiers + re-export all skill keys to Stage 5 env (hygiene)**

The Stage 4 env file has the five skill keys defined (`REVIEW_SKILL_KEY`, `TASK_ORCH_SKILL_KEY`, `TDD_SKILL_KEY`, `VBC_SKILL_KEY`, `DEBUG_SKILL_KEY`) but with duplicates across stages — last-wins gives correct values today but is fragile. Re-export canonical values explicitly so downstream tasks (9-11) never depend on which copy was sourced last. Verified at plan-write that these exact values resolve from a fresh bash source of the Stage 4 env.

```bash
cat >> ~/.paperclipowers-stage5.env <<'EOF'
# Stage 5 canonical re-exports (hygiene — insulates from env-file duplicates)
export ENGINEER_AGENT_ID="cb7711f4-c785-491d-a21a-186b07d445e7"
export TECH_LEAD_AGENT_ID="416f7693-e5e2-49f2-9c9d-5f645c8a476f"
export WORKSPACE_CWD_ENGINEER="/paperclip/instances/default/workspaces/cb7711f4-c785-491d-a21a-186b07d445e7"
export STAGE4_PIN_SHA="17df7271cd41be5e093dd4f72d14baaefc385f18"
export VBC_SKILL_KEY="henriquerferrer/paperclipowers/verification-before-completion"
export TDD_SKILL_KEY="henriquerferrer/paperclipowers/test-driven-development"
export DEBUG_SKILL_KEY="henriquerferrer/paperclipowers/systematic-debugging"
export REVIEW_SKILL_KEY="henriquerferrer/paperclipowers/code-review"
export TASK_ORCH_SKILL_KEY="henriquerferrer/paperclipowers/task-orchestration"
EOF
bash -c 'source ~/.paperclipowers-stage5.env; for v in ENGINEER_AGENT_ID TECH_LEAD_AGENT_ID STAGE4_PIN_SHA VBC_SKILL_KEY TDD_SKILL_KEY DEBUG_SKILL_KEY REVIEW_SKILL_KEY TASK_ORCH_SKILL_KEY; do printf "%-22s = %s\n" "$v" "${!v:-UNDEFINED}"; done'
```

Expected: 8 non-empty lines. If any shows `UNDEFINED`, the source of the env file failed partway — inspect manually before proceeding. (Use `bash -c '...'` as shown — zsh's indirect-expansion syntax `${!v}` doesn't work.)

---

## Task 2: Spec amendments (§5.2 approval gate, §5.4 session keying, §8 Stage 5 scope)

**Files:** Modify: `docs/specs/2026-04-13-paperclipowers-design.md`.

**Context:** Stage 5 execution depends on three spec statements that do not match Paperclip's current behaviour:

1. §5.2 step 2 says "Agent creates formal approval (`POST /api/approvals` with document reference)". Live-API probe in Stage 5 plan-write: `POST /api/companies/:id/approvals` only accepts types `hire_agent`, `approve_ceo_strategy`, `budget_override_required` (`/app/packages/shared/src/constants.ts:203`). There is no spec/plan approval type. The gate must use `status: in_review` + assignee reassignment instead.
2. §5.4 amendment (Stage 3) says "Paperclip's `issue_blockers_resolved` auto-wake preserves the conversation" within a subtask chain, and (by implication) mention wakes reuse session. Stage 4 Anomaly 4 proved this is wrong across DIFFERENT issue IDs: session is keyed per-issue in `agentTaskSessions`, so a mention on a subtask that the agent has not previously worked on is a fresh session even though `shouldResetTaskSessionForWake` returns false (server source: `/app/server/src/services/heartbeat.ts:693-716`).
3. §8 describes Stage 5 scope at a high level ("all 6 roles in test company"). Stage 2 results consolidated Quality Reviewer + Code Reviewer+QA to single Reviewer, and Stage 5 further narrows to PM + Reviewer hires only (Designer → Stage 6, hook-only integration in plan schema).

Amend the spec in place. Commit separately from the skill additions in Task 8 so the amendment is its own reviewable artifact.

- [ ] **Step 1: Amend §5.2 "Approval gate pattern"**

Replace the entire numbered list in §5.2 with:

```markdown
### 5.2 Approval gate pattern

When a skill requires human approval of a deliverable:

1. Agent writes deliverable to issue document:
   - Spec: `PUT /api/issues/{id}/documents/spec` with `{format: "markdown", body, title}`
   - Plan: `PUT /api/issues/{id}/documents/plan` (populates the top-level `.planDocument` field)
2. Agent `PATCH /api/issues/{id}` with a single payload: `{"status": "in_review", "assigneeAgentId": "<reviewer-agent-id>"}`. Both fields in one call — separate PATCHes can race the reassign wake.
3. Agent exits heartbeat.
4. Reviewer wakes on `issue_assigned` with a fresh session (per-issue session keying — §5.4), reads the document via `GET /api/issues/{id}/documents/{key}`, posts findings as a comment using the `code-review` skill's structured format.
5. Reviewer's last act on that heartbeat is a PATCH of its own:
   - Approval: `{"status": "todo", "assigneeAgentId": "<board-or-original-author-id>"}` + a comment `@<board> APPROVED` (the board's cookie-auth session is the final approver)
   - Rejection: `{"status": "todo", "assigneeAgentId": "<original-author-id>"}` + a findings comment. Original author (PM for spec, Tech Lead for plan) wakes on `issue_assigned`, reads findings, revises.
6. The board's role is minimal: when a Reviewer-approved artifact surfaces in the board's assigned queue, the board reads the artifact + Reviewer comment, then either PATCHes `{"status": "in_progress", "assigneeAgentId": "<next-role-id>"}` to proceed (next-role = Tech Lead after spec, or Engineer after plan) or comments a rejection and reassigns back to the original author.

**Note on Paperclip's approval table:** The `approvals` table + `POST /api/companies/:id/approvals` endpoint supports only three types — `hire_agent`, `approve_ceo_strategy`, `budget_override_required` (`packages/shared/src/constants.ts:203`). Adding a spec/plan approval type would require a server migration and is out of scope for Stage 5. The status+assignee PATCH above provides the same two-gate semantics using existing API surface. Raise an upstream feature request if first-class document approvals become important.
```

- [ ] **Step 2: Amend §5.4 "Context between agents" to describe per-issue session keying**

Replace the existing paragraph about `issue_blockers_resolved` auto-wake with:

```markdown
### 5.4 Context between agents

Agents share context through:

- **Issue description** — always visible
- **Comment thread** — full history visible
- **Issue documents** — `spec`, `plan` keys by convention; top-level `.planDocument` on the issue for plan content
- **Parent issue chain** — ancestor issues, goal, project
- **Git history** — what prior subtasks produced

Agents do NOT share memory across role handoffs. Claude sessions are keyed per-issue in `agentTaskSessions` (`server/src/services/heartbeat.ts` `deriveTaskKey`), and the session reset policy (`shouldResetTaskSessionForWake`, same file lines 693-716) only force-resets on two conditions: `forceFreshSession === true` in the wake context, or `wakeReason === "issue_assigned"`.

**Practical implication.** Each issue gets its own session slot for each agent:

- First heartbeat on issue I for agent A: `freshSession: true` (no prior session for (A, I)).
- Subsequent heartbeats on the SAME issue I for agent A, driven by wake reasons OTHER than `issue_assigned` (e.g. `issue_comment_mentioned`, `issue_status_changed`, `issue_commented`): session resumes from (A, I)'s stored sessionId.
- Heartbeats on a DIFFERENT issue J for agent A: fresh session for (A, J) regardless of wake reason, because the stored session is keyed by I, not by A alone.

This is why Stage 4 observed Tech Lead mention wakes as `freshSession: true` on different subtask issues (TL-2 on PAP-15, TL-3 on PAP-16, TL-4 on PAP-17 — three distinct issue keys, no shared session). Only TL-5 reused session because it fired on the parent PAP-14 (same issue as TL-1's session). Cost budget: treat per-subtask Tech Lead mention wakes as fresh sessions (same ~$0.2-0.3 range each as Stage 4 observed); expect session-resume savings only for agents that stay on one issue across many wakes (e.g., PM's Q&A rounds on one parent issue).

Progressive assignment (task-orchestration RULE 1) remains unchanged — progressive PATCH forces `issue_assigned` wake on the assignee, which clears their per-issue session for that subtask regardless of whether they had one before. The mechanism still works; the reason it works now includes both the reset-on-`issue_assigned` path AND the per-issue-key isolation.

A per-agent `sessionPolicy: forceFreshSession` flag that injects `forceFreshSession: true` into every wake payload — removing the need for progressive assignment on subtask chains — is tracked as a post-Stage 5 follow-up. Until then, `task-orchestration` (Stage 4) is responsible for progressive assignment on every subtask chain it produces.
```

- [ ] **Step 3: Amend §8 Stage 5 scope bullet**

Replace the Stage 5 line in §8 with:

```markdown
- **Stage 5 — Full pipeline test**: hire PM (`role: "pm"`) and Reviewer (`role: "qa"`; single consolidated Reviewer per Stage 2 results §Resolved architectural decisions); adapt `brainstorming`, `writing-plans`, author new `pipeline-dispatcher`; update Tech Lead + Engineer skill sets; run a small real feature end-to-end (PM brainstorm → Reviewer spec review → board approval → Tech Lead plan → Reviewer plan review → board approval → Tech Lead task-orchestration → Engineer subtasks → Reviewer final combined review → board merge); measure heartbeats, approvals, failure points. Designer deferred to Stage 6 — `writing-plans` emits a per-slice `needsDesignPolish: boolean` hook (Stage 5 hardcodes `false`; Stage 6 flips it live without skill changes). **Reviewer consolidation is load-bearing:** `code-review` skill's four triggers already encode spec/plan/per-subtask/final as one role.
```

- [ ] **Step 4: Commit the amendment**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add docs/specs/2026-04-13-paperclipowers-design.md
git status --porcelain
git diff --stat HEAD
```

Expected: only the spec file modified. Commit:

```bash
git commit -m "docs(paperclipowers): amend spec §5.2/§5.4/§8 for Stage 5

- §5.2: approval gate uses status+assignee PATCH (POST /api/approvals
  supports only hire_agent/approve_ceo_strategy/budget_override_required
  per packages/shared/src/constants.ts:203; no spec/plan approval type)
- §5.4: describe per-issue session keying in agentTaskSessions
  (explains Stage 4 Anomaly 4: mention wakes on different subtask issues
  are freshSession=true because sessions are keyed by issueId, not agentId)
- §8: Stage 5 scope narrowed — PM + Reviewer hires only; single consolidated
  Reviewer per Stage 2 results; Designer deferred to Stage 6 with
  needsDesignPolish hook in writing-plans"
```

Do NOT push yet — Task 8 pushes everything together.

- [ ] **Step 5: Sanity-check the amendment in isolation**

```bash
git log --oneline -3
git show --stat HEAD
grep -n "APPROVAL_TYPES\|POST /api/approvals\|POST /api/companies/:id/approvals" docs/specs/2026-04-13-paperclipowers-design.md
```

Expected: the `POST /api/approvals` wording is gone; `POST /api/companies/:id/approvals` is mentioned only in the limitation note explaining why it can't be used for specs/plans.

---

## Task 3: Author `_shared/` convention files

**Files:** Create: `skills-paperclip/_shared/heartbeat-interaction.md`, `skills-paperclip/_shared/paperclip-conventions.md`.

**Context:** The design spec §4 describes a `_shared/` directory holding two convention documents referenced by every Paperclip-adapted skill. Stages 1-4 inlined these conventions repeatedly in each skill. Stage 5 extracts them now — three skills are being authored or heavily rewritten, duplication would hurt. Keep both files short (≤120 lines each). They are NOT skills (no frontmatter); each adapted SKILL.md references the relevant convention file via a relative `../_shared/...` link.

Neither file is materialized as a skill at runtime (they lack frontmatter + aren't imported as a separate skill). They exist as repo-internal references + documentation. Stage 5 skills cite them; agents don't read them at runtime unless an agent fetches them via the workspace's git checkout (which requires the workspace to have the repo cloned — not the case today). For this stage, treat them as author-time references that keep the three Stage 5 skills consistent.

- [ ] **Step 1: Write `skills-paperclip/_shared/heartbeat-interaction.md`**

Use the `Write` tool to create the file with this full content:

```markdown
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
```

- [ ] **Step 2: Write `skills-paperclip/_shared/paperclip-conventions.md`**

Use the `Write` tool to create the file with this full content:

```markdown
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
```

- [ ] **Step 3: Sanity-check both files**

```bash
cd /Users/henrique/custom-skills/paperclipowers
ls -la skills-paperclip/_shared/
wc -l skills-paperclip/_shared/*.md
head -3 skills-paperclip/_shared/heartbeat-interaction.md skills-paperclip/_shared/paperclip-conventions.md
```

Expected: two files, each ~100-120 lines, neither with YAML frontmatter (they're not skills — no `name:`/`description:` top matter).

- [ ] **Step 4: Git status — staging only, no commit yet**

```bash
git status --porcelain
git diff --stat
```

Expected: two untracked new files. Task 8 commits the whole Stage 5 skill bundle together.

---

## Task 4: Adapt `brainstorming` to `skills-paperclip/brainstorming/`

**Files:**
- Create: `skills-paperclip/brainstorming/SKILL.md` (~220 lines, heavy rewrite)
- Create: `skills-paperclip/brainstorming/UPSTREAM.md` (provenance + merger map)

**Context:** Upstream `brainstorming` (skills/brainstorming/SKILL.md, 164 lines) drives an interactive CLI dialog: one-question-at-a-time, visual companion for mockups, TodoWrite checklist, write-to-filesystem-path spec. Paperclip's PM agent operates entirely differently: Q&A via issue comments batched per heartbeat, no browser, deliverables go to issue documents not filesystem paths, no TodoWrite tool. The upstream visual-companion.md (287 lines) is dropped entirely.

The adaptation replaces six upstream mechanisms with Paperclip equivalents. The full-merged content below is the exact Stage 5 `SKILL.md` — write it verbatim.

- [ ] **Step 1: Read upstream source for provenance**

```bash
cd /Users/henrique/custom-skills/paperclipowers
wc -l skills/brainstorming/SKILL.md skills/brainstorming/visual-companion.md skills/brainstorming/spec-document-reviewer-prompt.md
head -30 skills/brainstorming/SKILL.md
```

Expected: SKILL.md 164 lines; visual-companion.md 287 lines; spec-document-reviewer-prompt.md 49 lines. Frontmatter on SKILL.md starts `name: brainstorming`, `description: "You MUST use this before any creative work..."`.

- [ ] **Step 2: Create the target directory**

```bash
mkdir -p skills-paperclip/brainstorming
```

Expected: directory exists.

- [ ] **Step 3: Write `skills-paperclip/brainstorming/SKILL.md` verbatim**

Use the `Write` tool to create the file with this exact content:

```markdown
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
3. Write the spec to the issue: `PUT /api/issues/<issue-id>/documents/spec` with `{"format": "markdown", "body": "<full spec content>", "title": "<feature name> — Spec"}`. Use the curl `--data-binary @file` idiom (see `../_shared/heartbeat-interaction.md` § Curl payload idiom).
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
6. Exit heartbeat. On 3rd rejection cycle, escalate: post a summary comment, PATCH to `{"status": "blocked", "assigneeAgentId": "<board-id>"}`, let the board decide (spec §6.1).

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
```

- [ ] **Step 4: Write `skills-paperclip/brainstorming/UPSTREAM.md` verbatim**

Use the `Write` tool:

```markdown
# Upstream Provenance — brainstorming

**Stage introduced:** Stage 5
**Adaptation type:** HEAVY REWRITE — structural reimplementation for Paperclip heartbeat model. Upstream content retained as conceptual anchor (clarifying-question-first, spec-before-plan gate, decomposition-on-scope-overflow); mechanism entirely replaced. Do not treat upstream changes as patches to apply.
**Last synced:** 2026-04-14
**Upstream base commit:** <capture from `git -C /Users/henrique/custom-skills/paperclipowers/skills log -1 --format=%H brainstorming/`> (record actual SHA at Step 5 of Task 4)
**Upstream source paths:**
- `skills/brainstorming/SKILL.md` (164 lines)
- `skills/brainstorming/spec-document-reviewer-prompt.md` (49 lines — NOT ported; Reviewer uses `code-review/reviewer-prompt.md`)
- `skills/brainstorming/visual-companion.md` (287 lines — DROPPED entirely; no browser in Docker)
- `skills/brainstorming/scripts/*` (DROPPED; visual-companion infrastructure)

## Merger map

| Upstream content | Destination in paperclipowers | Rationale |
|---|---|---|
| SKILL.md: "Overview" + HARD-GATE | `brainstorming/SKILL.md` § intro + HARD-GATE (retained; gate reworded to reference spec completeness instead of user approval) | Same structural intent; different approver |
| SKILL.md: "Checklist" (9 items inc. visual companion) | `brainstorming/SKILL.md` § When to Invoke + § The Process (flattened into three wake scenarios, visual-companion items dropped) | Heartbeat model has no TodoWrite; upstream's ordered checklist maps to per-wake branching |
| SKILL.md: "Process Flow" (graphviz) | Dropped | Graph rendered well in Claude Code but doesn't survive Paperclip runtime materialization; prose flow suffices |
| SKILL.md: "Understanding the idea" section | `brainstorming/SKILL.md` § First Wake + § Q&A Round | Same intent, adapted to comment-based Q&A |
| SKILL.md: "One question at a time" principle | Inverted in `brainstorming/SKILL.md` § First Wake + Q&A Round: "batch 2-3 per comment" | Heartbeat scheduler latency makes one-question-per-round prohibitively slow |
| SKILL.md: "Exploring approaches" | Dropped | Upstream pattern has PM proposing 2-3 technical approaches pre-design. For Paperclip, approach-level tradeoffs belong to the Tech Lead's plan (§3.1, Tech Lead role), not the PM's spec. |
| SKILL.md: "Presenting the design" + section-by-section approval | Collapsed into § Writing the Spec (one doc write, one status PATCH, Reviewer-gate approval) | Approval-per-section iteration is a synchronous-CLI artifact; async Paperclip gate is all-or-nothing |
| SKILL.md: "Spec Self-Review" | `brainstorming/SKILL.md` § Spec Quality Checklist | Retained as authoring discipline before PUT |
| SKILL.md: "User Review Gate" | Replaced by § Writing the Spec step 5 (PATCH to Reviewer, then board) — two-stage gate | Paperclip has no synchronous user; Reviewer gate is the first review, board is the second |
| SKILL.md: "Implementation" (invoke writing-plans) | Replaced by approval-gate handoff (Reviewer + board approve → board PATCHes to Tech Lead) | PM does not directly invoke Tech Lead; skills are per-agent, the pipeline routes via assignee |
| SKILL.md: "Visual Companion" (149-164) | DROPPED | No browser in Docker container (spec §4.1) |
| visual-companion.md (full file) | DROPPED | Browser-dependent |
| spec-document-reviewer-prompt.md | NOT ported | Reviewer already has `code-review/reviewer-prompt.md` which covers spec review as Trigger 1 |
| SKILL.md: "Key Principles" list | Dropped (absorbed into Red Flags + process) | Redundant |
| SKILL.md: "Working in existing codebases" | Dropped | PM's spec is feature-level, not codebase-navigation; Tech Lead's writing-plans handles codebase-fit decisions |

## Design deviations documented here (not in design spec)

1. **3-round Q&A cap with escalation.** Upstream has no max-round bound; Paperclip needs one because heartbeat cost + latency compounds. Cap at 3 rounds before either writing a spec with `## Open Questions` or escalating to `status: blocked`. Spec §6.1 mentions "3x rejection" loops; this is the analog for Q&A.
2. **`## Open Questions` and `## Non-Goals` sections are required.** Upstream's spec sections are advisory; Paperclip needs these explicit to make the Reviewer's scope-check actionable.
3. **Spec decomposition is a comment-level interaction, not an automatic checkbox.** Upstream's decomposition check is one of 9 checklist items completed silently; Paperclip surfaces it as an explicit board interaction (post comment proposing decomposition, wait for reply) because the decision is scope-critical.
4. **Reviewer mode uses `code-review/reviewer-prompt.md`, not the upstream `spec-document-reviewer-prompt.md`.** Upstream's separate reviewer prompt is redundant — `code-review`'s Trigger 1 (spec review) already handles this artifact with the same categorized-findings format. Stage 2 code-review skill was consolidated for exactly this purpose.

## Resolved design decisions

- **Drop visual companion entirely.** Spec §4.1 lists it as one of the five dropped items. Re-introducing it would require a headless-browser setup in the Paperclip container, which is out of scope across the entire paperclipowers roadmap.
- **Spec written to `spec` document, not a filesystem path.** Consistent with `planDocument` convention in `task-orchestration` (Stage 4) and the `../_shared/paperclip-conventions.md` document.
- **PM does NOT invoke `writing-plans` directly.** Skill invocation is per-agent; the Tech Lead runs `writing-plans`, not the PM. Pipeline routing via issue assignee is the handoff.

## Update procedure

When upstream changes `skills/brainstorming/`:

1. `scripts/check-upstream-drift.sh brainstorming`
2. If SKILL.md changed: read the diff, decide whether the change affects the rewritten `brainstorming/SKILL.md`. Most upstream changes won't — this is a greenfield rewrite, not a line-level port.
3. If a new design principle surfaces upstream that should apply to the PM (e.g., a new question-batching heuristic), integrate into `brainstorming/SKILL.md` as a new subsection.
4. If visual-companion.md or scripts change: ignore — we dropped these.

Drift risk: LOW. The upstream skill evolves for CLI UX; Paperclip PM mechanics are stable.
```

- [ ] **Step 5: Capture upstream base commit for UPSTREAM.md**

```bash
cd /Users/henrique/custom-skills/paperclipowers
UPSTREAM_SHA=$(git log -1 --format=%H skills/brainstorming/ 2>/dev/null || echo "unknown-readonly-mirror")
echo "Upstream base commit for brainstorming: $UPSTREAM_SHA"
# Replace the placeholder in UPSTREAM.md with the actual SHA
sed -i.bak "s|<capture from .git -C /Users/henrique/custom-skills/paperclipowers/skills log -1 --format=%H brainstorming/.>.*|$UPSTREAM_SHA|" skills-paperclip/brainstorming/UPSTREAM.md
rm skills-paperclip/brainstorming/UPSTREAM.md.bak
grep "Upstream base commit" skills-paperclip/brainstorming/UPSTREAM.md
```

Expected: `**Upstream base commit:** <40-char SHA>` (or `unknown-readonly-mirror` if `skills/` is not a nested git repo; safe fallback).

- [ ] **Step 6: Full-file CLI-ism check (Stage 2 Anomaly 1 lesson)**

```bash
grep -nE "your human partner|in this message|TodoWrite|Task\(|git worktree|subagent" skills-paperclip/brainstorming/SKILL.md || echo "CLEAN"
```

Expected: `CLEAN`. If any hit: edit the SKILL.md to rephrase in Paperclip terms ("the board" / "in this heartbeat execution" / "subtasks" / "subtask assignee" — per the spec §5.1 substitution rules).

- [ ] **Step 7: Verify directory state**

```bash
ls -la skills-paperclip/brainstorming/
wc -l skills-paperclip/brainstorming/*.md
git status --porcelain skills-paperclip/brainstorming/
```

Expected: two untracked new files (SKILL.md ~220 lines, UPSTREAM.md ~75 lines). No accidental scripts/ or visual-companion subdirectories.

---

## Task 5: Adapt `writing-plans` to `skills-paperclip/writing-plans/`

**Files:**
- Create: `skills-paperclip/writing-plans/SKILL.md` (~280 lines, heavy rewrite)
- Create: `skills-paperclip/writing-plans/UPSTREAM.md`

**Context:** Upstream `writing-plans` (152 lines) assumes an engineer is reading the plan in a CLI: "bite-sized steps", exact file paths, code blocks per step, shell commands with expected output. Paperclip's Tech Lead writes a plan consumed by the same human-in-the-loop (the board) PLUS the downstream `task-orchestration` skill which decomposes the plan into subtasks. The consumption model matters: a plan with free-form prose steps is fine for a human engineer but too loose for `task-orchestration` to cleanly extract slice boundaries.

Stage 5's `writing-plans` therefore encodes three differences from upstream:

1. **Concrete schemas per slice** (design spec §2.2). Every slice specifies its TypeScript/JSON input and output types explicitly, not in prose. This is the "concrete contract" that prevents AI drift during implementation.
2. **Per-slice `needsDesignPolish: boolean` flag** — Stage 6 hook for Designer polish. Stage 5 always sets `false`. The flag is read by `task-orchestration` on slice decomposition (Task 7 updates the skill); in Stage 5 it's a no-op; in Stage 6 it triggers a follow-up subtask assigned to the Designer.
3. **Plan written to issue `planDocument`** via `PUT /api/issues/<id>/documents/plan`. On PUT, Paperclip auto-populates the top-level `.planDocument` field with the full body, which `task-orchestration/SKILL.md` § First Wake reads directly. No filesystem path, no pointer indirection.

The adapted skill also adds an approval gate (PATCH to Reviewer, then board) matching the `brainstorming` pattern, and reinforces the "no implementation code" boundary — the Tech Lead's output is a plan, not code.

- [ ] **Step 1: Read upstream source**

```bash
cd /Users/henrique/custom-skills/paperclipowers
wc -l skills/writing-plans/*.md
head -20 skills/writing-plans/SKILL.md
```

Expected: `SKILL.md` 152 lines, `plan-document-reviewer-prompt.md` 49 lines.

- [ ] **Step 2: Create target directory**

```bash
mkdir -p skills-paperclip/writing-plans
```

- [ ] **Step 3: Write `skills-paperclip/writing-plans/SKILL.md` verbatim**

Use the `Write` tool:

```markdown
---
name: writing-plans
description: Use when the Tech Lead has been assigned an issue with an approved spec document and no plan document. Writes a vertical-slice implementation plan with concrete schemas per slice and blockedByIssueIds dependency annotations, saves to planDocument on the issue, and hands off to Reviewer before board approval.
---

# Writing Plans — Tech Lead Skill

You are the Tech Lead. You have been assigned a feature issue whose `spec` document has already been approved (by the Reviewer + board). Your job is to author a concrete implementation plan — a vertical-slice decomposition with TypeScript/JSON schemas — save it to the issue's `plan` document, and hand off for approval before you start orchestrating.

This is the Paperclip adaptation of upstream `writing-plans`. Sibling skills: `task-orchestration` (runs after this one, consumes the plan's slice decomposition); `code-review` (the Reviewer's skill, evaluates your plan). See `../_shared/heartbeat-interaction.md` and `../_shared/paperclip-conventions.md` for the base conventions.

<HARD-GATE>
Do NOT decompose into subtasks, do NOT invoke task-orchestration, do NOT create any child issues until (1) you have written the plan to the `plan` document AND (2) it has been approved via the status+assignee gate (Reviewer → board → back to you with `status: in_progress`).
</HARD-GATE>

## When to Invoke

You wake on one of three signals:

1. **`issue_assigned`, feature issue with `spec` document present but `planDocument` null** — first wake after board approves the spec. Read the spec, write the plan. See § First Wake.
2. **`issue_assigned`, feature issue with both `spec` and `planDocument` present** — Reviewer or board bounced the plan back with findings. Revise. See § Revision.
3. **`issue_assigned`, feature issue with approved plan (status: in_progress, assignee: you)** — board has approved the plan. Stop using this skill; invoke `task-orchestration` instead. (The pipeline-dispatcher handles this routing.)

## The Process

### First Wake

1. Read the issue description (the board's original ask) and the `spec` document: `GET /api/issues/<id>/documents/spec`.
2. Read any ancestor issues (`.parentId` chain) for broader context.
3. Check the workspace: `git log --oneline -10` in your cwd to see what prior work exists. For the first feature in a fresh workspace, this may be empty.
4. Identify the vertical slices. A slice is a complete feature cut that produces working, testable software on its own (spec §2.1). For a small feature (≤3 slices), a linear chain works. For larger features, structure as a DAG using `blockedByIssueIds` candidate edges — one slice's output becomes another's input.
5. For each slice, draft the concrete schemas that will be its input/output contract (see § Concrete Schemas).
6. Draft the plan document content (see § Plan Document Structure).
7. Self-review against the Plan Quality Checklist (one pass, fix inline).
8. Write the plan: `PUT /api/issues/<issue-id>/documents/plan` with `{"format": "markdown", "body": "<plan content>", "title": "<feature> — Plan"}`. Use the curl `--data-binary @file` idiom.
9. PATCH the issue with ONE call: `{"status": "in_review", "assigneeAgentId": "<reviewer-agent-id>"}`. Combining fields is load-bearing (Stage 4 Anomaly 1).
10. Post a one-sentence announcement comment on the issue (no `@` mentions — assignee PATCH fires the proper wake).
11. Exit heartbeat.

### Revision

Analog of brainstorming's revision flow. Read Reviewer findings, revise the `plan` document via PUT (creates a new revision), PATCH back to `{"status": "in_review", "assigneeAgentId": "<reviewer-id>"}`. See `code-review` Part 2 for receiving-review discipline.

## Concrete Schemas — The Contract

Every slice in your plan must declare its concrete inputs and outputs. This is the difference between a Paperclip plan and an upstream CLI plan: the Engineer, running on a fresh Claude session in a separate heartbeat, cannot interrogate you for clarifications efficiently. The schema IS the contract. If the schema is wrong, the Engineer builds the wrong thing.

**Format (required for every slice):**

```markdown
### Slice N: <Short imperative title>

**Depends on slices:** [M, K] or "none"
**needsDesignPolish:** false

**Inputs:**
\`\`\`ts
// TypeScript-flavor types; JSON Schema or any concrete type language acceptable
interface SliceNInput {
  foo: string;               // constraint: non-empty
  bar: number | null;        // nullable: yes
  items: Array<{ id: string; count: number }>;
}
\`\`\`

**Outputs:**
\`\`\`ts
interface SliceNOutput {
  persistedId: string;       // what the Engineer produces + stores
  computedFoo: number;
}
// OR, for filesystem outputs:
// - Creates: src/features/foo/index.ts exporting `handleFoo(input: SliceNInput): Promise<SliceNOutput>`
// - Creates: src/features/foo/foo.test.ts with N test cases
\`\`\`

**Acceptance criteria:**
- <testable statement — specific enough to become a test>
- <testable statement>
- All tests in `<test-file-path>` pass
- Workspace `git status` clean before commit; commits squashed to one
```

Use TypeScript type syntax even for non-TS projects — it's a universal contract language. For Python projects, the Engineer translates at implementation time (TypedDict, dataclass, Pydantic) — that's cheap.

**`needsDesignPolish` flag.** Stage 5: always `false`. Stage 6 (Designer integration): set `true` on UI-surface slices where a design-polish follow-up should be scheduled after the Engineer's implementation lands. `task-orchestration` reads this flag per slice and creates a follow-up Designer subtask only when `true`. Stage 5 hardcodes `false` because the Designer agent doesn't exist yet.

## Plan Document Structure

The plan document written to the `plan` issue-document uses this structure:

```markdown
# <Feature Name> — Implementation Plan

## Overview

<1 paragraph — what this plan builds, aligned with the spec's Purpose.>

## Architecture

<2-3 sentences on the approach. Decisions at the architecture level: framework choices, data-flow shape, integration boundaries.>

## File Structure

<Bulleted list of new files, modified files. One line each. Cite the responsibility of each file — what it does and what other files depend on it.>

## Vertical Slices

### Slice 1: <Title>
<Full concrete schema block per § Concrete Schemas>

### Slice 2: <Title>
<...>

### Slice N: <Title>
<...>

## Cross-slice Testing

<Any integration tests that span multiple slices. Single-slice tests live in each slice's acceptance criteria; this section is for end-to-end validation.>

## Rollback

<How to undo the whole feature if needed. For most features: "git revert the subtask commits". For migration-touching features: explicit rollback steps.>
```

No inline code for the Engineer to copy-paste — that's `task-orchestration`'s domain when it creates subtask descriptions. The plan's job is to scope each slice's contract, not to write the implementation.

**Scope:** 300-2000 words total. Longer than the spec, shorter than the upstream CLI plans (which double as implementation manuals for a fresh engineer with no prior context). The Engineer gets the full slice schema via `task-orchestration`'s subtask description, not via the plan document directly.

## Plan Quality Checklist

Self-review before PUT:

1. **Spec coverage** — every Success Criterion from the `spec` document maps to exactly one slice's acceptance criteria. No orphan success criteria, no slices unmoored from the spec.
2. **Slice independence** — each slice produces working, testable software on its own. If Slice 2 can't pass its tests without Slice 3 being implemented, merge them or rewire the dependency.
3. **Schema concreteness** — every slice has non-prose Inputs and Outputs blocks. "A user object" is not a schema; `{id: string; email: string; createdAt: string}` is.
4. **Dependency annotations** — `Depends on slices: [M, K]` present on every slice. Empty list OK for the head of a chain; explicit is better than implicit.
5. **Acceptance criteria testable** — each criterion is specific enough to become a concrete test assertion. "Works correctly" is not testable.
6. **needsDesignPolish present** — every slice declares the flag explicitly, even if `false`. Missing flag = Task 7 task-orchestration will fail on the decomposition step.
7. **No implementation code** — you're writing the Tech Lead contract, not the Engineer's implementation. Resist the urge to prototype in the plan.
8. **Cross-slice tests specified** — any test that spans multiple slices is called out in the Cross-slice Testing section, not in any individual slice.

If a check fails, fix inline. No need for a second review pass.

## Scope Check

If the spec covers multiple independent subsystems despite the PM's decomposition check, STOP. You cannot compress three features into one plan cleanly. Post a comment on the issue:

```
The approved spec describes <N> independent subsystems:

1. <name> — could be its own plan
2. <name> — could be its own plan
...

Proceeding with a single plan would produce a subtask graph too large to orchestrate coherently. Options:

A. Split the spec into <N> child issues before planning (PM re-opens the spec)
B. I write a minimal "skeleton" plan covering shared infrastructure, then <N> follow-up plans per subsystem
C. Proceed with one plan anyway (I'll flag in the plan's Scope section that this may need post-implementation refactoring)

Which?
```

PATCH issue back to `{"status": "in_progress", "assigneeAgentId": "<board-id>"}`, exit heartbeat. Wait for the board's decision.

## Red Flags — STOP

- Writing implementation code in the plan document. The plan is a contract, not a scaffold.
- Leaving schema fields typed as `any` or prose-only (`"the user data"`). Concrete, or bail and ask the PM.
- Creating subtasks in this heartbeat. That's `task-orchestration`'s job, after plan approval.
- @-mentioning yourself in the announcement comment — self-wake loop.
- Separate PATCHes for status and assignee — race. Combine.
- Writing the plan to a filesystem path (`docs/plans/...`) — that's upstream CLI. Use the `plan` issue document.
- Skipping `needsDesignPolish` on any slice — Task 7 task-orchestration reads this flag; missing = decomposition fails.
- Authoring a plan with a single slice if the feature actually has ≥2 vertical slices. Compressing slices hides dependencies.

## Integration

**Companion Paperclip skills:**

- `pipeline-dispatcher` — routes you into this skill when the feature reaches the plan phase.
- `task-orchestration` — consumes your plan on the NEXT wake (after board approves), reads `.planDocument.body`, decomposes into subtasks. Your plan's slice granularity and `needsDesignPolish` flags are its inputs.
- `code-review` (Reviewer mode) — evaluates your plan via the same structured-findings format as code review. Trigger 2 (plan review) in their skill.

**Companion upstream concepts (dropped from this adaptation):**

- Bite-sized TDD steps per task — Paperclip plan is a contract; the Engineer's heartbeat follows `test-driven-development` discipline, but step-by-step TDD narration lives in subtask descriptions (task-orchestration's job), not the plan.
- "Subagent-driven" / "Inline execution" choice — `task-orchestration` is the only execution path in Paperclip.
- Task-level "git commit" steps in plan — the Engineer commits per subtask; plan doesn't narrate commits.

## Execution Model Reminder

Your output is a plan document on an issue. You do NOT create subtasks, do NOT write implementation code, do NOT run the Engineer's tests. All of those live in downstream heartbeats handled by different agents (Engineer) or your own later heartbeats after plan approval (you invoking `task-orchestration`).
```

- [ ] **Step 4: Write `skills-paperclip/writing-plans/UPSTREAM.md`**

```markdown
# Upstream Provenance — writing-plans

**Stage introduced:** Stage 5
**Adaptation type:** HEAVY REWRITE — Paperclip plan is a contract (consumed by task-orchestration + Reviewer), not a step-by-step scaffold for a CLI engineer.
**Last synced:** 2026-04-14
**Upstream base commit:** <capture at Step 5>
**Upstream source paths:**
- `skills/writing-plans/SKILL.md` (152 lines)
- `skills/writing-plans/plan-document-reviewer-prompt.md` (49 lines — NOT ported; Reviewer uses `code-review/reviewer-prompt.md`)

## Merger map

| Upstream content | Destination in paperclipowers | Rationale |
|---|---|---|
| SKILL.md: "Overview" | `writing-plans/SKILL.md` § intro (rewritten: "concrete contract, not bite-sized CLI steps") | Same intent; different consumption model |
| SKILL.md: "Scope Check" | `writing-plans/SKILL.md` § Scope Check (adapted to comment back to board) | CLI has user-dialogue; Paperclip has issue comments + assignee PATCH |
| SKILL.md: "File Structure" section | `writing-plans/SKILL.md` § Plan Document Structure > File Structure subsection | Retained as authoring guidance |
| SKILL.md: "Bite-Sized Task Granularity" | DROPPED from writing-plans, moved to task-orchestration's subtask templates | Bite-sized steps are the Engineer's lens; plan-level granularity is slice-level |
| SKILL.md: "Plan Document Header" | `writing-plans/SKILL.md` § Plan Document Structure § Overview + Architecture | Distilled |
| SKILL.md: "Task Structure" (full TDD/commit per task) | DROPPED | Task-level TDD narration lives in Engineer's skills (test-driven-development) + task-orchestration subtask templates |
| SKILL.md: "No Placeholders" | `writing-plans/SKILL.md` § Plan Quality Checklist (item 3: schema concreteness; item 5: testable acceptance) | Same anti-pattern guard, restated for schema discipline |
| SKILL.md: "Self-Review" | `writing-plans/SKILL.md` § Plan Quality Checklist | Retained |
| SKILL.md: "Execution Handoff" / "Subagent-Driven vs Inline" | Replaced by § Integration (task-orchestration is the only path) | Paperclip subtask graph IS the execution model |
| SKILL.md: "Save plans to docs/superpowers/plans/..." | Replaced by `PUT /api/issues/<id>/documents/plan` | Plan lives on the issue |
| plan-document-reviewer-prompt.md | NOT ported | Reviewer uses code-review/reviewer-prompt.md (Trigger 2: plan review) |

## Design deviations documented here (not in design spec)

1. **Concrete schemas per slice are REQUIRED.** Spec §2.2 called for "concrete TypeScript/JSON schemas"; this skill enforces it as a checklist item. A plan without concrete schemas is rejected at self-review.
2. **`needsDesignPolish: boolean` per slice.** Stage 6 hook baked into Stage 5 output. Stage 5 plans hardcode `false`; the field is present so `task-orchestration` can parse it without a schema migration when Stage 6 flips it live on UI slices.
3. **Plan document consumption:** the Tech Lead's NEXT heartbeat (on board approval) reads `.planDocument.body` via `task-orchestration`. Upstream's plan is read by a human; Paperclip's plan is read by a skill.
4. **No inline code per task.** Upstream's plan has full code blocks per step (the Engineer's implementation narrated); Paperclip's plan stops at slice schemas. The subtask description (task-orchestration) expands to concrete test cases and implementation hints.
5. **Scope-overflow comment instead of brainstorming-decomposition pointer.** If the spec slipped through PM's decomposition check, Tech Lead flags it back to the board rather than re-invoking brainstorming. Tech Lead does not run PM skills.

## Resolved design decisions

- **Plan lives on the issue, not the filesystem.** Consistent with the `spec` document convention.
- **Stage 6 Designer integration is a flag, not a structural rewrite.** Plans emitted in Stage 5 have `needsDesignPolish: false` on every slice; Stage 6 flips the flag per-slice and hires the Designer. No Stage 5 skill changes needed for Stage 6.

## Update procedure

When upstream changes `skills/writing-plans/`:

1. `scripts/check-upstream-drift.sh writing-plans`
2. Schema-contract discipline (concrete types) is NOT negotiable — don't absorb upstream changes that weaken it.
3. If upstream adds a new plan-section type (e.g., "rollback narration"), integrate into `writing-plans/SKILL.md` § Plan Document Structure.
4. Ignore upstream changes to bite-sized TDD steps or execution-handoff — those concepts live elsewhere in paperclipowers.

Drift risk: MEDIUM. Upstream evolves for CLI-engineer UX; schema-discipline keeps Paperclip plans machine-consumable and must not erode.
```

- [ ] **Step 5: Capture upstream base commit**

```bash
cd /Users/henrique/custom-skills/paperclipowers
UPSTREAM_SHA=$(git log -1 --format=%H skills/writing-plans/ 2>/dev/null || echo "unknown-readonly-mirror")
sed -i.bak "s|<capture at Step 5>|$UPSTREAM_SHA|" skills-paperclip/writing-plans/UPSTREAM.md
rm skills-paperclip/writing-plans/UPSTREAM.md.bak
grep "Upstream base commit" skills-paperclip/writing-plans/UPSTREAM.md
```

- [ ] **Step 6: CLI-ism check**

```bash
grep -nE "your human partner|in this message|TodoWrite|Task\(|git worktree|subagent|Inline Execution|Subagent-Driven" skills-paperclip/writing-plans/SKILL.md || echo "CLEAN"
```

Expected: `CLEAN`. Fix any hits inline before proceeding.

- [ ] **Step 7: Cross-reference check against spec §2.2**

```bash
grep -nE "concrete|schema|TypeScript|JSON" skills-paperclip/writing-plans/SKILL.md | head -10
```

Expected: at least 5 mentions of "schema" + "concrete" language. This is the load-bearing discipline (spec §2.2).

- [ ] **Step 8: Verify**

```bash
ls -la skills-paperclip/writing-plans/
wc -l skills-paperclip/writing-plans/*.md
```

Expected: two files (SKILL.md ~280 lines, UPSTREAM.md ~75 lines).

---

## Task 6: Author `pipeline-dispatcher` skill (NEW)

**Files:**
- Create: `skills-paperclip/pipeline-dispatcher/SKILL.md` (~180 lines, greenfield)
- Create: `skills-paperclip/pipeline-dispatcher/UPSTREAM.md`

**Context:** Upstream `using-superpowers` (117 lines) instructs CLI Claude to invoke the `Skill` tool before any response, listing skills and using TodoWrite to track checklists. In Paperclip there is no `Skill` tool (skills are already injected into the system prompt by the adapter), no `TodoWrite` (use comments or subtasks). The replacement skill has a different job: tell each role WHICH of its already-injected skills applies given the current wake context, and enforce the heartbeat-mode disciplines (no self-mention, no gratitude comments, no tool calls that don't exist).

This is a greenfield skill, not a port. No line-level mapping to upstream. The name is new (`pipeline-dispatcher`) because the behaviour is new — it dispatches per role through the pipeline, it does NOT wrap the Claude Code `Skill` tool.

- [ ] **Step 1: Create target directory**

```bash
cd /Users/henrique/custom-skills/paperclipowers
mkdir -p skills-paperclip/pipeline-dispatcher
```

- [ ] **Step 2: Write `skills-paperclip/pipeline-dispatcher/SKILL.md` verbatim**

Use the `Write` tool:

```markdown
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
```

- [ ] **Step 3: Write `skills-paperclip/pipeline-dispatcher/UPSTREAM.md`**

```markdown
# Upstream Provenance — pipeline-dispatcher

**Stage introduced:** Stage 5
**Adaptation type:** GREENFIELD — no line-level port. Replaces upstream `using-superpowers` wholesale because the underlying mechanism (Skill tool invocation, TodoWrite checklist) doesn't exist in Paperclip's heartbeat adapter.
**Last synced:** 2026-04-14
**Upstream base commit:** <capture at Step 4>
**Upstream source paths (conceptually replaced, not ported):**
- `skills/using-superpowers/SKILL.md` (117 lines)

## Merger map

| Upstream content | Destination in paperclipowers | Rationale |
|---|---|---|
| using-superpowers: "Invoke relevant skills BEFORE any response" | `pipeline-dispatcher/SKILL.md` § How to Use This Skill (skills are pre-loaded, routing is the action) | CLI Claude must call `Skill` tool to load; Paperclip adapter pre-loads all desiredSkills into system prompt |
| using-superpowers: "Red Flags" + rationalization guards | Replaced by § Heartbeat-Mode Disciplines | Original guards target CLI-Claude rationalization ("I remember this skill" etc.); Paperclip agents rationalize differently (e.g., trying to invoke tools that don't exist) |
| using-superpowers: "Process skills first" priority | Replaced by § Role-to-Skill Matrix | Priority emerges from role, not skill category |
| using-superpowers: "Skill Types" (Rigid vs Flexible) | Dropped | Not actionable at dispatch time; the skill itself indicates its own rigidity |
| using-superpowers: Graphviz flow diagram | Dropped | Prose routing is sufficient |
| using-superpowers: "How to Access Skills" platform table | Dropped | Paperclip has one access model: adapter-injected |
| using-superpowers: "User Instructions" priority clause | Dropped | Paperclip has no synchronous user; board comments substitute |

## Design deviations documented here (not in design spec)

1. **Role disambiguation by agent name when `role: "engineer"` is overloaded.** Paperclip's role enum has no `tech_lead`, so Stage 4 used `role: "engineer"` for the Tech Lead. This skill's matrix disambiguates by agent name contains `tech-lead`. Spec §7 doesn't mandate a naming convention; this skill codifies one as an operator agreement.
2. **Stage 6 Designer row is reserved, not active.** Written in now because the skill is versioned; flipping it live in Stage 6 is a skill revision, not a rewrite.
3. **Reviewer's Trigger 3 (per-subtask review) is intentionally unwired in Stage 5.** The Reviewer wakes only at spec / plan / final-combined gates; per-subtask review is a Stage 7+ decision (scope simplification to prove the pipeline before adding per-slice review overhead).

## Resolved design decisions

- **Skills are adapter-injected, not tool-invoked.** Consistent with the Paperclip `claude_local` adapter's skill-materialization mechanism (confirmed at Stage 1 Task 4 runtime paths).
- **One dispatcher skill, all roles.** Alternative was per-role dispatcher skills; rejected as unnecessary duplication — the role matrix is small enough to live in one file.

## Update procedure

When upstream changes `skills/using-superpowers/`:

1. `scripts/check-upstream-drift.sh using-superpowers` (reports against the greenfield base; always non-zero diff after upstream change)
2. Read the diff. Most upstream changes will be about CLI mechanics (new tool, new invocation syntax) — not applicable.
3. If upstream adds a new discipline (e.g., a new anti-pattern for skill invocation), evaluate whether a Paperclip analog exists and integrate into § Heartbeat-Mode Disciplines.
4. If upstream adds a new skill category (Rigid/Flexible/something), evaluate skipping — Paperclip's skill-type taxonomy isn't surfaced at dispatch.

Drift risk: HIGH but IRRELEVANT. Upstream evolves for Claude Code CLI behaviour; Paperclip's routing model is stable. Check drift for awareness, rarely port.
```

- [ ] **Step 4: Capture upstream base commit**

```bash
cd /Users/henrique/custom-skills/paperclipowers
UPSTREAM_SHA=$(git log -1 --format=%H skills/using-superpowers/ 2>/dev/null || echo "unknown-readonly-mirror")
sed -i.bak "s|<capture at Step 4>|$UPSTREAM_SHA|" skills-paperclip/pipeline-dispatcher/UPSTREAM.md
rm skills-paperclip/pipeline-dispatcher/UPSTREAM.md.bak
grep "Upstream base commit" skills-paperclip/pipeline-dispatcher/UPSTREAM.md
```

- [ ] **Step 5: CLI-ism check**

```bash
grep -nE "your human partner|in this message|Skill tool|Task\(|git worktree|TodoWrite" skills-paperclip/pipeline-dispatcher/SKILL.md | grep -v "does not exist\|doesn't exist\|NOT invoke\|DO NOT\|Never\|no .Skill. tool\|no .TodoWrite.\|not exist" || echo "CLEAN"
```

Expected: `CLEAN`. The skill deliberately mentions these CLI-only tools to tell agents NOT to use them, so the grep filter excludes hits in negation contexts.

- [ ] **Step 6: Verify directory + sanity-check matrix content**

```bash
ls -la skills-paperclip/pipeline-dispatcher/
wc -l skills-paperclip/pipeline-dispatcher/*.md
grep "^|" skills-paperclip/pipeline-dispatcher/SKILL.md | head -10
```

Expected: two files, SKILL.md ~180 lines, UPSTREAM.md ~55 lines. Grep shows the role-to-skill matrix rows rendered as pipe-separated lines.

---

## Task 7: Update `task-orchestration/SKILL.md` for Stage 5 planDocument consumption

**Files:** Modify: `skills-paperclip/task-orchestration/SKILL.md`.

**Context:** Stage 4 task-orchestration § First Wake falls back to `.description` when `.planDocument` is null: "Stage 4 uses description; future stages populate `.planDocument` via a separate skill". Stage 5 populates `.planDocument` via `writing-plans`, so the description-fallback branch is no longer the happy path.

Additionally, `writing-plans` emits `needsDesignPolish: boolean` per slice. `task-orchestration` should READ this flag per slice during decomposition. Stage 5 behaviour on reading the flag: log the flag value in a comment on each created subtask, do not spawn a Designer subtask. Stage 6 will add the Designer-subtask-creation branch.

Keep the change minimal — one section rewrite + one flag-read addition. Do NOT rewrite the whole skill; Stage 4 validated its current shape.

- [ ] **Step 1: Read current task-orchestration SKILL.md for context**

```bash
cd /Users/henrique/custom-skills/paperclipowers
grep -n "planDocument\|description\|Stage 4 uses description\|Stage 5" skills-paperclip/task-orchestration/SKILL.md | head -10
```

Expected: around lines 35-40 you'll find "If `.planDocument` is non-null, use it as the plan. If `.planDocument` is null, fall back to `.description`". This is the branch to rewrite.

- [ ] **Step 2: Rewrite § The Process Step 1 (plan reading)**

Edit `skills-paperclip/task-orchestration/SKILL.md`. Replace:

```markdown
1. **Read the plan.** On the parent `issue_assigned` wake, call `GET /api/issues/<parent-id>` and inspect `.planDocument`. If `.planDocument` is non-null, use it as the plan. If `.planDocument` is null, fall back to `.description` (Stage 4 uses description; future stages populate `.planDocument` via a separate skill). Read the plan in full. If the plan has testable acceptance criteria per slice, those become the subtasks' exit criteria.
```

with:

```markdown
1. **Read the plan.** On the parent `issue_assigned` wake, call `GET /api/issues/<parent-id>` and inspect `.planDocument`. `.planDocument.body` is the full plan (written by the Tech Lead's `writing-plans` skill on approval). If `.planDocument` is null, this is a pipeline ordering error: the board has assigned you to orchestrate before the plan exists. Post a comment `@<board> planDocument is null — cannot orchestrate; the plan authoring step has not run. Reassigning back.`, PATCH the issue with `{"status": "todo", "assigneeAgentId": "<board-id>"}`, and exit heartbeat. Do NOT fall back to `.description` — that was Stage 4's transitional behaviour and is no longer correct. Each slice in the plan has concrete Inputs/Outputs schemas, acceptance criteria, dependency annotations, and a `needsDesignPolish: boolean` flag; these become the subtasks' full definition.
```

- [ ] **Step 3: Add per-slice `needsDesignPolish` reading to § Creating the Subtask Graph**

In the same file, find the "Recipe — create subtask 1" subsection and insert a new paragraph BEFORE it:

```markdown
### Reading the `needsDesignPolish` flag per slice

Each slice in `.planDocument.body` declares a `needsDesignPolish: false | true` flag (see `writing-plans/SKILL.md` § Concrete Schemas). When creating each subtask, copy the flag value into the subtask description under a "Design Polish" header:

```
## Design Polish

**needsDesignPolish:** false
```

Stage 5 behaviour: always `false`, no Designer subtask spawned. Stage 6 will add: if `true`, create an additional follow-up subtask assigned to the Designer that depends on the Engineer's subtask completion. Stage 5 leaves this as a read-only surface to keep the plan→subtask mapping traceable.
```

- [ ] **Step 4: Add Stage 5 note to § When to Invoke**

In the same file, under `## When to Invoke` subsection, update the third wake signal:

```markdown
3. **`issue_status_changed` on a subtask** — fallback wake if the assignee transitioned status without posting the mention comment. Rare when subtask descriptions include the Notification Protocol, but handle it defensively.
```

Replace with (adds Stage 5 note):

```markdown
3. **`issue_status_changed` on a subtask** — fallback wake if the assignee transitioned status without posting the mention comment. Rare when subtask descriptions include the Notification Protocol, but handle it defensively.

(Stage 5 note: the per-subtask-review trigger that would hand subtasks to the Reviewer between completion and final review is INTENTIONALLY NOT wired in Stage 5. Engineer's `done` on a subtask unblocks the next subtask directly; final review happens on the parent once all subtasks are terminal. Stage 7+ may add per-subtask Reviewer handoff.)
```

- [ ] **Step 5: CLI-ism check**

```bash
grep -nE "your human partner|in this message|TodoWrite|Task\(|git worktree" skills-paperclip/task-orchestration/SKILL.md | grep -v "NOT attempt\|does not exist\|doesn't exist" || echo "CLEAN"
```

Expected: `CLEAN`.

- [ ] **Step 6: Verify the edit is minimal and targeted**

```bash
git diff --stat skills-paperclip/task-orchestration/SKILL.md
git diff skills-paperclip/task-orchestration/SKILL.md | head -60
```

Expected: ~20-30 insertions, ~5-10 deletions in one file. If the diff is larger than ~50 lines total, back off — you've rewritten more than the targeted sections.

- [ ] **Step 7: Update `task-orchestration/UPSTREAM.md` with Stage 5 note**

Append to `skills-paperclip/task-orchestration/UPSTREAM.md`:

```markdown

## Stage 5 revisions

- **§ The Process Step 1 rewritten.** Removed description-fallback branch; `.planDocument` is now always populated by `writing-plans` before this skill fires. If null, escalate to board rather than fall back.
- **§ Creating the Subtask Graph § Reading the `needsDesignPolish` flag per slice ADDED.** Stage 5 reads the flag and copies it into subtask descriptions (read-only surface). Stage 6 will wire the Designer-subtask-creation branch.
- **§ When to Invoke wake #3 gained a Stage 5 note.** Per-subtask Reviewer handoff intentionally unwired in Stage 5.

Pin SHA for Stage 5: `<captured at Task 8 Step 4>`.
```

---

## Task 8: Commit skill changes, push, import 3 new skills to company

**Files:** Modifies git state. Creates entries in the company's skill library.

**Context:** Stage 5 adds three skill directories (`brainstorming`, `writing-plans`, `pipeline-dispatcher`), updates one (`task-orchestration/SKILL.md` + `UPSTREAM.md`), and creates two `_shared/` files. Commit all Stage 5 skill files in ONE commit so `sourceRef` on the imported skills points to a coherent SHA. The spec amendment from Task 2 is already its own commit.

The import uses the **parent-directory URL** (`.../tree/paperclip-adaptation/skills-paperclip`), not per-skill subdirectories — Stage 2 Anomaly 2 proved that per-skill URLs silently drop sibling files during materialization.

Note: Task 7's UPSTREAM.md appendix references a Stage 5 pin SHA — capture it in Step 4 below and update after commit.

- [ ] **Step 1: Stage all Stage 5 skill files**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git status --porcelain
```

Expected: 2 untracked `_shared/*.md`, 2 untracked `brainstorming/*.md`, 2 untracked `writing-plans/*.md`, 2 untracked `pipeline-dispatcher/*.md`, and modified `task-orchestration/SKILL.md` + `task-orchestration/UPSTREAM.md`. 10 files total.

Stage them explicitly (avoid `git add .` — don't want to accidentally commit temp files):

```bash
git add \
  skills-paperclip/_shared/heartbeat-interaction.md \
  skills-paperclip/_shared/paperclip-conventions.md \
  skills-paperclip/brainstorming/SKILL.md \
  skills-paperclip/brainstorming/UPSTREAM.md \
  skills-paperclip/writing-plans/SKILL.md \
  skills-paperclip/writing-plans/UPSTREAM.md \
  skills-paperclip/pipeline-dispatcher/SKILL.md \
  skills-paperclip/pipeline-dispatcher/UPSTREAM.md \
  skills-paperclip/task-orchestration/SKILL.md \
  skills-paperclip/task-orchestration/UPSTREAM.md
git status --porcelain
```

Expected: 10 staged lines (A for additions, M for the two modifications). No unstaged changes.

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(paperclipowers): Stage 5 skills — brainstorming, writing-plans, pipeline-dispatcher + task-orchestration update

- skills-paperclip/_shared/: heartbeat-interaction.md, paperclip-conventions.md
  (extracted from inlined convention blocks in prior stages; Stage 5 makes this DRY)
- skills-paperclip/brainstorming/: PM skill (heavy rewrite; visual companion dropped)
- skills-paperclip/writing-plans/: Tech Lead plan authoring (concrete schemas,
  needsDesignPolish Stage 6 hook, writes to .planDocument)
- skills-paperclip/pipeline-dispatcher/: NEW greenfield skill; replaces
  using-superpowers; per-role routing in heartbeat model
- skills-paperclip/task-orchestration/SKILL.md: Stage 5 revision — remove
  description fallback in First Wake (plan is now always in .planDocument);
  read needsDesignPolish per slice into subtask descriptions (read-only in
  Stage 5; Stage 6 will spawn Designer subtasks on true)

Approval gate for spec + plan + final review uses status: in_review +
assigneeAgentId PATCH (combined in one call), NOT POST /api/approvals —
the approval table supports only hire_agent/approve_ceo_strategy/
budget_override_required (packages/shared/src/constants.ts:203). See
spec §5.2 amendment in prior commit."
```

- [ ] **Step 3: Capture the Stage 5 pin SHA**

```bash
STAGE5_PIN_SHA=$(git rev-parse HEAD)
echo "Stage 5 pin SHA: $STAGE5_PIN_SHA"
echo "export STAGE5_PIN_SHA=\"$STAGE5_PIN_SHA\"" >> ~/.paperclipowers-stage5.env
```

Expected: 40-char SHA. Appended to env file.

- [ ] **Step 4: Backfill the Stage 5 pin SHA into task-orchestration/UPSTREAM.md**

```bash
sed -i.bak "s|<captured at Task 8 Step 4>|$STAGE5_PIN_SHA|" skills-paperclip/task-orchestration/UPSTREAM.md
rm skills-paperclip/task-orchestration/UPSTREAM.md.bak
grep "Pin SHA for Stage 5" skills-paperclip/task-orchestration/UPSTREAM.md
```

Expected: line shows the actual SHA. Create a follow-up commit for this one trivial backfill:

```bash
git add skills-paperclip/task-orchestration/UPSTREAM.md
git diff --cached
git commit -m "docs(paperclipowers): backfill Stage 5 pin SHA into task-orchestration/UPSTREAM.md"
# Re-capture the SHA — we want the skill import to point at this commit, which is the true Stage 5 end
STAGE5_PIN_SHA=$(git rev-parse HEAD)
echo "Updated STAGE5_PIN_SHA: $STAGE5_PIN_SHA"
sed -i.bak "s|^export STAGE5_PIN_SHA=.*|export STAGE5_PIN_SHA=\"$STAGE5_PIN_SHA\"|" ~/.paperclipowers-stage5.env
rm ~/.paperclipowers-stage5.env.bak
```

- [ ] **Step 5: Push both commits to GitHub**

```bash
git log --oneline -5
git push origin paperclip-adaptation
```

Expected: push succeeds. 3 commits ahead of the remote before Stage 5 (Task 2 spec amendment + skill commit + SHA backfill); after push, `git log origin/paperclip-adaptation..paperclip-adaptation` should be empty.

- [ ] **Step 6: Confirm skill files are visible on GitHub**

```bash
curl -sfS "https://raw.githubusercontent.com/henriquerferrer/paperclipowers/paperclip-adaptation/skills-paperclip/pipeline-dispatcher/SKILL.md" | head -5
```

Expected: the frontmatter `---\nname: pipeline-dispatcher\n...` appears. If the raw.githubusercontent.com fetch 404s, the push didn't propagate yet — wait 30s and retry.

- [ ] **Step 7: Import the three new skills to the test company**

Reuse Stage 2's import payload shape with parent-directory URL. Write the payload file:

```bash
source ~/.paperclipowers-stage5.env
cat > /tmp/stage5-import.json <<EOF
{
  "source": "https://github.com/henriquerferrer/paperclipowers/tree/paperclip-adaptation/skills-paperclip",
  "sourceType": "github",
  "metadata": {
    "repoUrl": "https://github.com/henriquerferrer/paperclipowers",
    "repoRef": "paperclip-adaptation",
    "repoPath": "skills-paperclip",
    "description": "Stage 5 import — brainstorming, writing-plans, pipeline-dispatcher"
  },
  "trustLevel": "markdown_only"
}
EOF
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/stage5-import.json \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" | jq '[.[] | {key, slug, sourceRef}] | sort_by(.key)'
```

Expected: 8 entries in the response (one per skill directory containing a SKILL.md — four Engineer + task-orchestration + three new = 8). All should have `sourceRef == $STAGE5_PIN_SHA`. The four Engineer skills + task-orchestration are re-imported; content is byte-identical since the Stage 4 import (Stage 4 Anomaly 4 pattern) — only `sourceRef` drifts to the new commit.

If the endpoint reports "skill already exists with different SHA" on the 5 existing entries, that's expected — the importer overwrites `sourceRef`. If it reports an error on any NEW skill, STOP and inspect the URL/payload.

- [ ] **Step 8: Verify company skill library now has 8 paperclipowers skills**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.key | test("henriquerferrer/paperclipowers/")) | {key, slug, sourceRef: (.sourceRef[0:12])}] | sort_by(.key)'
```

Expected: 8 entries, all with sourceRef prefix matching the first 12 chars of `$STAGE5_PIN_SHA`. List must include:
- `brainstorming`
- `code-review`
- `pipeline-dispatcher`
- `systematic-debugging`
- `task-orchestration`
- `test-driven-development`
- `verification-before-completion`
- `writing-plans`

- [ ] **Step 9: Capture the three new skill keys into env**

```bash
cat >> ~/.paperclipowers-stage5.env <<'EOF'
export BRAINSTORMING_SKILL_KEY="henriquerferrer/paperclipowers/brainstorming"
export WRITING_PLANS_SKILL_KEY="henriquerferrer/paperclipowers/writing-plans"
export DISPATCHER_SKILL_KEY="henriquerferrer/paperclipowers/pipeline-dispatcher"
EOF
source ~/.paperclipowers-stage5.env
env | grep -E "SKILL_KEY=" | wc -l
```

Expected: at least 8 skill keys exported (4 Engineer + task-orchestration from Stage 4 env + 3 new).

---

## Task 9: Hire PM agent (`stage5-pm`, role=pm)

**Files:** Modifies Paperclip state. Updates `~/.paperclipowers-stage5.env`.

**Context:** PM uses `brainstorming` skill + `pipeline-dispatcher`. Role = `pm` (confirmed live at plan-write). When board is the actor (cookie auth), `POST /api/companies/:id/agents` returns `status: idle` immediately — `requireBoardApprovalForNewAgents: true` only gates agent-created-by-agent hires.

- [ ] **Step 1: Build and POST the hire payload**

```bash
source ~/.paperclipowers-stage5.env
cat > /tmp/hire-pm.json <<EOF
{
  "name": "stage5-pm",
  "role": "pm",
  "title": "Product Manager",
  "adapterType": "claude_local",
  "adapterConfig": {
    "paperclipSkillSync": {
      "desiredSkills": [
        "paperclipai/paperclip/paperclip",
        "paperclipai/paperclip/paperclip-create-agent",
        "paperclipai/paperclip/paperclip-create-plugin",
        "paperclipai/paperclip/para-memory-files",
        "$BRAINSTORMING_SKILL_KEY",
        "$DISPATCHER_SKILL_KEY",
        "$REVIEW_SKILL_KEY"
      ]
    }
  }
}
EOF
# Note: REVIEW_SKILL_KEY is the code-review skill key (for receiving-review flows).
# If REVIEW_SKILL_KEY wasn't in your env, set it:
#   export REVIEW_SKILL_KEY="henriquerferrer/paperclipowers/code-review"
cat /tmp/hire-pm.json | jq .desiredSkills
```

Expected: 7 skills listed — 4 bundled + brainstorming + pipeline-dispatcher + code-review.

```bash
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/hire-pm.json \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq '{id, name, role, status, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills | length}'
```

Expected:
```json
{"id":"<uuid>","name":"stage5-pm","role":"pm","status":"idle","desiredSkills":7}
```

- [ ] **Step 2: Capture PM agent ID**

```bash
PM_AGENT_ID=$(curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq -r '.[] | select(.name == "stage5-pm") | .id')
echo "PM_AGENT_ID=$PM_AGENT_ID"
echo "export PM_AGENT_ID=\"$PM_AGENT_ID\"" >> ~/.paperclipowers-stage5.env
```

Expected: a UUID. Appended to env.

- [ ] **Step 3: Pause the PM agent (to prevent stray timer wakes before Task 13)**

```bash
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$PM_AGENT_ID/pause" | jq '{id, status}'
```

Expected: `{"id":"<uuid>","status":"paused"}`. Task 13 resumes all four agents immediately before the feature-request is created.

- [ ] **Step 4: Verify PM has the 7 skills (runtime view)**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$PM_AGENT_ID/skills" \
  | jq '{mode, desiredSkills, entriesCount: (.entries | length)}'
```

Expected: `mode` non-error, `desiredSkills` lists all 7 keys, `entries` has 7 matching rows.

---

## Task 10: Hire Reviewer agent (`stage5-reviewer`, role=qa)

**Files:** Modifies Paperclip state. Updates `~/.paperclipowers-stage5.env`.

**Context:** Single consolidated Reviewer role (Stage 2 resolved decision). Uses `code-review` skill (performing mode — Part 1 of that skill) across all three review triggers. Role = `qa` (closest to reviewer semantics; `reviewer` is not a valid enum). No other paperclipowers skills needed — Reviewer doesn't perform TDD, doesn't write plans, doesn't orchestrate. `pipeline-dispatcher` routes the Reviewer into `code-review` on `issue_assigned` wake with `status: in_review`.

- [ ] **Step 1: Build and POST hire payload**

```bash
source ~/.paperclipowers-stage5.env
cat > /tmp/hire-reviewer.json <<EOF
{
  "name": "stage5-reviewer",
  "role": "qa",
  "title": "Reviewer",
  "adapterType": "claude_local",
  "adapterConfig": {
    "paperclipSkillSync": {
      "desiredSkills": [
        "paperclipai/paperclip/paperclip",
        "paperclipai/paperclip/paperclip-create-agent",
        "paperclipai/paperclip/paperclip-create-plugin",
        "paperclipai/paperclip/para-memory-files",
        "$REVIEW_SKILL_KEY",
        "$DISPATCHER_SKILL_KEY"
      ]
    }
  }
}
EOF
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/hire-reviewer.json \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq '{id, name, role, status, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills | length}'
```

Expected:
```json
{"id":"<uuid>","name":"stage5-reviewer","role":"qa","status":"idle","desiredSkills":6}
```

(4 bundled + code-review + pipeline-dispatcher.)

- [ ] **Step 2: Capture Reviewer ID + pause**

```bash
REVIEWER_AGENT_ID=$(curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq -r '.[] | select(.name == "stage5-reviewer") | .id')
echo "REVIEWER_AGENT_ID=$REVIEWER_AGENT_ID"
echo "export REVIEWER_AGENT_ID=\"$REVIEWER_AGENT_ID\"" >> ~/.paperclipowers-stage5.env

curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$REVIEWER_AGENT_ID/pause" | jq '{id, status}'
```

Expected: UUID captured; `status: paused`.

- [ ] **Step 3: Verify both new agents present, paused, skill counts correct**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq '[.[] | {name, role, status, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills | length}] | sort_by(.name)'
```

Expected (4 agents total):
```json
[
  {"name":"stage1-tester","role":"engineer","status":"paused","desiredSkills":8},
  {"name":"stage4-tech-lead","role":"engineer","status":"paused","desiredSkills":5},
  {"name":"stage5-pm","role":"pm","status":"paused","desiredSkills":7},
  {"name":"stage5-reviewer","role":"qa","status":"paused","desiredSkills":6}
]
```

Tech Lead and Engineer skill counts still reflect Stage 4 state — Task 11 updates them.

---

## Task 11: Update Tech Lead and Engineer skill sets

**Files:** Modifies Paperclip state.

**Context:** Tech Lead needs `writing-plans` (new) + `pipeline-dispatcher` (new) added to its existing `task-orchestration` + bundled skills. Engineer needs `pipeline-dispatcher` added to its 4 Engineer skills + bundled.

**Endpoint verified at plan-write by reading server source:**

- Route: `POST /api/agents/:id/skills/sync` at `/app/server/src/routes/agents.ts:856`
- Schema: `agentSkillSyncSchema = z.object({ desiredSkills: z.array(z.string().min(1)) })` at `/app/packages/shared/src/validators/adapter-skills.ts:51`
- Handler: replaces `adapterConfig.paperclipSkillSync.desiredSkills` with the request's array (full-list sync, NOT a delta), records a config revision with `source: "skill-sync"`, invokes the adapter's `syncSkills` hook for runtime materialization, returns the full runtime snapshot `{ mode, desiredSkills, entries, warnings }`.

The `PATCH /api/agents/:id` adapterConfig path also exists as a fallback but is NOT recommended — it bypasses the `resolveDesiredSkillAssignment` helper that `/skills/sync` runs, which is responsible for computing the runtime skill entries from the requested keys. Use the PATCH path only if `/skills/sync` 404s on a future Paperclip version.

- [ ] **Step 1: Update Tech Lead skills**

```bash
source ~/.paperclipowers-stage5.env
cat > /tmp/tl-sync.json <<EOF
{
  "desiredSkills": [
    "paperclipai/paperclip/paperclip",
    "paperclipai/paperclip/paperclip-create-agent",
    "paperclipai/paperclip/paperclip-create-plugin",
    "paperclipai/paperclip/para-memory-files",
    "$TASK_ORCH_SKILL_KEY",
    "$WRITING_PLANS_SKILL_KEY",
    "$DISPATCHER_SKILL_KEY",
    "$REVIEW_SKILL_KEY"
  ]
}
EOF
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/tl-sync.json \
  "$PAPERCLIP_API_URL/api/agents/$TECH_LEAD_AGENT_ID/skills/sync" | jq '.' | head -40
```

Expected: success response with the Tech Lead's new desiredSkills list (8 entries: 4 bundled + task-orchestration + writing-plans + pipeline-dispatcher + code-review-for-receiving). If this endpoint 404s, use:

```bash
cat > /tmp/tl-patch.json <<EOF
{
  "adapterConfig": {
    "paperclipSkillSync": {
      "desiredSkills": [
        "paperclipai/paperclip/paperclip",
        "paperclipai/paperclip/paperclip-create-agent",
        "paperclipai/paperclip/paperclip-create-plugin",
        "paperclipai/paperclip/para-memory-files",
        "$TASK_ORCH_SKILL_KEY",
        "$WRITING_PLANS_SKILL_KEY",
        "$DISPATCHER_SKILL_KEY",
        "$REVIEW_SKILL_KEY"
      ]
    }
  }
}
EOF
curl -s -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/tl-patch.json \
  "$PAPERCLIP_API_URL/api/agents/$TECH_LEAD_AGENT_ID" \
  | jq '{status, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills}'
```

- [ ] **Step 2: Update Engineer skills (add pipeline-dispatcher)**

```bash
cat > /tmp/eng-sync.json <<EOF
{
  "desiredSkills": [
    "paperclipai/paperclip/paperclip",
    "paperclipai/paperclip/paperclip-create-agent",
    "paperclipai/paperclip/paperclip-create-plugin",
    "paperclipai/paperclip/para-memory-files",
    "$VBC_SKILL_KEY",
    "$TDD_SKILL_KEY",
    "$DEBUG_SKILL_KEY",
    "$REVIEW_SKILL_KEY",
    "$DISPATCHER_SKILL_KEY"
  ]
}
EOF
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/eng-sync.json \
  "$PAPERCLIP_API_URL/api/agents/$ENGINEER_AGENT_ID/skills/sync" | jq '{desiredSkills: .desiredSkills, entryCount: (.entries | length)}'
# Fallback (if a future Paperclip version removes /skills/sync):
#   PATCH /api/agents/:id with {adapterConfig: {paperclipSkillSync: {desiredSkills: [...]}}} — see Step 1 fallback.
```

Expected: 9 skills on Engineer (4 bundled + 4 Engineer + pipeline-dispatcher).

- [ ] **Step 3: Verify all four agents' skill sets**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq '[.[] | {name, role, status, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills | length}] | sort_by(.name)'
```

Expected:
```json
[
  {"name":"stage1-tester","role":"engineer","status":"paused","desiredSkills":9},
  {"name":"stage4-tech-lead","role":"engineer","status":"paused","desiredSkills":8},
  {"name":"stage5-pm","role":"pm","status":"paused","desiredSkills":7},
  {"name":"stage5-reviewer","role":"qa","status":"paused","desiredSkills":6}
]
```

---

## Task 12: Materialization check + CLI-ism regression

**Files:** Read-only inspection of container state.

**Context:** All 8 paperclipowers skills (4 Engineer + task-orchestration + 3 new) must materialize correctly before any agent is resumed. Runtime path: `/paperclip/instances/default/skills/$COMPANY_ID/__runtime__/<slug>--<hash>/`. Skills materialize lazily on first wake, so Task 12 triggers materialization via a read-only inspection of the directory AFTER resume (Task 13) OR forces materialization via a no-op wake.

Simplest: skip pre-materialization, run Task 13's feature kickoff, then inspect materialization mid-flight. But a runtime CLI-ism grep is worthwhile before live flight — catches any leaks in the new skills before agents see them.

- [ ] **Step 1: Wake the PM once with a no-op issue to force materialization**

Create a throwaway probe issue assigned to the PM. Not a feature — just something that causes the scheduler to dispatch a heartbeat and materialize the PM's skills.

```bash
source ~/.paperclipowers-stage5.env
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$PM_AGENT_ID/resume" | jq '.status'
cat > /tmp/probe-issue.json <<EOF
{
  "title": "Stage 5 materialization probe",
  "description": "No-op issue to trigger skill materialization on the PM. Respond with 'materialization probe complete' and mark done.",
  "assigneeAgentId": "$PM_AGENT_ID",
  "status": "todo"
}
EOF
PROBE_ISSUE=$(curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/probe-issue.json \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" | jq -r '.id')
echo "Probe issue: $PROBE_ISSUE"
echo "export STAGE5_PROBE_ISSUE=\"$PROBE_ISSUE\"" >> ~/.paperclipowers-stage5.env
```

Wait ~60 seconds for the scheduler to pick it up and materialize.

```bash
sleep 60
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$PM_AGENT_ID&limit=3" \
  | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId, finishedAt}]'
```

Expected: at least one terminal run, `wakeReason: "issue_assigned"`, `issueId` matches probe issue.

- [ ] **Step 2: Inspect materialized skills on disk**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'ls -la /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/'"
```

Expected: 8+ directories (one per paperclipowers skill). Verify the three new ones exist:

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'ls /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ | grep -E \"brainstorming|writing-plans|pipeline-dispatcher\"'"
```

Expected: three lines, each like `brainstorming--<hash>`, `writing-plans--<hash>`, `pipeline-dispatcher--<hash>`.

- [ ] **Step 3: CLI-ism grep across all paperclipowers materialized skills**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__ -name SKILL.md | xargs grep -l -E \"your human partner|in this message\" 2>/dev/null'" || echo "CLEAN (no file matched any CLI-ism)"
```

Expected: `CLEAN`. If any file matches: STOP, identify the skill, fix the SKILL.md in the repo, re-commit, re-import.

- [ ] **Step 4: Verify the three new UPSTREAM.md files materialized too (Stage 2 Anomaly 3 — UPSTREAM alongside SKILL)**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__ -name UPSTREAM.md | sort'"
```

Expected: 8 lines (one UPSTREAM.md per skill, including brainstorming/writing-plans/pipeline-dispatcher).

- [ ] **Step 5: Clean up the probe issue and re-pause PM**

```bash
curl -s -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data '{"status":"cancelled"}' \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PROBE_ISSUE" | jq '{id, status}'

curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$PM_AGENT_ID/pause" | jq '{id, status}'
```

Expected: probe issue `cancelled`, PM `paused`. Task 13 re-resumes all four agents.

---

## Task 13: Resume agents, create parent feature issue, kick off the pipeline

**Files:** Modifies Paperclip state (agent resume + issue creation).

**Context:** Stage 5's end-to-end test runs on a small feature chosen to exercise every pipeline phase without spending too much budget. Target feature: add a `workspace-log summary` command that prints per-day totals of log entries (builds on the Stage 4 workspace-log CLI the Engineer already has committed in its workspace). This is small enough that the plan has 2-3 vertical slices, large enough that the PM has real Q&A ground (output format? time-range filtering? empty-state behaviour?), and touches the existing test suite.

The feature creation combines `assigneeAgentId + status: "todo"` in ONE PATCH (Stage 4 Anomaly 1) so the PM's `issue_assigned` wake fires on creation.

- [ ] **Step 1: Resume all four agents**

```bash
source ~/.paperclipowers-stage5.env
for aid in "$PM_AGENT_ID" "$TECH_LEAD_AGENT_ID" "$ENGINEER_AGENT_ID" "$REVIEWER_AGENT_ID"; do
  curl -s -X POST \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/agents/$aid/resume" | jq '{id, status}'
done
```

Expected: four lines, each `{"id":"<uuid>","status":"idle"}`.

- [ ] **Step 2: Create the parent feature issue with PM assigned AND status=todo**

```bash
cat > /tmp/stage5-feature.json <<EOF
{
  "title": "workspace-log summary command",
  "description": "Extend the workspace-log CLI (bin/workspace-log.js) with a new subcommand: \`workspace-log summary\`. The summary should produce a human-readable report of log activity — counts per day, or grouped by label, or similar; exact shape TBD during brainstorming. Builds on the existing \`init\`, \`note\`, and \`last\` subcommands already in the workspace.\n\nThis is a Stage 5 pipeline end-to-end validation: PM should brainstorm the exact output format via Q&A with the board; Tech Lead plans the implementation; Engineer builds; Reviewer checks at spec/plan/final gates.",
  "assigneeAgentId": "$PM_AGENT_ID",
  "status": "todo"
}
EOF
STAGE5_PARENT_ISSUE=$(curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/stage5-feature.json \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" | jq -r '.id')
echo "STAGE5_PARENT_ISSUE=$STAGE5_PARENT_ISSUE"
echo "export STAGE5_PARENT_ISSUE=\"$STAGE5_PARENT_ISSUE\"" >> ~/.paperclipowers-stage5.env
```

Expected: UUID. Assigning at CREATE (not a subsequent PATCH) + `status: "todo"` fires the `issue_assigned` wake on the PM.

- [ ] **Step 3: Verify the wake fired**

Wait ~60 seconds for scheduler:

```bash
sleep 60
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$PM_AGENT_ID&limit=3" \
  | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId, startedAt}]'
```

Expected: the most-recent run has `wakeReason: "issue_assigned"` and `issueId == $STAGE5_PARENT_ISSUE`. Status `running` initially, then `succeeded` once complete (~60-180s for a brainstorming heartbeat).

If the most-recent run is NOT on the new issue: the PM hasn't woken yet. Wait another minute and re-check. If still nothing after 3 minutes total, confirm PM is `idle` (not `paused`) and the parent issue's `assigneeAgentId` matches PM.

- [ ] **Step 4: Capture the PM's first run ID**

```bash
STAGE5_RUN_PM_1=$(curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$PM_AGENT_ID&limit=1" \
  | jq -r '.[0].id')
echo "STAGE5_RUN_PM_1=$STAGE5_RUN_PM_1"
echo "export STAGE5_RUN_PM_1=\"$STAGE5_RUN_PM_1\"" >> ~/.paperclipowers-stage5.env
```

Proceed to Task 14 for behavioral observation across the full pipeline.

---

## Task 14: End-to-end behavioural observation (all pipeline phases)

**Files:** Read-only inspection; writes comments on the parent issue as the board persona.

**Context:** This is the load-bearing behavioural validation. The entire pipeline runs autonomously once the board answers questions + approves at three gates. Observe each phase: PM brainstorming, Reviewer spec review, board spec approval, Tech Lead plan writing, Reviewer plan review, board plan approval, Tech Lead orchestration, Engineer subtask execution, Reviewer final combined review, board PR-merge gate.

Each phase has its own assertion criteria. Capture heartbeat run IDs, costs, and any anomalies. Expected total wall-clock: 30-90 minutes depending on scheduler cadence and heartbeat durations. Total budget: target ≤ $15 (Stage 4 was $3.72 for 10 heartbeats; Stage 5 is ~20-30 heartbeats expected).

Organize as phases; each phase has: WAIT, OBSERVE, ACT (if board action required).

- [ ] **Step 1 — Phase A (PM brainstorm Q&A round 1)**

WAIT: PM's first heartbeat runs to completion (~60-180s typical for Opus brainstorming).

OBSERVE: check the parent issue for a new PM comment with 2-3 clarifying questions.

```bash
source ~/.paperclipowers-stage5.env
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/comments?limit=5" \
  | jq '[.[] | {id, authorAgentId, authorUserId, body: (.body[0:200])}]'
```

Expected: one comment authored by `$PM_AGENT_ID`, body contains 2-3 numbered questions in the format specified in `brainstorming/SKILL.md` § First Wake. If the PM posted 5+ questions or only 1 question, the skill's batching guidance isn't holding — note for Stage 5 results doc, continue anyway.

ACT: as the board, post a reply answering the PM's questions. Use a realistic board answer (not minimal) so the PM has enough to write a spec.

> **⚠️ DO NOT COPY THIS PAYLOAD BLINDLY.** The JSON below is an ILLUSTRATIVE TEMPLATE assuming the PM asked about output format, time-range filtering, and empty-state behaviour. Read the PM's actual comment first (the `GET /comments` call above), then craft a reply that answers THEIR questions one-for-one. A blind copy produces an incoherent Q&A thread because the PM's questions won't match the template's numbered answers — the PM's next heartbeat reads your reply, reconstructs context, and will either ask follow-ups to clarify the mismatch (wasted round) or write a spec that mixes the board's intent with the template's hypothetical (wrong deliverable).

Template (adapt to actual questions):

```bash
cat > /tmp/board-reply-1.json <<'EOF'
{
  "body": "Good questions. Here are my answers:\n\n1. Output format: plain text, one line per day with `YYYY-MM-DD    N entries` style. No JSON output needed.\n2. Time range: support `--since=YYYY-MM-DD` optional flag; default is all-time.\n3. Empty state: print `No entries to summarize.` and exit 0 — not an error.\n\nProceed with the spec."
}
EOF
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/board-reply-1.json \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/comments" | jq '{id}'
```

**Procedure for actual execution:**
1. Read the PM's comment body from the `GET /comments` output above.
2. Open `/tmp/board-reply-1.json` with the `Write` tool (or your editor).
3. Replace the `body` string with a reply that answers the PM's exact questions in order. Preserve the `\n\n` structure for readability; use `\n` (literal two-char sequence) inside the JSON string.
4. Run the curl POST.

- [ ] **Step 2 — Phase B (PM writes spec, transitions to in_review)**

WAIT: PM's second heartbeat on `issue_commented` wake (~60-180s).

OBSERVE: expect the PM to either ask another round of questions OR write the spec.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq '{status, assigneeAgentId, documentSummaries: [.documentSummaries[] | {key, title, latestRevisionNumber}]}'

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/documents/spec" 2>/dev/null \
  | jq '{key, title, latestRevisionNumber, body: (.body[0:400])}'
```

Expected: document `spec` exists; issue `status: "in_review"`; `assigneeAgentId == $REVIEWER_AGENT_ID`. If the spec has `## Open Questions` with real ambiguities, that's acceptable per spec §6.1 (PM limited to 3 rounds).

If the PM asked a second round of Q&A instead of writing the spec, answer it and wait for Phase B to land. If 3 rounds happen without a spec, escalation should trigger — PM sets `status: blocked`.

- [ ] **Step 3 — Phase C (Reviewer spec review)**

WAIT: Reviewer's heartbeat on `issue_assigned` wake (fresh session per §5.4 per-issue keying). Typical duration 60-120s.

OBSERVE: Reviewer's comment on the parent with categorized findings.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/comments?limit=10" \
  | jq '[.[] | select(.authorAgentId == "'$REVIEWER_AGENT_ID'") | {id, body: (.body[0:600])}]'

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq '{status, assigneeAgentId}'
```

Expected: Reviewer comment present using `code-review/reviewer-prompt.md` format (Strengths / Issues / Recommendations / Assessment). Issue `status: "todo"` with assignee set back to PM (rejection) or forward (approval path). Per `code-review` skill, on approval, Reviewer hands back to board or original author; specifics depend on Reviewer's interpretation.

If Reviewer approves (`Ready to merge: Yes` in findings): proceed to Step 4.
If Reviewer rejects (`Ready to merge: No` or `With fixes`): loop — wait for PM revision, then Reviewer re-review. Limit 3 cycles.

- [ ] **Step 4 — Phase D (Board spec approval)**

ACT: simulate board approving the spec — PATCH the parent to Tech Lead with status todo.

```bash
cat > /tmp/board-approve-spec.json <<EOF
{
  "status": "in_progress",
  "assigneeAgentId": "$TECH_LEAD_AGENT_ID"
}
EOF
curl -s -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/board-approve-spec.json \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq '{id, status, assigneeAgentId}'

# Board comment stating approval (optional but useful context for Tech Lead)
cat > /tmp/board-approve-comment.json <<'EOF'
{"body":"Spec approved. Proceeding to plan writing."}
EOF
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/board-approve-comment.json \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/comments" | jq '{id}'
```

- [ ] **Step 5 — Phase E (Tech Lead writes plan)**

WAIT: Tech Lead's heartbeat on `issue_assigned` wake (fresh per-issue session; this issue hasn't been on the Tech Lead's session slot before). Typical 90-180s.

OBSERVE: plan document written, issue transitioned to `in_review` + Reviewer.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq '{status, assigneeAgentId, planDocument: (.planDocument | {key, title, latestRevisionNumber, body: (.body[0:800])})}'
```

Expected: `.planDocument` non-null, `key: "plan"`, `body` includes `## Vertical Slices` section with 2-3 `### Slice N:` blocks, each with concrete `Inputs:` and `Outputs:` TypeScript schemas and a `needsDesignPolish: false` declaration. `status: "in_review"`, `assigneeAgentId == $REVIEWER_AGENT_ID`.

Assertion: grep the plan body for `needsDesignPolish` — must appear once per slice.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq -r '.planDocument.body' | grep -c "needsDesignPolish"
```

Expected: N ≥ 2 (number of slices).

- [ ] **Step 6 — Phase F (Reviewer plan review)**

WAIT: Reviewer's `issue_assigned` wake (fresh — per-issue keying across the three review passes on this same issue means sessions may resume if Reviewer's prior spec-review session is still cached for this issueId).

OBSERVE: findings comment.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/comments?limit=10" \
  | jq '[.[] | select(.authorAgentId == "'$REVIEWER_AGENT_ID'") | {id, createdAt, body: (.body[0:600])}] | .[-1]'
```

Expected: new findings comment from Reviewer, structured per `code-review` format. Verdict shapes assign-back behaviour: approve → Tech Lead/board; reject → Tech Lead for revision.

If needed, loop Phase F ↔ Tech Lead revision up to 3 cycles per spec §6.1.

- [ ] **Step 7 — Phase G (Board plan approval)**

ACT: simulate board approving plan — PATCH to Tech Lead, `status: in_progress`.

```bash
cat > /tmp/board-approve-plan.json <<EOF
{
  "status": "in_progress",
  "assigneeAgentId": "$TECH_LEAD_AGENT_ID"
}
EOF
curl -s -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/board-approve-plan.json \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq '{status, assigneeAgentId}'

cat > /tmp/board-plan-comment.json <<'EOF'
{"body":"Plan approved. Proceed to task orchestration."}
EOF
curl -s -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/board-plan-comment.json \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/comments" | jq '{id}'
```

- [ ] **Step 8 — Phase H (Tech Lead orchestration: decompose into subtasks)**

WAIT: Tech Lead's `issue_assigned` wake. Session should RESUME from Phase E (same issueId). Typical 60-120s. The Tech Lead's pipeline-dispatcher routes into `task-orchestration` because `.planDocument` is populated and no subtasks exist.

OBSERVE: subtasks created under the parent.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues?parentId=$STAGE5_PARENT_ISSUE&limit=10" \
  | jq '[.[] | {identifier, status, assigneeAgentId, blockedBy: [.blockedBy[] | .identifier]}]'
```

Expected: N children (matching plan's slice count), all `status: "todo"`. FIRST child has `assigneeAgentId == $ENGINEER_AGENT_ID`, `blockedBy: []`. Followers: `assigneeAgentId: null`, `blockedBy: ["<predecessor-identifier>"]` (RULE 1 progressive assignment).

Capture the subtask IDs:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues?parentId=$STAGE5_PARENT_ISSUE&limit=10" \
  | jq -r '.[].id' | nl -ba | while read i id; do
    echo "export STAGE5_SUB_$i=\"$id\"" >> ~/.paperclipowers-stage5.env
  done
source ~/.paperclipowers-stage5.env
env | grep -E "^STAGE5_SUB_"
```

- [ ] **Step 9 — Phase I (Engineer subtask execution, sequential)**

WAIT: each subtask runs sequentially. Engineer wakes on first subtask's `issue_assigned` (fresh session), works, posts `@stage4-tech-lead DONE — ...`, marks subtask `done`. Tech Lead wakes on mention, PATCHes next subtask's assignee after RULE 2 agent-status probe. Repeat per subtask.

Polling loop (do NOT hot-poll; 60s intervals):

```bash
while true; do
  sleep 60
  source ~/.paperclipowers-stage5.env
  STATE=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues?parentId=$STAGE5_PARENT_ISSUE&limit=10" \
    | jq -r '[.[] | "\(.identifier)/\(.status)"] | join(" ")')
  echo "[$(date +%H:%M:%S)] subtasks: $STATE"
  # Break when all children are terminal
  ALL_TERMINAL=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues?parentId=$STAGE5_PARENT_ISSUE&limit=10" \
    | jq '[.[] | .status] | all(. == "done" or . == "blocked" or . == "cancelled")')
  [ "$ALL_TERMINAL" = "true" ] && break
done
```

Expected: subtasks transition sequentially `todo → in_progress → done`. Each transition triggers the next subtask's assignment (Tech Lead mention wake → PATCH). Total wall-clock for N subtasks: roughly N × (Engineer time 60-180s + TL time 30-90s).

ASSERT per subtask:
- Engineer posted `@<tech-lead-name> DONE — ... Commits: <sha>` mention comment
- Subtask status `done`
- Engineer's workspace has a new commit (inspect via `ssh nas "/usr/local/bin/docker exec paperclip sh -c 'git -C /paperclip/instances/default/workspaces/$ENGINEER_AGENT_ID log --oneline -5'"`)

- [ ] **Step 10 — Phase J (Parent transitions to in_review, Reviewer final combined)**

OBSERVE: after the final subtask completes, Tech Lead PATCHes parent to `in_review` (task-orchestration § End-of-Feature Review). Reviewer wakes on `issue_assigned`, performs final combined review.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq '{status, assigneeAgentId}'
```

Expected: `status: "in_review"`, `assigneeAgentId == $REVIEWER_AGENT_ID`.

WAIT: Reviewer's final-combined heartbeat runs. This one is more expensive than spec/plan review — Reviewer reads `git diff`, runs the test suite.

```bash
# Poll until Reviewer's last run on this issue is terminal
sleep 120
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$REVIEWER_AGENT_ID&limit=3" \
  | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId, startedAt, finishedAt}]'
```

Expected: a terminal run with `wakeReason: "issue_assigned"` and `issueId == $STAGE5_PARENT_ISSUE`.

OBSERVE: Reviewer's final comment + status transition.

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE/comments?limit=10" \
  | jq '[.[] | select(.authorAgentId == "'$REVIEWER_AGENT_ID'")] | .[-1] | {id, body: (.body[0:800])}'
```

Expected: final-combined-review comment with verdict (`Ready to merge: Yes/No/With fixes`). On approval: issue should transition to `done` or `status: "todo"` back to board (Reviewer is not authorized to create PRs in the test company context — `code-review/SKILL.md` § 1.5 "Final combined review — if approving" mentions PR creation, but that requires a configured git remote + gh CLI in the workspace; Stage 5 validation accepts the pattern without actual PR creation).

- [ ] **Step 11 — Phase K (Board merge gate — simulate PR approval)**

ACT: assuming Reviewer's final verdict is positive, board marks the parent done.

```bash
cat > /tmp/board-merge.json <<'EOF'
{"status": "done"}
EOF
curl -s -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/board-merge.json \
  "$PAPERCLIP_API_URL/api/issues/$STAGE5_PARENT_ISSUE" \
  | jq '{status, completedAt}'
```

Expected: `status: "done"`, `completedAt` set.

If Reviewer rejected at Phase J: loop Phase I or H as appropriate (open bug subtask OR revise plan). Document which in Stage 5 results.

- [ ] **Step 12 — Capture all heartbeat run IDs and costs for the feature**

```bash
for aid_name in "$PM_AGENT_ID:pm" "$TECH_LEAD_AGENT_ID:tl" "$ENGINEER_AGENT_ID:eng" "$REVIEWER_AGENT_ID:rev"; do
  aid="${aid_name%:*}"
  name="${aid_name#*:}"
  echo "=== $name ($aid) ==="
  curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$aid&limit=20" \
    | jq '[.[] | select(.contextSnapshot.issueId == "'$STAGE5_PARENT_ISSUE'" or (.contextSnapshot.issueId // "" | startswith("")))] | [.[] | {id, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId, duration: ((.finishedAt // "1970-01-01T00:00:00Z") | fromdate) - (.startedAt | fromdate), cached: .usageJson.cachedInputTokens, fresh: .usageJson.inputTokens, out: .usageJson.outputTokens, sessionReused: .usageJson.sessionReused, cost: .usageJson.costUsd}]'
done > /tmp/stage5-runs.json
cat /tmp/stage5-runs.json | head -100
```

Save this file — it becomes Table 1 of the Stage 5 results doc.

- [ ] **Step 13 — Assertions summary**

Compile expected vs actual for Stage 5 results doc:

- [ ] PM posted ≤3 Q&A rounds before writing spec
- [ ] Spec document written to `spec` key (confirmed present)
- [ ] Reviewer fired on `issue_assigned` with `status: in_review` (all 3 gates)
- [ ] Reviewer comments use `code-review/reviewer-prompt.md` format (Strengths / Critical / Important / Minor / Assessment)
- [ ] Plan document written to `plan` key; `.planDocument` top-level populated
- [ ] Plan has ≥2 slices, each with concrete schema + `needsDesignPolish: false`
- [ ] Tech Lead task-orchestration created subtasks matching slice count
- [ ] Progressive assignment visible (all followers have `assigneeAgentId: null` at creation)
- [ ] Engineer posted `@<tech-lead> DONE` mention per subtask
- [ ] Final combined review verdict present
- [ ] Parent reached `done` (or explicit rejection loop documented)
- [ ] Total cost: note value for budget calibration
- [ ] Any skill misfires or self-mention loops: zero expected; note any

---

## Task 15: Stage 5 results doc + rollback

**Files:** Create: `docs/plans/2026-04-14-stage-5-results.md`. Modifies Paperclip state (pause agents).

**Context:** Mirror the Stage 4 results doc structure: captured identifiers, rule-by-rule verification (where applicable), per-phase behavioural evidence, heartbeat cost summary, cross-heartbeat observations, anomalies, rollback state, follow-ups.

Leave skills + agents in the company; pause all agents so no stray timer wakes between Stage 5 and Stage 6. Stage 6 resumes and adds the Designer.

- [ ] **Step 1: Author `docs/plans/2026-04-14-stage-5-results.md`**

Use the `Write` tool. Populate from the observations captured in Task 14. Template:

```markdown
# Stage 5 Validation Results

**Date completed:** 2026-04-<actual date>
**Outcome:** SUCCESS / SUCCESS WITH CAVEATS / PARTIAL — <summary sentence tied to assertions in Task 14 Step 13>
**Tracking branch:** `paperclip-adaptation`
**Stage 5 commit range:** `<Stage 4 end SHA>..<STAGE5_PIN_SHA>`
**Prior state:** Stage 4 closed at `d08f1f9`; 5 skills at `17df7271`; 2 agents paused.

## Captured identifiers

| Field | Value |
|-------|-------|
| Company | `Paperclipowers Test` — `$COMPANY_ID` |
| PM agent | `stage5-pm` — `$PM_AGENT_ID`, role `pm` |
| Reviewer agent | `stage5-reviewer` — `$REVIEWER_AGENT_ID`, role `qa` |
| Tech Lead agent | `stage4-tech-lead` — `$TECH_LEAD_AGENT_ID`, role `engineer` (named tech-lead) |
| Engineer agent | `stage1-tester` — `$ENGINEER_AGENT_ID`, role `engineer` |
| Brainstorming skill | `henriquerferrer/paperclipowers/brainstorming` |
| Writing-plans skill | `henriquerferrer/paperclipowers/writing-plans` |
| Pipeline-dispatcher skill | `henriquerferrer/paperclipowers/pipeline-dispatcher` |
| Stage 5 pin SHA | `$STAGE5_PIN_SHA` |
| Parent feature issue | PAP-<N> — `$STAGE5_PARENT_ISSUE` |
| Subtasks | PAP-<N+1>..PAP-<N+M> — captured in env |

## Pipeline phase verification

### Phase A-B: PM brainstorming
- Q&A rounds: <actual>
- Spec document written: YES/NO + revision count
- Assertion: PM capped at ≤3 Q&A rounds: PASS/FAIL

### Phase C-D: Reviewer spec review → Board approval
- Reviewer findings format: matches code-review reviewer-prompt.md? YES/NO
- Categorized findings: Critical <n>, Important <n>, Minor <n>
- Outcome: approved / rejected <n> times
- Board approval gate: PATCH to Tech Lead with status in_progress: YES/NO

### Phase E-G: Tech Lead writing-plans → Reviewer → Board
- Plan document written to `.planDocument`: YES/NO
- Slice count: <n>
- needsDesignPolish flag per slice: present on <n>/<n> slices
- Concrete schemas: present on <n>/<n> slices

### Phase H-I: Tech Lead orchestration + Engineer subtask execution
- Subtasks created: <n> (matches slice count: YES/NO)
- Progressive assignment (RULE 1): PASS/FAIL per chain
- Paused-target check (RULE 2): observed on <n> PATCHes
- Notification Protocol (RULE 3): `@<tl>` mention per subtask: <n>/<n>
- All subtasks terminal: YES/NO
- Workspace commits: <n>

### Phase J-K: Final combined review → Board merge
- Reviewer final verdict: <verdict>
- Parent reached done: YES/NO

## Heartbeat cost summary

| Run | Agent | Issue | Wake reason | Duration | Cached in | Fresh | Out | Cost | SessionReused |
|-----|-------|-------|-------------|----------|-----------|-------|-----|------|---------------|
| (fill from `/tmp/stage5-runs.json`) | | | | | | | | | |

**Totals:** <wall-clock>, <cost>, <tokens>

## Cross-heartbeat observations

- Session resumption in same-issue mention wakes: <observed behavior>
- Fresh sessions on cross-issue Reviewer wakes (spec/plan/final): <observed>
- Tech Lead session across plan writing + orchestration (same issueId): reused?
- Per-issue keying consistent with spec §5.4 amendment: YES/NO

## Anomalies / notes for Stage 6

(Populate from actual observations. Template entries:)

1. <any skill misfires>
2. <any status/assignee race observed>
3. <any Reviewer trigger confusion>
4. <any workspace contamination>
5. <any budget surprises>

## Rollback state

- All four agents paused
- 8 skills remain imported, pinned at `$STAGE5_PIN_SHA`
- Parent + subtask issues all terminal
- Workspace git state captured: <SHA>
- `~/.paperclipowers-stage5.env` retained (mode 600)

## Follow-ups unblocked by Stage 5

1. Stage 6: import ui-ux-pro-max + configure Magic/Figma MCP + hire Designer
2. Stage 6: flip `needsDesignPolish` to `true` in one test slice and verify task-orchestration spawns the Designer subtask
3. Post-Stage-5: `sessionPolicy: forceFreshSession` per-agent flag (carry-forward)
4. Per-subtask Reviewer review (Stage 7+ decision)
5. Paperclip upstream contribution: new `approve_spec` / `approve_plan` approval types (lets the pipeline use first-class approvals instead of status PATCH)

<plus any anomaly-specific follow-ups>
```

Fill in actual values as Task 14 produces them. Commit the results doc separately from Task 16 rollback.

- [ ] **Step 2: Commit results doc**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add docs/plans/2026-04-14-stage-5-results.md
git commit -m "docs(paperclipowers): Stage 5 validation results"
git push origin paperclip-adaptation
```

- [ ] **Step 3: Pause all four agents**

```bash
source ~/.paperclipowers-stage5.env
for aid in "$PM_AGENT_ID" "$TECH_LEAD_AGENT_ID" "$ENGINEER_AGENT_ID" "$REVIEWER_AGENT_ID"; do
  curl -s -X POST \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/agents/$aid/pause" | jq '{id, status}'
done
```

Expected: four lines, all `status: "paused"`.

- [ ] **Step 4: Final state verification**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq '[.[] | {name, status, desiredSkills: .adapterConfig.paperclipSkillSync.desiredSkills | length}] | sort_by(.name)'

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | select(.key | test("henriquerferrer/paperclipowers/"))] | length'
```

Expected: 4 agents all `paused`; 8 paperclipowers skills in the library.

- [ ] **Step 5: Update memory with Stage 5 completion**

Memory update (do manually via the memory system if running inside Claude Code, or document for the operator):

```
Update ~/.claude/projects/-Users-henrique-Documents-paperclip/memory/paperclipowers_project.md:

- Stages 1-5 complete. Five-phase pipeline validated end-to-end.
- Four paperclipowers agents in Paperclipowers Test:
  - stage1-tester (Engineer), stage4-tech-lead (Tech Lead), stage5-pm (PM), stage5-reviewer (Reviewer)
  - All paused between stages
- Eight paperclipowers skills pinned at STAGE5_PIN_SHA
- Stage 6 next: import ui-ux-pro-max + hire Designer + configure Magic/Figma MCP
- Spec §5.2 + §5.4 amendments in Stage 5 reflect live-API reality
```

- [ ] **Step 6: Clean local state**

```bash
chmod 600 ~/.paperclipowers-stage5.env
ls -la ~/.paperclipowers-stage5.env
rm -f /tmp/hire-pm.json /tmp/hire-reviewer.json /tmp/tl-sync.json /tmp/eng-sync.json \
      /tmp/stage5-import.json /tmp/stage5-feature.json /tmp/board-reply-*.json \
      /tmp/board-approve-*.json /tmp/board-plan-comment.json /tmp/board-merge.json \
      /tmp/probe-issue.json /tmp/stage5-runs.json
echo "Stage 5 complete."
```

---

## Plan Self-Review

Before handing the plan to subagent-driven execution:

**1. Spec coverage:**
- Design spec §3 (6 roles) → Tasks 9-11 cover PM + Reviewer hires; Designer deferred but hooked via `needsDesignPolish` flag in Task 5.
- §4.1 removed skills (using-superpowers → pipeline-dispatcher) → Task 6 replaces wholesale.
- §5.1 adaptation rules (substitutions) → Task 3 captures in `_shared/heartbeat-interaction.md`; Tasks 4-6 skills apply them.
- §5.2 approval gate → Task 2 amends spec; Tasks 4-5 skills enforce the amended gate.
- §5.3 batched Q&A → Task 4 brainstorming § First Wake codifies 2-3 per comment.
- §5.4 session keying → Task 2 amends spec per live-server code; Task 3 `heartbeat-interaction.md` references.
- §6 error handling (3x reject, blocker escalation) → Tasks 4-5 both include escalation paths.
- §7 per-agent config → Tasks 9-11 use `adapterConfig.paperclipSkillSync.desiredSkills` per spec.
- §8 Stage 5 → Task 2 amends the Stage 5 scope bullet; Tasks 4-15 are its execution.

**2. Placeholder scan:**
- `<capture at Step N>` markers appear in UPSTREAM.md templates but each has a corresponding "Step N" that fills it. No orphan TBDs.
- Task 14 assertions are templates; numeric values fill during execution, not at plan-write.
- Task 15 results doc is explicitly a template (the stage-results doc is always filled in at execution time — that's its purpose).

**3. Type consistency:**
- `needsDesignPolish: boolean` used consistently in Tasks 5 (writing-plans emits) and 7 (task-orchestration reads).
- Role strings: `pm`, `qa`, `engineer`, `designer` consistent.
- Document keys: `spec`, `plan` consistent.
- Skill keys: `henriquerferrer/paperclipowers/<slug>` consistent.

**Overall:** Ready for subagent-driven execution. The plan is deliberately concrete on skill content (full SKILL.md drafts inline in Tasks 4-6) so an executor without prior pipeline context can produce the files verbatim.

---

## Execution Handoff

**Plan complete and saved to `docs/plans/2026-04-14-stage-5-pipeline.md`.**

**Recommended execution:** `superpowers:subagent-driven-development` — dispatch a fresh subagent per task, two-stage review between tasks. This mirrors Stage 4's execution model and keeps the main session context clean.

**Stage 5 cost sanity check:** ~$15 budget target (Stage 4 was $3.72 for 10 heartbeats; Stage 5 expects ~20-30 heartbeats spread across 4 agents).
