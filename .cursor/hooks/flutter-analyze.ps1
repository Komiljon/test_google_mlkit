# Hook: run flutter analyze after .dart edits (afterFileEdit / postToolUse).
# Reads JSON from stdin; returns additional_context for the agent.

$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Output '{}'
    exit 0
}

try {
    # $input — зарезервированная переменная PowerShell; используем $hookInput
    $hookInput = $raw | ConvertFrom-Json
} catch {
    Write-Output '{}'
    exit 0
}

$filePath = $null
if ($hookInput.file_path) {
    $filePath = [string]$hookInput.file_path
} elseif ($hookInput.tool_input) {
    $ti = $hookInput.tool_input
    if ($ti.path) { $filePath = [string]$ti.path }
    elseif ($ti.file_path) { $filePath = [string]$ti.file_path }
    elseif ($ti.target_file) { $filePath = [string]$ti.target_file }
}

if (-not $filePath -or -not $filePath.EndsWith('.dart', [StringComparison]::OrdinalIgnoreCase)) {
    Write-Output '{}'
    exit 0
}

$dir = Split-Path -Parent $filePath
$projectRoot = $null
while ($dir) {
    if (Test-Path (Join-Path $dir 'pubspec.yaml')) {
        $projectRoot = $dir
        break
    }
    $parent = Split-Path -Parent $dir
    if ($parent -eq $dir) { break }
    $dir = $parent
}

if (-not $projectRoot) {
    Write-Output '{}'
    exit 0
}

$stateDir = Join-Path $projectRoot '.cursor\hooks'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$stampFile = Join-Path $stateDir '.flutter-analyze.last'
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
if (Test-Path $stampFile) {
    $last = [int64](Get-Content $stampFile -Raw)
    if (($now - $last) -lt 5) {
        Write-Output '{}'
        exit 0
    }
}
Set-Content -Path $stampFile -Value $now -NoNewline

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    $msg = 'flutter analyze hook: flutter not found in PATH.'
    Write-Output (@{ additional_context = $msg } | ConvertTo-Json -Compress)
    exit 0
}

Push-Location $projectRoot
try {
    $relative = $filePath.Substring($projectRoot.Length).TrimStart('\', '/')
    $output = & flutter analyze $relative 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

$summary = $output.Trim()
if ($summary.Length -gt 3500) {
    $summary = $summary.Substring(0, 3500) + "`n... (truncated)"
}

$status = if ($exitCode -eq 0) { 'OK (exit 0)' } else { "issues (exit $exitCode)" }

$message = @"
[Hook flutter analyze] File: $relative
Status: $status

$summary

Fix analyzer errors before telling the user the task is done.
"@

Write-Output (@{ additional_context = $message } | ConvertTo-Json -Compress)
exit 0
