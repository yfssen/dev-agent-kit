# Install core + adapters. Never overwrite existing files unless -Force.
# Existing dest -> write sibling "*.kit-new" and report MERGE.
# Usage: .\install.ps1 -KitRoot <kit> -ProjectRoot <proj> [-Adapters cursor,claude,kiro] [-Force]

param(
    [Parameter(Mandatory = $true)][string]$KitRoot,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$Adapters = "cursor,claude,kiro",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$KitRoot = (Resolve-Path $KitRoot).Path
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$script:added = 0
$script:merged = 0
$script:skippedSame = 0
$script:mergeList = New-Object System.Collections.Generic.List[string]

function Ensure-Dir([string]$p) {
    New-Item -ItemType Directory -Force -Path $p | Out-Null
}

function Install-File([string]$src, [string]$dest) {
    if (-not (Test-Path $src)) {
        Write-Host "[MISS] source missing: $src"
        return
    }
    Ensure-Dir (Split-Path $dest -Parent)
    if (-not (Test-Path $dest)) {
        Copy-Item $src $dest
        Write-Host "[NEW]  $dest"
        $script:added++
        return
    }
    if ($Force) {
        Copy-Item $src $dest -Force
        Write-Host "[FORCE] $dest"
        $script:added++
        return
    }
    $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
    $dstHash = (Get-FileHash $dest -Algorithm SHA256).Hash
    if ($srcHash -eq $dstHash) {
        Write-Host "[SAME] $dest"
        $script:skippedSame++
        return
    }
    $incoming = "$dest.kit-new"
    Copy-Item $src $incoming -Force
    Write-Host "[MERGE] exists -> wrote $incoming (read both, then merge)"
    $script:merged++
    $script:mergeList.Add($dest) | Out-Null
}

Write-Host "KIT=$KitRoot"
Write-Host "PROJECT=$ProjectRoot"
Write-Host "MODE=$(if ($Force) { 'FORCE overwrite' } else { 'merge-safe (no overwrite)' })"

Ensure-Dir (Join-Path $ProjectRoot "docs")
Ensure-Dir (Join-Path $ProjectRoot "scripts")

Install-File (Join-Path $KitRoot "templates\AGENTS.md") (Join-Path $ProjectRoot "AGENTS.md")

$docsSrc = Join-Path $KitRoot "templates\docs"
Get-ChildItem $docsSrc -File -ErrorAction SilentlyContinue | ForEach-Object {
    Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot "docs") $_.Name)
}

$scriptsSrc = Join-Path $KitRoot "templates\scripts"
Get-ChildItem $scriptsSrc -File -ErrorAction SilentlyContinue | ForEach-Object {
    Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot "scripts") $_.Name)
}

$wanted = @($Adapters.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

foreach ($a in $wanted) {
    switch ($a) {
        "cursor" {
            Ensure-Dir (Join-Path $ProjectRoot ".cursor\rules")
            Get-ChildItem (Join-Path $KitRoot "adapters\cursor") -Filter *.mdc -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".cursor\rules") $_.Name)
            }
            Write-Host "[OK] adapter cursor"
        }
        "claude" {
            Install-File (Join-Path $KitRoot "adapters\claude\CLAUDE.md") (Join-Path $ProjectRoot "CLAUDE.md")
            Write-Host "[OK] adapter claude"
        }
        "codex" {
            Write-Host "[OK] adapter codex (AGENTS.md is enough)"
        }
        "kiro" {
            Ensure-Dir (Join-Path $ProjectRoot ".kiro\steering")
            Get-ChildItem (Join-Path $KitRoot "adapters\kiro\steering") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".kiro\steering") $_.Name)
            }
            Write-Host "[OK] adapter kiro"
        }
        { $_ -in @("workbuddy", "codebuddy") } {
            Install-File (Join-Path $KitRoot "adapters\workbuddy\CODEBUDDY.md") (Join-Path $ProjectRoot "CODEBUDDY.md")
            Ensure-Dir (Join-Path $ProjectRoot ".codebuddy\rules")
            Get-ChildItem (Join-Path $KitRoot "adapters\workbuddy\rules") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".codebuddy\rules") $_.Name)
            }
            Write-Host "[OK] adapter workbuddy/codebuddy"
        }
        "qoder" {
            Ensure-Dir (Join-Path $ProjectRoot ".qoder\rules")
            Get-ChildItem (Join-Path $KitRoot "adapters\qoder\rules") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".qoder\rules") $_.Name)
            }
            Write-Host "[OK] adapter qoder (AGENTS.md + .qoder/rules)"
        }
        default {
            Write-Host "[SKIP] unknown adapter: $a"
        }
    }
}

Write-Host ""
Write-Host "== Summary: NEW/FORCE=$added MERGE_NEEDED=$merged SAME=$skippedSame =="
if ($mergeList.Count -gt 0) {
    Write-Host "Merge these (read existing + *.kit-new, keep project facts, add kit tooling):"
    foreach ($m in $mergeList) { Write-Host "  - $m" }
    Write-Host "After merge, delete the sibling *.kit-new files."
    exit 2
}
Write-Host "Next: fill placeholders / # ADAPT if still templated."
exit 0
