# [mysql-shell] Open interactive MySQL using .env. ASCII-only.
# Password via MYSQL_PWD env (not argv). See tooling / AGENTS.md.
# ADAPT: .env path + key names (HOSTNAME/DATABASE/USERNAME/PASSWORD/HOSTPORT).

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$MysqlArgs
)

$mysql = $null
if ($env:LZ_MYSQL -and (Test-Path $env:LZ_MYSQL)) {
    $mysql = $env:LZ_MYSQL
} elseif (Get-Command mysql -ErrorAction SilentlyContinue) {
    $mysql = "mysql"
}
if (-not $mysql) {
    Write-Error "mysql client not found. Set `$env:LZ_MYSQL or add to PATH."
    exit 2
}

$envPath = Join-Path $PSScriptRoot "..\.env"   # ADAPT: often backend\.env in dual-git layout
if (-not (Test-Path $envPath)) { Write-Error ".env not found: $envPath"; exit 2 }

$cfg = @{}
foreach ($line in Get-Content $envPath) {
    if ($line -match '^\s*(HOSTNAME|DATABASE|USERNAME|PASSWORD|HOSTPORT)\s*=\s*(.+?)\s*$') {
        $cfg[$matches[1]] = $matches[2]
    }
}
if (-not $cfg.HOSTNAME -or -not $cfg.USERNAME -or -not $cfg.DATABASE) {
    Write-Error ".env missing HOSTNAME/USERNAME/DATABASE."
    exit 2
}

$port = "3306"
if ($cfg.HOSTPORT) { $port = $cfg.HOSTPORT }

Write-Host ("Connecting {0}@{1}:{2}/{3} (password hidden)" -f $cfg.USERNAME, $cfg.HOSTNAME, $port, $cfg.DATABASE)

$env:MYSQL_PWD = $cfg.PASSWORD
try {
    if ($MysqlArgs -and $MysqlArgs.Count -gt 0) {
        & $mysql -h $cfg.HOSTNAME -P $port -u $cfg.USERNAME -D $cfg.DATABASE --default-character-set=utf8 @MysqlArgs
    } else {
        & $mysql -h $cfg.HOSTNAME -P $port -u $cfg.USERNAME -D $cfg.DATABASE --default-character-set=utf8
    }
    exit $LASTEXITCODE
}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}
