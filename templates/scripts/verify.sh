#!/usr/bin/env bash
# [verify] One-command closed-loop gate (POSIX): lint changed files + api-check
# (static) + SSOT freshness (+ optional smoke), then a single PASS/FAIL -- the
# "definition of done" the agent must pass before claiming a task is finished.
# Each sub-check is PASS / FAIL / SKIP / WARN. Only FAIL fails the gate (exit 1).
# Done: yes only when Result is PASS and WARN=0. A WARN still exits 0 and prints Done: no.
# Missing script / missing checker / unconfigured paths -> SKIP (not FAIL).
# Encoding: ASCII-only (no BOM).
# ADAPT: the code-extension test, BASE_URL, and PROBE_PATH (must match smoke.sh).
# Usage: ./scripts/verify.sh [--target <path>] [--full] [--base-url <url>] [--ssot-strict]
# Smoke probe: GET BASE_URL+PROBE_PATH. Only run smoke if the body looks like this
# project's API JSON ("code"). A random HTTP service on the same port is SKIP.
set +e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TARGET=""
FULL=0
BASE_URL="http://localhost:8080"   # ADAPT
PROBE_PATH="/api/website/info"     # ADAPT: keep in sync with smoke.sh first public endpoint
SSOT_STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --full) FULL=1; shift ;;
    --base-url) BASE_URL="$2"; shift 2 ;;
    --ssot-strict) SSOT_STRICT=1; shift ;;
    *) shift ;;
  esac
done

passN=0; failN=0; skipN=0; warnN=0
lines=""
res() { # tag name detail
  case "$1" in
    PASS) passN=$((passN + 1)) ;;
    FAIL) failN=$((failN + 1)) ;;
    SKIP) skipN=$((skipN + 1)) ;;
    WARN) warnN=$((warnN + 1)) ;;
  esac
  d=""
  [ -n "$3" ] && d=" -- $3"
  lines="$lines
[$1] $2$d"
}

# shellcheck disable=SC1091
if [ -f "$HERE/kit-layout.sh" ]; then
  . "$HERE/kit-layout.sh"
fi

# --- Collect changed code files (all git repos in the workspace) ---
in_git=0
if command -v git >/dev/null 2>&1 && command -v kit_git_repos >/dev/null 2>&1; then
  if [ -n "$(kit_git_repos "$ROOT")" ]; then in_git=1; fi
fi
changed=""
if [ -n "$TARGET" ]; then
  changed="$TARGET"
elif [ "$in_git" = "1" ]; then
  changed="$(kit_changed_code "$ROOT")"
fi

# --- 1) lint changed files ---
if [ ! -f "$HERE/lint.sh" ]; then
  res SKIP lint "scripts/lint.sh missing"
elif [ -z "$(printf '%s' "$changed" | tr -d '[:space:]')" ]; then
  res SKIP lint "no changed code files"
else
  anyFail=0; anySkip=0; n=0
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    case "$c" in /*) full="$c" ;; *) full="$ROOT/$c" ;; esac
    [ -f "$full" ] || continue
    n=$((n + 1))
    bash "$HERE/lint.sh" "$full" >/dev/null 2>&1
    code=$?
    case "$code" in
      0) ;;
      2) anySkip=1 ;;
      *) anyFail=1 ;;
    esac
  done <<EOF
$changed
EOF
  if [ "$n" = "0" ]; then
    res SKIP lint "changed paths missing on disk (deleted?)"
  elif [ "$anyFail" = "1" ]; then
    res FAIL lint "syntax errors in changed files; run scripts/lint.sh on them"
  elif [ "$anySkip" = "1" ]; then
    res SKIP lint "checker missing (set LZ_PHP / add to PATH)"
  else
    res PASS lint "$n changed file(s) clean"
  fi
fi

# --- 2) api-check (static) ---
if [ ! -f "$HERE/api-check.sh" ]; then
  res SKIP api-check "scripts/api-check.sh missing"
else
  out="$(bash "$HERE/api-check.sh" 2>&1)"
  code=$?
  if ! printf '%s' "$out" | grep -q "== Summary:"; then
    res SKIP api-check "did not run (paths not configured?)"
  elif [ "$code" = "0" ]; then
    res PASS api-check "no missing controllers/methods"
  else
    res FAIL api-check "frontend calls without backend method/controller; run scripts/api-check.sh"
  fi
fi

# --- 3) SSOT freshness: workspace-root docs/*.md (mtime or root git) ---
if [ "$in_git" = "1" ]; then
  if [ -z "$(printf '%s' "$changed" | tr -d '[:space:]')" ]; then
    res SKIP ssot "no code change in any git repo"
  else
    set --
    while IFS= read -r _p; do
      [ -n "$_p" ] || continue
      set -- "$@" "$_p"
    done <<EOF
$changed
EOF
    missing=""
    if command -v kit_unnamed_changes >/dev/null 2>&1; then
      missing=$(kit_unnamed_changes "$ROOT" "$@")
    fi
    if kit_ssot_fresh "$ROOT" "$@" && [ -z "$missing" ]; then
      res PASS ssot "latest progress row names the changed files"
    else
      detail="code changed but workspace-root docs/*.md (SSOT) not updated"
      if [ -n "$missing" ]; then
        detail="latest progress row must name: $(printf '%s' "$missing" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
      fi
      if [ "$SSOT_STRICT" = "1" ]; then
        res FAIL ssot "$detail"
      else
        res WARN ssot "$detail"
      fi
    fi
  fi
else
  res SKIP ssot "no git repo at workspace root or immediate children"
fi

# --- 4) smoke (optional; needs THIS project's server, not "any HTTP on the port") ---
probe_kind() {
  if ! command -v curl >/dev/null 2>&1; then
    printf '%s' "none"
    return
  fi
  url="${BASE_URL%/}${PROBE_PATH}"
  body=$(curl -sS --noproxy '*' --max-time 2 "$url" 2>/dev/null)
  if [ $? -ne 0 ]; then
    printf '%s' "none"
    return
  fi
  if printf '%s' "$body" | grep -q '"code"'; then
    printf '%s' "ours"
  else
    printf '%s' "other"
  fi
}

if [ ! -f "$HERE/smoke.sh" ]; then
  res SKIP smoke "scripts/smoke.sh missing"
else
  kind="$(probe_kind)"
  run_smoke=0
  if [ "$FULL" = "1" ]; then
    run_smoke=1
  elif [ "$kind" = "ours" ]; then
    run_smoke=1
  elif [ "$kind" = "other" ]; then
    res SKIP smoke "other HTTP service at $BASE_URL (not this API; use --full to force)"
  else
    res SKIP smoke "server not reachable at $BASE_URL (use --full to force)"
  fi
  if [ "$run_smoke" = "1" ]; then
    bash "$HERE/smoke.sh" --base-url "$BASE_URL" >/dev/null 2>&1
    if [ $? -eq 0 ]; then res PASS smoke "endpoints alive"; else res FAIL smoke "endpoint failures; run scripts/smoke.sh"; fi
  fi
fi

# --- Verdict ---
echo "== verify =="
printf '%s\n' "$lines" | sed '/^$/d'
if [ "$failN" -gt 0 ]; then verdict="FAIL"; else verdict="PASS"; fi
echo "== Result: $verdict (PASS=$passN FAIL=$failN WARN=$warnN SKIP=$skipN) =="
if [ "$failN" -gt 0 ]; then
  echo "== Done: no =="
  echo "Next: fix the first [FAIL] line, then run this command again."
  exit 1
fi
if [ "$warnN" -gt 0 ]; then
  echo "== Done: no =="
  echo "Next: append one progress row naming the changed files, then run this command again."
  exit 0
fi
echo "== Done: yes =="
exit 0
