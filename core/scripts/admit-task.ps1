<#
.SYNOPSIS
  Admission control for a task contract: no admitted contract, no work.
.DESCRIPTION
  Reads the machine-readable YAML front matter of a task contract and rejects it unless it
  carries what makes the work checkable: a testable goal, a bounded scope, at least one
  acceptance command, a stop condition, a time budget, a trust profile, and (for sandboxed
  work) a pinned image digest.
  On success it writes <hub>\logs\jobs\<job_id>\state.json with status=admitted, which later
  steps (execution, review) can reference.
  Exit 0 = admitted, 1 = rejected (problems listed), 2 = input unusable.
.PARAMETER Path
  Task contract markdown file with a `---` front matter block.
.PARAMETER Json
  JSON object with the same fields (for tooling that already builds contracts programmatically).
.EXAMPLE
  .\admit-task.ps1 -Path .\docs\tasks\20261028-add-login.md
#>
[CmdletBinding()]
param(
    [string]$Path = '',
    [string]$Json = '',
    [string]$HubRoot = ''
)

$ErrorActionPreference = 'Stop'
$problems = New-Object System.Collections.ArrayList
function Add-Problem([string]$m) { [void]$problems.Add($m) }

function Find-Hub([string]$start) {
    $p = $start
    while ($p -and -not (Test-Path -LiteralPath (Join-Path $p 'manifest.json'))) {
        $parent = Split-Path $p -Parent
        if ($parent -eq $p) { return $null }
        $p = $parent
    }
    return $p
}
if (-not $HubRoot) { $HubRoot = Find-Hub $PSScriptRoot }
if (-not $HubRoot) { $HubRoot = (Get-Location).Path }

# ---------- parse ----------
$spec = $null
if ($Json) {
    try { $spec = $Json | ConvertFrom-Json } catch { Write-Output ('REJECTED: input is not valid JSON - ' + $_.Exception.Message); exit 2 }
}
elseif ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) { Write-Output ('REJECTED: file not found: ' + $Path); exit 2 }
    $text = [System.IO.File]::ReadAllText($Path)
    # accept front matter at the top of the file, or inside a ```yaml fence (documentation style)
    if ($text -match '(?s)\A\s*---\s*\r?\n(.*?)\r?\n---') {
        $yaml = $Matches[1]
    }
    elseif ($text -match '(?s)```ya?ml\s*\r?\n---\s*\r?\n(.*?)\r?\n---') {
        $yaml = $Matches[1]
    }
    else {
        Write-Output 'REJECTED: no YAML front matter (--- ... ---) found in the task contract'
        exit 2
    }
    # Minimal front-matter parser (no YAML dependency): top-level `key: value`, or a block of
    # `- item` lines (list) / `key: value` lines (nested map). Comments start with ' #'.
    $blocks = [ordered]@{}
    $order = New-Object System.Collections.ArrayList
    $current = $null
    $stripComment = { param($s) ($s -replace '\s+#.*$', '').Trim() }
    foreach ($line in ($yaml -split "\r?\n")) {
        $trim = $line.Trim()
        if ($trim.Length -eq 0 -or $trim.StartsWith('#')) { continue }
        if ($line -match '^([A-Za-z_][\w\-]*)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $value = & $stripComment $Matches[2]
            $current = $key
            if ($value.Length -gt 0) { $blocks[$key] = $value }
            else { $blocks[$key] = New-Object System.Collections.ArrayList; [void]$order.Add($key) }
        }
        elseif ($null -ne $current -and $blocks[$current] -is [System.Collections.ArrayList]) {
            [void]$blocks[$current].Add($line)
        }
    }
    $obj = [ordered]@{}
    foreach ($key in $blocks.Keys) {
        $v = $blocks[$key]
        if ($v -isnot [System.Collections.ArrayList]) { $obj[$key] = $v; continue }
        $items = @($v | Where-Object { $_.Trim().Length -gt 0 })
        if ($items.Count -eq 0) { $obj[$key] = @(); continue }
        $isList = -not ($items | Where-Object { $_ -notmatch '^\s*-\s+' })
        if ($isList) {
            $obj[$key] = @($items | ForEach-Object { (& $stripComment ($_ -replace '^\s*-\s+', '')).Trim('"', "'") })
        }
        else {
            $map = [ordered]@{}
            foreach ($item in $items) {
                if ($item -match '^\s*([A-Za-z_][\w\-]*)\s*:\s*(.*)$') {
                    $map[$Matches[1]] = & $stripComment $Matches[2]
                }
            }
            $obj[$key] = $map
        }
    }
    $spec = [pscustomobject]$obj
}
else { Write-Output 'REJECTED: provide -Path or -Json'; exit 2 }

function Value([object]$o, [string]$name) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Collections.IDictionary]) {
        if ($o.Contains($name)) { return $o[$name] }
        return $null
    }
    $p = $o.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

# ---------- rules ----------
$jobId = [string](Value $spec 'job_id')
if (-not $jobId) { Add-Problem 'job_id is required (used as the job folder name)' }
elseif ($jobId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$') { Add-Problem "job_id must match [A-Za-z0-9._-]{3,64}, got '$jobId'" }

$goal = [string](Value $spec 'goal')
if ($goal.Trim().Length -lt 10) { Add-Problem 'goal must be one testable sentence of at least 10 characters' }

$scope = @(Value $spec 'scope' | Where-Object { $_ })
if ($scope.Count -eq 0) { Add-Problem 'scope must list at least one path or area (unbounded work is not admittable)' }

$acceptance = @(Value $spec 'acceptance' | Where-Object { $_ })
if ($acceptance.Count -eq 0) { Add-Problem 'acceptance must list at least one command that proves the goal' }
foreach ($a in $acceptance) { if (([string]$a).Trim().Length -lt 5) { Add-Problem "acceptance entry too short: '$a'" } }

$stop = [string](Value $spec 'stop_condition')
if ($stop.Trim().Length -lt 10) { Add-Problem 'stop_condition is required: what makes the agent stop and hand off' }

$limits = Value $spec 'limits'
$timeoutMin = $null
$trust = ''
if ($null -eq $limits) { Add-Problem 'limits block is required (timeout_min, trust_profile)' }
else {
    $t = Value $limits 'timeout_min'
    if ($null -eq $t -or -not ($t -as [int])) { Add-Problem 'limits.timeout_min must be an integer (1..480)' }
    else {
        $timeoutMin = [int]$t
        if ($timeoutMin -lt 1 -or $timeoutMin -gt 480) { Add-Problem "limits.timeout_min out of range 1..480: $timeoutMin" }
    }
    $trust = [string](Value $limits 'trust_profile')
    if ($trust -notin @('read-only', 'write-scoped', 'execute-sandboxed')) {
        Add-Problem "limits.trust_profile must be read-only|write-scoped|execute-sandboxed, got '$trust'"
    }
}

$image = [string](Value $spec 'image')
if ($trust -eq 'execute-sandboxed' -and $image -notmatch '@sha256:[0-9a-f]{64}$') {
    Add-Problem 'execute-sandboxed requires a pinned image (image@sha256:<64 hex>)'
}

Write-Output ''
if ($problems.Count -gt 0) {
    Write-Output ('task REJECTED: ' + $problems.Count + ' problem(s)')
    $problems | ForEach-Object { Write-Output ('  - ' + $_) }
    Write-Output ''
    Write-Output 'No job was created. Fix the contract and run again: work does not start without admission.'
    exit 1
}

$jobDir = Join-Path (Join-Path $HubRoot 'logs\jobs') $jobId
New-Item -ItemType Directory -Force -Path $jobDir | Out-Null
$state = [ordered]@{
    job_id         = $jobId
    status         = 'admitted'
    admitted_at    = (Get-Date).ToString('s')
    goal           = $goal
    scope          = $scope
    acceptance     = $acceptance
    stop_condition = $stop
    limits         = [ordered]@{ timeout_min = $timeoutMin; trust_profile = $trust }
    image          = $(if ($image) { $image } else { $null })
    contract_file  = $(if ($Path) { (Resolve-Path -LiteralPath $Path).Path } else { $null })
    actor          = 'agent/qoder'
}
$statePath = Join-Path $jobDir 'state.json'
($state | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $statePath -Encoding UTF8
Write-Output ("task ADMITTED: job_id=$jobId trust=$trust timeout=${timeoutMin}m acceptance=$($acceptance.Count) scope=$($scope.Count)")
Write-Output ("state: " + $statePath)
exit 0
