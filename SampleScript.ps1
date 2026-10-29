[CmdletBinding()]
param(
    [switch]$Update
)

$Updater = Join-Path $PSScriptRoot "Update-FromGitHub.ps1"

if ($Update) {
    # Repository details and file list come from updater.config.json.
    & $Updater -TargetFolder $PSScriptRoot
    exit
}

Write-Host "Sample script is running."
Write-Host "Use -Update to download the latest version from GitHub."
