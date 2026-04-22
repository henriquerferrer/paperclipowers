# CEO Triage Modes

When the board assigns you a new issue — or you pick up a stale one — triage it in five steps before delegating anything:

1. Classify by title prefix (§ Step 1).
2. Check for compound brief — if yes, reject and split (§ Step 2).
3. Pick a mode from EXPANSION / SELECTIVE EXPANSION / HOLD / REDUCTION (§ Step 3).
4. Discover applicable ADRs so downstream roles inherit invariants (§ Step 4).
5. Post the triage comment with all of the above (§ Step 5).

Every downstream delegation inherits the mode, the ADRs, and the constraints they imply.

Adapted from gstack's `plan-ceo-review` mode framework.

## Step 1: Classify by title prefix

Every board-authored or CEO-authored issue should have one of five title prefixes. They signal the issue's shape and default assignee at a glance.

| Prefix | Shape | Default assignee | Example |
|---|---|---|---|
| `Strategy:` | Direction, no defined scope yet. CEO decomposes into sub-issues. | CEO | `Strategy: Stand up Higeia's public marketing surface` |
| `Feature:` | One shippable surface, one spec. PM drives through pipeline. | PM (or CEO if PM doesn't exist yet) | `Feature: Indexable SEO landing pages for top-20 PT queries` |
| `ADR:` | One technical decision. CTO authors; board gates. | CTO | `ADR-0001: Stack + hosting architecture` |
| `Hire:` | Agent creation request with role/skills defined. | CEO | `Hire: Product Manager for marketing surface` |
| `Board-Q:` | A question the board needs to answer (not the other way around). | Board user via `assigneeUserId` | `Board-Q: Payment provider + sliding-scale quota policy` |

**If the incoming issue has no prefix,** infer the kind from the body and proceed. If the kind is genuinely ambiguous, that's a smell — post a clarification comment to the board asking them to restate with a prefix, and exit heartbeat.

**If the prefix contradicts the body** (e.g., title says `Feature:` but the body asks for architecture + compliance + hires), that's a compound brief — see § Step 2.

## Step 2: Check for compound brief — and reject if needed

A compound brief is an issue whose body asks for more than one artifact type. These produce hybrid plan docs that no single role can revise cleanly. They're the #1 cause of pipeline stalls.

Detect a compound brief by scanning the body for requests that span artifact kinds:

- architecture decision + product spec → ADR + Feature → two issues
- product spec + implementation plan → spec authored by PM, plan authored by Tech Lead → one feature issue, two pipeline phases, not one body
- feature + hire request → Feature + Hire → two issues
- any combination of "tell me X and Y and Z" where X, Y, Z belong to different roles

**If the issue is compound, post this comment and do NOT delegate:**

```
Mode: REJECT — compound brief

This issue asks for <N> different artifact kinds (<X, Y, Z>). Each belongs to a 
different role or ADR. Splitting into:

- <replacement-1> — <role>
- <replacement-2> — <role>
- <replacement-3> — <role>

I'm creating the replacement issues and closing this one with a cross-link to them.
```

Then actually create the replacements (one `POST /api/companies/:id/issues` per replacement), comment each replacement's id back on the original, PATCH the original to `status: "done"` with a final comment listing all replacements. Do NOT delegate the compound issue to any role.

**HIG-4 was exactly this shape.** A single issue titled "CTO onboarding" asked for stack architecture + product sequencing + staffing plan + compliance matrix + board questions — five artifacts across four roles. The right response is to split, not to delegate.

## Step 3: Pick a mode

For non-compound issues, pick one of four scope-framing modes. The mode shapes how the PM/Tech Lead/Engineer treat scope downstream.

**SCOPE EXPANSION.** You are building for ambition. Envision the 10x version of the ask. Push scope up. Ask "what would make this 10x better for 2x the effort?" Each expansion is a separate decision — surface it in comments, let the board opt in before you delegate.

**SELECTIVE EXPANSION.** Hold the original scope as the floor — make it bulletproof. But surface expansion opportunities individually as comments so the board can cherry-pick. Neutral recommendation posture; state the opportunity, the effort estimate, the risk, let the board decide. Accepted expansions become part of the delegated spec; rejected go to a "Not in scope" section.

**HOLD SCOPE.** The ask is well-defined. Your job is to make it bulletproof — catch every failure mode, test every edge case, ensure observability. Do not silently reduce OR expand. This is the default when scope is already scoped.

**SCOPE REDUCTION.** You are a surgeon. Find the minimum viable version that achieves the core outcome. Cut everything else. Be ruthless. Use this when runway is tight, a deadline is hard, or the board explicitly asked for a minimum version.

### Mode selection table

| Signal | Mode |
|---|---|
| Board said "think big" / "what's the ambitious version" | EXPANSION |
| Board said "ship it" / "minimum version" / runway tight / compliance deadline | REDUCTION |
| Issue has explicit acceptance criteria; scope is clear | HOLD |
| Issue is directional but not fully scoped; expansion opportunities exist | SELECTIVE EXPANSION |
| Wartime posture (production incident, compliance deadline, funding pressure) | REDUCTION — unless the incident itself is expansion-shaped |
| Unclear | HOLD (default). Correct output; EXPANSION and REDUCTION require explicit evidence. |

## Step 4: Discover applicable ADRs

Before delegating, list every accepted ADR that applies to this issue. Downstream roles inherit invariants through your delegation comment — they shouldn't re-search ADRs themselves on every new feature.

Query accepted ADRs:

```bash
pc "$PCLIP/api/companies/$COMPANY_ID/issues?limit=200" | python3 -c "
import sys, json, re
rows = json.load(sys.stdin)
issues = rows if isinstance(rows, list) else rows.get('issues', [])
for i in issues:
    title = i.get('title', '')
    if re.match(r'ADR-\d+', title) and i.get('status') == 'done':
        print(f'{i[\"identifier\"]} {title}')"
```

For each ADR, judge: does any invariant it establishes touch this feature? Skim the ADR body (`GET /api/issues/<id>/documents/spec`) if the title alone is ambiguous. In the triage comment, list only the ADRs that actually apply — one line each, with the invariant that matters. A PM reading your comment should know exactly what constraints to respect in the spec, without opening any ADR.

If no ADRs apply, write `ADRs: none applicable` explicitly. This tells the PM the CEO checked and none constrain the feature; it's different from the CEO forgetting to check.

## Step 5: Communicate — the triage-comment template

Every triage comment (for accepted, non-compound issues) opens with:

```
Mode: <EXPANSION | SELECTIVE EXPANSION | HOLD | REDUCTION>
Why: <one sentence>
ADRs that apply:
- <HIG-N> <ADR-XXXX title> — <the one invariant that matters for this feature>
- <HIG-M> <ADR-YYYY title> — <invariant>
(or: `ADRs: none applicable`)
Routing: <delegated to @<agent-name> | hold for spec | needs CTO first | needs board clarification>
```

Example (accepted feature, HOLD mode):

```
Mode: HOLD
Why: acceptance criteria from board are specific; this is a well-defined feature.
ADRs that apply:
- HIG-6 ADR-0001 Stack + hosting — spec must assume Next.js + Payload + Postgres
- HIG-7 ADR-0002 Compliance schema — crisis-banner component is global, not per-page
Routing: delegated to @<pm-name>
```

Another (directional ask, SELECTIVE EXPANSION):

```
Mode: SELECTIVE EXPANSION
Why: baseline ask is a booking portal; several high-leverage expansions exist that the 
     board may want to choose from.
ADRs that apply:
- HIG-7 ADR-0002 Compliance schema — sliding-scale quota per week is required
- HIG-8 ADR-0003 Cost boundaries — Neon Free DB limit is 500MB; design pagination early
Routing: hold for CTO technical framing before PM; I will surface expansions as separate 
         comments for the board to opt into.
```

## Changing modes

If the board reframes the ask, or new constraints surface (runway, incident, regulatory update), change the mode explicitly:

```
Mode change: HOLD → REDUCTION.
Why: runway constraint surfaced in yesterday's board Q&A; cutting to MVP scope.
Routing: comment on @<pm-name>'s existing spec asking for a reduced version.
```

Never silently drift. A report working in HOLD mode will react differently from one in REDUCTION; ambiguity wastes their heartbeat.

## Critical rule

Once you set a mode, commit to it. Don't silently drift. If EXPANSION is selected, don't argue for less work in the next heartbeat. If REDUCTION is selected, don't sneak scope back in. Raise concerns once in the triage comment — after that, execute the chosen mode faithfully until you formally change it.

## Anti-patterns

- **Delegating a compound brief.** If the body asks for multiple artifact kinds, split before delegating. The pipeline can't produce a coherent spec from a multi-artifact brief; attempting it produces HIG-4-shaped hybrid plans.
- **Mode declared, no routing.** If you set a mode and don't also commit a routing decision, the issue stalls. Include routing in the same comment.
- **Mode contradicts delegation.** Setting SCOPE REDUCTION then delegating a spec with six features in it breaks the contract. The delegation comment should reflect the mode.
- **Silent mode change.** Changing from HOLD to EXPANSION without posting the mode change leaves the PM working to the wrong target. Always post the change explicitly.
- **Skipping ADR discovery.** Delegating without listing applicable ADRs forces the PM to re-search on every feature — slow, error-prone, easy to miss an ADR that matters. Always include the ADR list or `ADRs: none applicable`.
- **Accepting a feature issue titled with no prefix.** If the prefix is missing and the issue kind is genuinely ambiguous, post a clarification comment asking the board to restate with a prefix. Don't guess.
