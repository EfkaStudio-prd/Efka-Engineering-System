<#
.SYNOPSIS
  Opt-in installer for the Understand-Anything add-on (pinned, verifiable, reversible).
.DESCRIPTION
  EES adds a third category next to modules: add-ons. An add-on is third-party agent content
  (skills/plugins) that is useful for engineering work, is MIT-compatible, and can be installed
  only when a human asks for it. This wrapper never reimplements upstream logic: it clones the
  upstream repository at a pinned commit and creates junctions from the agent skill directories
  to the checkout, exactly what upstream's own installer does, plus a Qoder surface upstream
  does not map.

  Safety:
    - requires -Yes (consent); without it the script prints the plan and exits 2 (BLOCKED)
    - the checkout must resolve to the pinned commit, otherwise nothing is linked
    - only junctions are created; an existing real directory with the same name is never touched
    - state is recorded in <hub>\logs\integrations\understand-anything.json
.PARAMETER Yes
  Confirm the install. Without it, nothing is written.
.PARAMETER DryRun
  Print the plan (paths, commit, skills) and exit 0.
.PARAMETER Uninstall
  Remove the junctions EES created (checkout is kept; delete it manually if you want).
.PARAMETER Dir
  Checkout location (default %USERPROFILE%\.understand-anything\repo, same as upstream).
.PARAMETER Surface
  qoder (default) | agents | all - which skill directory receives the junctions.
.EXAMPLE
  .\install.ps1 -DryRun
  .\install.ps1 -Yes
  .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$Uninstall,
    [string]$Dir = '',
    [ValidateSet('qoder', 'agents', 'all')][string]$Surface = 'qoder',
    [string]$Tag = 'v2.9.0',
    [string]$Commit = 'f08763d11d0202a8a8f52b5dedda6d1b2e2ebac8'
)

$ErrorActionPreference = 'Stop'
# git writes progress to stderr; under 'Stop' that becomes a terminating error.
$script:nativeEap = $ErrorActionPreference
function Invoke-Native([scriptblock]$Block) {
    $ErrorActionPreference = 'Continue'
    try { & $Block } finally { $ErrorActionPreference = $script:nativeEap }
}
$RepoUrl = 'https://github.com/Egonex-AI/Understand-Anything.git'
$License = 'MIT'
$ExpectedSkills = @(
    'understand', 'understand-chat', 'understand-dashboard', 'understand-diff',
    'understand-explain', 'understand-figma', 'understand-knowledge', 'understand-onboard',
    'understand-domain'
)

function Find-Hub([string]$start) {
    $p = $start
    while ($p -and -not (Test-Path -LiteralPath (Join-Path $p 'manifest.json'))) {
        $parent = Split-Path $p -Parent
        if ($parent -eq $p) { return $null }
        $p = $parent
    }
    return $p
}
$HubRoot = Find-Hub $PSScriptRoot
if (-not $HubRoot) { $HubRoot = $PSScriptRoot }

if (-not $Dir) { $Dir = Join-Path $HOME '.understand-anything\repo' }
$skillsRoot = Join-Path $Dir 'understand-anything-plugin\skills'
$surfaces = switch ($Surface) {
    'qoder' { @(Join-Path $HOME '.qoder\skills') }
    'agents' { @(Join-Path $HOME '.agents\skills') }
    'all' { @((Join-Path $HOME '.qoder\skills'), (Join-Path $HOME '.agents\skills')) }
}

function Write-Step([string]$t) { Write-Output ('== ' + $t) }
function Write-Info([string]$t) { Write-Output ('   ' + $t) }

if ($Uninstall) {
    $removed = 0
    $pluginRoot = [string](Join-Path $Dir 'understand-anything-plugin')
    foreach ($surfacePath in $surfaces) {
        if (-not (Test-Path -LiteralPath $surfacePath)) { continue }
        foreach ($item in @(Get-ChildItem -LiteralPath $surfacePath -Force -ErrorAction SilentlyContinue)) {
            if ($item.LinkType -notin @('Junction', 'SymbolicLink')) { continue }
            $targetText = [string]($item.Target | Select-Object -First 1)
            if ($targetText -and $targetText.StartsWith($pluginRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $item.Delete()
                $removed++
                Write-Info ('removed ' + $item.FullName)
            }
        }
    }
    Write-Output ("uninstalled: $removed link(s) removed; checkout kept at $Dir")
    exit 0
}

$plan = [ordered]@{
    addon        = 'understand-anything'
    upstream     = $RepoUrl
    license      = $License
    commit       = $Commit
    tag          = $Tag
    checkout     = $Dir
    surfaces     = $surfaces
    skills       = $ExpectedSkills
    state_file   = (Join-Path $HubRoot 'logs\integrations\understand-anything.json')
}

if ($DryRun) {
    Write-Step 'DRY RUN - nothing will be written'
    $plan.GetEnumerator() | ForEach-Object {
        $v = if ($_.Value -is [array]) { $_.Value -join ', ' } else { $_.Value }
        Write-Info ($_.Key.PadRight(12) + ': ' + $v)
    }
    exit 0
}

if (-not $Yes) {
    Write-Output 'BLOCKED: this installs third-party agent skills; re-run with -Yes to confirm'
    Write-Output ('  upstream: ' + $RepoUrl + ' (' + $License + ') @ ' + $Commit)
    Write-Output ('  checkout: ' + $Dir)
    Write-Output ('  links   : ' + ($surfaces -join ', '))
    Write-Output '  inspect first with: .\install.ps1 -DryRun'
    exit 2
}

# ---------- checkout at the pinned commit ----------
if (-not (Test-Path -LiteralPath (Join-Path $Dir '.git'))) {
    Write-Step ('cloning ' + $RepoUrl)
    $parent = Split-Path $Dir -Parent
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Invoke-Native { & git clone --filter=blob:none --no-checkout $RepoUrl $Dir 2>&1 | ForEach-Object { Write-Info $_ } }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir '.git'))) { Write-Output 'FAILED: git clone'; exit 1 }
}
Write-Step ('checking out ' + $Tag + ' @ ' + $Commit)
Invoke-Native { & git -C $Dir fetch --depth 1 origin ("refs/tags/" + $Tag + ":refs/tags/" + $Tag) 2>&1 | ForEach-Object { Write-Info $_ } }
Invoke-Native { & git -C $Dir fetch --depth 1 origin $Commit 2>&1 | ForEach-Object { Write-Info $_ } }
Invoke-Native { & git -C $Dir checkout --detach $Commit 2>&1 | ForEach-Object { Write-Info $_ } }

$head = ''
Invoke-Native { $script:head = (& git -C $Dir rev-parse HEAD 2>$null) }
$head = if ($null -eq $head) { '' } else { ([string]$head).Trim() }
if ($head -ne $Commit) {
    Write-Output ("FAILED: HEAD is '$head', expected the pin $Commit - nothing was linked")
    exit 1
}
Write-Info ('HEAD = ' + $head)
$tagOk = $false
Invoke-Native { $script:tagHead = (& git -C $Dir rev-parse ("refs/tags/" + $Tag) 2>$null) }
if ($tagHead) { $tagOk = (([string]$tagHead).Trim() -eq $Commit) }
Write-Info ('tag ' + $Tag + ' -> ' + $(if ($tagOk) { 'matches the pin' } else { 'not verifiable locally (commit pin still enforced)' }))

# ---------- link skills ----------
$found = @(Get-ChildItem -LiteralPath $skillsRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')
    })
if ($found.Count -eq 0) { Write-Output ("FAILED: no skills with SKILL.md under " + $skillsRoot); exit 1 }

$linked = 0
$skipped = 0
foreach ($surfacePath in $surfaces) {
    if (-not (Test-Path -LiteralPath $surfacePath)) { New-Item -ItemType Directory -Force -Path $surfacePath | Out-Null }
    foreach ($skill in $found) {
        $link = Join-Path $surfacePath $skill.Name
        if (Test-Path -LiteralPath $link) {
            $item = Get-Item -LiteralPath $link -Force
            if ($item.LinkType -eq 'Junction' -or $item.LinkType -eq 'SymbolicLink') { $item.Delete() }
            else {
                Write-Info ('skip (real directory exists): ' + $link)
                $skipped++
                continue
            }
        }
        New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
        Write-Info ('link ' + $link + ' -> ' + $skill.FullName)
        $linked++
    }
}

# ---------- state ----------
$stateDir = Split-Path $plan.state_file -Parent
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$state = [ordered]@{
    addon         = 'understand-anything'
    status        = 'installed'
    installed_at  = (Get-Date).ToString('s')
    upstream      = $RepoUrl
    license       = $License
    version       = $Tag
    tag_verified  = $tagOk
    commit        = $head
    checkout      = $Dir
    skills_root   = $skillsRoot
    skills        = @($found | ForEach-Object { $_.Name })
    surfaces      = $surfaces
    links_created = $linked
    links_skipped = $skipped
    actor         = 'human/confirmed'
}
($state | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $plan.state_file -Encoding UTF8

Write-Step 'installed'
Write-Info ("skills linked: $linked (skipped: $skipped)")
Write-Info ('state: ' + $plan.state_file)
Write-Info 'Restart the IDE/CLI, then ask: "understand this repository" (skill: understand)'
exit 0
