# Cursor postToolUse (matcher: Write) auto-lint. ASCII only, no BOM.
# After the agent edits a file, run the project's lint automatically and, on a
# real failure, feed the result back as additional_context -- so self-check is
# deterministic, not reliant on the agent remembering to do it.
# Exit-code contract (matches templates/scripts/lint.ps1):
#   0 = pass, 1 = real error (surface it), 2 = checker missing (skip, not a code error).
# ADAPT: edit $exts for your stack.

$ErrorActionPreference = "SilentlyContinue"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$path = $null
foreach ($k in @('file_path', 'path', 'filePath', 'file', 'target')) {
    if ($j.$k) { $path = [string]$j.$k; break }
}
if (-not $path -and $j.tool_input) {
    foreach ($k in @('file_path', 'path', 'filePath', 'file', 'target')) {
        if ($j.tool_input.$k) { $path = [string]$j.tool_input.$k; break }
    }
}
if (-not $path) {
    $m = [regex]::Match($raw, '[A-Za-z]:\\[^"]+?\.(php|vue|js|ts|sql)|/[^"]+?\.(php|vue|js|ts|sql)')
    if ($m.Success) { $path = $m.Value }
}
if (-not $path) { exit 0 }

# ADAPT: files to consider. lint.ps1 skips extensions it cannot parse (default .php only).
$exts = @('.php', '.vue', '.js', '.ts', '.sql')
$ext = [System.IO.Path]::GetExtension($path).ToLower()
if ($exts -notcontains $ext) { exit 0 }

$proj = (Get-Location).Path
$lint = Join-Path $proj 'scripts\lint.ps1'
if (-not (Test-Path $lint)) { exit 0 }

$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $lint $path 2>&1 | Out-String
$code = $LASTEXITCODE

$log = Join-Path $proj 'scripts\.lint-last.log'
$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
Set-Content -Path $log -Value ("[$stamp] exit=$code file=$path`r`n$out") -Encoding ascii

if ($code -eq 1) {
    $trimmed = ($out -replace '\s+', ' ').Trim()
    if ($trimmed.Length -gt 800) { $trimmed = $trimmed.Substring(0, 800) }
    $ctx = "Auto-lint FAILED (exit 1) on $path. Fix before proceeding: $trimmed"
    Write-Output (@{ additional_context = $ctx } | ConvertTo-Json -Compress)
}
exit 0
