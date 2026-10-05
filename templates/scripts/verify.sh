#!/usr/bin/env bash
# [verify] One-command closed-loop gate (POSIX): lint changed files + api-check
# (static) + SSOT freshness (+ optional smoke), then a single PASS/FAIL -- the
# "definition of done" the agent must pass before claiming a task is finished.
# Each sub-check is PASS / FAIL / SKIP / WARN. Only FAIL fails the gate (exit 1).
# Missing script / missing checker / unconfigured paths -> SKIP (not FAIL).
# Encoding: ASCII-only (no BOM).
# ADAPT: the code-extension test and BASE_URL (smoke passthrough).
# Usage: ./scripts/verify.sh [--target <path>] [--full] [--base-url <url>] [--ssot-strict]
set +e

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TARGET=""
FULL=0
BASE_URL="http://localhost:8080"   # ADAPT
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

is_code() { case "$1" in *.php) return 0 ;; *) return 1 ;; esac }   # ADAPT

# --- Collect changed code files ---
in_git=0
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=1
fi
changed=""
if [ -n "$TARGET" ]; then
  changed="$TARGET"
elif [ "$in_git" = "1" ]; then
  while IFS= read -r l; do
    [ ${#l} -ge 4 ] || continue
    p="${l:3}"
    case "$p" in *" -> "*) p="${p##* -> }" ;; esac
    p="${p%\"}"; p="${p#\"}"
    if is_code "$p"; then changed="$changed
$p"; fi
  done <<EOF
$(git -C "$ROOT" status --porcelain 2>/dev/null)
EOF
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

# --- 3) SSOT freshness ---
if [ "$in_git" = "1" ]; then
  docs_touched=0; code_changed=0
  while IFS= read -r l; do
    [ ${#l} -ge 4 ] || continue
    p="${l:3}"
    case "$p" in *" -> "*) p="${p##* -> }" ;; esac
    p="${p%\"}"; p="${p#\"}"
    case "$p" in
      docs/*/*) ;;
      docs/*.md) docs_touched=1; continue ;;
    esac
    if is_code "$p"; then code_changed=1; fi
  done <<EOF
$(git -C "$ROOT" status --porcelain 2>/dev/null)
EOF
  if [ "$code_changed" = "0" ]; then
    res SKIP ssot "no code change in working tree"
  elif [ "$docs_touched" = "1" ]; then
    res PASS ssot "SSOT updated alongside code"
  elif [ "$SSOT_STRICT" = "1" ]; then
    res FAIL ssot "code changed but docs/*.md (SSOT) not updated"
  else
    res WARN ssot "code changed but docs/*.md (SSOT) not updated"
  fi
else
  res SKIP ssot "not a git work tree"
fi

# --- 4) smoke (optional; needs a running server) ---
if [ ! -f "$HERE/smoke.sh" ]; then
  res SKIP smoke "scripts/smoke.sh missing"
else
  reachable=0
  if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null --max-time 2 "$BASE_URL" && reachable=1
  fi
  if [ "$reachable" = "0" ] && [ "$FULL" = "0" ]; then
    res SKIP smoke "server not reachable at $BASE_URL (use --full to force)"
  else
    bash "$HERE/smoke.sh" --base-url "$BASE_URL" >/dev/null 2>&1
    if [ $? -eq 0 ]; then res PASS smoke "endpoints alive"; else res FAIL smoke "endpoint failures; run scripts/smoke.sh"; fi
  fi
fi

# --- Verdict ---
echo "== verify =="
printf '%s\n' "$lines" | sed '/^$/d'
if [ "$failN" -gt 0 ]; then verdict="FAIL"; else verdict="PASS"; fi
echo "== Result: $verdict (PASS=$passN FAIL=$failN WARN=$warnN SKIP=$skipN) =="
[ "$failN" -gt 0 ] && exit 1
exit 0
