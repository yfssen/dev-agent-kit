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
$bashEnvFile = $null
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
    "scripts\db.ps1", "scripts\lint.ps1", "scripts\smoke.ps1", "scripts\api-check.ps1", "scripts\verify.ps1",
    "scripts\kit-layout.ps1",
    "scripts\db.sh", "scripts\lint.sh", "scripts\smoke.sh", "scripts\api-check.sh", "scripts\verify.sh",
    "scripts\kit-layout.sh",
    "scripts\mysql.ps1", "scripts\mysql.sh",
    "scripts\scan-project.ps1", "scripts\scan-project.sh",
    "scripts\apply-mysql-dsn.ps1", "scripts\apply-mysql-dsn.sh",
    "scripts\git-remote-add.ps1", "scripts\git-remote-add.sh",
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

    # --- verify gate ---
    $verifyLines = @(& .\scripts\verify.ps1 2>&1 | ForEach-Object { "$_" })
    $verifyLines | ForEach-Object { Write-Host $_ }
    $vText = $verifyLines -join "`n"
    if ($vText -match '\[FAIL\] api-check') { Ok "verify flags fixture api-check FAIL" } else { Bad "verify should FAIL api-check on fixture" }
    if ($vText -match '\[SKIP\] smoke') { Ok "verify skips smoke when server down" } else { Bad "verify should SKIP smoke without server" }
    if ($vText -match '== Result: FAIL') { Ok "verify Result FAIL when a check FAILs" } else { Bad "verify should print Result FAIL" }
    if ($vText -match '== Done: no ==') { Ok "verify Done no when a check FAILs" } else { Bad "verify should print Done no on FAIL" }

    # Fixture copy is not a repo. git rev-parse exits 128; the scan must not leak it.
    # backend/ + frontend/ have no .git, so advice is ask_children.
    # Write-Host is not in the pipeline; read the outfile.
    & .\scripts\scan-project.ps1 -OutFile "docs\_scan-raw.md" | Out-Null
    $scanCode = $LASTEXITCODE
    $scanText = ""
    $scanFile = Join-Path (Get-Location) "docs\_scan-raw.md"
    if (Test-Path $scanFile) {
      $scanText = Get-Content $scanFile -Raw
      # Drop it before git init. A fresh docs/*.md makes the next SSOT check look updated.
      Remove-Item $scanFile -Force
    }
    if ($scanCode -eq 0) { Ok "scan-project non-repo exits 0" } else { Bad "scan-project non-repo leaked exit $scanCode" }
    if ($scanText -match 'advice: ask_children' -and $scanText -match 'project_dirs_without_git:.*backend' -and $scanText -match 'frontend') {
      Ok "scan Git layout lists project dirs without git"
    } else {
      Bad "scan Git layout should be ask_children for backend+frontend"
    }
    if ($scanText -match 'repo_remotes: none') { Ok "scan repo_remotes none before any git" } else { Bad "scan repo_remotes should be none" }

    # Init a repo to exercise lint + SSOT WARN.
    if (Get-Command git -ErrorAction SilentlyContinue) {
      $remoteProj = Join-Path $env:TEMP ("dev-agent-kit-remote-" + [guid]::NewGuid().ToString("n"))
      $bare = Join-Path $env:TEMP ("dev-agent-kit-bare-" + [guid]::NewGuid().ToString("n") + ".git")
      try {
        New-Item -ItemType Directory -Force (Join-Path $remoteProj "scripts"), (Join-Path $remoteProj "app"), (Join-Path $remoteProj "docs") | Out-Null
        Copy-Item (Join-Path $KitRoot "templates\scripts\git-remote-add.ps1") (Join-Path $remoteProj "scripts\git-remote-add.ps1") -Force
        Copy-Item (Join-Path $KitRoot "templates\scripts\scan-project.ps1") (Join-Path $remoteProj "scripts\scan-project.ps1") -Force
        & git init -q (Join-Path $remoteProj "app") 2>$null
        & git init -q --bare $bare 2>$null
        $add = Join-Path $remoteProj "scripts\git-remote-add.ps1"
        $env:GIT_TERMINAL_PROMPT = "0"
        & $add -Repo app -Url "https://example.com/a.git && calc" | Out-Null
        if ($LASTEXITCODE -eq 2) { Ok "git-remote-add rejects bad url" } else { Bad "git-remote-add bad url exit $LASTEXITCODE" }
        & git -C (Join-Path $remoteProj "app") remote add origin "https://example.com/already.git" 2>$null
        & $add -Repo app -Url "https://example.com/other.git" | Out-Null
        if ($LASTEXITCODE -eq 2) { Ok "git-remote-add leaves existing remote" } else { Bad "git-remote-add existing remote exit $LASTEXITCODE" }
        $still = (& git -C (Join-Path $remoteProj "app") remote get-url origin 2>$null | Out-String).Trim()
        if ($still -eq "https://example.com/already.git") { Ok "git-remote-add did not replace origin" } else { Bad "origin changed to $still" }
        & git -C (Join-Path $remoteProj "app") remote remove origin 2>$null
        & $add -Repo app -Url "https://127.0.0.1:1/nope.git" | Out-Null
        if ($LASTEXITCODE -eq 3) { Ok "git-remote-add removes remote when ls-remote fails" } else { Bad "dead remote exit $LASTEXITCODE" }
        $left = @(& git -C (Join-Path $remoteProj "app") remote 2>$null)
        if ($left.Count -eq 0) { Ok "failed remote was removed" } else { Bad "dead remote still present" }
        $fileUrl = "file:///" + ($bare -replace '\\', '/')
        & $add -Repo app -Url $fileUrl | Out-Null
        if ($LASTEXITCODE -ne 0) { Bad "git-remote-add bare remote exit $LASTEXITCODE" }
        else {
          git -C (Join-Path $remoteProj "app") ls-remote origin 2>$null | Out-Null
          if ($LASTEXITCODE -eq 0) { Ok "git-remote-add proves local bare remote" } else { Bad "ls-remote after add failed" }
        }
        Push-Location $remoteProj
        try {
          & .\scripts\scan-project.ps1 -OutFile "docs\_scan-raw.md" | Out-Null
          $rr = ""
          $rrFile = Join-Path $remoteProj "docs\_scan-raw.md"
          if (Test-Path $rrFile) { $rr = Get-Content $rrFile -Raw }
          if ($rr -match 'repo_remotes: app=origin') { Ok "scan repo_remotes names the child remote" } else { Bad "scan repo_remotes missing app=origin" }
        } finally {
          Pop-Location
        }
      } finally {
        if (Test-Path $remoteProj) { Remove-Item $remoteProj -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $bare) { Remove-Item $bare -Recurse -Force -ErrorAction SilentlyContinue }
      }
      & git init -q 2>$null
      & git -c user.email=kit@example.com -c user.name=kit add -A 2>$null
      & git -c user.email=kit@example.com -c user.name=kit commit -qm dryrun-init 2>$null
      Add-Content -Path ".\backend\sample_ok.php" -Value "`n// dry-run edit" -Encoding ascii
      $verify2 = @(& .\scripts\verify.ps1 2>&1 | ForEach-Object { "$_" })
      $verify2 | ForEach-Object { Write-Host $_ }
      $v2 = $verify2 -join "`n"
      if ($v2 -match '\[PASS\] lint -- 1 changed') { Ok "verify lints dirty php" } else { Bad "verify should PASS lint on 1 dirty php" }
      if ($v2 -match '\[WARN\] ssot') { Ok "verify WARNs stale SSOT" } else { Bad "verify should WARN when code changed but SSOT not updated" }
      if ($v2 -match '== Done: no ==') { Ok "verify WARN is not Done yes" } else { Bad "stale SSOT should print Done no" }
    } else {
      Write-Host "[WARN] git not available; verify lint/ssot git cases skipped" -ForegroundColor Yellow
    }

    $nudgePs = Join-Path $KitRoot "templates\hooks\cursor\hooks\ssot-reminder.ps1"
    $nudgeSh = Join-Path $KitRoot "templates\hooks\cursor\hooks\ssot-reminder.sh"
    $nudgePsText = Get-Content $nudgePs -Raw
    $nudgeShText = Get-Content $nudgeSh -Raw
    if ($nudgePsText -notmatch 'followup_message\s*=') { Ok "ssot-reminder.ps1 does not auto-send a chat turn" } else { Bad "ssot-reminder.ps1 must not emit followup_message" }
    if ($nudgeShText -notmatch '"followup_message"') { Ok "ssot-reminder.sh does not auto-send a chat turn" } else { Bad "ssot-reminder.sh must not emit followup_message" }
    $hooksJson = Get-Content (Join-Path $KitRoot "templates\hooks\cursor\hooks.json") -Raw
    if ($hooksJson -notmatch 'ssot-reminder') { Ok "hooks.json has no stop ssot-reminder" } else { Bad "hooks.json must not register ssot-reminder" }

    # Same-folder multi-git: no root .git; SSOT at workspace-root docs/; .vue counts as code.
    if (Get-Command git -ErrorAction SilentlyContinue) {
      $mg = Join-Path $env:TEMP ("dak-multigit-" + [guid]::NewGuid().ToString("n"))
      try {
        New-Item -ItemType Directory -Force $mg,
          (Join-Path $mg "docs"),
          (Join-Path $mg "admin"),
          (Join-Path $mg "pc_web"),
          (Join-Path $mg "scripts") | Out-Null
        Copy-Item (Join-Path $KitRoot "templates\scripts\kit-layout.ps1") (Join-Path $mg "scripts\kit-layout.ps1") -Force
        Copy-Item (Join-Path $KitRoot "templates\scripts\lint.ps1") (Join-Path $mg "scripts\lint.ps1") -Force
        Copy-Item (Join-Path $KitRoot "templates\scripts\verify.ps1") (Join-Path $mg "scripts\verify.ps1") -Force
        Set-Content -Path (Join-Path $mg "docs\progress.md") -Value "ssot" -Encoding ascii

        Push-Location (Join-Path $mg "admin")
        try {
          & git init -q
          Set-Content -Path "x.php" -Value "<?php echo 1;" -Encoding ascii
          & git -c user.email=kit@example.com -c user.name=kit add -A
          & git -c user.email=kit@example.com -c user.name=kit commit -qm init
          Add-Content -Path "x.php" -Value "`n// edit" -Encoding ascii
        } finally { Pop-Location }

        Push-Location (Join-Path $mg "pc_web")
        try {
          & git init -q
          Set-Content -Path "a.vue" -Value "<template></template>" -Encoding ascii
          & git -c user.email=kit@example.com -c user.name=kit add -A
          & git -c user.email=kit@example.com -c user.name=kit commit -qm init
          Add-Content -Path "a.vue" -Value "`n<!-- edit -->" -Encoding ascii
        } finally { Pop-Location }

        $ssotItem = Get-Item (Join-Path $mg "docs\progress.md")
        $ssotItem.LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(-10)

        . (Join-Path $mg "scripts\kit-layout.ps1")
        $mgRepos = @(Get-KitGitRepos $mg)
        if ($mgRepos.Count -ge 2) { Ok "multi-git discovers child repos ($($mgRepos.Count))" } else { Bad "multi-git should find admin + pc_web, got $($mgRepos.Count)" }
        $mgRootGit = Test-Path (Join-Path $mg ".git")
        if (-not $mgRootGit) { Ok "multi-git workspace root has no .git" } else { Bad "multi-git fixture root should not be a git repo" }

        $mgCode = @(Get-KitChangedCode $mg)
        $mgJoined = ($mgCode -join '|')
        if ($mgJoined -match 'admin/.+\.php' -and $mgJoined -match 'pc_web/.+\.vue') {
          Ok "multi-git changed code includes php and vue"
        } else {
          Bad "multi-git changed code should include admin php + pc_web vue, got: $mgJoined"
        }
        if (-not (Test-KitSsotFresh $mg $mgCode)) { Ok "root docs mtime SSOT stale" } else { Bad "SSOT should be stale when child code is newer than root docs" }

        Push-Location $mg
        try {
          $mgVerify = @(& .\scripts\verify.ps1 2>&1 | ForEach-Object { "$_" })
          $mgVerify | ForEach-Object { Write-Host $_ }
          $mgV = $mgVerify -join "`n"
          if ($mgV -match '\[WARN\] ssot') { Ok "verify WARNs stale SSOT on multi-git" } else { Bad "verify should WARN ssot when child code dirty and root docs not updated" }
          if ($mgV -match '== Done: no ==') { Ok "multi-git stale SSOT is Done no" } else { Bad "multi-git stale SSOT should print Done no" }
        } finally { Pop-Location }

        (Get-Item (Join-Path $mg "docs\progress.md")).LastWriteTimeUtc = [datetime]::UtcNow
        if (Test-KitSsotFresh $mg $mgCode) { Ok "root docs mtime SSOT fresh" } else { Bad "SSOT should be fresh after touching workspace-root docs/*.md" }

        Push-Location $mg
        try {
          $omit = @(& .\scripts\verify.ps1 2>&1 | ForEach-Object { "$_" })
        } finally { Pop-Location }
        $omitText = $omit -join "`n"
        if ($omitText -match '\[WARN\] ssot' -and $omitText -match 'admin/.+\.php' -and $omitText -match 'pc_web/.+\.vue') {
          Ok "fresh docs still WARN when the latest row omits changed files"
        } else {
          Bad "verify should list changed paths missing from the progress row"
        }
        $heading = Get-KitProgressHeading
        $rowLine = '| 2026-10-13 | ' + ($mgCode -join ', ') + ' | verify |'
        $body = $heading + "`n| a | b |`n| --- | --- |`n" + $rowLine + "`n"
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [IO.File]::WriteAllText((Join-Path $mg "docs\progress.md"), $body, $utf8)
        Push-Location $mg
        try {
          $namedRun = @(& .\scripts\verify.ps1 2>&1 | ForEach-Object { "$_" })
        } finally { Pop-Location }
        $namedText = $namedRun -join "`n"
        if ($namedText -match '\[PASS\] ssot' -and $namedText -match '== Done: yes ==') {
          Ok "progress row that names changed files is Done yes"
        } else {
          Bad "naming changed files in the latest row should pass ssot and Done yes"
        }

        # Remaining edits are older than SSOT. A deleted path must still count
        # (parent dir mtime), otherwise delete-only trees look fresh.
        (Get-Item (Join-Path $mg "pc_web\a.vue")).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(-30)
        Remove-Item -LiteralPath (Join-Path $mg "admin\x.php") -Force
        $adminDir = Get-Item (Join-Path $mg "admin")
        $adminDir.LastWriteTimeUtc = [datetime]::UtcNow
        $docsAfterDel = Get-Item (Join-Path $mg "docs\progress.md")
        $docsAfterDel.LastWriteTimeUtc = $adminDir.LastWriteTimeUtc.AddMinutes(-5)
        $mgDel = @(Get-KitChangedCode $mg)
        $mgDelJoined = ($mgDel -join '|')
        if ($mgDelJoined -match 'admin/.+\.php') { Ok "deleted php stays in changed code" } else { Bad "deleted code should stay in changed list, got: $mgDelJoined" }
        if (-not (Test-KitSsotFresh $mg $mgDel)) { Ok "deleted code keeps SSOT stale" } else { Bad "SSOT should be stale when code was deleted and root docs not updated" }
        $docsAfterDel.LastWriteTimeUtc = $adminDir.LastWriteTimeUtc.AddMinutes(5)
        if (Test-KitSsotFresh $mg $mgDel) { Ok "deleted code SSOT fresh after docs touch" } else { Bad "SSOT should be fresh after updating root docs following a deletion" }

        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $mg "scripts\lint.ps1") (Join-Path $mg "pc_web\a.vue") | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok "lint skips .vue (not php -l)" } else { Bad "lint .vue should skip exit 0, got $LASTEXITCODE" }
      } finally {
        if (Test-Path $mg) { Remove-Item $mg -Recurse -Force -ErrorAction SilentlyContinue }
      }
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

        $vSmoke = @(& .\scripts\verify.ps1 -BaseUrl "http://127.0.0.1:$port" 2>&1 | ForEach-Object { "$_" })
        $vSmoke | ForEach-Object { Write-Host $_ }
        if (($vSmoke -join "`n") -match '\[PASS\] smoke') { Ok "verify PASS smoke against this project's mock API" } else { Bad "verify should PASS smoke when probe hits our API" }
      }
      finally {
        if ($mockProc -and -not $mockProc.HasExited) {
          Stop-Process -Id $mockProc.Id -Force -ErrorAction SilentlyContinue
        }
      }
    }

    # --- repeat detection: same failing check N runs in a row (fingerprint = check names) ---
    # Start from a clean state so earlier verify calls in this dry-run cannot leak in.
    $fpFile = Join-Path $work '.verify-fingerprint'
    if (Test-Path $fpFile) { Remove-Item $fpFile -Force }
    $repeatSeen = $false
    $fpCounts = @()
    for ($i = 1; $i -le 3; $i++) {
      $o = @(& .\scripts\verify.ps1 -Target backend\sample_ok.php -SsotStrict 2>&1 | ForEach-Object { "$_" })
      if (Test-Path $fpFile) { $fpCounts += (Get-Content $fpFile -Raw).Trim() }
      if (($o -join "`n") -match '\[WARN\] repeat') { $repeatSeen = $true }
    }
    # The fingerprint must be check NAMES only (no paths, no hashes) plus a run counter --
    # a hash over paths/counts would reset on every run and never trip.
    $fpOk = ($fpCounts.Count -eq 3) -and
            ($fpCounts[0] -match '^[a-z][a-z-]*(\+[a-z][a-z-]*)* 1$') -and
            ($fpCounts[2] -match '^[a-z][a-z-]*(\+[a-z][a-z-]*)* 3$')
    if ($fpOk) { Ok "fingerprint is check names + run counter ($($fpCounts[2]))" } else { Bad "fingerprint should be names + counter, got '$($fpCounts -join ' | ')'" }
    if ($repeatSeen) { Ok "verify brakes after 3 identical failures" } else { Bad "verify should WARN repeat after 3 identical failures" }
    # The closing Next: line must not contradict the brake. The model follows the last line,
    # so "fix the first FAIL and re-run" would silently cancel the brake it just set.
    $nextLine = @(($o -join "`n") -split "`r?`n" | Where-Object { $_ -match '^Next:' } | Select-Object -Last 1)
    if ($nextLine.Count -gt 0 -and $nextLine[0] -match 'STOP') {
      Ok "verify Next: line stops instead of telling the model to re-run"
    } else {
      Bad "Next: should say STOP while the brake is on, got '$($nextLine -join '')'"
    }

    # The brake must lift on its own once nothing FAILs. Hide api-check (the fixture's only
    # always-FAIL check) so this run is clean, then put it back.
    $apiPath = Join-Path $work 'scripts\api-check.ps1'
    $apiBak = "$apiPath.bak"
    try {
      Rename-Item $apiPath $apiBak
      & .\scripts\verify.ps1 -Target backend\sample_ok.php 2>&1 | Out-Null
    } finally {
      if (Test-Path $apiBak) { Rename-Item $apiBak $apiPath }
    }
    if (-not (Test-Path $fpFile)) { Ok "verify clears the fingerprint when no check FAILs" } else { Bad "fingerprint should be removed when nothing FAILs" }

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
      if ($installShText -match '\.kit-new' -and $installShText -match 'exit 2' -and $installShText -match 'MERGE GUIDE') {
        Ok "install.sh source has merge-safe (.kit-new + exit 2 + MERGE GUIDE)"
      } else {
        Bad "install.sh missing merge-safe markers (.kit-new / exit 2 / MERGE GUIDE)"
      }
      $installPsText = Get-Content $install -Raw
      if ($installPsText -match 'MERGE GUIDE') { Ok "install.ps1 source has MERGE GUIDE" } else { Bad "install.ps1 missing MERGE GUIDE" }
    }
    # Seed a realistic project .gitignore BEFORE install: a non-ASCII comment (written from
    # char codes so this file stays ASCII) and deliberately no trailing newline, which is what
    # a hand-edited file often looks like. Both are traps for a read-modify-write installer.
    $projGiSeed = Join-Path $work ".gitignore"
    $cnComment = "# " + (-join ([char]0x6784, [char]0x5EFA, [char]0x4EA7, [char]0x7269))
    [IO.File]::WriteAllText($projGiSeed, ($cnComment + "`nnode_modules/"), (New-Object System.Text.UTF8Encoding($false)))
    $giSeedBytes = [IO.File]::ReadAllBytes($projGiSeed)

    & $install -KitRoot $KitRoot -ProjectRoot $work -Adapters "cursor,claude" 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
      Ok "install.ps1 merge-safe exit=$LASTEXITCODE"
    } else {
      Bad "install.ps1 unexpected exit $LASTEXITCODE"
    }

    # --- kit ignore rules must land in the PROJECT's .gitignore, not only the kit's own ---
    # verify writes .verify-fingerprint into the project root. Without this rule it becomes an
    # untracked file in every installed project -- the kit's own .gitignore does not reach here.
    $projGi = Join-Path $work ".gitignore"
    $giLines = if (Test-Path $projGi) { @(Get-Content $projGi) } else { @() }
    if ($giLines -contains '.verify-fingerprint') {
      Ok "installer added .verify-fingerprint to the project .gitignore"
    } else {
      Bad "project .gitignore should list .verify-fingerprint after install"
    }
    # Idempotent: re-running install must not duplicate the rule.
    $giBefore = @(Get-Content $projGi | Where-Object { $_ -eq '.verify-fingerprint' }).Count
    & $install -KitRoot $KitRoot -ProjectRoot $work -Adapters "cursor,claude" 2>&1 | Out-Null
    $giAfter = @(Get-Content $projGi | Where-Object { $_ -eq '.verify-fingerprint' }).Count
    if ($giAfter -eq $giBefore -and $giAfter -ge 1) {
      Ok "installer does not duplicate the ignore rule on re-run"
    } else {
      Bad "ignore rule duplicated on re-run ($giBefore -> $giAfter)"
    }

    # --- the installer must APPEND, never read-modify-write the project .gitignore ---
    # Regression guard: the first implementation did Get-Content (ANSI on PS 5.1) + WriteAllText
    # on the whole file. Every existing byte got re-encoded, so a Chinese comment in the
    # project's .gitignore turned into mojibake the moment the kit was installed.
    $giNowBytes = [IO.File]::ReadAllBytes($projGi)
    $prefixIntact = $giNowBytes.Length -ge $giSeedBytes.Length
    if ($prefixIntact) {
      for ($i = 0; $i -lt $giSeedBytes.Length; $i++) {
        if ($giNowBytes[$i] -ne $giSeedBytes[$i]) { $prefixIntact = $false; break }
      }
    }
    if ($prefixIntact) {
      Ok "installer left the pre-existing .gitignore bytes byte-for-byte untouched"
    } else {
      Bad "installer rewrote pre-existing .gitignore bytes (encoding corruption)"
    }
    $appended = [Text.Encoding]::UTF8.GetString($giNowBytes, $giSeedBytes.Length, $giNowBytes.Length - $giSeedBytes.Length)
    if ($appended.StartsWith("`n")) {
      Ok "installer starts the appended block on a fresh line (no glue onto last rule)"
    } else {
      Bad "appended ignore rules glued onto the last existing line (missing newline)"
    }
    if (([Text.Encoding]::UTF8.GetString($giNowBytes) -split "`n")[0] -eq $cnComment) {
      Ok "non-ASCII .gitignore comment still decodes to the original text"
    } else {
      Bad "non-ASCII .gitignore comment was corrupted by the installer"
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
      $gitCmd = Get-Command git -ErrorAction SilentlyContinue
      if ($gitCmd) {
        $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
        $beside = Join-Path $gitRoot "bin\bash.exe"
        if (Test-Path $beside) { $gitBash = $beside }
      }
    }
    if (-not $gitBash) {
      $cmdBash = Get-Command bash -ErrorAction SilentlyContinue
      if ($cmdBash -and $cmdBash.Source -notmatch '\\Windows\\[Ss]ystem32\\bash\.exe$') {
        $gitBash = $cmdBash.Source
      }
    }
    if ($gitBash) {
      # bash.exe started from PowerShell gets a rebuilt PATH that does NOT include Git's own
      # /usr/bin, so every coreutils call inside the .sh scripts dies with exit 127
      # ("mkdir: command not found", db.sh's cygpath guard). Prepending the Windows path from
      # PowerShell does not help -- MSYS drops entries that point inside its own install root.
      # BASH_ENV is sourced by every non-interactive bash, so the fix has to happen in-shell.
      $bashEnvFile = Join-Path $env:TEMP ("kit-bash-env-" + [guid]::NewGuid().ToString("n") + ".sh")
      [IO.File]::WriteAllText($bashEnvFile, "export PATH=/usr/bin:/bin:`$PATH`n", (New-Object System.Text.UTF8Encoding($false)))
      $env:BASH_ENV = $bashEnvFile -replace '\\', '/'
      $probe = @(& $gitBash -c 'command -v cygpath || echo MISSING' 2>&1 | ForEach-Object { "$_" })
      if (($probe -join '') -match 'cygpath$') {
        Ok "bash sees Git /usr/bin (BASH_ENV) -- .sh checks no longer report phantom exit 127"
      } else {
        Bad "bash still cannot find cygpath; .sh checks will report exit 127 ($($probe -join ' '))"
      }

      # --- install.sh: the NEW/FORCE summary must match the file lines it actually printed ---
      # Regression guard: the ignore-rule block reused the global "added" counter and reset it
      # to 0 mid-run, so the summary undercounted every core script installed before that point
      # (28 files created, summary reported 7). A silent undercount hides install failures.
      $shProj = Join-Path $env:TEMP ("kit-shinstall-" + [guid]::NewGuid().ToString("n"))
      New-Item -ItemType Directory -Force $shProj | Out-Null
      $shGi = Join-Path $shProj ".gitignore"
      [IO.File]::WriteAllText($shGi, ($cnComment + "`nnode_modules/"), (New-Object System.Text.UTF8Encoding($false)))
      $shSeedBytes = [IO.File]::ReadAllBytes($shGi)
      $shScript = $installSh -replace '\\', '/'
      $shKitArg = $KitRoot -replace '\\', '/'
      $shProjArg = $shProj -replace '\\', '/'
      $shOut = @(& $gitBash $shScript $shKitArg $shProjArg "cursor" 2>&1 | ForEach-Object { "$_" })
      $shFileLines = @($shOut | Where-Object { $_ -match '^\[(NEW|FORCE)\]' }).Count
      $shSummary = 0
      foreach ($l in $shOut) {
        $m = [regex]::Match($l, 'NEW/FORCE=(\d+)')
        if ($m.Success) { $shSummary = [int]$m.Groups[1].Value; break }
      }
      if ($shSummary -eq $shFileLines -and $shFileLines -gt 0) {
        Ok "install.sh summary NEW/FORCE=$shSummary matches the $shFileLines file(s) it reported"
      } else {
        Bad "install.sh summary NEW/FORCE=$shSummary but it printed $shFileLines [NEW]/[FORCE] line(s)"
      }
      $shBytes = [IO.File]::ReadAllBytes($shGi)
      $shPrefixOk = $shBytes.Length -ge $shSeedBytes.Length
      if ($shPrefixOk) {
        for ($i = 0; $i -lt $shSeedBytes.Length; $i++) {
          if ($shBytes[$i] -ne $shSeedBytes[$i]) { $shPrefixOk = $false; break }
        }
      }
      if ($shPrefixOk) {
        Ok "install.sh left the pre-existing .gitignore bytes untouched"
      } else {
        Bad "install.sh rewrote pre-existing .gitignore bytes"
      }
      $shText = [Text.Encoding]::UTF8.GetString($shBytes)
      if (($shText -split "`n") -contains '.verify-fingerprint') {
        Ok "install.sh added the kit rule to the project .gitignore"
      } else {
        Bad "install.sh did not add the kit rule to the project .gitignore"
      }
      & $gitBash $shScript $shKitArg $shProjArg "cursor" 2>&1 | Out-Null
      $shText2 = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($shGi))
      $shDup = @(($shText2 -split "`n") | Where-Object { $_ -eq '.verify-fingerprint' }).Count
      if ($shDup -eq 1) {
        Ok "install.sh does not duplicate the ignore rule on re-run"
      } else {
        Bad "install.sh duplicated the ignore rule on re-run (count=$shDup)"
      }
      Remove-Item $shProj -Recurse -Force -ErrorAction SilentlyContinue

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

      $klSh = Join-Path $KitRoot "templates\scripts\kit-layout.sh"
      if (Test-Path $klSh) {
        $tmpKl = Join-Path $work "_kit-layout.sh"
        $lfKl = ([IO.File]::ReadAllText($klSh) -replace "`r`n", "`n" -replace "`r", "`n")
        [IO.File]::WriteAllText($tmpKl, $lfKl, (New-Object System.Text.UTF8Encoding $false))
        & $gitBash -n $tmpKl 2>$null
        if ($LASTEXITCODE -eq 0) { Ok "kit-layout.sh bash -n syntax OK" } else { Bad "kit-layout.sh bash -n failed exit=$LASTEXITCODE" }
        $klUnix = (& $gitBash -c "cygpath -u '$($tmpKl -replace '\\','/')'").Trim()
        $delProbe = Join-Path $work "_kit-del-ssot.sh"
        $delBody = @"
set +e
. "$klUnix"
root=`$(mktemp -d)
mkdir -p "`$root/docs" "`$root/app"
echo ssot > "`$root/docs/progress.md"
(
  cd "`$root/app" || exit 1
  git init -q
  printf '%s\n' '<?php echo 1;' > a.php
  git -c user.email=kit@example.com -c user.name=kit add -A
  git -c user.email=kit@example.com -c user.name=kit commit -qm init
  rm -f a.php
)
code=`$(kit_changed_code "`$root")
touch -d "10 minutes ago" "`$root/docs/progress.md"
touch "`$root/app"
if kit_ssot_fresh "`$root" `$code; then echo BAD_FRESH; rm -rf "`$root"; exit 2; fi
touch "`$root/docs/progress.md"
if kit_ssot_fresh "`$root" `$code; then rm -rf "`$root"; exit 0; fi
echo BAD_STALE
rm -rf "`$root"
exit 3
"@
        $delBody = ($delBody -replace "`r`n", "`n" -replace "`r", "`n")
        [IO.File]::WriteAllText($delProbe, $delBody, (New-Object System.Text.UTF8Encoding $false))
        $delOut = & $gitBash $delProbe 2>&1 | ForEach-Object { "$_" }
        if ($delOut) { $delOut | ForEach-Object { Write-Host $_ } }
        if ($LASTEXITCODE -eq 0) { Ok "kit-layout.sh deleted code keeps SSOT stale until docs touch" } else { Bad "kit-layout.sh deletion SSOT expected exit 0, got $LASTEXITCODE" }
      } else {
        Bad "templates/scripts/kit-layout.sh missing"
      }

      $remoteSh = Join-Path (Get-Location) "scripts\git-remote-add.sh"
      if (Test-Path $remoteSh) {
        $lfR = ([IO.File]::ReadAllText($remoteSh) -replace "`r`n", "`n" -replace "`r", "`n")
        [IO.File]::WriteAllText($remoteSh, $lfR, (New-Object System.Text.UTF8Encoding $false))
        & $gitBash -n $remoteSh 2>$null
        if ($LASTEXITCODE -eq 0) { Ok "git-remote-add.sh bash -n syntax OK" } else { Bad "git-remote-add.sh bash -n failed exit=$LASTEXITCODE" }
      } else {
        Bad "scripts/git-remote-add.sh missing in workdir"
      }

      $verifySh = Join-Path (Get-Location) "scripts\verify.sh"
      if (Test-Path $verifySh) {
        $lfV = ([IO.File]::ReadAllText($verifySh) -replace "`r`n", "`n" -replace "`r", "`n")
        [IO.File]::WriteAllText($verifySh, $lfV, (New-Object System.Text.UTF8Encoding $false))
        & $gitBash -n $verifySh 2>$null
        if ($LASTEXITCODE -eq 0) { Ok "verify.sh bash -n syntax OK" } else { Bad "verify.sh bash -n failed exit=$LASTEXITCODE" }
        # Dead port: must SKIP smoke even if localhost:8080 is occupied by another stack.
        $vShOut = & $gitBash $verifySh --base-url "http://127.0.0.1:1" 2>&1 | ForEach-Object { "$_" }
        $vShOut | ForEach-Object { Write-Host $_ }
        $vShText = $vShOut -join "`n"
        if ($vShText -match '== Result:') { Ok "verify.sh prints Result line" } else { Bad "verify.sh should print == Result:" }
        if ($vShText -match '== Done: no ==') { Ok "verify.sh prints Done no when a check fails" } else { Bad "verify.sh should print Done no" }
        if ($vShText -match '\[SKIP\] smoke') { Ok "verify.sh skips smoke on dead port" } else { Bad "verify.sh should SKIP smoke when probe cannot connect" }
      } else {
        Bad "scripts/verify.sh missing in workdir"
      }

      $hookDir = Join-Path $KitRoot "templates\hooks\cursor\hooks"
      if (Test-Path $hookDir) {
        $hookShN = 0; $hookShBad = 0
        foreach ($hf in Get-ChildItem $hookDir -Filter *.sh -File) {
          $tmpH = Join-Path $work ("_" + $hf.Name)
          $lfH = ([IO.File]::ReadAllText($hf.FullName) -replace "`r`n", "`n" -replace "`r", "`n")
          [IO.File]::WriteAllText($tmpH, $lfH, (New-Object System.Text.UTF8Encoding $false))
          & $gitBash -n $tmpH 2>$null
          if ($LASTEXITCODE -eq 0) { $hookShN++ } else { $hookShBad++; Bad "hook $($hf.Name) bash -n failed" }
        }
        if ($hookShBad -eq 0 -and $hookShN -gt 0) { Ok "hooks *.sh bash -n OK ($hookShN files)" }
        $hookPsN = 0; $hookPsBad = 0
        foreach ($hf in Get-ChildItem $hookDir -Filter *.ps1 -File) {
          $parseErr = $null
          [void][System.Management.Automation.Language.Parser]::ParseFile($hf.FullName, [ref]$null, [ref]$parseErr)
          if ($parseErr -and $parseErr.Count -gt 0) { $hookPsBad++; Bad "hook $($hf.Name) parse error" } else { $hookPsN++ }
        }
        if ($hookPsBad -eq 0 -and $hookPsN -gt 0) { Ok "hooks *.ps1 parse OK ($hookPsN files)" }
      } else {
        Bad "templates/hooks/cursor/hooks missing"
      }

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
  if ($bashEnvFile -and (Test-Path $bashEnvFile)) {
    Remove-Item $bashEnvFile -Force -ErrorAction SilentlyContinue
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
