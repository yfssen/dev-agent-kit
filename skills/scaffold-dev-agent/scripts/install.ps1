# Install core + adapters. Never overwrite existing files unless -Force.
# Existing dest -> write sibling "*.kit-new" and report MERGE.
# Usage: .\install.ps1 -KitRoot <kit> -ProjectRoot <proj> [-Adapters cursor,claude,kiro] [-Force]
# -Adapters auto : detect adapters already installed in the project and re-sync
#   them merge-safe (one stable command upgrades any project), then report any
#   opt-in capability layers (e.g. hooks) the kit offers but the project lacks.

param(
    [Parameter(Mandatory = $true)][string]$KitRoot,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$Adapters = "cursor,claude,kiro",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$KitRoot = (Resolve-Path $KitRoot).Path
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$script:added = 0
$script:merged = 0
$script:skippedSame = 0
$script:mergeList = New-Object System.Collections.Generic.List[string]

function Ensure-Dir([string]$p) {
    New-Item -ItemType Directory -Force -Path $p | Out-Null
}

function Install-File([string]$src, [string]$dest) {
    if (-not (Test-Path $src)) {
        Write-Host "[MISS] source missing: $src"
        return
    }
    Ensure-Dir (Split-Path $dest -Parent)
    if (-not (Test-Path $dest)) {
        Copy-Item $src $dest
        Write-Host "[NEW]  $dest"
        $script:added++
        return
    }
    if ($Force) {
        Copy-Item $src $dest -Force
        Write-Host "[FORCE] $dest"
        $script:added++
        return
    }
    $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
    $dstHash = (Get-FileHash $dest -Algorithm SHA256).Hash
    if ($srcHash -eq $dstHash) {
        Write-Host "[SAME] $dest"
        $script:skippedSame++
        return
    }
    $incoming = "$dest.kit-new"
    Copy-Item $src $incoming -Force
    Write-Host "[MERGE] exists -> wrote $incoming (read both, then merge)"
    $script:merged++
    $script:mergeList.Add($dest) | Out-Null
}

Write-Host "KIT=$KitRoot"
Write-Host "PROJECT=$ProjectRoot"
Write-Host "MODE=$(if ($Force) { 'FORCE overwrite' } else { 'merge-safe (no overwrite)' })"

Ensure-Dir (Join-Path $ProjectRoot "docs")
Ensure-Dir (Join-Path $ProjectRoot "scripts")

Install-File (Join-Path $KitRoot "templates\AGENTS.md") (Join-Path $ProjectRoot "AGENTS.md")

$docsSrc = Join-Path $KitRoot "templates\docs"
Get-ChildItem $docsSrc -File -ErrorAction SilentlyContinue | ForEach-Object {
    Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot "docs") $_.Name)
}

$scriptsSrc = Join-Path $KitRoot "templates\scripts"
Get-ChildItem $scriptsSrc -File -ErrorAction SilentlyContinue | ForEach-Object {
    Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot "scripts") $_.Name)
}

# --- Merge kit-required ignore rules into the PROJECT's .gitignore (append-only, idempotent) ---
# verify writes .verify-fingerprint into the project root. The kit's own .gitignore does not
# reach into projects, so without this the file shows up as untracked in every project that
# installs the kit. Rules live in templates/gitignore-extra.txt and travel with the install.
$ignoreExtra = Join-Path $KitRoot "templates\gitignore-extra.txt"
if (Test-Path $ignoreExtra) {
    # Explicit UTF8: the kit's rule file is ASCII, but PS 5.1 Get-Content defaults to the
    # ANSI code page and would mis-decode anything non-ASCII it ever gains.
    $rules = @(Get-Content -LiteralPath $ignoreExtra -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') })
    if ($rules.Count -gt 0) {
        $giPath = Join-Path $ProjectRoot ".gitignore"
        $existing = @()
        if (Test-Path $giPath) {
            # Explicit UTF8 again: project .gitignore files commonly carry Chinese comments.
            # Reading them as ANSI and writing back re-encodes every byte and corrupts them.
            $existing = @(Get-Content -LiteralPath $giPath -Encoding UTF8)
        }
        $missing = @($rules | Where-Object { $existing -notcontains $_ })
        if ($missing.Count -gt 0) {
            # APPEND-ONLY. Never read-modify-write the whole file: that re-encodes existing
            # content (PS 5.1 is not UTF-8 by default) and rewrites line endings. AppendAllText
            # leaves every existing byte untouched, so the project keeps its own encoding.
            $block = (@('# dev-agent-kit: files this toolkit creates on this machine') + $missing) -join "`n"
            $prefix = ""
            if (Test-Path $giPath) {
                $raw = [IO.File]::ReadAllBytes($giPath)
                if ($raw.Length -gt 0) {
                    # A hand-edited .gitignore often has no trailing newline; without this the
                    # first appended rule would glue onto the last existing line.
                    $prefix = if ($raw[$raw.Length - 1] -eq 10) { "`n" } else { "`n`n" }
                }
            }
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::AppendAllText($giPath, $prefix + $block + "`n", $utf8NoBom)
            Write-Host "[GITIGNORE] added $($missing.Count) rule(s): $($missing -join ', ')"
        }
        else {
            Write-Host "[GITIGNORE] project .gitignore already covers the kit's rules"
        }
    }
}

$wanted = @($Adapters.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

# Opt-in capability layers (not AI-tool choices). "auto" never force-adds these;
# it only reports the missing ones so you can decide to opt in.
$capabilityLayers = @('hooks')

function Detect-Adapters([string]$root) {
    $found = New-Object System.Collections.Generic.List[string]
    $rules = Join-Path $root ".cursor\rules"
    if ((Test-Path $rules) -and (Get-ChildItem $rules -Filter *.mdc -File -ErrorAction SilentlyContinue)) { $found.Add("cursor") | Out-Null }
    if (Test-Path (Join-Path $root "CLAUDE.md")) { $found.Add("claude") | Out-Null }
    if (Test-Path (Join-Path $root ".kiro\steering")) { $found.Add("kiro") | Out-Null }
    if ((Test-Path (Join-Path $root "CODEBUDDY.md")) -or (Test-Path (Join-Path $root ".codebuddy"))) { $found.Add("workbuddy") | Out-Null }
    if (Test-Path (Join-Path $root ".qoder\rules")) { $found.Add("qoder") | Out-Null }
    if (Test-Path (Join-Path $root ".cursor\hooks.json")) { $found.Add("hooks") | Out-Null }
    return $found
}

# "auto": expand to whatever the project already has, so one command re-syncs any project.
if ($wanted -contains "auto") {
    $detected = @(Detect-Adapters $ProjectRoot)
    $wanted = @($wanted | Where-Object { $_ -ne "auto" })
    $wanted = @(($wanted + $detected) | Select-Object -Unique)
    Write-Host ("AUTO-DETECTED adapters: " + $(if ($detected.Count) { [string]::Join(', ', $detected) } else { '(none; fresh project)' }))
}

foreach ($a in $wanted) {
    switch ($a) {
        "cursor" {
            Ensure-Dir (Join-Path $ProjectRoot ".cursor\rules")
            Get-ChildItem (Join-Path $KitRoot "adapters\cursor") -Filter *.mdc -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".cursor\rules") $_.Name)
            }
            Write-Host "[OK] adapter cursor"
        }
        "claude" {
            Install-File (Join-Path $KitRoot "adapters\claude\CLAUDE.md") (Join-Path $ProjectRoot "CLAUDE.md")
            Write-Host "[OK] adapter claude"
        }
        "codex" {
            Write-Host "[OK] adapter codex (AGENTS.md is enough)"
        }
        "kiro" {
            Ensure-Dir (Join-Path $ProjectRoot ".kiro\steering")
            Get-ChildItem (Join-Path $KitRoot "adapters\kiro\steering") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".kiro\steering") $_.Name)
            }
            Write-Host "[OK] adapter kiro"
        }
        { $_ -in @("workbuddy", "codebuddy") } {
            Install-File (Join-Path $KitRoot "adapters\workbuddy\CODEBUDDY.md") (Join-Path $ProjectRoot "CODEBUDDY.md")
            Ensure-Dir (Join-Path $ProjectRoot ".codebuddy\rules")
            Get-ChildItem (Join-Path $KitRoot "adapters\workbuddy\rules") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".codebuddy\rules") $_.Name)
            }
            # WorkBuddy often indexes project skills more reliably than user-global alone
            $projSkill = Join-Path $ProjectRoot ".codebuddy\skills\scaffold-dev-agent"
            Ensure-Dir (Join-Path $projSkill "scripts")
            $skillSrc = Join-Path $KitRoot "skills\scaffold-dev-agent"
            Install-File (Join-Path $skillSrc "SKILL.md") (Join-Path $projSkill "SKILL.md")
            Install-File (Join-Path $skillSrc "adapter-map.md") (Join-Path $projSkill "adapter-map.md")
            Install-File (Join-Path $skillSrc "init-workflow.md") (Join-Path $projSkill "init-workflow.md")
            Get-ChildItem (Join-Path $skillSrc "scripts") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $projSkill "scripts") $_.Name)
            }
            Set-Content -Path (Join-Path $projSkill "kit-path.txt") -Value $KitRoot -Encoding ascii
            Write-Host "[OK] adapter workbuddy/codebuddy (+ project .codebuddy/skills/scaffold-dev-agent)"
        }
        "qoder" {
            Ensure-Dir (Join-Path $ProjectRoot ".qoder\rules")
            Get-ChildItem (Join-Path $KitRoot "adapters\qoder\rules") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".qoder\rules") $_.Name)
            }
            Write-Host "[OK] adapter qoder (AGENTS.md + .qoder/rules)"
        }
        "hooks" {
            # Deterministic guardrails (Cursor): guard-shell / auto-lint / backup-ssot.
            $hookSrc = Join-Path $KitRoot "templates\hooks\cursor"
            Install-File (Join-Path $hookSrc "hooks.json") (Join-Path $ProjectRoot ".cursor\hooks.json")
            Install-File (Join-Path $hookSrc "hooks.posix.json") (Join-Path $ProjectRoot ".cursor\hooks.posix.json")
            Ensure-Dir (Join-Path $ProjectRoot ".cursor\hooks")
            Get-ChildItem (Join-Path $hookSrc "hooks") -File | ForEach-Object {
                Install-File $_.FullName (Join-Path (Join-Path $ProjectRoot ".cursor\hooks") $_.Name)
            }
            Write-Host "[OK] adapter hooks (Cursor .cursor/hooks.json + hooks/; mac/linux: rename hooks.posix.json -> hooks.json)"
        }
        default {
            Write-Host "[SKIP] unknown adapter: $a"
        }
    }
}

Write-Host ""
Write-Host "== Summary: NEW/FORCE=$added MERGE_NEEDED=$merged SAME=$skippedSame =="

# Report opt-in capability layers the kit offers but the project does not have yet.
$installedNow = @(Detect-Adapters $ProjectRoot)
foreach ($cap in $capabilityLayers) {
    if ($installedNow -notcontains $cap) {
        Write-Host "[AVAILABLE] optional capability not installed: $cap -- re-run with -Adapters $cap to add it"
    }
}

if ($mergeList.Count -gt 0) {
    Write-Host "Merge these (read existing + *.kit-new, keep project facts, add kit tooling):"
    foreach ($m in $mergeList) { Write-Host "  - $m" }
    Write-Host "After merge, delete the sibling *.kit-new files."
    Write-Host "MERGE GUIDE: keep project # ADAPT values (BaseUrl, ProbePath, .env path, checker command, filled progress snapshot)."
    Write-Host "MERGE GUIDE: take kit behavior from *.kit-new (kit-layout multi-git, workspace-root docs SSOT, code extensions, cooldown)."
    Write-Host "MERGE GUIDE: Git layout in scripts/scan-project.ps1 and .sh is new kit behavior. Old projects lack ## Git layout and repo_remotes. Take that section from *.kit-new, then run the merged scan. Record repos that already exist. Ask once only for project dirs that still have no .git. For each repo_remotes value none, ask once for an existing git URL or skip, and add it only with scripts/git-remote-add. Do not open a Gitee or GitHub repo. Do not commit. Do not push. Do not git config. Do not redo init."
    Write-Host "MERGE GUIDE: single-repo git status, .php-only, and 1200s cooldown are old kit defaults, not project facts. Replace them."
    Write-Host "MERGE GUIDE: ssot-reminder must not print followup_message. Drop the stop hook. Verify owns the SSOT WARN."
    Write-Host "MERGE GUIDE: verify prints Done: yes only when Result is PASS and WARN=0. Exit 1 only on FAIL. The first FAIL line is the next edit. Next: STOP means the same checks failed three times: reproduce before another edit. A WARN means append one progress row (what changed, which check) and re-run. Take this from verify *.kit-new."
    Write-Host "MERGE GUIDE: daily work reads progress section 2 and the last 10 rows of section 6, then only the code they point at. Keep older rows. Update the architecture doc only when observable behavior changes. Reproduce a bug once before editing. Quote Done: yes from this turn. Name changed files the task did not ask for."
    Write-Host "MERGE GUIDE: coding rules say write it straight. No new interface, base class, factory, or generic layer for a single call. Backend follows the existing controller and service style. Take this from coding *.kit-new."
    Write-Host "MERGE GUIDE: the latest progress row must name each changed code path. verify WARNs with the missing paths. Take Get-KitUnnamedChanges from kit-layout *.kit-new."
    Write-Host "MERGE GUIDE: leaving *.kit-new unmerged means this upgrade did not land."
    exit 2
}
Write-Host "Next: fill placeholders / # ADAPT if still templated."
exit 0
