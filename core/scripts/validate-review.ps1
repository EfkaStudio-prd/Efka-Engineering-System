<#
.SYNOPSIS
  Validates a review report against the EES review contract.
.DESCRIPTION
  Rule-based validation (no external JSON-Schema engine): checks the fields that
  actually gate a merge - verdict, evidence per finding, observed tests, and the
  independence flag. The JSON Schema in templates/review-output.schema.json is the
  machine-readable twin of these rules for other tools.
  Exit 0 = contract satisfied, 1 = violations listed.
.EXAMPLE
  .\validate-review.ps1 -Path .\review.json
  Get-Content review.json -Raw | .\validate-review.ps1
#>
[CmdletBinding()]
param(
    [string]$Path = '',
    [string]$Json = ''
)

$ErrorActionPreference = 'Stop'
$problems = New-Object System.Collections.ArrayList
function Add-Problem([string]$Message) { [void]$problems.Add($Message) }

$raw = if ($Path) { [System.IO.File]::ReadAllText($Path) } else { $Json }
if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Provide -Path or pipe JSON into -Json.' }

try { $r = $raw | ConvertFrom-Json }
catch { Write-Output ('INVALID: not valid JSON - ' + $_.Exception.Message); exit 1 }

# --- top level ---
foreach ($field in 'verdict', 'findings', 'tests_observed', 'independent') {
    if ($null -eq $r.PSObject.Properties[$field]) { Add-Problem ("missing required field: " + $field) }
}
if ($r.verdict -and $r.verdict -notin @('approve', 'request_changes', 'blocked')) {
    Add-Problem ("verdict must be approve|request_changes|blocked, got '" + $r.verdict + "'")
}
if ($r.PSObject.Properties['independent'] -and $r.independent -isnot [bool]) {
    Add-Problem 'independent must be boolean'
}

# --- findings ---
$findings = @($r.findings)
foreach ($f in $findings) {
    if ($f.severity -notin @('critical', 'high', 'medium', 'low', 'nit')) {
        Add-Problem ("finding severity invalid: '" + $f.severity + "'")
    }
    if (-not $f.title -or ([string]$f.title).Trim().Length -lt 8) {
        Add-Problem 'finding.title must be >= 8 characters'
    }
    if (-not $f.evidence -or ([string]$f.evidence).Trim().Length -lt 8) {
        Add-Problem ("finding '" + $f.title + "' has no usable evidence (opinion is not a finding)")
    }
}

# --- tests observed ---
$tests = @($r.tests_observed)
foreach ($t in $tests) {
    if (-not $t.command) { Add-Problem 'tests_observed entry missing command' }
    if ($t.result -notin @('pass', 'fail', 'not_run')) {
        Add-Problem ("tests_observed.result invalid: '" + $t.result + "'")
    }
    # A claimed run may point at a sandbox receipt: then the receipt must exist and agree.
    if ($t.receipt) {
        $receiptPath = [string]$t.receipt
        if (-not (Test-Path -LiteralPath $receiptPath)) {
            Add-Problem ("receipt not found: " + $receiptPath)
        }
        else {
            try {
                $rc = [System.IO.File]::ReadAllText($receiptPath) | ConvertFrom-Json
                if ($null -ne $t.exit_code -and $null -ne $rc.exit_code -and [int]$t.exit_code -ne [int]$rc.exit_code) {
                    Add-Problem ("receipt exit_code mismatch for '" + $t.command + "' (claimed " + $t.exit_code + ', receipt ' + $rc.exit_code + ')')
                }
                if ($t.result -eq 'pass' -and $rc.verdict -and $rc.verdict -ne 'pass') {
                    Add-Problem ("receipt verdict is '" + $rc.verdict + "' but the test is claimed as pass: " + $receiptPath)
                }
                if (-not $rc.image) { Add-Problem ("receipt has no image pin: " + $receiptPath) }
            }
            catch { Add-Problem ("receipt is not valid JSON: " + $receiptPath) }
        }
    }
}

# --- verdict-specific gates ---
switch ($r.verdict) {
    'approve' {
        $passed = @($tests | Where-Object { $_.result -eq 'pass' -and $null -ne $_.exit_code -and [int]$_.exit_code -eq 0 })
        if ($passed.Count -eq 0) {
            Add-Problem 'approve requires at least one tests_observed entry with result=pass and exit_code=0'
        }
        $blocking = @($findings | Where-Object { $_.severity -in @('critical', 'high') })
        if ($blocking.Count -gt 0) {
            Add-Problem ('approve is inconsistent with ' + $blocking.Count + ' critical/high finding(s)')
        }
    }
    'blocked' {
        if (-not $r.residual_risk) { Add-Problem 'blocked requires residual_risk explaining the blocker' }
    }
    'request_changes' {
        if ($findings.Count -eq 0) { Add-Problem 'request_changes requires at least one finding' }
    }
}

Write-Output ''
if ($problems.Count -eq 0) {
    Write-Output ('review OK: verdict=' + $r.verdict + ' findings=' + $findings.Count + ' tests=' + $tests.Count + ' independent=' + $r.independent)
    exit 0
}
Write-Output ('review INVALID: ' + $problems.Count + ' problem(s)')
$problems | ForEach-Object { Write-Output ('  - ' + $_) }
exit 1
