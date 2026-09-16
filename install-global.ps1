# Bootstrap this kit on a new machine: sync global skills for all AI tools.
# ASCII-only. Copy the whole repo, then run ONCE from kit root:
#   .\install-global.ps1
# Optional: .\install-global.ps1 -KitRoot "D:\path\to\dev-agent-kit"

param(
    [string]$KitRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $KitRoot) {
    $KitRoot = $PSScriptRoot
}
$KitRoot = (Resolve-Path $KitRoot).Path

$skillSrc = Join-Path $KitRoot "skills\scaffold-dev-agent"
$skillMd = Join-Path $skillSrc "SKILL.md"
if (-not (Test-Path $skillMd)) {
    Write-Error "Not a valid kit root (missing skills/scaffold-dev-agent/SKILL.md): $KitRoot"
    exit 1
}

Write-Host "========================================"
Write-Host " dev-agent-kit  install-global"
Write-Host "========================================"
Write-Host ("KIT = " + $KitRoot)
Write-Host ""

$sync = Join-Path $skillSrc "scripts\sync-global-skills.ps1"
& $sync -KitRoot $KitRoot
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Done. On any project, open Cursor/Kiro/WorkBuddy/Qoder/Codex and say:"
Write-Host "  use scaffold-dev-agent to install the development agent and run init-workflow"
Write-Host ""
Write-Host "kit-path.txt in each skills dir points to this KIT (no need to paste the path)."
Write-Host "After you edit the skill in this repo, re-run: .\install-global.ps1"
exit 0
