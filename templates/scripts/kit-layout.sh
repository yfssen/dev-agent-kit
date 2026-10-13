#!/usr/bin/env bash
# Shared workspace layout for verify + ssot-reminder. Source only. ASCII, no BOM.
# SSOT = workspace-root top-level docs/*.md (NOT docs inside child git repos).
# Git repos = workspace if it is a work tree, PLUS each immediate child that has .git.
# ADAPT: KIT_CODE_EXT, KIT_REPO_NAMES, KIT_SKIP_DIRS.

# KIT_CODE_EXT: space-separated suffixes. ADAPT
KIT_CODE_EXT="${KIT_CODE_EXT:-php vue js ts sql}"
# KIT_REPO_NAMES: space-separated child dir names; empty = auto-discover. ADAPT
KIT_REPO_NAMES="${KIT_REPO_NAMES:-}"
KIT_SKIP_DIRS="${KIT_SKIP_DIRS:-node_modules vendor dist unpackage uni_modules .git}"

kit_is_code() {
  _base="${1##*/}"
  case "$_base" in *.*) ;; *) return 1 ;; esac
  _ext=$(printf '%s' "${_base##*.}" | tr 'A-Z' 'a-z')
  for _e in $KIT_CODE_EXT; do
    [ "$_ext" = "$_e" ] && return 0
  done
  return 1
}

kit_skip_dir() {
  _n="$1"
  for _s in $KIT_SKIP_DIRS; do
    [ "$_n" = "$_s" ] && return 0
  done
  return 1
}

# Print repo absolute paths, one per line. Arg1 = workspace root.
kit_git_repos() {
  ws="$1"
  git_in() { (cd "$1" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1); }
  if git_in "$ws"; then printf '%s\n' "$ws"; fi
  if [ -n "$KIT_REPO_NAMES" ]; then
    for _n in $KIT_REPO_NAMES; do
      _c="$ws/$_n"
      [ -d "$_c/.git" ] || continue
      kit_skip_dir "$_n" && continue
      printf '%s\n' "$_c"
    done
  else
    for _c in "$ws"/*; do
      [ -d "$_c/.git" ] || continue
      _n="$(basename "$_c")"
      kit_skip_dir "$_n" && continue
      printf '%s\n' "$_c"
    done
  fi
}

kit_git_status() {
  (cd "$1" 2>/dev/null && git status --porcelain 2>/dev/null)
}

# Print workspace-relative changed code paths. Arg1 = workspace root.
kit_changed_code() {
  ws="$1"
  kit_git_repos "$ws" | while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    prefix=""
    if [ "$repo" != "$ws" ]; then prefix="$(basename "$repo")/"; fi
    kit_git_status "$repo" | while IFS= read -r l; do
      [ ${#l} -ge 4 ] || continue
      p="${l:3}"
      case "$p" in *" -> "*) p="${p##* -> }" ;; esac
      p="${p%\"}"; p="${p#\"}"
      kit_is_code "$p" || continue
      printf '%s%s\n' "$prefix" "$p"
    done
  done
}

kit_root_ssot_in_git() {
  ws="$1"
  (cd "$ws" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1) || return 1
  while IFS= read -r l; do
    [ ${#l} -ge 4 ] || continue
    p="${l:3}"
    case "$p" in *" -> "*) p="${p##* -> }" ;; esac
    p="${p%\"}"; p="${p#\"}"
    case "$p" in
      docs/*/*) ;;
      docs/*.md) return 0 ;;
    esac
  done <<EOF
$(kit_git_status "$ws")
EOF
  return 1
}

# Exit 0 if SSOT looks fresh. Args: workspace, then code rel paths.
# A removed path has no mtime. Use the nearest existing parent directory
# (deletion updates that mtime) so a delete-only tree is not "nothing to compare".
kit_ssot_fresh() {
  ws="$1"; shift
  if kit_root_ssot_in_git "$ws"; then return 0; fi
  [ $# -eq 0 ] && return 0
  max_code=0
  missing_untimed=0
  for rel in "$@"; do
    f="$ws/$rel"
    t=0
    if [ -f "$f" ]; then
      t=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
    else
      dir=$(dirname "$f")
      while [ ! -d "$dir" ]; do
        parent=$(dirname "$dir")
        [ "$parent" = "$dir" ] && break
        dir=$parent
      done
      if [ -d "$dir" ]; then
        t=$(stat -c %Y "$dir" 2>/dev/null || stat -f %m "$dir" 2>/dev/null || echo 0)
      fi
      [ "$t" -eq 0 ] && missing_untimed=1
    fi
    [ "$t" -gt "$max_code" ] && max_code=$t
  done
  [ "$missing_untimed" = "1" ] && [ "$max_code" -eq 0 ] && return 1
  [ "$max_code" -eq 0 ] && return 0
  max_ssot=0
  ssot_any=0
  for f in "$ws"/docs/*.md; do
    [ -f "$f" ] || continue
    ssot_any=1
    t=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
    [ "$t" -gt "$max_ssot" ] && max_ssot=$t
  done
  [ "$ssot_any" = "0" ] && return 1
  [ "$max_ssot" -ge $((max_code - 2)) ]
}

# Heading bytes stay ASCII here. They are the progress-log title.
kit_progress_heading() {
  printf '## \345\205\255\343\200\201\345\217\230\346\233\264\350\256\260\345\275\225'
}

kit_progress_docs() {
  ws="$1"
  name=$(printf '\351\241\271\347\233\256\350\277\233\345\272\246\344\270\216\345\256\214\346\210\220\345\272\246.md')
  prefer="$ws/docs/$name"
  if [ -f "$prefer" ]; then
    printf '%s\n' "$prefer"
    return
  fi
  for f in "$ws"/docs/*.md; do
    [ -f "$f" ] || continue
    printf '%s\n' "$f"
  done
}

kit_latest_progress_row() {
  ws="$1"
  heading=$(kit_progress_heading)
  best=""
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    row=$(awk -v h="$heading" '
      index($0, h) == 1 { insec = 1; next }
      insec && index($0, "## ") == 1 { insec = 0 }
      insec && index($0, "|") == 1 && index($0, "---") == 0 { row = $0 }
      END { if (row != "") print row }
    ' "$path")
    [ -n "$row" ] && best="$row"
  done <<EOF
$(kit_progress_docs "$ws")
EOF
  printf '%s' "$best"
}

# Print changed paths the latest progress row does not mention.
kit_unnamed_changes() {
  ws="$1"
  shift
  row=$(kit_latest_progress_row "$ws" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')
  for rel in "$@"; do
    [ -n "$rel" ] || continue
    n=$(printf '%s' "$rel" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')
    case "$row" in
      *"$n"*) ;;
      *) printf '%s\n' "$rel" ;;
    esac
  done
}
