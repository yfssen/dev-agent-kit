#!/usr/bin/env bash
# [reconcile] Contract reconciliation: frontend URL calls vs backend controller methods.
# Static code comparison (no network) -> deterministic, reproducible.
# ADAPT: APP_DIR/API_DIR/ADDON_DIR paths, the frontend url regex, and route shapes.
# Status: OK / NO_METHOD / NO_CONTROLLER / UNKNOWN
# Usage: ./scripts/api-check.sh  |  APP_DIR=... ./scripts/api-check.sh
# Encoding: ASCII-only (no BOM). Put Chinese notes in .md files.

set -eu

APP_DIR="${APP_DIR:-frontend/src}"                       # ADAPT
API_DIR="${API_DIR:-backend/app/api/controller}"         # ADAPT
ADDON_DIR="${ADDON_DIR:-backend/addon}"                  # ADAPT
SHOW_ALL="${ALL:-0}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_PATH="$ROOT/$APP_DIR"
API_PATH="$ROOT/$API_DIR"
ADDON_PATH="$ROOT/$ADDON_DIR"

if [ ! -d "$APP_PATH" ]; then
  echo "AppDir not found: $APP_PATH" >&2
  exit 1
fi

# Temporary files for rows
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
: >"$TMP/rows"

# Index api controllers: name(lower)|fullpath
: >"$TMP/api_index"
if [ -d "$API_PATH" ]; then
  for f in "$API_PATH"/*.php; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .php)
    lower=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    printf '%s|%s\n' "$lower" "$f" >>"$TMP/api_index"
  done
fi

has_method() {
  path="$1"; action="$2"
  grep -Eq "function[[:space:]]+${action}[[:space:]]*\(" "$path" 2>/dev/null
}

find_addon_ctrl() {
  addon="$1"; ctrl="$2"
  dir="$ADDON_PATH/$addon/api/controller"
  [ -d "$dir" ] || return 1
  for f in "$dir"/*.php; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .php)
    lower=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    cl=$(printf '%s' "$ctrl" | tr '[:upper:]' '[:lower:]')
    if [ "$lower" = "$cl" ]; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
}

lookup_api() {
  ctrl_l=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  while IFS='|' read -r name path; do
    if [ "$name" = "$ctrl_l" ]; then
      printf '%s' "$path"
      return 0
    fi
  done <"$TMP/api_index"
  return 1
}

seen_file="$TMP/seen"
: >"$seen_file"

# Scan frontend for url: '/...'
while IFS= read -r -d '' file; do
  rel=${file#"$ROOT"/}
  # portable line numbers via grep -n
  grep -nE "url:[[:space:]]*['\"]/[^'\"]+['\"]" "$file" 2>/dev/null | while IFS= read -r hit; do
    line_no=${hit%%:*}
    rest=${hit#*:}
    url=$(printf '%s' "$rest" | sed -n "s/.*url:[[:space:]]*['\"]\\([^'\"]*\\)['\"].*/\\1/p")
    url=${url%%\?*}
    case "$url" in
      */api/*) ;;
      *) continue ;;
    esac
    if grep -Fxq "$url" "$seen_file" 2>/dev/null; then
      continue
    fi
    echo "$url" >>"$seen_file"

    type=""; ctrl=""; act=""; addon=""
    if printf '%s' "$url" | grep -Eq '^/api/[^/]+/[^/]+'; then
      type=api
      ctrl=$(printf '%s' "$url" | sed -n 's|^/api/\([^/]*\)/.*|\1|p')
      act=$(printf '%s' "$url" | sed -n 's|^/api/[^/]*/\([^/]*\).*|\1|p')
    elif printf '%s' "$url" | grep -Eq '^/[^/]+/api/[^/]+/[^/]+'; then
      type=addon
      addon=$(printf '%s' "$url" | sed -n 's|^/\([^/]*\)/api/.*|\1|p')
      ctrl=$(printf '%s' "$url" | sed -n 's|^/[^/]*/api/\([^/]*\)/.*|\1|p')
      act=$(printf '%s' "$url" | sed -n 's|^/[^/]*/api/[^/]*/\([^/]*\).*|\1|p')
    else
      printf 'UNKNOWN\t%s\t%s:%s\t\n' "$url" "$rel" "$line_no" >>"$TMP/rows"
      continue
    fi

    path=""
    if [ "$type" = "api" ]; then
      path=$(lookup_api "$ctrl" || true)
    else
      path=$(find_addon_ctrl "$addon" "$ctrl" || true)
    fi

    if [ -z "$path" ]; then
      printf 'NO_CONTROLLER\t%s\t%s:%s\tcontroller %s not found\n' "$url" "$rel" "$line_no" "$ctrl" >>"$TMP/rows"
    elif ! has_method "$path" "$act"; then
      printf 'NO_METHOD\t%s\t%s:%s\tmethod %s missing\n' "$url" "$rel" "$line_no" "$act" >>"$TMP/rows"
    else
      printf 'OK\t%s\t%s:%s\t\n' "$url" "$rel" "$line_no" >>"$TMP/rows"
    fi
  done
done < <(find "$APP_PATH" -type f \( -name '*.vue' -o -name '*.js' -o -name '*.ts' \) \
  ! -path '*/node_modules/*' ! -path '*/unpackage/*' ! -path '*/uni_modules/*' ! -path '*/dist/*' -print0)

ok=0; nm=0; nc=0; uk=0
while IFS=$'\t' read -r st url where hint || [ -n "${st:-}" ]; do
  [ -z "${st:-}" ] && continue
  case "$st" in
    OK) ok=$((ok + 1)) ;;
    NO_METHOD) nm=$((nm + 1)) ;;
    NO_CONTROLLER) nc=$((nc + 1)) ;;
    UNKNOWN) uk=$((uk + 1)) ;;
  esac
done <"$TMP/rows"

echo "== API check: $APP_DIR =="
echo ""

if [ "$SHOW_ALL" = "1" ] && [ "$ok" -gt 0 ]; then
  echo "-- OK --"
  awk -F'\t' '$1=="OK"{print "[OK]   " $2 "   (" $3 ")"}' "$TMP/rows"
  echo ""
fi
if [ "$nm" -gt 0 ]; then
  echo "-- NO_METHOD --"
  awk -F'\t' '$1=="NO_METHOD"{print "[NM]   " $2 "   -> " $4 "   (" $3 ")"}' "$TMP/rows"
  echo ""
fi
if [ "$nc" -gt 0 ]; then
  echo "-- NO_CONTROLLER --"
  awk -F'\t' '$1=="NO_CONTROLLER"{print "[NC]   " $2 "   -> " $4 "   (" $3 ")"}' "$TMP/rows"
  echo ""
fi
if [ "$uk" -gt 0 ]; then
  echo "-- UNKNOWN --"
  awk -F'\t' '$1=="UNKNOWN"{print "[??]   " $2 "   (" $3 ")"}' "$TMP/rows"
  echo ""
fi

echo "== Summary: OK=$ok NO_METHOD=$nm NO_CONTROLLER=$nc UNKNOWN=$uk =="
if [ $((nm + nc)) -gt 0 ]; then
  exit 1
fi
exit 0
