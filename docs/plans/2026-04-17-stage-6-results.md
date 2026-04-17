# Stage 6 Validation Results

**Date completed:** 2026-04-17
**Outcome:** PARTIAL SUCCESS — Hook 1 (Designer subtask spawn) validated structurally; Hook 2 (MCP isolation) failed due to a spec-level error in the cwd model. Full end-to-end pipeline executed with working deliverable (hand-written polish), 10 heartbeats, $4.72 (47% of budget target). Seven carry-forward anomalies surfaced, four of them new; spec §7.2 requires redesign before Stage 7.
**Tracking branch:** `paperclip-adaptation`
**Stage 6 commit range:** `fcac2e0..<results-commit>` (plan + skill amendments + backfill + this results doc)
**Prior state:** Stage 5 follow-up #2 closed at `fe6336e` + post-stage cleanup commits (`f2ab31e`).

## Captured identifiers

| Field | Value |
|-------|-------|
| Company | `Paperclipowers Test` — `02de212f-0ec4-4440-ac2f-0eb58cb2b2ad` |
| Designer agent | `stage6-designer` — `e7ad0312-f416-42c9-9090-6dc51bd99363`, role `designer`, 8 desiredSkills |
| `ui-ux-pro-max` skill | `d313d80c-0125-4d78-a319-4d06af119bad`, key `nextlevelbuilder/ui-ux-pro-max-skill/ui-ux-pro-max`, pin `b7e3af80f6e331f6fb456667b82b12cade7c9d35` |
| `21st-dev-magic` secret | `f49ab752-4389-467f-896e-75e71f83355c` (field schema: `{"name","value"}` not plan's `{"id","value"}`) |
| Stage 6 pin SHA | `e4ca9bba01df9f87ffafb0be2c3c7dc7c684e9f8` (backfill tip; content SHA `15ecff28fa048f3435cdd83e27673d7817ca203a`) |
| Parent feature issue | PAP-26 — `bf9bb840-7a5b-47f8-bebe-228daa38bba4` |
| Engineer subtask | PAP-27 — `33f41d95-0f12-4fe5-a992-9575618a8e48` (done) |
| Designer subtask (orphaned) | PAP-28 — `f59218b1-2f28-4a3d-907b-5afdd8198d18` (cancelled as cleanup) |
| Designer subtask (executed) | PAP-29 — `cb45e926-e3d9-4bd7-8e90-d4d573cdaed8` (done) |
| Workspace commits added | `f9ff800` (PAP-27 Engineer), `15fc7fc` (PAP-29 Designer polish) |

## Heartbeat cost summary

| # | Run | Agent | Wake trigger | Dur | Cached in | Out | Cost | fresh/reused |
|---|-----|-------|--------------|-----|-----------|-----|------|--------------|
| 1 | `45b190a7` | PM | unassign→reassign PATCH | 116s | 277,296 | 4,120 | $0.2277 | F |
| 2 | `af85271d` | Reviewer | spec handoff | 203s | 940,755 | 9,140 | $0.5513 | F |
| 3 | `fb235983` | TL | board PATCH | 203s | 610,188 | 8,612 | $0.4364 | F |
| 4 | `c3f6e128` | Reviewer | plan handoff | 168s | 695,536 | 7,306 | $0.4477 | F |
| 5 | `5ef77ae2` | TL | board PATCH (orchestration) | 198s | 746,111 | 8,769 | $0.5145 | F |
| 6 | `8abe3c0b` | Engineer | `issue_assigned` (PAP-27) | 120s | 685,480 | 6,568 | $0.4305 | F |
| 7 | `6c9cc045` | TL | `issue_comment_mentioned` (Eng DONE) | 91s | 289,179 | 3,955 | $0.2336 | F |
| 8 | `8f442301` | Designer | `issue_assigned` (PAP-29) | 199s | 1,040,195 | 8,351 | $0.5927 | F |
| 9 | `f42d2851` | TL | `issue_children_completed` (after PAP-28 cancel) | 103s | 510,485 | 3,243 | $0.3775 | **R** |
| 10 | `97f74609` | Reviewer | final combined review | 208s | 1,813,490 | 10,222 | $0.9130 | F |

**Totals:** 1,609s wall-clock (~27min from first PM wake to Reviewer completion), **$4.7249**, 7,608,715 cached input tokens, 70,286 output tokens, 10 heartbeats. Designer + Reviewer used `claude-sonnet-4-6`; TL/PM/Engineer used `claude-opus-4-6[1m]`.

**Comparison to Stage 5:** Stage 5 was $7.94 / 12 heartbeats / 27.5min / 2 subtasks; Stage 6 was $4.72 / 10 heartbeats / 27min / 3 subtasks (including orphan). Lower cost explained by (a) PM skipping brainstorming (-1 wake vs Stage 5), (b) Reviewer running on Sonnet not Opus, (c) shorter Q&A path. **Budget target $10 — actual 47%.** Unit economics: ~$0.47/heartbeat vs Stage 5's $0.66.

## Pipeline phase verification

### Phase A–B: PM
- Q&A rounds: **0** (PM skipped brainstorming; judged description spec-like enough to proceed directly). Anomaly 8 below.
- Spec document written: YES, `latestRevisionNumber: 1`, 3720 bytes, covers interface, HTML structure, backward compatibility, testing requirements, **and a Designer-scope section with explicit Magic MCP tool safety guidance** (carried forward from PAP-26 description).
- PM board handoff: PATCHed to Reviewer (`in_review` + `assigneeAgentId=Reviewer`). ✓
- Anomaly 2 recurrence: YES — 2 comments (one questions/status, one spec summary).

### Phase C–D: Reviewer spec review → board
- Findings: 0 Critical, 1 Important (timestamp format underspecified), 3 Minor (zero-task edge case, DOCTYPE optionality, `<meta charset>` missing).
- Verdict: APPROVED.
- **Board approval gate: HONORED** — Reviewer PATCHed `{status: todo, assigneeUserId: <board>, assigneeAgentId: null}` + `@board APPROVED` comment. ✓ **Anomaly 3 fix validated for spec approval.**
- Anomaly 2: Reviewer posted 3 comments (status narration + APPROVED + findings).

### Phase E–G: TL plan → Reviewer → board
- Plan written: YES, 4 slices (HTML Emitter / summary+CLI / Tests / **Designer Polish Subtask**), 5494 bytes.
- Slice-level `needsDesignPolish` flag: **NOT EMITTED** on any slice. Anomaly 9 below.
- Reviewer plan review: APPROVED with 2 Minor notes (empty-entries behavior, CLI entrypoint verification).
- Board approval gate: HONORED. ✓
- Anomaly 2: TL posted 2 comments per heartbeat; Reviewer posted 4 comments on plan review.

### Phase H–I: TL orchestration + Engineer subtask
- Subtasks created: **3** (expected 2: Engineer + Designer). PAP-27 (Engineer), PAP-28 (Designer follower, orphaned), PAP-29 (Designer duplicate assigned at creation).
- Progressive assignment (RULE 1): **FAIL on Designer chain** — PAP-29 created with `assigneeAgentId` pre-set to Designer; PAP-28 never progressively PATCHed. Anomaly 6.
- Post-POST verification (Stage 5 follow-up amendment): VIOLATED — multiple issues with non-null assigneeAgentId at chain head (PAP-27 + PAP-29 both assigned), and PAP-28 orphan not detected.
- Engineer heartbeat: succeeded; posted DONE mention + transition to `done`. Workspace commit `f9ff800`.

### Phase I.5: Designer subtask (Hook 1 + Hook 2 verification)
- **Hook 1 (Designer subtask spawn): PASSED STRUCTURALLY** — two subtasks created (Engineer chain head + Designer follower). Not via the task-orchestration amendment's `needsDesignPolish: true` flag path (flag absent from plan); instead via plan-authored Slice 4 (Designer). The amendment's hook point is unreachable until writing-plans emits the flag.
- **Hook 2 (MCP isolation): FAILED** — Designer's completion comment explicitly states: *"The `21st_magic_component_inspiration` and `21st_magic_component_refiner` MCP tools were not available in this heartbeat environment; the polish was applied directly from modern UI principles."* Grep of the heartbeat-run record: 0 `mcp__` tool-use entries, 0 `tool_use` JSON entries. Root cause: spec §7.2 assumes per-agent cwd; Paperclip default is SHARED workspace (Designer committed to Engineer's workspace `cb7711f4-...`, not to the agent-UUID cwd where `.mcp.json` was placed). See Anomaly 10 for remediation options.
- Designer heartbeat: succeeded; hand-wrote polished CSS (card layout, blue gradient header, system font, striped rows, `<tfoot>` total). Commit `15fc7fc` in Engineer's workspace.
- Notification Protocol: VIOLATED — Designer's completion comment did NOT `@mention` the Tech Lead. Anomaly 7.

### Phase J: End-of-feature (pipeline deadlock + recovery)
- TL `issue_children_completed` wake did NOT auto-fire because (a) Designer didn't @mention (A7) and (b) PAP-28 orphan blocked the "all terminal" condition.
- Manual intervention: operator cancelled PAP-28, which flipped all children terminal and fired TL's `issue_children_completed` wake.
- TL heartbeat 9 (`f42d2851`, 103s, $0.38, **sessionReused=true**): transitioned PAP-26 to `in_review`, reassigned to Reviewer.

### Phase K: Final combined review → board
- Reviewer heartbeat 10 (`97f74609`, 208s, $0.91): APPROVED, 0 Critical, 0 Important.
- **Board merge gate: SKIPPED** — Reviewer PATCHed PAP-26 directly to `done` (Stage 5 Anomaly 3 recurrence on the FINAL review branch only; spec and plan approvals correctly routed to board). Anomaly 3 partially closed: gate pattern lands for pre-decision reviews but not for final close-out.
- Anomaly 2: Reviewer posted 4 comments on this run.

## Anomalies

Numbering continues from Stage 5 (Anomalies 1–5) and prior follow-ups.

### Anomaly 2 — REGRESSION, widespread

PM, TL, Reviewer, and Designer all posted redundant status-narration comments (`Done. Here's what I did…`, `PAP-X is now in_review…`, `End-of-feature review`). Comment tallies: Reviewer 10, TL 6, PM 2, Designer 2 (on PAP-29) — ~18 comments on PAP-26, of which ~9 are status narration. `pipeline-dispatcher/SKILL.md § Heartbeat-Mode Disciplines § No gratitude or meta-commentary` prohibits this, but compliance did not improve between Stage 5 and Stage 6 follow-ups. Candidate intervention: make `pipeline-dispatcher` prescriptive with pre-exit comment count (e.g., "before exiting, verify you posted EXACTLY one technical comment in this heartbeat; if two, delete the status-narration one").

### Anomaly 3 — PARTIALLY CLOSED

Spec + plan approval PATCHes from Reviewer correctly target the board via `assigneeUserId` (two clean validations this run). The FINAL combined review still PATCHes `{status: "done"}` directly, bypassing the board merge gate. `code-review/SKILL.md §1.5` amendment covers "approval forward" but its final-review branch collapses the board gate into a Reviewer-direct done transition. Stage 7 amendment candidate: require the same status+assigneeUserId pattern on Trigger 4.

### Anomaly 6 — NEW — TL created duplicate Designer subtask

TL's per-completion heartbeat (7, run `6c9cc045`) responded to Engineer's @mention by POSTing a new subtask (PAP-29, `assigneeAgentId=Designer` at creation) instead of PATCHing the existing follower PAP-28. Both PAP-28 (status=todo, assignee=null, blockedBy=[PAP-27]) and PAP-29 (status=todo, assignee=Designer, blockedBy=[]) coexisted, violating the Post-POST verification invariant (Stage 5 follow-up amendment) that there be AT MOST ONE non-null-assignee subtask per chain. PAP-28 became orphaned (cleaned up by operator cancel). Root cause hypothesis: TL's heartbeat logic, on per-completion wake, rebuilt the subtask graph from scratch instead of querying existing children first. `task-orchestration/SKILL.md § Per-Completion Heartbeat Step 2` says "Find the first child with status: todo whose blockedByIssueIds are now all terminal — that's the next-in-line" — TL did NOT execute this step; it created a fresh subtask instead. Stage 7 amendment candidate: add a pre-POST check "if a follower subtask already exists, PATCH it rather than POST a new one".

### Anomaly 7 — NEW — Designer omitted Notification Protocol @mention

Designer's completion comment (PAP-29) did not contain `@<tech-lead-name>`. The `task-orchestration` Notification Protocol template is verbatim included in every subtask description by the Tech Lead's orchestration step, but the Designer ignored it and posted free-form status narration instead. Consequence: TL did not wake on `issue_comment_mentioned`; the pipeline deadlocked until PAP-28 was cancelled (which made the blocker condition clear and fired `issue_children_completed`). Root cause hypothesis: Designer's skill set (ui-ux-pro-max + verification-before-completion + code-review + pipeline-dispatcher) does NOT include `task-orchestration`, so the Designer's skill context has no Notification Protocol definition. Designer reads the @mention instruction ONLY from the subtask description body. If the description instruction is weakly worded or the model prioritizes ui-ux-pro-max's own closing pattern, the @mention is dropped. Stage 7 remediation: either add task-orchestration to Designer's desiredSkills (excessive — it's producer-side), OR strengthen pipeline-dispatcher Designer section to restate the `@<tech-lead>` requirement (feasible and tight).

### Anomaly 8 — NEW — PM skipped brainstorming Q&A entirely

PM went directly from `issue_assigned` to `PUT /documents/spec` without a single Q&A round. This is acceptable when the description is sufficiently complete, but `brainstorming/SKILL.md` prescribes "after 2-3 Q&A rounds, transition to design presentation" — zero rounds is a boundary case. The PAP-26 description did include explicit interface specs and Designer MCP guidance, which likely triggered PM's "already clear" judgment. Not a skill bug; a judgment call that needs explicit support. Stage 7 candidate: `brainstorming/SKILL.md § First Wake` should say "if the description is already spec-like (has Interface / Acceptance sections), you MAY skip Q&A. Document the decision in your spec's Background section." Makes the skip intentional rather than accidental.

### Anomaly 9 — NEW — `writing-plans` skill does NOT emit `needsDesignPolish: true` for UI slices

TL's plan did not set `needsDesignPolish: true` on any slice. Instead, TL invented a pattern: a separate "Slice 4 — Designer Polish Subtask" alongside Engineer Slices 1–3. This produces the correct visible outcome (two subtasks) via a plan-authoring shortcut, but bypasses the `task-orchestration/SKILL.md § Stage 6 activation` amendment path entirely. The Stage 6 amendment I wrote in Task 4 (spawning a Designer follower from a slice's `needsDesignPolish: true` flag) has zero activation coverage in this run because the flag never appeared.

Two interpretations: (a) the `writing-plans` skill never learned to emit the flag as `true` (Stage 5 hardcoded `false` and Stage 6 was supposed to "flip it live without skill changes" per spec §8 — but Stage 6 didn't amend `writing-plans`); (b) the TL model, given the spec §7.2 Designer role existence, prefers the more explicit "name the Designer slice directly" pattern over the indirect "flag a slice for polish" pattern.

Either way, the Stage 6 hook's amendment path is untested and the `writing-plans` skill should be amended at Stage 7 to emit `true` on any slice whose acceptance criteria reference visual/UI concerns. Alternatively, REMOVE the amendment entirely and codify the TL's invented pattern (explicit Designer slice) in the plan template — this simplifies the mental model at the cost of a small task-orchestration amendment retraction.

### Anomaly 10 — NEW — Spec §7.2 MCP isolation model is incompatible with Paperclip workspace reality

Spec §7.2 prescribes per-agent `cwd` override with agent-specific `.mcp.json`. In reality, Paperclip's default `claude_local` adapter does NOT use a per-agent `cwd` — it uses a PER-CHAIN or PER-PROJECT workspace that all assignees on that issue chain share. Evidence: Designer's commit `15fc7fc` landed in `/paperclip/instances/default/workspaces/cb7711f4-...` (Engineer's agent-UUID workspace), not `/paperclip/instances/default/workspaces/e7ad0312-...` (Designer's agent-UUID workspace) where `.mcp.json` was placed. All children of PAP-26 report `executionWorkspaceId=None`.

Because Claude Code auto-loads project-scoped `.mcp.json` from its *actual* cwd, and the actual cwd was the Engineer's workspace (which has no `.mcp.json`), the Designer got no MCP servers. Hook 2 failed structurally, not from a bug in my configuration.

Three remediation paths for Stage 7:
1. **Per-issue workspace override**: set `executionWorkspaceId` on the Designer subtask to point at a Designer-only workspace that does have `.mcp.json`. Requires understanding of Paperclip's workspace resolution in the adapter.
2. **Workspace-embedded `.mcp.json`**: place `.mcp.json` in the chain's shared workspace and rely on Claude Code's MCP server selection to scope tools per-agent — but this gives every agent MCP access, breaking isolation.
3. **Agent-cwd override re-attempt**: set `adapterConfig.cwd` explicitly on the Designer agent (the pattern the plan originally specified). This was Option A in the Stage 6 plan-deviation decision; we chose Option B (omit cwd) because no existing agent used the override. Stage 7 should re-test with the override + a properly-provisioned cwd, and characterize when/how Paperclip honors vs. ignores the override.

Whichever path Stage 7 takes, spec §7.2 must be rewritten to describe the actual working mechanism, not the assumed one.

## Cross-heartbeat observations

- **Per-issue session keying (spec §5.4 amendment) — VALIDATED for TL.** Heartbeat 9 (`f42d2851`, TL per-completion on PAP-26) showed `sessionReused=true`, `freshSession=false` — TL resumed from heartbeat 5 (`5ef77ae2`, TL plan→orchestration on same PAP-26). ✓
- **Cross-issue freshness.** Every other heartbeat shows `freshSession=true` because each was either a different issue (Engineer on PAP-27, Designer on PAP-29, each first-touch) or an `issue_assigned` wake (which force-resets per §5.4).
- **Wake mechanism gotcha (Anomaly 11 candidate).** PATCH-while-paused DROPS wakes silently — the server emits a `WARN: failed to wake agent on issue update: Agent is not invokable in its current state`, but unpause does NOT replay dropped wakes. Plan Task 7's sequence (Step 7.4 PATCH PM → Step 7.5 unpause all) fell into this trap; the pipeline sat dormant for 30 minutes until an operator unassign→reassign cycle re-fired the wake. Stage 7 plan template must invert the order: unpause first, PATCH second. Alternatively, add an API probe "is there a queued wake for agent X on issue Y?" — would let the operator detect the drop before it stalls the pipeline.

## Skill compliance summary

| Skill | Compliance | Notes |
|-------|-----------|-------|
| `ui-ux-pro-max` (NEW, external) | N/A — never exercised | Designer ran without MCP tools (A10); skill content was loaded but its Magic MCP workflow was unreachable. Imported correctly at `b7e3af8`. |
| `task-orchestration` Stage 6 amendment | Unreachable path | The `needsDesignPolish: true` branch (Task 4) was never triggered because `writing-plans` didn't emit the flag. Amendment content is correct; activation is blocked upstream. (A9.) |
| `pipeline-dispatcher` Stage 6 amendment | Partially exercised | Designer routing worked — Designer correctly identified its role and attempted its workflow. But the workflow's MCP step failed (A10), and Designer omitted the NP `@mention` (A7). Amendment content is correct; a second follow-up should add the explicit @mention reminder for Designer. |
| `brainstorming` Stage 5 follow-up | No regression | PM skipped Q&A entirely (A8 — judgment call, not a skill failure). PUT-then-GET-verify path (Anomaly 1 fix) not exercised (no PUT occurred via this PM run — PM went direct to spec PUT without the status-comment-first artifact of Stage 5 Anomaly 1). |
| `code-review` Stage 5 follow-up | Partially validated | Spec + plan approval PATCHes correctly targeted the board (A3 spec/plan branches closed). Final combined review still direct-mark-done (A3 final branch still open). |
| `writing-plans` | Gap surfaced | Skill does NOT emit `needsDesignPolish: true` on UI slices (A9). Stage 7 amendment candidate. |

## CLI-ism regression check

Skipped for Stage 6 — no new materialized skills to scan beyond ui-ux-pro-max (external, MIT-licensed, upstream responsibility). Stage 5's scan pattern is unchanged; the 8 paperclipowers skills remain pinned at `e4ca9bba01df9f87ffafb0be2c3c7dc7c684e9f8` with no new CLI-isms introduced by the Stage 6 amendments (verified by inspection of the diff `15ecff2..HEAD`).

## Rollback state

- 5 agents paused (Task 10 executed).
- PAP-26 `done`; children PAP-27 `done`, PAP-28 `cancelled` (orphan cleanup), PAP-29 `done`.
- 9 skills in library (8 paperclipowers + ui-ux-pro-max) + 6 unused `ckm-*` skills (side-effect of the single-import for ui-ux-pro-max; `nextlevelbuilder/ui-ux-pro-max-skill` repo contains 7 skills).
- Operator-side: `.mcp.json` in place at Designer's agent-UUID cwd (ineffective per A10), `21st-dev-magic` secret in Paperclip secret store (unused).
- Local env file `~/.paperclipowers-stage5.env` retains `STAGE6_PIN_SHA`, `DESIGNER_AGENT_ID`, `UIUX_*`, `MAGIC_SECRET_*`, `STAGE6_PARENT_ISSUE`.

## Plan deviations (for plan-template hygiene)

1. **Secret create schema**: plan's `{"id":"21st-dev-magic","value":"..."}` → actual `{"name":"21st-dev-magic","value":"..."}`. Secret returned a separate UUID `id`. envBindings uses `secretId: "21st-dev-magic"` (the NAME, which is what the adapter resolves).
2. **Designer cwd override omitted**: plan's `cwd: "/paperclip/instances/default/workspaces/designer-<companyId>"` was replaced with no-cwd (matching the 4 existing agents' pattern). Operator mid-plan deviation chose Option B after `docker exec paperclip mkdir` created the plan's path as `root:root 555`. This choice contributed to A10 — the override approach might have made the per-agent cwd actually work.
3. **`ui-ux-pro-max-skill` repo is a 7-skill bundle.** The plan assumed a single-skill import; the repo contains 6 additional `ckm-*` skills (`ckm-banner-design`, `ckm-brand`, `ckm-design-system`, `ckm-design`, `ckm-slides`, `ckm-ui-styling`). All were imported into the library; only `ui-ux-pro-max` is assigned. Low impact (unused skills don't affect agent behavior) but worth noting for library hygiene.
4. **Plan Task 7 PATCH-before-unpause bug** (A11 above): plan's Step 7.4 PATCH while paused dropped wake silently; unpause didn't replay. Workaround used: unassign→reassign cycle. Stage 7 plan template must unpause before PATCHing.

## Follow-ups for Stage 7+

Sorted by load-bearing weight:

1. **Spec §7.2 rewrite (A10).** Characterize Paperclip's actual workspace model; decide MCP isolation approach (per-issue workspace override? agent-cwd override with a materially-different adapter path? shared workspace + server-side tool filtering?). Without this, the Designer role cannot deliver MCP-driven polish as spec'd.
2. **`writing-plans` amendment (A9).** Either emit `needsDesignPolish: true` on UI-relevant slices, OR retract the `task-orchestration` Stage 6 amendment and codify TL's invented pattern (explicit Designer slice). Pick one, align both.
3. **`task-orchestration` per-completion follower-reuse check (A6).** Before POSTing a new subtask on a completion wake, query existing children for an unresolved-follower candidate; PATCH instead of POST.
4. **`pipeline-dispatcher` Designer @mention reminder (A7).** Tight amendment: add "ALWAYS end your completion comment with `@<tech-lead-name> DONE — <summary>. Commits: <shas>.`" to the Designer section. Low-cost, high-impact.
5. **`code-review` final-review board gate (A3 final branch).** Apply the spec+plan gate pattern to Trigger 4; Reviewer should PATCH `{status: todo, assigneeUserId: <board>, assigneeAgentId: null}` on final approval, not `{status: done}`.
6. **`pipeline-dispatcher` comment-count discipline (A2).** Pre-exit invariant: exactly one technical comment per heartbeat. Stage 5 follow-up level amendment.
7. **`brainstorming` skip-Q&A policy (A8).** Make the zero-round case intentional with a documented criterion.
8. **Stage 6 plan Task 7 PATCH-order fix (A11).** Not a runtime follow-up — a plan-template hygiene fix: unpause before PATCHing.
9. **`paperclipowers/frontend-design` adaptation**: originally deferred from Stage 6. Still deferred; Stage 7 should either author it or definitively drop the ambition.
10. **6 unused `ckm-*` skills cleanup.** Low priority; remove from library if library pollution becomes a concern at Stage 7 production rollout.

## Decision: Stage 7 prerequisites

Before promoting any of this to a non-throwaway company, at minimum:
- **Hook 2 must work** (A10 resolved).
- **TL must stop duplicating followers** (A6 resolved).
- **Designer must honor Notification Protocol** (A7 resolved).

A2 (comment discipline) and A3 final-branch are polish issues; they degrade signal but don't break the pipeline. A8 (brainstorming skip) is a judgment call, not a bug.
