[CmdletBinding()]
param(
    [Parameter()]
    [string]$Owner = "Ardaganbao",

    [Parameter()]
    [string]$Repository = "powershellRepo",

    [Parameter()]
    [string]$Branch = "main",

    # Where the one-liner installs the scripts.
    [Parameter()]
    [string]$InstallPath = (Join-Path $HOME "powershellRepo"),

    [Parameter()]
    [switch]$SkipUpdate,

    # Set internally when the script restarts after updating itself.
    [Parameter(DontShow)]
    [switch]$SelfUpdated
)

# GitHub requires TLS 1.2; Windows PowerShell 5.1 may not enable it by default.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Started from the one-liner (irm ... | iex): there is no file yet, so save Start.ps1
# into $InstallPath and run it from there in a new process, which keeps this session
# clean and works whatever the execution policy is.
if (-not $PSCommandPath) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    $startPath = Join-Path $InstallPath "Start.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$Owner/$Repository/$Branch/Start.ps1" -OutFile $startPath -UseBasicParsing -Headers @{ "User-Agent" = "PowerShell-Updater" }
    Write-Host "Installed to $InstallPath"
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $startPath -Owner $Owner -Repository $Repository -Branch $Branch
    return
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

$RawBase = "https://raw.githubusercontent.com/$Owner/$Repository/$Branch"

# Downloads one file from the repository; returns $true when the local copy changed.
function Update-RepoFile {
    param(
        [string]$Name
    )

    $destination = Join-Path $PSScriptRoot $Name
    $tempFile = [System.IO.Path]::GetTempFileName()

    try {
        Invoke-WebRequest -Uri "$RawBase/$Name" -OutFile $tempFile -UseBasicParsing -Headers @{ "User-Agent" = "PowerShell-Updater" }

        if ((Test-Path $destination) -and (Get-FileHash $tempFile).Hash -eq (Get-FileHash $destination).Hash) {
            return $false
        }

        Copy-Item -Path $tempFile -Destination $destination -Force
        return $true
    }
    finally {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}

if (-not $SkipUpdate) {
    $restart = $false

    try {
        # 1. Update this script first; the new version takes over from here.
        $restart = -not $SelfUpdated -and (Update-RepoFile -Name (Split-Path -Leaf $PSCommandPath))

        if (-not $restart) {
            # 2. Get the latest updater and config, then let it update the other scripts.
            Update-RepoFile -Name "Update-FromGitHub.ps1" | Out-Null
            Update-RepoFile -Name "updater.config.json" | Out-Null
            & (Join-Path $PSScriptRoot "Update-FromGitHub.ps1") -Owner $Owner -Repository $Repository -Branch $Branch -TargetFolder $PSScriptRoot
        }
    }
    catch {
        Write-Warning "Update check failed, running the local version: $($_.Exception.Message)"
    }

    if ($restart) {
        Write-Host "Entry point updated, restarting with the new version..."
        & $PSCommandPath @PSBoundParameters -SelfUpdated
        return
    }
}

# 3. Run the main script.
& (Join-Path $PSScriptRoot "SampleScript.ps1")
