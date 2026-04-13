# Upstream Provenance — code-review

**Stage introduced:** Stage 2
**Adaptation type:** GREENFIELD DERIVATIVE — merger of 3 upstream files into 2 Paperclip-native files. Do not treat upstream changes as patches to apply.
**Last synced:** 2026-04-13
**Upstream base commit:** 6f204930537670d9173aed20e96b699799ee6c31
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
