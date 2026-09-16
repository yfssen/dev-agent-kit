# [self-check] Syntax/type check helper. See tooling rules.
# Missing / non-running checker -> exit 2 (NOT a false "syntax error"). Real error -> exit 1.
# ADAPT: replace the checker resolution + invocation for your stack.
# Encoding: ASCII-only (no BOM).
#
# Traps when adapting to Node/eslint (D2/D4):
# - Resolve $Target against workspace $root BEFORE Push-Location into a subapp.
# - Never Join-Path an empty env base ($env:ProgramFiles may be blank in some shells);
#   that throws and aborts the WHOLE candidate list. Guard each base first.
# - Error text must say "not found" when fallbacks fail — not "too old" if you never tried them.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Target
)

$root = Split-Path $PSScriptRoot -Parent

# Resolve relative paths against workspace root (keep .ps1/.sh aligned).
$fullTarget = $Target
if (-not [System.IO.Path]::IsPathRooted($Target)) {
    $fullTarget = Join-Path $root $Target
}

# --- Resolve checker (example: PHP CLI) ---   # ADAPT
$php = $null
if ($env:LZ_PHP -and (Test-Path $env:LZ_PHP)) {
    $php = $env:LZ_PHP
} elseif (Get-Command php -ErrorAction SilentlyContinue) {
    $php = "php"
}
if (-not $php) {
    Write-Error "checker not found. Set `$env:LZ_PHP or add it to PATH. (NOT a syntax error.)"
    exit 2
}

if (-not (Test-Path $fullTarget)) { Write-Error "Target not found: $Target"; exit 2 }

if (Test-Path $fullTarget -PathType Container) {
    $files = @(Get-ChildItem $fullTarget -Recurse -Filter *.php -File)   # ADAPT extension
} else {
    $files = @(Get-Item $fullTarget)
}

$fail = 0
foreach ($f in $files) {
    $out = & $php -l $f.FullName 2>&1                                # ADAPT invocation
    if ($null -eq $LASTEXITCODE) {
        Write-Error "checker did not run (no exit code). Check `$env:LZ_PHP / PATH. (NOT a syntax error.)"
        exit 2
    }
    if ($LASTEXITCODE -ne 0) {
        $fail++
        Write-Host $out -ForegroundColor Red
    }
}

if ($fail -eq 0) {
    Write-Host ("OK: " + $files.Count + " file(s), no errors") -ForegroundColor Green
    exit 0
} else {
    Write-Host ("FAIL: " + $fail + " file(s) with errors") -ForegroundColor Red
    exit 1
}
