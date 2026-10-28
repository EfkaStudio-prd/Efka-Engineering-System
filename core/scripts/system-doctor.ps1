<#
.SYNOPSIS
  Portable readiness doctor for the Efka Engineering System (any host, any agent).
.DESCRIPTION
  Read-only. Checks the toolchain, agent surfaces (Qoder/OpenCode/Claude/Codex),
  MCP configuration, git repositories, secret-file hygiene, and disk headroom.
  Exit code 0 = no FAIL, 1 = at least one FAIL.
.PARAMETER Repos
  Extra git repositories to check. Default: the hub folder itself plus any
  sibling folder that already contains a .git directory.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\system-doctor.ps1
  powershell -ExecutionPolicy Bypass -File .\system-doctor.ps1 -Repos 'C:\work\api','C:\work\web' -Json
#>
[CmdletBinding()]
param(
    [string[]]$Repos = @(),
    [string]$HubRoot = '',
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($HubRoot)) {
    $probe = $PSScriptRoot
    while ($probe -and -not (Test-Path -LiteralPath (Join-Path $probe 'manifest.json'))) {
        $parentDir = Split-Path $probe -Parent
        if ($parentDir -eq $probe) { break }
        $probe = $parentDir
    }
    $HubRoot = if ($probe) { $probe } else { (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
}
$results = New-Object System.Collections.ArrayList

function Add-Result([string]$Area, [string]$Item, [string]$Status, [string]$Detail) {
    [void]$results.Add([pscustomobject]@{ Area = $Area; Item = $Item; Status = $Status; Detail = $Detail })
}

function Resolve-Tool([string[]]$Candidates) {
    foreach ($c in $Candidates) {
        if (-not $c) { continue }
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

# ---------- toolchain ----------
$tools = [ordered]@{
    git    = @('git')
    node   = @('node')
    npm    = @('npm')
    python = @('python', 'python3')
    uv     = @('uv')
    pwsh   = @('pwsh', (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe'), (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'))
    jq     = @('jq') + @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Filter 'jq.exe' -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    gh     = @('gh')
    rg     = @('rg')
    podman = @('podman')
}
$required = @('git')
foreach ($name in $tools.Keys) {
    $found = Resolve-Tool $tools[$name]
    if ($found) { Add-Result 'toolchain' $name 'OK' $found }
    elseif ($required -contains $name) { Add-Result 'toolchain' $name 'FAIL' 'required but not found' }
    else { Add-Result 'toolchain' $name 'INFO' 'not installed on the Windows PATH (the executor probes WSL podman separately: gate section sandbox)' }
}

# ---------- agent surfaces ----------
$surfaces = [ordered]@{
    'qoder'    = @{ Path = (Join-Path $env:USERPROFILE '.qoder'); Skills = 'skills' }
    'opencode' = @{ Path = (Join-Path $env:USERPROFILE '.config\opencode'); Skills = 'skills' }
    'claude'   = @{ Path = (Join-Path $env:USERPROFILE '.claude'); Skills = 'skills' }
    'codex'    = @{ Path = (Join-Path $env:USERPROFILE '.codex'); Skills = 'skills' }
}
foreach ($name in $surfaces.Keys) {
    $s = $surfaces[$name]
    if (-not (Test-Path -LiteralPath $s.Path)) { Add-Result 'agent' $name 'INFO' 'not installed'; continue }
    $skillDir = Join-Path $s.Path $s.Skills
    $count = 0
    if (Test-Path -LiteralPath $skillDir) {
        $count = @(Get-ChildItem -LiteralPath $skillDir -Recurse -Filter 'SKILL.md' -ErrorAction SilentlyContinue).Count
    }
    Add-Result 'agent' $name 'OK' ("config present, {0} skill(s)" -f $count)
}

# ---------- MCP (Qoder user config, generic) ----------
$mcpFile = Join-Path $env:USERPROFILE '.qoder\mcp.json'
if (Test-Path -LiteralPath $mcpFile) {
    try {
        $servers = (Get-Content -LiteralPath $mcpFile -Raw | ConvertFrom-Json).mcpServers
        $names = @($servers.PSObject.Properties.Name)
        if ($names.Count -eq 0) { Add-Result 'mcp' 'servers' 'INFO' 'none configured' }
        foreach ($n in $names) {
            $cmd = $servers.$n.command
            if ($cmd -and -not (Test-Path -LiteralPath $cmd) -and -not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
                Add-Result 'mcp' $n 'FAIL' "command not found: $cmd"
            }
            else { Add-Result 'mcp' $n 'OK' ("type=" + $servers.$n.type) }
        }
    }
    catch { Add-Result 'mcp' 'mcp.json' 'FAIL' "parse error: $_" }
}
else { Add-Result 'mcp' 'mcp.json' 'INFO' 'no MCP config for this profile' }

# ---------- repositories ----------
$repoList = @($HubRoot)
if ($Repos.Count -gt 0) { $repoList += $Repos }
else {
    $parent = Split-Path $HubRoot -Parent
    $repoList += @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $HubRoot -and (Test-Path -LiteralPath (Join-Path $_.FullName '.git')) } |
            ForEach-Object { $_.FullName })
}
foreach ($repo in ($repoList | Select-Object -Unique)) {
    $leaf = Split-Path $repo -Leaf
    if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
        Add-Result 'repo' $leaf 'WARN' 'not a git repository (git init recommended)'
        continue
    }
    $probe = @(& git -C $repo rev-parse --is-inside-work-tree 2>$null)
    if ($probe.Count -eq 0) { Add-Result 'repo' $leaf 'WARN' 'git not usable in this context'; continue }
    $dirty = @(& git -C $repo status --porcelain 2>$null | Where-Object { $_ })
    $branch = (& git -C $repo rev-parse --abbrev-ref HEAD 2>$null)
    if (-not $branch) { $branch = 'HEAD' }
    $hp = (& git -C $repo config --get core.hooksPath 2>$null)
    $st = if ($dirty.Count -eq 0) { 'OK' } else { 'WARN' }
    Add-Result 'repo' $leaf $st ("{0}, {1} change(s), hooksPath={2}" -f $branch, $dirty.Count, $(if ($hp) { $hp } else { 'unset' }))
}

# ---------- secret files that must never be committed ----------
$secretNames = @('mcp-router.json', 'initial-password.env', '.env')
$leaks = @(Get-ChildItem -LiteralPath $HubRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $secretNames -contains $_.Name -and $_.FullName -notmatch '\\\.git\\' })
if ($leaks.Count -gt 0) {
    foreach ($l in $leaks) { Add-Result 'secrets' $l.Name 'FAIL' ('credential file inside the hub: ' + $l.FullName) }
}
else { Add-Result 'secrets' 'credential files' 'OK' 'none found inside the hub' }

# ---------- capacity ----------
$driveLetter = (Split-Path $HubRoot -Qualifier).TrimEnd(':')
$freeGB = 0
try {
    $d = Get-PSDrive -Name $driveLetter -ErrorAction Stop
    $freeGB = [math]::Round(($d.Free / 1GB), 1)
    $st = if ($freeGB -lt 20) { 'FAIL' } elseif ($freeGB -lt 60) { 'WARN' } else { 'OK' }
    Add-Result 'capacity' ($driveLetter + ': free') $st ("$freeGB GB free")
}
catch { Add-Result 'capacity' 'disk' 'INFO' 'could not read free space' }

Write-Output ''
if ($Json) { ConvertTo-Json -Input @($results) -Depth 4 | Write-Output }
else { $results | Format-Table -AutoSize Area, Item, Status, Detail | Out-String -Width 200 | Write-Output }

$counts = @($results) | Group-Object Status -AsHashTable
$fail = 0; $warn = 0; $ok = 0
if ($counts) {
    if ($counts.ContainsKey('FAIL')) { $fail = $counts['FAIL'].Count }
    if ($counts.ContainsKey('WARN')) { $warn = $counts['WARN'].Count }
    if ($counts.ContainsKey('OK')) { $ok = $counts['OK'].Count }
}
Write-Output ("doctor: OK={0} WARN={1} FAIL={2}" -f $ok, $warn, $fail)
exit $(if ($fail -gt 0) { 1 } else { 0 })
