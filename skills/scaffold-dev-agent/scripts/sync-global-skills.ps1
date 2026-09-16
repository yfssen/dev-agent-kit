# Sync scaffold-dev-agent skill into each AI tool's global skills dir.
# ASCII-only. Run after editing skills/scaffold-dev-agent/.
# Usage: .\sync-global-skills.ps1

param(
    [string]$KitRoot = ""
)

$ErrorActionPreference = "Stop"
if (-not $KitRoot) {
    $KitRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$KitRoot = (Resolve-Path $KitRoot).Path
$src = Join-Path $KitRoot "skills\scaffold-dev-agent"
if (-not (Test-Path (Join-Path $src "SKILL.md"))) {
    Write-Error "SKILL.md not found under $src"
    exit 1
}

$up = $env:USERPROFILE
$targets = @(
    (Join-Path $up ".cursor\skills\scaffold-dev-agent"),
    (Join-Path $up ".kiro\skills\scaffold-dev-agent"),
    (Join-Path $up ".agents\skills\scaffold-dev-agent"),
    (Join-Path $up ".claude\skills\scaffold-dev-agent"),
    (Join-Path $up ".codebuddy\skills\scaffold-dev-agent"),
    (Join-Path $up ".workbuddy\skills\scaffold-dev-agent"),
    (Join-Path $up ".qoder\skills\scaffold-dev-agent"),
    (Join-Path $up ".codex\skills\scaffold-dev-agent")
)

foreach ($dest in $targets) {
    New-Item -ItemType Directory -Force -Path (Join-Path $dest "scripts") | Out-Null
    Copy-Item (Join-Path $src "SKILL.md") $dest -Force
    Copy-Item (Join-Path $src "adapter-map.md") $dest -Force
    Copy-Item (Join-Path $src "init-workflow.md") $dest -Force
    Copy-Item (Join-Path $src "scripts\*") (Join-Path $dest "scripts") -Force
    Set-Content -Path (Join-Path $dest "kit-path.txt") -Value $KitRoot -Encoding ascii
    Write-Host "[OK] $dest"
}

Write-Host ""
Write-Host "Synced. Each tool can say: use scaffold-dev-agent (kit path from kit-path.txt)."
