#!/usr/bin/env bash
# Install core + adapters. Never overwrite existing files unless --force.
# Existing dest -> write sibling "*.kit-new" and report MERGE.
# Usage: ./install.sh <kit-root> <project-root> [cursor,claude,kiro] [--force]
# Adapter "auto": detect adapters already installed in the project and re-sync
#   them merge-safe (one stable command upgrades any project), then report any
#   opt-in capability layers (e.g. hooks) the kit offers but the project lacks.

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

# --- Merge kit-required ignore rules into the PROJECT's .gitignore (append-only, idempotent) ---
# verify writes .verify-fingerprint into the project root. The kit's own .gitignore does not
# reach into projects, so without this the file shows up as untracked in every project that
# installs the kit. Rules live in templates/gitignore-extra.txt and travel with the install.
ignore_extra="$KIT/templates/gitignore-extra.txt"
if [ -f "$ignore_extra" ]; then
  gi="$PROJ/.gitignore"
  # NOTE: do not reuse the global "added" counter here -- it counts NEW/FORCE files and is
  # printed in the final summary. Resetting it to 0 silently undercounts the summary.
  gi_added=0
  while IFS= read -r rule; do
    case "$rule" in ''|'#'*) continue ;; esac
    if [ -f "$gi" ] && grep -qxF -- "$rule" "$gi" 2>/dev/null; then continue; fi
    if [ "$gi_added" -eq 0 ]; then
      # Start on a fresh line: a hand-edited .gitignore often has no trailing newline,
      # and appending straight onto the last rule would corrupt it.
      if [ -s "$gi" ] && [ -n "$(tail -c 1 "$gi" 2>/dev/null)" ]; then
        printf '\n' >> "$gi"
      fi
      printf '\n# dev-agent-kit: files this toolkit creates on this machine\n' >> "$gi"
    fi
    printf '%s\n' "$rule" >> "$gi"
    gi_added=$((gi_added + 1))
  done < "$ignore_extra"
  if [ "$gi_added" -gt 0 ]; then
    echo "[GITIGNORE] added $gi_added rule(s) to .gitignore"
  else
    echo "[GITIGNORE] project .gitignore already covers the kit's rules"
  fi
fi

# Opt-in capability layers (not AI-tool choices). "auto" reports missing ones only.
CAP_LAYERS="hooks"

detect_adapters() {
  root="$1"; out=""
  if [ -d "$root/.cursor/rules" ] && ls "$root/.cursor/rules/"*.mdc >/dev/null 2>&1; then out="$out cursor"; fi
  [ -f "$root/CLAUDE.md" ] && out="$out claude"
  [ -d "$root/.kiro/steering" ] && out="$out kiro"
  { [ -f "$root/CODEBUDDY.md" ] || [ -d "$root/.codebuddy" ]; } && out="$out workbuddy"
  [ -d "$root/.qoder/rules" ] && out="$out qoder"
  [ -f "$root/.cursor/hooks.json" ] && out="$out hooks"
  echo "$out"
}

IFS=',' read -r -a wanted <<< "$ADAPTERS"

# "auto": expand to whatever the project already has, so one command re-syncs any project.
has_auto=0
for a in "${wanted[@]}"; do
  case "$(echo "$a" | tr '[:upper:]' '[:lower:]' | tr -d ' ')" in auto) has_auto=1 ;; esac
done
if [ "$has_auto" = "1" ]; then
  detected="$(detect_adapters "$PROJ")"
  echo "AUTO-DETECTED adapters:${detected:- (none; fresh project)}"
  newlist=""
  for a in "${wanted[@]}" $detected; do
    a=$(echo "$a" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    [ -n "$a" ] || continue
    [ "$a" = "auto" ] && continue
    case " $newlist " in *" $a "*) ;; *) newlist="$newlist $a" ;; esac
  done
  wanted=()
  for a in $newlist; do wanted+=("$a"); done
fi

for a in ${wanted[@]+"${wanted[@]}"}; do
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
      # WorkBuddy often indexes project skills more reliably than user-global alone
      PROJ_SKILL="$PROJ/.codebuddy/skills/scaffold-dev-agent"
      mkdir -p "$PROJ_SKILL/scripts"
      SKILL_SRC="$KIT/skills/scaffold-dev-agent"
      install_file "$SKILL_SRC/SKILL.md" "$PROJ_SKILL/SKILL.md"
      install_file "$SKILL_SRC/adapter-map.md" "$PROJ_SKILL/adapter-map.md"
      install_file "$SKILL_SRC/init-workflow.md" "$PROJ_SKILL/init-workflow.md"
      for f in "$SKILL_SRC/scripts/"*; do
        [ -f "$f" ] || continue
        install_file "$f" "$PROJ_SKILL/scripts/$(basename "$f")"
      done
      printf '%s\n' "$KIT" > "$PROJ_SKILL/kit-path.txt"
      echo "[OK] adapter workbuddy/codebuddy (+ project .codebuddy/skills/scaffold-dev-agent)"
      ;;
    qoder)
      mkdir -p "$PROJ/.qoder/rules"
      for f in "$KIT/adapters/qoder/rules/"*; do
        [ -f "$f" ] || continue
        install_file "$f" "$PROJ/.qoder/rules/$(basename "$f")"
      done
      echo "[OK] adapter qoder (AGENTS.md + .qoder/rules)"
      ;;
    hooks)
      # Deterministic guardrails (Cursor): guard-shell / auto-lint / backup-ssot.
      install_file "$KIT/templates/hooks/cursor/hooks.json" "$PROJ/.cursor/hooks.json"
      install_file "$KIT/templates/hooks/cursor/hooks.posix.json" "$PROJ/.cursor/hooks.posix.json"
      mkdir -p "$PROJ/.cursor/hooks"
      for f in "$KIT/templates/hooks/cursor/hooks/"*; do
        [ -f "$f" ] || continue
        install_file "$f" "$PROJ/.cursor/hooks/$(basename "$f")"
      done
      chmod +x "$PROJ/.cursor/hooks/"*.sh 2>/dev/null || true
      echo "[OK] adapter hooks (Cursor .cursor/hooks.json + hooks/; mac/linux: use hooks.posix.json)"
      ;;
    *)
      echo "[SKIP] unknown adapter: $a"
      ;;
  esac
done

echo ""
echo "== Summary: NEW/FORCE=$added MERGE_NEEDED=$merged SAME=$same =="

# Report opt-in capability layers the kit offers but the project does not have yet.
installed_now="$(detect_adapters "$PROJ")"
for cap in $CAP_LAYERS; do
  case " $installed_now " in
    *" $cap "*) ;;
    *) echo "[AVAILABLE] optional capability not installed: $cap -- re-run with adapter '$cap' to add it" ;;
  esac
done

if [ "$merged" -gt 0 ]; then
  echo "Merge these (read existing + *.kit-new, keep project facts, add kit tooling):"
  printf '%s\n' "$merge_list"
  echo "After merge, delete the sibling *.kit-new files."
  echo "MERGE GUIDE: keep project # ADAPT values (BaseUrl, ProbePath, .env path, checker command, filled progress snapshot)."
  echo "MERGE GUIDE: take kit behavior from *.kit-new (kit-layout multi-git, workspace-root docs SSOT, code extensions, cooldown)."
  echo "MERGE GUIDE: Git layout in scripts/scan-project.ps1 and .sh is new kit behavior. Old projects lack ## Git layout and repo_remotes. Take that section from *.kit-new, then run the merged scan. Record repos that already exist. Ask once only for project dirs that still have no .git. For each repo_remotes value none, ask once for an existing git URL or skip, and add it only with scripts/git-remote-add. Do not open a Gitee or GitHub repo. Do not commit. Do not push. Do not git config. Do not redo init."
  echo "MERGE GUIDE: single-repo git status, .php-only, and 1200s cooldown are old kit defaults, not project facts. Replace them."
  echo "MERGE GUIDE: ssot-reminder must not print followup_message. Drop the stop hook. Verify owns the SSOT WARN."
  echo "MERGE GUIDE: verify prints Done: yes only when Result is PASS and WARN=0. Exit 1 only on FAIL. The first FAIL line is the next edit. Next: STOP means the same checks failed three times: reproduce before another edit. A WARN means append one progress row (what changed, which check) and re-run. Take this from verify *.kit-new."
  echo "MERGE GUIDE: daily work reads progress section 2 and the last 10 rows of section 6, then only the code they point at. Keep older rows. Update the architecture doc only when observable behavior changes. Reproduce a bug once before editing. Quote Done: yes from this turn. Name changed files the task did not ask for."
  echo "MERGE GUIDE: coding rules say write it straight. No new interface, base class, factory, or generic layer for a single call. Backend follows the existing controller and service style. Take this from coding *.kit-new."
  echo "MERGE GUIDE: the latest progress row must name each changed code path. verify WARNs with the missing paths. Take Get-KitUnnamedChanges from kit-layout *.kit-new."
  echo "MERGE GUIDE: leaving *.kit-new unmerged means this upgrade did not land."
  exit 2
fi
echo "Next: fill placeholders / # ADAPT if still templated."
exit 0
