#!/usr/bin/env bash
# Bootstrap this kit on a new machine: sync global skills for all AI tools.
# ASCII-only. Copy the whole repo, then run ONCE from kit root:
#   ./install-global.sh
# Optional: ./install-global.sh /path/to/dev-agent-kit

set -eu

if [ "${1:-}" != "" ]; then
  KIT=$(CDPATH= cd -- "$1" && pwd)
else
  KIT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
fi

SKILL_SRC="$KIT/skills/scaffold-dev-agent"
if [ ! -f "$SKILL_SRC/SKILL.md" ]; then
  echo "Not a valid kit root (missing skills/scaffold-dev-agent/SKILL.md): $KIT" >&2
  exit 1
fi

echo "========================================"
echo " dev-agent-kit  install-global"
echo "========================================"
echo "KIT = $KIT"
echo ""

# Inline sync (same targets as sync-global-skills.ps1)
UP="${HOME}"
TARGETS=(
  "$UP/.cursor/skills/scaffold-dev-agent"
  "$UP/.kiro/skills/scaffold-dev-agent"
  "$UP/.agents/skills/scaffold-dev-agent"
  "$UP/.claude/skills/scaffold-dev-agent"
  "$UP/.codebuddy/skills/scaffold-dev-agent"
  "$UP/.workbuddy/skills/scaffold-dev-agent"
  "$UP/.qoder/skills/scaffold-dev-agent"
  "$UP/.codex/skills/scaffold-dev-agent"
)

for dest in "${TARGETS[@]}"; do
  mkdir -p "$dest/scripts"
  cp "$SKILL_SRC/SKILL.md" "$dest/"
  cp "$SKILL_SRC/adapter-map.md" "$dest/"
  cp "$SKILL_SRC/init-workflow.md" "$dest/"
  cp "$SKILL_SRC/scripts/"* "$dest/scripts/" 2>/dev/null || true
  # do not require chmod on sync script copies inside dest
  printf '%s\n' "$KIT" > "$dest/kit-path.txt"
  echo "[OK] $dest"
done

echo ""
echo "Done."
echo "Cursor / Claude / Codex / Kiro / Qoder, say:"
echo "  use scaffold-dev-agent and read init-workflow.md"
echo ""
echo "WorkBuddy: do not say only the skill name. It searches the marketplace and reports not found."
echo "Send the WorkBuddy sentence in the tools guide, section 2A. The file is:"
echo "  $UP/.workbuddy/skills/scaffold-dev-agent/SKILL.md"
echo "init-workflow.md is the sibling file, not a second skill."
echo ""
echo "kit-path.txt points to this KIT. Re-run ./install-global.sh after editing the skill."
exit 0
