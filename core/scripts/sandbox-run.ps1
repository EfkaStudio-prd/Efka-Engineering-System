<#
.SYNOPSIS
  Runs one command inside a pinned, unprivileged container (the EES execution boundary).
.DESCRIPTION
  Fail-closed by design:
    - refuses to run when podman, the image, or the requested limits are unavailable
      (exit 2 = BLOCKED) instead of falling back to the host shell;
    - no network unless -AllowNetwork;
    - read-only root filesystem, tmpfs /tmp, no capabilities, no-new-privileges;
    - only -WorkDir is mounted (read-only unless -WorkWrite);
    - memory / cpu / pid limits + wall-clock timeout.
  Every run writes an evidence receipt to <hub>\logs\sandbox\<timestamp>.json.
.PARAMETER Command
  Shell command executed as `sh -lc <Command>` inside the container.
.PARAMETER WorkDir
  Directory to expose at /work. Windows paths are translated to /mnt/<drive>/...
.PARAMETER WorkWrite
  Mount /work read-write (default read-only).
.EXAMPLE
  .\sandbox-run.ps1 -Command 'uname -a; ls /work'
  .\sandbox-run.ps1 -Command 'npm test' -WorkDir 'C:\Projects\api' -WorkWrite -TimeoutSec 300
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Command,
    [string]$WorkDir = '',
    [string]$Image = 'docker.io/library/alpine@sha256:c64c687cbea9300178b30c95835354e34c4e4febc4badfe27102879de0483b5e',
    [string]$Distro = 'Ubuntu-24.04',
    [int]$TimeoutSec = 60,
    [int]$MemoryMB = 512,
    [double]$Cpus = 1.0,
    [int]$PidsLimit = 128,
    [int]$MaxOutputKB = 64,
    [switch]$AllowNetwork,
    [switch]$WorkWrite,
    [switch]$AllowUnenforcedLimits,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# Native stderr redirected into the pipeline becomes a terminating error under
# 'Stop'; native calls below rely on exit codes instead.
$nativeEap = $ErrorActionPreference
function Invoke-NativeSafely([scriptblock]$Block) {
    $ErrorActionPreference = 'Continue'
    try { & $Block } finally { $ErrorActionPreference = $nativeEap }
}

function Blocked([string]$Why) {
    Write-Output ('BLOCKED: ' + $Why)
    exit 2
}

function Convert-ToWslPath([string]$WinPath) {
    if ($WinPath -match '^[A-Za-z]:\\') {
        return '/mnt/' + $WinPath.Substring(0, 1).ToLowerInvariant() + ($WinPath.Substring(2).Replace('\', '/'))
    }
    return ($WinPath -replace '\\', '/')
}

function New-TempName([string]$suffix) { [guid]::NewGuid().ToString('N') + $suffix }

$hub = $PSScriptRoot
while ($hub -and -not (Test-Path -LiteralPath (Join-Path $hub 'manifest.json'))) {
    $parent = Split-Path $hub -Parent
    if ($parent -eq $hub) { break }
    $hub = $parent
}
if (-not $hub) { $hub = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }

# ---------- preflight (fail closed) ----------
& wsl.exe -d $Distro -- true 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Blocked "WSL distro '$Distro' not available" }

$work = if ($WorkDir) { (Resolve-Path -LiteralPath $WorkDir).Path } else { (Get-Location).Path }
if (-not (Test-Path -LiteralPath $work)) { Blocked "WorkDir does not exist: $work" }
$unixWork = Convert-ToWslPath $work
$mountMode = if ($WorkWrite) { 'rw' } else { 'ro' }

$tmpSh = Join-Path $env:TEMP (New-TempName '.sh')
$tmpLog = Join-Path $env:TEMP (New-TempName '.log')
$unixSh = Convert-ToWslPath $tmpSh
$unixLog = Convert-ToWslPath $tmpLog

$netArg = if ($AllowNetwork) { '--network=host' } else { '--network=none' }

# Image pinning check: existence alone is not enough (podman matches by name),
# the pinned digest must appear in RepoDigests. Run it as a script file so that
# wsl.exe argv handling cannot strip quotes from --format.
$digestPart = if ($Image -match '@(sha256:[0-9a-f]{64})$') { $Matches[1] } else { '' }
$tmpPre = Join-Path $env:TEMP (New-TempName '.pre.sh')
$preScript = @'
#!/usr/bin/env bash
set -uo pipefail
img="$1"; digest="$2"
podman image exists "$img" >/dev/null 2>&1 || { echo "no:image-missing"; exit 0; }
if [ -n "$digest" ]; then
  podman image inspect --format '{{.RepoDigests}}' "$img" 2>/dev/null | grep -q "$digest" || { echo "no:digest-mismatch"; exit 0; }
fi
echo yes
'@
[System.IO.File]::WriteAllText($tmpPre, ($preScript -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
$unixPre = Convert-ToWslPath $tmpPre
$preOut = (Invoke-NativeSafely { ((& wsl.exe -d $Distro -- bash $unixPre $Image $digestPart 2>&1) | ForEach-Object { $_.ToString() }) -join "`n" })
if ($null -eq $preOut) { $preOut = '' }
$preOut = $preOut.Trim()
Remove-Item -LiteralPath $tmpPre -Force -ErrorAction SilentlyContinue
if ($preOut -notmatch '^yes') {
    Blocked ("image not usable: $Image [$preOut] (pull the pinned image explicitly, EES does not download images)")
}

# ---------- build the shell script (single command line: no bash line continuations) ----------
$sq = "'"
$cmdQuoted = $sq + ($Command -replace "'", "'\''") + $sq
$podmanCall = @(
    'timeout -k 2 ' + $TimeoutSec,
    'podman run --rm --name "$ees_name"',
    $netArg,
    '--read-only --tmpfs /tmp:rw,size=64m',
    ('--volume ' + $sq + $unixWork + ':/work:' + $mountMode + $sq),
    '--workdir /work',
    '--userns=keep-id',
    '--cap-drop ALL --security-opt no-new-privileges',
    ('--memory ' + $MemoryMB + 'm --cpus ' + $Cpus + ' --pids-limit ' + $PidsLimit),
    '--env HOME=/tmp',
    ($sq + $Image + $sq),
    'sh -lc ' + $cmdQuoted + ' 2>&1'
) -join ' '
$lines = @(
    '#!/usr/bin/env bash',
    'set -uo pipefail',
    'ees_name="ees-$$-${RANDOM}"',
    't0=$(date +%s)',
    $podmanCall,
    'rc=$?',
    'podman rm -f "$ees_name" >/dev/null 2>&1 || true',
    't1=$(date +%s)',
    ('if [ "$rc" -ne 0 ] && [ $((t1-t0)) -ge ' + $TimeoutSec + ' ]; then echo "__EES_TIMEOUT__"; fi'),
    'echo "__EES_RC__${rc}"',
    'exit $rc'
) -join "`n"

if ($DryRun) {
    Write-Output 'DRY RUN - container command:'
    Write-Output $podmanCall
    Write-Output ("workdir=$work ($mountMode) image=$Image network=" + $(if ($AllowNetwork) { 'host' } else { 'none' }))
    exit 0
}

[System.IO.File]::WriteAllText($tmpSh, ($lines -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
$started = Get-Date
$runOut = Invoke-NativeSafely { @(& wsl.exe -d $Distro -- bash -c "bash '$unixSh' > '$unixLog' 2>&1" 2>&1 | ForEach-Object { $_.ToString() }) }
$exit = $LASTEXITCODE
$durationMs = [int]((Get-Date) - $started).TotalMilliseconds

$raw = ''
if (Test-Path -LiteralPath $tmpLog) {
    $raw = [System.IO.File]::ReadAllText($tmpLog)
    Remove-Item -LiteralPath $tmpLog -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $tmpSh -Force -ErrorAction SilentlyContinue

$reported = $exit
if ($raw -match '__EES_RC__(\d+)') { $reported = [int]$Matches[1] }
# a run killed by the wall clock is a timeout, whatever signal podman reported
$timedOut = $raw -match '__EES_TIMEOUT__'
if ($timedOut) { $reported = 124 }
# the markers are transport only - never show them as command output
$raw = ($raw -split "`n" | Where-Object { $_ -notmatch '^__(EES_RC__\d+|EES_TIMEOUT__)$' }) -join "`n"

# ---------- limit enforcement (fail closed) ----------
$limitUnenforced = $false
if ($raw -match '(?i)(memory limit|pids limit|cpu limit|unable to apply|cgroups).*(not supported|unsupported|ignored|permission denied)') {
    $limitUnenforced = $true
}
if ($limitUnenforced -and -not $AllowUnenforcedLimits) {
    Write-Output 'BLOCKED: hardware limits could not be enforced in this environment'
    Write-Output ('  ' + (($raw -split "`n" | Select-Object -First 3) -join ' | '))
    Write-Output '  re-run with -AllowUnenforcedLimits only if you accept unenforced limits'
    $reported = 2
}

# ---------- receipt ----------
$outBytes = [System.Text.Encoding]::UTF8.GetByteCount($raw)
$sha = [System.Security.Cryptography.SHA256]::Create()
$outHash = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($raw)) | ForEach-Object { $_.ToString('x2') })
$excerptLines = @($raw -split "`n" | Select-Object -First 40)
$excerpt = ($excerptLines -join "`n")
if ($excerpt.Length -gt 4096) { $excerpt = $excerpt.Substring(0, 4096) }

$limitMax = $MaxOutputKB * 1024
$display = if ($raw.Length -gt $limitMax) { $raw.Substring(0, $limitMax) + "`n…[truncated, see receipt hash]" } else { $raw }

$receiptDir = Join-Path $hub 'logs\sandbox'
New-Item -ItemType Directory -Force -Path $receiptDir | Out-Null
$ts = Get-Date
$receipt = [ordered]@{
    receipt_id      = [guid]::NewGuid().ToString()
    timestamp       = $ts.ToString('s')
    actor           = 'agent/qoder'
    tool            = 'sandbox-run'
    argv            = @('sh', '-lc', $Command)
    cwd             = '/work'
    host_workdir    = $work
    mount_mode      = $mountMode
    image           = $Image
    network         = $(if ($AllowNetwork) { 'host' } else { 'none' })
    limits          = [ordered]@{ memory_mb = $MemoryMB; cpus = $Cpus; pids = $PidsLimit; timeout_s = $TimeoutSec }
    exit_code       = $reported
    duration_ms     = $durationMs
    output          = [ordered]@{ bytes = $outBytes; sha256 = $outHash; excerpt = $excerpt }
    limits_enforced = (-not $limitUnenforced)
    verdict         = $(if ($reported -eq 0) { 'pass' } elseif ($reported -eq 2) { 'blocked' } elseif ($reported -eq 124) { 'timeout' } else { 'fail' })
}
$receiptPath = Join-Path $receiptDir ('sandbox-' + $ts.ToString('yyyyMMdd-HHmmss') + '.json')
($receipt | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $receiptPath -Encoding UTF8

# ---------- report ----------
Write-Output ('sandbox: exit=' + $reported + ' verdict=' + $receipt.verdict + ' duration=' + $durationMs + 'ms')
Write-Output ('image:   ' + $Image)
Write-Output ('workdir: ' + $work + ' (' + $mountMode + ')  network=' + $receipt.network)
if ($raw.Trim().Length -gt 0) {
    Write-Output '--- output ---'
    Write-Output $display
}
Write-Output ('receipt: ' + $receiptPath)

if ($reported -eq 0) { exit 0 }
if ($reported -eq 2) { exit 2 }
exit 1
