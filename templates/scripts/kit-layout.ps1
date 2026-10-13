# Shared workspace layout for verify + ssot-reminder. Dot-source only. ASCII, no BOM.
# SSOT = workspace-root top-level docs/*.md (NOT docs inside child git repos).
# Git repos = workspace if it is a work tree, PLUS each immediate child that has .git
# (same-folder multi-git: admin/, pc_web/, backend/, ...). Root often has no .git.
# ADAPT: $KitCodeExts, $KitRepoNames (empty = auto-discover), $KitSkipDirNames.

if (-not $KitCodeExts) {
    $KitCodeExts = @('.php', '.vue', '.js', '.ts', '.sql')   # ADAPT
}
if (-not $KitRepoNames) {
    $KitRepoNames = @()   # ADAPT: e.g. @('admin','pc_web','backend'); empty = scan children
}
if (-not $KitSkipDirNames) {
    $KitSkipDirNames = @('node_modules', 'vendor', 'dist', 'unpackage', 'uni_modules', '.git')
}

function Get-KitGitRepos([string]$ws) {
    $repos = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    function Add-Repo([string]$p) {
        if (-not $p -or -not (Test-Path $p)) { return }
        $n = [IO.Path]::GetFullPath($p)
        if ($seen.ContainsKey($n)) { return }
        $seen[$n] = $true
        [void]$repos.Add($n)
    }
    & git -C $ws rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Add-Repo $ws }

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($KitRepoNames.Count -gt 0) {
        foreach ($n in $KitRepoNames) { [void]$candidates.Add((Join-Path $ws $n)) }
    } else {
        Get-ChildItem $ws -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            [void]$candidates.Add($_.FullName)
        }
    }
    foreach ($c in $candidates) {
        $leaf = Split-Path $c -Leaf
        if ($KitSkipDirNames -contains $leaf) { continue }
        if (Test-Path (Join-Path $c '.git')) { Add-Repo $c }
    }
    return $repos
}

function Get-KitChangedCode([string]$ws) {
    $list = New-Object System.Collections.Generic.List[string]
    $wsFull = [IO.Path]::GetFullPath($ws)
    foreach ($repo in (Get-KitGitRepos $ws)) {
        $prefix = ''
        $repoFull = [IO.Path]::GetFullPath($repo)
        if ($repoFull -ne $wsFull) {
            $prefix = (Split-Path $repoFull -Leaf) + '/'
        }
        foreach ($l in @(& git -C $repo status --porcelain 2>$null)) {
            if ($null -eq $l) { continue }
            $s = [string]$l
            if ($s.Length -lt 4) { continue }
            $p = $s.Substring(3).Trim()
            if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1] }
            $p = $p.Trim('"')
            $norm = ($p -replace '\\', '/')
            $ext = [IO.Path]::GetExtension($norm).ToLower()
            if ($KitCodeExts -contains $ext) { [void]$list.Add($prefix + $norm) }
        }
    }
    return $list
}

function Get-KitSsotFiles([string]$ws) {
    $dir = Join-Path $ws 'docs'
    if (-not (Test-Path $dir)) { return @() }
    return @(Get-ChildItem $dir -Filter *.md -File -ErrorAction SilentlyContinue)
}

function Test-KitRootSsotInGit([string]$ws) {
    & git -C $ws rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    foreach ($l in @(& git -C $ws status --porcelain 2>$null)) {
        if ($null -eq $l) { continue }
        $s = [string]$l
        if ($s.Length -lt 4) { continue }
        $p = $s.Substring(3).Trim()
        if ($p -match ' -> ') { $p = ($p -split ' -> ')[-1] }
        $norm = ($p.Trim('"') -replace '\\', '/')
        if ($norm -match '^docs/[^/]+\.md$') { return $true }
    }
    return $false
}

# True = SSOT looks updated. False = nudge / WARN.
# A removed path has no mtime. Use the nearest existing parent directory
# (deletion updates that mtime) so a delete-only tree is not "nothing to compare".
function Test-KitSsotFresh([string]$ws, $codeRels) {
    if (Test-KitRootSsotInGit $ws) { return $true }
    # @() so a single string is 1 path, not a char array (.Count would be Length).
    $rels = @()
    if ($null -ne $codeRels) { $rels = @($codeRels) }
    if ($rels.Count -eq 0) { return $true }
    $ssot = @(Get-KitSsotFiles $ws)
    if ($ssot.Count -eq 0) { return $false }

    $maxCode = $null
    $missingUntimed = $false
    foreach ($rel in $rels) {
        $abs = Join-Path $ws (($rel -replace '/', [char][IO.Path]::DirectorySeparatorChar))
        $stamp = $null
        if (Test-Path -LiteralPath $abs) {
            $stamp = (Get-Item -LiteralPath $abs).LastWriteTimeUtc
        } else {
            $dir = Split-Path -Parent $abs
            while ($dir -and -not (Test-Path -LiteralPath $dir)) {
                $parent = Split-Path -Parent $dir
                if (-not $parent -or $parent -eq $dir) { $dir = $null; break }
                $dir = $parent
            }
            if ($dir -and (Test-Path -LiteralPath $dir)) {
                $stamp = (Get-Item -LiteralPath $dir).LastWriteTimeUtc
            }
            if ($null -eq $stamp) { $missingUntimed = $true }
        }
        if ($null -ne $stamp -and ($null -eq $maxCode -or $stamp -gt $maxCode)) { $maxCode = $stamp }
    }
    if ($missingUntimed -and $null -eq $maxCode) { return $false }
    if ($null -eq $maxCode) { return $true }

    $maxSsot = $null
    foreach ($f in $ssot) {
        if ($null -eq $maxSsot -or $f.LastWriteTimeUtc -gt $maxSsot) { $maxSsot = $f.LastWriteTimeUtc }
    }
    return ($maxSsot -ge $maxCode.AddSeconds(-2))
}

# Section heading bytes stay ASCII in this file. The chars are the progress-log title.
function Get-KitProgressHeading {
    return '## ' + [char]0x516D + [char]0x3001 + [char]0x53D8 + [char]0x66F4 + [char]0x8BB0 + [char]0x5F55
}

function Get-KitProgressDocs([string]$ws) {
    $name = (-join @(
        [char]0x9879, [char]0x76EE, [char]0x8FDB, [char]0x5EA6,
        [char]0x4E0E, [char]0x5B8C, [char]0x6210, [char]0x5EA6
    )) + '.md'
    $prefer = Join-Path (Join-Path $ws 'docs') $name
    if (Test-Path -LiteralPath $prefer) { return @($prefer) }
    $dir = Join-Path $ws 'docs'
    if (-not (Test-Path $dir)) { return @() }
    return @(Get-ChildItem $dir -Filter *.md -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
}

function Get-KitLatestProgressRow([string]$ws) {
    $heading = Get-KitProgressHeading
    $best = ''
    foreach ($path in (Get-KitProgressDocs $ws)) {
        $text = [IO.File]::ReadAllText($path)
        $row = ''
        $in = $false
        foreach ($line in ($text -split '\r?\n')) {
            if ($line.StartsWith($heading)) { $in = $true; continue }
            if ($in -and $line.StartsWith('## ')) { $in = $false; continue }
            if ($in -and $line.StartsWith('|') -and ($line.IndexOf('---') -lt 0)) { $row = $line }
        }
        if ($row) { $best = $row }
    }
    return $best
}

# Changed code paths the latest progress row does not mention.
function Get-KitUnnamedChanges([string]$ws, $codeRels) {
    $row = ((Get-KitLatestProgressRow $ws) -replace '\\', '/').ToLowerInvariant()
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($rel in @($codeRels)) {
        if ($null -eq $rel) { continue }
        $n = ([string]$rel -replace '\\', '/').Trim()
        if (-not $n) { continue }
        if (-not $row.Contains($n.ToLowerInvariant())) { [void]$missing.Add($n) }
    }
    return $missing
}
