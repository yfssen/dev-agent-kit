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
  echo "## Git layout"
  own=no
  [ -d "$ROOT/.git" ] && own=yes
  echo "- own_git: $own"
  parent=no
  if command -v git >/dev/null 2>&1; then
    if top=$(cd "$ROOT" && git rev-parse --show-toplevel 2>/dev/null); then
      root_phys=$(cd "$ROOT" && pwd)
      [ "$top" != "$root_phys" ] && parent=$top
    fi
  fi
  echo "- parent_git: $parent"
  with_git=""
  without_git=""
  for p in "$ROOT"/*; do
    [ -d "$p" ] || continue
    base=$(basename "$p")
    case "$base" in
      node_modules|vendor|dist|unpackage|uni_modules|docs|scripts|.git|.cursor|.kiro|.codebuddy|.qoder|.github) continue ;;
    esac
    if [ -d "$p/.git" ]; then
      with_git="${with_git:+$with_git, }$base"
    else
      without_git="${without_git:+$without_git, }$base"
    fi
  done
  echo "- children_with_git: ${with_git:-none}"
  echo "- project_dirs_without_git: ${without_git:-none}"
  remotes=none
  if [ "$own" = "yes" ] && command -v git >/dev/null 2>&1; then
    rv=$(cd "$ROOT" && git remote -v 2>/dev/null || true)
    [ -n "$rv" ] && remotes=$(printf '%s' "$rv" | tr '\n' '; ')
  fi
  echo "- remotes: $remotes"
  remote_names() {
    dir="$1"
    if ! command -v git >/dev/null 2>&1; then
      printf 'none'
      return
    fi
    names=$(cd "$dir" && git remote 2>/dev/null | tr '\n' ',' || true)
    names=${names%,}
    if [ -z "$names" ]; then
      printf 'none'
    else
      printf '%s' "$names"
    fi
  }
  rr=""
  add_rr() {
    if [ -z "$rr" ]; then rr="$1"; else rr="$rr; $1"; fi
  }
  if [ "$own" = "yes" ]; then
    add_rr "root=$(remote_names "$ROOT")"
  fi
  for p in "$ROOT"/*; do
    [ -d "$p" ] || continue
    base=$(basename "$p")
    case "$base" in
      node_modules|vendor|dist|unpackage|uni_modules|docs|scripts|.git|.cursor|.kiro|.codebuddy|.qoder|.github) continue ;;
    esac
    if [ -d "$p/.git" ]; then
      add_rr "$base=$(remote_names "$p")"
    fi
  done
  echo "- repo_remotes: ${rr:-none}"
  advice=record_single
  if [ "$own" = "no" ] && [ "$parent" != "no" ]; then advice=ask_parent
  elif [ "$own" = "yes" ] && [ -n "$with_git" ]; then advice=nested
  elif [ "$own" = "yes" ]; then advice=record_single
  elif [ -n "$with_git" ] && [ -z "$without_git" ]; then advice=record_multi
  elif [ -z "$without_git" ]; then advice=ask_empty
  else advice=ask_children
  fi
  echo "- advice: $advice"
  echo ""
  echo "## Git hot files (last 20 commits, top 12)"
  # Git for Windows does not accept msys paths (/e/www/...). cd in bash, then git
  # without -C. If root is not a repo, fall back to a single child .git (dual-git
  # parent workspace). 0 or 2+ children: report why, do not guess.
  if ! command -v git >/dev/null 2>&1; then
    echo "- skipped: git not on PATH"
  else
    repo=""
    if (cd "$ROOT" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
      repo="$ROOT"
    else
      child_count=0
      child_repo=""
      for p in "$ROOT"/*; do
        [ -d "$p/.git" ] || continue
        child_count=$((child_count + 1))
        child_repo="$p"
      done
      if [ "$child_count" -eq 1 ]; then repo="$child_repo"; fi
    fi
    if [ -z "$repo" ]; then
      echo "- skipped: root is not a git work tree and no single child repo found"
    else
      if [ "$repo" = "$ROOT" ]; then echo "- repo: ."; else echo "- repo: ${repo#"$ROOT"/}"; fi
      (
        cd "$repo" || exit 0
        # Two processes (git + awk), not git|sed|sort|uniq|sort|head — hosts that wrap
        # every external command will kill a long pipeline before it finishes.
        git -c core.quotepath=false log -20 --name-only --pretty=format: 2>/dev/null \
          | awk 'NF { c[$0]++ }
                 END {
                   n = 0
                   for (i = 0; i < 12; i++) {
                     best = 0; pick = ""
                     for (f in c) if (c[f] > best) { best = c[f]; pick = f }
                     if (best == 0) break
                     print "- " best, pick
                     delete c[pick]
                     n++
                   }
                   if (n == 0) print "- none (empty log)"
                 }'
      )
    fi
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
# Temp removal is housekeeping. With set -e, a wrapped/locked rm would turn a
# successful scan into exit 1 (false FAIL).
rm -f "$tmp" 2>/dev/null || true
