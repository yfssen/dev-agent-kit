# Cursor preCompact SSOT backup. ASCII only, no BOM. Side-effect only.
# Before the context is compacted, snapshot the SSOT docs so progress is never
# silently lost. Backs up all docs/*.md (avoids hardcoding any non-ASCII name).

$ErrorActionPreference = "SilentlyContinue"
[void][Console]::In.ReadToEnd()

$proj = (Get-Location).Path
$docs = Join-Path $proj 'docs'
if (-not (Test-Path $docs)) { exit 0 }

$backup = Join-Path $docs '.ssot-backups'
New-Item -ItemType Directory -Force -Path $backup | Out-Null

$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
Get-ChildItem $docs -Filter *.md -File -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $backup ("$stamp-" + $_.Name)) -Force
}

# Prune: keep newest 40 snapshots.
$all = @(Get-ChildItem $backup -Filter *.md -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
if ($all.Count -gt 40) { $all | Select-Object -Skip 40 | Remove-Item -Force }

exit 0
