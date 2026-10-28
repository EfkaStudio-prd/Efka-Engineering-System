<#
.SYNOPSIS
  Scaffold a new project that already satisfies the Efka Engineering System baseline.
.DESCRIPTION
  Creates a folder with README, AGENTS.md (from the hub template), .gitignore,
  .gitattributes, a per-project check.ps1 quality gate, an initial git commit and a
  baseline tag. Refuses to touch a non-empty folder unless -Force is given.
.USAGE
  .\New-EfkaProject.ps1 -Path 'C:\Projects\my-api' -Name 'My API' -Kind node
  .\New-EfkaProject.ps1 -Path 'C:\Projects\notes'  -Name 'Notes'  -Kind docs -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Name,
    [ValidateSet('generic', 'node', 'python', 'dotnet', 'docs')][string]$Kind = 'generic',
    [string]$HubRoot = '',
    [switch]$Force,
    [switch]$DryRun
)

Stop = 'Stop'
if ([string]::IsNullOrWhiteSpace($HubRoot)) { $HubRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$hubScan = Join-Path $HubRoot 'scripts\scan-secrets.ps1'

if ((Test-Path -LiteralPath $Path) -and -not $Force) {
    $existing = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0) {
        throw "$Path already exists and is not empty. Re-run with -Force only if you mean it."
    }
}

$gitignores = @{
    generic = @('# secrets & local config', '.env', '.env.*', '*.local', 'secrets/', '# editor/OS', '.vscode/', '.idea/', '.DS_Store', 'Thumbs.db', '# logs & temp', '*.log', 'tmp/', '.tmp/')
    node    = @('node_modules/', 'dist/', 'build/', 'coverage/', '.env', '.env.*', '*.log', '.cache/')
    python  = @('__pycache__/', '*.py[cod]', '.venv/', 'venv/', '.pytest_cache/', '.mypy_cache/', 'dist/', 'build/', '*.egg-info/', '.env', '.env.*')
    dotnet  = @('bin/', 'obj/', '*.user', 'TestResults/', '.vs/', '*.log')
    docs    = @('*.log', 'tmp/', '.env', '.env.*')
}

$readme = @"
# $Name

> Status: prototype · Dibuat: $(Get-Date -Format 'yyyy-MM-dd') · Kind: $Kind

## Tujuan

<isi satu paragraf: masalah yang diselesaikan dan untuk siapa>

## Mulai cepat

``````powershell
# verifikasi menyeluruh (harus lolos sebelum dianggap selesai)
powershell -ExecutionPolicy Bypass -File .\check.ps1
``````

## Struktur

| Path | Isi |
|---|---|
| ``AGENTS.md`` | aturan kerja untuk agen AI / manusia |
| ``check.ps1`` | gerbang kualitas proyek ini |
| ``docs/`` | dokumen desain & keputusan |

## Referensi sistem

- ``$HubRoot\README.md``
"@

$check = @"
<#
  Quality gate for: $Name
  Read-only checks first, then the project's own build/test commands.
  Exit code 0 = siap, 1 = ada yang harus dibereskan.
#>
[CmdletBinding()]
param()

`$ErrorActionPreference = 'Continue'
`$fail = 0

Write-Output '== secrets =='
& powershell -NoProfile -ExecutionPolicy Bypass -File '$hubScan' -Paths `$PSScriptRoot
if (`$LASTEXITCODE -ne 0) { `$fail++ }

Write-Output '== project checks =='
switch ('$Kind') {
    'node' {
        if (Test-Path 'package.json') {
            if (Test-Path 'node_modules') { & npm test --silent }
            else { Write-Output 'node_modules missing - run npm install first'; `$fail++ }
        }
    }
    'python' {
        if (Test-Path 'pyproject.toml') { & uv run pytest -q }
        elseif (Test-Path 'tests') { Write-Output 'tests/ present but no pyproject.toml - wire a runner' }
    }
    'dotnet' {
        if (Get-ChildItem -Filter '*.sln' -ErrorAction SilentlyContinue) { & dotnet test --nologo }
    }
    default { Write-Output "no build/test wired for kind '$Kind' yet" }
}

Write-Output ''
if (`$fail -gt 0) { Write-Output ('check.ps1: {0} problem(s)' -f `$fail); exit 1 }
Write-Output 'check.ps1: OK'
exit 0
"@

$files = [ordered]@{
    'README.md'      = $readme
    '.gitignore'     = ((@('# --- Efka Engineering System baseline ---') + $gitignores[$Kind]) -join "`n") + "`n"
    '.gitattributes' = "* text=auto`n*.sh text eol=lf`n*.ps1 text eol=crlf`n*.png binary`n*.rbz binary`n"
    'check.ps1'      = $check
}

$agentsTemplate = Join-Path $HubRoot 'templates\AGENTS.project.md'
if (Test-Path -LiteralPath $agentsTemplate) {
    $files['AGENTS.md'] = ([System.IO.File]::ReadAllText($agentsTemplate)) -replace '<nama proyek>', $Name
}
else {
    Write-Output "WARN: template AGENTS.project.md not found, skipping AGENTS.md"
}

foreach ($rel in $files.Keys) {
    Write-Output ("create  " + $rel)
}

if ($DryRun) {
    Write-Output 'DryRun: nothing written, no git commands run.'
    return
}

New-Item -ItemType Directory -Force -Path $Path | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Path 'docs') | Out-Null
foreach ($rel in $files.Keys) {
    [System.IO.File]::WriteAllText((Join-Path $Path $rel), $files[$rel], [System.Text.UTF8Encoding]::new($false))
}

& git -C $Path init -b main | Out-Null
& git -C $Path add -A
& git -C $Path commit -m "chore: scaffold $Name with the Efka Engineering System baseline" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "git commit failed in $Path (check git identity: git config --global user.name/user.email)" }
& git -C $Path tag baseline-$(Get-Date -Format 'yyyyMMdd')

Write-Output ''
Write-Output "Scaffolded $Name at $Path (kind=$Kind), committed, tagged baseline."
Write-Output "Next: fill AGENTS.md, wire check.ps1 build/test, then run .\check.ps1"
