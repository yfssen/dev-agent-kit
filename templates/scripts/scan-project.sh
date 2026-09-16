#!/usr/bin/env bash
# [scan-project] Structural scan for init workflow. ASCII-only. No secrets.
# Usage: ./scripts/scan-project.sh [out-file]

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUT="${1:-}"

tmp=$(mktemp)
{
  echo "# scan-project raw"
  echo ""
  echo "- root: $ROOT"
  echo "- scanned_at: $(date '+%Y-%m-%d %H:%M:%S')"
  if [ -d "$ROOT/.git" ]; then echo "- root_has_git: true"; else echo "- root_has_git: false"; fi
  echo ""
  echo "## Top-level"
  for p in "$ROOT"/* "$ROOT"/.[!.]*; do
    [ -e "$p" ] || continue
    base=$(basename "$p")
    [ "$base" = "." ] || [ "$base" = ".." ] && continue
    if [ -d "$p" ]; then
      git=""
      [ -d "$p/.git" ] && git=" [git]"
      echo "- dir: $base$git"
    else
      echo "- file: $base"
    fi
  done
  echo ""
  echo "## Dual-git heuristic"
  count=0
  kids=""
  for p in "$ROOT"/*; do
    [ -d "$p/.git" ] || continue
    count=$((count + 1))
    kids="$kids
  - $(basename "$p")"
  done
  if [ "$count" -ge 2 ]; then
    echo "- likely_dual_git: yes ($count child repos)"
    printf '%s\n' "$kids"
  elif [ "$count" -eq 1 ]; then
    echo "- likely_dual_git: maybe (1 child git)$kids"
  else
    echo "- likely_dual_git: no child .git found (or single-repo at root)"
  fi
  echo ""
  echo "## Stack signals (find, pruned)"
  for pat in package.json composer.json requirements.txt pyproject.toml pom.xml go.mod .env .env.example; do
    echo "### $pat"
    find "$ROOT" -maxdepth 3 -name "$pat" \
      -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/dist/*' 2>/dev/null \
      | head -n 8 | while read -r f; do echo "- ${f#$ROOT/}"; done
  done
  echo ""
  echo "## Git hot files (last 20 commits, top 12)"
  if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" -c core.quotepath=false log -20 --name-only --pretty=format: 2>/dev/null | sed '/^$/d' | sort | uniq -c | sort -nr | head -n 12 | while read -r c f; do
      echo "- $c $f"
    done
  else
    echo "- skipped: git missing or not a git work tree"
  fi
  echo ""
  echo "## Next"
  echo "- Agent: fill docs/project-architecture.md (CN filename in templates/docs) from code + this scan"
  echo "- ADAPT scripts .env path if dual-git (often <backend>/.env)"
  echo "- Do not paste this whole dump into chat; grep the section you need"
} >"$tmp"

cat "$tmp"
if [ -n "$OUT" ]; then
  case "$OUT" in
    /*) dest="$OUT" ;;
    *) dest="$ROOT/$OUT" ;;
  esac
  mkdir -p "$(dirname "$dest")"
  cp "$tmp" "$dest"
  echo "Wrote $dest"
fi
rm -f "$tmp"
