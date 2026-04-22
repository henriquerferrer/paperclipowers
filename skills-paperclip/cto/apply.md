# Applying the Paperclipowers CTO Bundle

This directory contains a full CTO instructions bundle. Unlike the CEO supplement, there is no Paperclip-core default for CTO — these files define the role from scratch on a single agent.

## Files

| File | Role |
|---|---|
| `AGENTS.md` | Role framing, delegation rules, what the CTO does and does not do |
| `SOUL.md` | CTO posture and voice |
| `HEARTBEAT.md` | Per-heartbeat checklist |
| `TOOLS.md` | Tools reference stub |
| `ADR-TEMPLATE.md` | ADR issue template and lifecycle |

## Procedure

Let `INSTRUCTIONS_DIR` be the CTO agent's instructions directory. On a Synology NAS running Paperclip via Docker with bind-mount `/volume2/docker/paperclip/data` → `/paperclip` in-container, the host path is:

```
/volume2/docker/paperclip/data/instances/<instance>/companies/<company-id>/agents/<cto-agent-id>/instructions/
```

The path the Paperclip adapter needs is the container path (`/paperclip/instances/<instance>/companies/<company-id>/agents/<cto-agent-id>/instructions/AGENTS.md`), not the host path.

1. Create `$INSTRUCTIONS_DIR` on the NAS host if it doesn't exist.
2. Copy all five files in this directory (`AGENTS.md`, `SOUL.md`, `HEARTBEAT.md`, `TOOLS.md`, `ADR-TEMPLATE.md`) into `$INSTRUCTIONS_DIR`.
3. PATCH the CTO agent's `adapterConfig.instructionsFilePath` to the **container path** of `AGENTS.md`:

   ```bash
   cat > /tmp/cto-instructions.json <<'EOF'
   {"adapterConfig":{"instructionsFilePath":"/paperclip/instances/<instance>/companies/<company-id>/agents/<cto-agent-id>/instructions/AGENTS.md"}}
   EOF
   pc -H "Content-Type: application/json" --data-binary @/tmp/cto-instructions.json \
      -X PATCH "$PCLIP/api/agents/<cto-agent-id>"
   ```

4. Verify the PATCH: `pc "$PCLIP/api/agents/<cto-agent-id>"` should show `adapterConfig.instructionsFilePath` set to the path from step 3.

5. On the next heartbeat, confirm the CTO references `./HEARTBEAT.md`, `./ADR-TEMPLATE.md`, or the delegation rules in a comment.

## Board-layer skills

The CTO's `desiredSkills` should include:

- `paperclipai/paperclip/paperclip` -- base Paperclip API skill
- `paperclipai/paperclip/paperclip-create-agent` -- for hires
- `paperclipai/paperclip/para-memory-files` -- memory and daily notes

It should NOT include the pipeline-role skills (`writing-plans`, `task-orchestration`, `test-driven-development`). Those belong to Tech Leads, Engineers, and Reviewers. If you inherit a CTO agent with pipeline-role skills set, remove them before applying this bundle — the role guardrails in `AGENTS.md` will conflict with skills that tell the CTO to write plans.

## Rollback

- PATCH `adapterConfig.instructionsFilePath` back to `null` (or its prior value) — the CTO runs with an empty system prompt supplement, same as before the apply.
- Optionally delete the files in `$INSTRUCTIONS_DIR`.
