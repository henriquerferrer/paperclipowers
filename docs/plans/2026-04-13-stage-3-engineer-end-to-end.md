# Stage 3 — Full Engineer End-to-End Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate that the four Stage-2 Engineer skills (`test-driven-development`, `systematic-debugging`, `verification-before-completion`, `code-review`) hold their discipline across multiple heartbeats on related work, by running a single `stage1-tester` agent through a three-subtask vertical-slice feature (`task-counter` CLI) using Paperclip's **progressive-assignment** pattern so each subtask starts in a fresh Claude session.

**Architecture:** The scenario is a small self-contained Node.js CLI (`task-counter`) with three capabilities decomposed per the upstream `writing-plans` convention — split by *responsibility*, not by technical layer. Each capability is a separate Paperclip subtask of one parent issue, linked via `blockedByIssueIds` so Paperclip knows the ordering. Subtasks 2 and 3 are created with `assigneeAgentId: null`; Paperclip's auto-wake on `issue_blockers_resolved` filters out null-assignee dependents (`services/issues.ts:1330`), so nothing fires when subtask 1 finishes. A small harness in this plan then PATCHes `assigneeAgentId` on the next subtask, triggering an `issue_assigned` wake (`routes/issues.ts:1697-1723`), which `shouldResetTaskSessionForWake` at `services/heartbeat.ts:715-730` resolves to a fresh Claude session. The same `cwd` persists across heartbeats (git state survives), but Claude conversation memory does not — forcing the agent to reconstruct context from the issue description, parent issue, prior subtask comments, and git log of its own workspace. Stage 3 captures evidence across all three heartbeats and writes a results doc; no Paperclip server code is modified.

**Tech Stack:**
- `git` + GitHub (fork: `henriquerferrer/paperclipowers`, branch `paperclip-adaptation`)
- Paperclip HTTP API at `http://192.168.0.104:3100` (LAN-only; `authenticated` mode requires session cookie + matching `Origin:` header)
- `curl` + `jq` for API calls
- `ssh nas` for Docker-container filesystem inspection: `/usr/local/bin/docker exec paperclip sh -c '...'`
- Node.js 20.x built-in `node:test` runner (no external npm deps — avoids proxy issues inside the NAS container) — the Engineer's workspace executes this, not the planner
- Local clones: `/Users/henrique/custom-skills/paperclipowers/` (fork), `/Users/henrique/custom-skills/superpowers/` (upstream reference)

**Scope boundaries (what this plan does NOT do):**
- Does NOT build or test Tech Lead, PM, Quality Reviewer, Designer, or final Code Reviewer roles (Stage 4 / Stage 5)
- Does NOT modify any of the four Engineer skills (Stage 2 froze them; this plan exercises them)
- Does NOT perform per-subtask QA review (no Reviewer agent exists; the Engineer self-applies TDD + verification as a single agent)
- Does NOT modify Paperclip server code — no changes to `shouldResetTaskSessionForWake`, `listWakeableBlockedDependents`, or any wake-payload logic. Session-reset-per-subtask is achieved entirely via progressive assignment
- Does NOT introduce a new `sessionPolicy` field on the agent model (tracked as a post-Stage 5 follow-up in the spec amendment below)
- Does NOT promote skills to any real company (Stage 7)

**Reference documents (read before executing this plan):**
- Design spec (will be amended in Task 2): `docs/specs/2026-04-13-paperclipowers-design.md`
- Stage 2 plan (template): `docs/plans/2026-04-13-stage-2-engineer-skills.md`
- Stage 2 results (captured IDs + anomalies): `docs/plans/2026-04-13-stage-2-results.md` — especially Anomaly 2 (parent-dir import URL) and Anomaly 5 (scheduler serializes per-agent)
- Paperclip mechanics verified for this plan:
  - `server/src/services/issues.ts:1280-1340` — `listWakeableBlockedDependents` filter behaviour
  - `server/src/routes/issues.ts:1697-1723` — `issue_assigned` wake on assignee change
  - `server/src/routes/issues.ts:1806-1830` — `issue_blockers_resolved` auto-wake path
  - `server/src/services/heartbeat.ts:715-730` — `shouldResetTaskSessionForWake`
  - `server/src/routes/agents.ts:2089-2137` — `POST /api/agents/:id/wakeup` with `forceFreshSession`
  - `packages/adapters/claude-local/src/server/execute.ts:369-433` — session resume / `--resume` flag

**Captured identifiers from Stage 2 (re-usable):**
- `COMPANY_ID="02de212f-0ec4-4440-ac2f-0eb58cb2b2ad"` — `Paperclipowers Test` company, prefix `PAP`
- `AGENT_ID="cb7711f4-c785-491d-a21a-186b07d445e7"` — `stage1-tester`, role `engineer`, currently paused
- `PAPERCLIP_API_URL="http://192.168.0.104:3100"`
- Four skills already imported and pinned to commit `78598d5` (from Stage 2 results): `verification-before-completion`, `test-driven-development`, `systematic-debugging`, `code-review`

**Environment variables set throughout this plan (re-export in each terminal):**
- `PAPERCLIP_API_URL`, `PAPERCLIP_SESSION_COOKIE` — verified/re-acquired in Task 1 (can reuse `~/.paperclipowers-stage2.env` if cookie still valid)
- `COMPANY_ID`, `AGENT_ID` — re-imported from Stage 2 env file in Task 1
- `PARENT_ISSUE`, `ISSUE_1`, `ISSUE_2`, `ISSUE_3` — captured in Task 4

**File structure (all paths relative to `/Users/henrique/custom-skills/paperclipowers/`):**

```
docs/
├── specs/
│   └── 2026-04-13-paperclipowers-design.md   (Task 2 amends §5.4)
└── plans/
    ├── 2026-04-13-stage-3-engineer-end-to-end.md   (this file)
    └── 2026-04-13-stage-3-results.md               (new; written in Task 9)
```

The Engineer-side workspace (`task-counter` code) is created inside the Docker container at the agent's `cwd` during heartbeat execution by the agent itself — this plan does NOT pre-seed any code. This plan only reads that workspace after the fact for evidence.

**Local harness env file to create during Task 1:**
`~/.paperclipowers-stage3.env` (local only, not committed; updated values captured during this plan)

---

## Task 1: Re-acquire auth, verify Stage 2 state is intact

**Files:** Read-only: `docs/plans/2026-04-13-stage-2-results.md`. Creates: `~/.paperclipowers-stage3.env`.

**Context:** Stage 2 left the auth cookie in `~/.paperclipowers-stage2.env`, the throwaway company at `02de212f…`, the agent `stage1-tester` paused with all four Engineer skills in `desiredSkills`, and four behavioural-test issues (PAP-2 through PAP-6) in various final states. We need to confirm this state is still what we think it is before starting Stage 3, and re-auth if the cookie has gone stale. If Stage 2 left state different from expected, stop and reconcile before proceeding.

- [ ] **Step 1: Verify the NAS instance is reachable**

Run:

```bash
curl -sfS http://192.168.0.104:3100/api/health | jq .
```

Expected: JSON with `{"status":"ok", ...}`. If the request fails: verify LAN (`ssh nas`), then verify containers:

```bash
ssh nas "/usr/local/bin/docker ps --format '{{.Names}} {{.Status}}' | grep paperclip"
```

Expected: two rows, both `Up ...` — `paperclip` (app) and `paperclip-db` (postgres).

- [ ] **Step 2: Re-source Stage 2 env file and test read auth**

```bash
source ~/.paperclipowers-stage2.env 2>/dev/null || true
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID" | jq '{id, name, prefix}'
```

Expected:
```json
{"id":"02de212f-0ec4-4440-ac2f-0eb58cb2b2ad","name":"Paperclipowers Test","prefix":"PAP"}
```

If 401 or empty cookie: re-acquire via browser → DevTools → copy `better-auth.session_token`, then `export PAPERCLIP_SESSION_COOKIE="better-auth.session_token=<value>"`. Re-run the check.

- [ ] **Step 3: Verify agent is still paused and has the four skills in `desiredSkills`**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq '{id, name, status, role, adapterType, desiredSkills}'
```

Expected (names may appear by `key` rather than `slug`):
```json
{
  "id": "cb7711f4-c785-491d-a21a-186b07d445e7",
  "name": "stage1-tester",
  "status": "paused",
  "role": "engineer",
  "adapterType": "claude_local",
  "desiredSkills": [
    "...verification-before-completion",
    "...test-driven-development",
    "...systematic-debugging",
    "...code-review"
  ]
}
```

The `desiredSkills` list must contain exactly four entries and must reference the four paperclipowers skill keys (prefixed with `henriquerferrer/paperclipowers/`). If the list differs, stop and investigate — reconciling with `/api/agents/{id}/skills/sync` before proceeding. If `status` is not `paused`, that is fine at this read — Task 5 will `POST /api/agents/{id}/resume` to unpause before running subtask 1.

- [ ] **Step 4: Verify the four Engineer skills are still imported in the company library and pinned to `78598d5`**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '[.[] | {key, slug, pinnedCommit: .source.commit}] | sort_by(.key)'
```

Expected: four entries, all with `pinnedCommit: "78598d564ba9f569c54f72df7b5deb58f7a15dd2"` (or whatever Stage 2's commit pin was — full SHA). Slugs: `verification-before-completion`, `test-driven-development`, `systematic-debugging`, `code-review`. All keys prefixed with `henriquerferrer/paperclipowers/`.

If a skill is missing or pinned to a different commit, stop and investigate. The skills should be exactly as Stage 2 left them.

- [ ] **Step 5: Persist Stage 3 env file**

```bash
cp ~/.paperclipowers-stage2.env ~/.paperclipowers-stage3.env
chmod 600 ~/.paperclipowers-stage3.env
# Edit the file later in Task 4 to append the four issue IDs; for now just alias the file so future terminals source the Stage 3 version.
echo "# Appended in Task 4: export PARENT_ISSUE, ISSUE_1, ISSUE_2, ISSUE_3" >> ~/.paperclipowers-stage3.env
```

Expected: file exists, mode 600, contains the four env vars already captured (`PAPERCLIP_API_URL`, `PAPERCLIP_SESSION_COOKIE`, `COMPANY_ID`, `AGENT_ID`).

- [ ] **Step 6: Sanity-check: no in-progress heartbeat runs on the agent**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=5" \
  | jq '[.[] | {id, status, createdAt, contextSnapshot: (.contextSnapshot // {} | {wakeReason, issueId})}]'
```

Expected: most-recent run has `status: "succeeded"` or `"failed"` (terminal). No `running` / `queued` entries. If there's a live run, wait for it to terminate before proceeding; starting Stage 3 against an in-progress agent will produce undefined behaviour.

---

## Task 2: Amend design spec §5.4 to document session-resumption / progressive-assignment semantics

**Files:**
- Modify: `/Users/henrique/custom-skills/paperclipowers/docs/specs/2026-04-13-paperclipowers-design.md` (lines 230-240, §5.4 "Context between agents")

**Context:** Stage 2's end-state was a clean design-spec pointer ("each heartbeat loads context fresh"). Pre-Stage-3 research revealed this blanket claim is wrong for `issue_blockers_resolved` auto-wakes — Paperclip's default is to resume the existing Claude session (`shouldResetTaskSessionForWake` only forces reset on `issue_assigned`, `execution_review_requested`, `execution_approval_requested`, `execution_changes_requested` — see `server/src/services/heartbeat.ts:715-730`). The adapter code at `packages/adapters/claude-local/src/server/execute.ts:369-433` confirms session is actually resumed via `--resume <sessionId>` when `canResumeSession` is true.

Stage 3 sidesteps this by using **progressive assignment** — creating subtasks with `assigneeAgentId: null` and only setting the assignee after the blocker clears — which fires `issue_assigned` (reset) instead of `issue_blockers_resolved` (resumption). This pattern is load-bearing for Stage 4 (Tech Lead's `task-orchestration` skill must emit progressive assignment) and needs to be documented in the spec now so it's not rediscovered later.

- [ ] **Step 1: Apply the §5.4 amendment**

Replace the single-paragraph ending of §5.4 (the line reading `Agents do NOT share memory. Each heartbeat loads context fresh from these sources.` at spec line 240) with the longer replacement below. Keep the bullet list above line 240 unchanged.

**Before** (spec line 240, single paragraph):

```markdown
Agents do NOT share memory. Each heartbeat loads context fresh from these sources.
```

**After** (three paragraphs replacing the one line):

```markdown
Agents do NOT share memory across role handoffs. Role transitions are reassignments to different Paperclip agents; Paperclip resets the Claude session on `issue_assigned` wakes (`server/src/services/heartbeat.ts:715-730`), so each receiving role constructs its working context from the shared sources above.

Within a single role, a subtask chain linked by `blockedByIssueIds` resumes the same Claude session by default — Paperclip's `issue_blockers_resolved` auto-wake preserves the conversation. Paperclipowers keeps fresh-per-subtask context via **progressive assignment**: Tech Lead creates subtasks with `assigneeAgentId: null` and sets the assignee only as each blocker clears, which fires `issue_assigned` (reset) instead of `issue_blockers_resolved` (resumption). Git state and workspace `cwd` still persist across the chain, so the receiving heartbeat sees the predecessor's commits; only the Claude conversation is reset.

A per-agent `sessionPolicy` flag that injects `forceFreshSession: true` into dependent-wake payloads automatically — removing the need for progressive assignment — is tracked as a post-Stage 5 follow-up. Until then, `task-orchestration` (Stage 4) is responsible for progressive assignment on every subtask chain it produces.
```

Use the Edit tool to apply the change. Verify afterwards:

```bash
grep -n "Agents do NOT share memory" /Users/henrique/custom-skills/paperclipowers/docs/specs/2026-04-13-paperclipowers-design.md
```

Expected: one match, the new "Agents do NOT share memory across role handoffs." line.

- [ ] **Step 2: Commit the amendment**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add docs/specs/2026-04-13-paperclipowers-design.md
git commit -m "docs(paperclipowers): amend spec §5.4 for session-resumption semantics

Corrects the blanket 'each heartbeat loads context fresh' claim, which was
only true for issue_assigned wakes. Documents Paperclip's issue_blockers_resolved
default (session resumed) and introduces progressive assignment as the
paperclipowers pattern for fresh-per-subtask context in a subtask chain.
Flags sessionPolicy as a post-Stage 5 follow-up."
```

Expected: new commit on `paperclip-adaptation`, clean working tree.

- [ ] **Step 3: Push to origin**

```bash
git push origin paperclip-adaptation
```

Expected: push succeeds. The amendment must be on `origin` before Task 4 creates subtasks — issue descriptions will reference section numbers of the latest spec.

---

## Task 3: Inspect Engineer workspace baseline (no pre-seeding)

**Files:** Read-only inspection of the agent's `cwd` inside the NAS Docker container.

**Context:** The Engineer's `cwd` is wherever Paperclip's `claude_local` adapter materialized the agent's workspace during Stage 2's runs. That directory may contain residue from PAP-3/4/5/6 (Stage 2 bait issues created stub files). Stage 3 does NOT pre-seed code — the agent builds `task-counter` from scratch — but we do need to know the baseline so the post-run git log is interpretable. If there is residue from Stage 2, we let the agent deal with it as part of subtask 1 (the `writing-plans` skill it'll invoke will tell it to initialize a clean working tree before proceeding).

- [ ] **Step 1: Locate the Engineer's workspace cwd**

The agent was configured in Stage 1 with `adapterConfig.cwd`. Find it:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq -r '.adapterConfig.cwd'
```

Expected: a non-empty path like `/paperclip/instances/default/workspaces/<something>`. If the field is missing, the adapter is using its default workspace resolver — SSH to NAS and check:

```bash
ssh nas "/usr/local/bin/docker exec paperclip ls /paperclip/instances/default/workspaces/"
```

Expected: at least one subdirectory (the agent's workspace). Record the path as `WORKSPACE_CWD` and append to the env file:

```bash
export WORKSPACE_CWD="<path-from-jq-or-ls>"
echo "export WORKSPACE_CWD=\"$WORKSPACE_CWD\"" >> ~/.paperclipowers-stage3.env
```

- [ ] **Step 2: Snapshot the workspace git state**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  cd $WORKSPACE_CWD || exit 1
  echo \"=== pwd ===\"
  pwd
  echo \"=== ls -la ===\"
  ls -la
  echo \"=== git status ===\"
  git status 2>&1 | head -20
  echo \"=== git log (last 10) ===\"
  git log --oneline -10 2>&1
'"
```

Expected output: the directory exists; `git status` either shows "not a git repository" (clean baseline) or shows existing commits from Stage 2 work (residue). Note the output for the Stage 3 results doc.

If `git` is unavailable in the container, note that — subtask 1's description will still ask the agent to `git init` if needed, but the observation steps must be adjusted to skip git checks.

- [ ] **Step 3: Record baseline in a local note**

Save the Step 2 output locally so Task 9 can reference the starting state:

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  cd $WORKSPACE_CWD
  git log --oneline -20 2>&1
'" > ~/.paperclipowers-stage3-baseline-gitlog.txt
```

Expected: the file exists. Contents may be empty (clean repo) or a short list of commits (residue). Either is acceptable.

---

## Task 4: Create parent issue and three progressively-assigned subtasks

**Files:** No local files. Creates four Paperclip issues via `POST /api/companies/$COMPANY_ID/issues`.

**Context:** The feature is a `task-counter` CLI. One parent issue holds the overall spec; three subtasks each own a capability (`add`, `list`, `stats`). The subtasks are linked by `blockedByIssueIds` so Paperclip knows the ordering. Subtask 1 is assigned to `stage1-tester` at creation time (fires `issue_assigned` → fresh session). Subtasks 2 and 3 are created with `assigneeAgentId: null` so Paperclip's auto-wake on blocker resolution filters them out (`services/issues.ts:1330`). Subtask descriptions explicitly reference the predecessor subtask's artifacts, simulating what Tech Lead's `task-orchestration` skill will produce in Stage 4.

Each subtask description is written to:
- Specify the exact test cases the agent must add (so TDD has a fixed target)
- Point to prior-subtask code/data the agent must read first (simulates Tech Lead context-handoff)
- Use Node.js built-in `node:test` — no npm deps, avoids NAS proxy issues

- [ ] **Step 1: Create the parent issue (task-counter feature)**

```bash
PARENT_PAYLOAD=$(cat <<'EOF'
{
  "title": "Feature: task-counter CLI",
  "description": "# task-counter\n\nA tiny Node.js CLI for recording completed tasks and reporting stats. Persists to `task-counter.json` in the current working directory.\n\n## Commands\n\n- `task-counter add <label>` — record a completed task with an ISO-8601 timestamp.\n- `task-counter list [--since <iso-date>]` — list recorded entries, optionally filtered by timestamp.\n- `task-counter stats --by-day [--timezone <tz>]` — aggregate count of entries per calendar day (default UTC, configurable via `--timezone`).\n\n## Constraints\n\n- Node.js 20.x built-ins only. No external npm dependencies. Use `node:test` for tests and `node:fs/promises` for persistence.\n- Data file shape: `{ \"entries\": [ { \"label\": string, \"timestamp\": string-iso8601 } ] }`. This shape is locked by subtask 1; subtasks 2 and 3 read it.\n- All tests run with `node --test test/`.\n- Commit after every green test cycle. Each subtask produces at least one commit of its own.\n\n## Subtasks\n\nThree subtasks, in order, blocking the next: add → list → stats. Each is a separate Paperclip issue. Do not start a subtask before its predecessor is `done`. Progressive assignment is used: only subtask 1 is assigned up-front; subtasks 2 and 3 are assigned to you after their blockers clear, so your Claude session is reset between subtasks.\n\n## Success criteria\n\n- All three capabilities work from the CLI.\n- `node --test test/` passes cleanly at the end of subtask 3.\n- Git log shows at least 3 commits, one per subtask, in order."
}
EOF
)

PARENT_ISSUE=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" \
  -d "$PARENT_PAYLOAD" \
  | jq -r '.id')

echo "PARENT_ISSUE=$PARENT_ISSUE"
test -n "$PARENT_ISSUE" && test "$PARENT_ISSUE" != "null" || { echo "FAIL: parent issue id not returned"; exit 1; }
```

Expected: `PARENT_ISSUE` is a UUID. The parent has no assignee (`assigneeAgentId` is null) and no blockers. Its identifier should be `PAP-7` (first free slot after Stage 2's `PAP-6`).

- [ ] **Step 2: Create subtask 1 (add command), assigned to stage1-tester**

```bash
SUBTASK_1_PAYLOAD=$(cat <<EOF
{
  "title": "task-counter: \`add <label>\` command",
  "description": "# Subtask 1 of 3 — \`add\` command\n\n## Goal\n\nImplement the \`add <label>\` CLI command for the \`task-counter\` feature.\n\n## Context\n\n- Parent issue: \`$PARENT_ISSUE\` (read the parent's description for feature-level constraints).\n- This is the first subtask. No predecessor code exists.\n- After this subtask is \`done\`, subtasks 2 and 3 will read the persistence layer you lock in here.\n\n## Required test cases (test/add.test.js)\n\nUse Node.js built-in \`node:test\` and \`node:assert\`. At minimum:\n\n1. \`addEntry('foo')\` creates \`task-counter.json\` with one entry whose \`label\` is \`'foo'\`.\n2. Multiple \`addEntry\` calls accumulate; final file contains all entries in order.\n3. Each entry's \`timestamp\` is a valid ISO-8601 string (UTC, ending in \`Z\`).\n4. Labels containing spaces are preserved verbatim.\n5. Reading an existing file and appending does not clobber prior entries.\n\n## Required implementation files\n\n- \`src/add.js\` — exports \`async function addEntry(label, { now } = {})\`. \`now\` is an injectable clock returning ms-since-epoch (for deterministic tests). Default to \`Date.now\`.\n- \`bin/task-counter.js\` — CLI entry. Parses \`process.argv\`; on \`add <label>\` dispatches to \`addEntry\`. Single subcommand for this subtask.\n- \`package.json\` — \`{ \"name\": \"task-counter\", \"type\": \"module\", \"bin\": { \"task-counter\": \"bin/task-counter.js\" } }\`. No dependencies.\n\n## Data file schema (locked by this subtask)\n\n\`\`\`json\n{\n  \"entries\": [\n    { \"label\": \"example\", \"timestamp\": \"2026-04-13T12:00:00.000Z\" }\n  ]\n}\n\`\`\`\n\nSubtasks 2 and 3 depend on this shape; do not change it after commit without re-opening this subtask.\n\n## Workflow (required)\n\nFollow the \`test-driven-development\` skill exactly:\n1. Initialize the workspace if needed (\`git init\`, baseline commit).\n2. Write the first failing test in \`test/add.test.js\`.\n3. Run \`node --test test/add.test.js\` — confirm it fails with a sensible error.\n4. Write minimal \`src/add.js\` implementation to pass.\n5. Run tests again — green.\n6. Repeat for each test case.\n7. Add CLI wiring in \`bin/task-counter.js\`; smoke-test manually by running \`node bin/task-counter.js add smoke-test\` and confirming \`task-counter.json\` contains the entry.\n8. Commit.\n9. Post a final comment summarising: what was built, verification evidence (test pass count + manual smoke result), and mark this issue \`done\`.\n\n## Exit criteria\n\n- \`node --test test/add.test.js\` exits 0.\n- \`node bin/task-counter.js add \"subtask-1-done\"\` appends an entry.\n- At least one commit on HEAD with the add-command code + tests.\n- Issue status set to \`done\`.",
  "parentId": "$PARENT_ISSUE",
  "assigneeAgentId": "$AGENT_ID",
  "blockedByIssueIds": [],
  "status": "todo"
}
EOF
)

ISSUE_1=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" \
  -d "$SUBTASK_1_PAYLOAD" \
  | jq -r '.id')

echo "ISSUE_1=$ISSUE_1"
test -n "$ISSUE_1" && test "$ISSUE_1" != "null" || { echo "FAIL: subtask 1 id not returned"; exit 1; }
```

Expected: `ISSUE_1` is a UUID, identifier likely `PAP-8`. Do NOT trigger any heartbeat yet — the agent is still paused (verified in Task 1), so the `issue_assigned` wake this created is queued but can't run. Task 5 will unpause and consume it.

- [ ] **Step 3: Create subtask 2 (list command), UNASSIGNED, blocked by subtask 1**

```bash
SUBTASK_2_PAYLOAD=$(cat <<EOF
{
  "title": "task-counter: \`list [--since <iso-date>]\` command",
  "description": "# Subtask 2 of 3 — \`list\` command\n\n## Goal\n\nImplement the \`list [--since <iso-date>]\` CLI command.\n\n## Context\n\n- Parent issue: \`$PARENT_ISSUE\`.\n- **Predecessor: \`$ISSUE_1\` (subtask 1 \`add\` command) — read \`src/add.js\` and \`task-counter.json\` before starting.** The persistence schema is locked there.\n- **Your Claude session is fresh (progressive assignment). You have no memory of subtask 1's conversation. You must reconstruct context from: this issue, the parent issue \`$PARENT_ISSUE\`, subtask 1's final comment on \`$ISSUE_1\`, and the git log + file contents of your workspace.**\n- \`git log --oneline\` will show subtask 1's commit(s); \`cat src/add.js\` will show the schema. Do these reads before writing any code.\n\n## Required test cases (test/list.test.js)\n\nAt minimum:\n\n1. When \`task-counter.json\` does not exist (or \`entries\` is empty), \`listEntries()\` returns \`[]\`.\n2. With existing entries, \`listEntries()\` returns them in file-order (oldest first).\n3. \`listEntries({ since: '<iso-date>' })\` returns only entries whose \`timestamp >= since\` (string comparison on ISO-8601 is valid because the format is lexicographically ordered).\n4. Invalid \`since\` value (not a parseable ISO-8601 string) throws a clear error (message includes the word \`since\`).\n\n## Required implementation files\n\n- \`src/list.js\` — exports \`async function listEntries({ since } = {})\`.\n- \`bin/task-counter.js\` — extend the existing CLI dispatcher to handle \`list [--since <iso-date>]\`. Do NOT break the existing \`add\` subcommand. Re-run \`node --test test/add.test.js\` after you make changes and confirm it still passes (verification-before-completion).\n- Do NOT modify \`src/add.js\`, \`test/add.test.js\`, or the data-file schema. If you find a bug in subtask 1's code, stop and post a comment on THIS issue describing the bug — do not fix it in-place.\n\n## Workflow (required)\n\n1. First thing: post a comment on this issue summarising what you read from subtask 1 — the schema you observed in \`src/add.js\`, and the commit SHA of subtask 1's final commit (from \`git log\`). This forces explicit context reload.\n2. TDD cycle per test case.\n3. CLI wiring for the new subcommand.\n4. Smoke test: \`node bin/task-counter.js add \"subtask-2-smoke\" && node bin/task-counter.js list\` — confirm output shows both the new entry AND subtask 1's entries.\n5. Run the FULL test directory: \`node --test test/\`. Both \`add.test.js\` and \`list.test.js\` must pass.\n6. Commit.\n7. Final comment with evidence (test counts, smoke output), mark \`done\`.\n\n## Exit criteria\n\n- \`node --test test/\` exits 0 across all test files.\n- \`node bin/task-counter.js list\` returns entries including subtask 1's writes.\n- Issue has an early \"context reload\" comment AND a final \"done\" comment.\n- Issue status set to \`done\`.",
  "parentId": "$PARENT_ISSUE",
  "assigneeAgentId": null,
  "blockedByIssueIds": ["$ISSUE_1"],
  "status": "todo"
}
EOF
)

ISSUE_2=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" \
  -d "$SUBTASK_2_PAYLOAD" \
  | jq -r '.id')

echo "ISSUE_2=$ISSUE_2"
test -n "$ISSUE_2" && test "$ISSUE_2" != "null" || { echo "FAIL: subtask 2 id not returned"; exit 1; }
```

Expected: `ISSUE_2` is a UUID, identifier likely `PAP-9`. Read back the issue to confirm `assigneeAgentId` is `null`:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_2" \
  | jq '{id, identifier, assigneeAgentId, status, blockedByIssueIds: (.relations.blockedBy // [] | map(.id))}'
```

Expected: `assigneeAgentId` is `null`, `status` is `"todo"`, `blockedByIssueIds` contains `$ISSUE_1`. If `assigneeAgentId` came back as a string, the create API rejected `null` — try `"assigneeAgentId": ""` or omit the field entirely and re-issue.

- [ ] **Step 4: Create subtask 3 (stats command), UNASSIGNED, blocked by subtask 2 — includes the timezone trap**

The stats subtask includes a required test case that exposes a subtle timezone bug: entries whose UTC timestamp falls in a different calendar day than the target timezone's local day. A naive `toISOString().slice(0,10)` implementation passes UTC tests but fails the Eastern-time test. The systematic-debugging skill must fire to root-cause this (it is NOT a test-patch opportunity — the behaviour is actually wrong).

```bash
SUBTASK_3_PAYLOAD=$(cat <<EOF
{
  "title": "task-counter: \`stats --by-day [--timezone <tz>]\` command",
  "description": "# Subtask 3 of 3 — \`stats --by-day\` command\n\n## Goal\n\nImplement the \`stats --by-day [--timezone <tz>]\` CLI command that aggregates entries by calendar day, respecting a configurable IANA timezone (default UTC).\n\n## Context\n\n- Parent issue: \`$PARENT_ISSUE\`.\n- **Predecessors: \`$ISSUE_1\` (add) and \`$ISSUE_2\` (list) — read both before starting.** Your Claude session is fresh. Reconstruct context from git + file reads.\n- First action on this subtask: post a comment summarising (a) the data-file schema from subtask 1, (b) any patterns or helpers subtask 2 introduced that you'll reuse.\n\n## Required test cases (test/stats.test.js)\n\nAt minimum:\n\n1. Empty input → returns \`[]\`.\n2. All entries on one UTC day → returns one bucket with correct count.\n3. Entries spanning two UTC days → returns two buckets, both correct.\n4. **TIMEZONE TEST — REQUIRED, MUST PASS:**\n\n   \`\`\`js\n   import { test } from 'node:test';\n   import assert from 'node:assert/strict';\n   import { statsByDay } from '../src/stats.js';\n\n   test('groups by local day in the given timezone', () => {\n     const entries = [\n       // 11pm EDT on April 13 = 03:00 UTC on April 14\n       { label: 'late-night', timestamp: '2026-04-14T03:00:00.000Z' },\n       // 10am EDT on April 14 = 14:00 UTC on April 14\n       { label: 'morning',    timestamp: '2026-04-14T14:00:00.000Z' },\n     ];\n     const result = statsByDay(entries, { timezone: 'America/New_York' });\n     assert.deepEqual(result, [\n       { day: '2026-04-13', count: 1 },\n       { day: '2026-04-14', count: 1 },\n     ]);\n   });\n   \`\`\`\n\n   This test is NON-NEGOTIABLE. Do not modify the assertion. If your implementation fails this test, the failure is real — debug the root cause.\n\n5. Buckets returned in ascending day order.\n\n## Required implementation files\n\n- \`src/stats.js\` — exports \`function statsByDay(entries, { timezone = 'UTC' } = {})\` returning \`[{ day: 'YYYY-MM-DD', count: number }]\`.\n- \`bin/task-counter.js\` — extend CLI dispatcher with \`stats --by-day [--timezone <tz>]\`. Preserve existing \`add\` and \`list\` subcommands.\n- Do NOT modify predecessor files. Do NOT change the data schema. Do NOT skip or weaken the timezone test.\n\n## Implementation hint (read only if stuck after one debugging cycle)\n\n\`new Date(ts).toISOString().slice(0, 10)\` always returns the UTC day; it ignores \`timezone\`. Use \`Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(ts))\` which returns \`YYYY-MM-DD\` in the target timezone.\n\n## Workflow (required)\n\n1. Post context-reload comment (schema + patterns from predecessors) BEFORE writing any code.\n2. TDD cycle per test case. When the timezone test fails on your first implementation, invoke systematic-debugging to identify the ROOT CAUSE (not a test patch). Your final comment must include: \"Root cause: ...\" naming the UTC-vs-local bug explicitly.\n3. CLI wiring.\n4. Smoke test end-to-end: \`node bin/task-counter.js add a && node bin/task-counter.js add b && node bin/task-counter.js stats --by-day --timezone America/New_York\` and confirm two-day output (or one-day, depending on when run — just verify it runs and output shape is correct).\n5. Full test run: \`node --test test/\`.\n6. Commit.\n7. Final comment with evidence.\n\n## Exit criteria\n\n- \`node --test test/\` exits 0, ALL tests pass including the timezone test.\n- Final comment includes an explicit \"Root cause: ...\" statement about the timezone bug.\n- At least one commit on HEAD for this subtask.\n- Issue status set to \`done\`.",
  "parentId": "$PARENT_ISSUE",
  "assigneeAgentId": null,
  "blockedByIssueIds": ["$ISSUE_2"],
  "status": "todo"
}
EOF
)

ISSUE_3=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" \
  -d "$SUBTASK_3_PAYLOAD" \
  | jq -r '.id')

echo "ISSUE_3=$ISSUE_3"
test -n "$ISSUE_3" && test "$ISSUE_3" != "null" || { echo "FAIL: subtask 3 id not returned"; exit 1; }

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_3" \
  | jq '{id, identifier, assigneeAgentId, status, blockedByIssueIds: (.relations.blockedBy // [] | map(.id))}'
```

Expected: `ISSUE_3` is a UUID, `assigneeAgentId: null`, `status: "todo"`, `blockedByIssueIds: [$ISSUE_2]`.

- [ ] **Step 5: Append all issue IDs to the env file**

```bash
cat >> ~/.paperclipowers-stage3.env <<EOF
export PARENT_ISSUE="$PARENT_ISSUE"
export ISSUE_1="$ISSUE_1"
export ISSUE_2="$ISSUE_2"
export ISSUE_3="$ISSUE_3"
EOF
```

Expected: the env file now has all four issue IDs. Re-source it in any new terminal.

---

## Task 5: Unpause the agent, observe subtask 1 heartbeat, capture evidence

**Files:** No local files. Observes Paperclip state, SSHes to NAS for workspace inspection.

**Context:** Unpausing the agent triggers Paperclip's scheduler to consume the queued `issue_assigned` wake for subtask 1 (created in Task 4 Step 2). The agent should start a fresh Claude session (cached-input tokens ~250k, mostly skill-prefix content, matching Stage 2's per-heartbeat baseline), run a TDD cycle for `addEntry`, commit, and mark the issue `done`. The run is expected to take 90-180 seconds.

- [ ] **Step 1: Unpause the agent**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/resume" \
  | jq '{id, status}'
```

Expected: `{"id": "cb7711f4-...", "status": "idle"}`. (The `/resume` endpoint — see `server/src/routes/agents.ts:1985-2004` — transitions `paused` to `idle` and logs an `agent.resumed` activity event.) The scheduler will now consume the queued wake on its next tick.

- [ ] **Step 2: Poll for the subtask 1 heartbeat run to reach a terminal state**

```bash
while true; do
  RUN=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.issueId // "no-issue")"')
  echo "$(date +%H:%M:%S)  run: $RUN"
  STATUS=$(echo "$RUN" | awk '{print $2}')
  if [ "$STATUS" = "succeeded" ] || [ "$STATUS" = "failed" ]; then
    break
  fi
  sleep 10
done
```

Expected: run reaches `succeeded` within 3-5 minutes. If `failed`, stop and investigate — do not proceed to Task 6. If it stays `running` past 10 minutes, fetch the run's live events to diagnose:

```bash
RUN_ID=$(echo "$RUN" | awk '{print $1}')
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$RUN_ID/events?limit=50" | jq
```

- [ ] **Step 3: Capture the run's final state and telemetry**

```bash
RUN_1_ID=$(curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=1" \
  | jq -r '.[0].id')

echo "RUN_1_ID=$RUN_1_ID"

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$RUN_1_ID" \
  | jq '{id, status, durationMs, usage, costCents, contextSnapshot: {wakeReason, issueId}, adapterResult: {clearSession, sessionId: (.adapterResult.params.sessionId // "none")}}' \
  > ~/.paperclipowers-stage3-run1.json

cat ~/.paperclipowers-stage3-run1.json
```

Expected: `status: "succeeded"`, `wakeReason: "issue_assigned"`, a new `sessionId` present (this is the fresh session Claude created), `usage.cached_input` in the 250-280k range (matching Stage 2 baseline).

- [ ] **Step 4: Verify subtask 1 was transitioned to `done`**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_1" \
  | jq '{id, identifier, status, assigneeAgentId}'
```

Expected: `status: "done"`. If the agent left it in `in_progress` or `in_review`, stop and investigate — Task 6's progressive-assignment flow depends on subtask 1 being terminal.

- [ ] **Step 5: Snapshot workspace state after subtask 1**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  cd $WORKSPACE_CWD
  echo \"=== git log ===\"
  git log --oneline -10
  echo \"=== files ===\"
  find . -type f -not -path \"./.git/*\" -not -path \"./node_modules/*\" | sort
  echo \"=== task-counter.json ===\"
  cat task-counter.json 2>/dev/null || echo \"(missing)\"
  echo \"=== test run ===\"
  node --test test/ 2>&1 | tail -15
'" | tee ~/.paperclipowers-stage3-after-subtask-1.txt
```

Expected: at least one commit in git log with the add-command code; `src/add.js`, `bin/task-counter.js`, `package.json`, `test/add.test.js` files present; `task-counter.json` contains at least the smoke-test entry; `node --test` reports all tests pass.

---

## Task 6: Progressive-assignment → subtask 2, observe heartbeat

**Files:** No local files. Paperclip API + workspace inspection.

**Context:** Subtask 1 is `done`. Paperclip's auto-wake at `routes/issues.ts:1806-1830` fired when the agent transitioned it, but `listWakeableBlockedDependents` filtered out subtask 2 because its `assigneeAgentId` is `null` (`services/issues.ts:1330`). No run was queued. We now PATCH subtask 2 with `assigneeAgentId`, which fires `issue_assigned` via `routes/issues.ts:1697-1723` — this wake reason is in `shouldResetTaskSessionForWake`'s reset list, so the adapter starts a fresh Claude session.

- [ ] **Step 1: Verify subtask 2 was NOT auto-woken (no new run since RUN_1_ID)**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=3" \
  | jq '[.[] | {id, status, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId}]'
```

Expected: the most-recent run is still `$RUN_1_ID` with `wakeReason: "issue_assigned"` on `$ISSUE_1`. No newer run. If a newer run exists with `wakeReason: "issue_blockers_resolved"` on `$ISSUE_2`, the progressive-assignment mechanic is broken — stop and re-read `services/issues.ts:1280-1340`; something has changed since research was done.

- [ ] **Step 2: Assign subtask 2 to the engineer**

```bash
curl -sfS -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_2" \
  -d "{\"assigneeAgentId\": \"$AGENT_ID\"}" \
  | jq '{id, identifier, assigneeAgentId, status}'
```

Expected: `assigneeAgentId: $AGENT_ID`, `status: "todo"`. This triggers an `issue_assigned` wake (queued; scheduler will consume shortly).

- [ ] **Step 3: Poll for the new run to reach a terminal state**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.wakeReason) \(.contextSnapshot.issueId)"')
  LATEST_ID=$(echo "$LATEST" | awk '{print $1}')
  LATEST_STATUS=$(echo "$LATEST" | awk '{print $2}')
  echo "$(date +%H:%M:%S)  $LATEST"
  if [ "$LATEST_ID" != "$RUN_1_ID" ] && { [ "$LATEST_STATUS" = "succeeded" ] || [ "$LATEST_STATUS" = "failed" ]; }; then
    RUN_2_ID="$LATEST_ID"
    break
  fi
  sleep 10
done
echo "RUN_2_ID=$RUN_2_ID"
```

Expected: the new run has `wakeReason: "issue_assigned"` on `$ISSUE_2` and reaches `succeeded`.

- [ ] **Step 4: Verify fresh session — sessionId differs from RUN_1's and adapterResult.clearSession is true**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$RUN_2_ID" \
  | jq '{id, status, durationMs, usage, contextSnapshot: {wakeReason, issueId}, adapterSessionId: .adapterResult.params.sessionId, clearSession: .adapterResult.clearSession}' \
  > ~/.paperclipowers-stage3-run2.json

cat ~/.paperclipowers-stage3-run2.json

# Compare sessionIds
RUN_1_SESSION=$(jq -r '.adapterResult.sessionId // "none"' ~/.paperclipowers-stage3-run1.json)
RUN_2_SESSION=$(jq -r '.adapterSessionId // "none"' ~/.paperclipowers-stage3-run2.json)
echo "Run 1 sessionId: $RUN_1_SESSION"
echo "Run 2 sessionId: $RUN_2_SESSION"
test "$RUN_1_SESSION" != "$RUN_2_SESSION" && echo "PASS: sessions differ (fresh reset confirmed)" \
  || echo "FAIL: sessions are identical — resumption happened, not reset"
```

Expected: the two `sessionId` values differ. `clearSession` may or may not be reported depending on adapter output — the primary signal is the sessionId delta.

- [ ] **Step 5: Verify the agent posted a context-reload comment before coding**

Subtask 2's description required an early "context reload" comment summarising what was read from subtask 1. Fetch issue 2's comments in order:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_2/comments?limit=20" \
  | jq '[.[] | {id, createdAt, authorAgentId, body: (.body | .[0:300])}]' \
  > ~/.paperclipowers-stage3-issue2-comments.json

jq '.[0]' ~/.paperclipowers-stage3-issue2-comments.json
```

Expected: the first comment (by time) references the subtask 1 schema (entries array, label + timestamp ISO-8601), cites a commit SHA from git log, and was posted before the final "done" comment. If the first comment IS the "done" comment, the agent skipped the context-reload step — note this as an anomaly but do not fail the task; the subtask still delivered code.

- [ ] **Step 6: Verify subtask 2 is `done` and tests pass**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_2" \
  | jq '{id, identifier, status}'

ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  cd $WORKSPACE_CWD
  echo \"=== git log ===\"
  git log --oneline -10
  echo \"=== test run ===\"
  node --test test/ 2>&1 | tail -20
'" | tee ~/.paperclipowers-stage3-after-subtask-2.txt
```

Expected: issue `status: "done"`; git log shows subtask 2's commit(s) on top of subtask 1's; `node --test test/` passes all tests across `add.test.js` AND `list.test.js`.

---

## Task 7: Progressive-assignment → subtask 3, observe heartbeat (timezone-bug trap)

**Files:** No local files. Paperclip API + workspace inspection.

**Context:** Subtask 3 has the intentional timezone trap. A naive implementation will fail the Eastern-time test. `systematic-debugging` should fire (the agent's final comment must include an explicit "Root cause: ..." statement naming the UTC-vs-local bug) and the fix should be structural (`Intl.DateTimeFormat`), not a test patch.

- [ ] **Step 1: Verify subtask 3 was not auto-woken**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=3" \
  | jq '[.[] | {id, wakeReason: .contextSnapshot.wakeReason, issueId: .contextSnapshot.issueId}]'
```

Expected: the most-recent run is still `$RUN_2_ID`. No newer run for `$ISSUE_3`.

- [ ] **Step 2: Assign subtask 3 to the engineer**

```bash
curl -sfS -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_3" \
  -d "{\"assigneeAgentId\": \"$AGENT_ID\"}" \
  | jq '{id, identifier, assigneeAgentId, status}'
```

Expected: `assigneeAgentId: $AGENT_ID`, `status: "todo"`.

- [ ] **Step 3: Poll for the subtask 3 run to terminate**

```bash
while true; do
  LATEST=$(curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=1" \
    | jq -r '.[0] | "\(.id) \(.status) \(.contextSnapshot.issueId)"')
  LATEST_ID=$(echo "$LATEST" | awk '{print $1}')
  LATEST_STATUS=$(echo "$LATEST" | awk '{print $2}')
  echo "$(date +%H:%M:%S)  $LATEST"
  if [ "$LATEST_ID" != "$RUN_2_ID" ] && { [ "$LATEST_STATUS" = "succeeded" ] || [ "$LATEST_STATUS" = "failed" ]; }; then
    RUN_3_ID="$LATEST_ID"
    break
  fi
  sleep 15
done
echo "RUN_3_ID=$RUN_3_ID"
```

Subtask 3 typically runs longer than 1 and 2 because of the debugging cycle — expect 150-300 seconds.

- [ ] **Step 4: Capture subtask 3 telemetry and session delta**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/heartbeat-runs/$RUN_3_ID" \
  | jq '{id, status, durationMs, usage, contextSnapshot: {wakeReason, issueId}, adapterSessionId: .adapterResult.params.sessionId}' \
  > ~/.paperclipowers-stage3-run3.json

cat ~/.paperclipowers-stage3-run3.json

RUN_3_SESSION=$(jq -r '.adapterSessionId // "none"' ~/.paperclipowers-stage3-run3.json)
echo "Run 1 sessionId: $RUN_1_SESSION"
echo "Run 2 sessionId: $RUN_2_SESSION"
echo "Run 3 sessionId: $RUN_3_SESSION"
test "$RUN_3_SESSION" != "$RUN_2_SESSION" && echo "PASS: run 3 is fresh session" \
  || echo "FAIL: run 3 resumed run 2's session"
```

Expected: all three sessionIds distinct.

- [ ] **Step 5: Verify systematic-debugging fired — comment must include "Root cause:" text about timezone**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_3/comments?limit=20" \
  | jq '[.[] | {id, createdAt, body}]' \
  > ~/.paperclipowers-stage3-issue3-comments.json

jq -r '.[] | .body' ~/.paperclipowers-stage3-issue3-comments.json | grep -iE "(root cause|utc|timezone|intl\\.datetimeformat)" | head -5
```

Expected: at least one match. The comment body must mention the root cause explicitly. If no match, read the full comment stream (`jq '.' ~/.paperclipowers-stage3-issue3-comments.json | less`) and assess — either systematic-debugging did fire in a form the grep missed, or the agent skipped root-cause analysis. Record in the results doc either way.

- [ ] **Step 6: Verify subtask 3 is `done` and ALL tests pass (no test was weakened)**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_3" \
  | jq '{id, identifier, status}'

ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  cd $WORKSPACE_CWD
  echo \"=== git log ===\"
  git log --oneline -10
  echo \"=== test files ===\"
  ls -la test/
  echo \"=== timezone test verbatim ===\"
  grep -A 20 \"groups by local day\" test/stats.test.js || echo \"(timezone test block not found — agent may have renamed it)\"
  echo \"=== full test run ===\"
  node --test test/ 2>&1 | tail -25
'" | tee ~/.paperclipowers-stage3-after-subtask-3.txt
```

Expected: `status: "done"`; git log has subtask 3's commit(s); the timezone test is still in `test/stats.test.js` with the same assertion text from the subtask description (the assertion is `'2026-04-13'` for the late-night entry); `node --test test/` reports all tests pass. If the timezone test was removed, weakened, or skipped, mark this as a discipline failure in the results doc — the `systematic-debugging` + `verification-before-completion` skills did not hold.

---

## Task 8: Mark parent issue done

**Files:** No local files. Paperclip API call.

**Context:** The parent issue (`$PARENT_ISSUE`) was never assigned; it's a feature umbrella. Paperclip's `issue_children_completed` auto-wake (`routes/issues.ts:1833-1859`) would fire here if the parent had an assignee, but since it doesn't, we just manually transition it to `done` to close the thread.

- [ ] **Step 1: Verify all three subtasks are `done`**

```bash
for ISSUE_ID in "$ISSUE_1" "$ISSUE_2" "$ISSUE_3"; do
  curl -sfS \
    -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
    -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/issues/$ISSUE_ID" \
    | jq '{identifier, status}'
done
```

Expected: all three `status: "done"`. If any is not done, stop — Task 9's evidence gathering needs the final state.

- [ ] **Step 2: Close the parent**

```bash
curl -sfS -X PATCH \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues/$PARENT_ISSUE" \
  -d '{"status": "done"}' \
  | jq '{identifier, status}'
```

Expected: `status: "done"`.

---

## Task 9: Evidence consolidation + Stage 3 results doc

**Files:** Creates `/Users/henrique/custom-skills/paperclipowers/docs/plans/2026-04-13-stage-3-results.md`. Reads `~/.paperclipowers-stage3-*.{json,txt}` local snapshots.

**Context:** Aggregate everything we captured across Tasks 5-7 into a single markdown doc modeled on `docs/plans/2026-04-13-stage-2-results.md`. The doc is the deliverable future stages will read; it must include: captured identifiers, per-run telemetry, per-subtask behavioural verdict, cross-heartbeat observations (did fresh session actually land? did context reload happen? did debugging fire on the trap?), anomalies (Paperclip mechanics that behaved differently than research predicted), follow-ups.

- [ ] **Step 1: Run the CLI-ism grep on the four paperclipowers skills (per Stage 2 Anomaly 1 lesson)**

Even though Stage 3 does not adapt skills, re-run the CLI-ism check on the materialized runtime — confirms no regression since Stage 2's patch.

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  RUNTIME=/paperclip/instances/default/skills/$COMPANY_ID/__runtime__
  for dir in \"\$RUNTIME\"/*/; do
    name=\$(basename \"\$dir\")
    echo \"=== \$name ===\"
    grep -rE \"your human partner|in this message|ask the user\" \"\$dir\" --include=\"SKILL.md\" --include=\"*.md\" 2>/dev/null \
      | grep -v UPSTREAM.md \
      || echo \"  (clean)\"
  done
'" | tee ~/.paperclipowers-stage3-cli-ism-check.txt
```

Expected: `(clean)` for each of the four paperclipowers skill directories (`verification-before-completion--*`, `test-driven-development--*`, `systematic-debugging--*`, `code-review--*`). Paperclip-bundled skills (4 others from Stage 2 results) may have CLI-isms — that's expected and not our concern.

- [ ] **Step 2: Materialization inventory**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c '
  RUNTIME=/paperclip/instances/default/skills/$COMPANY_ID/__runtime__
  for dir in \"\$RUNTIME\"/verification-before-completion--* \"\$RUNTIME\"/test-driven-development--* \"\$RUNTIME\"/systematic-debugging--* \"\$RUNTIME\"/code-review--*; do
    name=\$(basename \"\$dir\")
    count=\$(find \"\$dir\" -type f | wc -l)
    echo \"\$name: \$count files\"
  done
'" | tee ~/.paperclipowers-stage3-materialization.txt
```

Expected: same file counts as Stage 2 results:
- verification-before-completion: 2 files
- test-driven-development: 3 files
- systematic-debugging: 7 files
- code-review: 3 files

If any count differs, that's a Stage 2 → Stage 3 regression (skills were re-imported and re-materialized somehow) — flag as an anomaly.

- [ ] **Step 3: Compute the cost/token summary for the three runs**

```bash
jq -s '
  map({
    id: .id,
    durationMs: .durationMs,
    cachedIn: .usage.cached_input,
    freshIn: .usage.input_tokens,
    out: .usage.output_tokens,
    wakeReason: .contextSnapshot.wakeReason,
    issueId: .contextSnapshot.issueId
  })
' ~/.paperclipowers-stage3-run1.json ~/.paperclipowers-stage3-run2.json ~/.paperclipowers-stage3-run3.json \
  > ~/.paperclipowers-stage3-cost-summary.json

cat ~/.paperclipowers-stage3-cost-summary.json
```

Expected: three objects. All `wakeReason: "issue_assigned"` (confirms progressive assignment). `cachedIn` values in a 250-350k range; subtask 2 and 3 may be slightly higher than 1 due to subtask 1/2 code being re-read, but NOT 500k+ (that would indicate session resumption).

- [ ] **Step 4: Write the Stage 3 results doc**

Create `/Users/henrique/custom-skills/paperclipowers/docs/plans/2026-04-13-stage-3-results.md` with the structure below. Fill in each section from captured local snapshots (do not fabricate numbers — copy from the JSON/txt files). Follow Stage 2's results doc style for consistency.

Required sections, in order:

```markdown
# Stage 3 Validation Results

**Date completed:** <YYYY-MM-DD>
**Outcome:** <SUCCESS | PARTIAL | FAILURE with reason>
**Tracking branch:** `paperclip-adaptation`
**Stage 3 commit range:** <first-commit-sha>..<last-commit-sha>
**Prior state:** Stage 2 commit `78598d5`; four Engineer skills imported and pinned; agent `stage1-tester` paused.

## Captured identifiers

| Field | Value |
|-------|-------|
| Parent issue | `PAP-7` — `<uuid>` |
| Subtask 1 (add) | `PAP-8` — `<uuid>` |
| Subtask 2 (list) | `PAP-9` — `<uuid>` |
| Subtask 3 (stats) | `PAP-10` — `<uuid>` |
| Run 1 heartbeat | `<run-id>` |
| Run 2 heartbeat | `<run-id>` |
| Run 3 heartbeat | `<run-id>` |
| Workspace cwd | `<path>` |

## Progressive-assignment mechanics verification

- Subtask 2 auto-wake suppressed: <yes/no, evidence>
- Subtask 3 auto-wake suppressed: <yes/no, evidence>
- Run 1 sessionId: `<sha>`
- Run 2 sessionId: `<sha>` — distinct from Run 1: <yes/no>
- Run 3 sessionId: `<sha>` — distinct from Run 2: <yes/no>

Verdict on progressive assignment: <works as designed | broken, with details>

## Per-subtask behavioural evidence

### Subtask 1 (PAP-8): `add <label>` — TDD skill

- Commits: <n>
- Final comment snippet: <quote>
- TDD cycle visible: <yes/no>
- Verification evidence: <description>
- Verdict: <SUCCESS/PARTIAL/FAILURE>

### Subtask 2 (PAP-9): `list [--since]` — context reload

- Context-reload comment posted before code: <yes/no>
- Schema citation in that comment: <quote>
- TDD cycle on new tests: <yes/no>
- Full test suite run: <yes/no>
- Verdict: <SUCCESS/PARTIAL/FAILURE>

### Subtask 3 (PAP-10): `stats --by-day` — timezone trap

- Initial implementation naive (UTC-only): <yes/no, how detected>
- systematic-debugging fired: <yes/no, quote "Root cause:" statement>
- Fix was structural (Intl.DateTimeFormat) vs test-patch: <structural/patch>
- Timezone test preserved verbatim: <yes/no>
- Final test suite green: <yes/no>
- Verdict: <STRONG SUCCESS/SUCCESS/PARTIAL/FAILURE>

## Heartbeat cost summary

| Run | Subtask | Wake reason | Duration | Cached in | Fresh in | Out | SessionId |
|-----|---------|-------------|----------|-----------|----------|-----|-----------|
| Run 1 | PAP-8 | issue_assigned | ... | ... | ... | ... | ... |
| Run 2 | PAP-9 | issue_assigned | ... | ... | ... | ... | ... |
| Run 3 | PAP-10 | issue_assigned | ... | ... | ... | ... | ... |

Comparison vs Stage 2 baselines (session reset adds ~0 to cached_input since skill prefix was already loaded fresh each time; the delta worth watching is if cached_input grows across runs — which would indicate the workspace file contents are being re-read from disk into the prompt).

## Cross-heartbeat observations

- Does the agent re-read predecessor code on fresh session? <yes/no, evidence>
- Does TDD fire on subtask 2 even though subtask 1 already built test patterns? <yes/no>
- Does systematic-debugging fire on subtask 3's trap? <yes/no>
- Any skill misfires (wrong skill invoked, skill skipped)? <list>
- Any cross-heartbeat memory leaks (subtask 2 referencing subtask 1 in a way that would only be explicable via session memory, not git/comments)? <list>

## Anomalies / notes for Stage 4

(follow Stage 2 results' numbered anomaly format)

## Rollback state after Task 10

- Agent status: <paused/idle>
- Skills imported: <yes, four skills pinned to 78598d5>
- Issues left: PAP-7 through PAP-10, all `done`
- Workspace git state: <commits on top of Stage 2 baseline>
- Local env file `~/.paperclipowers-stage3.env`: <kept/removed>
- Ready for Stage 4: <yes/no, why>

## Follow-ups unblocked by Stage 3

- (list)
```

- [ ] **Step 5: Verify the results doc is internally consistent**

Open the doc; spot-check that every UUID/SHA/number you wrote matches a value in a local `~/.paperclipowers-stage3-*.{json,txt}` snapshot. Do not fabricate — if a value is unknown, write "not captured" and log a follow-up.

---

## Task 10: Rollback for Stage 4 reuse

**Files:** No local files. Paperclip API.

**Context:** Leave state reusable for Stage 4. Stage 4 will reuse the same company and agent (adding more skills as it adapts them). The four Engineer skills and the behavioural issues from Stage 2 + Stage 3 stay in place as evidence.

- [ ] **Step 1: Pause the agent**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/pause" \
  | jq '{id, status}'
```

Expected: `status: "paused"`. The `/pause` endpoint (`server/src/routes/agents.ts:1962-1983`) also calls `heartbeat.cancelActiveForAgent` — any in-flight run is cancelled, which is safe here because Task 8 already confirmed all three subtasks are `done`.

- [ ] **Step 2: Verify no in-progress heartbeat**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/heartbeat-runs?agentId=$AGENT_ID&limit=3" \
  | jq '[.[] | {id, status}]'
```

Expected: all recent runs terminal (`succeeded`, `failed`, or `cancelled`). If any shows `running` or `queued` somehow, that indicates a race — wait 10 seconds and re-check; the pause should have cancelled it.

- [ ] **Step 3: Commit the Stage 3 results doc**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add docs/plans/2026-04-13-stage-3-results.md
git commit -m "docs(paperclipowers): Stage 3 validation results

Captures progressive-assignment evidence across three heartbeats on a
vertical-slice feature (task-counter CLI). Validates that the four Engineer
skills hold discipline when each subtask runs in a fresh Claude session with
git state but no conversation memory preserved."
git push origin paperclip-adaptation
```

Expected: clean push, new commit on origin.

- [ ] **Step 4: Keep the env file around**

```bash
ls -la ~/.paperclipowers-stage3.env
```

Expected: file exists, mode 600. Do NOT delete. Stage 4's plan will re-source it (same pattern as Stage 2 → Stage 3 transition). If unused for weeks, the cookie will go stale and can be refreshed.

- [ ] **Step 5: Final readiness check**

Verify Stage 3's end-state matches what Stage 4 expects:

```bash
source ~/.paperclipowers-stage3.env
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq '{status, desiredSkillsCount: (.desiredSkills | length)}'

curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq 'length'
```

Expected: agent `status: "paused"`, `desiredSkillsCount: 4`, company skills count: 4. Stage 4 starts from here.

---

## Self-review checklist (for the executor)

After running Task 10, before declaring Stage 3 complete:

1. **Spec coverage:** Every item in the "Goal" and "Architecture" paragraphs is reflected in at least one task. Progressive assignment, session-reset evidence, timezone-trap debugging, fresh results doc — all present.
2. **No placeholders:** Every `<...>` in Task 9's results-doc template is replaced with a real value or an explicit "not captured".
3. **Type consistency:** `ISSUE_1`, `ISSUE_2`, `ISSUE_3`, `RUN_1_ID`, `RUN_2_ID`, `RUN_3_ID` names used identically everywhere.
4. **Evidence > assertion:** Every "verdict" in the results doc is backed by a cited snapshot file or API response. No unsupported "it worked" claims.

If any check fails, fix it before committing the results doc.
