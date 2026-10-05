# Cursor stop SSOT reminder. ASCII only, no BOM. Fail-open, cooldown-throttled.
# When a turn ends with code changed but docs/*.md (SSOT) untouched, nudge once
# (via followup_message) to update the SSOT -- so cross-session memory stays in
# sync with the code without relying on the agent to remember.
# ADAPT: edit $exts for your stack; tune $cooldownSec.

$ErrorActionPreference = "SilentlyContinue"
[void][Console]::In.ReadToEnd()

$exts = @('.php')      # ADAPT
$cooldownSec = 1200    # min seconds between nudges (20 min); avoids per-turn nagging

$proj = (Get-Location).Path
if (-not (Test-Path (Join-Path $proj 'docs'))) { exit 0 }

# Must be inside a git work tree.
& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

$porcelain = @(& git status --porcelain 2>$null)
if (-not $porcelain -or $porcelain.Count -eq 0) { exit 0 }

$codeFiles = New-Object System.Collections.Generic.List[string]
$docsTouched = $false
foreach ($line in $porcelain) {
    if ($line.Length -lt 4) { continue }
    $p = $line.Substring(3).Trim()
    if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1] }
    $p = $p.Trim('"')
    $norm = $p -replace '\\', '/'
    # Only top-level docs/*.md counts as SSOT (exclude docs/.ssot-backups/..).
    if ($norm -match '^docs/[^/]+\.md$') { $docsTouched = $true; continue }
    $ext = [System.IO.Path]::GetExtension($norm).ToLower()
    if ($exts -contains $ext) { [void]$codeFiles.Add($norm) }
}

if ($codeFiles.Count -eq 0 -or $docsTouched) { exit 0 }

# Cooldown throttle via state file.
$state = Join-Path $proj '.cursor/hooks/.ssot-nudge-last'
$now = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
if (Test-Path $state) {
    $last = 0
    [int]::TryParse((Get-Content $state -Raw).Trim(), [ref]$last) | Out-Null
    if (($now - $last) -lt $cooldownSec) { exit 0 }
}
Set-Content -Path $state -Value $now -Encoding ascii

$sample = ($codeFiles | Select-Object -First 5) -join ', '
$more = if ($codeFiles.Count -gt 5) { " (+" + ($codeFiles.Count - 5) + " more)" } else { "" }
$msg = "SSOT check: code changed this session (" + $codeFiles.Count + " file(s): " + $sample + $more + ") but docs/*.md (SSOT) was not updated. If this affects progress/architecture/CRUD, update the relevant docs/*.md now; otherwise state briefly that no SSOT change is needed."
Write-Output (@{ followup_message = $msg } | ConvertTo-Json -Compress)
exit 0
