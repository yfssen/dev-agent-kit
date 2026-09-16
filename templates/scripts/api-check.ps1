# [reconcile] Contract reconciliation: frontend URL calls vs backend controller methods.
# Static code comparison (no network) -> deterministic, reproducible.
# ADAPT: $AppDir/$ApiDir/$AddonDir paths, the frontend url regex, and route shapes for your stack.
#
# Status: OK / NO_METHOD (controller exists, action missing) / NO_CONTROLLER / UNKNOWN
# Usage: ./scripts/api-check.ps1  |  -AppDir <frontend>  |  -All

param(
    [string]$AppDir = "frontend/src",                       # ADAPT
    [string]$ApiDir = "backend/app/api/controller",         # ADAPT
    [string]$AddonDir = "backend/addon",                    # ADAPT (optional plugin dir)
    [switch]$All
)

$root = Split-Path $PSScriptRoot -Parent
$appPath = Join-Path $root $AppDir
$apiPath = Join-Path $root $ApiDir
$addonPath = Join-Path $root $AddonDir
if (-not (Test-Path $appPath)) { Write-Error "AppDir not found: $appPath"; exit 1 }

# Index app/api controllers (case-insensitive): name(lower) -> fullpath
$apiIndex = @{}
if (Test-Path $apiPath) {
    foreach ($f in Get-ChildItem $apiPath -Filter *.php -File) { $apiIndex[$f.BaseName.ToLower()] = $f.FullName }
}

$contentCache = @{}
function Get-Src([string]$path) {
    if (-not $contentCache.ContainsKey($path)) { $contentCache[$path] = (Get-Content $path -Raw -ErrorAction SilentlyContinue) }
    return $contentCache[$path]
}
function Has-Method([string]$path, [string]$action) {
    $txt = Get-Src $path
    if ($null -eq $txt) { return $false }
    return ($txt -imatch ('function\s+' + [regex]::Escape($action) + '\s*\('))   # ADAPT for other langs
}
function Find-AddonCtrl([string]$addon, [string]$ctrl) {
    $dir = Join-Path $addonPath (Join-Path $addon "api\controller")
    if (-not (Test-Path $dir)) { return $null }
    foreach ($f in Get-ChildItem $dir -Filter *.php -File) { if ($f.BaseName.ToLower() -eq $ctrl.ToLower()) { return $f.FullName } }
    return $null
}

$files = Get-ChildItem $appPath -Recurse -Include *.vue, *.js, *.ts -File |
    Where-Object { $_.FullName -notmatch '\\(node_modules|unpackage|uni_modules|dist)\\' }

$seen = @{}; $rows = @()
foreach ($file in $files) {
    $rel = $file.FullName.Substring($root.Length + 1)
    $hits = Select-String -Path $file.FullName -Pattern "url:\s*['""](/[^'""]+)['""]" -AllMatches   # ADAPT regex
    foreach ($h in $hits) {
        foreach ($m in $h.Matches) {
            $u = $m.Groups[1].Value -replace '\?.*$', ''
            if ($u -notmatch '/api/') { continue }
            if ($seen.ContainsKey($u)) { continue }
            $seen[$u] = $true

            $type = $null; $ctrl = $null; $act = $null; $addon = $null
            if ($u -match '^/api/([^/]+)/([^/]+)') { $type = 'api'; $ctrl = $matches[1]; $act = $matches[2] }
            elseif ($u -match '^/([^/]+)/api/([^/]+)/([^/]+)') { $type = 'addon'; $addon = $matches[1]; $ctrl = $matches[2]; $act = $matches[3] }
            else { $rows += [pscustomobject]@{ status = 'UNKNOWN'; url = $u; where = "${rel}:$($h.LineNumber)"; hint = '' }; continue }

            $path = $null
            if ($type -eq 'api') { if ($apiIndex.ContainsKey($ctrl.ToLower())) { $path = $apiIndex[$ctrl.ToLower()] } }
            else { $path = Find-AddonCtrl $addon $ctrl }

            if ($null -eq $path) { $rows += [pscustomobject]@{ status = 'NO_CONTROLLER'; url = $u; where = "${rel}:$($h.LineNumber)"; hint = "controller '$ctrl' not found" } }
            elseif (-not (Has-Method $path $act)) { $rows += [pscustomobject]@{ status = 'NO_METHOD'; url = $u; where = "${rel}:$($h.LineNumber)"; hint = "method '$act' missing" } }
            else { $rows += [pscustomobject]@{ status = 'OK'; url = $u; where = "${rel}:$($h.LineNumber)"; hint = '' } }
        }
    }
}

$ok = @($rows | Where-Object { $_.status -eq 'OK' })
$nm = @($rows | Where-Object { $_.status -eq 'NO_METHOD' })
$nc = @($rows | Where-Object { $_.status -eq 'NO_CONTROLLER' })
$uk = @($rows | Where-Object { $_.status -eq 'UNKNOWN' })

Write-Host "== API check: $AppDir ==`n"
if ($All -and $ok.Count -gt 0) { Write-Host "-- OK --" -ForegroundColor Green; foreach ($r in $ok) { Write-Host ("[OK]   " + $r.url + "   (" + $r.where + ")") -ForegroundColor Green }; Write-Host "" }
if ($nm.Count -gt 0) { Write-Host "-- NO_METHOD --" -ForegroundColor Yellow; foreach ($r in $nm) { Write-Host ("[NM]   " + $r.url + "   -> " + $r.hint + "   (" + $r.where + ")") -ForegroundColor Yellow }; Write-Host "" }
if ($nc.Count -gt 0) { Write-Host "-- NO_CONTROLLER --" -ForegroundColor Red; foreach ($r in $nc) { Write-Host ("[NC]   " + $r.url + "   -> " + $r.hint + "   (" + $r.where + ")") -ForegroundColor Red }; Write-Host "" }
if ($uk.Count -gt 0) { Write-Host "-- UNKNOWN --" -ForegroundColor DarkGray; foreach ($r in $uk) { Write-Host ("[??]   " + $r.url + "   (" + $r.where + ")") -ForegroundColor DarkGray }; Write-Host "" }

$summary = "== Summary: OK=" + $ok.Count + " NO_METHOD=" + $nm.Count + " NO_CONTROLLER=" + $nc.Count + " UNKNOWN=" + $uk.Count + " =="
Write-Host $summary
Write-Output $summary
if (($nm.Count + $nc.Count) -gt 0) { exit 1 }
exit 0
