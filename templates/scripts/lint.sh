#!/usr/bin/env bash
# [self-check] Syntax/type check helper. See tooling rules.
# Missing dependency -> exit 2 (NOT a false "syntax error"). Real error -> exit 1.
# ADAPT: replace the checker resolution + invocation for your stack.
#   PHP:    php -l "$file"
#   Node:   npx tsc --noEmit
#   Python: ruff check "$target" / mypy "$target"
# Encoding: ASCII-only (no BOM). Put Chinese notes in .md files.

set -eu

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <file-or-dir>" >&2
  exit 2
fi
TARGET="$1"

# --- Resolve checker (example: PHP CLI) ---   # ADAPT
PHP_BIN=""
if [ -n "${LZ_PHP:-}" ] && [ -x "$LZ_PHP" ]; then
  PHP_BIN="$LZ_PHP"
elif command -v php >/dev/null 2>&1; then
  PHP_BIN="php"
fi
if [ -z "$PHP_BIN" ]; then
  echo "checker not found. Set LZ_PHP or add it to PATH. (NOT a syntax error.)" >&2
  exit 2
fi

if [ ! -e "$TARGET" ]; then
  echo "Target not found: $TARGET" >&2
  exit 2
fi

fail=0
count=0
if [ -d "$TARGET" ]; then
  # ADAPT extension: *.php
  while IFS= read -r -d '' f; do
    count=$((count + 1))
    if ! out=$("$PHP_BIN" -l "$f" 2>&1); then
      fail=$((fail + 1))
      printf '%s\n' "$out"
    fi
  done < <(find "$TARGET" -type f -name '*.php' -print0)
else
  count=1
  if ! out=$("$PHP_BIN" -l "$TARGET" 2>&1); then
    fail=$((fail + 1))
    printf '%s\n' "$out"
  fi
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: $count file(s), no errors"
  exit 0
else
  echo "FAIL: $fail file(s) with errors"
  exit 1
fi
