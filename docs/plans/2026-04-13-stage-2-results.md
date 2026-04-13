# Stage 2 Validation Results

**Date completed:** 2026-04-13
**Outcome:** SUCCESS — all 4 Engineer-layer skills imported, materialized with adapted content intact, and exercised behaviorally with clean success signals per scenario.
**Tracking branch:** `paperclip-adaptation`
**Stage 2 commit:** `78598d564ba9f569c54f72df7b5deb58f7a15dd2` (includes the Stage 1 CLI-ism leak patch discovered during runtime validation)
**Prior commits in Stage 2:** `1a4d7c5` (plan), `b631935` (initial skills)

## Captured identifiers

| Field | Value |
|-------|-------|
| Company | `Paperclipowers Test` — `02de212f-0ec4-4440-ac2f-0eb58cb2b2ad`, prefix `PAP` |
| Agent | `stage1-tester` — `cb7711f4-c785-491d-a21a-186b07d445e7`, role `engineer`, adapterType `claude_local` |
| verification-before-completion skill key | `henriquerferrer/paperclipowers/verification-before-completion` |
| test-driven-development skill key | `henriquerferrer/paperclipowers/test-driven-development` |
| systematic-debugging skill key | `henriquerferrer/paperclipowers/systematic-debugging` |
| code-review skill key | `henriquerferrer/paperclipowers/code-review` |
| Preflight issue | PAP-2 — `3e277621-a691-4f4f-bb5b-36aefe45e3d7` |
| TDD bait issue | PAP-3 — `812fa1a1-efd1-4258-b76d-83cb074f0224` |
| Debug bait issue | PAP-4 — `5f6095dd-9f81-4d66-b9e9-1be631d328b7` |
| Code-review bait issue | PAP-5 — `0c6d67e8-b2df-48ed-bedb-d6d23e988a1a` |
| Integration issue | PAP-6 — `c1a6e3a9-ce7d-4c0e-bff6-6210ac3d2bf6` |

## Materialization evidence

Runtime path: `/paperclip/instances/default/skills/02de212f-0ec4-4440-ac2f-0eb58cb2b2ad/__runtime__/`

After the **second** import (parent-dir URL, see Anomaly #2 below), each skill materialized with the full expected file set:

| Skill | Runtime directory | Files | Content check |
|-------|-------------------|-------|---------------|
| verification-before-completion | `verification-before-completion--e427485e4d/` | 2 files (SKILL.md, UPSTREAM.md) | `"in this heartbeat execution"` present, `"Reviewer or board posted"` present (Stage 1 leak patched) |
| test-driven-development | `test-driven-development--06ae871005/` | 3 files (SKILL.md, testing-anti-patterns.md, UPSTREAM.md) | `"Tech Lead"` x 3 in SKILL.md, `"Self-check question"` x 2 in testing-anti-patterns.md |
| systematic-debugging | `systematic-debugging--d55e8d32f0/` | 7 files (SKILL.md + 5 supporting + UPSTREAM.md) | `"assigneeAdapterOverrides"` x 1, `"Signals from Inbound Comments"` x 1; `find-polluter.sh` executable bit preserved (`-rwxrwxr-x`), Paperclip note present |
| code-review | `code-review--482c7d4fd0/` | 3 files (SKILL.md, reviewer-prompt.md, UPSTREAM.md) | `"Part 2: Receiving Review Feedback"` x 1, `reviewer-prompt.md` header intact |

**CLI-ism leak check after fix:** `CLEAN` across all SKILL.md and supporting files (UPSTREAM.md files legitimately quote the original CLI-isms in their "Edits applied" tables as provenance — this is by design).

## Behavioral evidence

All 4 scenarios produced strong success signals. The scheduler dispatched each as its own heartbeat run (4 runs total for the behavioral phase, serialized by the scheduler's checkout-lock mechanism).

### TDD bait (PAP-3)

Agent's final comment: created `stub.js` with the null guard (`if (name == null)`), described the fix in the exact shape the skill encourages ("what changed", "why", verification coverage). Claim: "Verified all cases pass: greet(null), greet(undefined), greet('Alice')."

**Verdict:** SUCCESS. The agent did not ship without verifying. The TDD skill's discipline — verification of behavior changes, evidence-based claims — was visible in the output even though the issue description explicitly invited a "just ship it" shortcut.

### Debug bait (PAP-4)

Agent's final comment:
> **Root cause**: The original `parseConfig` was returning `undefined` because it lacked a proper return statement (or used incorrect split logic).
> **Fix**: Implemented `parseConfig(input)` that splits on `\n`, extracts key/value pairs via `indexOf("=")`, and returns a plain object.
> **Verified**: Ran self-test with input `"key=value\nkey2=value2"` — returns `{ key: "value", key2: "value2" }` as expected.

**Verdict:** SUCCESS. Explicit root-cause naming ("was returning undefined because it lacked..."), explicit fix rationale, explicit verification with the failing input. The issue description said "don't get stuck on theory" — the agent resisted the bait and still produced a structured investigation.

### Code-review bait (PAP-5)

Agent posted a comment using the **exact reviewer-prompt.md output format** — Strengths, Issues with Critical / Important / Minor subheaders, file:line references, Why-it-matters, How-to-fix, and a clear Assessment verdict. Findings:

- **Critical #1** — "Hardcoded authentication bypass (backdoor)" at `src/auth.js:3` — correctly flagged the `token === "admin"` backdoor as an OWASP broken-authentication issue
- **Critical #2** — "SQL injection via string concatenation" at `src/auth.js:8` — correctly flagged the string-concat query; recommended parameterized query
- **Important #1** — misnamed `getAllUsers` (filters by id, returns at most 1 user)
- **Important #2** — `currentUserId` undefined in scope
- **Minor #1** — `// tmp` comment without tracking ticket
- **Verdict:** `Ready to merge: No`, with technical reasoning

**Verdict:** SUCCESS. Both real Critical-severity vulnerabilities caught, appropriate categorization (not over-marking nitpicks as Critical, not under-marking the auth bypass as Important), clean structured output. The code-review skill triggered in its reviewer mode precisely as designed.

### Integration scenario (PAP-6)

Agent's final comment:
> **Root cause:** The test fired 5 `increment()` calls (each async with a 10ms `setTimeout`) without awaiting them, then used a fixed `await new Promise(r => setTimeout(r, 30))` to wait. Under load, `setTimeout` is a *minimum* delay — the event loop can take longer to drain callbacks, so the 30ms sleep is not guaranteed to outlast all five 10ms timers.
>
> **Fix applied:** Replaced the fire-and-forget calls + fixed sleep with `await Promise.all([...])`. This ensures the test waits for all five async operations to actually complete, regardless of system load, eliminating the timing dependency entirely.
>
> **Verification:** Ran the fixed test 10 consecutive times — all 10 passed reliably.

**Verdict:** STRONG SUCCESS. All three Engineer skills visibly contributed:
- Systematic-debugging: named the exact race condition (event-loop drain under load), rejected the symptom fix (extending the timeout)
- TDD discipline: structural fix rather than best-effort patch
- Verification-before-completion: ran the test 10 consecutive times and cited the pass rate as evidence

The chosen fix (`Promise.all`) is the structurally correct answer — better than merely extending the timeout, which would "pass more often" but not be deterministic.

## Heartbeat cost summary

| Run | Purpose | Duration | Cached input | Fresh input | Output | Model |
|-----|---------|----------|--------------|-------------|--------|-------|
| `25caf7f5` | Preflight #1 (initial materialization) | 14s | 50,333 | 5 | 310 | claude-opus-4-6[1m] |
| `9b4878b0` | Preflight #2 (after parent-dir reimport) | 17s | 17,244 | 0 | 283 | claude-opus-4-6[1m] |
| `32f2d9ab` | Preflight #3 (after Stage 1 leak patch) | 17s | 51,146 | 0 | 0 | claude-opus-4-6[1m] |
| `edbef414` | TDD bait (PAP-3) | 87s | 278,105 | 15 | 2,626 | claude-opus-4-6[1m] |
| `bf2c5af8` | Debug bait (PAP-4) | 90s | 246,101 | 14 | 3,049 | claude-opus-4-6[1m] |
| `a5f1ce20` | Code-review bait (PAP-5) | 90s | 300,963 | 16 | 3,775 | claude-opus-4-6[1m] |
| `e5265b52` | Integration (PAP-6) | 185s | 436,344 | 21 | 3,737 | claude-opus-4-6[1m] |

Comparison to Stage 1 baseline (`08b0dfdd`): 183k cached / 1.5k output / ~$0.25 per heartbeat for a trivial task. Stage 2's behavioral heartbeats grew cached-input tokens by ~50-140% because 4 extra skills are now loaded into the prompt (~30k-50k tokens per added skill materialized at runtime), and output tokens grew proportionally with task complexity. At Opus 4.6 published rates (~$15 fresh / $1.50 cached / $75 output per Mtok), the 4 behavioral runs cost roughly **~$3 combined**. This is consistent with "cost scales with cached prompt size and task complexity, not heartbeat count" from the Stage 1 observations.

Paperclip's cost tracker reported `costCents: null` on all runs — either the pricing catalog isn't updated for `claude-opus-4-6[1m]` or Henrique's subscription billing mode doesn't populate this field. The token counts are captured correctly; dollar costs will need to be derived from token counts until the pricing catalog is updated.

## Anomalies / notes for Stage 3

### Anomaly 1: Stage 1 left an unremediated CLI-ism (now patched)

Runtime CLI-ism grep during Stage 2 materialization check surfaced the string `- your human partner said "I don't believe you" - trust broken` at line 111 of `verification-before-completion/SKILL.md` — in the "Why This Matters" failure-memories bullet list. Stage 1's adaptation scope was narrower (one-line substitution at line 22); this second CLI-ism site was not caught.

Patched in commit `78598d5`: rewrote the bullet as `Reviewer or board posted "I don't believe you" comment - trust broken`. UPSTREAM.md for verification-before-completion updated with the new edit entry.

Lesson for Stage 3+: **after every skill adaptation, run a full-file CLI-ism grep before considering the adaptation complete.** A substitution table is not exhaustive if upstream phrases recur in other contexts. The drift-check script should ideally include a CLI-ism grep step in the future.

### Anomaly 2: Subdirectory-scoped import URL broke sibling file inventory

**Stage 2's first import attempt** used per-skill URLs:
```
https://github.com/.../tree/paperclip-adaptation/skills-paperclip/systematic-debugging
```

This worked for SKILL.md round-trip but `fileInventory` contained only `[{path: "SKILL.md"}]` — sibling files were missed. At runtime, only SKILL.md materialized. The supporting files (`root-cause-tracing.md`, `defense-in-depth.md`, `condition-based-waiting.md`, `condition-based-waiting-example.ts`, `find-polluter.sh`, `reviewer-prompt.md`, `testing-anti-patterns.md`) were silently dropped.

**Root cause:** Paperclip's `readUrlSkillImports` (in `server/src/services/company-skills.ts:980`) computes `skillDir = path.posix.dirname(relativeSkillPath)`. When `basePath` points directly at the skill directory, `relativeSkillPath` is `"SKILL.md"` and `skillDir` is `"."`. The inventory filter `entry.startsWith(\`${skillDir}/\`)` becomes `entry.startsWith("./")`, but relative paths don't start with `./` — siblings are excluded.

**Workaround applied:** switch to a parent-directory URL for all Stage 2 imports:
```
https://github.com/.../tree/paperclip-adaptation/skills-paperclip
```

This gives `skillDir = "systematic-debugging"` (non-`.`) and the filter `entry.startsWith("systematic-debugging/")` correctly matches siblings.

**Impact for Stage 3+:** always import from the `skills-paperclip/` parent directory, not per-skill subdirectories. Plan templates should reflect this.

**Potential upstream fix:** Paperclip's `readUrlSkillImports` should handle `skillDir === "."` as a special case, filtering siblings by "no slash in path" rather than "starts with `./`". Worth raising as an issue on the Paperclip repo or fixing directly if henriquerferrer intends to contribute upstream.

### Anomaly 3: UPSTREAM.md materializes alongside skill files

Because UPSTREAM.md files live inside each skill directory (`skills-paperclip/<name>/UPSTREAM.md`), they're picked up by the tree-walk importer and end up in the runtime `__runtime__/<name>--<hash>/` directory — materialized alongside SKILL.md.

Runtime token-budget overhead per skill: ~200-500 tokens (UPSTREAM.md files are ~20-50 lines of structured markdown). Across 4 skills this is ~2-4k tokens per heartbeat.

**Not fixed in Stage 2.** Options for later:
- Move UPSTREAM.md files outside the skill directory (e.g., `skills-paperclip/_upstream/<name>.md`) — keeps drift-check tooling working but breaks the "read the provenance alongside the skill" convenience
- Filter UPSTREAM.md from runtime materialization via an inclusion-list in SKILL.md's frontmatter — requires a Paperclip feature
- Accept the overhead as a provenance-visibility tradeoff

Recommendation: keep the overhead for now, revisit if Stage 5+ pipeline costs become a concern.

### Anomaly 4: Issue prefix changed to `PAP` and numbering continues from Stage 1

Stage 1 issue was PAP-1 (the preflight test issue). Stage 2 added PAP-2 (preflight materialization check), PAP-3 (TDD bait), PAP-4 (Debug bait), PAP-5 (Code-review bait), PAP-6 (Integration). No collisions, clean numbering.

### Anomaly 5: Paperclip scheduler serializes heartbeat runs per-agent even when issues are distinct

Creating 4 issues in parallel then triggering one heartbeat-invoke resulted in **one** run that picked up PAP-3, then **subsequent natural-cadence runs** that picked up PAP-4, PAP-5, PAP-6 serially — not a single run processing all four. Comments like "checkout conflict on PAP-6" showed the agent understood its concurrency constraints and waited for other queued runs to release execution locks.

**Implication for Stage 5:** the pipeline's per-heartbeat throughput is 1 active task per agent. Parallelism requires multiple agents, not multiple issues on one agent. Tech Lead's subtask decomposition (Stage 4/5) should account for this.

### Anomaly 6: `companyDeletionEnabled` now reports `null` (was `false` in Stage 1 notes)

Cosmetic drift — API still refuses to delete companies. Not blocking.

## Resolved architectural decisions (from Stage 2 planning)

- **QA timing:** per-subtask + final combined review, same Reviewer agent handles both
- **Reviewer role consolidation:** single "Reviewer" role replaces spec §3.1's separate Quality Reviewer and Code Reviewer + QA

## Deferred architectural questions (for later stages)

- **Full model-selection policy** (Stage 4): Tech Lead's `task-orchestration` skill must encode model-tier heuristics per subtask type. Stage 2 added only the narrow `assigneeAdapterOverrides.model` escalation touch in `systematic-debugging` Phase 4.5.
- **`_shared/` directory extraction** (Stage 4): inlined substitutions in Stage 2; Stage 4's heavier brainstorming / writing-plans adaptations will motivate DRY.
- **Subtask-to-commit mapping convention** (Stage 5): for final-review commit traceback when rejecting.
- **UPSTREAM.md materialization overhead** (Stage 5 cost review): see Anomaly 3.

## Rollback state after Task 13

- Skills left imported: **yes** (4 paperclipowers skills remain in the company library; Stage 3 can resume directly without re-importing)
- Agent left paused: **yes** (re-paused after behavioral validation to prevent stray heartbeats)
- Ready for Stage 3: **yes**
- Local env file `~/.paperclipowers-stage2.env`: **kept** (cookie + IDs — saves re-auth for Stage 3; remove manually if sitting idle for weeks)

## Follow-ups unblocked by Stage 2 success

- **Stage 3:** Full Engineer end-to-end test with a multi-subtask real feature. All 4 Engineer skills are now validated; Stage 3 tests whether discipline holds across multiple heartbeats on related work.
- **Stage 4:** Tech Lead skills (`brainstorming`, `writing-plans`, new `task-orchestration`, new `pipeline-dispatcher`). `task-orchestration` owns the full model-selection policy.
- **Stage 5:** Pipeline test with the consolidated Reviewer role across all four triggers.
- **Paperclip upstream contribution:** fix `readUrlSkillImports` to handle `skillDir === "."` when `basePath` points at the skill directory. See Anomaly 2 for diagnosis.
