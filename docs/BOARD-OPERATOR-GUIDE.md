# Board Operator Guide — paperclipowers

**Who this is for:** you, the human running a Paperclip company. Not for agents. Read it once per new company; internalize; move on.

**Why it exists:** paperclipowers is a role-specialized skill library on top of Paperclip. The board layer (CEO, CTO) and pipeline layer (PM, Tech Lead, Engineer, Reviewer, Designer) each do a narrow job well. The system fails predictably when the board (that's you) violates the shape of what each role accepts as input. This guide teaches the shape so you don't.

## The mental model in 60 seconds

Four layers, each with one responsibility:

| Layer | Who | What they produce | What they do NOT do |
|---|---|---|---|
| **Board** | You (human, cookie-authed) | Strategy issues, board answers, hires-approvals | Write specs, write plans, write code |
| **Board agents** | CEO, CTO | CEO: triage + delegate. CTO: ADRs. | Write specs, write plans, write code |
| **Pipeline** | PM, Tech Lead, Engineer, Reviewer, Designer | Specs (PM), Plans (TL), Code (Eng), Review findings (Rev), Polish (Des) | Decide stack, decide company strategy |
| **Artifacts** | (not agents — documents) | ADRs, specs, plans, subtasks, PRs | — |

Your only levers: **create issues** and **answer board-Q issues**. Everything else flows from that.

## The five issue kinds (title-prefix convention)

Every issue you author gets one of five prefixes. This is the single most important discipline in this guide.

| Prefix | Shape | Default assignee | Example |
|---|---|---|---|
| `Strategy:` | Direction, no defined scope yet. | CEO | `Strategy: Stand up Higeia's public marketing surface` |
| `Feature:` | One shippable surface, one spec. | PM (or CEO if no PM yet) | `Feature: Indexable SEO landing pages for top-20 PT queries` |
| `ADR:` | One technical decision. | CTO | `ADR-0001: Stack + hosting architecture` |
| `Hire:` | Agent creation request. | CEO | `Hire: Product Manager for marketing surface` |
| `Board-Q:` | Question YOU need to answer (not the other way around). | Board user | `Board-Q: Payment provider + sliding-scale quota policy` |

Self-check before submitting an issue: **"If the prefix says X, is the body actually one X-shaped problem?"** If not, it's really a `Strategy:` — let the CEO decompose.

### When each kind is right

- **`Strategy:`** — you have a goal but no concrete artifact list yet. The CEO decomposes into ADRs + Features + Hires + Board-Qs. Use this when you don't yet know which sub-issues you need.
- **`Feature:`** — you know the shippable surface. One spec, one plan, one slice of engineering. The PM owns it end-to-end once you've created it.
- **`ADR:`** — usually the CTO authors these, not you. You'd only author one as a shortcut when you're sure which architectural decision needs to happen next.
- **`Hire:`** — rare; the CEO usually initiates via `paperclip-create-agent` during a heartbeat. Use this when you specifically need a role the CEO hasn't thought to hire yet.
- **`Board-Q:`** — something your agents are blocked on until you answer. Examples: budget, vendor preference, regulatory question, user-facing copy decision.

## The one anti-pattern to never commit: compound briefs

A compound brief is a single issue whose body asks for more than one artifact kind. The canonical failure:

> **Bad — HIG-4 shape:**
> ```
> Title: CTO onboarding — ship Higeia's product surface and staff engineering
> Body:
>   Write me:
>   - Technical architecture sketch (stack, hosting, db)
>   - Sequencing plan (what to build in what order)
>   - Staffing plan (who to hire when)
>   - Compliance matrix (how 7 constraints get enforced)
>   - Open questions for me
> ```

This asks for: ADR (architecture) + ADR (compliance) + Feature planning + Hire + Board-Q — five artifacts. The CTO did its best and produced a hybrid plan doc that no role can revise cleanly, because revising any one part means re-authoring the whole hybrid.

> **Good — the same intent, as scoped issues:**
> ```
> Strategy: Stand up Higeia's product surface
>   (CEO decomposes into:)
>   - ADR-0001: Stack + hosting architecture (CTO)
>   - ADR-0002: Compliance-at-schema data model (CTO)
>   - ADR-0003: Cost & vendor boundaries (CTO)
>   - Hire: PM + tech-lead-product + Engineer + Reviewer (CEO, blocked on ADR-0001)
>   - Board-Q: Budget, hosting region, telehealth vendor, payment provider... (board)
> ```

**The CEO will now auto-reject compound briefs** (with the triage-modes skill installed) — but you don't want to rely on the CEO's rejection. Split before you submit.

### How to tell you're about to commit one

Before hitting submit, count the artifact kinds in the body:

- **One spec-shaped problem?** → `Feature:`
- **One technical decision?** → `ADR:` (or let the CTO author)
- **Multiple of the above?** → `Strategy:` (let the CEO decompose)
- **A question you want answered by your agents?** → rephrase: you don't ask, you direct. If the question is "how should we do X," that's `Strategy:`. If it's "is Y true," that's research — open a `Feature:` assigned to the right role.
- **A question from your agents that they blocked on?** → Board-Q flows the OTHER way — agents create these and assign to you.

## Who creates what, when

Work flows through these hand-offs. You touch the system primarily at the first row.

| Step | Actor | Artifact |
|---|---|---|
| 1. Define the goal | Board (you) | `Strategy:` or `Feature:` issue |
| 2. Triage + decompose (if Strategy) | CEO | Sub-issues with mode + ADR references + routing |
| 3. Technical framing (if needed) | CTO | Framing comment on the feature issue, or an ADR |
| 4. Spec | PM | `spec` document on the feature issue |
| 5. Spec review | Reviewer | Approval or findings |
| 6. Board approves spec | Board (you) | Comment + PATCH forward |
| 7. Plan | Tech Lead | `plan` document on the feature issue |
| 8. Plan review | Reviewer | Approval or findings |
| 9. Board approves plan | Board (you) | Comment + PATCH forward |
| 10. Subtasks | Tech Lead | One subtask per plan slice |
| 11. Implementation | Engineer (possibly Designer) | Code commits |
| 12. Final review | Reviewer | Approval |
| 13. Board merges PR | Board (you) | Merge on GitHub |

**Your touchpoints are rows 1, 6, 9, 13.** Everything else happens between agents.

## Your authority — what you do personally

You, the board, have full authority over:

- Creating any issue.
- Approving or rejecting any spec, plan, or ADR.
- Hiring or firing any agent.
- Setting the company goal.
- Answering board-Q issues.
- Merging PRs on GitHub (the pipeline produces them; you ship them).

## What you do NOT do

- Write specs yourself. If you need a spec, create a `Feature:` issue assigned to the PM.
- Write plans yourself. If you need a plan, create a `Feature:` issue; the Tech Lead writes the plan after the PM ships the spec.
- Write code yourself (you CAN, of course — but the pipeline's job is to produce it; if you're writing code, the Engineer isn't).
- Skip the CEO. Assigning directly to the CTO / PM / Tech Lead bypasses triage. The CEO's Prime Directives + Triage Modes + ADR discovery exist to prevent the kinds of mis-scoped briefs that waste downstream heartbeats. Use the CEO.
- Treat the CTO as a super-PM. The CTO writes ADRs, not specs. If you assign a feature-shaped issue to the CTO, it will (correctly) reject and route back to the CEO. Assign features to the CEO; assign architecture decisions to the CTO.

## Approving and rejecting — the board gate

When a spec or plan lands in your queue (status `todo`, `assigneeUserId` = you), you're being asked to approve.

### Approving

Post a short comment and PATCH forward:

```
Approved. <optional — one sentence if any context>
```

Then PATCH the issue back to the next role:
- **For a spec approval:** `{"status":"todo", "assigneeAgentId":"<tech-lead-id>", "assigneeUserId":null}`
- **For a plan approval:** `{"status":"todo", "assigneeAgentId":"<tech-lead-id>", "assigneeUserId":null}` (plan already written by TL; approval unblocks task-orchestration)
- **For an ADR approval:** `{"status":"done", "assigneeAgentId":null}` and edit the title to add `[Accepted]` if following the ADR convention.

### Rejecting with findings

Post a comment naming the specific issues. Cite Prime Directive numbers when applicable (so the CEO learns the pattern):

```
Rejecting. Findings:
1. PD-3 (Data flows have shadow paths) — the spec's search flow covers happy path only; 
   missing shadow paths for empty results and upstream-API failure.
2. Scope is compound — this spec covers landing pages AND the blog. Split into two 
   features so the Tech Lead plan can be focused.
```

PATCH back to the original author (PM for spec, TL for plan):
- `{"status":"todo", "assigneeAgentId":"<pm-or-tl-id>", "assigneeUserId":null}`

## Anti-patterns — things you might do by accident

1. **Compound brief submitted anyway.** You know it's compound but submit because "the CEO will split it." Don't — you're training yourself to rely on a rejection, and it burns a full heartbeat. Split before you submit.
2. **Assigning directly to the CTO.** The CTO's `AGENTS.md` will decline feature-shaped work and route back to the CEO. You wasted a heartbeat. Always assign to the CEO for triage.
3. **Writing a Strategy: issue that's really a Feature:.** If you have the scope defined ("here's exactly what to build"), it's a Feature, not a Strategy. Strategy is for goal-with-unclear-artifacts.
4. **Submitting a Feature: with no acceptance criteria.** PMs need testable success criteria to write a spec. If you can't state them, the issue is a Strategy (the CEO decomposes) or a Feature that needs board-Q rounds (the PM asks via brainstorming).
5. **Ignoring a Board-Q from your agents.** The pipeline blocks on it. If you don't want to answer, answer with "deferred — pick reasonable default." Don't leave it unanswered for days.
6. **Hiring before the need is concrete.** Don't pre-hire. Wait until the CEO hits a blocker that requires a new role. Over-hiring wastes budget and produces agents with no work.
7. **Merging a PR without reviewing the final-review comment.** The Reviewer's final comment on an `in_review` feature issue is your gate; read it before merging.

## Rollback and emergency stops

- **Pause an agent:** `POST /api/agents/<id>/pause` — stops future heartbeats until resumed. Use if an agent is in a loop or burning budget on wrong work.
- **Unassign an issue:** PATCH `{"assigneeAgentId":null}` — stops the issue from waking anyone.
- **Cancel an issue:** PATCH `{"status":"cancelled"}` — terminal, agents don't wake on it.
- **Kill a stuck heartbeat:** SSH to the host, `docker exec paperclip ...` to find the process (ask the CTO / operator skill for the specific command).

## First-run checklist for a new company

1. Create the company in the UI (`POST /api/companies` if via API).
2. Create the CEO agent with `role: "ceo"` via UI. Ensure `permissions.canCreateAgents: true`.
3. Create the CTO agent via UI. Name doesn't matter; role can be `engineer` or `default`.
4. Run `scripts/install-paperclipowers-to-company.sh` with `CEO_AGENT_ID` + `CTO_AGENT_ID` + `COMPANY_ID`.
5. In the UI, set CEO and CTO desiredSkills per `docs/INSTALL-TO-COMPANY.md`. **CTO gets ONLY board-layer skills** — no `writing-plans`, `task-orchestration`, `brainstorming`, `code-review`. Those would contradict the CTO's AGENTS.md.
6. Create your first `Strategy:` issue. The CEO will triage on its next heartbeat.
7. Watch for `Mode: ...` comments. If the CEO is getting the framing wrong, check that `pipeline-dispatcher` and the CEO supplemental files are actually installed (`docs/INSTALL-TO-COMPANY.md § Troubleshooting`).

## Where to go from here

- `docs/INSTALL-TO-COMPANY.md` — mechanical installer instructions.
- `skills-paperclip/ceo/` — the files the CEO reads. Worth skimming once.
- `skills-paperclip/cto/` — the files the CTO reads.
- `skills-paperclip/pipeline-dispatcher/SKILL.md` — the role matrix for pipeline agents.
- `skills-paperclip/brainstorming/SKILL.md`, `writing-plans/SKILL.md`, `task-orchestration/SKILL.md`, `code-review/SKILL.md`, `test-driven-development/SKILL.md` — the pipeline skills.
