<#
.SYNOPSIS
  Production gate for the Efka Engineering System: one command, one verdict.
.DESCRIPTION
  Runs every objective check that applies on this host and prints a section table:
    doctor   - toolchain, agent surfaces, MCP, repos, secret files, disk
    secrets  - high-confidence credential scan over the hub and the repos you pass
    sandbox  - execution boundary preflight (rootless podman + pinned image)
    adapters - optional per-host checks found in adapters\<name>\verify.ps1
    integrations - optional add-ons found in integrations\<name>\verify.ps1
  Writes logs\verify-<timestamp>.json and .txt next to the hub (git-ignored).
  Exit code 0 = every section OK/WARN/INFO, 1 = at least one FAIL.
.PARAMETER RequireSandbox
  Treat an unavailable execution boundary as FAIL instead of WARN.
.PARAMETER DeepSandbox
  Also run tests\sandbox-selftest.ps1 (10 boundary cases) and tests\admit-task-selftest.ps1
  (5 contract cases), about 25 s in total.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\verify-all.ps1
  powershell -ExecutionPolicy Bypass -File .\verify-all.ps1 -Repos 'C:\work\api' -NoLog
  powershell -ExecutionPolicy Bypass -File .\verify-all.ps1 -DeepSandbox -RequireSandbox
#>
[CmdletBinding()]
param(
    [string[]]$Repos = @(),
    [string]$HubRoot = '',
    [switch]$RequireSandbox,
    [switch]$DeepSandbox,
    [switch]$NoLog
)

$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($HubRoot)) {
    # Walk up until manifest.json is found: works both in the repo (core/scripts)
    # and in an installed layout (<target>/scripts).
    $probe = $PSScriptRoot
    while ($probe -and -not (Test-Path -LiteralPath (Join-Path $probe 'manifest.json'))) {
        $parentDir = Split-Path $probe -Parent
        if ($parentDir -eq $probe) { break }
        $probe = $parentDir
    }
    $HubRoot = if ($probe) { $probe } else { (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
}

$sections = New-Object System.Collections.ArrayList
$failures = 0

function Add-Section([string]$Name, [string]$Status, [string]$Detail, [string[]]$Lines) {
    [void]$sections.Add([pscustomobject]@{ Section = $Name; Status = $Status; Detail = $Detail; Lines = @($Lines) })
    if ($Status -eq 'FAIL') { $script:failures++ }
}

function Invoke-Child {
    param([string]$Name, [string]$ScriptPath, [string[]]$ScriptArgs)
    if (-not (Test-Path -LiteralPath $ScriptPath)) { Add-Section $Name 'FAIL' "missing script: $ScriptPath" @(); return }
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs 2>&1 | ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
    if ($null -eq $code -and $out.Count -eq 0) {
        Add-Section $Name 'WARN' 'child process could not start (restricted invocation) - re-run from a normal terminal' @()
        return
    }
    $status = if ($code -eq 0) { 'OK' } else { 'FAIL' }
    $summary = ($out | Select-Object -Last 2) -join ' | '
    Add-Section $Name $status ("exit={0}; {1}" -f $code, $summary) $out
}

Write-Output '== Efka Engineering System :: verify-all =='
Write-Output ''

$doctorArgs = @()
if ($Repos.Count -gt 0) { $doctorArgs += @('-Repos', ($Repos -join ',')) }
Invoke-Child -Name 'doctor' -ScriptPath (Join-Path $PSScriptRoot 'system-doctor.ps1') -ScriptArgs $doctorArgs

$secretPaths = (@($HubRoot) + $Repos) -join ','
$secretArgs = @('-Paths', $secretPaths)
Invoke-Child -Name 'secrets' -ScriptPath (Join-Path $PSScriptRoot 'scan-secrets.ps1') -ScriptArgs $secretArgs

# execution boundary: preflight only (fails closed at run time, not at gate time)
$sandboxRunner = Join-Path $PSScriptRoot 'sandbox-run.ps1'
if (-not (Test-Path -LiteralPath $sandboxRunner)) {
    Add-Section 'sandbox' 'FAIL' 'missing sandbox-run.ps1' @()
}
else {
    $sbOut = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $sandboxRunner -Command 'true' -DryRun 2>&1 | ForEach-Object { $_.ToString() })
    $sbCode = $LASTEXITCODE
    $sbHead = ($sbOut | Where-Object { $_.Trim() } | Select-Object -First 1)
    if ($sbCode -eq 0) {
        Add-Section 'sandbox' 'OK' 'rootless podman + pinned image ready (preflight)' @()
    }
    elseif ($sbCode -eq 2) {
        Add-Section 'sandbox' $(if ($RequireSandbox) { 'FAIL' } else { 'WARN' }) ('execution boundary unavailable: ' + $sbHead) $sbOut
    }
    else {
        Add-Section 'sandbox' 'WARN' ("preflight exit=$sbCode; $sbHead") $sbOut
    }
}

if ($DeepSandbox) {
    $selftest = Join-Path (Join-Path $HubRoot 'tests') 'sandbox-selftest.ps1'
    if (-not (Test-Path -LiteralPath $selftest)) { $selftest = Join-Path (Split-Path $PSScriptRoot -Parent) 'tests\sandbox-selftest.ps1' }
    if (-not (Test-Path -LiteralPath $selftest)) { Add-Section 'sandbox:selftest' 'WARN' 'sandbox-selftest.ps1 not installed' @() }
    else {
        $stOut = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $selftest 2>&1 | ForEach-Object { $_.ToString() })
        $stCode = $LASTEXITCODE
        $stSummary = ($stOut | Where-Object { $_ -match 'sandbox self-test:' } | Select-Object -Last 1)
        if ($stCode -eq 0) { Add-Section 'sandbox:selftest' 'OK' $stSummary $stOut }
        else { Add-Section 'sandbox:selftest' 'FAIL' ("$stSummary") $stOut }
    }

    $admitTest = Join-Path (Join-Path $HubRoot 'tests') 'admit-task-selftest.ps1'
    if (-not (Test-Path -LiteralPath $admitTest)) { $admitTest = Join-Path (Split-Path $PSScriptRoot -Parent) 'tests\admit-task-selftest.ps1' }
    if (-not (Test-Path -LiteralPath $admitTest)) { Add-Section 'contracts:selftest' 'WARN' 'admit-task-selftest.ps1 not installed' @() }
    else {
        $cOut = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $admitTest 2>&1 | ForEach-Object { $_.ToString() })
        $cCode = $LASTEXITCODE
        $cSummary = ($cOut | Where-Object { $_ -match 'admission self-test:' } | Select-Object -Last 1)
        if ($cCode -eq 0) { Add-Section 'contracts:selftest' 'OK' $cSummary $cOut }
        else { Add-Section 'contracts:selftest' 'FAIL' ("$cSummary") $cOut }
    }
}

# optional per-host adapters: adapters\<name>\verify.ps1
$adapterRoot = Join-Path $HubRoot 'adapters'
if (Test-Path -LiteralPath $adapterRoot) {
    $adapterScripts = @(Get-ChildItem -LiteralPath $adapterRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $v = Join-Path $_.FullName 'verify.ps1'
            if (Test-Path -LiteralPath $v) { $v }
        })
    if ($adapterScripts.Count -eq 0) { Add-Section 'adapters' 'INFO' 'no adapter verify.ps1 present' @() }
    foreach ($a in $adapterScripts) {
        Invoke-Child -Name ('adapter:' + (Split-Path (Split-Path $a -Parent) -Leaf)) -ScriptPath $a -ScriptArgs @()
    }
}
else { Add-Section 'adapters' 'INFO' 'no adapters/ directory' @() }

# optional add-ons: integrations\<name>\verify.ps1 (third-party agent content, opt-in)
$integrationRoot = Join-Path $HubRoot 'integrations'
if (Test-Path -LiteralPath $integrationRoot) {
    $integrationScripts = @(Get-ChildItem -LiteralPath $integrationRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $v = Join-Path $_.FullName 'verify.ps1'
            if (Test-Path -LiteralPath $v) { $v }
        })
    if ($integrationScripts.Count -eq 0) { Add-Section 'integrations' 'INFO' 'no add-on verify.ps1 present' @() }
    foreach ($i in $integrationScripts) {
        Invoke-Child -Name ('integration:' + (Split-Path (Split-Path $i -Parent) -Leaf)) -ScriptPath $i -ScriptArgs @()
    }
}
else { Add-Section 'integrations' 'INFO' 'no integrations/ directory' @() }

Write-Output ''
$sections | Format-Table -AutoSize Section, Status, Detail | Out-String -Width 220 | Write-Output
$counts = $sections | Group-Object Status -AsHashTable
$ok = 0; $warn = 0; $fail = 0
if ($counts) {
    if ($counts.ContainsKey('OK')) { $ok = $counts['OK'].Count }
    if ($counts.ContainsKey('WARN')) { $warn = $counts['WARN'].Count }
    if ($counts.ContainsKey('FAIL')) { $fail = $counts['FAIL'].Count }
}
Write-Output ("verify-all: OK={0} WARN={1} FAIL={2}" -f $ok, $warn, $fail)

if (-not $NoLog) {
    $logDir = Join-Path $HubRoot 'logs'
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    try {
        ConvertTo-Json -Input @{ timestamp = (Get-Date).ToString('s'); ok = $ok; warn = $warn; fail = $fail; sections = @($sections) } -Depth 5 |
            Set-Content -LiteralPath (Join-Path $logDir "verify-$stamp.json") -Encoding UTF8 -ErrorAction Stop
        ($sections | Format-Table -AutoSize Section, Status, Detail | Out-String -Width 220) |
            Set-Content -LiteralPath (Join-Path $logDir "verify-$stamp.txt") -Encoding UTF8 -ErrorAction Stop
        Write-Output ("log: " + (Join-Path $logDir "verify-$stamp.json"))
    }
    catch { Write-Output ('log NOT written: ' + $_.Exception.Message) }

    # keep the newest 60 runs so logs/ cannot grow without bound
    $all = @(Get-ChildItem -LiteralPath $logDir -Filter 'verify-*' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($all.Count -gt 60) { $all | Select-Object -Skip 60 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue } }
}

exit $(if ($fail -gt 0) { 1 } else { 0 })
