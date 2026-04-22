# ADR Template

An Architecture Decision Record is a Paperclip issue with a structured description and a `spec`-keyed document carrying the ADR body. Title format: `ADR-NNNN: <one-line decision>`. Written by the CTO, reviewed by the CEO.

## Issue description template

Use this as the issue's `description` field when creating the ADR:

```markdown
# ADR-NNNN: <decision>

## Status

Proposed | Accepted | Superseded by [ADR-XXXX]

## Context

2-5 paragraphs. What is the situation forcing this decision? What was true before? What changed? What constraints apply (compliance, stack coherence, team skills, budget)?

## Decision

1-3 paragraphs. What did we decide? Be specific — name the technology, the version, the pattern, the boundary. State the decision in present tense ("We use Postgres 17 for all transactional state"), not future.

## Alternatives Considered

For each alternative the CTO seriously evaluated:

- **Name.** Short description.
- **Why not chosen.** Specific, not dismissive. "Rejected" is not a reason; "rejected because operating cost at our scale is 3x Postgres for equivalent throughput" is.

## Consequences

- **Positive.** Capabilities this unlocks.
- **Negative.** Capabilities this forecloses or complicates.
- **Neutral.** Things that stay the same but are now coupled to this decision.

## Compliance / Security / Observability

If applicable, how this ADR affects compliance posture, security surface, or observability story. Empty if not applicable.

## Revisit Criteria

Under what future circumstances should this ADR be re-examined? "Never" is a valid answer; prefer a concrete trigger (load threshold, vendor deprecation, regulatory change) over "as needed."
```

## Lifecycle

1. **Propose.** CTO creates the ADR issue with `status: "todo"`, assignee self, title `ADR-NNNN: <decision>`. Write the structured description directly. Write the full ADR body to the `spec` document (`PUT /api/issues/{id}/documents/spec`).
2. **Review.** PATCH to `in_review` and assign to the CEO in ONE call.
3. **Accept or revise.** CEO reads, applies Prime Directives, either approves (PATCH `status: "done"`, update title prefix to `ADR-NNNN [Accepted]:`) or rejects with findings (PATCH back to CTO with `status: "todo"`).
4. **Supersede — never edit.** When a decision changes, write ADR-(N+k) with a `Supersedes: ADR-NNNN` line in its description. Update ADR-NNNN's spec-doc Status block to `Superseded by ADR-(N+k)`. The original ADR remains in `done` status with the updated Status line — the body is not mutated.

## Numbering

Until Paperclip supports per-prefix identifier sequences, ADR numbers live in the issue title. On each new ADR, query existing ADRs and increment:

```bash
# Inside a CTO heartbeat. Assumes you have $COMPANY_ID and $PCLIP set.
pc "$PCLIP/api/companies/$COMPANY_ID/issues?limit=200" | python3 -c "
import sys, json, re
rows = json.load(sys.stdin)
issues = rows if isinstance(rows, list) else rows.get('issues', [])
highest = 0
for i in issues:
    m = re.match(r'ADR-(\d+)', i.get('title', ''))
    if m:
        highest = max(highest, int(m.group(1)))
print(f'{highest + 1:04d}')"
```

Zero-pad to 4 digits (ADR-0001, ADR-0042). Sorting alphabetically also sorts numerically up to ADR-9999 — by that point the company has bigger problems.

## When the CTO should NOT write an ADR

- A feature choice the PM can make in the spec (URL structure, copy, button placement).
- A code-level decision the Tech Lead can make in the plan (which test framework to use, which utility library).
- A code-level decision the Engineer can make in implementation (which loop variant, which abstraction).

ADRs are for decisions that bind multiple features, cross features and non-features (compliance, ops, vendor choices), or commit the company for 6+ months. Below that threshold, write nothing — let the PM/Tech Lead/Engineer decide.

## Examples of valid ADR topics

- Stack choices: framework, language, runtime, hosting region.
- Data model invariants: a required field on a shared schema (e.g., clinician-directory: `oppLicenseNumber` + `verifiedAt` are non-null).
- Compliance boundaries: what data crosses which boundaries under what conditions.
- Vendor commitments: payment provider, telehealth vendor, analytics vendor, email provider.
- Identity model: how users, agents, and external accounts relate.
- Observability baseline: what every service logs, alerts, traces.

## Examples of non-ADR-worthy

- Button copy, icon choice, URL slug format — spec-level.
- Which `map()` vs `for`, which helper library — plan- or code-level.
- One-off bug fixes.
- Personnel decisions — CEO's remit, not an ADR.
