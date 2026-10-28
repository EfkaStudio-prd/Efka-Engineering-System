<#
.SYNOPSIS
  Self-test of task admission control (admit-task.ps1).
.DESCRIPTION
  Proves that a contract without the fields that make work checkable cannot start a job:
    C1 the shipped template is admitted and creates state.json
    C2 a contract without acceptance commands is rejected
    C3 execute-sandboxed without a pinned image is rejected
    C4 a malformed job_id is rejected
    C5 JSON input is accepted (tooling path)
  Exit 0 only when every case passes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$core = Split-Path $PSScriptRoot -Parent
$admit = Join-Path $core 'scripts\admit-task.ps1'
$template = Join-Path $core 'templates\TASK_CONTRACT.md'
if (-not (Test-Path $admit)) { throw "admit-task.ps1 not found at $admit" }

$results = New-Object System.Collections.ArrayList
function Case([string]$Id, [string]$Name, [bool]$Pass, [string]$Evidence) {
    [void]$results.Add([pscustomobject]@{ Id = $Id; Case = $Name; Result = $(if ($Pass) { 'PASS' } else { 'FAIL' }); Evidence = $Evidence })
}

$tmpHub = Join-Path $env:TEMP ('ees-admit-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmpHub | Out-Null
Set-Content -LiteralPath (Join-Path $tmpHub 'manifest.json') -Value '{"name":"admit-test"}' -Encoding UTF8

function Invoke-Admit([string[]]$ArgList) {
    $all = @('-Path') + @()
    $script = Join-Path $env:TEMP ('ees-admit-case-' + [guid]::NewGuid().ToString('N') + '.ps1')
    $cmd = @($ArgList | Where-Object { $_ } )
    $body = "& '$admit' " + ($cmd -join ' ') + " -HubRoot '$tmpHub'`nexit `$LASTEXITCODE`n"
    Set-Content -LiteralPath $script -Value $body -Encoding UTF8
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script 2>&1 | ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
    Remove-Item -LiteralPath $script -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Exit = $code; Out = ($out -join "`n") }
}

function New-Contract([string]$Name, [string[]]$Lines) {
    $p = Join-Path $env:TEMP ('ees-contract-' + $Name + '-' + [guid]::NewGuid().ToString('N') + '.md')
    Set-Content -LiteralPath $p -Value (@('---') + $Lines + @('---', '', '# contract')) -Encoding UTF8
    return $p
}

# C1 shipped template (positive)
$r = Invoke-Admit @('-Path', "`"$template`"")
$state = Join-Path $tmpHub 'logs\jobs\20261028-example-slug\state.json'
Case 'C1' 'template admitted' ($r.Exit -eq 0 -and $r.Out -match 'task ADMITTED' -and (Test-Path -LiteralPath $state)) ("exit=" + $r.Exit)

# C2 no acceptance
$p = New-Contract 'noaccept' @(
    'job_id: 20261028-no-acceptance',
    'goal: Something that is never verified',
    'scope:',
    '  - src/',
    'stop_condition: Stop when the goal looks done',
    'limits:',
    '  timeout_min: 30',
    '  trust_profile: read-only'
)
$r = Invoke-Admit @('-Path', "`"$p`"")
Case 'C2' 'missing acceptance rejected' ($r.Exit -eq 1 -and $r.Out -match 'acceptance must list') ("exit=" + $r.Exit)

# C3 sandboxed without digest
$p = New-Contract 'nodigest' @(
    'job_id: 20261028-no-digest',
    'goal: Run the suite inside the boundary',
    'scope:',
    '  - src/',
    'acceptance:',
    '  - npm test',
    'stop_condition: Stop and hand off after two failed attempts',
    'limits:',
    '  timeout_min: 60',
    '  trust_profile: execute-sandboxed',
    'image: docker.io/library/alpine:3.20'
)
$r = Invoke-Admit @('-Path', "`"$p`"")
Case 'C3' 'unpinned image rejected' ($r.Exit -eq 1 -and $r.Out -match 'pinned image') ("exit=" + $r.Exit)

# C4 bad job_id
$p = New-Contract 'badid' @(
    'job_id: bad id with spaces',
    'goal: Something that is never verified',
    'scope:',
    '  - src/',
    'acceptance:',
    '  - npm test',
    'stop_condition: Stop and hand off after two failed attempts',
    'limits:',
    '  timeout_min: 30',
    '  trust_profile: read-only'
)
$r = Invoke-Admit @('-Path', "`"$p`"")
Case 'C4' 'malformed job_id rejected' ($r.Exit -eq 1 -and $r.Out -match 'job_id must match') ("exit=" + $r.Exit)

# C5 JSON input
$json = @{
    job_id         = '20261028-json-input'
    goal           = 'Admit a contract produced by tooling'
    scope          = @('src/')
    acceptance     = @('powershell -File ./check.ps1')
    stop_condition = 'Stop and hand off after two failed attempts'
    limits         = @{ timeout_min = 45; trust_profile = 'read-only' }
} | ConvertTo-Json -Depth 5 -Compress
$jf = Join-Path $env:TEMP ('ees-contract-json-' + [guid]::NewGuid().ToString('N') + '.json')
Set-Content -LiteralPath $jf -Value $json -Encoding UTF8
$script = Join-Path $env:TEMP ('ees-admit-json-' + [guid]::NewGuid().ToString('N') + '.ps1')
$raw = (Get-Content -LiteralPath $jf -Raw).Replace("'", "''")
Set-Content -LiteralPath $script -Value ("& '$admit' -Json '$raw' -HubRoot '$tmpHub'`nexit `$LASTEXITCODE`n") -Encoding UTF8
$o = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script 2>&1 | ForEach-Object { $_.ToString() })
$code = $LASTEXITCODE
Remove-Item -LiteralPath $script, $jf -Force -ErrorAction SilentlyContinue
Case 'C5' 'JSON contract admitted' ($code -eq 0 -and ($o -join "`n") -match 'task ADMITTED') ("exit=$code")

Write-Output ''
$results | Format-Table -Property @('Id', 'Case', 'Result', 'Evidence') -AutoSize | Out-String -Width 160 | Write-Output
$failed = @($results | Where-Object Result -eq 'FAIL').Count
Write-Output ("admission self-test: " + ($results.Count - $failed) + "/" + $results.Count + " passed")
Remove-Item -LiteralPath $tmpHub -Recurse -Force -ErrorAction SilentlyContinue
exit $(if ($failed -gt 0) { 1 } else { 0 })
