# [git-remote-add] Attach an existing remote URL and prove it with git ls-remote.
# ASCII-only. Does not git config, commit, or push.
# If ls-remote fails, the remote added by this run is removed.
# Usage:
#   ./scripts/git-remote-add.ps1 -Repo backend -Url 'git@host:backend.git'
#   ./scripts/git-remote-add.ps1 -Repo . -Url 'https://host/repo.git' -Name origin

param(
    [string]$Repo = ".",
    [string]$Url = "",
    [string]$Name = "origin"
)

function Fail([string]$msg, [int]$code) {
    Write-Host "FAIL $msg"
    exit $code
}

if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Fail "remote name rejected" 2
}

$okUrl = $false
if ($Url -match '^git@[A-Za-z0-9._-]+:[A-Za-z0-9._+/-]+$') { $okUrl = $true }
elseif ($Url -match '^ssh://([A-Za-z0-9._-]+@)?[A-Za-z0-9._-]+(:[0-9]+)?/[A-Za-z0-9._+/-]+$') { $okUrl = $true }
elseif ($Url -match '^https?://([A-Za-z0-9._-]+(:[^@/\s]*)?@)?[A-Za-z0-9._-]+(:[0-9]+)?/[A-Za-z0-9._+/-]+$') { $okUrl = $true }
elseif ($Url -match '^file:///[A-Za-z]:/[A-Za-z0-9._+/-]+$') { $okUrl = $true }
elseif ($Url -match '^file:///[A-Za-z0-9._+/-]+$') { $okUrl = $true }
if (-not $okUrl) { Fail "url rejected" 2 }

$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not [System.IO.Path]::IsPathRooted($Repo)) {
    $repoPath = Join-Path $projectRoot $Repo
} else {
    $repoPath = $Repo
}
$repoFull = [System.IO.Path]::GetFullPath($repoPath)
$rootFull = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/')
$repoCmp = $repoFull.TrimEnd('\', '/')
$inside = ($repoCmp -eq $rootFull) -or $repoFull.StartsWith($rootFull + '\') -or $repoFull.StartsWith($rootFull + '/')
if (-not $inside) { Fail "repo outside project" 2 }
if (-not (Test-Path (Join-Path $repoFull ".git"))) { Fail "not a git repo" 2 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "git not on PATH" 2 }

$global:LASTEXITCODE = $null
$names = @(git -C $repoFull remote 2>$null)
if ($global:LASTEXITCODE -ne 0) { Fail "git remote failed" 2 }
foreach ($n in $names) {
    if (([string]$n).Trim() -eq $Name) { Fail "remote $Name already set" 2 }
}

$global:LASTEXITCODE = $null
git -C $repoFull remote add $Name $Url 2>$null
if ($global:LASTEXITCODE -ne 0) { Fail "git remote add failed" 2 }

$global:LASTEXITCODE = $null
git -C $repoFull ls-remote $Name 2>$null | Out-Null
if ($global:LASTEXITCODE -ne 0) {
    git -C $repoFull remote remove $Name 2>$null | Out-Null
    Fail "ls-remote failed; remote removed" 3
}

Write-Host "OK repo=$Repo remote=$Name ls-remote=ok"
exit 0
