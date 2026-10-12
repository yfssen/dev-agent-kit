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

$wbSkill = Join-Path $env:USERPROFILE ".workbuddy\skills\scaffold-dev-agent\SKILL.md"
Write-Host ""
Write-Host "Done."
Write-Host "Cursor / Claude / Codex / Kiro / Qoder, say:"
Write-Host "  use scaffold-dev-agent and read init-workflow.md"
Write-Host ""
Write-Host "WorkBuddy: do not say only the skill name. It searches the marketplace and reports not found."
Write-Host "Send the WorkBuddy sentence in the tools guide, section 2A. The file is:"
Write-Host "  $wbSkill"
Write-Host "init-workflow.md is the sibling file, not a second skill."
Write-Host ""
Write-Host "kit-path.txt in each skills dir points to this KIT (no need to paste the path)."
Write-Host "After you edit the skill in this repo, re-run: .\install-global.ps1"
exit 0
