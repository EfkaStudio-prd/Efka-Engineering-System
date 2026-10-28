<#
.SYNOPSIS
  Read-only verification of the Understand-Anything add-on.
.DESCRIPTION
  Reports three things the gate cares about:
    1. is the checkout present, and is it exactly the pinned commit (no drift)?
    2. do the expected skills exist in the checkout?
    3. are the agent surfaces actually linked to this checkout?
  Not installed is not a failure: an add-on is optional, so the section reports OK with
  "not installed". Drift or a half-installed state is a failure.
  Exit 0 = fine (installed and consistent, or absent), 1 = installed but inconsistent.
#>
[CmdletBinding()]
param(
    [string]$Dir = '',
    [string]$Tag = 'v2.9.0',
    [string]$Commit = 'f08763d11d0202a8a8f52b5dedda6d1b2e2ebac8'
)

$ErrorActionPreference = 'Continue'
if (-not $Dir) { $Dir = Join-Path $HOME '.understand-anything\repo' }
$skillsRoot = Join-Path $Dir 'understand-anything-plugin\skills'
$surfaces = @((Join-Path $HOME '.qoder\skills'), (Join-Path $HOME '.agents\skills'))
$expected = @(
    'understand', 'understand-chat', 'understand-dashboard', 'understand-diff',
    'understand-explain', 'understand-figma', 'understand-knowledge', 'understand-onboard',
    'understand-domain'
)

if (-not (Test-Path -LiteralPath (Join-Path $Dir '.git'))) {
    Write-Output 'understand-anything: not installed (optional add-on; integrations/understand-anything/install.ps1 -Yes)'
    exit 0
}

$problems = New-Object System.Collections.ArrayList
function Add-Problem([string]$m) { [void]$problems.Add($m) }

$head = (& git -C $Dir rev-parse HEAD 2>$null)
$head = if ($null -eq $head) { '' } else { ([string]$head).Trim() }
if ($head -ne $Commit) {
    Add-Problem ("checkout is at $head, pin is $Commit - run install.ps1 -Yes to re-pin")
}

$missing = @($expected | Where-Object { -not (Test-Path -LiteralPath (Join-Path (Join-Path $skillsRoot $_) 'SKILL.md')) })
if ($missing.Count -gt 0) { Add-Problem ('skills missing from the checkout: ' + ($missing -join ', ')) }

$linked = 0
$checkedSurfaces = 0
foreach ($surface in $surfaces) {
    if (-not (Test-Path -LiteralPath $surface)) { continue }
    $checkedSurfaces++
    foreach ($name in $expected) {
        $link = Join-Path $surface $name
        if (-not (Test-Path -LiteralPath $link)) { continue }
        $item = Get-Item -LiteralPath $link -Force
        if ($item.LinkType -eq 'Junction' -or $item.LinkType -eq 'SymbolicLink') { $linked++ }
    }
}
if ($checkedSurfaces -eq 0) { Add-Problem 'no agent skill directory exists (~/.qoder/skills or ~/.agents/skills)' }
elseif ($linked -eq 0) { Add-Problem 'checkout exists but no skill is linked into an agent surface' }

$node = $null
try { $node = (& node --version 2>$null) } catch { }
$nodeText = if ($node) { 'node ' + ([string]$node).Trim() } else { 'node not on PATH (needed when the skills actually run)' }

if ($problems.Count -gt 0) {
    Write-Output ('understand-anything: FAIL ' + ($problems -join ' | '))
    exit 1
}

Write-Output ("understand-anything: OK " + $Tag + " pinned=" + $head.Substring(0, 12) + " skills=" + $expected.Count + " links=" + $linked + " " + $nodeText)
exit 0
