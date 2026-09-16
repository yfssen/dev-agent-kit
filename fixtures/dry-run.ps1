# Kit dry-run (engineering acceptance). ASCII-only.
# Copies fixtures/fake-project to a TEMP workdir (idempotent; does not dirty the repo).
# Prerequisites: php on PATH or $env:LZ_PHP (for lint + smoke mock). Optional: Git Bash for .sh runtime.
# Usage: pwsh -File fixtures/dry-run.ps1 [-RequireBash]

param(
    [switch]$RequireBash
)

$ErrorActionPreference = "Stop"
$KitRoot = Split-Path $PSScriptRoot -Parent
$FixtureSrc = Join-Path $PSScriptRoot "fake-project"
$failed = 0
$work = Join-Path $env:TEMP ("dev-agent-kit-dryrun-" + [guid]::NewGuid().ToString("n"))

function Ok([string]$msg) { Write-Host "[PASS] $msg" -ForegroundColor Green }
function Bad([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:failed++ }
function Info([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Resolve-Php {
    if ($env:LZ_PHP -and (Test-Path $env:LZ_PHP)) { return $env:LZ_PHP }
    $cmd = Get-Command php -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

Info "KitRoot=$KitRoot"
Info "Work=$work"

try {
  Copy-Item $FixtureSrc $work -Recurse -Force
  # Tracked sample is .env.example; scripts need .env in the TEMP workdir
  $envEx = Join-Path $work ".env.example"
  $envFile = Join-Path $work ".env"
  if ((Test-Path $envEx) -and -not (Test-Path $envFile)) {
    Copy-Item $envEx $envFile -Force
  }
  New-Item -ItemType Directory -Force `
    (Join-Path $work "scripts"), `
    (Join-Path $work ".cursor\rules"), `
    (Join-Path $work ".kiro\steering"), `
    (Join-Path $work "docs") | Out-Null

  Copy-Item (Join-Path $KitRoot "templates\scripts\*") (Join-Path $work "scripts") -Force
  Copy-Item (Join-Path $KitRoot "adapters\cursor\*.mdc") (Join-Path $work ".cursor\rules") -Force
  Copy-Item (Join-Path $KitRoot "adapters\claude\CLAUDE.md") (Join-Path $work "CLAUDE.md") -Force
  Copy-Item (Join-Path $KitRoot "adapters\kiro\steering\*") (Join-Path $work ".kiro\steering") -Force
  Copy-Item (Join-Path $KitRoot "adapters\workbuddy\CODEBUDDY.md") (Join-Path $work "CODEBUDDY.md") -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force (Join-Path $work ".codebuddy\rules"), (Join-Path $work ".qoder\rules") | Out-Null
  Copy-Item (Join-Path $KitRoot "adapters\workbuddy\rules\*") (Join-Path $work ".codebuddy\rules") -Force -ErrorAction SilentlyContinue
  Copy-Item (Join-Path $KitRoot "adapters\qoder\rules\*") (Join-Path $work ".qoder\rules") -Force -ErrorAction SilentlyContinue

  # Fixture skeleton must not ship adapter overlays (stale copies mislead; dry-run injects from adapters/)
  $overlayLeak = @(
    "CLAUDE.md", "CODEBUDDY.md",
    ".cursor\rules\tooling.mdc", ".cursor\rules\coding.mdc", ".cursor\rules\project-progress.mdc",
    ".kiro\steering\tooling.md", ".kiro\steering\coding.md", ".kiro\steering\project-progress.md",
    ".codebuddy\rules\tooling.md", ".codebuddy\rules\project-progress.md",
    ".qoder\rules\tooling.md", ".qoder\rules\project-progress.md"
  )
  $leakN = 0
  foreach ($rel in $overlayLeak) {
    if (Test-Path (Join-Path $FixtureSrc $rel)) {
      Bad "fixture ships adapter overlay $rel (delete it; dry-run copies from adapters/)"
      $leakN++
    }
  }
  if ($leakN -eq 0) { Ok "fixture has no adapter overlay copies" }

  $must = @(
    "scripts\db.ps1", "scripts\lint.ps1", "scripts\smoke.ps1", "scripts\api-check.ps1",
    "scripts\db.sh", "scripts\lint.sh", "scripts\smoke.sh", "scripts\api-check.sh",
    "scripts\mysql.ps1", "scripts\mysql.sh",
    "scripts\scan-project.ps1", "scripts\scan-project.sh",
    "scripts\apply-mysql-dsn.ps1", "scripts\apply-mysql-dsn.sh",
    ".cursor\rules\tooling.mdc", ".cursor\rules\coding.mdc",
    "CLAUDE.md", ".kiro\steering\tooling.md", "AGENTS.md"
  )
  foreach ($rel in $must) {
    if (Test-Path (Join-Path $work $rel)) { Ok "installed $rel" }
    else { Bad "missing $rel" }
  }

  # Mother templates must not ship machine-private paths -- check ALL scripts, not just db.ps1
  $privHit = 0
  foreach ($sf in (Get-ChildItem (Join-Path $work "scripts") -File)) {
    if ($sf.Name -notmatch '\.(ps1|sh)$') { continue }
    $raw = Get-Content $sf.FullName -Raw
    if ($raw -match 'phpstudy_pro') { Bad "machine-private path in $($sf.Name)"; $privHit++ }
  }
  if ($privHit -eq 0) { Ok "no machine-private path in scripts/ (all .ps1/.sh)" }

  Push-Location $work
  $ErrorActionPreference = "Continue"
  try {
    # --- db security ---
    & .\scripts\db.ps1 "UPDATE x SET y=1" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 1) { Ok "db blocks UPDATE (exit 1)" } else { Bad "db UPDATE expected exit 1, got $LASTEXITCODE" }

    & .\scripts\db.ps1 "SELECT 1; DROP TABLE users" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 1) { Ok "db blocks multi-statement (exit 1)" } else { Bad "db multi-statement expected exit 1, got $LASTEXITCODE" }

    & .\scripts\db.ps1 "SELECT 1 INTO OUTFILE '/tmp/x'" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 1) { Ok "db blocks INTO OUTFILE (exit 1)" } else { Bad "db file-I/O expected exit 1, got $LASTEXITCODE" }

    # --- lint ---
    $php = Resolve-Php
    if (-not $php) {
      Bad "php not found (set PATH or LZ_PHP). Required for lint + smoke."
    } else {
      $env:LZ_PHP = $php
      & .\scripts\lint.ps1 ".\backend\sample_ok.php" | Out-Host
      if ($LASTEXITCODE -eq 0) { Ok "lint ok on sample_ok.php" } else { Bad "lint sample expected 0, got $LASTEXITCODE" }

      $oldPhp = $env:LZ_PHP
      $env:LZ_PHP = "C:\no-such-php\php.exe"
      $savedPath = $env:PATH
      $env:PATH = "C:\no-such-bin"
      & .\scripts\lint.ps1 ".\backend\sample_ok.php" 2>$null | Out-Null
      $lintMissing = $LASTEXITCODE
      if ($lintMissing -eq 2) { Ok "lint missing dep exit 2" } else { Bad "lint missing dep expected exit 2, got $lintMissing" }

      # Checker path exists but is not runnable: must be exit 2, not leftover 1 from db/cmd
      $bogus = Join-Path $work "not-a-php.txt"
      Set-Content -Path $bogus -Value "not php" -Encoding ascii
      $env:LZ_PHP = $bogus
      $global:LASTEXITCODE = 1
      & .\scripts\lint.ps1 ".\backend\sample_ok.php" 2>$null | Out-Null
      $lintStale = $LASTEXITCODE
      $env:PATH = $savedPath
      $env:LZ_PHP = $oldPhp
      if ($lintStale -eq 2) { Ok "lint checker-did-not-run exit 2 (not leftover 1)" } else { Bad "lint expected exit 2 when checker did not run, got $lintStale" }
    }

    # --- api-check ---
    $apiLines = @(& .\scripts\api-check.ps1 -All 2>&1 | ForEach-Object { "$_" })
    $apiLines | ForEach-Object { Write-Host $_ }
    $summaryLine = $apiLines | Where-Object { $_ -match 'OK=\d+.*NO_METHOD=\d+.*NO_CONTROLLER=\d+' } | Select-Object -Last 1
    if ($summaryLine -match 'OK=(\d+).*NO_METHOD=(\d+).*NO_CONTROLLER=(\d+)') {
      $okN = [int]$Matches[1]; $nmN = [int]$Matches[2]; $ncN = [int]$Matches[3]
      if ($okN -ge 1) { Ok "api-check OK=$okN" } else { Bad "api-check expected OK>=1" }
      if ($nmN -ge 1) { Ok "api-check NO_METHOD=$nmN" } else { Bad "api-check expected NO_METHOD>=1" }
      if ($ncN -ge 1) { Ok "api-check NO_CONTROLLER=$ncN" } else { Bad "api-check expected NO_CONTROLLER>=1" }
    } else {
      Bad "api-check summary not parsed"
    }

    # --- smoke ---
    if ($php) {
      $port = 18080
      Info "mock server on http://127.0.0.1:$port/ via php -S"
      $mockProc = Start-Process -FilePath $php -ArgumentList @(
        "-S", "127.0.0.1:$port", "mock-router.php"
      ) -WorkingDirectory $work -PassThru -WindowStyle Hidden
      try {
        Start-Sleep -Milliseconds 600
        & .\scripts\smoke.ps1 -BaseUrl "http://127.0.0.1:$port" | Out-Host
        if ($LASTEXITCODE -eq 0) { Ok "smoke PASS against mock server" } else { Bad "smoke expected exit 0, got $LASTEXITCODE" }
      }
      finally {
        if ($mockProc -and -not $mockProc.HasExited) {
          Stop-Process -Id $mockProc.Id -Force -ErrorAction SilentlyContinue
        }
      }
    }

    # --- db security extras ---
    & .\scripts\db.ps1 "SELECT 1\gDROP TABLE users" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 1) { Ok "db blocks mysql \\g delimiter (exit 1)" } else { Bad "db \\g expected exit 1, got $LASTEXITCODE" }

    # Static assert: db.sh must contain multi-statement guards (catches syntax regressions even without bash)
    $dbShText = Get-Content .\scripts\db.sh -Raw
    if ($dbShText -match "\*';'\*" -and $dbShText -match '\\\[gG\]') {
      Ok "db.sh source contains ; and \\g guards"
    } else {
      Bad "db.sh missing multi-statement guards in source"
    }
    if ($dbShText -match "\*';\*\)" -and $dbShText -notmatch "\*';'\*\)") {
      Bad "db.sh has broken case pattern *';*) (unclosed quote)"
    }

    # --- install.ps1 merge-safe (against this workdir as "project") ---
    $install = Join-Path $KitRoot "skills\scaffold-dev-agent\scripts\install.ps1"
    $installSh = Join-Path $KitRoot "skills\scaffold-dev-agent\scripts\install.sh"
    if (-not (Test-Path $installSh)) {
      Bad "install.sh missing"
    } else {
      $installShText = Get-Content $installSh -Raw
      if ($installShText -match '\.kit-new' -and $installShText -match 'exit 2') {
        Ok "install.sh source has merge-safe (.kit-new + exit 2)"
      } else {
        Bad "install.sh missing merge-safe markers (.kit-new / exit 2)"
      }
    }
    & $install -KitRoot $KitRoot -ProjectRoot $work -Adapters "cursor,claude" 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
      Ok "install.ps1 merge-safe exit=$LASTEXITCODE"
    } else {
      Bad "install.ps1 unexpected exit $LASTEXITCODE"
    }

    # --- bash .sh checks ---
    $gitBash = $null
    $bashCandidates = @(
      "C:\Program Files\Git\bin\bash.exe",
      "C:\Program Files\Git\usr\bin\bash.exe",
      "C:\Program Files (x86)\Git\bin\bash.exe"
    )
    foreach ($c in $bashCandidates) {
      if (Test-Path $c) { $gitBash = $c; break }
    }
    if (-not $gitBash) {
      $cmdBash = Get-Command bash -ErrorAction SilentlyContinue
      if ($cmdBash -and $cmdBash.Source -notmatch '\\Windows\\[Ss]ystem32\\bash\.exe$') {
        $gitBash = $cmdBash.Source
      }
    }
    if ($gitBash) {
      $dbSh = Join-Path (Get-Location) "scripts\db.sh"
      $lf = ([IO.File]::ReadAllText($dbSh) -replace "`r`n", "`n" -replace "`r", "`n")
      [IO.File]::WriteAllText($dbSh, $lf, (New-Object System.Text.UTF8Encoding $false))
      & $gitBash -n $dbSh 2>$null
      if ($LASTEXITCODE -eq 0) { Ok "db.sh bash -n syntax OK" } else { Bad "db.sh bash -n failed exit=$LASTEXITCODE" }
      & $gitBash $dbSh "UPDATE x SET y=1" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 1) { Ok "db.sh blocks UPDATE" } else { Bad "db.sh UPDATE expected exit 1, got $LASTEXITCODE" }
      & $gitBash $dbSh "SELECT 1; DROP TABLE users" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 1) { Ok "db.sh blocks multi-statement" } else { Bad "db.sh multi-statement expected exit 1, got $LASTEXITCODE" }
      & $gitBash $dbSh "SELECT 1\gDROP TABLE users" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 1) { Ok "db.sh blocks \\g" } else { Bad "db.sh \\g expected exit 1, got $LASTEXITCODE" }

      if (Test-Path $installSh) {
        $tmpInstall = Join-Path $work "_install.sh"
        $lfInstall = ([IO.File]::ReadAllText($installSh) -replace "`r`n", "`n" -replace "`r", "`n")
        [IO.File]::WriteAllText($tmpInstall, $lfInstall, (New-Object System.Text.UTF8Encoding $false))
        & $gitBash -n $tmpInstall 2>$null
        if ($LASTEXITCODE -eq 0) { Ok "install.sh bash -n syntax OK" } else { Bad "install.sh bash -n failed exit=$LASTEXITCODE" }
        $kitUnix = ($KitRoot -replace '\\', '/')
        $workUnix = ($work -replace '\\', '/')
        & $gitBash $tmpInstall $kitUnix $workUnix "cursor,claude" 2>&1 | Out-Host
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
          Ok "install.sh merge-safe exit=$LASTEXITCODE"
        } else {
          Bad "install.sh unexpected exit $LASTEXITCODE"
        }
      }
    } else {
      Write-Host "[WARN] Git Bash not found; .sh runtime checks skipped (source asserts still ran). Install Git for Windows or pass -RequireBash." -ForegroundColor Yellow
      if ($RequireBash) { Bad "RequireBash set but no usable bash found" }
    }
  }
  finally {
    Pop-Location
  }
}
finally {
  if (Test-Path $work) {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ""
if ($failed -eq 0) {
  Write-Host "== DRY-RUN OK ==" -ForegroundColor Green
  exit 0
} else {
  Write-Host "== DRY-RUN FAILED: $failed check(s) ==" -ForegroundColor Red
  exit 1
}
