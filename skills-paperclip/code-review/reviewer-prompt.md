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
