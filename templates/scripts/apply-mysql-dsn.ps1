# [apply-mysql-dsn] Write .env from a mysql CLI command or DSN. ASCII-only.
# Does NOT print password. Keys: HOSTNAME/DATABASE/USERNAME/PASSWORD/HOSTPORT.
# Usage:
#   ./scripts/apply-mysql-dsn.ps1 -Command 'mysql -h127.0.0.1 -P3306 -uroot -pSecret -Dmydb'
#   ./scripts/apply-mysql-dsn.ps1 -Dsn 'mysql://user:pass@127.0.0.1:3306/mydb'
#   ./scripts/apply-mysql-dsn.ps1 -EnvPath 'backend\.env' -Command '...'

param(
    [string]$Command = "",
    [string]$Dsn = "",
    [string]$EnvPath = ""
)

if (-not $EnvPath) {
    $EnvPath = Join-Path $PSScriptRoot "..\.env"   # ADAPT: often backend\.env
}
if (-not [System.IO.Path]::IsPathRooted($EnvPath)) {
    $EnvPath = Join-Path (Split-Path $PSScriptRoot -Parent) $EnvPath
}

$hostName = ""; $port = "3306"; $user = ""; $pass = ""; $db = ""

if ($Dsn) {
    if ($Dsn -match '^mysql://([^:/]+):([^@]*)@([^:/]+)(?::(\d+))?/([^?\s]+)$') {
        $user = $Matches[1]; $pass = $Matches[2]; $hostName = $Matches[3]
        if ($Matches[4]) { $port = $Matches[4] }
        $db = $Matches[5].TrimEnd('/')
    } else {
        Write-Error "Unsupported DSN. Expect mysql://user:pass@host:port/db"
        exit 2
    }
} elseif ($Command) {
    $cmd = $Command
    if ($cmd -cmatch '(?:^|\s)-h\s*([^\s]+)') { $hostName = $Matches[1] }
    elseif ($cmd -match '(?:^|\s)--host[= ]([^\s]+)') { $hostName = $Matches[1] }
    if ($cmd -cmatch '(?:^|\s)-P\s*(\d+)') { $port = $Matches[1] }
    elseif ($cmd -match '(?:^|\s)--port[= ](\d+)') { $port = $Matches[1] }
    if ($cmd -cmatch '(?:^|\s)-u\s*([^\s]+)') { $user = $Matches[1] }
    elseif ($cmd -match '(?:^|\s)--user[= ]([^\s]+)') { $user = $Matches[1] }
    # -pPASSWORD must be lowercase p ( -P is port )
    if ($cmd -cmatch '(?:^|\s)-p([^\s]+)') { $pass = $Matches[1] }
    elseif ($cmd -match '(?:^|\s)--password=([^\s]+)') { $pass = $Matches[1] }
    if ($cmd -cmatch '(?:^|\s)-D\s*([^\s]+)') { $db = $Matches[1] }
    elseif ($cmd -match '(?:^|\s)--database[= ]([^\s]+)') { $db = $Matches[1] }
} else {
    Write-Error "Provide -Command or -Dsn"
    exit 2
}

if (-not $hostName -or -not $user -or -not $db) {
    Write-Error "Parsed incomplete connection (need host, user, database)."
    exit 2
}
if ($pass -eq "") {
    Write-Host "WARNING: password empty; edit PASSWORD in .env if needed." -ForegroundColor Yellow
}

$dir = Split-Path $EnvPath -Parent
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$map = @{
    HOSTNAME = $hostName
    HOSTPORT = $port
    USERNAME = $user
    PASSWORD = $pass
    DATABASE = $db
}
$keys = @('HOSTNAME', 'HOSTPORT', 'USERNAME', 'PASSWORD', 'DATABASE')
$out = New-Object System.Collections.Generic.List[string]
$seen = @{}
if (Test-Path $EnvPath) {
    foreach ($line in Get-Content $EnvPath) {
        $hit = $false
        foreach ($k in $keys) {
            if ($line -match ("^\s*" + $k + "\s*=")) {
                $out.Add("$k=$($map[$k])") | Out-Null
                $seen[$k] = $true
                $hit = $true
                break
            }
        }
        if (-not $hit) { $out.Add($line) | Out-Null }
    }
}
foreach ($k in $keys) {
    if (-not $seen.ContainsKey($k)) { $out.Add("$k=$($map[$k])") | Out-Null }
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($EnvPath, $out.ToArray(), $utf8)

Write-Host ("Wrote .env (password hidden): host={0} port={1} user={2} db={3}" -f $hostName, $port, $user, $db)
Write-Host ("path={0}" -f $EnvPath)
Write-Host "Next: fill the DB connect review doc (docs/, no password); run db.ps1 `"SELECT 1 AS ok`""
exit 0
