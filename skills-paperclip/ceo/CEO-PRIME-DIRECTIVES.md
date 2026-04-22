# CEO Prime Directives

Review criteria for every proposal that lands on your desk — a PM spec, a CTO ADR, a Tech Lead plan, a report's recommendation. Apply these when deciding whether to approve, reject with findings, or request revision.

Adapted from gstack's `plan-ceo-review` Prime Directives.

## The 9 directives

1. **Zero silent failures.** Every failure mode in the proposal must be visible — to the system, to a user, or to an alerting surface. If a failure can happen silently, reject with findings citing this directive.

2. **Every error has a name.** A proposal that says "handle errors" is not specific enough. Ask: which exception class, what triggers it, what catches it, what the user sees, whether there's a test for it. Catch-all handlers (`catch Exception`, `rescue StandardError`, bare `try/except`) are a code smell — flag them at spec or plan review.

3. **Data flows have shadow paths.** Every data flow has a happy path plus three shadow paths: null input, empty/zero-length input, upstream error. The proposal must trace all four for every new flow. If the doc only addresses the happy path, reject with findings.

4. **Interactions have edge cases.** Every user-visible interaction has edge cases: double-click, navigate-away mid-action, slow connection, stale state, back button. Proposals touching user-facing surfaces must address them in the spec's `## Edge Cases` section or equivalent.

5. **Observability is scope, not afterthought.** New dashboards, alerts, and runbooks are first-class deliverables. If a proposal ships a feature without an observability plan (what to log, what to alert on, how an on-call engineer diagnoses a regression), require one before approval.

6. **Diagrams are not optional for non-trivial flows.** Any new data flow, state machine, processing pipeline, or decision tree should have an ASCII diagram in the doc. Ask for one if it's missing. A diagram a reader can scan in 30 seconds outperforms three paragraphs of prose.

7. **Everything deferred must be written down.** Vague intentions are lies. Deferred work becomes a backlog issue with explicit parentage to the proposal. No "we'll handle it later" without a linked issue id. If a spec or plan contains "TODO" without a linked issue, reject with findings.

8. **Optimize for the 6-month future, not just today.** Proposals that solve today's problem at the cost of next quarter's nightmare must call out the trade explicitly. When in doubt, ask: "where does this constrain us in six months?" If the author can't answer, they haven't thought it through.

9. **Permission to say 'scrap it, do this instead.'** If a proposal is fundamentally wrong — not incrementally fixable — reject it and propose the alternative in the rejection comment. The cost of an extra spec cycle is a fraction of the cost of implementing the wrong thing. Don't let politeness ship bad code.

## How to use

When you reject a proposal with findings, cite the directive number in the rejection comment: `Rejected. Prime Directive 3 — the spec's data-flow section covers the happy path only; shadow paths for empty search results and upstream-API failures are missing.` This teaches the pattern. Over time, your reports internalize the directives and self-gate before proposals reach you.

Not every directive applies to every proposal. ADRs on pure architecture don't have user-facing edge cases. PM specs on internal tooling may not need observability sections. Use judgment — but err on the side of invoking them; catching a gap at review is cheaper than at production.
