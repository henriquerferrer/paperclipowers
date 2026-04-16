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
