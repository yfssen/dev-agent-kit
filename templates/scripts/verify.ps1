# [verify] One-command closed-loop gate: lint changed files + api-check (static)
# + SSOT freshness (+ optional smoke), then a single PASS/FAIL -- the "definition
# of done" the agent must pass before claiming a task is finished.
# Each sub-check is PASS / FAIL / SKIP / WARN. Only FAIL fails the gate (exit 1).
# Missing script / missing checker / unconfigured paths -> SKIP (not FAIL), so an
# unconfigured project still runs cleanly. Encoding: ASCII-only (no BOM).
# ADAPT: $exts (changed-code detection) and $BaseUrl (smoke passthrough).
# Usage: ./scripts/verify.ps1 [-Target <path>] [-Full] [-BaseUrl <url>] [-SsotStrict]

param(
    [string]$Target,                                 # lint this path instead of git-changed files
    [switch]$Full,                                   # run smoke even if server probe fails
    [string]$BaseUrl = "http://localhost:8080",      # ADAPT: passthrough to smoke
    [switch]$SsotStrict                              # treat stale SSOT as FAIL (default: WARN)
)

$root = Split-Path $PSScriptRoot -Parent
$exts = @('.php')   # ADAPT

$script:passN = 0; $script:failN = 0; $script:skipN = 0; $script:warnN = 0
$script:lines = New-Object System.Collections.Generic.List[string]
function Res([string]$tag, [string]$name, [string]$detail) {
    switch ($tag) {
        'PASS' { $script:passN++ }
        'FAIL' { $script:failN++ }
        'SKIP' { $script:skipN++ }
        'WARN' { $script:warnN++ }
    }
    $d = if ($detail) { " -- $detail" } else { "" }
    $script:lines.Add("[$tag] $name$d")
}

function Get-AbsPath([string]$rel) {
    if ([string]::IsNullOrWhiteSpace($rel)) { return $null }
    $norm = $rel.Trim().Trim('"') -replace '/', [char][IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::IsPathRooted($norm)) { return $norm }
    return [IO.Path]::GetFullPath((Join-Path $root $norm))
}

function Get-PorcelainRel {
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($l in @(& git -C $root status --porcelain 2>$null)) {
        if ($null -eq $l) { continue }
        $s = [string]$l
        if ($s.Length -lt 4) { continue }
        $p = $s.Substring(3).Trim()
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1] }
        $p = $p.Trim('"')
        if ($p) { [void]$list.Add($p) }
    }
    return $list
}

# --- Collect changed code files (git working tree + staged) ---
$changed = New-Object System.Collections.Generic.List[string]
& git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
$inGit = ($LASTEXITCODE -eq 0)
if ($Target) {
    [void]$changed.Add($Target)
} elseif ($inGit) {
    foreach ($p in (Get-PorcelainRel)) {
        $ext = [IO.Path]::GetExtension($p).ToLower()
        if ($exts -contains $ext) { [void]$changed.Add($p) }
    }
}

# --- 1) lint changed files ---
# Nested powershell so lint.ps1's "exit" cannot kill this gate.
$lintScript = Join-Path $PSScriptRoot 'lint.ps1'
if (-not (Test-Path $lintScript)) {
    Res 'SKIP' 'lint' 'scripts/lint.ps1 missing'
} elseif ($changed.Count -eq 0) {
    Res 'SKIP' 'lint' 'no changed code files'
} else {
    $anyFail = $false; $anySkip = $false; $n = 0
    foreach ($rel in $changed) {
        $abs = Get-AbsPath $rel
        if (-not $abs -or -not (Test-Path -LiteralPath $abs -PathType Leaf)) { continue }
        $n++
        & powershell -NoProfile -ExecutionPolicy Bypass -File $lintScript $abs 2>$null | Out-Null
        switch ($LASTEXITCODE) {
            0 { }
            2 { $anySkip = $true }
            default { $anyFail = $true }
        }
    }
    if ($n -eq 0) { Res 'SKIP' 'lint' 'changed paths missing on disk (deleted?)' }
    elseif ($anyFail) { Res 'FAIL' 'lint' 'syntax errors in changed files; run scripts/lint.ps1 on them' }
    elseif ($anySkip) { Res 'SKIP' 'lint' 'checker missing (set LZ_PHP / add to PATH)' }
    else { Res 'PASS' 'lint' "$n changed file(s) clean" }
}

# --- 2) api-check (static frontend/backend reconcile) ---
$apiScript = Join-Path $PSScriptRoot 'api-check.ps1'
if (-not (Test-Path $apiScript)) {
    Res 'SKIP' 'api-check' 'scripts/api-check.ps1 missing'
} else {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $apiScript 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($out -notmatch '== Summary:') {
        Res 'SKIP' 'api-check' 'did not run (paths not configured?)'
    } elseif ($code -eq 0) {
        Res 'PASS' 'api-check' 'no missing controllers/methods'
    } else {
        Res 'FAIL' 'api-check' 'frontend calls without backend method/controller; run scripts/api-check.ps1'
    }
}

# --- 3) SSOT freshness (code changed but docs/*.md untouched) ---
if ($inGit) {
    $docsTouched = $false; $codeChanged = $false
    foreach ($p in (Get-PorcelainRel)) {
        $norm = $p -replace '\\', '/'
        if ($norm -match '^docs/[^/]+\.md$') { $docsTouched = $true; continue }
        $ext = [IO.Path]::GetExtension($norm).ToLower()
        if ($exts -contains $ext) { $codeChanged = $true }
    }
    if (-not $codeChanged) { Res 'SKIP' 'ssot' 'no code change in working tree' }
    elseif ($docsTouched) { Res 'PASS' 'ssot' 'SSOT updated alongside code' }
    elseif ($SsotStrict) { Res 'FAIL' 'ssot' 'code changed but docs/*.md (SSOT) not updated' }
    else { Res 'WARN' 'ssot' 'code changed but docs/*.md (SSOT) not updated' }
} else {
    Res 'SKIP' 'ssot' 'not a git work tree'
}

# --- 4) smoke (optional; needs a running server) ---
$smokeScript = Join-Path $PSScriptRoot 'smoke.ps1'
if (-not (Test-Path $smokeScript)) {
    Res 'SKIP' 'smoke' 'scripts/smoke.ps1 missing'
} else {
    $reachable = $false
    try {
        $req = [System.Net.WebRequest]::Create($BaseUrl)
        $req.Timeout = 2000; $req.Method = 'HEAD'
        $resp = $req.GetResponse(); $resp.Close(); $reachable = $true
    } catch {
        if ($_.Exception.Response) { $reachable = $true }   # HTTP error still means server is up
    }
    if (-not $reachable -and -not $Full) {
        Res 'SKIP' 'smoke' "server not reachable at $BaseUrl (use -Full to force)"
    } else {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $smokeScript -BaseUrl $BaseUrl 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Res 'PASS' 'smoke' 'endpoints alive' }
        else { Res 'FAIL' 'smoke' 'endpoint failures; run scripts/smoke.ps1' }
    }
}

# --- Verdict (Write-Output so agents/dry-run can capture; Write-Host is invisible to 2>&1 on PS 5.1) ---
Write-Output "== verify =="
foreach ($ln in $script:lines) { Write-Output $ln }
$verdict = if ($script:failN -gt 0) { 'FAIL' } else { 'PASS' }
Write-Output "== Result: $verdict (PASS=$($script:passN) FAIL=$($script:failN) WARN=$($script:warnN) SKIP=$($script:skipN)) =="
if ($script:failN -gt 0) { exit 1 }
exit 0
