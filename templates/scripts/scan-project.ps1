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

# Recent churn (helps locate logic without dumping the tree)
L "## Git hot files (last 20 commits, top 12)"
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    L "- skipped: git not on PATH"
} else {
    # Root itself, else exactly one child with .git (parent workspace / dual-git).
    # git -C is OK here: PowerShell passes a native Windows path, not msys /e/...
    $repo = $null
    $global:LASTEXITCODE = $null
    git -C $Root rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($global:LASTEXITCODE -eq 0) {
        $repo = $Root
    } else {
        $childRepos = @(Get-ChildItem $Root -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName ".git") })
        if ($childRepos.Count -eq 1) { $repo = $childRepos[0].FullName }
    }
    if (-not $repo) {
        L "- skipped: root is not a git work tree and no single child repo found"
    } else {
        $repoRel = if ($repo -eq $Root) { "." } else { $repo.Substring($Root.Length).TrimStart('\', '/') }
        L ("- repo: " + $repoRel)
        $names = @(git -C $repo -c core.quotepath=false log -20 --name-only --pretty=format: 2>$null | Where-Object { $_ })
        $counts = @{}
        foreach ($n in $names) {
            if (-not $counts.ContainsKey($n)) { $counts[$n] = 0 }
            $counts[$n]++
        }
        $top = @($counts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 12)
        if ($top.Count -eq 0) { L "- none (empty log)" }
        else { foreach ($e in $top) { L ("- " + $e.Value + " " + $e.Key) } }
    }
}
L ""
L "## Next"
L "- Agent: fill docs/project-architecture.md (CN filename in templates/docs) from code + this scan"
L "- ADAPT scripts .env path if dual-git (often <backend>/.env)"
L "- Do not paste this whole dump into chat; grep the section you need"

$text = ($lines -join "`n") + "`n"
Write-Host $text
if ($OutFile) {
    if (-not [System.IO.Path]::IsPathRooted($OutFile)) {
        $OutFile = Join-Path $Root $OutFile
    }
    $dir = Split-Path $OutFile -Parent
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    # Write UTF-8 WITHOUT BOM: PowerShell 5.1 "-Encoding utf8" emits a BOM,
    # which violates the project rule "UTF-8 without BOM".
    [System.IO.File]::WriteAllText($OutFile, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("Wrote " + $OutFile)
}
