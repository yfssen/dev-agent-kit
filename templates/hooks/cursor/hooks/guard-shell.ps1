# Cursor beforeShellExecution guard. ASCII only, no BOM.
# Turns "please do not push / do not write the DB" from a prompt instruction
# into a deterministic prompt-before-run. Returns permission=ask on risky commands.
# Fail-open: on any parse error, allow (never hard-block the whole shell).
# ADAPT: tune the patterns below for your stack.

$ErrorActionPreference = "SilentlyContinue"
$raw = [Console]::In.ReadToEnd()

function Emit-Allow {
    Write-Output '{ "permission": "allow" }'
    exit 0
}
function Emit-Ask([string]$msg) {
    $o = [ordered]@{
        permission    = "ask"
        user_message  = $msg
        agent_message = "A dev-agent-kit hook flagged this command for review."
    }
    Write-Output ($o | ConvertTo-Json -Compress)
    exit 0
}

if (-not $raw) { Emit-Allow }
try { $j = $raw | ConvertFrom-Json } catch { Emit-Allow }

$cmd = ""
if ($j.command) { $cmd = [string]$j.command }
elseif ($j.tool_input -and $j.tool_input.command) { $cmd = [string]$j.tool_input.command }
if (-not $cmd) { Emit-Allow }

$c = $cmd

if ($c -match '(?i)git\s+push') {
    Emit-Ask "About to 'git push'. Review branch and remote before continuing."
}
if ($c -match '(?i)git\s+reset\s+--hard' -or $c -match '(?i)git\s+clean\s+-[a-z]*f') {
    Emit-Ask "Destructive git command. This can discard local work."
}
if ($c -match '(?i)rm\s+-[a-z]*r[a-z]*f' -or $c -match '(?i)rm\s+-[a-z]*f[a-z]*r' -or $c -match '(?i)Remove-Item[^\r\n]*-Recurse') {
    Emit-Ask "Recursive delete. Confirm the target path first."
}
if ($c -match '(?i)(drop\s+table|truncate\s+table|truncate\s+|delete\s+from|alter\s+table)') {
    Emit-Ask "Command contains a destructive SQL write. Confirm, and log writes in docs."
}
if ($c -match '(?i)(mysql|mariadb)\b[^\r\n]*(-e|--execute)') {
    Emit-Ask "Direct mysql execution. Writes must be reviewed and recorded in docs."
}
if (($c -match '(?i)\.env\b') -and ($c -match '(>|Set-Content|Out-File|Add-Content)')) {
    Emit-Ask "This may overwrite .env (secrets). Confirm before continuing."
}

Emit-Allow
