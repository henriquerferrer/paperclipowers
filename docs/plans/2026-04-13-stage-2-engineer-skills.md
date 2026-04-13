# Stage 2 — Engineer-Layer Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt upstream `test-driven-development`, `systematic-debugging`, and a merged `code-review` (from `requesting-code-review` + `receiving-code-review` + `code-reviewer.md`) into Paperclip-native skills under `skills-paperclip/`, validate them on the Stage 1 throwaway company, and establish upstream-tracking infrastructure so future syncs are tractable.

**Architecture:** Two of the three skills (TDD, systematic-debugging) receive mostly-mechanical adaptations — small substitutions of CLI-specific language for Paperclip heartbeat/reassignment equivalents. The third (`code-review`) is a genuine restructure that merges three upstream files into a two-file skill spanning both reviewer and reviewee roles. Each adapted skill ships with an `UPSTREAM.md` provenance file recording the upstream base commit and edit list, and a `scripts/check-upstream-drift.sh` lets future sync passes diff each adapted skill against its recorded base. Validation reuses the Stage 1 throwaway company (`Paperclipowers Test`, id `02de212f-0ec4-4440-ac2f-0eb58cb2b2ad`) and the paused `stage1-tester` agent — unpaused, reassigned with all four Engineer skills, run through a materialization check plus four behavioral scenarios (one bait per skill plus an integration "fix the flaky test" scenario).

**Tech Stack:**
- `git` + GitHub (fork: `henriquerferrer/paperclipowers`, branch `paperclip-adaptation`)
- Paperclip HTTP API at `http://192.168.0.104:3100` (LAN-only; `authenticated` mode requires session cookie + matching `Origin:` header)
- `curl` + `jq` for API calls
- `ssh nas` for Docker-container filesystem inspection: `/usr/local/bin/docker exec paperclip sh -c '...'`
- Local clones: `/Users/henrique/custom-skills/paperclipowers/` (fork), `/Users/henrique/custom-skills/superpowers/` (upstream reference)

**Scope boundaries (what this plan does NOT do):**
- Does NOT build `_shared/heartbeat-interaction.md` / `_shared/paperclip-conventions.md` (deferred to Stage 4; Stage 2 inlines CLI→Paperclip substitutions in each skill)
- Does NOT adapt `brainstorming`, `writing-plans`, `task-orchestration`, or `pipeline-dispatcher` (Stage 4)
- Does NOT wire full model-selection policy into `task-orchestration` (Stage 4 owns the full policy; Stage 2 only adds a narrow escalation touch in `systematic-debugging` Phase 4.5)
- Does NOT test the full pipeline (Stage 5)
- Does NOT import into any real company (Stage 7)

**Reference documents (read before executing this plan):**
- Design spec: `docs/specs/2026-04-13-paperclipowers-design.md`
- Stage 1 plan (template): `docs/plans/2026-04-13-stage-1-validate-import-path.md`
- Stage 1 results (captured IDs + anomalies): `docs/plans/2026-04-13-stage-1-results.md`
- Upstream skills to adapt:
  - `skills/test-driven-development/SKILL.md`
  - `skills/test-driven-development/testing-anti-patterns.md`
  - `skills/systematic-debugging/SKILL.md`
  - `skills/systematic-debugging/root-cause-tracing.md`
  - `skills/systematic-debugging/defense-in-depth.md`
  - `skills/systematic-debugging/condition-based-waiting.md`
  - `skills/systematic-debugging/condition-based-waiting-example.ts`
  - `skills/systematic-debugging/find-polluter.sh`
  - `skills/requesting-code-review/SKILL.md`
  - `skills/requesting-code-review/code-reviewer.md`
  - `skills/receiving-code-review/SKILL.md`

**Captured identifiers from Stage 1 (re-usable):**
- `COMPANY_ID="02de212f-0ec4-4440-ac2f-0eb58cb2b2ad"` — `Paperclipowers Test` company, prefix `PAP`
- `AGENT_ID="cb7711f4-c785-491d-a21a-186b07d445e7"` — `stage1-tester`, role `engineer`, currently paused
- `PAPERCLIP_API_URL="http://192.168.0.104:3100"`

**Environment variables set throughout this plan (re-export in each terminal):**
- `PAPERCLIP_API_URL`, `PAPERCLIP_SESSION_COOKIE` — discovered/re-acquired in Task 1
- `COMPANY_ID`, `AGENT_ID` — re-imported from Stage 1 results doc in Task 1
- `TDD_SKILL_ID`, `DEBUG_SKILL_ID`, `REVIEW_SKILL_ID`, and matching `_KEY` variants — captured in Task 7
- `ISSUE_TDD`, `ISSUE_DEBUG`, `ISSUE_REVIEW`, `ISSUE_INTEGRATION` — captured in Tasks 10 and 11

**File structure (all paths relative to `/Users/henrique/custom-skills/paperclipowers/`):**

```
skills-paperclip/
├── test-driven-development/
│   ├── SKILL.md                         (adapted, ~5 substitutions vs upstream)
│   ├── testing-anti-patterns.md         (adapted, 2 substitutions)
│   └── UPSTREAM.md                      (new; provenance metadata)
├── systematic-debugging/
│   ├── SKILL.md                         (adapted, 2 substitutions + one section rewrite)
│   ├── root-cause-tracing.md            (verbatim from upstream)
│   ├── defense-in-depth.md              (verbatim from upstream)
│   ├── condition-based-waiting.md       (verbatim from upstream)
│   ├── condition-based-waiting-example.ts  (verbatim from upstream)
│   ├── find-polluter.sh                 (verbatim from upstream; +x bit preserved)
│   └── UPSTREAM.md                      (new; provenance metadata)
└── code-review/
    ├── SKILL.md                         (new; merged from 3 upstream files)
    ├── reviewer-prompt.md               (adapted from upstream code-reviewer.md)
    └── UPSTREAM.md                      (new; provenance metadata, flagged as "greenfield derivative")

scripts/
└── check-upstream-drift.sh              (new; diffs each adapted skill against its UPSTREAM.md base SHA)

docs/plans/
└── 2026-04-13-stage-2-results.md        (new; written at end of Task 12)
```

---

## Task 1: Re-acquire auth and restore Stage 1 identifiers

**Files:** Read-only: `docs/plans/2026-04-13-stage-1-results.md`. Creates: `~/.paperclipowers-stage2.env` (local, not committed).

**Context:** Stage 1's rollback deleted `~/.paperclipowers-stage1.env` (Task 8 Step 6). The throwaway company and agent still exist (per Stage 1 results anomalies: `companyDeletionEnabled: false`), but we need to re-authenticate and re-export their IDs before interacting with the API.

The Paperclip instance on the NAS runs in `authenticated` mode — mutations require a `better-auth.session_token` cookie AND a matching `Origin:` header (enforced by `board-mutation-guard` middleware). Bearer-token auth does NOT work. See `memory/paperclip_nas.md` for full details.

- [ ] **Step 1: Verify the NAS instance is reachable**

Run:

```bash
curl -sfS http://192.168.0.104:3100/api/health | jq .
```

Expected: JSON with `{"status": "ok", "companyDeletionEnabled": false, ...}`. If the request fails, verify you're on the home LAN (NAS is LAN-only) and that the Docker container is running:

```bash
ssh nas "/usr/local/bin/docker ps --format '{{.Names}} {{.Status}}' | grep paperclip"
```

Expected: two rows, both `Up ...` — `paperclip` (app) and `paperclip-db` (postgres).

- [ ] **Step 2: Acquire a session cookie**

Open a web browser, navigate to `http://192.168.0.104:3100`, log in with your Paperclip account, then in DevTools copy the value of the `better-auth.session_token` cookie (name may vary slightly — look for `session_token` in the Application → Cookies panel for the `192.168.0.104` origin).

Export it along with the API URL:

```bash
export PAPERCLIP_API_URL="http://192.168.0.104:3100"
export PAPERCLIP_SESSION_COOKIE="better-auth.session_token=<paste-cookie-value-here>"
```

- [ ] **Step 3: Verify cookie auth works for a read**

Run:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies" | jq 'length'
```

Expected: integer ≥ 1. If 401, the cookie is stale — re-fetch from DevTools and try again.

- [ ] **Step 4: Verify cookie auth works for a mutation (heartbeat force-trigger on the paused agent is harmless — the agent is paused so won't execute, but the endpoint still requires mutation auth)**

Actually do a safer write-test by PATCHing the agent's metadata to a no-op value:

```bash
curl -sfS -X GET \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/cb7711f4-c785-491d-a21a-186b07d445e7" | jq '{id, name, status, adapterType}'
```

Expected:
```json
{
  "id": "cb7711f4-c785-491d-a21a-186b07d445e7",
  "name": "stage1-tester",
  "status": "paused",
  "adapterType": "claude_local"
}
```

If the agent returns `status: paused`, proceed. If `status: idle` or other, either Stage 1 left state different from expected or someone touched it — inspect full payload and decide whether to re-pause before continuing.

- [ ] **Step 5: Restore Stage 1 identifiers as env vars and persist**

Run:

```bash
export COMPANY_ID="02de212f-0ec4-4440-ac2f-0eb58cb2b2ad"
export AGENT_ID="cb7711f4-c785-491d-a21a-186b07d445e7"

cat > ~/.paperclipowers-stage2.env <<EOF
export PAPERCLIP_API_URL="$PAPERCLIP_API_URL"
export PAPERCLIP_SESSION_COOKIE="$PAPERCLIP_SESSION_COOKIE"
export COMPANY_ID="$COMPANY_ID"
export AGENT_ID="$AGENT_ID"
EOF
chmod 600 ~/.paperclipowers-stage2.env
```

Expected: file exists, owner-only read/write. Re-source with `source ~/.paperclipowers-stage2.env` in any new terminal during this plan.

- [ ] **Step 6: Confirm the company skill library is empty (Stage 1 rollback removed the single skill)**

Run:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" | jq 'length'
```

Expected: `0` (Stage 1 Task 8 Step 2 asserted this was the state at end of Stage 1).

If > 0, inspect what's there:

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" | jq '.[] | {id, key, slug}'
```

If residual skills exist from experimentation, delete them before proceeding — Stage 2 validation assumes a clean starting library.

---

## Task 2: Adapt `test-driven-development` (SKILL.md + testing-anti-patterns.md)

**Files:**
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/SKILL.md`
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/testing-anti-patterns.md`
- Reference only: `/Users/henrique/custom-skills/paperclipowers/skills/test-driven-development/SKILL.md`
- Reference only: `/Users/henrique/custom-skills/paperclipowers/skills/test-driven-development/testing-anti-patterns.md`

**Context:** Upstream TDD is near-model-agnostic. The only CLI-specific language is the five "your human partner" escalation references. Each maps to "Tech Lead via reassignment + comment" in Paperclip — the Engineer's upstream dependency on a trusted human decision-maker → the Engineer's Paperclip dependency on the Tech Lead role that owns the plan. No other substantive changes required.

- [ ] **Step 1: Copy upstream TDD SKILL.md as starting point**

```bash
mkdir -p /Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development
cp /Users/henrique/custom-skills/paperclipowers/skills/test-driven-development/SKILL.md \
   /Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/SKILL.md
```

Expected: file exists, byte-identical to upstream.

- [ ] **Step 2: Apply substitution 1 — line 24 "Exceptions" section**

Edit `skills-paperclip/test-driven-development/SKILL.md`:

**Before:**
```
**Exceptions (ask your human partner):**
```

**After:**
```
**Exceptions (escalate to Tech Lead via reassignment + comment):**
```

- [ ] **Step 3: Apply substitution 2 — line ~346 "When Stuck" table, "Don't know how to test" row**

**Before:**
```
| Don't know how to test | Write wished-for API. Write assertion first. Ask your human partner. |
```

**After:**
```
| Don't know how to test | Write wished-for API. Write assertion first. Set `status: blocked` and reassign to Tech Lead with comment explaining which test you're trying to write. |
```

- [ ] **Step 4: Apply substitution 3 — line ~371 "Final Rule"**

**Before:**
```
No exceptions without your human partner's permission.
```

**After:**
```
No exceptions without Tech Lead approval via reassignment + comment. If the Tech Lead agrees the task falls into an exception category (throwaway prototype, generated code, configuration), they will re-open the subtask with updated instructions.
```

- [ ] **Step 5: Verify the SKILL.md diff is exactly the three substitutions, nothing else**

Run:

```bash
diff /Users/henrique/custom-skills/paperclipowers/skills/test-driven-development/SKILL.md \
     /Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/SKILL.md
```

Expected: three change hunks, corresponding to lines 24, ~346, and ~371. Line numbers from upstream reference.

If any other lines differ, revert to Step 1 and retry. Do NOT proceed with extra edits — keep the delta minimal for upstream-tracking.

- [ ] **Step 6: Copy upstream testing-anti-patterns.md as starting point**

```bash
cp /Users/henrique/custom-skills/paperclipowers/skills/test-driven-development/testing-anti-patterns.md \
   /Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/testing-anti-patterns.md
```

- [ ] **Step 7: Apply substitution 4 — line 37 "your human partner's correction"**

Edit `skills-paperclip/test-driven-development/testing-anti-patterns.md`:

**Before:**
```
**your human partner's correction:** "Are we testing the behavior of a mock?"
```

**After:**
```
**Self-check question:** "Am I testing the behavior of a mock?"
```

- [ ] **Step 8: Apply substitution 5 — line 259 "your human partner's question"**

**Before:**
```
**your human partner's question:** "Do we need to be using a mock here?"
```

**After:**
```
**Self-check question:** "Do I actually need a mock here?"
```

- [ ] **Step 9: Verify the testing-anti-patterns.md diff**

Run:

```bash
diff /Users/henrique/custom-skills/paperclipowers/skills/test-driven-development/testing-anti-patterns.md \
     /Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/testing-anti-patterns.md
```

Expected: two change hunks at lines 37 and 259.

- [ ] **Step 10: Verify frontmatter parses**

Run:

```bash
head -4 /Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/SKILL.md
```

Expected:
```
---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---
```

The `name` and `description` must be present and unchanged — Paperclip's `parseFrontmatterMarkdown` reads these for skill-library display and for Claude Code's skill description matching.

---

## Task 3: Adapt `systematic-debugging` (SKILL.md + 5 supporting files)

**Files:**
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/SKILL.md`
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/root-cause-tracing.md` (verbatim)
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/defense-in-depth.md` (verbatim)
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/condition-based-waiting.md` (verbatim)
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/condition-based-waiting-example.ts` (verbatim)
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/find-polluter.sh` (verbatim, executable bit preserved)

**Context:** Upstream systematic-debugging SKILL.md has two "your human partner" sites (line 211 in Phase 4.5 architectural-question guidance, and lines 234-243 "your human partner's Signals You're Doing It Wrong" section). Line 211 maps to Paperclip escalation + the `assigneeAdapterOverrides.model` re-open mechanism (honoring the upstream "re-dispatch with more capable model" escalation semantics via Paperclip's per-issue model override). The "Signals" section becomes "Signals from inbound comments" — describing patterns visible in issue comment threads.

Cross-references to `superpowers:test-driven-development` and `superpowers:verification-before-completion` become slug-only (per Q3 decision — portable to any company importing paperclipowers).

The 5 supporting files carry no CLI-isms and port verbatim. The `find-polluter.sh` script references `npm test`; a comment is added noting that for non-JS test runners the agent should adapt the test-runner invocation, and that bisection on large suites may need multiple heartbeats.

- [ ] **Step 1: Copy upstream SKILL.md as starting point**

```bash
mkdir -p /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging
cp /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/SKILL.md \
   /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/SKILL.md
```

- [ ] **Step 2: Apply substitution 1 — line 211 Phase 4.5 escalation**

Edit `skills-paperclip/systematic-debugging/SKILL.md`. Find the "If 3+ Fixes Failed: Question Architecture" block:

**Before (line 211):**
```
   **Discuss with your human partner before attempting more fixes**
```

**After:**
```
   **Set `status: blocked`, reassign the subtask to the Tech Lead with a comment explaining the architectural concern.** The Tech Lead may re-open the subtask with updated instructions or a more capable model (via `assigneeAdapterOverrides.model` — the Paperclip equivalent of "re-dispatch with a stronger model" from upstream superpowers). Do not attempt Fix #4 on your own.
```

- [ ] **Step 3: Apply substitution 2 — replace lines 234-243 "your human partner's Signals" section**

Find the section starting with `## your human partner's Signals You're Doing It Wrong`. Replace the entire section (header + bullet list + "When you see these" line) with:

**After:**
```markdown
## Signals from Inbound Comments

**Watch for these patterns in comments posted on your assigned issue (from Tech Lead, Reviewer, or the board):**
- "Is that not happening?" — you assumed without verifying; add diagnostic instrumentation, don't guess
- "Will it show us...?" — you should have gathered evidence before proposing a fix
- "Stop guessing" — you're proposing fixes without understanding; return to Phase 1
- "Question this more carefully" or "think this through from the top" — question fundamentals, not just symptoms
- A new comment arrives after you set `status: in_review` rejecting your claim of done — your approach isn't working; return to Phase 1 with the new information

**When you see these:** STOP. Do not post another fix attempt. Return to Phase 1 and gather more evidence before responding.
```

- [ ] **Step 4: Apply substitution 3 — slug-only cross-references at lines ~179 and ~287-288**

Find the two upstream references to `superpowers:test-driven-development` and `superpowers:verification-before-completion` and rewrite both.

**Before (in Phase 4 Step 1, around line 179):**
```
   - Use the `superpowers:test-driven-development` skill for writing proper failing tests
```

**After:**
```
   - Use the `test-driven-development` skill for writing proper failing tests
```

**Before (in the "Related skills" list, around lines 287-288):**
```
- **superpowers:test-driven-development** - For creating failing test case (Phase 4, Step 1)
- **superpowers:verification-before-completion** - Verify fix worked before claiming success
```

**After:**
```
- **`test-driven-development`** — For creating failing test case (Phase 4, Step 1)
- **`verification-before-completion`** — Verify fix worked before claiming success
```

- [ ] **Step 5: Verify the SKILL.md diff touches only the expected regions**

Run:

```bash
diff /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/SKILL.md \
     /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/SKILL.md
```

Expected: 4 change hunks — one at line 211 (single line), one spanning lines ~234-243 (section replacement), one at line ~179 (cross-ref), one at ~287-288 (two cross-refs).

If more hunks appear, revert to Step 1 and retry.

- [ ] **Step 6: Copy the 3 supporting markdown files verbatim**

```bash
cp /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/root-cause-tracing.md \
   /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/root-cause-tracing.md

cp /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/defense-in-depth.md \
   /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/defense-in-depth.md

cp /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/condition-based-waiting.md \
   /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/condition-based-waiting.md
```

- [ ] **Step 7: Verify the 3 files are byte-identical to upstream**

Run:

```bash
for f in root-cause-tracing.md defense-in-depth.md condition-based-waiting.md; do
  echo "=== $f ==="
  diff "/Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/$f" \
       "/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/$f" \
    || echo "  DIFFERS — investigate"
done
```

Expected: no output from any `diff` invocation (byte-identical).

- [ ] **Step 8: Copy the `.ts` example and `.sh` bisection script, preserving permissions**

```bash
cp -p /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/condition-based-waiting-example.ts \
      /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/condition-based-waiting-example.ts

cp -p /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/find-polluter.sh \
      /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/find-polluter.sh
```

The `-p` flag preserves the executable bit on `find-polluter.sh`.

- [ ] **Step 9: Verify the `.sh` executable bit is preserved**

Run:

```bash
ls -l /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/find-polluter.sh
```

Expected: permissions include `x` (e.g., `-rwxr-xr-x`). If not executable:

```bash
chmod +x /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/find-polluter.sh
```

- [ ] **Step 10: Add a Paperclip-context header comment to `find-polluter.sh`**

Edit the script to add context after line 2 (the existing `# Bisection script ...` comment). Insert these lines after line 4:

**Insert after line 4:**
```bash
#
# Paperclip note: this script assumes an `npm test <file>` test runner. For
# non-JS projects (Python pytest, Go go test, Rust cargo test, etc.), edit
# line 42 to invoke the correct runner. Large suites may exceed a single
# heartbeat window — if the agent is interrupted mid-bisection, continue
# from the last tested file on the next heartbeat.
```

Verify no other changes:

```bash
diff /Users/henrique/custom-skills/paperclipowers/skills/systematic-debugging/find-polluter.sh \
     /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/find-polluter.sh
```

Expected: one change hunk — the 6 new comment lines.

- [ ] **Step 11: Verify frontmatter on SKILL.md is intact**

```bash
head -4 /Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/SKILL.md
```

Expected:
```
---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
---
```

---

## Task 4: Merge upstream `requesting-code-review` + `receiving-code-review` + `code-reviewer.md` into `code-review/`

**Files:**
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/SKILL.md`
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/reviewer-prompt.md`
- Reference only: `/Users/henrique/custom-skills/paperclipowers/skills/requesting-code-review/SKILL.md`
- Reference only: `/Users/henrique/custom-skills/paperclipowers/skills/requesting-code-review/code-reviewer.md`
- Reference only: `/Users/henrique/custom-skills/paperclipowers/skills/receiving-code-review/SKILL.md`

**Context:** This is the one genuinely restructured skill. Upstream splits the concern into:
- `requesting-code-review/SKILL.md` — CLI workflow for an agent to dispatch a code-reviewer subagent via the Task tool
- `requesting-code-review/code-reviewer.md` — the reviewer's task prompt (pure checklist + output format)
- `receiving-code-review/SKILL.md` — discipline for evaluating incoming review feedback

In Paperclip, the "dispatch subagent" mechanic becomes issue reassignment (design spec §3.2, §5.2). The merged skill serves two positions held by agents in the pipeline:
- **Reviewer** — reviewing artifacts across four triggers (spec, plan, per-subtask code diff, final combined code diff). Replaces the design spec's separate Quality Reviewer and Code Reviewer + QA roles; Stage 2 planning resolved these into one consolidated Reviewer role since all four triggers use the same skill and checklist.
- **Full-Stack Engineer / Designer** — when woken with review findings, evaluating them without performative agreement.

The skill has two major parts (Performing / Receiving) plus shared sections on comment etiquette and red flags. The reviewer's checklist lives in the companion `reviewer-prompt.md` (derived from upstream `code-reviewer.md`) — reviewers open it before posting findings to ensure structure.

Per Q1 decision: this skill is also assigned to the Engineer (deviation from design spec §3.1 role matrix, documented in the `UPSTREAM.md` and at the bottom of this plan). Per QA-timing resolution: same Reviewer agent handles all four triggers (per-subtask + final), matching upstream's catch-early discipline.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review
```

- [ ] **Step 2: Write `code-review/SKILL.md`**

Write the full contents of `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/SKILL.md`:

```markdown
---
name: code-review
description: Use when you are assigned an issue to review (as Reviewer) or when you have been reassigned an issue with review findings (as Engineer or Designer). Covers all four review triggers (spec, plan, per-subtask diff, final combined diff), posting categorized findings, and evaluating received feedback without performative agreement.
---

# Code Review

## Overview

Code review in Paperclip serves a single Reviewer role across four trigger points, plus reviewee discipline when feedback comes back. At any given moment you are in one of two positions:

- **Performing review** — reading an artifact (spec document, plan document, per-subtask code diff, or final combined code diff) and posting categorized findings as comments on the issue
- **Receiving review** — evaluating feedback on technical merit, pushing back when wrong, implementing when right

This skill covers both. The reviewer's checklist and output format live in the companion `reviewer-prompt.md` in this directory.

**Core principle:** Review early, review often. Evaluate feedback on technical merit, not social pressure.

## When to Invoke

**If you are the Reviewer, you wake on one of four triggers:**

1. **Spec review** — the PM has written a `spec` document and created an approval. Read the spec against the parent issue's ask, post findings, the approval proceeds to the board.
2. **Plan review** — the Tech Lead has written a `plan` document and created an approval. Read the plan against the approved spec (schemas concrete? vertical slicing sound? acceptance criteria testable?), post findings, the approval proceeds to the board.
3. **Per-subtask code review** — an Engineer (or Designer) has marked a subtask `done`. Read that subtask's git diff against the plan's acceptance criteria for that slice, post findings, and either approve (parent moves closer to complete, dependent subtasks become unblocked) or reject (reassign to the subtask's last assignee with specific fixes).
4. **Final combined review** — all subtasks are done and the parent feature issue has reached `in_review`. Read the full base→HEAD diff, run the test suite end-to-end, verify against the full plan's acceptance criteria, then either approve (create PR, mark parent done) or reject (identify which subtask introduced the problem, reassign that subtask with findings).

Same Reviewer agent handles all four triggers — each heartbeat wake is a fresh context load, so separate triggers never share stale state.

**If you are the reviewee** (Engineer or Designer):
- You have been reassigned an issue whose status changed from `in_review` back to `in_progress` or `todo`
- New comments on your issue contain review findings
- A comment explicitly references categories (Critical / Important / Minor) with file:line references

## Part 1: Performing Review

### 1.1 Read Full Context Before Evaluating

Before posting anything:
- Read the issue description and full comment thread
- If reviewing a spec or plan, fetch the issue document: `GET /api/issues/{id}/documents/{key}` where key is `spec` or `plan`
- If reviewing code, read the plan document first (to know the acceptance criteria) then compute the git diff range
- Read ancestor issues (parent, grandparent) for context on the broader feature goal

**Never** post findings based on only the issue title or a partial read. Fresh-context review is the whole point — but "fresh context" means new perspective, not incomplete information.

### 1.2 Compute the Review Range

For code review:

```bash
BASE_SHA=$(git rev-parse <merge-base-or-plan-starting-commit>)
HEAD_SHA=$(git rev-parse HEAD)
git diff --stat $BASE_SHA..$HEAD_SHA
git diff $BASE_SHA..$HEAD_SHA
```

The base SHA is typically:
- The commit at which the Tech Lead's plan was approved (if recorded in a comment or the plan document)
- The parent feature branch's base if this is a full-feature review
- `HEAD~1` if reviewing the most recent subtask's diff

For spec/plan review: no diff — read the full document. Compare it against the parent issue's ask and any ancestor constraints.

### 1.3 Use the Reviewer Checklist

Open `reviewer-prompt.md` in this directory. It has the full checklist covering Code Quality / Architecture / Testing / Requirements / Production Readiness, plus the output format. Follow it item by item — do not skip sections.

### 1.4 Post Structured Findings

Post your findings as a comment on the issue, using the exact format in `reviewer-prompt.md`:

```
### Strengths
[Specific positives with file:line refs]

### Issues

#### Critical (Must Fix)
[Bugs, security issues, data loss risks, broken functionality]

#### Important (Should Fix)
[Architecture problems, missing features, poor error handling, test gaps]

#### Minor (Nice to Have)
[Code style, optimization opportunities, documentation improvements]

### Recommendations
[Process or quality improvements]

### Assessment
**Ready to merge:** Yes / No / With fixes
**Reasoning:** [1-2 sentences]
```

**Critical rules:**
- Categorize by actual severity. Not everything is Critical.
- Be specific. `file:line` references, not vague regions.
- Explain WHY each issue matters.
- Acknowledge strengths. A review that only lists issues is incomplete.
- Give a clear verdict. "Looks good" is not a verdict.

### 1.5 Approval Gate Outcome

Your next action depends on which trigger woke you:

**Spec or plan review (triggers 1-2) — if approving:**
- The formal approval proceeds to the next approver (board). Your comment serves as context for the board's decision.
- Call the approval endpoint: `POST /api/approvals/{id}/approve` (Stage 4's `_shared/paperclip-conventions.md` will formalize this).

**Spec or plan review — if rejecting:**
- Call `POST /api/approvals/{id}/reject` with your findings comment as context
- The issue reassigns back to the document's author — PM for spec, Tech Lead for plan — who revises and creates a new approval

**Per-subtask code review (trigger 3) — if approving:**
- Post the findings comment with `Ready to merge: Yes`. The orchestrator transitions the subtask to its completed state, freeing dependent subtasks per `blockedByIssueIds` (exact transition mechanism formalized in Stage 5).

**Per-subtask code review — if rejecting:**
- Set the subtask status back to `in_progress` or `todo`
- Reassign to the subtask's last assignee (Engineer, or Designer if visual changes caused the regression) via `PATCH /api/issues/{id}` with `assigneeAgentId`
- Your findings comment provides the specific fixes; reassignment triggers the reviewee's next heartbeat

**Final combined review (trigger 4) — if approving:**
- Create the PR via the workspace's git integration (exact mechanism varies per deployment; typically `git push` + `gh pr create` in the execution workspace)
- Mark the parent issue `done`

**Final combined review — if rejecting:**
- Identify which subtask introduced the failing behavior — use `git log` to find the offending commit, map commits to subtasks via the commit-message convention or the subtask's branch
- Re-open that specific subtask (`in_progress`), reassign it to its original assignee with findings
- The parent stays in `in_review` until the re-opened subtask completes and re-passes per-subtask QA (trigger 3 on the re-opened subtask)

**For any trigger — if finding architectural issues** that indicate the plan itself is wrong:
- Escalate to the Tech Lead via reassignment, not back to the Engineer
- Comment explaining why this is a plan-level issue, not an implementation-level issue

## Part 2: Receiving Review Feedback

### 2.1 The Response Pattern

When you wake up to find review findings in your issue comments:

```
1. READ: Complete feedback without reacting. Read every comment in the thread.
2. UNDERSTAND: Restate each finding in your own words (in your head, or in a comment if genuinely unclear).
3. VERIFY: Check the claims against the actual codebase. Does the reviewer's file:line reference exist? Is the issue real?
4. EVALUATE: Is the suggested change technically sound for THIS codebase, THIS stack, THIS task's scope?
5. RESPOND: Technical acknowledgment or reasoned pushback via issue comment.
6. IMPLEMENT: One item at a time. Verify each fix before moving to the next.
```

### 2.2 Forbidden Responses

**NEVER** post or think:
- "You're absolutely right!"
- "Great point!" / "Excellent feedback!"
- "Thanks for catching that!" / ANY gratitude expression
- "Let me implement that now" (before verification)

**INSTEAD:**
- Restate the technical requirement in a comment ("I'll add input validation to `parseConfig` — the null-byte case on line 42 was missed because the regex only checks for whitespace.")
- Ask clarifying questions in a comment if truly unclear
- Push back with technical reasoning via comment if you believe the reviewer is wrong
- Or just start working — actions speak, and the commit will show the fix

**Why no gratitude:** In an async pipeline, gratitude is noise. The code IS the acknowledgment. Comments should carry technical content only.

### 2.3 Handling Unclear Feedback

```
IF any finding is unclear:
  STOP — do not implement anything yet
  Post a single comment asking for clarification on ALL unclear items
  Set status: blocked if the clarifications must come before any progress

WHY: Items may be related. Partial understanding = wrong implementation.
```

**Example:**

> Reviewer comment: "Issues 1, 2, and 3 as listed above — please fix."
> You understand issues 1 and 3 clearly. Issue 2 is ambiguous.
>
> ❌ WRONG: implement 1 and 3 now, ask about 2 later
> ✅ RIGHT: Post a single comment: "Working on 1 and 3 after confirmation. On issue 2: is `X` meant to refer to the `Y` function in `bar.ts`, or the newer `Y2` helper in `baz.ts`? My read is `Y2`, but confirm before I touch it."

### 2.4 YAGNI Check

```
IF a reviewer suggests "implementing properly" or "adding X for robustness":
  grep the codebase for actual usage of the thing being improved

  IF unused: Post a comment — "Grepped the codebase; nothing calls this endpoint. Removing it (YAGNI) instead of hardening unused code — flag if you disagree."
  IF used: Then implement the improvement
```

**Why:** In Paperclip, both you and the reviewer report to the board. If the feature isn't needed, hardening it wastes work. The reviewer's job is to catch quality issues, not to grow scope.

### 2.5 Implementation Order

For multi-item feedback:

```
1. Resolve anything unclear FIRST (Section 2.3)
2. Then implement in this order:
   - Blocking issues (breaks functionality, security risks)
   - Simple fixes (typos, imports, renames)
   - Complex fixes (refactoring, logic changes)
3. Run tests after each fix
4. Verify no regressions before committing
5. Commit each logical group separately with a clear message
```

### 2.6 When to Push Back

Push back — via a comment on the issue — when:
- The suggested change would break existing functionality (show the test that would fail)
- The reviewer lacks full context (explain the constraint they missed, e.g., "this file is also called from X which requires the old signature")
- It violates YAGNI (unused feature — see Section 2.4)
- It's technically incorrect for this codebase's stack (cite the version/platform)
- A legacy/compatibility constraint exists (link the original decision)
- It conflicts with the Tech Lead's plan (flag it as a plan-level issue; reassign to Tech Lead, not to the reviewer)

**How to push back:**
- Use technical reasoning. Reference tests, types, constraints, or prior decisions.
- Be specific. "I disagree" is not pushback; "I disagree because `foo.test.ts:42` proves the current behavior is correct" is.
- Ask specific questions if you need more information.
- If the disagreement is architectural, reassign to the Tech Lead rather than hashing it out with the reviewer.

### 2.7 Acknowledging Correct Feedback

When feedback is right:

✅ Just fix it. The commit shows you heard.
✅ If you need to comment, state the fix: "Added null check at `parseConfig.ts:42`. Test added at `parseConfig.test.ts:115`."
✅ "Good catch on the race condition — the fix is using a single atomic transaction at `db.ts:88`."

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!"
❌ ANY gratitude expression

**If you catch yourself about to write "Thanks":** Delete it. State the fix instead.

### 2.8 Correcting Your Own Pushback

If you pushed back and then verified the reviewer was right:

✅ "You were right — I checked `foo.ts:42` and it does hit the null-path. Implementing the fix."
✅ "Verified; my initial reading missed that `bar.ts:100` calls this with nullable input. Fixing now."

❌ Long apology
❌ Defending why you pushed back
❌ Over-explaining

State the correction factually in a single comment, then move on.

## Part 3: Comment Thread Etiquette

- **Reply in the issue's comment thread** — don't open a new top-level comment for each back-and-forth
- **Reference line numbers** in your codebase — `foo.ts:42` — not in your comment text
- **One logical topic per comment** — if you have three different responses, consider three comments or one comment with numbered sections
- **Link to the specific document revision** if the document has changed since the review — issue documents are versioned
- **No meta-commentary** — don't post "I'll look at this tomorrow" or "on it" in comments; just start work and the next heartbeat's activity log will show progress

## Red Flags — STOP

If you catch yourself:
- Performatively agreeing before verifying
- Implementing without reading the full context
- Batching fixes without testing each one
- Arguing social tone rather than technical substance
- Ignoring a Critical finding because "I'm sure it's fine"
- Skipping the reviewer checklist because "I've done this before"
- Marking a review complete without running the test suite (for QA)
- Writing "thanks" anywhere

**All of these mean:** stop, return to the relevant section's procedure.

## The Bottom Line

**Reviewer:** read fully, categorize by real severity, be specific, give a clear verdict.

**Reviewee:** verify before implementing, push back with technical reasoning, no performative agreement.

Mocks are tools. Comments are artifacts. Reviews are artifacts. Actions are the only acknowledgment.

## See Also

- `reviewer-prompt.md` — the reviewer's checklist and output format (open it when performing review)
- `test-driven-development` — for adding the test that proves a fix works (Part 2, Section 2.5)
- `verification-before-completion` — evidence before claiming done after fixing review issues
- `systematic-debugging` — when a review finding points to an apparent symptom whose root cause is elsewhere
```

- [ ] **Step 3: Write `code-review/reviewer-prompt.md`**

Write the full contents of `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/reviewer-prompt.md`:

```markdown
# Reviewer Prompt — Checklist and Output Format

This is the reviewer's reference. Open it when performing a review (Part 1 of `SKILL.md`). Follow the checklist section-by-section before posting your findings comment.

## Your Role

You are reviewing code (or a spec / plan) for production readiness. You arrived at this review with no prior context from the implementation work — that's the point. Your job is fresh-context evaluation against the stated requirements.

## Inputs You Should Have Before Starting

- The issue description (the ask)
- The plan document (the acceptance criteria) — fetch via `GET /api/issues/{id}/documents/plan` on the parent issue
- The git diff range if reviewing code (`git diff $BASE..$HEAD`)
- The document content if reviewing a spec or plan (`GET /api/issues/{id}/documents/{key}`)
- Ancestor issues for context on the broader feature goal

If any of these are missing or ambiguous, post a clarification comment FIRST. Do not review blind.

## Review Checklist

### Code Quality
- [ ] Clean separation of concerns — files have one clear responsibility
- [ ] Proper error handling at system boundaries (external APIs, user input); no over-validation of internal call sites
- [ ] Type safety where the language supports it
- [ ] DRY — no copy-pasted logic within this diff
- [ ] Edge cases covered (null, empty, max size, unicode, concurrent access as applicable)

### Architecture
- [ ] Design decisions match the plan's approach
- [ ] Scalability considerations appropriate for expected load (not over-engineered for hypothetical load)
- [ ] Performance — no obviously quadratic loops, no missing indexes, no N+1 queries
- [ ] Security — no secrets in code, no injection risks, no bypassed authentication

### Testing
- [ ] Tests exist for every new function / method
- [ ] Tests verify real behavior, not mock behavior (see `test-driven-development/testing-anti-patterns.md`)
- [ ] Edge cases have explicit tests
- [ ] Integration tests where multi-component interaction matters
- [ ] All tests pass; output is pristine (no warnings, no errors)

### Requirements
- [ ] All plan requirements met — cross-reference each plan acceptance criterion to a file:line
- [ ] Implementation matches the spec's intent (not just the letter)
- [ ] No scope creep — changes outside the plan's scope should be flagged
- [ ] Breaking changes (if any) documented in the PR description or issue comment

### Production Readiness
- [ ] Migration strategy present if schema changed
- [ ] Backward compatibility considered for API changes
- [ ] No obviously unmaintained code added (TODO-with-no-owner, commented-out code, dead branches)
- [ ] No debug prints / console.log leftovers
- [ ] Environment variables / config changes documented

## Output Format

Post your findings as a single comment on the issue. Use exactly this structure:

```
### Strengths

- [Specific positive with file:line ref. E.g., "Clean separation in `parseConfig.ts:15-42` — the validator and the parser are correctly decoupled."]
- [Another specific positive.]
- [...]

### Issues

#### Critical (Must Fix)

[Only use Critical for: bugs that break functionality, security issues, data loss risks, missing required plan items. If nothing is Critical, write "None."]

1. **[Short title]**
   - File: `path/to/file.ts:42`
   - What's wrong: [Concrete description]
   - Why it matters: [Concrete impact]
   - How to fix: [Specific direction; omit if obvious from what's wrong]

#### Important (Should Fix)

[Architecture problems, missing features from the plan, poor error handling at system boundaries, test gaps for the happy path or common edge cases.]

1. **[Short title]**
   - File: `path/to/file.ts:42`
   - What's wrong: [Concrete description]
   - Why it matters: [Concrete impact]
   - How to fix: [Specific direction]

#### Minor (Nice to Have)

[Code style, naming, optimization opportunities, documentation improvements, test-suite hygiene.]

1. **[Short title]**
   - File: `path/to/file.ts:42`
   - Impact: [Brief note]

### Recommendations

[Any process or quality improvements that apply beyond this specific change. Optional — omit the section if none.]

### Assessment

**Ready to merge:** Yes / No / With fixes

**Reasoning:** [1-2 sentences tying the assessment to the findings above. E.g., "Core implementation is solid with good test coverage. Important issues (null handling in parseConfig, missing integration test for the migration path) are easily fixed and don't require architectural changes."]
```

## DO

- Categorize by actual severity. Not everything is Critical. A nitpick is a nitpick.
- Be specific. `file:line` references, not vague descriptions of regions.
- Explain WHY issues matter. "Missing null check" is weak; "Missing null check at line 42 — caller at `handler.ts:88` passes nullable input from the DB query on line 76" is strong.
- Acknowledge strengths. Reviews that only list issues are incomplete.
- Give a clear verdict. The reviewee needs to know if they can proceed.

## DON'T

- Don't say "looks good" without running through the checklist.
- Don't mark nitpicks as Critical. Critical means something will break or leak data.
- Don't give feedback on code you didn't actually read.
- Don't be vague ("improve error handling" is not actionable — say where and how).
- Don't avoid giving a clear verdict because you're uncertain — request clarification or assess as "With fixes" and list what must be fixed.

## Example Output

```
### Strengths

- Clean database schema with proper migration file (`db/migrations/0042_add_sessions.ts:1-35`).
- Comprehensive test coverage — 18 tests across happy path, error cases, and concurrent access (`session.test.ts`).
- Good error handling with fallbacks at the API boundary (`api/sessions.ts:85-92`).

### Issues

#### Critical

None.

#### Important

1. **Missing help text in CLI wrapper**
   - File: `bin/index-conversations.ts:1-31`
   - What's wrong: No `--help` flag handler; users can't discover `--concurrency` option from the CLI.
   - Why it matters: The plan specifies CLI usability as an acceptance criterion (plan section 4.2).
   - How to fix: Add a `--help` case to the argv switch, print usage example including `--concurrency`.

2. **Date validation missing**
   - File: `api/search.ts:25-27`
   - What's wrong: Invalid ISO date strings silently return empty result sets instead of throwing.
   - Why it matters: Users cannot distinguish "no matches" from "your input was wrong."
   - How to fix: Validate ISO format at the entry point; throw a descriptive error with an example of the expected format.

#### Minor

1. **Progress indicators**
   - File: `indexer.ts:130`
   - Impact: No "X of Y" counter for long indexing runs. Users don't know how long to wait. Not a plan requirement, but a UX improvement worth considering.

### Recommendations

- Consider extracting the date-validation logic into a shared helper — the same pattern will recur in future endpoints.

### Assessment

**Ready to merge:** With fixes

**Reasoning:** Core implementation is solid with good tests and architecture. The two Important issues (help text, date validation) are both plan requirements and should be fixed before merge. Minor issues can be addressed in follow-up.
```
```

- [ ] **Step 4: Verify both files parse**

Run:

```bash
head -4 /Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/SKILL.md
head -2 /Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/reviewer-prompt.md
```

Expected SKILL.md output:
```
---
name: code-review
description: Use when you are assigned an issue to review (as Reviewer) or when you have been reassigned an issue with review findings (as Engineer or Designer). Covers all four review triggers (spec, plan, per-subtask diff, final combined diff), posting categorized findings, and evaluating received feedback without performative agreement.
---
```

Expected reviewer-prompt.md output:
```
# Reviewer Prompt — Checklist and Output Format

```

`reviewer-prompt.md` has no frontmatter — it's a reference file, not an entry-point SKILL.md. Only SKILL.md participates in Claude Code's skill-invocation matching.

- [ ] **Step 5: Verify no stray CLI-isms were inadvertently introduced**

Run:

```bash
grep -E "human partner|subagent|Task tool|dispatch|in this message|Circle K" \
  /Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/*.md || echo "CLEAN"
```

Expected: `CLEAN` (no matches). If any matches, review the file — the merger should have rewritten all CLI-specific language.

---

## Task 5: Add upstream-tracking infrastructure

**Files:**
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/UPSTREAM.md`
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/UPSTREAM.md`
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/UPSTREAM.md`
- Create: `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/verification-before-completion/UPSTREAM.md` (retroactive for Stage 1)
- Create: `/Users/henrique/custom-skills/paperclipowers/scripts/check-upstream-drift.sh`

**Context:** Each adapted skill gets a provenance file recording the upstream base commit and the specific edits applied. When upstream obra/superpowers releases new versions, a drift-check script diffs each adapted skill's upstream base against current upstream HEAD and flags which skills need review. This keeps the update cost tractable as paperclipowers accumulates more adapted skills over Stages 4-6.

Stage 1's `verification-before-completion` retroactively gets an `UPSTREAM.md` so the provenance system covers everything from Stage 1 onward.

- [ ] **Step 1: Capture the current upstream base SHA**

The "upstream base" is the commit in `skills/` (which mirrors obra/superpowers) that our adaptations are based on. Since `skills/` is synced via the fork's `main` branch from upstream, `HEAD:skills/<name>/` is the base for our adapted `skills-paperclip/<name>/`.

Compute it:

```bash
cd /Users/henrique/custom-skills/paperclipowers
UPSTREAM_BASE_SHA=$(git rev-parse HEAD)
echo "UPSTREAM_BASE_SHA=$UPSTREAM_BASE_SHA"
```

Record this SHA. It goes into every UPSTREAM.md file written in this task.

- [ ] **Step 2: Write `verification-before-completion/UPSTREAM.md`** (retroactive, Stage 1)

Write to `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/verification-before-completion/UPSTREAM.md`:

```markdown
# Upstream Provenance — verification-before-completion

**Stage introduced:** Stage 1
**Adaptation type:** Mechanical substitution (1 line)
**Last synced:** <TODAY_DATE>
**Upstream base commit:** <UPSTREAM_BASE_SHA>
**Upstream source path:** `skills/verification-before-completion/SKILL.md`

## Edits applied

1. **SKILL.md line 22** — replaced "in this message" with "in this heartbeat execution" (design spec §5.1).

## Update procedure

When upstream changes `skills/verification-before-completion/`, run `scripts/check-upstream-drift.sh verification-before-completion`. If changes occur outside line 22, inspect and re-port manually. If only the substituted line changed, reapply the substitution.

This skill has low drift risk — upstream is mostly model-agnostic and the single adaptation is trivially re-appliable.
```

Replace `<TODAY_DATE>` with today's date (`date -u +%Y-%m-%d`) and `<UPSTREAM_BASE_SHA>` with the SHA from Step 1.

- [ ] **Step 3: Write `test-driven-development/UPSTREAM.md`**

Write to `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/test-driven-development/UPSTREAM.md`:

```markdown
# Upstream Provenance — test-driven-development

**Stage introduced:** Stage 2
**Adaptation type:** Mechanical substitutions (5 total across 2 files)
**Last synced:** <TODAY_DATE>
**Upstream base commit:** <UPSTREAM_BASE_SHA>
**Upstream source paths:**
- `skills/test-driven-development/SKILL.md`
- `skills/test-driven-development/testing-anti-patterns.md`

## Edits applied

### SKILL.md

1. **Line 24** — "Exceptions (ask your human partner):" → "Exceptions (escalate to Tech Lead via reassignment + comment):"
2. **Line ~346** ("When Stuck" table, "Don't know how to test" row) — "Ask your human partner." → "Set `status: blocked` and reassign to Tech Lead with comment..."
3. **Line ~371** ("Final Rule") — "No exceptions without your human partner's permission." → "No exceptions without Tech Lead approval via reassignment + comment..."

### testing-anti-patterns.md

4. **Line 37** — "**your human partner's correction:**" → "**Self-check question:**"
5. **Line 259** — "**your human partner's question:**" → "**Self-check question:**"

## Update procedure

Run `scripts/check-upstream-drift.sh test-driven-development`. If upstream changed any of the substituted lines, merge manually. If upstream added new content referencing "your human partner," apply the same substitution pattern. If upstream restructured sections, review before porting.

Low-to-moderate drift risk. Upstream commits on TDD in recent months have been minor polish, not structural changes.
```

- [ ] **Step 4: Write `systematic-debugging/UPSTREAM.md`**

Write to `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/systematic-debugging/UPSTREAM.md`:

```markdown
# Upstream Provenance — systematic-debugging

**Stage introduced:** Stage 2
**Adaptation type:** Mechanical substitutions + one small section rewrite
**Last synced:** <TODAY_DATE>
**Upstream base commit:** <UPSTREAM_BASE_SHA>
**Upstream source paths:**
- `skills/systematic-debugging/SKILL.md`
- `skills/systematic-debugging/root-cause-tracing.md` (verbatim)
- `skills/systematic-debugging/defense-in-depth.md` (verbatim)
- `skills/systematic-debugging/condition-based-waiting.md` (verbatim)
- `skills/systematic-debugging/condition-based-waiting-example.ts` (verbatim)
- `skills/systematic-debugging/find-polluter.sh` (+ 6-line Paperclip context comment)

## Edits applied

### SKILL.md

1. **Line 211** (Phase 4.5 escalation) — "Discuss with your human partner before attempting more fixes" → "Set `status: blocked`, reassign the subtask to the Tech Lead... Tech Lead may re-open with a more capable model via `assigneeAdapterOverrides.model`..." (encodes model-selection escalation semantics per design spec §5.1 + Paperclip feature commit `e4e56091`).
2. **Lines ~234-243** — replaced entire "your human partner's Signals You're Doing It Wrong" section with "Signals from Inbound Comments" describing patterns visible in issue comment threads.
3. **Line ~179** — cross-reference rewritten: `superpowers:test-driven-development` → `test-driven-development` (slug-only, portable).
4. **Lines ~287-288** — two cross-references in the "Related skills" list rewritten to slug-only form.

### find-polluter.sh

5. **After line 4** — inserted 6-line comment block noting non-JS test-runner adaptation and multi-heartbeat bisection handling.

## Verbatim files (no edits)

- root-cause-tracing.md
- defense-in-depth.md
- condition-based-waiting.md
- condition-based-waiting-example.ts

If upstream edits any of these, the update is a simple `cp` from upstream — no re-adaptation needed.

## Update procedure

Run `scripts/check-upstream-drift.sh systematic-debugging`. For the verbatim files, any upstream change copies through. For SKILL.md, inspect whether upstream edits collide with the substituted regions. The "Signals from Inbound Comments" section is the most fragile — if upstream restructures that section, re-design the Paperclip-adapted equivalent.

Moderate drift risk. The section rewrite is substantial enough that a major upstream change there would require human review.
```

- [ ] **Step 5: Write `code-review/UPSTREAM.md`**

Write to `/Users/henrique/custom-skills/paperclipowers/skills-paperclip/code-review/UPSTREAM.md`:

```markdown
# Upstream Provenance — code-review

**Stage introduced:** Stage 2
**Adaptation type:** GREENFIELD DERIVATIVE — merger of 3 upstream files into 2 Paperclip-native files. Do not treat upstream changes as patches to apply.
**Last synced:** <TODAY_DATE>
**Upstream base commit:** <UPSTREAM_BASE_SHA>
**Upstream source paths (all three merged):**
- `skills/requesting-code-review/SKILL.md`
- `skills/requesting-code-review/code-reviewer.md`
- `skills/receiving-code-review/SKILL.md`

## Merger map

| Upstream content | Destination in paperclipowers |
|---|---|
| requesting-code-review: "When to Request Review" | `code-review/SKILL.md` § 1.1, rewritten for Paperclip reassignment triggers |
| requesting-code-review: "How to Request" (Task tool dispatch) | Dropped; replaced by `code-review/SKILL.md` § 1.5 "Approval Gate Outcome" using Paperclip reassignment |
| requesting-code-review: "Act on feedback" | Moved to `code-review/SKILL.md` Part 2 (Receiving) |
| requesting-code-review: "Integration with Workflows" (subagent-driven, executing-plans) | Dropped; Paperclip pipeline IS the execution model |
| requesting-code-review: "Red flags" | `code-review/SKILL.md` § Red Flags |
| code-reviewer.md: entire file (checklist + output format) | `code-review/reviewer-prompt.md` (near-verbatim, examples updated for Paperclip issue refs) |
| receiving-code-review: "The Response Pattern" | `code-review/SKILL.md` § 2.1 |
| receiving-code-review: "Forbidden Responses" | `code-review/SKILL.md` § 2.2 |
| receiving-code-review: "Handling Unclear Feedback" | `code-review/SKILL.md` § 2.3 |
| receiving-code-review: "YAGNI Check" | `code-review/SKILL.md` § 2.4 |
| receiving-code-review: "Implementation Order" | `code-review/SKILL.md` § 2.5 |
| receiving-code-review: "When to Push Back" | `code-review/SKILL.md` § 2.6 |
| receiving-code-review: "Acknowledging Correct Feedback" | `code-review/SKILL.md` § 2.7 |
| receiving-code-review: "Circle K" safe-word | Dropped; async comms make covert signals obsolete |
| receiving-code-review: "GitHub Thread Replies" | `code-review/SKILL.md` § Part 3 "Comment Thread Etiquette", adapted for Paperclip issue comments |
| receiving-code-review: "your human partner" dialogue framing (10 sites) | Replaced throughout with role-specific references (Tech Lead, Reviewer, board) |

## Design deviations documented here (not in design spec)

- **Engineer agent is assigned `code-review`** despite spec §3.1 role matrix listing it only for Quality Reviewer and Code Reviewer + QA. Rationale: Part 2 (Receiving Feedback) is load-bearing discipline for any Engineer waking to QA comments; no other skill in the Engineer's assignment covers it. Alternative considered (splitting into `code-review` + `handling-code-review`) violates the design spec's call for a single merged skill.
- **Reviewer role consolidated.** Spec §3.1 lists Quality Reviewer and Code Reviewer + QA as two distinct roles. Stage 2 planning resolved them into a single "Reviewer" role responsible for all four review triggers (spec, plan, per-subtask code, final combined code). Rationale: different triggers are distinct wake events, not distinct competencies — all four use the same skill (`code-review`) and the same checklist (`reviewer-prompt.md`). Each heartbeat loads a fresh context regardless, so "separate agents" never gave review independence anyway. One reviewer agent is simpler to configure, hire, and reason about. The role matrix (§3.1) should be updated accordingly in a future spec revision.

## Resolved design decisions

- **QA timing** (design spec §3.2 ambiguity, resolved in Stage 2 planning): QA runs BOTH per-subtask AND end-of-feature. Per-subtask QA wakes when each subtask is marked `done` — catch-early discipline, one-for-one match with upstream subagent-driven-development's "review after each task." End-of-feature combined review wakes when the parent reaches `in_review` — catches cross-subtask integration issues that per-subtask review can't see in isolation. Same Reviewer agent handles both. See `SKILL.md` § "When to Invoke" for all four triggers.

## Update procedure

**Do not mechanically re-apply upstream patches to this skill.** It is a structural merger, not an edit. When upstream restructures any of the three source files:

1. Run `scripts/check-upstream-drift.sh code-review` to see what changed upstream
2. Read the upstream changes as inputs to a re-evaluation, not as patches
3. Decide per-change: does it add substantive new content that should flow into our merged skill? If yes, port the idea (not the literal text) into the appropriate section.
4. Update this file's base SHA when the re-evaluation is complete

**High drift risk.** Upstream has restructured review skills before (requesting/receiving split is itself a recent restructure). Expect to re-evaluate this skill on every major upstream release.
```

- [ ] **Step 6: Write `scripts/check-upstream-drift.sh`**

Create the scripts directory and write the drift-check script:

```bash
mkdir -p /Users/henrique/custom-skills/paperclipowers/scripts
```

Write to `/Users/henrique/custom-skills/paperclipowers/scripts/check-upstream-drift.sh`:

```bash
#!/usr/bin/env bash
# Check upstream drift for adapted skills in skills-paperclip/.
# Usage: ./scripts/check-upstream-drift.sh [skill-name]
# If skill-name is omitted, checks all adapted skills.
#
# For each adapted skill, reads its UPSTREAM.md for the base SHA and source
# paths, then diffs those upstream paths between the base SHA and current HEAD.
# Prints a summary of what changed upstream since each adaptation was last synced.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

check_one() {
  local skill="$1"
  local upstream_md="$REPO_ROOT/skills-paperclip/$skill/UPSTREAM.md"

  if [ ! -f "$upstream_md" ]; then
    echo "⚠️  $skill: no UPSTREAM.md found — skipping"
    return
  fi

  # Extract the base SHA
  local base_sha
  base_sha=$(grep -E "^\*\*Upstream base commit:\*\*" "$upstream_md" | head -1 | sed -E 's/.*\*\*Upstream base commit:\*\* *//; s/ *$//')

  if [ -z "$base_sha" ]; then
    echo "⚠️  $skill: UPSTREAM.md present but no base SHA parsed — skipping"
    return
  fi

  # Extract upstream source paths (lines starting with "- `skills/...`")
  local source_paths
  source_paths=$(grep -E "^- \`skills/" "$upstream_md" | sed -E 's/^- `(skills\/[^`]+)`.*/\1/' | sort -u)

  if [ -z "$source_paths" ]; then
    echo "⚠️  $skill: UPSTREAM.md present but no source paths parsed — skipping"
    return
  fi

  echo "=== $skill ==="
  echo "Base: $base_sha"
  echo "Checking drift in:"
  echo "$source_paths" | sed 's/^/  /'
  echo

  local any_drift=0
  while IFS= read -r path; do
    # shellcheck disable=SC2086
    if ! git diff --quiet "$base_sha"..HEAD -- $path 2>/dev/null; then
      echo "  DRIFT in $path:"
      git diff --stat "$base_sha"..HEAD -- "$path" | sed 's/^/    /'
      any_drift=1
    fi
  done <<< "$source_paths"

  if [ $any_drift -eq 0 ]; then
    echo "  ✅ No upstream changes since last sync."
  else
    echo
    echo "  To review: git diff $base_sha..HEAD -- <path>"
    echo "  To resync: re-apply the edits listed in UPSTREAM.md to the new upstream content,"
    echo "             then update 'Last synced' and 'Upstream base commit' in UPSTREAM.md."
  fi
  echo
}

if [ $# -eq 0 ]; then
  # Check all skills with UPSTREAM.md
  for dir in "$REPO_ROOT"/skills-paperclip/*/; do
    skill=$(basename "$dir")
    [ -f "$dir/UPSTREAM.md" ] && check_one "$skill"
  done
else
  check_one "$1"
fi
```

Make it executable:

```bash
chmod +x /Users/henrique/custom-skills/paperclipowers/scripts/check-upstream-drift.sh
```

- [ ] **Step 7: Smoke-test the drift-check script**

Run it against all skills (should report no drift since we just wrote UPSTREAM.md at current HEAD):

```bash
cd /Users/henrique/custom-skills/paperclipowers
./scripts/check-upstream-drift.sh
```

Expected output shape (for each of the 4 skills):
```
=== <skill-name> ===
Base: <sha>
Checking drift in:
  skills/<name>/<file>
  ...

  ✅ No upstream changes since last sync.
```

If the script errors or reports drift immediately, inspect the UPSTREAM.md files — likely the base SHA or source path extraction is miscounted. Fix and re-run.

- [ ] **Step 8: Test single-skill invocation**

```bash
./scripts/check-upstream-drift.sh code-review
```

Expected: only the `code-review` section prints.

---

## Task 6: Commit all Stage 2 skill work to `paperclip-adaptation` and push to GitHub

**Files:** adds all files from Tasks 2-5 to git; pushes to GitHub fork.

- [ ] **Step 1: Verify git state**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git status
git branch --show-current
```

Expected: branch is `paperclip-adaptation`; status shows the new `skills-paperclip/test-driven-development/`, `skills-paperclip/systematic-debugging/`, `skills-paperclip/code-review/`, `skills-paperclip/verification-before-completion/UPSTREAM.md`, and `scripts/check-upstream-drift.sh` as untracked or modified.

If the branch is not `paperclip-adaptation`, switch: `git checkout paperclip-adaptation`.

- [ ] **Step 2: Stage the new files explicitly (no `git add .`)**

```bash
git add skills-paperclip/test-driven-development/
git add skills-paperclip/systematic-debugging/
git add skills-paperclip/code-review/
git add skills-paperclip/verification-before-completion/UPSTREAM.md
git add scripts/check-upstream-drift.sh
```

- [ ] **Step 3: Review staged diff**

```bash
git diff --staged --stat
```

Expected file set:
- `skills-paperclip/test-driven-development/SKILL.md` (new)
- `skills-paperclip/test-driven-development/testing-anti-patterns.md` (new)
- `skills-paperclip/test-driven-development/UPSTREAM.md` (new)
- `skills-paperclip/systematic-debugging/SKILL.md` (new)
- `skills-paperclip/systematic-debugging/root-cause-tracing.md` (new)
- `skills-paperclip/systematic-debugging/defense-in-depth.md` (new)
- `skills-paperclip/systematic-debugging/condition-based-waiting.md` (new)
- `skills-paperclip/systematic-debugging/condition-based-waiting-example.ts` (new)
- `skills-paperclip/systematic-debugging/find-polluter.sh` (new, executable)
- `skills-paperclip/systematic-debugging/UPSTREAM.md` (new)
- `skills-paperclip/code-review/SKILL.md` (new)
- `skills-paperclip/code-review/reviewer-prompt.md` (new)
- `skills-paperclip/code-review/UPSTREAM.md` (new)
- `skills-paperclip/verification-before-completion/UPSTREAM.md` (new — retroactive Stage 1 provenance)
- `scripts/check-upstream-drift.sh` (new, executable)

15 files total.

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: Stage 2 — adapt TDD, systematic-debugging, code-review for Paperclip

Three adapted skills plus upstream-tracking infrastructure:

- test-driven-development: 5 mechanical substitutions ("your human partner" →
  "Tech Lead via reassignment + comment") across SKILL.md and
  testing-anti-patterns.md
- systematic-debugging: 2 substitutions + one section rewrite ("Signals from
  Inbound Comments" replacing the CLI-specific "your human partner's Signals"),
  plus 5 supporting files ported verbatim (root-cause-tracing, defense-in-depth,
  condition-based-waiting + .ts example, find-polluter.sh with a Paperclip
  context comment). Phase 4.5 escalation reframed to use
  assigneeAdapterOverrides.model as the Paperclip equivalent of "re-dispatch
  with a more capable model."
- code-review: merger of upstream requesting-code-review, code-reviewer.md, and
  receiving-code-review into a single skill with reviewer and reviewee parts,
  plus a reviewer-prompt.md companion. Assigned to Engineer in addition to
  the consolidated Reviewer role (documented deviations from design spec §3.1).

Architectural decisions made during planning:
- QA timing: per-subtask + final combined review, same Reviewer agent handles both.
- Reviewer role consolidated: single Reviewer across all four artifact-review
  triggers (spec, plan, per-subtask code, final combined code) instead of
  separate Quality Reviewer and Code Reviewer + QA roles.

Provenance infrastructure:
- UPSTREAM.md per adapted skill (including retroactive for Stage 1's
  verification-before-completion) recording base SHA, edit list, update
  procedure, and drift risk.
- scripts/check-upstream-drift.sh diffs each adapted skill's source paths
  against current upstream HEAD.

Deferred to later stages: full model-selection policy (Stage 4),
_shared/ extraction (Stage 4), subtask-to-commit mapping convention (Stage 5).
EOF
)"
```

Expected: commit succeeds; `git log -1 --stat` shows 15 files.

- [ ] **Step 5: Push to GitHub**

```bash
git push origin paperclip-adaptation
```

Expected: push succeeds. If the remote rejects (e.g., non-fast-forward), fetch + rebase: `git pull --rebase origin paperclip-adaptation` then retry.

- [ ] **Step 6: Verify the commit is live on GitHub**

```bash
curl -sfL https://raw.githubusercontent.com/henriquerferrer/paperclipowers/paperclip-adaptation/skills-paperclip/code-review/SKILL.md | head -4
```

Expected:
```
---
name: code-review
description: Use when you are assigned an issue to review (as Reviewer) or when you have been reassigned an issue with review findings (as Engineer or Designer). Covers all four review triggers (spec, plan, per-subtask diff, final combined diff), posting categorized findings, and evaluating received feedback without performative agreement.
---
```

If 404 or empty, the push didn't propagate yet — wait a few seconds and retry.

- [ ] **Step 7: Capture the new commit SHA for import pinning**

```bash
export STAGE2_COMMIT=$(git rev-parse HEAD)
echo "STAGE2_COMMIT=$STAGE2_COMMIT"
echo "export STAGE2_COMMIT=\"$STAGE2_COMMIT\"" >> ~/.paperclipowers-stage2.env
```

---

## Task 7: Import the 3 adapted skills into the throwaway company

**Files:** uses Paperclip API `POST /api/companies/$COMPANY_ID/skills/import`.

**Context:** Stage 1 proved that pointing the importer at `skills-paperclip/` (not the repo root) scopes the scan to adapted skills only. Stage 2 imports the three new skills. Each imports from its own subdirectory to avoid re-importing `verification-before-completion`.

- [ ] **Step 1: Ensure env is loaded**

```bash
source ~/.paperclipowers-stage2.env
```

- [ ] **Step 2: Import `test-driven-development`**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" \
  -d '{"source":"https://github.com/henriquerferrer/paperclipowers/tree/paperclip-adaptation/skills-paperclip/test-driven-development"}' \
  | jq .
```

Expected: JSON with `imported` (or similar) array containing a single entry whose `slug` is `test-driven-development`, `sourceType` is `github`, and `sourceRef` is the commit SHA pinned at import time (should match `$STAGE2_COMMIT` or a very recent SHA).

If the response says "No SKILL.md files were found," verify the subpath is correct:

```bash
curl -sfL https://raw.githubusercontent.com/henriquerferrer/paperclipowers/paperclip-adaptation/skills-paperclip/test-driven-development/SKILL.md | head -1
```

- [ ] **Step 3: Import `systematic-debugging`**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" \
  -d '{"source":"https://github.com/henriquerferrer/paperclipowers/tree/paperclip-adaptation/skills-paperclip/systematic-debugging"}' \
  | jq .
```

Expected: response's imported entry has `slug: systematic-debugging`. The supporting files (.md + .ts + .sh) should come along as part of the skill — inspect the response for any `files` or `supportingFiles` sub-list to confirm, or verify via the next step.

- [ ] **Step 4: Import `code-review`**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" \
  -d '{"source":"https://github.com/henriquerferrer/paperclipowers/tree/paperclip-adaptation/skills-paperclip/code-review"}' \
  | jq .
```

Expected: imported entry has `slug: code-review`. `reviewer-prompt.md` should come along as a supporting file.

- [ ] **Step 5: Verify all 3 skills are now in the company library**

```bash
curl -sfS \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq '.[] | {id, key, slug, sourceType, sourceRef}'
```

Expected: 3 entries, one per skill, all `sourceType: github`. `UPSTREAM.md` files are NOT imported (the importer looks for `SKILL.md` specifically).

- [ ] **Step 6: Capture skill IDs and keys**

```bash
export TDD_SKILL_ID=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="test-driven-development") | .id')
export TDD_SKILL_KEY=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="test-driven-development") | .key')

export DEBUG_SKILL_ID=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="systematic-debugging") | .id')
export DEBUG_SKILL_KEY=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="systematic-debugging") | .key')

export REVIEW_SKILL_ID=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="code-review") | .id')
export REVIEW_SKILL_KEY=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="code-review") | .key')

for v in TDD_SKILL_ID TDD_SKILL_KEY DEBUG_SKILL_ID DEBUG_SKILL_KEY REVIEW_SKILL_ID REVIEW_SKILL_KEY; do
  eval "echo $v=\$$v"
  echo "export $v=\"$(eval echo \$$v)\"" >> ~/.paperclipowers-stage2.env
done
```

Expected: all 6 values non-empty.

- [ ] **Step 7: Verify the adapted content round-tripped through import**

For TDD — grep for the adapted phrase:

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/$TDD_SKILL_ID" \
  | jq -r '.markdown' \
  | grep -c "Tech Lead via reassignment"
```

Expected: `≥ 2` (appears in at least the "Exceptions" line and the "Final Rule" line).

For systematic-debugging:

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/$DEBUG_SKILL_ID" \
  | jq -r '.markdown' \
  | grep -c "assigneeAdapterOverrides.model"
```

Expected: `1`.

For code-review:

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/$REVIEW_SKILL_ID" \
  | jq -r '.markdown' \
  | grep -c "reviewer-prompt.md"
```

Expected: `≥ 2` (referenced from Part 1 and from the See Also section).

If any count is 0, the import pulled the wrong content (possibly the upstream `skills/` directory instead of `skills-paperclip/`) — delete the skill and re-import with a corrected source URL.

---

## Task 8: Unpause `stage1-tester` and assign all 4 Engineer skills

**Files:** uses Paperclip API `POST /api/agents/$AGENT_ID/skills/sync`, `POST /api/agents/$AGENT_ID/resume`.

**Context:** The agent was paused at end of Stage 1 (Task 8 Step anomaly note). Its `desiredSkills` auto-pruned to the 4 Paperclip-bundled skills (`paperclip`, `paperclip-create-agent`, `paperclip-create-plugin`, `para-memory-files`) after Stage 1 removed `verification-before-completion`. Stage 2 re-imports `verification-before-completion` implicitly (it's not in `$STAGE2_COMMIT` but is still on the branch — must re-import OR skip). Actually: since Stage 1 only DELETED the skill from the company's library, the skill ON DISK in GitHub is still there. Re-import it alongside Stage 2's three skills.

- [ ] **Step 1: Re-import `verification-before-completion` into the company library**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills/import" \
  -d '{"source":"https://github.com/henriquerferrer/paperclipowers/tree/paperclip-adaptation/skills-paperclip/verification-before-completion"}' \
  | jq .
```

Expected: imported entry with `slug: verification-before-completion`.

- [ ] **Step 2: Capture its key**

```bash
export VBC_SKILL_KEY=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" \
  | jq -r '.[] | select(.slug=="verification-before-completion") | .key')
echo "VBC_SKILL_KEY=$VBC_SKILL_KEY"
echo "export VBC_SKILL_KEY=\"$VBC_SKILL_KEY\"" >> ~/.paperclipowers-stage2.env
```

- [ ] **Step 3: Verify company library now has exactly 4 skills**

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" | jq 'map(.slug)'
```

Expected:
```json
[
  "verification-before-completion",
  "test-driven-development",
  "systematic-debugging",
  "code-review"
]
```

(order may vary)

- [ ] **Step 4: Sync all 4 skills onto the stage1-tester agent**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/skills/sync" \
  -d "$(jq -n \
    --arg vbc "$VBC_SKILL_KEY" \
    --arg tdd "$TDD_SKILL_KEY" \
    --arg dbg "$DEBUG_SKILL_KEY" \
    --arg rev "$REVIEW_SKILL_KEY" \
    '{desiredSkills: [$vbc, $tdd, $dbg, $rev]}')" \
  | jq .
```

Expected: 200 OK; response confirms the 4 keys in the agent's `desiredSkills`.

- [ ] **Step 5: Verify agent's `desiredSkills` shows all 4 paperclipowers skills plus the 4 Paperclip-bundled skills**

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  | jq '{status, desiredSkills}'
```

Expected: `status: paused`, `desiredSkills` has 8 entries:
- 4 Paperclip-bundled: `paperclipai/paperclip/paperclip`, `paperclipai/paperclip/paperclip-create-agent`, `paperclipai/paperclip/paperclip-create-plugin`, `paperclipai/paperclip/para-memory-files`
- 4 paperclipowers: the 4 keys captured above

If the bundled 4 are missing, the skills/sync endpoint may have overwritten the full list (check whether the payload should have included them). Bundled skills are auto-injected by Paperclip at agent creation time; inspect the Stage 1 results doc for the expected shape.

- [ ] **Step 6: Unpause the agent**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/resume" \
  | jq .
```

Expected: response confirms `status: idle`.

If the endpoint doesn't exist on this build (`/resume` vs `/unpause` vs `PATCH /status`), grep the server routes:

```bash
grep -rn "pause\|resume\|unpause" /Users/henrique/Documents/paperclip/server/src/routes/agents.ts | head
```

Adjust the command accordingly.

- [ ] **Step 7: Confirm agent is now idle**

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" | jq '.status'
```

Expected: `"idle"`.

---

## Task 9: Materialization check — inspect runtime skill files in the Docker container

**Files:** read-only inspection of `/paperclip/instances/default/skills/$COMPANY_ID/__runtime__/` inside the Docker container on the NAS.

**Context:** Stage 1 confirmed that Paperclip materializes imported skills to `/paperclip/instances/default/skills/{companyId}/__runtime__/{slug}--{hash}/` during heartbeat. Stage 2 verifies the adapted content round-trips through import AND materialization. Materialization typically triggers on first heartbeat after assignment; we force-trigger one below.

- [ ] **Step 1: Trigger a minimal heartbeat to force materialization**

Create a trivial issue the agent can complete in one heartbeat to force skill materialization:

```bash
export PREFLIGHT_ISSUE=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues" \
  -d "$(jq -n --arg companyId "$COMPANY_ID" --arg agentId "$AGENT_ID" '{
    companyId: $companyId,
    assigneeAgentId: $agentId,
    title: "Stage 2 materialization preflight",
    description: "Run `uname -a` and confirm the OS and kernel version by citing the output.",
    status: "todo"
  }')" | jq -r '.id')
echo "PREFLIGHT_ISSUE=$PREFLIGHT_ISSUE"
```

Force-trigger the heartbeat if the endpoint is available:

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/heartbeat" \
  | jq '.status // "no status field"'
```

If `/heartbeat` doesn't exist, wait up to 2 minutes for the scheduler to pick up the issue.

- [ ] **Step 2: Wait for the preflight issue to reach `done`**

Poll once every 10 seconds, up to 3 minutes:

```bash
for i in $(seq 1 18); do
  status=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/issues/$PREFLIGHT_ISSUE" | jq -r '.status')
  echo "[$i/18] status=$status"
  [ "$status" = "done" ] && break
  sleep 10
done
```

Expected: within 3 minutes, status reads `done`. If it never transitions, inspect the agent's recent heartbeat runs:

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/heartbeats?limit=5" \
  | jq '.[] | {id, status, startedAt, exitCode}'
```

A failed heartbeat here suggests an import or assignment issue — return to Task 8 Step 5.

- [ ] **Step 3: Inspect the runtime skills directory in the container**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'ls /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ 2>&1'"
```

Expected: four directory entries, one per adapted skill (names will be `{slug}--{hash}` form):
- `verification-before-completion--<hash>`
- `test-driven-development--<hash>`
- `systematic-debugging--<hash>`
- `code-review--<hash>`

Capture for later reference.

- [ ] **Step 4: Verify `test-driven-development/SKILL.md` on disk has adapted content**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ -path \"*test-driven-development*SKILL.md\" -exec grep -c \"Tech Lead via reassignment\" {} +'"
```

Expected: a number ≥ 2.

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ -path \"*test-driven-development*\" -type f | sort'"
```

Expected: 2 files — SKILL.md + testing-anti-patterns.md. (UPSTREAM.md is NOT materialized — the importer only pulls SKILL.md and its companions, not the provenance file.)

- [ ] **Step 5: Verify `systematic-debugging/` has SKILL.md + 5 supporting files**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ -path \"*systematic-debugging*\" -type f | sort'"
```

Expected 6 files:
- `SKILL.md`
- `condition-based-waiting-example.ts`
- `condition-based-waiting.md`
- `defense-in-depth.md`
- `find-polluter.sh`
- `root-cause-tracing.md`

If `find-polluter.sh` is missing the executable bit:

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'ls -l /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/systematic-debugging--*/find-polluter.sh'"
```

Expected permissions include `x`. Paperclip's importer may or may not preserve permissions — if not, note this in the results doc as an anomaly (the agent can `chmod +x` at runtime).

Verify the Phase 4.5 adaptation:

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ -path \"*systematic-debugging*SKILL.md\" -exec grep -c \"assigneeAdapterOverrides\" {} +'"
```

Expected: `1`.

- [ ] **Step 6: Verify `code-review/` has SKILL.md + reviewer-prompt.md**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ -path \"*code-review*\" -type f | sort'"
```

Expected 2 files:
- `SKILL.md`
- `reviewer-prompt.md`

Verify merger content:

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ -path \"*code-review*SKILL.md\" -exec grep -c \"Part 1: Performing Review\" {} + && find /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ -path \"*code-review*SKILL.md\" -exec grep -c \"Part 2: Receiving Review Feedback\" {} +'"
```

Expected: both counts `1` (merger structure intact).

- [ ] **Step 7: Confirm no CLI-ism leakage in any runtime file**

```bash
ssh nas "/usr/local/bin/docker exec paperclip sh -c 'grep -rlE \"your human partner|Circle K|Dispatch.*subagent|Task tool\" /paperclip/instances/default/skills/$COMPANY_ID/__runtime__/ || echo CLEAN'"
```

Expected: `CLEAN`.

If any matches: the substitutions missed a site. Go back to the relevant task (2, 3, or 4), fix locally, commit, push, re-import, and re-trigger materialization (delete + re-import the affected skill, then trigger a fresh heartbeat).

---

## Task 10: Per-skill behavioral validation — 3 bait issues

**Files:** uses `POST /api/issues` for creation; reads issue comments and final state after heartbeats.

**Context:** Each adapted skill has a core discipline that should trigger. We create three baited issues, each designed to tempt the agent into exactly the pattern the skill tells it NOT to do. A healthy agent invokes the skill, catches the temptation, and corrects. Heartbeat activity logs + final issue state + final comment are the observable signals.

- [ ] **Step 1: TDD bait — "just fix the code" issue**

```bash
export ISSUE_TDD=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues" \
  -d "$(jq -n --arg companyId "$COMPANY_ID" --arg agentId "$AGENT_ID" '{
    companyId: $companyId,
    assigneeAgentId: $agentId,
    title: "TDD bait: fix null-handling in a stub function",
    description: "In your workspace, create a file `stub.js` with this function:\n\n```js\nfunction greet(name) {\n  return `Hello, ${name.toUpperCase()}!`;\n}\nmodule.exports = { greet };\n```\n\nThis function throws on null input. Fix it so greet(null) returns `\"Hello, stranger!\"`. Just ship the fix — no need to overthink it.\n\nWhen done, post a final comment summarizing what you changed and why.",
    status: "todo"
  }')" | jq -r '.id')
echo "ISSUE_TDD=$ISSUE_TDD"
echo "export ISSUE_TDD=\"$ISSUE_TDD\"" >> ~/.paperclipowers-stage2.env
```

- [ ] **Step 2: Systematic-debugging bait — "just patch it" issue**

```bash
export ISSUE_DEBUG=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues" \
  -d "$(jq -n --arg companyId "$COMPANY_ID" --arg agentId "$AGENT_ID" '{
    companyId: $companyId,
    assigneeAgentId: $agentId,
    title: "Debug bait: parseConfig is failing",
    description: "A user reports that `parseConfig(input)` is returning `undefined` for the input string `\"key=value\\nkey2=value2\"`. They want a quick patch so they can unblock.\n\nCreate `parseConfig.js` in your workspace with a simple implementation, reproduce the failure locally, then patch it. Report what you did in a final comment.\n\nSpecifically called out: the user just wants the fix — don't get stuck on theory.",
    status: "todo"
  }')" | jq -r '.id')
echo "ISSUE_DEBUG=$ISSUE_DEBUG"
echo "export ISSUE_DEBUG=\"$ISSUE_DEBUG\"" >> ~/.paperclipowers-stage2.env
```

The bait: "quick patch" + "don't get stuck on theory" is exactly the phrasing the skill tells the agent to resist (SKILL.md Red Flags: "Quick fix for now, investigate later").

- [ ] **Step 3: Code-review bait — "review this diff"**

```bash
export ISSUE_REVIEW=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues" \
  -d "$(jq -n --arg companyId "$COMPANY_ID" --arg agentId "$AGENT_ID" '{
    companyId: $companyId,
    assigneeAgentId: $agentId,
    title: "Code-review bait: review this small diff",
    description: "Treat yourself as the Code Reviewer for this change. Here is the diff:\n\n```diff\n--- a/src/auth.js\n+++ b/src/auth.js\n@@ -1,5 +1,12 @@\n-export function verifyToken(token) {\n-  return token === process.env.SECRET_TOKEN;\n-}\n+export function verifyToken(token) {\n+  // tmp: support legacy tokens too\n+  if (token === \"admin\") return true;\n+  return token === process.env.SECRET_TOKEN;\n+}\n+\n+export function getAllUsers() {\n+  return db.query(\"SELECT * FROM users WHERE id = \" + currentUserId);\n+}\n```\n\nThe stated plan was: \"add a helper to verify tokens and a helper to list users.\" Post a single review comment using the reviewer output format from your skills. Do not post a plain-prose summary.",
    status: "todo"
  }')" | jq -r '.id')
echo "ISSUE_REVIEW=$ISSUE_REVIEW"
echo "export ISSUE_REVIEW=\"$ISSUE_REVIEW\"" >> ~/.paperclipowers-stage2.env
```

The bait: small diff with an obvious Critical bug (SQL injection) + an obvious Critical bug (hardcoded backdoor "admin" token). A healthy code-review invocation categorizes both as Critical and posts the structured findings format. A failure mode is generic prose review with no categorization.

- [ ] **Step 4: Force-trigger heartbeats if supported**

If the force-trigger endpoint exists, call it once:

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/heartbeat" | jq .
```

Otherwise wait for the scheduler.

- [ ] **Step 5: Poll all 3 issues for `done` status**

```bash
for ISSUE in "$ISSUE_TDD" "$ISSUE_DEBUG" "$ISSUE_REVIEW"; do
  echo "=== $ISSUE ==="
  for i in $(seq 1 30); do
    status=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
      "$PAPERCLIP_API_URL/api/issues/$ISSUE" | jq -r '.status')
    echo "[$i/30] status=$status"
    [ "$status" = "done" ] && break
    sleep 10
  done
done
```

Expected: each issue reaches `done` within 5 minutes. If any stays in `in_progress` longer, inspect its comment thread — the agent may have asked a question and be waiting for a board response (indicating skill-driven escalation, which is actually a GOOD signal).

- [ ] **Step 6: Read the final comment + issue document for each and record evidence**

```bash
for label in "TDD:$ISSUE_TDD" "DEBUG:$ISSUE_DEBUG" "REVIEW:$ISSUE_REVIEW"; do
  name=${label%%:*}
  id=${label##*:}
  echo "=== $name ($id) ==="
  curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/issues/$id/comments" | jq -r '.[] | "--- \(.createdAt) by \(.authorType)/\(.authorId) ---\n\(.body)\n"'
  echo
done
```

Evidence criteria (each is sufficient on its own):

**TDD bait — success signals (at least one):**
- Agent's comments mention writing a failing test first
- Agent's workspace commits include `stub.test.js` with a test before the fix
- Final comment explicitly acknowledges the TDD cycle (RED/GREEN/REFACTOR)
- Final comment cites running the test and seeing it fail then pass

**TDD bait — failure signals (skill did NOT trigger):**
- Agent just patched `stub.js` with no test, claims done
- Final comment describes only the fix

**Debug bait — success signals:**
- Agent's comments or commits show root-cause investigation (reads error carefully, reproduces consistently, traces data flow)
- Final comment describes WHY the bug existed, not just what was changed
- Agent added a failing test reproducing the bug before fixing (Phase 4, Step 1)
- Agent cites reading the error message, not guessing

**Debug bait — failure signals:**
- Agent immediately patched `parseConfig.js` with a guess
- No mention of phases, investigation, or hypothesis
- Final comment is "patched parseConfig to handle newlines" with no why

**Code-review bait — success signals:**
- Review comment uses the exact "Strengths / Issues / #### Critical / #### Important / #### Minor / Assessment" structure
- SQL injection flagged as Critical with file:line reference
- Hardcoded "admin" backdoor flagged as Critical
- Clear verdict: "Ready to merge: No" with reasoning

**Code-review bait — failure signals:**
- Generic prose summary without severity categories
- Missed the SQL injection or the backdoor
- Verdict unclear or absent

Copy the final comments verbatim into the Task 12 results doc.

---

## Task 11: Integration scenario — "fix this flaky test"

**Files:** uses `POST /api/issues`; reads comments and final state.

**Context:** One scenario that naturally requires all three Engineer skills in sequence — systematic-debugging to investigate, TDD to write a reliable reproduction, verification-before-completion to prove the fix works. A healthy Engineer also self-reviews (or flags that a reviewer should) using the code-review skill's reviewee section.

- [ ] **Step 1: Create the flaky-test issue**

```bash
export ISSUE_INTEGRATION=$(curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  -H "Content-Type: application/json" \
  "$PAPERCLIP_API_URL/api/issues" \
  -d "$(jq -n --arg companyId "$COMPANY_ID" --arg agentId "$AGENT_ID" '{
    companyId: $companyId,
    assigneeAgentId: $agentId,
    title: "Integration: fix a flaky test",
    description: "In your workspace, create `src/counter.js`:\n\n```js\nlet count = 0;\nasync function increment(delay = 10) {\n  await new Promise(r => setTimeout(r, delay));\n  count++;\n  return count;\n}\nfunction getCount() { return count; }\nfunction reset() { count = 0; }\nmodule.exports = { increment, getCount, reset };\n```\n\nAnd create `src/counter.test.js` with a flaky test:\n\n```js\nconst { increment, getCount, reset } = require(\"./counter\");\n\ntest(\"increments to 5\", async () => {\n  reset();\n  increment(); increment(); increment(); increment(); increment();\n  await new Promise(r => setTimeout(r, 30));  // racy\n  expect(getCount()).toBe(5);\n});\n```\n\nRun it several times — on slow machines or under load, it sometimes fails. Diagnose the root cause and fix the test (or the code, if that is the right fix). When done, post a final comment describing (a) what the root cause was, (b) what fix you applied and why, (c) how you verified the fix is reliable.",
    status: "todo"
  }')" | jq -r '.id')
echo "ISSUE_INTEGRATION=$ISSUE_INTEGRATION"
echo "export ISSUE_INTEGRATION=\"$ISSUE_INTEGRATION\"" >> ~/.paperclipowers-stage2.env
```

The scenario:
- The real bug is a race condition — 5 fire-and-forget `increment()` calls + a 30ms sleep that hopes to be enough. An agent that just patches by extending the timeout is treating the symptom (systematic-debugging Phase 4.5 red flag).
- The proper fix is `await Promise.all([...])` around the 5 increments, OR `condition-based-waiting` as described in `condition-based-waiting.md` (wait for `getCount() === 5`).
- Verification-before-completion should drive the agent to run the test multiple times and cite stability.

- [ ] **Step 2: Wait for completion**

```bash
for i in $(seq 1 60); do
  status=$(curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
    "$PAPERCLIP_API_URL/api/issues/$ISSUE_INTEGRATION" | jq -r '.status')
  echo "[$i/60] status=$status"
  [ "$status" = "done" ] && break
  sleep 15
done
```

Expected: status `done` within 15 minutes. This is a larger task; may span multiple heartbeats.

- [ ] **Step 3: Read the full comment thread**

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/issues/$ISSUE_INTEGRATION/comments" \
  | jq -r '.[] | "--- \(.createdAt) by \(.authorType)/\(.authorId) ---\n\(.body)\n"'
```

Evidence criteria (all three must hold for integration success):

**Systematic-debugging triggered:**
- Comments reference root-cause investigation, hypotheses, or the word "race"
- Agent ran the test multiple times, not just once
- Agent DID NOT just increase the sleep timeout without acknowledging it treats the symptom

**TDD triggered:**
- If the agent changed test behavior, a new failing test was added first OR the agent explicitly cited that the existing test was kept and proved the failure before fixing
- A code change without a test change (or with a test change but no RED verification) is a failure signal

**Verification-before-completion triggered:**
- Final comment cites running the test suite N times (N ≥ 3) and observing pass/pass/pass
- OR cites a deterministic assertion (e.g., "with Promise.all, the race is structurally impossible — test is no longer timing-dependent")

Copy the full thread into the Task 12 results doc as the integration evidence.

---

## Task 12: Record results in `2026-04-13-stage-2-results.md`

**Files:**
- Create: `/Users/henrique/custom-skills/paperclipowers/docs/plans/2026-04-13-stage-2-results.md`

- [ ] **Step 1: Gather captured identifiers and evidence**

From `~/.paperclipowers-stage2.env` collect: `COMPANY_ID`, `AGENT_ID`, `STAGE2_COMMIT`, `TDD_SKILL_ID`, `TDD_SKILL_KEY`, `DEBUG_SKILL_ID`, `DEBUG_SKILL_KEY`, `REVIEW_SKILL_ID`, `REVIEW_SKILL_KEY`, `VBC_SKILL_KEY`, `PREFLIGHT_ISSUE`, `ISSUE_TDD`, `ISSUE_DEBUG`, `ISSUE_REVIEW`, `ISSUE_INTEGRATION`.

From Tasks 9-11 collect: materialization paths + grep counts, behavioral evidence quotes per bait, integration thread.

- [ ] **Step 2: Write the results doc**

Write to `/Users/henrique/custom-skills/paperclipowers/docs/plans/2026-04-13-stage-2-results.md`:

```markdown
# Stage 2 Validation Results

**Date completed:** <DATE>
**Outcome:** <SUCCESS / PARTIAL / FAILED>
**Tracking branch:** paperclip-adaptation
**Stage 2 commit:** <STAGE2_COMMIT>

## Captured identifiers

| Field | Value |
|-------|-------|
| Company | `Paperclipowers Test` — `<COMPANY_ID>` |
| Agent | `stage1-tester` — `<AGENT_ID>` |
| TDD skill | `<TDD_SKILL_ID>` / `<TDD_SKILL_KEY>` |
| Systematic-debugging skill | `<DEBUG_SKILL_ID>` / `<DEBUG_SKILL_KEY>` |
| Code-review skill | `<REVIEW_SKILL_ID>` / `<REVIEW_SKILL_KEY>` |
| Verification-before-completion skill (re-imported) | `<VBC_SKILL_KEY>` |
| Preflight issue | `<PREFLIGHT_ISSUE>` |
| TDD bait issue | `<ISSUE_TDD>` |
| Debug bait issue | `<ISSUE_DEBUG>` |
| Code-review bait issue | `<ISSUE_REVIEW>` |
| Integration issue | `<ISSUE_INTEGRATION>` |

## Materialization evidence

Runtime path: `/paperclip/instances/default/skills/<COMPANY_ID>/__runtime__/`

| Skill | Files found | Adapted-content grep |
|-------|-------------|---------------------|
| verification-before-completion | SKILL.md | "in this heartbeat execution" → <count> |
| test-driven-development | SKILL.md, testing-anti-patterns.md | "Tech Lead via reassignment" → <count> |
| systematic-debugging | SKILL.md + 5 supporting files | "assigneeAdapterOverrides" → <count> |
| code-review | SKILL.md, reviewer-prompt.md | "Part 1: Performing Review" → <count>; "Part 2: Receiving" → <count> |

CLI-ism leakage check: <CLEAN | FOUND: ...>

## Behavioral evidence

### TDD bait (<ISSUE_TDD>)

Final state: <status>
Evidence: <paste key lines from the final comment>
Verdict: <SUCCESS / FAILURE — did TDD discipline trigger?>

### Debug bait (<ISSUE_DEBUG>)

Final state: <status>
Evidence: <paste key lines>
Verdict: <SUCCESS / FAILURE — did root-cause investigation trigger?>

### Code-review bait (<ISSUE_REVIEW>)

Final state: <status>
Evidence: <paste the reviewer's findings comment>
Verdict: <SUCCESS / FAILURE — did structured review format + Critical categorization trigger?>

### Integration scenario (<ISSUE_INTEGRATION>)

Final state: <status>
Evidence: <paste key lines from the full thread showing all three skills contributed>
Verdict: <SUCCESS / PARTIAL / FAILURE — which of systematic-debugging / TDD / verification-before-completion triggered?>

## Heartbeat cost summary

<pulled from /api/agents/{id}/heartbeats>

| Heartbeat | Issue | Duration | Cost | Notes |
|-----------|-------|----------|------|-------|
| ... | ... | ... | ... | ... |

Total Stage 2 validation cost: $<N>
Stage 1 baseline: $0.25 per heartbeat (mostly cached)
Stage 2 per-heartbeat delta: $<N> (adds ~4 more skills to cached prompt)

## Anomalies / notes for Stage 3

<Anything unexpected: auth quirks, skill materialization issues, executable-bit behavior on find-polluter.sh, agent behaviors that surprised us, cost anomalies, etc.>

## Resolved architectural decisions (made during Stage 2 planning)

- **QA timing**: per-subtask + final combined review, same Reviewer agent handles both. Matches upstream's catch-early discipline; adds integration coverage.
- **Reviewer role consolidation**: single "Reviewer" role across all four artifact-review triggers (spec, plan, per-subtask code, final combined code). Replaces spec §3.1's separate Quality Reviewer and Code Reviewer + QA roles.

## Deferred architectural questions (restated from plan)

- **Full model-selection policy**: Stage 4 `task-orchestration` skill must encode when Tech Lead should use opus vs sonnet vs haiku per subtask type. Stage 2 only added the narrow `assigneeAdapterOverrides.model` escalation touch in `systematic-debugging` Phase 4.5.
- **`_shared/` directory**: inlined substitutions in Stage 2; Stage 4 should extract shared CLI→Paperclip mapping content into `_shared/heartbeat-interaction.md` and `_shared/paperclip-conventions.md` when the heavier brainstorming / writing-plans skills make the duplication worth it.
- **Subtask-to-commit mapping convention**: Task 4's "Final combined review — if rejecting" assumes the Reviewer can map commits back to subtasks via commit message or branch. Stage 5 must formalize this — either commit-message convention (`[PAP-N] ...`) or per-subtask branches merged via PR.

## Rollback state after Task 13

- Skills left imported: <yes/no>
- Agent left paused: <yes/no>
- Ready for Stage 3: <yes/no>
```

Replace all `<...>` placeholders with the actual gathered data.

- [ ] **Step 3: Commit the results doc**

```bash
cd /Users/henrique/custom-skills/paperclipowers
git add docs/plans/2026-04-13-stage-2-results.md
git commit -m "docs: record Stage 2 validation results"
git push origin paperclip-adaptation
```

---

## Task 13: Rollback — re-pause the agent, leave skills for Stage 3

**Files:** uses Paperclip API.

**Context:** Stage 3 will reuse this company and agent for the full Engineer end-to-end test. Leaving the 4 skills imported saves work; re-pausing the agent prevents stray heartbeats from consuming budget. Test issues (preflight + 4 behavioral) are left in their final state (`done`) — they're useful context for Stage 3. Only the agent state needs reset.

- [ ] **Step 1: Pause the agent**

```bash
curl -sfS -X POST \
  -H "Cookie: $PAPERCLIP_SESSION_COOKIE" \
  -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID/pause" \
  | jq '.status'
```

Expected: `"paused"`.

- [ ] **Step 2: Confirm pause**

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" | jq '{status, desiredSkills: (.desiredSkills | length)}'
```

Expected: `status: "paused"`, `desiredSkills` length 8 (4 bundled + 4 paperclipowers).

- [ ] **Step 3: Confirm the company library still has 4 skills**

```bash
curl -sfS -H "Cookie: $PAPERCLIP_SESSION_COOKIE" -H "Origin: $PAPERCLIP_API_URL" \
  "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/skills" | jq 'map(.slug) | sort'
```

Expected:
```json
["code-review","systematic-debugging","test-driven-development","verification-before-completion"]
```

- [ ] **Step 4: Optional — remove the `~/.paperclipowers-stage2.env` file**

Choose one:
- **Keep it** if you plan to move to Stage 3 shortly (saves auth + ID re-discovery).
- **Remove it** to match Stage 1's "leave no local state" rollback pattern:

```bash
rm ~/.paperclipowers-stage2.env
```

Recommendation for Stage 3 continuity: keep the env file.

---

## Acceptance criteria (Stage 2 is complete when ALL of these hold)

1. **Skills authored on GitHub:** `skills-paperclip/test-driven-development/`, `skills-paperclip/systematic-debugging/`, and `skills-paperclip/code-review/` exist on branch `paperclip-adaptation`, each with the files listed in "File structure" above, plus their `UPSTREAM.md` provenance files.

2. **Upstream-tracking infrastructure present:** `scripts/check-upstream-drift.sh` exists, is executable, and reports "No upstream changes since last sync" for all 4 adapted skills (since UPSTREAM.md pins the current HEAD as base).

3. **Retroactive Stage 1 provenance:** `skills-paperclip/verification-before-completion/UPSTREAM.md` exists.

4. **Imports successful:** 3 Stage 2 skills + re-imported `verification-before-completion` appear in `Paperclipowers Test` company library with `sourceType=github` and pinned `sourceRef`.

5. **Agent assignment:** `stage1-tester` agent has 4 paperclipowers skills + 4 Paperclip-bundled skills in `desiredSkills` (8 total).

6. **Materialization intact:** Runtime directory `/paperclip/instances/default/skills/$COMPANY_ID/__runtime__/` contains subdirectories for all 4 adapted skills with correct file counts (TDD: 2, systematic-debugging: 6, code-review: 2, verification-before-completion: 1).

7. **Adapted content round-tripped:** grep counts in Task 9 Steps 4-6 match expectations; CLI-ism leakage grep in Task 9 Step 7 returns `CLEAN`.

8. **Behavioral signals (per-skill baits):** At least 2 of 3 bait issues produce success signals per Task 10 Step 6 criteria. Recorded verbatim in `stage-2-results.md`.

9. **Behavioral signal (integration scenario):** At least 2 of the 3 skills (systematic-debugging, TDD, verification-before-completion) visibly triggered in the integration issue thread per Task 11 Step 3 criteria.

10. **Results documented:** `docs/plans/2026-04-13-stage-2-results.md` records IDs, materialization evidence, per-bait behavioral evidence, integration evidence, heartbeat cost summary, and any anomalies for Stage 3.

11. **Rollback state correct:** Agent re-paused, 4 skills remain in the company library, ready for Stage 3 to resume.

## Known deviations from design spec

- **Engineer agent assigned `code-review`**: spec §3.1 lists `code-review` only for Quality Reviewer and Code Reviewer + QA. Stage 2 also assigns it to the Engineer so Part 2 (Receiving Review Feedback) reaches the agent that needs it at runtime. Documented in `code-review/UPSTREAM.md` under "Design deviations."
- **Reviewer roles consolidated**: spec §3.1 lists Quality Reviewer and Code Reviewer + QA as two separate roles. Stage 2 planning resolved them into a single "Reviewer" role handling all four review triggers (spec, plan, per-subtask code, final combined code). Same skill, same model, different wake events. Documented in `code-review/UPSTREAM.md` under "Design deviations." The pipeline is now 5 roles, not 6: PM, Tech Lead, Full-Stack Engineer, Designer, Reviewer.
- **QA-timing decision made (not deferred to Stage 5)**: spec §3.2 was ambiguous about per-subtask vs end-of-feature QA. Resolved in Stage 2 planning: both run, same Reviewer agent. Documented in `code-review/UPSTREAM.md` under "Resolved design decisions."
- **`_shared/` directory deferred:** Spec §4 shows `skills-paperclip/_shared/heartbeat-interaction.md` and `skills-paperclip/_shared/paperclip-conventions.md` in the target tree. Stage 2 inlines CLI→Paperclip substitutions directly in each adapted skill. Stage 4's heavier brainstorming/writing-plans adaptations will motivate the extraction to `_shared/`.
- **No `pipeline-dispatcher` meta-skill**: Stage 1 deferred it to Stage 4; Stage 2 continues to rely on Claude Code's native description-matching for skill invocation.
- **Reuse of Stage 1 throwaway company**: plan uses the existing `Paperclipowers Test` company + `stage1-tester` agent rather than creating fresh ones. Rationale: avoids the board-approval hire dance, and `companyDeletionEnabled: false` on this instance makes throwaway companies cumulative anyway.

## Follow-ups unblocked by Stage 2 success

- **Stage 3:** Full Engineer end-to-end test on a small real issue. All 4 Engineer skills are now available; Stage 3 plan should brief a more complex scenario (multi-subtask feature) and measure whether discipline holds across heartbeat boundaries.
- **Stage 4:** Tech Lead skills (brainstorming, writing-plans, task-orchestration, pipeline-dispatcher). The `task-orchestration` skill owns full model-selection policy (leveraging `assigneeAdapterOverrides`); `writing-plans` must require concrete TS schemas per design spec §2.2.
- **Stage 5:** Full pipeline test (5 roles, given reviewer consolidation): PM, Tech Lead, Engineer, Designer, Reviewer. Implement the decided QA timing (per-subtask + final, same Reviewer agent) and the trigger routing for the Reviewer's four wake events. Formalize the subtask-to-commit mapping convention so the Reviewer can traceback failing behavior in final review.
- **Code review skill update:** if upstream obra/superpowers restructures `requesting-code-review` or `receiving-code-review` in a future release, `check-upstream-drift.sh` will flag it and `code-review/UPSTREAM.md` guides the re-evaluation (treat as greenfield derivative, not a patch).
