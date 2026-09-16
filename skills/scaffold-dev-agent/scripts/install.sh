#!/usr/bin/env bash
# Install core + adapters. Never overwrite existing files unless --force.
# Existing dest -> write sibling "*.kit-new" and report MERGE.
# Usage: ./install.sh <kit-root> <project-root> [cursor,claude,kiro] [--force]

set -eu
KIT=$(CDPATH= cd -- "${1:?kit root}" && pwd)
PROJ=$(CDPATH= cd -- "${2:?project root}" && pwd)
ADAPTERS="${3:-cursor,claude,kiro}"
FORCE=0
if [ "${4:-}" = "--force" ] || [ "${3:-}" = "--force" ]; then
  FORCE=1
fi
# Allow: ./install.sh kit proj --force
if [ "${3:-}" = "--force" ]; then
  ADAPTERS="cursor,claude,kiro"
fi

added=0
merged=0
same=0
merge_list=""

install_file() {
  src="$1"
  dest="$2"
  if [ ! -f "$src" ]; then
    echo "[MISS] source missing: $src"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [ ! -e "$dest" ]; then
    cp "$src" "$dest"
    echo "[NEW]  $dest"
    added=$((added + 1))
    return 0
  fi
  if [ "$FORCE" = "1" ]; then
    cp "$src" "$dest"
    echo "[FORCE] $dest"
    added=$((added + 1))
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    s=$(sha256sum "$src" | awk '{print $1}')
    d=$(sha256sum "$dest" | awk '{print $1}')
  else
    s=$(shasum -a 256 "$src" | awk '{print $1}')
    d=$(shasum -a 256 "$dest" | awk '{print $1}')
  fi
  if [ "$s" = "$d" ]; then
    echo "[SAME] $dest"
    same=$((same + 1))
    return 0
  fi
  cp "$src" "$dest.kit-new"
  echo "[MERGE] exists -> wrote $dest.kit-new (read both, then merge)"
  merged=$((merged + 1))
  merge_list="${merge_list}
  - ${dest}"
}

echo "KIT=$KIT"
echo "PROJECT=$PROJ"
if [ "$FORCE" = "1" ]; then
  echo "MODE=FORCE overwrite"
else
  echo "MODE=merge-safe (no overwrite)"
fi

mkdir -p "$PROJ/docs" "$PROJ/scripts"

install_file "$KIT/templates/AGENTS.md" "$PROJ/AGENTS.md"

if [ -d "$KIT/templates/docs" ]; then
  for f in "$KIT/templates/docs/"*; do
    [ -f "$f" ] || continue
    install_file "$f" "$PROJ/docs/$(basename "$f")"
  done
fi

if [ -d "$KIT/templates/scripts" ]; then
  for f in "$KIT/templates/scripts/"*; do
    [ -f "$f" ] || continue
    install_file "$f" "$PROJ/scripts/$(basename "$f")"
  done
  chmod +x "$PROJ/scripts/"*.sh 2>/dev/null || true
fi

IFS=',' read -r -a wanted <<< "$ADAPTERS"
for a in "${wanted[@]}"; do
  a=$(echo "$a" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
  [ -n "$a" ] || continue
  case "$a" in
    --force) continue ;;
    cursor)
      mkdir -p "$PROJ/.cursor/rules"
      for f in "$KIT/adapters/cursor/"*.mdc; do
        [ -f "$f" ] || continue
        install_file "$f" "$PROJ/.cursor/rules/$(basename "$f")"
      done
      echo "[OK] adapter cursor"
      ;;
    claude)
      install_file "$KIT/adapters/claude/CLAUDE.md" "$PROJ/CLAUDE.md"
      echo "[OK] adapter claude"
      ;;
    codex)
      echo "[OK] adapter codex (AGENTS.md is enough)"
      ;;
    kiro)
      mkdir -p "$PROJ/.kiro/steering"
      for f in "$KIT/adapters/kiro/steering/"*; do
        [ -f "$f" ] || continue
        install_file "$f" "$PROJ/.kiro/steering/$(basename "$f")"
      done
      echo "[OK] adapter kiro"
      ;;
    workbuddy|codebuddy)
      install_file "$KIT/adapters/workbuddy/CODEBUDDY.md" "$PROJ/CODEBUDDY.md"
      mkdir -p "$PROJ/.codebuddy/rules"
      for f in "$KIT/adapters/workbuddy/rules/"*; do
        [ -f "$f" ] || continue
        install_file "$f" "$PROJ/.codebuddy/rules/$(basename "$f")"
      done
      echo "[OK] adapter workbuddy/codebuddy"
      ;;
    qoder)
      mkdir -p "$PROJ/.qoder/rules"
      for f in "$KIT/adapters/qoder/rules/"*; do
        [ -f "$f" ] || continue
        install_file "$f" "$PROJ/.qoder/rules/$(basename "$f")"
      done
      echo "[OK] adapter qoder (AGENTS.md + .qoder/rules)"
      ;;
    *)
      echo "[SKIP] unknown adapter: $a"
      ;;
  esac
done

echo ""
echo "== Summary: NEW/FORCE=$added MERGE_NEEDED=$merged SAME=$same =="
if [ "$merged" -gt 0 ]; then
  echo "Merge these (read existing + *.kit-new, keep project facts, add kit tooling):"
  printf '%s\n' "$merge_list"
  echo "After merge, delete the sibling *.kit-new files."
  exit 2
fi
echo "Next: fill placeholders / # ADAPT if still templated."
exit 0
