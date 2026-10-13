# [verify] One-command closed-loop gate: lint changed files + api-check (static)
# + SSOT freshness (+ optional smoke), then a single PASS/FAIL -- the "definition
# of done" the agent must pass before claiming a task is finished.
# Each sub-check is PASS / FAIL / SKIP / WARN. Only FAIL fails the gate (exit 1).
# Done: yes only when Result is PASS and WARN=0. A WARN still exits 0 and prints Done: no.
# Missing script / missing checker / unconfigured paths -> SKIP (not FAIL), so an
# unconfigured project still runs cleanly. Encoding: ASCII-only (no BOM).
# ADAPT: $exts, $BaseUrl, and $ProbePath (must match smoke.ps1's first public endpoint).
# Usage: ./scripts/verify.ps1 [-Target <path>] [-Full] [-BaseUrl <url>] [-SsotStrict]
# Smoke probe: GET $BaseUrl$ProbePath. Only run smoke if the body looks like this
# project's API JSON ("code"). A random HTTP service on the same port (phpstudy,
# nginx default site, ...) is SKIP, not FAIL -- otherwise the done-gate wedges.

param(
    [string]$Target,                                 # lint this path instead of git-changed files
    [switch]$Full,                                   # run smoke even if server probe fails
    [string]$BaseUrl = "http://localhost:8080",      # ADAPT: passthrough to smoke
    [switch]$SsotStrict                              # treat stale SSOT as FAIL (default: WARN)
)

$root = Split-Path $PSScriptRoot -Parent
$ProbePath = "/api/website/info"   # ADAPT: keep in sync with smoke.ps1 first public endpoint
$layout = Join-Path $PSScriptRoot 'kit-layout.ps1'
if (Test-Path $layout) { . $layout }
# Code extensions and multi-git discovery live in kit-layout.ps1 ($KitCodeExts).

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

# --- Collect changed code files (all git repos in the workspace) ---
$changed = New-Object System.Collections.Generic.List[string]
$repos = @()
if (Get-Command Get-KitGitRepos -ErrorAction SilentlyContinue) {
    $repos = @(Get-KitGitRepos $root)
}
$inGit = ($repos.Count -gt 0)
if ($Target) {
    [void]$changed.Add($Target)
} elseif ($inGit) {
    foreach ($p in (Get-KitChangedCode $root)) { [void]$changed.Add($p) }
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

# --- 3) SSOT freshness: workspace-root docs/*.md (mtime or root git), not child-repo docs ---
if ($inGit) {
    $codeRels = @($changed)
    if ($codeRels.Count -eq 0) { Res 'SKIP' 'ssot' 'no code change in any git repo' }
    else {
        $missing = @()
        if (Get-Command Get-KitUnnamedChanges -ErrorAction SilentlyContinue) {
            $missing = @(Get-KitUnnamedChanges $root $codeRels)
        }
        $fresh = Test-KitSsotFresh $root $codeRels
        $named = ($missing.Count -eq 0)
        if ($fresh -and $named) {
            Res 'PASS' 'ssot' 'latest progress row names the changed files'
        } else {
            $detail = 'code changed but workspace-root docs/*.md (SSOT) not updated'
            if ($missing.Count -gt 0) {
                $detail = 'latest progress row must name: ' + ($missing -join ', ')
            }
            if ($SsotStrict) { Res 'FAIL' 'ssot' $detail } else { Res 'WARN' 'ssot' $detail }
        }
    }
} else {
    Res 'SKIP' 'ssot' 'no git repo at workspace root or immediate children'
}

# --- 4) smoke (optional; needs THIS project's server, not "any HTTP on the port") ---
function Get-ProbeKind {
    # Same client family as smoke.ps1 (Invoke-*). Do not use HEAD / empty-proxy
    # HttpWebRequest -- those disagree with Invoke-RestMethod on local php -S.
    $url = $BaseUrl.TrimEnd('/') + $ProbePath
    $body = $null
    try {
        $resp = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        $body = [string]$resp.Content
    } catch {
        $r = $_.Exception.Response
        if (-not $r) { return 'none' }
        try {
            $stream = $r.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
            }
        } catch { $body = '' }
        if ([string]::IsNullOrEmpty($body)) { return 'other' }
    }
    if ($body -match '"code"') { return 'ours' }
    return 'other'
}

$smokeScript = Join-Path $PSScriptRoot 'smoke.ps1'
if (-not (Test-Path $smokeScript)) {
    Res 'SKIP' 'smoke' 'scripts/smoke.ps1 missing'
} else {
    $kind = Get-ProbeKind
    $runSmoke = $false
    if ($Full) { $runSmoke = $true }
    elseif ($kind -eq 'ours') { $runSmoke = $true }
    elseif ($kind -eq 'other') {
        Res 'SKIP' 'smoke' "other HTTP service at $BaseUrl (not this API; use -Full to force)"
    } else {
        Res 'SKIP' 'smoke' "server not reachable at $BaseUrl (use -Full to force)"
    }
    if ($runSmoke) {
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
if ($script:failN -gt 0) {
    Write-Output "== Done: no =="
    Write-Output "Next: fix the first [FAIL] line, then run this command again."
    exit 1
}
if ($script:warnN -gt 0) {
    Write-Output "== Done: no =="
    Write-Output "Next: append one progress row naming the changed files, then run this command again."
    exit 0
}
Write-Output "== Done: yes =="
exit 0
