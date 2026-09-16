# [scan-project] Structural scan for init workflow. ASCII-only. No secrets.
# Usage: ./scripts/scan-project.ps1 [-Root <path>] [-OutFile docs/_scan-raw.md]

param(
    [string]$Root = "",
    [string]$OutFile = ""
)

if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$Root = (Resolve-Path $Root).Path

$lines = New-Object System.Collections.Generic.List[string]
function L([string]$s) { $script:lines.Add($s) | Out-Null }

L "# scan-project raw"
L ""
L ("- root: " + $Root)
L ("- scanned_at: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
L ("- root_has_git: " + (Test-Path (Join-Path $Root ".git")))
L ""

# Top-level entries
L "## Top-level"
Get-ChildItem $Root -Force | Where-Object { $_.Name -notmatch '^\.git$' } | ForEach-Object {
    $kind = if ($_.PSIsContainer) { "dir" } else { "file" }
    $git = ""
    if ($_.PSIsContainer -and (Test-Path (Join-Path $_.FullName ".git"))) { $git = " [git]" }
    L ("- " + $kind + ": " + $_.Name + $git)
}
L ""

# Dual-git heuristic
$gitKids = @(Get-ChildItem $Root -Directory -Force | Where-Object { Test-Path (Join-Path $_.FullName ".git") })
L "## Dual-git heuristic"
if ($gitKids.Count -ge 2) {
    L ("- likely_dual_git: yes (" + $gitKids.Count + " child repos)")
    foreach ($g in $gitKids) { L ("  - " + $g.Name) }
} elseif ($gitKids.Count -eq 1) {
    L ("- likely_dual_git: maybe (1 child git: " + $gitKids[0].Name + ")")
} else {
    L "- likely_dual_git: no child .git found (or single-repo at root)"
}
L ""

# Stack signals
$signals = @(
    @{ name = "node/package.json"; rel = "package.json" },
    @{ name = "php/composer.json"; rel = "composer.json" },
    @{ name = "python/requirements.txt"; rel = "requirements.txt" },
    @{ name = "python/pyproject.toml"; rel = "pyproject.toml" },
    @{ name = "java/pom.xml"; rel = "pom.xml" },
    @{ name = "dotnet/*.csproj"; rel = "*.csproj" },
    @{ name = "go/go.mod"; rel = "go.mod" },
    @{ name = "env/.env"; rel = ".env" },
    @{ name = "env/.env.example"; rel = ".env.example" }
)

L "## Stack signals (depth <= 3)"
foreach ($sig in $signals) {
    $hits = @(Get-ChildItem $Root -Recurse -File -Filter ($sig.rel) -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\node_modules\\|\\vendor\\|\\dist\\|\\unpackage\\' } |
        Select-Object -First 8)
    if ($hits.Count -gt 0) {
        L ("### " + $sig.name)
        foreach ($h in $hits) {
            $rel = $h.FullName.Substring($Root.Length).TrimStart('\', '/')
            L ("- " + $rel)
        }
    }
}
L ""

# Name heuristics for fe/be
L "## Name heuristics"
$feHints = @("frontend", "front", "web", "uniapp", "uni-app", "client", "h5", "admin-web", "app")
$beHints = @("backend", "back", "server", "api", "service", "thinkphp", "tp", "admin", "application")
$dirs = @(Get-ChildItem $Root -Directory)
foreach ($d in $dirs) {
    $n = $d.Name.ToLower()
    $tags = @()
    foreach ($h in $feHints) { if ($n -match [regex]::Escape($h)) { $tags += "frontend?"; break } }
    foreach ($h in $beHints) { if ($n -match [regex]::Escape($h)) { $tags += "backend?"; break } }
    if ($tags.Count -gt 0) { L ("- " + $d.Name + " -> " + ($tags -join ",")) }
}
L ""
L "## Next"
L "- Agent: fill docs/project-architecture.md (CN filename in templates/docs) from code + this scan"
L "- ADAPT scripts .env path if dual-git (often <backend>/.env)"

$text = ($lines -join "`n") + "`n"
Write-Host $text
if ($OutFile) {
    if (-not [System.IO.Path]::IsPathRooted($OutFile)) {
        $OutFile = Join-Path $Root $OutFile
    }
    $dir = Split-Path $OutFile -Parent
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Content -Path $OutFile -Value $text -Encoding utf8
    Write-Host ("Wrote " + $OutFile)
}
