# Stage 1 — Validate Import Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the fork → adapt → import → assign → run loop end-to-end using `verification-before-completion` as a minimal guinea-pig skill, so Stages 2–7 can proceed with confidence that the mechanics work.

**Architecture:** Adapt one superpowers skill with a one-line Paperclip edit, push to GitHub, import into a throwaway Paperclip company via the HTTP API, hire one test agent with the skill assigned, trigger a heartbeat, observe that the skill is materialized into the execution workspace and referenced by the agent. Every operation is reversible; the test company is deleted at the end.

**Tech Stack:**
- `git` + GitHub (fork repo: `henriquerferrer/paperclipowers`)
- Paperclip HTTP API (server at `/Users/henrique/Documents/paperclip/server/src/routes/`)
- `curl` + `jq` for API calls
- Paperclip runs in Docker on NAS at `/Volumes/docker/paperclip/`
- Local paperclipowers clone: `/Users/henrique/custom-skills/paperclipowers/`

**Scope boundaries (what this plan does NOT do):**
- Does NOT build the full 6-role pipeline (Stages 4–5)
- Does NOT adapt any skill other than `verification-before-completion` (Stage 2)
- Does NOT import into a production company (Stage 7)
- Does NOT configure MCP servers or Designer role (Stage 6)

**Reference documents:**
- Design spec: `docs/specs/2026-04-13-paperclipowers-design.md`
- Upstream skill (unmodified): `skills/verification-before-completion/SKILL.md`
- Paperclip company-skills service: `/Users/henrique/Documents/paperclip/server/src/services/company-skills.ts`
- Paperclip agents route: `/Users/henrique/Documents/paperclip/server/src/routes/agents.ts`

**Environment variables set throughout this plan (re-export in each terminal):**
- `PAPERCLIP_API_URL` — base URL of the running Paperclip server (discovered in Task 3)
- `PAPERCLIP_TOKEN` — API token (discovered in Task 3)
- `COMPANY_ID` — UUID of the throwaway test company (captured in Task 4)
- `SKILL_ID` — UUID of the imported skill row (captured in Task 5)
- `SKILL_KEY` — canonical skill key (captured in Task 5)
- `AGENT_ID` — UUID of the hired test agent (captured in Task 6)
- `ISSUE_ID` — UUID of the trigger issue (captured in Task 7)

---

## Task 1: Create the Paperclip-adapted `verification-before-completion` skill

**Files:**
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/verification-before-completion/SKILL.md`
- Reference only (do not modify): `/Users/henrique/custom-skills/paperclipowers/skills/verification-before-completion/SKILL.md`

**Why this location:** The design spec (§4) defines two parallel trees: `skills/` holds upstream-verbatim copies synced from obra/superpowers, and `skills-paperclip/` holds Paperclip-adapted versions. Stage 1 writes the first adapted skill. Paperclip's importer (`readUrlSkillImports`) walks a directory recursively and picks up any `SKILL.md` — pointing it at `skills-paperclip/` isolates adapted skills from upstream copies.

- [ ] **Step 1: Copy upstream as starting point**

```bash
mkdir -p /Users/henrique/custom-skills/paperclipowers/skills-paperclip/verification-before-completion
cp /Users/henrique/custom-skills/paperclipowers/skills/verification-before-completion/SKILL.md \
   /Users/henrique/custom-skills/paperclipowers/skills-paperclip/verification-before-completion/SKILL.md
```

Expected: file `skills-paperclip/verification-before-completion/SKILL.md` exists and is byte-identical to the upstream copy.

- [ ] **Step 2: Apply the single Paperclip-specific edit**

Edit `skills-paperclip/verification-before-completion/SKILL.md` at the line under "## The Iron Law":

**Before (line ~22):**

```
If you haven't run the verification command in this message, you cannot claim it passes.
```

**After:**

```
If you haven't run the verification command in this heartbeat execution, you cannot claim it passes.
```

Rationale: design spec §5.1 — the CLI "message" concept maps to a Paperclip "heartbeat execution" (one short async run, not a conversation turn). This is the only CLI-ism in the upstream file; all other text (Iron Law, Gate Function, Red Flags) is model-agnostic.

- [ ] **Step 3: Verify the edit is correct and the rest is unchanged**

Run:

```bash
diff /Users/henrique/custom-skills/paperclipowers/skills/verification-before-completion/SKILL.md \
     /Users/henrique/custom-skills/paperclipowers/skills-paperclip/verification-before-completion/SKILL.md
```

Expected output (exactly these two changed lines, nothing else):

```
22c22
< If you haven't run the verification command in this message, you cannot claim it passes.
---
> If you haven't run the verification command in this heartbeat execution, you cannot claim it passes.
```

If the diff shows any other changes, the copy picked up unintended edits — revert to Step 1 and retry.

- [ ] **Step 4: Verify frontmatter is parseable**

Run:

```bash
head -4 /Users/henrique/custom-skills/paperclipowers/skills-paperclip/verification-before-completion/SKILL.md
```

Expected:

```
---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---
```

The `name` and `description` fields must be present and unchanged — Paperclip's `parseFrontmatterMarkdown` reads these for skill-library display and agent trigger matching.

- [ ] **Step 5: Commit**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add skills-paperclip/verification-before-completion/SKILL.md
git commit -m "feat: add Paperclip-adapted verification-before-completion skill

One-line delta from upstream obra/superpowers: 'in this message' ->
'in this heartbeat execution' per design spec §5.1."
```

Expected: commit succeeds; `git log -1` shows the new commit.

---

## Task 2: Push `paperclipowers` to GitHub

**Files:**
- Modify (git remote): `/Users/henrique/custom-skills/paperclipowers/.git/config`

- [ ] **Step 1: Verify the GitHub remote is set to the fork**

Run:

```bash
cd /Users/henrique/custom-skills/paperclipowers
git remote -v
```

Expected: `origin` points to `https://github.com/henriquerferrer/paperclipowers.git` (or `git@github.com:henriquerferrer/paperclipowers.git`). If no remote, add it:

```bash
git remote add origin https://github.com/henriquerferrer/paperclipowers.git
```

- [ ] **Step 2: Verify current branch**

Run:

```bash
git branch --show-current
```

Expected: `paperclip-adaptation` (the working branch for the fork; `main` is upstream-synced).

- [ ] **Step 3: Push to GitHub**

Run:

```bash
git push -u origin paperclip-adaptation
```

Expected: push succeeds; GitHub shows the commits at `https://github.com/henriquerferrer/paperclipowers/commits/paperclip-adaptation`.

- [ ] **Step 4: Verify the skill file is live on GitHub**

Run:

```bash
curl -sfL https://raw.githubusercontent.com/henriquerferrer/paperclipowers/paperclip-adaptation/skills-paperclip/verification-before-completion/SKILL.md \
  | head -4
```

Expected: same frontmatter as Task 1 Step 4. If 404, the push didn't take — re-run Step 3.

---

## Task 3: Discover Paperclip API base URL and authentication token

**Files:**
- Read only: `/Volumes/docker/paperclip/docker-compose.yml` (or `~/.paperclip/config.json` / `~/.paperclipai/config.json`)

**Context:** The user's Paperclip instance is running in Docker on a NAS. The API's base URL and auth mechanism depend on how that deployment exposes the server. This task discovers both so subsequent tasks can use them.

- [ ] **Step 1: Find the exposed API port**

Try, in order:

```bash
ls /Volumes/docker/paperclip/ 2>/dev/null
cat /Volumes/docker/paperclip/docker-compose.yml 2>/dev/null | grep -A 3 "ports:"
docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -i paperclip
```

Expected: identify the host:port that maps to the Paperclip server (typically `:3100` or similar). Record it.

- [ ] **Step 2: Find the API token**

Try, in order:

```bash
cat ~/.paperclip/config.json 2>/dev/null
cat ~/.paperclipai/config.json 2>/dev/null
ls /Volumes/docker/paperclip/ | grep -i secret
```

If none of these show a token, check the Paperclip UI (log in at the discovered base URL) for an account → API tokens section, or generate a new one. Record as `PAPERCLIP_TOKEN`.

- [ ] **Step 3: Export both as env vars for this shell**

```bash
export PAPERCLIP_API_URL="http://<host>:<port>"   # e.g. http://localhost:3100
export PAPERCLIP_TOKEN="<token-from-step-2>"
```

- [ ] **Step 4: Verify connectivity**

Run:

```bash
curl -sfS "$PAPERCLIP_API_URL/api/health" | jq .
```

Expected: a JSON response indicating the server is healthy (e.g., `{"status":"ok"}` or similar). If this fails, the base URL is wrong — go back to Step 1.

- [ ] **Step 5: Verify authentication**

Run:

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" "$PAPERCLIP_API_URL/api/companies" | jq 'length'
```

Expected: integer ≥ 0 (count of companies visible to this token). If 401, the token is invalid — return to Step 2. If the endpoint path differs (some Paperclip builds use `/api/v1/...`), grep the server routes to confirm:

```bash
grep -r "app.get.*companies" /Users/henrique/Documents/paperclip/server/src/routes/ | head -5
```

- [ ] **Step 6: Record discovered values in a local notes file (not committed)**

```bash
cat > ~/.paperclipowers-stage1.env <<EOF
export PAPERCLIP_API_URL="$PAPERCLIP_API_URL"
export PAPERCLIP_TOKEN="$PAPERCLIP_TOKEN"
EOF
chmod 600 ~/.paperclipowers-stage1.env
```

Re-source with `source ~/.paperclipowers-stage1.env` in any new terminal during this plan.

---

## Task 4: Create the throwaway test company `paperclipowers-test`

**Files:**
- API: `POST $PAPERCLIP_API_URL/api/companies`

- [ ] **Step 1: Check for name collisions**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies" \
  | jq '.[] | select(.slug=="paperclipowers-test")'
```

Expected: empty output (no company with this slug exists). If a company already exists, either delete it first (Task 8 rollback) or pick a different slug like `paperclipowers-test-2`.

- [ ] **Step 2: Create the company**

```bash
curl -sfS -X POST \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies" \
  -d '{"name":"Paperclipowers Test","slug":"paperclipowers-test"}' \
  | jq .
```

Expected: JSON response containing `id` (UUID), `name: "Paperclipowers Test"`, `slug: "paperclipowers-test"`. If the endpoint rejects the payload because of missing required fields, inspect the route handler:

```bash
grep -n "app.post.*companies" /Users/henrique/Documents/paperclip/server/src/routes/companies.ts | head
```

Adjust the payload to match the route's schema and retry.

- [ ] **Step 3: Capture the company ID**

```bash
export COMPANY_ID=$(curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies" \
  | jq -r '.[] | select(.slug=="paperclipowers-test") | .id')
echo "COMPANY_ID=$COMPANY_ID"
echo "export COMPANY_ID=\"$COMPANY_ID\"" >> ~/.paperclipowers-stage1.env
```

Expected: `COMPANY_ID` prints as a UUID (not empty).

---

## Task 5: Import the adapted skill from GitHub into the test company

**Files:**
- API: `POST $PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import`
- Reference: `/Users/henrique/Documents/paperclip/server/src/services/company-skills.ts:2268-2306` (`importFromSource`)

**Context:** `importFromSource` accepts a `source` string. For `sourceType=github`, it calls `readUrlSkillImports`, walks the repo tree recursively from the given path, and imports every `SKILL.md` it finds. Pointing the importer at `skills-paperclip/` limits the scan to the adapted subset.

- [ ] **Step 1: Import from GitHub with subpath scoping**

```bash
curl -sfS -X POST \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" \
  -d '{"source":"https://github.com/henriquerferrer/paperclipowers/tree/paperclip-adaptation/skills-paperclip"}' \
  | jq .
```

Expected: JSON response with an `imported` (or `skills`) array containing exactly one entry, whose `slug` is `verification-before-completion` and `sourceType` is `github`. The response should also include a `sourceRef` (commit SHA pinned at import time).

If the response says "No SKILL.md files were found," the subpath in the URL is wrong or the file didn't push — verify with:

```bash
curl -sfL https://raw.githubusercontent.com/henriquerferrer/paperclipowers/paperclip-adaptation/skills-paperclip/verification-before-completion/SKILL.md | head -1
```

- [ ] **Step 2: Verify the skill is in the company library**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '.[] | {id, key, slug, sourceType, sourceRef}'
```

Expected output (shape):

```json
{
  "id": "<uuid>",
  "key": "<canonical-key>",
  "slug": "verification-before-completion",
  "sourceType": "github",
  "sourceRef": "<commit-sha>"
}
```

- [ ] **Step 3: Capture skill ID and canonical key**

```bash
export SKILL_ID=$(curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="verification-before-completion") | .id')
export SKILL_KEY=$(curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="verification-before-completion") | .key')
echo "SKILL_ID=$SKILL_ID"
echo "SKILL_KEY=$SKILL_KEY"
echo "export SKILL_ID=\"$SKILL_ID\"" >> ~/.paperclipowers-stage1.env
echo "export SKILL_KEY=\"$SKILL_KEY\"" >> ~/.paperclipowers-stage1.env
```

Expected: both non-empty.

- [ ] **Step 4: Verify the skill markdown is stored correctly**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/$SKILL_ID" \
  | jq -r '.markdown' \
  | grep -c "in this heartbeat execution"
```

Expected: `1` (the Paperclip-specific edit is present in the stored content — confirms the import read the adapted version, not upstream).

---

## Task 6: Hire a test agent in the company with the skill assigned

**Files:**
- API: `POST $PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agent-hires`
- API: `POST $PAPERCLIP_API_URL/api/agents/$AGENT_ID/skills/sync`
- Reference: `/Users/henrique/Documents/paperclip/server/src/routes/agents.ts:855-948` (`skills/sync`) and `1277-1416` (`agent-hires`)

- [ ] **Step 1: Hire the agent**

```bash
curl -sfS -X POST \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agent-hires" \
  -d "$(jq -n --arg key "$SKILL_KEY" '{
    name: "stage1-tester",
    role: "engineer",
    adapterType: "claude_local",
    desiredSkills: [$key]
  }')" \
  | jq .
```

Expected: response contains `id` (UUID), `name: "stage1-tester"`, `companyId: $COMPANY_ID`, `adapterType: "claude_local"`, and `adapterConfig.paperclipSkillSync.desiredSkills` includes `$SKILL_KEY`.

If the route rejects the payload (missing required fields vary by Paperclip version), inspect:

```bash
grep -n "agent-hires\|hireAgent" /Users/henrique/Documents/paperclip/server/src/routes/agents.ts | head
```

Adjust payload to match and retry.

- [ ] **Step 2: Capture the agent ID**

```bash
export AGENT_ID=$(curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  | jq -r '.[] | select(.name=="stage1-tester") | .id')
echo "AGENT_ID=$AGENT_ID"
echo "export AGENT_ID=\"$AGENT_ID\"" >> ~/.paperclipowers-stage1.env
```

Expected: UUID printed.

- [ ] **Step 3: Verify the skill is assigned to this agent**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq '.adapterConfig.paperclipSkillSync.desiredSkills'
```

Expected: JSON array containing `$SKILL_KEY`.

- [ ] **Step 4: Re-sync skills explicitly (idempotency check)**

This validates that the dedicated assignment endpoint works the same way a later re-assignment would:

```bash
curl -sfS -X POST \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/skills/sync" \
  -d "$(jq -n --arg key "$SKILL_KEY" '{desiredSkills: [$key]}')" \
  | jq .
```

Expected: 200 OK; response shows the same `desiredSkills` array. A 200 (not 201) here is the signal that the skill was already assigned.

---

## Task 7: Trigger a heartbeat and observe skill materialization

**Files:**
- API: `POST $PAPERCLIP_API_URL/api/issues` (create trigger issue)
- Docker container filesystem: execution workspace materialization path

**Context:** `heartbeat.ts:2423` calls `listRuntimeSkillEntries` at wake time, attaches the entries to `runtimeConfig.paperclipRuntimeSkills`, and the claude-local adapter materializes them as markdown files in the execution workspace's `~/.claude/skills/` (see `packages/adapters/claude-local/src/server/skills.ts:50`). The agent loads them via Claude Code's native skill mechanism.

The success signal is two-part: **(a)** skill file appears on disk in the execution workspace during heartbeat; **(b)** agent's output/activity log shows the skill was loaded or applied.

- [ ] **Step 1: Create a trigger issue assigned to the test agent**

```bash
curl -sfS -X POST \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues" \
  -d "$(jq -n --arg companyId "$COMPANY_ID" --arg agentId "$AGENT_ID" '{
    companyId: $companyId,
    assigneeAgentId: $agentId,
    title: "Stage 1 heartbeat test",
    description: "Print the current date, claim the task is done, and exit. (This intentionally baits the verification-before-completion skill: claiming done without running a verification is exactly the pattern the skill should catch.)",
    status: "todo"
  }')" \
  | jq .
```

Expected: 201 response with an `id`. Capture it:

```bash
export ISSUE_ID=$(curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/issues?companyId=$COMPANY_ID&assigneeAgentId=$AGENT_ID" \
  | jq -r '.[] | select(.title=="Stage 1 heartbeat test") | .id')
echo "ISSUE_ID=$ISSUE_ID"
echo "export ISSUE_ID=\"$ISSUE_ID\"" >> ~/.paperclipowers-stage1.env
```

- [ ] **Step 2: Wait for (or force-trigger) the next heartbeat**

Paperclip's heartbeat scheduler wakes agents on a cadence. To avoid waiting, force-trigger:

```bash
curl -sfS -X POST \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/heartbeat" \
  | jq .
```

If this route doesn't exist on your Paperclip build, check alternatives:

```bash
grep -rn "heartbeat\|wake" /Users/henrique/Documents/paperclip/server/src/routes/ | head
```

Fallback: wait up to 2 minutes for the scheduler to pick up the new issue, then check the activity log:

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/activity?limit=10" \
  | jq '.[] | {createdAt, action}'
```

Expected: within 2 minutes, an entry with action containing `heartbeat` or `execution`.

- [ ] **Step 3: Check the execution workspace on the NAS for the materialized skill**

```bash
find /Volumes/docker/paperclip -type d -name "verification-before-completion" 2>/dev/null
```

Expected: at least one path like `/Volumes/docker/paperclip/.../<workspace-id>/.claude/skills/verification-before-completion`. If the Docker volume isn't mounted on the host, shell into the container instead:

```bash
docker exec -it $(docker ps --format '{{.Names}}' | grep -i paperclip-server | head -1) \
  find /paperclip -type d -name "verification-before-completion" 2>/dev/null
```

Expected: at least one match under a workspace path.

- [ ] **Step 4: Read the materialized SKILL.md and confirm it's the adapted version**

```bash
docker exec -it $(docker ps --format '{{.Names}}' | grep -i paperclip-server | head -1) \
  sh -c 'cat $(find /paperclip -type f -name "SKILL.md" -path "*verification-before-completion*" | head -1)' \
  | grep -c "in this heartbeat execution"
```

Expected: `1`. This confirms the DB-stored adapted content round-trips all the way through runtime materialization.

- [ ] **Step 5: Inspect the agent's output / heartbeat log for evidence of the skill**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/activity?limit=20" \
  | jq '.[] | {createdAt, action, message: .payload.message // .payload.stdout}' \
  | head -100
```

Expected (any of these signals is sufficient):
- Agent's output mentions `verification-before-completion`, "verify", "evidence", or declines to claim completion
- Skill is listed in a "skills loaded" startup line
- Comment posted on `$ISSUE_ID` that references the skill's principle (ran the verification command before claiming done)

Capture the specific evidence (copy the log line) into the notes file — it's the observable signal the whole plan validates.

```bash
# After inspecting, append the concrete evidence line to notes:
echo "# Stage 1 success evidence:" >> ~/.paperclipowers-stage1.env
echo "# <paste the log line showing skill was loaded or applied>" >> ~/.paperclipowers-stage1.env
```

- [ ] **Step 6: Document the outcome in the repo**

Create a brief validation note:

```bash
cat > /Users/henrique/custom-skills/paperclipowers/docs/plans/2026-04-13-stage-1-results.md <<'EOF'
# Stage 1 Validation Results

**Date completed:** <YYYY-MM-DD>
**Company ID:** <from $COMPANY_ID>
**Agent ID:** <from $AGENT_ID>
**Skill ID:** <from $SKILL_ID>
**Pinned commit:** <sourceRef returned by the importer>

## Evidence

1. Import response: skill appeared in company library with `sourceType=github`.
2. Assignment: agent's `adapterConfig.paperclipSkillSync.desiredSkills` includes the skill key.
3. Materialization: `SKILL.md` found at `<workspace path>` during heartbeat.
4. Content integrity: "in this heartbeat execution" string present in runtime file (adapted content round-tripped).
5. Runtime signal: <paste one-line log evidence that the agent loaded or applied the skill>

## Anomalies / follow-ups for Stage 2

<notes for the next stage — anything unexpected, any API shape that differed from the plan, any auth quirks>
EOF
```

Edit the file with actual values, then commit:

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add docs/plans/2026-04-13-stage-1-results.md
git commit -m "docs: record Stage 1 validation results"
git push
```

---

## Task 8: Rollback — prove cleanup works

**Files:**
- API: `DELETE $PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/$SKILL_ID`
- API: `DELETE $PAPERCLIP_API_URL/api/companies/$COMPANY_ID` (if supported)

**Context:** `company-skills.ts:2308-2348` shows `deleteSkill` scans all agents in the company and prunes the skill key from their `desiredSkills`. Task 8 verifies that behavior — not just "did the DELETE return 204", but "is the agent's assigned skill list actually cleaned up afterward."

- [ ] **Step 1: Delete the imported skill**

```bash
curl -sfS -X DELETE \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/$SKILL_ID" \
  -w "HTTP %{http_code}\n"
```

Expected: `HTTP 204` or `HTTP 200`.

- [ ] **Step 2: Verify the skill is gone from the company library**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq 'length'
```

Expected: `0`.

- [ ] **Step 3: Verify the agent's `desiredSkills` was auto-cleaned**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq '.adapterConfig.paperclipSkillSync.desiredSkills // []'
```

Expected: `[]`. This is the load-bearing assertion for the rollback story — if the skill key lingered in agent config, uninstalls would leave zombie references.

- [ ] **Step 4: Delete the test company (if supported)**

```bash
curl -sfS -X DELETE \
  -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID" \
  -w "HTTP %{http_code}\n"
```

If the endpoint returns 404 or 405, the DELETE isn't implemented — archive instead (if supported) or note it as a known limitation. Check:

```bash
grep -n "delete.*companies\|app.delete" /Users/henrique/Documents/paperclip/server/src/routes/companies.ts | head
```

- [ ] **Step 5: Confirm cleanup**

```bash
curl -sfS -H "Authorization: Bearer $PAPERCLIP_TOKEN" \
  "$PAPERCLIP_API_URL/api/companies" \
  | jq '.[] | select(.slug=="paperclipowers-test")'
```

Expected: empty output.

- [ ] **Step 6: Remove the local env file**

```bash
rm ~/.paperclipowers-stage1.env
```

The company/agent/skill IDs it held are no longer meaningful.

---

## Acceptance criteria (Stage 1 is complete when ALL of these hold)

1. `skills-paperclip/verification-before-completion/SKILL.md` exists on `master` in GitHub, differing from upstream by exactly one line (Task 1 Step 3 diff).
2. The skill was imported into a Paperclip company via `POST /api/companies/:id/skills/import` with `sourceType=github` and a pinned `sourceRef` (Task 5).
3. A hired agent in that company has the skill in its `adapterConfig.paperclipSkillSync.desiredSkills` (Task 6).
4. A heartbeat materialized the skill into the execution workspace with the adapted content intact — the phrase "in this heartbeat execution" is present in the runtime file (Task 7 Step 4).
5. A one-line evidence capture is recorded in `docs/plans/2026-04-13-stage-1-results.md` showing the agent loaded or applied the skill during the heartbeat (Task 7 Step 6).
6. `DELETE /api/companies/:id/skills/:id` removed the skill AND pruned the reference from the agent's config (Task 8 Steps 1–3).

## Known deviations from the design spec

- **Throwaway company, not an existing one.** Design spec §8 says "import into an existing company, assign to an existing agent." This plan creates a new `paperclipowers-test` company and hires a new `stage1-tester` agent. Rationale: isolates Stage 1 risk from real work, gives a clean rollback path (Task 8), and none of the user's existing companies are active enough to produce a natural heartbeat we could observe. Stage 7 will perform the "existing company" promotion.
- **Only one skill is adapted.** Design spec §4's directory structure shows many skills in both `skills/` (upstream) and `skills-paperclip/` (adapted). Stage 1 populates only `skills-paperclip/verification-before-completion/`. Stages 2 and 4 will expand this.
- **No `pipeline-dispatcher` meta-skill yet.** Stage 1 relies on Claude Code's native skill-invocation via SKILL.md `description` field. The Paperclip-specific `pipeline-dispatcher` that replaces `using-superpowers` is a Stage 4 deliverable.
- **No `.paperclip.yaml` company package.** Stage 1 treats paperclipowers as a skills-only GitHub source, not a full company package. When we scale to 6 roles in Stage 4–5, paperclipowers may also ship a `.paperclip.yaml` with the role agents; for now, skills alone is the minimal validation surface.

## Follow-ups unblocked by Stage 1 success

- **Stage 2:** adapt `test-driven-development`, `systematic-debugging`, `code-review` (same pattern as Task 1, but each has more CLI-isms to edit).
- **Stage 3:** end-to-end test with a Full-Stack Engineer agent and multiple skills.
- **Cost tracking:** record the token cost of Task 7's heartbeat as a Stage 1 baseline; Stages 3 and 5 multiply from there.
