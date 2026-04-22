# Installing paperclipowers on a Paperclip company

This guide sets up a new Paperclip company to use the paperclipowers board-layer (CEO + CTO) and the pipeline skill library (PM → Tech Lead → Engineer → Reviewer → Designer).

There are two paths: the **automated installer** (recommended) and the **manual procedure** (for understanding or edge cases).

## Prerequisites

1. **A running Paperclip instance** with a company already created, either locally (`localhost:3100`) or on your own host (typical Synology NAS setup: `http://<nas>:3100`).
2. **CEO agent exists.** The installer does NOT create agents — agent creation goes through Paperclip's board-approval flow and is done via the UI or `paperclip-create-agent` skill. Create the CEO first (role=ceo), then run the installer.
3. **CTO agent (optional).** If you want the board layer, create the CTO with a UI-mutable name (installer doesn't care about role, it uses the agent id).
4. **Paperclip session cookie.** Obtain from DevTools → Application → Cookies → `better-auth.session_token` after logging in.
5. **SSH access to the Paperclip host.** The installer writes files to the bind-mounted instructions directory; it does not go through an API. Configure an ssh alias in `~/.ssh/config` (typical: `Host nas`).

## Automated installer

```bash
export PCLIP="http://192.168.0.104:3100"                       # or http://localhost:3100
export PCLIP_COOKIE="better-auth.session_token=<value>"
export COMPANY_ID="<uuid>"
export CEO_AGENT_ID="<uuid>"
export CTO_AGENT_ID="<uuid>"                                   # optional — omit to skip CTO
export NAS_HOST="nas"                                          # ssh alias (default: nas)
export NAS_DATA_ROOT="/volume2/docker/paperclip/data"          # host path bound to /paperclip
export INSTANCE="default"                                      # Paperclip instance (default: default)

bash scripts/install-paperclipowers-to-company.sh
```

A dry run shows what it would do without mutating anything:

```bash
DRY_RUN=1 bash scripts/install-paperclipowers-to-company.sh
```

### What the installer does

1. Imports the paperclipowers skill library from GitHub (`POST /api/companies/:id/skills/import`).
2. Copies `CEO-COGNITIVE-PATTERNS.md`, `CEO-PRIME-DIRECTIVES.md`, `CEO-TRIAGE-MODES.md` into the CEO's instructions dir. Backs up the existing `AGENTS.md` first. Appends 3 reference bullets to `AGENTS.md` if not already present (idempotent).
3. If `CTO_AGENT_ID` is set: creates the CTO instructions dir, copies 5 bundle files (`AGENTS.md`, `SOUL.md`, `HEARTBEAT.md`, `TOOLS.md`, `ADR-TEMPLATE.md`), then PATCHes the CTO's `adapterConfig.instructionsFilePath` to the new `AGENTS.md`. Any pre-existing CTO AGENTS.md is backed up.
4. Verifies each step and prints the final directory contents + the AGENTS.md tail.

### What the installer does NOT do

- Create agents (use the UI or `paperclip-create-agent`).
- Modify the CEO's or CTO's `desiredSkills` — after install, you must set these via the UI:
  - CEO: add `henriquerferrer/paperclipowers/pipeline-dispatcher` (so when the CEO delegates to PM/Tech-Lead/Engineer, it uses the pipeline vocabulary).
  - CTO: add `pipeline-dispatcher`. **Do NOT** add `writing-plans` or `task-orchestration` — those are Tech Lead skills. CTO writes ADRs, not plans.
- Create the pipeline agents (PM, Tech Lead, Engineer, Reviewer, Designer). Those are created on-demand when the CEO/CTO hires them via `paperclip-create-agent` inside a heartbeat.

### Rollback

The installer creates timestamped backups of any existing `AGENTS.md` it modifies (e.g., `AGENTS.md.backup-20260421T174644Z`). To undo:

1. Restore the backup: `mv AGENTS.md.backup-<TS> AGENTS.md`
2. Delete the copied files (`CEO-*.md` on the CEO side; all 5 bundle files on the CTO side).
3. PATCH the CTO's `instructionsFilePath` back to its previous value (or null if it was unset).

## Manual procedure

If you'd rather understand what's happening, the runbooks are:

- `skills-paperclip/ceo/apply.md` — how to layer the 3 supplemental files onto an existing CEO.
- `skills-paperclip/cto/apply.md` — how to bootstrap a CTO's instructions dir from scratch and PATCH the adapter config.

Both runbooks explain the why and the rollback for a single agent.

## After install

### Set desiredSkills for CEO and CTO

In the Paperclip UI → Company → Agents → (CEO or CTO) → Skills:

**CEO desiredSkills:**
- `paperclipai/paperclip/paperclip`
- `paperclipai/paperclip/paperclip-create-agent`
- `paperclipai/paperclip/para-memory-files`
- `henriquerferrer/paperclipowers/pipeline-dispatcher`

**CTO desiredSkills:**
- `paperclipai/paperclip/paperclip`
- `paperclipai/paperclip/paperclip-create-agent`
- `paperclipai/paperclip/para-memory-files`
- `henriquerferrer/paperclipowers/pipeline-dispatcher`

The CTO should NOT have `writing-plans`, `task-orchestration`, `test-driven-development`, `brainstorming`, or `code-review`. Those are pipeline-role skills. The CTO's role guardrails in `AGENTS.md` will conflict with skills that tell it to write plans or specs.

### Hire the pipeline roles as you need them

Don't hire speculatively. When the CEO receives the first feature-shaped issue, the pipeline needs:

- 1 PM
- 1 Tech Lead (name MUST contain `tech-lead`)
- 1 Engineer
- 1 Reviewer
- 1 Designer (optional; only if polish is in scope)

Each hire happens via `paperclip-create-agent` inside a CEO or CTO heartbeat, with its own desiredSkills per the role matrix in `skills-paperclip/pipeline-dispatcher/SKILL.md`.

### First-run validation

On the CEO's next heartbeat (scheduled or triggered by a new board issue), watch for:

- A comment starting with `Mode: …` on any new board-assigned issue (from the triage-modes skill).
- Reference to a Prime Directive by number when the CEO rejects a proposal.
- The CEO declining to write specs/plans/code and delegating explicitly.

On the CTO's next heartbeat:

- The CTO should decline any feature-shaped issue that lands on it (pipeline-role work) and PATCH back to the CEO.
- The CTO should accept issues with `ADR-` prefix in the title and author the ADR body to the issue's `spec` document.

## Troubleshooting

**"CEO instructions dir missing"** — The CEO was created but never given a seeded bundle. Paperclip seeds `AGENTS.md`/`SOUL.md`/`HEARTBEAT.md`/`TOOLS.md` on agent creation from `server/src/onboarding-assets/ceo/`. If this is missing, the agent was likely created with `role=default` instead of `role=ceo`. Delete and recreate with role=ceo, then run the installer.

**Skill import returns "Skill not found"** — The default `source` URL points at `/skills-paperclip` (plural). Paperclip's import parser treats `owner/repo/X` as a single-skill lookup named `X`; the full GitHub tree URL is the multi-skill form. See `skills-paperclip/paperclip-ops`-equivalent doc on the import quirk if you hit this.

**CTO PATCH returns 400 on instructionsFilePath** — The path must be the *container-facing* path (`/paperclip/instances/...`), not the NAS host path (`/volume2/...`). The installer handles this automatically; if doing it manually, remember the distinction.

**SCP fails with "subsystem request failed"** — Synology DSM doesn't expose SFTP by default. The installer streams via `cat | ssh cat > …` to avoid this. If doing manual copies, use the same idiom.
