# [verify] API smoke test. See .cursor/rules/tooling.mdc.
# Gets a token via a dev-only login fixture, then hits public + authed endpoints.
# PASS = HTTP 200 + JSON has expected shape. WARN = alive but business error. FAIL = network/404.
# ADAPT: BaseUrl default, the token fixture path, and the endpoint lists.

param(
    [string]$BaseUrl = "http://localhost:8080",   # ADAPT: local env that serves CURRENT code
    [string]$Mobile = "13800138001"               # ADAPT: fixture identity
)

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$pass = 0; $warn = 0; $fail = 0

function Invoke-Api([string]$Path, [hashtable]$Query) {
    $url = $BaseUrl.TrimEnd('/') + $Path
    if ($Query -and $Query.Count -gt 0) {
        $pairs = foreach ($k in $Query.Keys) { "$k=$([uri]::EscapeDataString([string]$Query[$k]))" }
        $url = $url + "?" + ($pairs -join "&")
    }
    try { return @{ ok = $true; data = (Invoke-RestMethod -Uri $url -TimeoutSec 20 -Method Get) } }
    catch { return @{ ok = $false; err = $_.Exception.Message } }
}

function Check([string]$Name, [string]$Path, [hashtable]$Query) {
    $r = Invoke-Api $Path $Query
    if (-not $r.ok) { $script:fail++; Write-Host ("[FAIL] $Name  $Path  -> " + $r.err) -ForegroundColor Red; return }
    $code = $r.data.code                                   # ADAPT: your API's status field
    if ($null -eq $code) { $script:fail++; Write-Host ("[FAIL] $Name  $Path  -> no 'code' (not API JSON)") -ForegroundColor Red }
    elseif ($code -lt 0) { $script:warn++; Write-Host ("[WARN] $Name  $Path  -> code=$code " + $r.data.message) -ForegroundColor Yellow }
    else { $script:pass++; Write-Host ("[PASS] $Name  $Path") -ForegroundColor Green }
}

Write-Host "== Base: $BaseUrl =="

Write-Host "`n-- Public endpoints --"                     # ADAPT list
Check "home.info" "/api/website/info" @{}

Write-Host "`n-- Login (fixture) --"                      # ADAPT fixture path
$login = Invoke-Api "/api/testlogin/login" @{ mobile = $Mobile }
$token = $null
if ($login.ok -and $login.data.code -eq 0) {
    $token = $login.data.data.token
    Write-Host "[PASS] login" -ForegroundColor Green; $pass++
} else {
    $fail++; Write-Host "[FAIL] login -> cannot get token; skip authed checks" -ForegroundColor Red
}

if ($token) {
    Write-Host "`n-- Authed endpoints --"                 # ADAPT list
    $t = @{ token = $token }
    Check "user.info" "/api/user/info" $t
}

Write-Host ("`n== Summary: PASS=$pass WARN=$warn FAIL=$fail ==")
if ($fail -gt 0) { exit 1 }
exit 0
