# Cursor stop hook. ASCII only, no BOM. Fail-open.
# Intentionally silent. Do NOT print followup_message.
# Cursor submits followup_message as a user turn: it lands in the composer and
# starts another agent loop. On a dirty multi-git tree that becomes a long
# auto-sent bubble (IDE meta, upgrade SQL, hundreds of unrelated files).
# SSOT freshness is scripts/verify (WARN), not a chat injection.
$ErrorActionPreference = "SilentlyContinue"
[void][Console]::In.ReadToEnd()
exit 0
