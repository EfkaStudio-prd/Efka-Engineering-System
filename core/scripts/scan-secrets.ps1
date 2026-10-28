<#
.SYNOPSIS
  High-confidence secret scanner for the Efka Engineering System.
.DESCRIPTION
  Read-only. Flags credential-looking FILENAMES and credential-looking CONTENT.
  It is deliberately conservative: it only reports patterns that are almost always
  real secrets, so a clean result can be trusted without tuning.
  Exit code 1 when anything is found.
.USAGE
  .\scan-secrets.ps1 -Paths 'C:\Efka Engineering System','C:\9Router_Backup'
  .\scan-secrets.ps1 -Paths . -Json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Paths,
    [switch]$Json,
    [int]$MaxFileMB = 2
)

$ErrorActionPreference = 'Stop'

# Accept both -Paths a,b,c and -Paths 'a,b,c' (some launchers keep it as one string).
$Paths = @($Paths | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })
if ($Paths.Count -eq 0) { throw 'No scan paths given.' }

$findings = New-Object System.Collections.ArrayList

function Add-Finding([string]$Path, [string]$Rule, [string]$Evidence) {
    [void]$findings.Add([pscustomobject]@{ Path = $Path; Rule = $Rule; Evidence = $Evidence })
}

# File names that must never live in a normal repository or shareable folder.
$nameRules = @(
    @{ Name = 'mcp router key';    Pattern = '^mcp-router\.json$' },
    @{ Name = 'MCP oauth tokens';  Pattern = '_tokens\.json$' },
    @{ Name = 'env file';          Pattern = '^\.env(\..+)?$' },
    @{ Name = 'initial password';  Pattern = '^initial-password\.env$' },
    @{ Name = 'ssh private key';   Pattern = '^id_(rsa|ed25519|ecdsa)$' },
    @{ Name = 'certificate key';   Pattern = '\.(pfx|p12|pem|key)$' },
    @{ Name = 'netrc/creds file';  Pattern = '^(_netrc|\.npmrc|\.pypirc|credentials)$' }
)

# Content patterns. Generic key=value assignment is only applied to non-markdown
# files, because documentation legitimately shows placeholder examples.
$textRules = @(
    @{ Name = 'private key block'; Pattern = 'BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY' },
    @{ Name = 'json secret field'; Pattern = '"(apiKey|api_key|token|secret|password|client_secret)"\s*:\s*"[A-Za-z0-9_\-\.\+/]{16,}"' },
    @{ Name = 'aws access key';    Pattern = 'AKIA[0-9A-Z]{16}' },
    @{ Name = 'bearer token';      Pattern = 'Bearer\s+[A-Za-z0-9_\-\.]{24,}' }
)
$assignmentRule = @{ Name = 'secret assignment'; Pattern = '(?im)^\s*[A-Za-z0-9_.\-]*(password|passwd|secret|token|api_?key|access_?key|private_?key|client_?secret)\s*[=:]\s*[^\s#]{8,}\s*$' }
$placeholder = '(?i)(example|contoh|placeholder|redacted|xxx|<[^>]+>|\*\*\*|changeme|your[-_]?)'

function Get-Masked([string]$Text) {
    $t = $Text.Trim()
    if ($t.Length -le 8) { return '****' }
    return $t.Substring(0, 4) + '…' + ('*' * 4)
}

foreach ($root in $Paths) {
    if (-not (Test-Path -LiteralPath $root)) {
        Add-Finding $root 'path missing' 'the scan target does not exist'
        continue
    }
    $files = Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\node_modules\\' }

    foreach ($f in $files) {
        foreach ($r in $nameRules) {
            if ($f.Name -match $r.Pattern) { Add-Finding $f.FullName $r.Name 'file name match' }
        }
        if ($f.Length -gt ($MaxFileMB * 1MB)) { continue }
        $isText = $f.Extension -in @('.json', '.ps1', '.sh', '.md', '.txt', '.yml', '.yaml', '.env', '.conf', '.ini', '.py', '.js', '.ts', '.xml')
        if (-not $isText) { continue }

        $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
        $lineNo = 0
        foreach ($line in $lines) {
            $lineNo++
            foreach ($r in $textRules) {
                if ($line -match $r.Pattern) {
                    Add-Finding $f.FullName $r.Name ("line {0}: {1}" -f $lineNo, (Get-Masked $line))
                }
            }
            if ($isText -and $f.Extension -ne '.md' -and $line -match $assignmentRule.Pattern -and $line -notmatch $placeholder) {
                Add-Finding $f.FullName $assignmentRule.Name ("line {0}: {1}" -f $lineNo, (Get-Masked $line))
            }
        }
    }
}

if ($Json) { ConvertTo-Json -Input @($findings) -Depth 3 | Write-Output }
else {
    if ($findings.Count -eq 0) { Write-Output 'scan-secrets: clean (no high-confidence credential patterns)' }
    else {
        Write-Output ("scan-secrets: {0} finding(s)" -f $findings.Count)
        $findings | Format-Table -AutoSize -Wrap Rule, Evidence, Path | Out-String -Width 200 | Write-Output
    }
}

exit $(if ($findings.Count -gt 0) { 1 } else { 0 })
