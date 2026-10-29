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

    # Only update the files; don't run any script.
    [Parameter()]
    [switch]$UpdateOnly,

    # Open Manager.ps1 after updating instead of running the scripts.
    [Parameter()]
    [switch]$Gui,

    # Set internally when the script restarts after updating itself.
    [Parameter(DontShow)]
    [switch]$SelfUpdated
)

# GitHub requires TLS 1.2; Windows PowerShell 5.1 may not enable it by default.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Started from the one-liner (irm ... | iex): there is no file yet, so save Start.ps1
# into $InstallPath and run it from there in a new process, which keeps this session
# clean and works whatever the execution policy is. It then opens the Script Manager.
if (-not $PSCommandPath) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    $startPath = Join-Path $InstallPath "Start.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$Owner/$Repository/$Branch/Start.ps1" -OutFile $startPath -UseBasicParsing -Headers @{ "User-Agent" = "PowerShell-Updater" }
    Write-Host "Installed to $InstallPath"
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $startPath -Owner $Owner -Repository $Repository -Branch $Branch -Gui
    return
}

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

# Raise this when you change Start.ps1 so you can see which version a computer runs.
$StartVersion = "1.1"

# Shown once per run; the restart after a self-update skips it.
if (-not $SelfUpdated) {
    Write-Host ""
    Write-Host "Welcome to powershellRepo v$StartVersion, $env:USERNAME!" -ForegroundColor Cyan
    if (-not $SkipUpdate) {
        Write-Host "Checking GitHub for updates..." -ForegroundColor DarkGray
    }
    Write-Host ""
}

$ApiBase = "https://api.github.com/repos/$Owner/$Repository"
$Headers = @{ "User-Agent" = "PowerShell-Updater" }

# Git's hash of a local file, the same value GitHub lists for each file in the repository.
function Get-GitBlobHash {
    param(
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $header = [System.Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $sha1 = [System.Security.Cryptography.SHA1]::Create()

    try {
        $sha1.TransformBlock($header, 0, $header.Length, $null, 0) | Out-Null
        $sha1.TransformFinalBlock($bytes, 0, $bytes.Length) | Out-Null
        return -join ($sha1.Hash | ForEach-Object { $_.ToString("x2") })
    }
    finally {
        $sha1.Dispose()
    }
}

# Downloads one file only when it is missing or differs from the repository;
# returns $true when the local copy changed.
function Update-RepoFile {
    param(
        [string]$Name
    )

    $repoPath = $Name -replace '\\', '/'
    if (-not $RemoteHashes.ContainsKey($repoPath)) {
        Write-Warning "$Name is not in the repository."
        return $false
    }

    $destination = Join-Path $PSScriptRoot $Name
    if ((Test-Path $destination) -and (Get-GitBlobHash $destination) -eq $RemoteHashes[$repoPath]) {
        return $false
    }

    $tempFile = [System.IO.Path]::GetTempFileName()

    try {
        # Download from the exact commit so a just-pushed change is never served stale.
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$Owner/$Repository/$CommitSha/$repoPath" -OutFile $tempFile -UseBasicParsing -Headers $Headers

        $destinationFolder = Split-Path -Parent $destination
        if (-not (Test-Path $destinationFolder)) {
            New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
        }

        Copy-Item -Path $tempFile -Destination $destination -Force
        Write-Host "Updated: $Name"
        return $true
    }
    finally {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}

if (-not $SkipUpdate) {
    $restart = $false

    try {
        # Ask GitHub for the latest commit and the hash of every file in it,
        # so only the files that changed are downloaded.
        $CommitSha = Invoke-RestMethod -Uri "$ApiBase/commits/$Branch" -Headers ($Headers + @{ Accept = "application/vnd.github.sha" })
        $tree = Invoke-RestMethod -Uri "$ApiBase/git/trees/${CommitSha}?recursive=1" -Headers $Headers
        $RemoteHashes = @{}
        $tree.tree | Where-Object { $_.type -eq "blob" } | ForEach-Object { $RemoteHashes[$_.path] = $_.sha }

        # 1. Update this script first; the new version takes over from here.
        $restart = -not $SelfUpdated -and (Update-RepoFile -Name (Split-Path -Leaf $PSCommandPath))

        if (-not $restart) {
            # 2. Update the config, then every file it lists.
            $configChanged = Update-RepoFile -Name "updater.config.json"
            $config = Get-Content -Path (Join-Path $PSScriptRoot "updater.config.json") -Raw | ConvertFrom-Json
            $changed = @($config.Files | Where-Object { Update-RepoFile -Name $_ })

            if (-not $configChanged -and $changed.Count -eq 0) {
                Write-Host "Everything is up to date."
            }
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

if ($UpdateOnly) {
    return
}

if ($Gui) {
    & (Join-Path $PSScriptRoot "Manager.ps1")
    return
}

# 3. Run every script in the config that is turned on; Manager.ps1 turns them on and off.
$config = Get-Content -Path (Join-Path $PSScriptRoot "updater.config.json") -Raw | ConvertFrom-Json
$statePath = Join-Path $PSScriptRoot "scripts.local.json"
$turnedOff = @()
if (Test-Path $statePath) {
    $turnedOff = @((Get-Content -Path $statePath -Raw | ConvertFrom-Json).PSObject.Properties |
        Where-Object { -not $_.Value } |
        ForEach-Object { $_.Name })
}

foreach ($name in $config.Scripts) {
    if ($turnedOff -contains $name) {
        Write-Host "Skipped (turned off): $name"
        continue
    }

    try {
        & (Join-Path $PSScriptRoot $name)
    }
    catch {
        Write-Warning "$name failed: $($_.Exception.Message)"
    }
}
