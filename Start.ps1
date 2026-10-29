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

    # Set internally when the script restarts after all updates were downloaded.
    [Parameter(DontShow)]
    [switch]$UpdatesApplied,

    # Set by older versions, which restart before downloading the other files.
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

# The version is the git commit this folder was last updated to (kept out of the repository, see .gitignore).
$VersionPath = Join-Path $PSScriptRoot "installed-version.txt"
$InstalledCommit = ""
if (Test-Path $VersionPath) {
    $InstalledCommit = (Get-Content -Path $VersionPath -Raw).Trim()
}

$versionLabel = "unknown"
if ($InstalledCommit) {
    $versionLabel = $InstalledCommit.Substring(0, 7)
}

# onIT logo as pixels: T = teal, W = white, N = navy, . = background.
# Each console line shows two pixel rows using half-block characters.
$LogoPixels = @(
    '.......TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.......',
    '.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWTTTT.....',
    '...TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWWWWTTTT...',
    '..TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWWWWWWWWTTT..',
    '..TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWWWWWWWWWWTT..',
    '.TTTTTTTTTTTTWWWWWTTTTTWWWTWWWWWTTTTTTTTTTWWWWWWWWWWWWWWTTT.',
    '.TTTTTTTTTTWWWWWWWWWTTTWWWWWWWWWWTTTTTTTTWWNNNWNNNNNNNNNWTT.',
    'TTTTTTTTTTWWWWTTTWWWWTTWWWWWTTWWWWTTTTTTTWWNNNWNNNNNNNNNWTTT',
    'TTTTTTTTTTWWWTTTTTWWWTTWWWTTTTTWWWTTTTTTWWWNNNWWWWNNNWWWWWTT',
    'TTTTTTTTTTWWWTTTTTWWWTTWWWTTTTTWWWTTTTTTWWWNNNWWWWNNNWWWWWTT',
    'TTTTTTTTTTWWWTTTTTWWWTTWWWTTTTTWWWTTTTTTWWWNNNWWWWNNNWWWWWTT',
    'TTTTTTTTTTWWWTTTTTWWWTTWWWTTTTTWWWTTTTTTWWWNNNWWWWNNNWWWWWTT',
    'TTTTTTTTTTWWWWTTTWWWWTTWWWTTTTTWWWTTTTTTTWWNNNWWWWNNNWWWWTTT',
    '.TTTTTTTTTTWWWWWWWWWTTTWWWTTTTTWWWTTTTTTTWWNNNWWWWNNNWWWWTT.',
    '.TTTTTTTTTTTTWWWWWTTTTTWWWTTTTTWWWTTTTTTTTWWWWWWWWWWWWWWTTT.',
    '..TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWWWWWWWWWWTT..',
    '..TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWWWWWWWWTTT..',
    '...TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWWWWWTTTT...',
    '.....TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWWWWTTTT.....',
    '.......TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT.......'
)

# Brand colours as "R;G;B" for 24-bit console colour codes.
$LogoColors = @{ T = "108;192;194"; W = "255;255;255"; N = "26;43;73" }

# Plain-text logo for consoles without 24-bit colour (e.g. PowerShell ISE).
$AsciiLogo = @(
    '    __________________________________________ ',
    '   /                         _____________    \',
    '  |      ___  _ __          /  ___ _____  \    |',
    '  |     / _ \| ''_ \        |  |_ _|_   _|  |   |',
    '  |    | (_) | | | |       |   | |  | |    |   |',
    '  |     \___/|_| |_|       |  |___| |_|    |   |',
    '   \                        \_____________/   / ',
    '    \________________________________________/  '
)

function Write-Logo {
    $supportsColor = -not [Console]::IsOutputRedirected -and
        $Host.UI.PSObject.Properties["SupportsVirtualTerminal"] -and $Host.UI.SupportsVirtualTerminal

    if ($supportsColor) {
        Write-PixelLogo
    }
    else {
        Write-AsciiLogo
    }
}

function Write-PixelLogo {
    # Characters are built at run time so this file stays plain ASCII for Windows PowerShell 5.1.
    $esc = [char]27
    $upperHalf = [char]0x2580
    $lowerHalf = [char]0x2584

    for ($y = 0; $y -lt $LogoPixels.Count; $y += 2) {
        $top = $LogoPixels[$y]
        $bottom = $LogoPixels[$y + 1]
        $line = New-Object System.Text.StringBuilder
        [void]$line.Append("  ")

        for ($x = 0; $x -lt $top.Length; $x++) {
            $upper = [string]$top[$x]
            $lower = [string]$bottom[$x]

            if ($upper -eq "." -and $lower -eq ".") {
                [void]$line.Append("$esc[0m ")
            }
            elseif ($lower -eq ".") {
                [void]$line.Append("$esc[0;38;2;$($LogoColors[$upper])m$upperHalf")
            }
            elseif ($upper -eq ".") {
                [void]$line.Append("$esc[0;38;2;$($LogoColors[$lower])m$lowerHalf")
            }
            else {
                [void]$line.Append("$esc[38;2;$($LogoColors[$upper]);48;2;$($LogoColors[$lower])m$upperHalf")
            }
        }

        [void]$line.Append("$esc[0m")
        Write-Host $line.ToString()
    }
}

function Write-AsciiLogo {
    for ($row = 0; $row -lt $AsciiLogo.Count; $row++) {
        $line = $AsciiLogo[$row].PadRight(48)

        if ($row -eq 0 -or $row -eq $AsciiLogo.Count - 1) {
            Write-Host $line -ForegroundColor DarkCyan
            continue
        }

        # Columns: pill | "on" | pill | circle | "IT" (circle edge on its first and last row) | circle | pill
        $itColor = "Blue"
        if ($row -eq 1 -or $row -eq $AsciiLogo.Count - 2) {
            $itColor = "White"
        }

        $parts = @(
            @(0, 7, "DarkCyan"), @(7, 13, "White"), @(20, 7, "DarkCyan"),
            @(27, 3, "White"), @(30, 11, $itColor), @(41, 3, "White"), @(44, 4, "DarkCyan")
        )
        foreach ($part in $parts) {
            Write-Host $line.Substring($part[0], $part[1]) -ForegroundColor $part[2] -NoNewline
        }
        Write-Host ""
    }
}

# Shown once per run; the restart after a self-update confirms it instead.
if ($UpdatesApplied -or $SelfUpdated) {
    Write-Host "Restarted with the new Start.ps1." -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host ""
    # Skipped for -UpdateOnly, whose output the Script Manager shows as plain text.
    if (-not $UpdateOnly) {
        Write-Logo
        Write-Host ""
    }
    Write-Host "Welcome to powershellRepo (version $versionLabel), $env:USERNAME!" -ForegroundColor Cyan
    Write-Host "This keeps your scripts up to date from GitHub and runs the ones that are turned on."
    Write-Host ""
    Write-Host "  .\Start.ps1 -Gui         Open the Script Manager to turn scripts on/off and run them" -ForegroundColor DarkGray
    Write-Host "  .\Start.ps1 -UpdateOnly  Update without running anything" -ForegroundColor DarkGray
    Write-Host "  .\Start.ps1 -SkipUpdate  Run without checking GitHub" -ForegroundColor DarkGray
    Write-Host ""
    if ($SkipUpdate) {
        Write-Host "Update check skipped." -ForegroundColor DarkGray
    }
    else {
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

if (-not $SkipUpdate -and -not $UpdatesApplied) {
    $restart = $false

    try {
        # Ask GitHub for the latest commit and the hash of every file in it,
        # so only the files that changed are downloaded.
        $commit = Invoke-RestMethod -Uri "$ApiBase/commits/$Branch" -Headers $Headers
        $CommitSha = $commit.sha
        $tree = Invoke-RestMethod -Uri "$ApiBase/git/trees/${CommitSha}?recursive=1" -Headers $Headers
        $RemoteHashes = @{}
        $tree.tree | Where-Object { $_.type -eq "blob" } | ForEach-Object { $RemoteHashes[$_.path] = $_.sha }

        # 1. Download every update first: this script, the config, then every file it lists.
        $restart = -not $SelfUpdated -and (Update-RepoFile -Name (Split-Path -Leaf $PSCommandPath))
        $configChanged = Update-RepoFile -Name "updater.config.json"
        $config = Get-Content -Path (Join-Path $PSScriptRoot "updater.config.json") -Raw | ConvertFrom-Json
        $changed = @($config.Files | Where-Object { Update-RepoFile -Name $_ })

        if (-not $restart -and -not $configChanged -and $changed.Count -eq 0) {
            Write-Host "Everything is up to date."
        }

        $date = ([datetime]$commit.commit.committer.date).ToLocalTime().ToString("yyyy-MM-dd HH:mm")
        $message = ($commit.commit.message -split "`n")[0]
        $versionText = "version $($CommitSha.Substring(0, 7)) ($date): $message"

        if ($CommitSha -ne $InstalledCommit) {
            Set-Content -Path $VersionPath -Value $CommitSha -Encoding ascii
            Write-Host "Updated to $versionText" -ForegroundColor Green
        }
        else {
            Write-Host "Running $versionText" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    catch {
        Write-Warning "Update check failed, running the local version: $($_.Exception.Message)"
    }

    # 2. If this script changed, restart so the new version runs the scripts.
    #    The other scripts are read from disk when they run, so they need no restart.
    if ($restart) {
        Write-Host "Start.ps1 was updated, restarting with the new version..." -ForegroundColor Green
        & $PSCommandPath @PSBoundParameters -UpdatesApplied
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
Write-Host "Running scripts..." -ForegroundColor DarkGray
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
