<#
.SYNOPSIS
  Self-test of the EES execution boundary (sandbox-run.ps1).
.DESCRIPTION
  Proves the boundary with observable evidence, not with configuration reading:
    T1 command runs and returns 0
    T2 network is blocked
    T3 root filesystem is read-only
    T4 /tmp is writable (tmpfs)
    T5 the workspace mount is read-only by default
    T6 wall-clock timeout kills the command (verdict=timeout)
    T7 memory limit is actually enforced (cgroup value inside the container)
    T8 unknown image fails closed (BLOCKED, exit 2)
    T9 host environment is not leaked into the container
    T10 every run leaves a well-formed evidence receipt (digest + output hash)
  Exit 0 only when every case passes.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\tests\sandbox-selftest.ps1
#>
[CmdletBinding()]
param(
    [string]$Image = 'docker.io/library/alpine@sha256:c64c687cbea9300178b30c95835354e34c4e4febc4badfe27102879de0483b5e',
    [string]$WorkDir = ''
)

$ErrorActionPreference = 'Continue'
$runner = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\sandbox-run.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw "sandbox-run.ps1 not found at $runner" }
if (-not $WorkDir) { $WorkDir = Split-Path $PSScriptRoot -Parent }

$results = New-Object System.Collections.ArrayList
function Case([string]$Id, [string]$Name, [bool]$Pass, [string]$Evidence) {
    [void]$results.Add([pscustomobject]@{ Id = $Id; Case = $Name; Result = $(if ($Pass) { 'PASS' } else { 'FAIL' }); Evidence = $Evidence })
}

# Native argv mangles quotes/semicolons, so each case gets a tiny wrapper script
# with the command in a literal here-string. That keeps the test honest: what the
# runner receives is exactly the text below.
function Invoke-Sandbox([string]$Command, [hashtable]$Extra = @{}) {
    $bound = @{ Command = $Command; WorkDir = $WorkDir; Image = $Image }
    foreach ($k in $Extra.Keys) { $bound[$k] = $Extra[$k] }
    $extraLines = ($bound.Keys | Where-Object { $_ -notin @('Command', 'WorkDir', 'Image') } |
        ForEach-Object { ' -' + $_ + ' ' + $bound[$_] }) -join ''
    $img = $bound['Image']
    $wrapper = @"
`$cmd = @'
$Command
'@
& '$runner' -Command `$cmd -WorkDir '$WorkDir' -Image '$img'$extraLines
exit `$LASTEXITCODE
"@
    $wf = Join-Path $env:TEMP ('ees-case-' + [guid]::NewGuid().ToString('N') + '.ps1')
    Set-Content -LiteralPath $wf -Value $wrapper -Encoding UTF8
    $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $wf 2>&1 | ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
    Remove-Item -LiteralPath $wf -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Exit = $code; Out = ($out -join "`n") }
}

Write-Output '== EES sandbox self-test =='
Write-Output ("runner : " + $runner)
Write-Output ("image  : " + $Image)
Write-Output ("workdir: " + $WorkDir)
Write-Output ''

# T1 basic execution (keep test commands free of double quotes: native argv loses them)
$r = Invoke-Sandbox 'echo ees-ok; id -u'
Case 'T1' 'command runs' ($r.Exit -eq 0 -and $r.Out -match 'ees-ok') ("exit=" + $r.Exit + " last=" + (($r.Out -split "`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1))

# T2 network blocked: the command exits 9 if it can reach the internet
$r = Invoke-Sandbox 'wget -q -T 3 -O- https://example.com >/dev/null 2>&1 && exit 9 || exit 0'
Case 'T2' 'network blocked' ($r.Exit -eq 0) ("exit=" + $r.Exit + " (9 = network reachable)")

# T3 read-only rootfs: touch /x succeeds => 9
$r = Invoke-Sandbox 'touch /x 2>/dev/null && exit 9 || exit 0'
Case 'T3' 'rootfs read-only' ($r.Exit -eq 0) ("exit=" + $r.Exit)

# T4 tmpfs writable
$r = Invoke-Sandbox 'touch /tmp/probe && echo tmp-ok'
Case 'T4' 'tmpfs writable' ($r.Exit -eq 0 -and $r.Out -match 'tmp-ok') ("exit=" + $r.Exit)

# T5 workspace mount read-only by default
$r = Invoke-Sandbox 'touch /work/.ees-probe 2>/dev/null && exit 9 || exit 0'
Case 'T5' 'workspace read-only' ($r.Exit -eq 0) ("exit=" + $r.Exit)

# T6 timeout
$r = Invoke-Sandbox 'sleep 30' @{ TimeoutSec = 3 }
Case 'T6' 'timeout enforced' ($r.Exit -eq 1 -and $r.Out -match 'verdict=timeout') ("exit=" + $r.Exit + " head=" + (($r.Out -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)))

# T7 memory limit enforced: cgroup v2 value must equal the requested limit (64 MiB)
$r = Invoke-Sandbox 'grep -c 67108864 /sys/fs/cgroup/memory.max' @{ MemoryMB = 64 }
$valueOk = $r.Exit -eq 0 -and $r.Out -match '(?m)^1\s*$'
Case 'T7' 'memory limit enforced' $valueOk ("expected 67108864 in /sys/fs/cgroup/memory.max; exit=" + $r.Exit + " out=" + (($r.Out -split "`n" | Where-Object { $_.Trim() }) -join '|'))

# T8 fail closed on unknown image
$r = Invoke-Sandbox 'echo x' @{ Image = 'docker.io/library/alpine@sha256:0000000000000000000000000000000000000000000000000000000000000000' }
Case 'T8' 'unknown image blocks' ($r.Exit -eq 2 -and $r.Out -match 'BLOCKED') ("exit=" + $r.Exit)

# T9 host env not leaked
$env:EES_SENTINEL = 'should-not-appear'
$r = Invoke-Sandbox 'env | grep -c ^EES_SENTINEL= || true'
Remove-Item Env:EES_SENTINEL -ErrorAction SilentlyContinue
$count = 0
if ($r.Out -match '(?m)^\s*(\d+)\s*$') { $count = [int]$Matches[1] }
Case 'T9' 'host env not leaked' ($count -eq 0 -and $r.Exit -eq 0) ("occurrences=" + $count + " exit=" + $r.Exit)

# T10 the run left a well-formed receipt (the evidence loop closes here)
$receiptLine = ($r.Out -split "`n" | Where-Object { $_ -match '^receipt: ' } | Select-Object -Last 1)
$receiptPath = if ($receiptLine) { $receiptLine -replace '^receipt: ', '' } else { '' }
$receiptOk = $false
$receiptWhy = 'no receipt path in output'
if ($receiptPath -and (Test-Path -LiteralPath $receiptPath)) {
    try {
        $rc = [System.IO.File]::ReadAllText($receiptPath) | ConvertFrom-Json
        $need = @('receipt_id', 'timestamp', 'tool', 'image', 'exit_code', 'duration_ms', 'output', 'verdict')
        $missing = @($need | Where-Object { $null -eq $rc.PSObject.Properties[$_] })
        $receiptOk = $missing.Count -eq 0 -and $rc.image -match '@sha256:' -and $rc.output.sha256 -match '^[0-9a-f]{64}$' -and [int]$rc.exit_code -eq $r.Exit
        $receiptWhy = if ($receiptOk) { 'fields + digest + output hash present' } else { 'missing=' + ($missing -join ',') + ' image=' + $rc.image }
    }
    catch { $receiptWhy = 'receipt is not valid JSON' }
}
else { $receiptWhy = 'receipt file missing: ' + $receiptPath }
Case 'T10' 'receipt written' $receiptOk $receiptWhy

Write-Output ''
$results | Format-Table -Property @('Id', 'Case', 'Result', 'Evidence') -AutoSize | Out-String -Width 160 | Write-Output
$failed = @($results | Where-Object Result -eq 'FAIL').Count
Write-Output ("sandbox self-test: " + ($results.Count - $failed) + "/" + $results.Count + " passed")
exit $(if ($failed -gt 0) { 1 } else { 0 })
