# Upstream Provenance — task-orchestration

**Stage introduced:** Stage 4
**Adaptation type:** GREENFIELD DERIVATIVE — structural merger of `subagent-driven-development` (primary) and `dispatching-parallel-agents` (concepts), rewritten for Paperclip heartbeat + subtask-graph model. Do not treat upstream changes as patches to apply.
**Last synced:** 2026-04-14
**Upstream base commit:** 8ea39819eed74fe2a0338e71789f06b30e953041
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
| subagent-driven-development: "Model Selection" | `task-orchestration/SKILL.md` § Model Selection (stub — Paperclip's `assigneeAgentId` picks a named agent, not a model tier; explicit per-issue model-tier dispatch is a Stage 6 follow-up) |
| subagent-driven-development: "Handling Implementer Status" | `task-orchestration/SKILL.md` § Per-Completion Heartbeat (DONE/DONE_WITH_CONCERNS/BLOCKED/NEEDS_CONTEXT map to status+mention comment forms in Notification Protocol) |
| subagent-driven-development: "Prompt Templates" pointer | `task-orchestration/SKILL.md` § Subtask Description Template (pointing at the three template files) |
| subagent-driven-development: "Example Workflow" | Rewritten as Paperclip curl-recipe walkthrough in `task-orchestration/SKILL.md` § Example Workflow (upstream's Task() syntax not portable to heartbeat mode; a concrete curl-based example is necessary to make the abstract rules actionable) |
| subagent-driven-development: "Advantages" | Dropped — self-congratulatory, not procedural |
| subagent-driven-development: "Red Flags" | `task-orchestration/SKILL.md` § Red Flags (adapted list; Paperclip-specific flags added — RULE 1/2/3 violations, shared-workspace parallelism, self-mention loops) |
| subagent-driven-development: "Integration" | `task-orchestration/SKILL.md` § Integration (Paperclip companion-skill list, not upstream skill list) |
| subagent-driven-development: implementer-prompt.md | `task-orchestration/implementer-subtask-template.md` (converted from Task-tool prompt to subtask-description template) |
| subagent-driven-development: spec-reviewer-prompt.md | `task-orchestration/spec-review-subtask-template.md` (same conversion; marked DORMANT until Stage 5 Reviewer exists) |
| subagent-driven-development: code-quality-reviewer-prompt.md | `task-orchestration/code-quality-review-subtask-template.md` (same; DORMANT) |
| dispatching-parallel-agents: "Identify Independent Domains" + "Dispatch in Parallel" | `task-orchestration/SKILL.md` § Parallelism via Independence (boiled down to: independence = no blockedByIssueIds edge + distinct workspaces) |
| dispatching-parallel-agents: "Agent Prompt Structure" | `task-orchestration/SKILL.md` § Subtask Description Template (the "focused / self-contained / specific about output" quality checklist absorbed verbatim) |
| dispatching-parallel-agents: "Common Mistakes" | Absorbed into § Red Flags |
| dispatching-parallel-agents: "Real Example from Session" | Dropped — debugging-specific and CLI-centric |
| dispatching-parallel-agents: "Key Benefits" / "Real-World Impact" | Dropped — rationale prose |

## Design deviations documented here (not in design spec)

1. **@mention-based per-completion wake.** The spec §3.2 flow shows "Paperclip auto-wakes dependent subtasks on completion." That phrase is load-bearing for the Engineer chain but does NOT address how the Tech Lead wakes per subtask completion. Task orchestration invents the `@<tech-lead>` mention pattern because Paperclip's `issue_children_completed` wake fires only when ALL children are terminal (`server/src/services/issues.ts:1347-1376`), making it unusable as a per-subtask trigger. This deviation should be raised as a spec clarification after Stage 4 validation confirms the pattern works.
2. **Paused-target pre-PATCH check.** Stage 3 Anomaly 1 exposed that `issue_assigned` wakes are silently dropped when the target agent is paused. The skill encodes a mandatory `GET /api/agents/:id` status probe before every assignee PATCH (and before the POST that sets the first subtask's assignee). No upstream analogue (CLI has no paused state).
3. **Subtask-description Notification Protocol section.** The upstream "subagent reports status" convention is implicit in the Task-tool response; Paperclip needs it explicit in the subtask description because the assignee runs in a separate heartbeat with no prior-conversation memory.
4. **DONE_WITH_CONCERNS as a separate notification form.** Upstream has DONE_WITH_CONCERNS as an in-session status; Paperclip needs it surfaced as a distinct `@tech-lead` comment form so the Tech Lead can branch its per-completion behaviour (see SKILL.md § Notification Protocol — DONE_WITH_CONCERNS asymmetry).

## Resolved design decisions

- **Stage 4 omits the Reviewer-review loop.** The upstream two-stage review (spec compliance, then code quality) is encoded structurally (§ End-of-Feature Review; hand-off hooks) but DORMANT — the two Reviewer templates are shipped but unused because the Reviewer agent doesn't exist until Stage 5. The hand-off points are committed now so Stage 5 just adds the Reviewer agent and flips the dormant paths live without changing the skill.
- **Progressive assignment is unconditional.** The skill has NO escape hatch — every subtask chain is created with null assignees except the first, regardless of whether the chain has 2 subtasks or 20. See spec §5.4 amendment.

## Update procedure

**Do not mechanically re-apply upstream patches to this skill.** It is a structural merger, not an edit. When upstream restructures any of the source files:

1. Run `scripts/check-upstream-drift.sh task-orchestration` to see what changed upstream.
2. Read the upstream changes as inputs to a re-evaluation, not as patches.
3. For each upstream change, decide: does it add substantive new content that should flow into our merged skill? If yes, port the idea (not the literal text) into the appropriate section.
4. Update this file's base SHA when the re-evaluation is complete.

**High drift risk.** Upstream's `subagent-driven-development` has restructured before (the split into three prompt files was a relatively recent change). Expect to re-evaluate on every major upstream release.

## Stage 5 revisions

- **§ The Process Step 1 rewritten.** Removed description-fallback branch; `.planDocument` is now always populated by `writing-plans` before this skill fires. If null, escalate to board rather than fall back. (Companion First Wake bullet at line 56 also updated for consistency — same content, different phrasing in two places.)
- **§ Creating the Subtask Graph § Reading the `needsDesignPolish` flag per slice ADDED.** Stage 5 reads the flag and copies it into subtask descriptions (read-only surface). Stage 6 will wire the Designer-subtask-creation branch.
- **§ When to Invoke wake #3 gained a Stage 5 note.** Per-subtask Reviewer handoff intentionally unwired in Stage 5.

Pin SHA for Stage 5: `ce32bbdfa3d2a52462ae68fa9d6248eab681bbff`.

## Stage 5 follow-up (2026-04-16) — Anomaly 4 + 5 amendments

- **§ Creating the Subtask Graph field-table `status` row HARDENED.** Explicit caveat: `"todo"` always at creation, even for followers with non-empty `blockedByIssueIds`; `"blocked"` is a runtime-set status only. (Stage 5 Anomaly 5: PAP-21 was created with `status: "blocked"`; `issue_blockers_resolved` rescued it, but the state-machine path was wrong.)
- **§ Post-POST verification (RULE 1 + Anomaly 5 self-check) ADDED** between the POST recipes and § Progressive Assignment. Mandates a GET-parent-children check after POSTing to verify `assigneeAgentId: null` on all followers and `status: "todo"` on all subtasks. (Stage 5 Anomaly 4: PAP-21 was created with `assigneeAgentId` pre-set; only an idle target kept the pipeline running.)

Pin SHA for Stage 5 follow-up: `3e5c3b7648108afe671fd05de825c52523a4df79`.

## Stage 5 follow-up (2026-04-17) — field-split correctness patch

- **§ The Process Step 1 board-return PATCH corrected** from `assigneeAgentId: "<board-id>"` to `assigneeUserId: "<board-user-id>", assigneeAgentId: null`. Paperclip API validates `assigneeAgentId` as UUID; the board is a better-auth user (non-UUID), so the PATCH must target `assigneeUserId`. Same rule applied to every other board-routing PATCH across five skill files + spec §5.2. See `_shared/paperclip-conventions.md` § Field-split rule for the canonical statement.
- Stage 5 never exposed this because Anomaly 3 was the Reviewer skipping the board entirely — no board PATCH ever fired. The initial Stage 5 follow-up (3e5c3b7) inherited the bug from spec §5.2; both now fixed together.

Pin SHA for Stage 5 follow-up (field-split correction): `86f0e0c2d12b038593913293b6dc79ea5db24c47`.

## Stage 6 (2026-04-17) — Designer role activation

- **§ Stage 6 activation — spawning a Designer subtask when `needsDesignPolish: true` ADDED** to § Reading the needsDesignPolish flag per slice. Turns the Stage 5 read-only surface into a live orchestration branch: Engineer+Designer subtask pair with progressive assignment, blockedBy edge between them, same End-of-Feature check unchanged.
- **§ Post-POST verification subsection UPDATED** — "Exactly ONE subtask" → "Exactly ONE subtask per chain" to cover multi-chain cases introduced by Engineer→Designer pairs.

Pin SHA for Stage 6: `15ecff28fa048f3435cdd83e27673d7817ca203a`.

## Stage 7 prep (2026-04-18) — A16 subtask projectId inheritance

- **§ Creating the Subtask Graph field table gained a `projectId` row** between `parentId` and `assigneeAgentId`. Rule: `projectId` on every subtask POST MUST equal the parent's `projectId` (copied from the first-wake GET on the parent); `null` if the parent is ungrouped. The Paperclip server does NOT auto-inherit this field from `parentId`, so omitting it leaves the subtask with `project_id = NULL` in the DB, which routes the assignee's heartbeat to `ws_source = agent_home` instead of `project_primary` (Stage 6 A10 failure mode).
- **§ Curl recipes 1 and 2 BOTH gained a `projectId` field** in the JSON body, placed after `parentId` to match the field table order. The placeholder `<parent-projectId-or-null>` signals that the value is copied from the parent and may legitimately be `null`.
- **§ Post-POST verification subsection gained a third bullet** — check that each subtask's returned `projectId` equals the captured parent `projectId`, with an explicit caveat against "the ids happen to look similar" rescue paths. Rescue PATCH clause extended to cover `projectId: <parent's>`.
- **Stage 6.5 Anomaly 16 context.** Stage 6.5 Run 2 POSTed PAP-34 and PAP-35 without `projectId`; both landed with `project_id = NULL`. Run 1 (PAP-31 + PAP-32) had inherited `projectId` — the difference in Run 2 was silent, model-driven omission of the field by the TL between the two runs. Run 2 was saved only by an operator-side manual PATCH before the Designer's wake; without that intervention the Designer would have regressed to the Stage 6 A10 failure. See `docs/plans/2026-04-17-stage-6.5-results.md` § A16 for the full evidence.
- **Not fixed here (Stage 7+ server-side candidate).** A complementary fix in Paperclip core would be to have `createIssueSchema` auto-inherit `projectId` from `parentId` when the subtask has no explicit projectId. This skill amendment is portable and works against today's Paperclip; the server-side fix would make the rule defense-in-depth. Both are worth doing.

Pin SHA for Stage 7 prep (A16): `fef8ba0d9133e28092612698a4240e9b1c61b2cc`.

## Stage 7 prep (2026-04-18) — A15 @mention placeholder normalization

- **§ Creating the Subtask Graph curl recipes 1 and 2** — `@tech-lead-agent` in the embedded Notification Protocol example strings changed to `@<tech-lead-name>` (angle-bracket placeholder).
- **§ Progressive Assignment worked example (steps 4 and 6)** — `@tech-lead DONE — ...` changed to `@<tech-lead-name> DONE — ...`; step 4 gained an inline reference to `pipeline-dispatcher § No real-name substitution in quoted examples` explaining the rule.
- **Stage 6.5 Anomaly 15 context.** Paperclip's `@mention` resolver matches `@<real-agent-name>` in any comment body regardless of markdown context (code blocks and blockquotes do not protect). Stage 6.5 Run 2 observed a Reviewer plan-review comment firing a spurious wake on the Tech Lead from a quoted Notification Protocol example that had been substituted with the real TL name. Bare tokens like `@tech-lead` in skill prose are currently safe only because no agent is literally named `tech-lead`; that is a latent risk if future stages hire such agents. Angle-bracketed placeholders (`@<role-name>`) break Paperclip's parser reliably because `<` is a non-word boundary char.
- **Companion discipline added to `pipeline-dispatcher/SKILL.md § Heartbeat-Mode Disciplines § No real-name substitution in quoted examples`** codifies the general rule: when an agent quotes a protocol template into a comment body (e.g., during review), preserve the placeholder verbatim — never substitute the real name. Real `@<agent-name>` is a wake directive, always. Every skill-prose example now uses the angle-bracket form consistently so a verbatim quote remains inert.
- **Not fixed here (Stage 7+ server-side candidate).** Paperclip core could ignore `@mentions` inside markdown code blocks and blockquotes (the A15 option-a remediation from the Stage 6.5 results doc). The skills-side normalization is belt-and-suspenders and portable against today's Paperclip; the server-side fix would make the correctness property structural rather than disciplinary. Both are worth doing.

Pin SHA for Stage 7 prep (A15): `1b2c3fc5ba1a8e5c10ef51657f2b6283c39e6da2`.
