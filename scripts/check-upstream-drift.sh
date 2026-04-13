#!/usr/bin/env bash
# Check upstream drift for adapted skills in skills-paperclip/.
# Usage: ./scripts/check-upstream-drift.sh [skill-name]
# If skill-name is omitted, checks all adapted skills.
#
# For each adapted skill, reads its UPSTREAM.md for the base SHA and source
# paths, then diffs those upstream paths between the base SHA and current HEAD.
# Prints a summary of what changed upstream since each adaptation was last synced.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

check_one() {
  local skill="$1"
  local upstream_md="$REPO_ROOT/skills-paperclip/$skill/UPSTREAM.md"

  if [ ! -f "$upstream_md" ]; then
    echo "⚠️  $skill: no UPSTREAM.md found — skipping"
    return
  fi

  # Extract the base SHA
  local base_sha
  base_sha=$(grep -E "^\*\*Upstream base commit:\*\*" "$upstream_md" | head -1 | sed -E 's/.*\*\*Upstream base commit:\*\* *//; s/ *$//')

  if [ -z "$base_sha" ]; then
    echo "⚠️  $skill: UPSTREAM.md present but no base SHA parsed — skipping"
    return
  fi

  # Extract upstream source paths (lines starting with "- `skills/...`")
  local source_paths
  source_paths=$(grep -E "^- \`skills/" "$upstream_md" 2>/dev/null | sed -E 's/^- `(skills\/[^`]+)`.*/\1/' | sort -u || true)

  if [ -z "$source_paths" ]; then
    echo "⚠️  $skill: UPSTREAM.md present but no source paths parsed — skipping"
    return
  fi

  echo "=== $skill ==="
  echo "Base: $base_sha"
  echo "Checking drift in:"
  echo "$source_paths" | sed 's/^/  /'
  echo

  local any_drift=0
  while IFS= read -r path; do
    # shellcheck disable=SC2086
    if ! git diff --quiet "$base_sha"..HEAD -- $path 2>/dev/null; then
      echo "  DRIFT in $path:"
      git diff --stat "$base_sha"..HEAD -- "$path" | sed 's/^/    /'
      any_drift=1
    fi
  done <<< "$source_paths"

  if [ $any_drift -eq 0 ]; then
    echo "  ✅ No upstream changes since last sync."
  else
    echo
    echo "  To review: git diff $base_sha..HEAD -- <path>"
    echo "  To resync: re-apply the edits listed in UPSTREAM.md to the new upstream content,"
    echo "             then update 'Last synced' and 'Upstream base commit' in UPSTREAM.md."
  fi
  echo
}

if [ $# -eq 0 ]; then
  # Check all skills with UPSTREAM.md
  for dir in "$REPO_ROOT"/skills-paperclip/*/; do
    skill=$(basename "$dir")
    [ -f "$dir/UPSTREAM.md" ] && check_one "$skill"
  done
else
  check_one "$1"
fi
