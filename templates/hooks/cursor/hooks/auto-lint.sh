#!/usr/bin/env bash
# Cursor postToolUse (matcher: Write) auto-lint (POSIX). ASCII only, no BOM.
# Runs project lint after an edit; on a real failure (exit 1) feeds the result
# back as additional_context. exit 2 (checker missing) is skipped, not surfaced.
# ADAPT: edit the extension case below for your stack.
set +e
raw="$(cat)"
[ -z "$raw" ] && exit 0

path=""
if command -v jq >/dev/null 2>&1; then
  path="$(printf '%s' "$raw" | jq -r '.file_path // .path // .filePath // .tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
fi
[ -z "$path" ] && path="$(printf '%s' "$raw" | grep -oE '/[^"]+\.(php|vue|js|ts|sql)' | head -n1)"
[ -z "$path" ] && exit 0

# ADAPT: files to consider. lint.sh skips extensions it cannot parse (default .php only).
case "$path" in
  *.php|*.vue|*.js|*.ts|*.sql) : ;;
  *) exit 0 ;;
esac

lint="./scripts/lint.sh"
[ -f "$lint" ] || exit 0

out="$(bash "$lint" "$path" 2>&1)"
code=$?
stamp="$(date '+%Y-%m-%d %H:%M:%S')"
printf '[%s] exit=%s file=%s\n%s\n' "$stamp" "$code" "$path" "$out" > ./scripts/.lint-last.log 2>/dev/null

if [ "$code" -eq 1 ]; then
  esc="$(printf '%s' "$out" | tr '\r\n' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g' | cut -c1-800)"
  printf '{ "additional_context": "Auto-lint FAILED (exit 1) on %s. Fix before proceeding: %s" }\n' "$path" "$esc"
fi
exit 0
