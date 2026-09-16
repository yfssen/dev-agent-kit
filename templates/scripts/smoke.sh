#!/usr/bin/env bash
# [verify] API smoke test. See tooling rules.
# Gets a token via a dev-only login fixture, then hits public + authed endpoints.
# PASS = HTTP 200 + JSON has expected shape. WARN = alive but business error. FAIL = network/404.
# ADAPT: BaseUrl default, the token fixture path, and the endpoint lists.
# Encoding: ASCII-only (no BOM). Put Chinese notes in .md files.

set -eu

BASE_URL="http://localhost:8080"   # ADAPT: local env that serves CURRENT code
MOBILE="13800138001"               # ADAPT: fixture identity

while [ "${1:-}" != "" ]; do
  case "$1" in
    --base-url) BASE_URL="$2"; shift 2 ;;
    --mobile) MOBILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

pass=0; warn=0; fail=0

# Returns body on stdout; exit 0 on HTTP success-ish curl, else non-zero.
invoke_api() {
  path="$1"
  qs="${2:-}"
  url="${BASE_URL%/}${path}"
  if [ -n "$qs" ]; then
    url="${url}?${qs}"
  fi
  curl -fsS --max-time 20 "$url" 2>/dev/null
}

# Extract .code from flat JSON (no jq required). ADAPT if your shape differs.
json_code() {
  printf '%s' "$1" | sed -n 's/.*"code"[[:space:]]*:[[:space:]]*\(-\{0,1\}[0-9][0-9]*\).*/\1/p' | head -n 1
}

json_token() {
  printf '%s' "$1" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

check() {
  name="$1"; path="$2"; qs="${3:-}"
  if ! body=$(invoke_api "$path" "$qs"); then
    fail=$((fail + 1))
    echo "[FAIL] $name  $path  -> request failed"
    return 0
  fi
  code=$(json_code "$body")
  if [ -z "$code" ]; then
    fail=$((fail + 1))
    echo "[FAIL] $name  $path  -> no 'code' (not API JSON)"
  elif [ "$code" -lt 0 ]; then
    warn=$((warn + 1))
    echo "[WARN] $name  $path  -> code=$code"
  else
    pass=$((pass + 1))
    echo "[PASS] $name  $path"
  fi
}

echo "== Base: $BASE_URL =="

echo ""
echo "-- Public endpoints --"                     # ADAPT list
check "home.info" "/api/website/info" ""

echo ""
echo "-- Login (fixture) --"                      # ADAPT fixture path
token=""
if body=$(invoke_api "/api/testlogin/login" "mobile=$(printf '%s' "$MOBILE" | sed 's/ /%20/g')"); then
  code=$(json_code "$body")
  if [ "$code" = "0" ]; then
    token=$(json_token "$body")
    echo "[PASS] login"
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "[FAIL] login -> cannot get token; skip authed checks"
  fi
else
  fail=$((fail + 1))
  echo "[FAIL] login -> cannot get token; skip authed checks"
fi

if [ -n "$token" ]; then
  echo ""
  echo "-- Authed endpoints --"                 # ADAPT list
  check "user.info" "/api/user/info" "token=$(printf '%s' "$token" | sed 's/ /%20/g')"
fi

echo ""
echo "== Summary: PASS=$pass WARN=$warn FAIL=$fail =="
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
