<#
.SYNOPSIS
  One-click installer for the Efka Engineering System (Windows / PowerShell).
.DESCRIPTION
  Installs or updates the system into a target folder, wires the secret-guard git
  hook into the installed repository, copies the bundled agent skills into every
  detected agent surface (Qoder / OpenCode / Claude / Codex), and runs the doctor.
  Safe to re-run: existing adapters, logs, and host-specific files are preserved.
.EXAMPLE
  # from a clone
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  # one-liner (no clone)
  irm https://raw.githubusercontent.com/EfkaStudio-prd/Efka-Engineering-System/main/install.ps1 | iex
  # custom target, also install the OpenCode lane
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Target 'D:\Efka Engineering System' -Profile full
#>
[CmdletBinding()]
param(
    [string]$Target = (Join-Path $env:USERPROFILE 'Efka Engineering System'),
    [ValidateSet('core', 'full')][string]$Profile = 'core',
    [switch]$WithTasks,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoSlug = 'EfkaStudio-prd/Efka-Engineering-System'

function Write-Step([string]$Text) { Write-Host ("== " + $Text) -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host ("   " + $Text) -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host ("   " + $Text) -ForegroundColor Yellow }

# ---------- resolve source ----------
$source = $PSScriptRoot
if (-not $source -or -not (Test-Path -LiteralPath (Join-Path $source 'core'))) {
    Write-Step 'bootstrap: downloading the repository'
    $zip = Join-Path $env:TEMP ("efka-" + [guid]::NewGuid().ToString('N') + '.zip')
    $expand = Join-Path $env:TEMP ("efka-" + [guid]::NewGuid().ToString('N'))
    Invoke-WebRequest -Uri ("https://github.com/" + $repoSlug + "/archive/refs/heads/main.zip") -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $expand -Force
    $source = @(Get-ChildItem -LiteralPath $expand -Directory)[0].FullName
    Write-Ok ("source: " + $source)
}

Write-Step ("install target: " + $Target)
if ($DryRun) { Write-Warn 'DryRun: nothing will be written' }

$created = @()
function Ensure-Dir([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return }
    $created += $Path
    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
    Write-Ok ("created " + $Path)
}

# ---------- 1. core ----------
Ensure-Dir $Target
foreach ($sub in 'scripts', 'templates', 'tests', 'githooks', 'docs', 'adapters', 'logs') {
    Ensure-Dir (Join-Path $Target $sub)
}
foreach ($pair in @(
        @{ From = 'core\scripts'; To = 'scripts' },
        @{ From = 'core\templates'; To = 'templates' },
        @{ From = 'core\tests'; To = 'tests' },
        @{ From = 'core\githooks'; To = 'githooks' },
        @{ From = 'docs'; To = 'docs' }
    )) {
    $from = Join-Path $source $pair.From
    if (-not (Test-Path -LiteralPath $from)) { continue }
    $files = @(Get-ChildItem -LiteralPath $from -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($from.Length).TrimStart('\')
        $dest = Join-Path (Join-Path $Target $pair.To) $rel
        if ($DryRun) { continue }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }
    Write-Ok ("{0}: {1} file(s)" -f $pair.To, $files.Count)
}
foreach ($meta in 'manifest.json', 'README.md', 'VERSION') {
    $p = Join-Path $source $meta
    if ((Test-Path -LiteralPath $p) -and -not $DryRun) { Copy-Item -LiteralPath $p -Destination (Join-Path $Target $meta) -Force }
}

# ---------- 2. skills into every detected agent surface ----------
$skillSource = Join-Path $source 'skills'
if (Test-Path -LiteralPath $skillSource) {
    $surfaces = @(
        (Join-Path $env:USERPROFILE '.qoder\skills'),
        (Join-Path $env:USERPROFILE '.config\opencode\skills'),
        (Join-Path $env:USERPROFILE '.claude\skills'),
        (Join-Path $env:USERPROFILE '.codex\skills')
    )
    foreach ($surface in $surfaces) {
        $parent = Split-Path $surface -Parent
        if (-not (Test-Path -LiteralPath $parent)) { continue }
        Ensure-Dir $surface
        $skills = @(Get-ChildItem -LiteralPath $skillSource -Directory)
        foreach ($s in $skills) {
            $dest = Join-Path $surface $s.Name
            if ($DryRun) { continue }
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -Path (Join-Path $s.FullName '*') -Destination $dest -Recurse -Force
        }
        Write-Ok ("skills -> {0} ({1})" -f $surface, $skills.Count)
    }
}

# ---------- 3. git + secret guard ----------
$hooksDir = (Join-Path $Target 'githooks').Replace('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $Target '.git'))) {
    if (-not $DryRun) { & git -C $Target init -b main 2>&1 | Out-Null }
    Write-Ok 'git repository initialised (branch main)'
}
if (-not $DryRun) {
    & git -C $Target config core.hooksPath $hooksDir
    Write-Ok ("core.hooksPath -> " + $hooksDir)
}

# ---------- 4. optional: verified module lanes ----------
# Module-specific installers are deliberately not part of EES: modules are verified through
# adapters/<name>/verify.ps1 on the machine that owns them (see docs/MODULES.md).

# ---------- 5. optional: scheduled gate ----------
if ($WithTasks -and -not $DryRun) {
    $script = Join-Path $Target 'scripts\verify-all.ps1'
    $existing = Get-ScheduledTask -TaskName 'Efka System Doctor' -ErrorAction SilentlyContinue
    if ($existing) { Unregister-ScheduledTask -TaskName 'Efka System Doctor' -Confirm:$false }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script + '"')
    $trigger = New-ScheduledTaskTrigger -Daily -At '08:00'
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
    Register-ScheduledTask -TaskName 'Efka System Doctor' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Daily gate for the Efka Engineering System' | Out-Null
    Write-Ok 'scheduled task: Efka System Doctor (daily 08:00)'
}

# ---------- 6. report ----------
Write-Step 'running the doctor'
if ($DryRun) { Write-Warn 'skipped in DryRun' }
else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Target 'scripts\system-doctor.ps1')
    Write-Ok ("doctor exit: " + $LASTEXITCODE)
}

Write-Host ''
Write-Host 'Installed. Next steps:' -ForegroundColor Cyan
Write-Host ("  1. gate        : powershell -ExecutionPolicy Bypass -File `"" + (Join-Path $Target 'scripts\verify-all.ps1') + "`" -DeepSandbox")
Write-Host ("  2. new project : powershell -ExecutionPolicy Bypass -File `"" + (Join-Path $Target 'scripts\New-EfkaProject.ps1') + "`" -Path <dir> -Name <name>")
Write-Host ("  3. read first  : " + (Join-Path $Target 'docs\INSTALL.md'))
Write-Host '  4. execution   : pull a pinned image once (podman pull alpine:3.20), then scripts\sandbox-run.ps1 -Command <cmd> -WorkDir <dir>'
