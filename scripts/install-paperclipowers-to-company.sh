#!/usr/bin/env bash
#
# install-paperclipowers-to-company.sh
#
# Install the paperclipowers board-layer bundles + skill library onto a Paperclip company.
# Idempotent: safe to re-run. Existing files are backed up before any append.
#
# Prerequisites:
#   - The CEO and (optionally) CTO agents already exist on the target company.
#     Agent creation requires UI/CLI action that honours the company's board-approval
#     policy — this script does NOT create agents.
#   - SSH access to the Paperclip host (bind-mount host) via an ssh_config alias.
#   - Paperclip session cookie obtained from DevTools (better-auth.session_token).
#
# Environment variables (required unless noted):
#   PCLIP                 Paperclip base URL, e.g. http://192.168.0.104:3100
#   PCLIP_COOKIE          "better-auth.session_token=<value>"
#   COMPANY_ID            UUID of the target company
#   CEO_AGENT_ID          UUID of the CEO agent (role=ceo)
#   NAS_HOST              SSH alias for the Paperclip host (default: nas)
#   NAS_DATA_ROOT         host path bound to /paperclip in the container
#                         (default: /volume2/docker/paperclip/data)
#   INSTANCE              Paperclip instance name (default: default)
#   CTO_AGENT_ID          UUID of the CTO agent. Optional — if unset, skips CTO install.
#   SKILLS_GIT_URL        GitHub tree URL for the paperclipowers skill library
#                         (default: https://github.com/henriquerferrer/paperclipowers/tree/main/skills-paperclip)
#   DRY_RUN               If "1", prints actions without executing mutations.
#
# Exit codes:
#   0   success (or dry-run complete)
#   1   misuse / missing prerequisite
#   2   API error
#   3   filesystem error on the NAS
#
# Rollback:
#   Each run creates timestamped backups of any modified AGENTS.md alongside the original.
#   To undo: restore the .backup-* file, delete the copied CEO-*.md / cto/*.md files,
#   and PATCH the CTO's adapterConfig.instructionsFilePath back to its prior value.

set -euo pipefail

# -------- config / defaults --------
NAS_HOST="${NAS_HOST:-nas}"
NAS_DATA_ROOT="${NAS_DATA_ROOT:-/volume2/docker/paperclip/data}"
INSTANCE="${INSTANCE:-default}"
SKILLS_GIT_URL="${SKILLS_GIT_URL:-https://github.com/henriquerferrer/paperclipowers/tree/main/skills-paperclip}"
DRY_RUN="${DRY_RUN:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CEO_LOCAL_DIR="$REPO_ROOT/skills-paperclip/ceo"
CTO_LOCAL_DIR="$REPO_ROOT/skills-paperclip/cto"

TS="$(date -u +%Y%m%dT%H%M%SZ)"

# -------- helpers --------
die() { echo "ERROR: $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found in PATH"; }

say() { echo "==> $*"; }

dry_prefix() { [[ "$DRY_RUN" = "1" ]] && echo "[DRY-RUN] " || echo ""; }

# Paperclip API helper.
# Usage: api METHOD PATH [JSON_BODY_FILE]
# Relies on PCLIP + PCLIP_COOKIE.
api() {
  local method="$1" path="$2" body_file="${3:-}"
  local url="$PCLIP$path"
  local -a args=(-sS -H "Cookie: $PCLIP_COOKIE" -H "Origin: $PCLIP")
  case "$method" in
    GET|HEAD) ;;
    *)
      args+=(-H "Content-Type: application/json")
      if [[ -n "$body_file" ]]; then args+=(--data-binary "@$body_file"); fi
      args+=(-X "$method")
      ;;
  esac
  if [[ "$DRY_RUN" = "1" && "$method" != "GET" && "$method" != "HEAD" ]]; then
    echo "[DRY-RUN] $method $url${body_file:+  <- $body_file}"
    [[ -n "$body_file" ]] && cat "$body_file"
    return 0
  fi
  curl "${args[@]}" "$url"
}

# ssh helper that respects DRY_RUN for mutating operations.
nas_exec() {
  local cmd="$1"
  local mutating="${2:-1}"
  if [[ "$DRY_RUN" = "1" && "$mutating" = "1" ]]; then
    echo "[DRY-RUN] ssh $NAS_HOST \"$cmd\""
    return 0
  fi
  ssh "$NAS_HOST" "$cmd"
}

# Stream a local file to a NAS path via ssh (cat > remote).
# Synology DSM doesn't expose SFTP by default, so scp fails with "subsystem request failed".
nas_put() {
  local local_path="$1" remote_path="$2"
  [[ -f "$local_path" ]] || die "local file not found: $local_path"
  if [[ "$DRY_RUN" = "1" ]]; then
    echo "[DRY-RUN] cat $local_path | ssh $NAS_HOST 'cat > $remote_path'"
    return 0
  fi
  cat "$local_path" | ssh "$NAS_HOST" "cat > '$remote_path'"
}

# -------- preflight --------
need curl
need ssh
need python3

[[ -n "${PCLIP:-}" ]] || die "PCLIP env var is required (e.g. http://192.168.0.104:3100)"
[[ -n "${PCLIP_COOKIE:-}" ]] || die "PCLIP_COOKIE env var is required (better-auth.session_token=...)"
[[ -n "${COMPANY_ID:-}" ]] || die "COMPANY_ID env var is required"
[[ -n "${CEO_AGENT_ID:-}" ]] || die "CEO_AGENT_ID env var is required"

[[ -d "$CEO_LOCAL_DIR" ]] || die "CEO supplemental dir not found at $CEO_LOCAL_DIR"
[[ -d "$CTO_LOCAL_DIR" ]] || die "CTO bundle dir not found at $CTO_LOCAL_DIR"

# Verify API reachability & auth before touching anything.
say "Preflight: health check"
api GET /api/health | python3 -c "
import sys, json
h = json.load(sys.stdin)
print(f'  deploymentMode={h.get(\"deploymentMode\")} version={h.get(\"version\")}')" || die "health check failed"

say "Preflight: listing company (auth + company-id check)"
api GET "/api/companies" | python3 -c "
import sys, json
cs = json.load(sys.stdin)
target = '$COMPANY_ID'
matching = [c for c in cs if c['id'] == target]
if not matching:
    print(f'ERROR: company $COMPANY_ID not found or not visible', file=sys.stderr)
    sys.exit(1)
c = matching[0]
print(f'  company.name={c[\"name\"]} issuePrefix={c[\"issuePrefix\"]}')" || die "company lookup failed"

say "Preflight: verifying CEO agent exists and is role=ceo"
api GET "/api/agents/$CEO_AGENT_ID" | python3 -c "
import sys, json
a = json.load(sys.stdin)
if a.get('role') != 'ceo':
    print(f'WARN: agent role is {a.get(\"role\")}, expected ceo', file=sys.stderr)
print(f'  ceo.name={a[\"name\"]} role={a.get(\"role\")} instructionsFilePath={(a.get(\"adapterConfig\") or {}).get(\"instructionsFilePath\")}')" || die "CEO lookup failed"

if [[ -n "${CTO_AGENT_ID:-}" ]]; then
  say "Preflight: verifying CTO agent exists"
  api GET "/api/agents/$CTO_AGENT_ID" | python3 -c "
import sys, json
a = json.load(sys.stdin)
print(f'  cto.name={a[\"name\"]} role={a.get(\"role\")} instructionsFilePath={(a.get(\"adapterConfig\") or {}).get(\"instructionsFilePath\")}')" || die "CTO lookup failed"
fi

# -------- step 1: import paperclipowers skill library --------
say "Step 1: Importing paperclipowers skill library from $SKILLS_GIT_URL"

IMPORT_BODY=$(mktemp -t pclip-import.XXXXXX.json)
cat > "$IMPORT_BODY" <<EOF
{"source":"$SKILLS_GIT_URL"}
EOF

api POST "/api/companies/$COMPANY_ID/skills/import" "$IMPORT_BODY" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
except Exception:
    print('  (empty or non-JSON response — ok if import already up-to-date)')
    sys.exit(0)
if isinstance(r, dict) and 'error' in r:
    print(f'  ERROR: {r[\"error\"]}', file=sys.stderr); sys.exit(1)
if isinstance(r, dict) and 'skills' in r:
    print(f'  imported {len(r[\"skills\"])} skills')
else:
    print('  import response:', json.dumps(r)[:200])" || die "skill import failed"

rm -f "$IMPORT_BODY"

# -------- step 2: install CEO supplement --------
say "Step 2: Installing CEO supplement"

CEO_REMOTE_DIR="$NAS_DATA_ROOT/instances/$INSTANCE/companies/$COMPANY_ID/agents/$CEO_AGENT_ID/instructions"

say "  CEO dir: $CEO_REMOTE_DIR"
nas_exec "test -d '$CEO_REMOTE_DIR' || { echo 'CEO instructions dir missing; agent may need to be initialized first' >&2; exit 3; }" 0

say "  Backing up existing CEO AGENTS.md"
nas_exec "test -f '$CEO_REMOTE_DIR/AGENTS.md' && cp '$CEO_REMOTE_DIR/AGENTS.md' '$CEO_REMOTE_DIR/AGENTS.md.backup-$TS' || true"

say "  Copying 3 supplemental files"
for F in CEO-COGNITIVE-PATTERNS.md CEO-PRIME-DIRECTIVES.md CEO-TRIAGE-MODES.md; do
  nas_put "$CEO_LOCAL_DIR/$F" "$CEO_REMOTE_DIR/$F"
  echo "    $F"
done

say "  Appending References to AGENTS.md (idempotent)"
APPEND_MARKER="CEO-COGNITIVE-PATTERNS.md"
if [[ "$DRY_RUN" = "1" ]]; then
  echo "[DRY-RUN] appending 3 reference bullets to $CEO_REMOTE_DIR/AGENTS.md unless already present"
else
  # Idempotency: only append if the marker line isn't already in AGENTS.md.
  if ! ssh "$NAS_HOST" "grep -q '$APPEND_MARKER' '$CEO_REMOTE_DIR/AGENTS.md' 2>/dev/null"; then
    { printf '\n'; cat <<'REFS'
- `./CEO-COGNITIVE-PATTERNS.md` -- 18 strategic-thinking instincts. Internalize; don't enumerate.
- `./CEO-PRIME-DIRECTIVES.md` -- 9 review criteria to apply to every proposal you approve or reject.
- `./CEO-TRIAGE-MODES.md` -- EXPANSION / SELECTIVE EXPANSION / HOLD / REDUCTION framework. Set the mode in the first triage comment on every new board issue.
REFS
    } | ssh "$NAS_HOST" "cat >> '$CEO_REMOTE_DIR/AGENTS.md'"
    echo "    appended"
  else
    echo "    marker already present — skipped"
  fi
fi

# -------- step 3: install CTO bundle (optional) --------
if [[ -n "${CTO_AGENT_ID:-}" ]]; then
  say "Step 3: Installing CTO bundle"

  CTO_REMOTE_DIR="$NAS_DATA_ROOT/instances/$INSTANCE/companies/$COMPANY_ID/agents/$CTO_AGENT_ID/instructions"
  CTO_CONTAINER_PATH="/paperclip/instances/$INSTANCE/companies/$COMPANY_ID/agents/$CTO_AGENT_ID/instructions/AGENTS.md"

  say "  CTO dir (creating if missing): $CTO_REMOTE_DIR"
  nas_exec "mkdir -p '$CTO_REMOTE_DIR'"

  say "  Copying 5 bundle files"
  for F in AGENTS.md SOUL.md HEARTBEAT.md TOOLS.md ADR-TEMPLATE.md; do
    # If an existing AGENTS.md exists and we're about to overwrite, back it up first.
    if [[ "$F" = "AGENTS.md" && "$DRY_RUN" != "1" ]]; then
      ssh "$NAS_HOST" "test -f '$CTO_REMOTE_DIR/$F' && cp '$CTO_REMOTE_DIR/$F' '$CTO_REMOTE_DIR/$F.backup-$TS' || true"
    fi
    nas_put "$CTO_LOCAL_DIR/$F" "$CTO_REMOTE_DIR/$F"
    echo "    $F"
  done

  say "  PATCHing CTO adapterConfig.instructionsFilePath"
  CTO_PATCH=$(mktemp -t pclip-cto-patch.XXXXXX.json)
  cat > "$CTO_PATCH" <<EOF
{"adapterConfig":{"instructionsFilePath":"$CTO_CONTAINER_PATH"}}
EOF
  api PATCH "/api/agents/$CTO_AGENT_ID" "$CTO_PATCH" | python3 -c "
import sys, json
a = json.load(sys.stdin)
p = (a.get('adapterConfig') or {}).get('instructionsFilePath')
print(f'  instructionsFilePath now: {p}')" || die "CTO PATCH failed"
  rm -f "$CTO_PATCH"
else
  say "Step 3: CTO_AGENT_ID not set — skipping CTO install"
fi

# -------- step 4: verification --------
say "Step 4: Verification"

say "  CEO instructions dir contents:"
nas_exec "ls '$CEO_REMOTE_DIR' | grep -v backup" 0

if [[ -n "${CTO_AGENT_ID:-}" ]]; then
  say "  CTO instructions dir contents:"
  nas_exec "ls '$CTO_REMOTE_DIR' | grep -v backup" 0
fi

say "  CEO AGENTS.md References section (tail):"
nas_exec "tail -n 8 '$CEO_REMOTE_DIR/AGENTS.md'" 0

say "Done."
echo
echo "Next steps (manual):"
echo "  1. In the Paperclip UI, set desiredSkills on the CEO and CTO agents:"
echo "     CEO: add 'henriquerferrer/paperclipowers/pipeline-dispatcher' so board issues route into the pipeline."
echo "     CTO: add 'pipeline-dispatcher', 'writing-plans' is NOT for CTO — CTO writes ADRs, not plans."
echo "     (Both should already have the paperclipai/paperclip base skills + para-memory-files.)"
echo "  2. When the CEO's next heartbeat fires, it will read the new References. Watch for a 'Mode: …' line on board issues."
echo "  3. Rollback if needed: restore .backup-$TS files and PATCH CTO instructionsFilePath back to its prior value."
