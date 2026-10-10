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

# True = SSOT looks updated (or there is nothing to compare). False = nudge / WARN.
function Test-KitSsotFresh([string]$ws, $codeRels) {
    if (Test-KitRootSsotInGit $ws) { return $true }
    # @() so a single string is 1 path, not a char array (.Count would be Length).
    $rels = @()
    if ($null -ne $codeRels) { $rels = @($codeRels) }
    if ($rels.Count -eq 0) { return $true }
    $ssot = @(Get-KitSsotFiles $ws)
    if ($ssot.Count -eq 0) { return $false }

    $maxCode = $null
    foreach ($rel in $rels) {
        $abs = Join-Path $ws (($rel -replace '/', [char][IO.Path]::DirectorySeparatorChar))
        if (-not (Test-Path -LiteralPath $abs)) { continue }
        $t = (Get-Item -LiteralPath $abs).LastWriteTimeUtc
        if ($null -eq $maxCode -or $t -gt $maxCode) { $maxCode = $t }
    }
    if ($null -eq $maxCode) { return $true }

    $maxSsot = $null
    foreach ($f in $ssot) {
        if ($null -eq $maxSsot -or $f.LastWriteTimeUtc -gt $maxSsot) { $maxSsot = $f.LastWriteTimeUtc }
    }
    return ($maxSsot -ge $maxCode.AddSeconds(-2))
}
