# Applying the Paperclipowers CEO Supplement

This directory contains three supplemental files that augment Paperclip's default CEO onboarding bundle. Applying them is additive only — no existing file is modified, except to append three bullets to the `## References` section of `AGENTS.md`.

## What gets added

| File | Role |
|---|---|
| `CEO-COGNITIVE-PATTERNS.md` | 18 strategic-thinking instincts |
| `CEO-PRIME-DIRECTIVES.md` | 9 review criteria for proposals |
| `CEO-TRIAGE-MODES.md` | EXPANSION / SELECTIVE / HOLD / REDUCTION framework |

## Procedure

Let `INSTRUCTIONS_DIR` be the CEO agent's instructions directory. On a Synology NAS running Paperclip via Docker with bind-mount `/volume2/docker/paperclip/data` → `/paperclip` in-container, the host path is:

```
/volume2/docker/paperclip/data/instances/<instance>/companies/<company-id>/agents/<ceo-agent-id>/instructions/
```

1. Copy `CEO-COGNITIVE-PATTERNS.md`, `CEO-PRIME-DIRECTIVES.md`, `CEO-TRIAGE-MODES.md` into `$INSTRUCTIONS_DIR`.
2. Append the three bullets from `REFERENCES-APPEND.md` to the bottom of `$INSTRUCTIONS_DIR/AGENTS.md`. Do not modify any existing lines.
3. No Paperclip API change is required. The CEO reads the new files on its next heartbeat via the existing `## References` mechanism in `AGENTS.md`.

## Verification

- After apply, `ls $INSTRUCTIONS_DIR` should show the original 4 files (`AGENTS.md`, `SOUL.md`, `HEARTBEAT.md`, `TOOLS.md`) plus the 3 new files and any existing `memory/` subdirectory.
- The CEO's `adapterConfig.instructionsFilePath` still points to `AGENTS.md`; this is unchanged.
- On the next heartbeat, confirm the CEO references one of the new sections — the triage mode, a cognitive pattern, or a prime directive — in a triage or review comment.

## Rollback

Delete the 3 new files from `$INSTRUCTIONS_DIR` and remove the 3 appended bullets from `AGENTS.md`. The result is byte-identical to the pre-apply state.

## Why additive-only

- Paperclip's default CEO bundle ships from upstream `paperclipai/paperclip`. Editing the defaults in-place in a Paperclip instance risks divergence when upstream updates the bundle.
- Additive layering via References preserves a clean upgrade path: if upstream ships an improved `SOUL.md`, you can accept the upgrade without losing the paperclipowers supplement.
- The three supplemental files capture content the default bundle omits (strategic-thinking instincts, review criteria, triage mode framework) without overlapping what the default covers (delegation rules, heartbeat procedure, voice).
