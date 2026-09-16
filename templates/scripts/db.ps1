# [query-state] Read-only DB query helper. Reads .env. See tooling rules.
# Allowed: SINGLE statement starting with SELECT/SHOW/DESCRIBE/DESC/EXPLAIN.
# Rejects multi-statement (;) and file I/O (INTO OUTFILE/DUMPFILE, LOAD_FILE, LOAD DATA).
# ADAPT: for Postgres/other, swap the client resolution + invocation at the bottom.
# Encoding: ASCII-only (no BOM).

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Sql
)

# --- Single statement only: ONE trailing ';' is allowed; separators and \g / \G are not ---
$norm = $Sql.TrimEnd()
if ($norm.EndsWith(";")) { $norm = $norm.Substring(0, $norm.Length - 1).TrimEnd() }
if ($norm -match ';' -or $norm -imatch '\\[gG]') {
    Write-Error "Read-only helper: multi-statement SQL is not allowed (no ';' separator, no \g / \G)."
    exit 1
}

# --- Whitelist: statement must START with a read-only keyword ---
$trimmed = $Sql.TrimStart()
if ($trimmed -inotmatch '^(SELECT|SHOW|DESCRIBE|DESC|EXPLAIN)\b') {
    Write-Error "Read-only helper: only SELECT/SHOW/DESCRIBE/EXPLAIN are allowed."
    exit 1
}

# --- Hard-block file I/O that can slip past a naive whitelist ---
$fileIo = '\b(INTO\s+OUTFILE|INTO\s+DUMPFILE|LOAD_FILE|LOAD\s+DATA)\b'
if ($Sql -imatch $fileIo) {
    Write-Error "Read-only helper: file I/O is not allowed."
    exit 1
}

# --- Resolve client: $env:LZ_MYSQL > PATH ---
$mysql = $null
if ($env:LZ_MYSQL -and (Test-Path $env:LZ_MYSQL)) {
    $mysql = $env:LZ_MYSQL
} elseif (Get-Command mysql -ErrorAction SilentlyContinue) {
    $mysql = "mysql"
}
if (-not $mysql) {
    Write-Error "mysql client not found. Set `$env:LZ_MYSQL, or add it to PATH."
    exit 2
}

# --- Read connection from .env ---   # ADAPT: .env path + key names
$envPath = Join-Path $PSScriptRoot "..\.env"
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

# Pass password via env var so it never appears in the command line / process list.
$env:MYSQL_PWD = $cfg.PASSWORD
try {
    & $mysql -h $cfg.HOSTNAME -P $port -u $cfg.USERNAME -D $cfg.DATABASE --default-character-set=utf8 -e $Sql
    exit $LASTEXITCODE
}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}
