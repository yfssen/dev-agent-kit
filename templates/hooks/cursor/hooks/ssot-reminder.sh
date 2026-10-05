#!/usr/bin/env bash
# Cursor stop SSOT reminder (POSIX). ASCII only, no BOM. Fail-open, throttled.
# When a turn ends with code changed but docs/*.md (SSOT) untouched, nudge once
# (via followup_message) to keep cross-session memory in sync with the code.
# ADAPT: edit the code-extension case and cooldown_sec.
set +e
cat >/dev/null 2>&1

cooldown_sec=1200   # min seconds between nudges (20 min)
[ -d "./docs" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

status="$(git status --porcelain 2>/dev/null)"
[ -z "$status" ] && exit 0

code_count=0
code_sample=""
docs_touched=0
while IFS= read -r line; do
  [ ${#line} -ge 4 ] || continue
  p="${line:3}"
  case "$p" in *" -> "*) p="${p##* -> }";; esac
  p="${p%\"}"; p="${p#\"}"
  # Only top-level docs/*.md counts as SSOT (exclude docs/.ssot-backups/..).
  case "$p" in
    docs/*/*) ;;                      # nested under docs/, ignore
    docs/*.md) docs_touched=1; continue;;
  esac
  case "$p" in
    *.php)   # ADAPT
      code_count=$((code_count + 1))
      if [ "$code_count" -le 5 ]; then
        if [ -z "$code_sample" ]; then code_sample="$p"; else code_sample="$code_sample, $p"; fi
      fi
      ;;
  esac
done <<EOF
$status
EOF

[ "$code_count" -gt 0 ] || exit 0
[ "$docs_touched" -eq 0 ] || exit 0

state="./.cursor/hooks/.ssot-nudge-last"
now="$(date +%s)"
if [ -f "$state" ]; then
  last="$(cat "$state" 2>/dev/null)"
  case "$last" in ''|*[!0-9]*) last=0;; esac
  if [ $((now - last)) -lt "$cooldown_sec" ]; then exit 0; fi
fi
printf '%s' "$now" > "$state" 2>/dev/null

more=""
if [ "$code_count" -gt 5 ]; then more=" (+$((code_count - 5)) more)"; fi
msg="SSOT check: code changed this session ($code_count file(s): $code_sample$more) but docs/*.md (SSOT) was not updated. If this affects progress/architecture/CRUD, update the relevant docs/*.md now; otherwise state briefly that no SSOT change is needed."
msg_esc=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{ "followup_message": "%s" }\n' "$msg_esc"
exit 0
