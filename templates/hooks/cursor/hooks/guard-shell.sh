#!/usr/bin/env bash
# Cursor beforeShellExecution guard (POSIX). ASCII only, no BOM. Fail-open.
# Returns permission=ask on risky commands. ADAPT patterns for your stack.
set +e
raw="$(cat)"

allow() { printf '{ "permission": "allow" }\n'; exit 0; }
ask() {
  printf '{ "permission": "ask", "user_message": "%s", "agent_message": "A dev-agent-kit hook flagged this command for review." }\n' "$1"
  exit 0
}

[ -z "$raw" ] && allow

cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$raw" | jq -r '.command // .tool_input.command // empty' 2>/dev/null)"
fi
[ -z "$cmd" ] && cmd="$raw"   # fallback: scan the whole payload

shopt -s nocasematch
if [[ "$cmd" =~ git[[:space:]]+push ]]; then
  ask "About to git push. Review branch and remote before continuing."
fi
if [[ "$cmd" =~ git[[:space:]]+reset[[:space:]]+--hard ]] || [[ "$cmd" =~ git[[:space:]]+clean[[:space:]]+-[a-z]*f ]]; then
  ask "Destructive git command. This can discard local work."
fi
if [[ "$cmd" =~ rm[[:space:]]+-[a-z]*r[a-z]*f ]] || [[ "$cmd" =~ rm[[:space:]]+-[a-z]*f[a-z]*r ]]; then
  ask "Recursive delete. Confirm the target path first."
fi
if [[ "$cmd" =~ (drop[[:space:]]+table|truncate[[:space:]]+table|delete[[:space:]]+from|alter[[:space:]]+table) ]]; then
  ask "Command contains a destructive SQL write. Confirm, and log writes in docs."
fi
if [[ "$cmd" =~ (mysql|mariadb)[[:space:]].*(-e|--execute) ]]; then
  ask "Direct mysql execution. Writes must be reviewed and recorded in docs."
fi
if [[ "$cmd" =~ \.env ]] && [[ "$cmd" =~ (\>|tee|Set-Content|Out-File) ]]; then
  ask "This may overwrite .env (secrets). Confirm before continuing."
fi

allow
