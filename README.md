# PowerShell GitHub Self-Updater

This project includes a small PowerShell updater that downloads the latest version of your scripts from GitHub and replaces the local files.

## Files

- `Start.ps1` - The entry point. Updates itself and the other scripts, then runs `SampleScript.ps1`.
- `Update-FromGitHub.ps1` - Downloads files from GitHub.
- `updater.config.json` - Which GitHub repository, branch and files to update from.
- `SampleScript.ps1` - The main script (put your work here).

## Run it

```powershell
.\Start.ps1
```

Every run:

1. Downloads the latest `Start.ps1`. If it changed, it replaces itself and restarts with the new version.
2. Downloads the latest `Update-FromGitHub.ps1` and `updater.config.json`, then every file listed in `Files`.
3. Runs `SampleScript.ps1`.

If GitHub can't be reached, it shows a warning and runs the local versions. Use `.\Start.ps1 -SkipUpdate` to run without checking for updates.

### Install on a new computer

Only `Start.ps1` is needed; it downloads everything else on the first run:

```powershell
mkdir C:\Scripts; cd C:\Scripts
Invoke-WebRequest https://raw.githubusercontent.com/Ardaganbao/powershellRepo/main/Start.ps1 -OutFile Start.ps1
.\Start.ps1
```

To add a script, put it in the repository and add its name to `Files` in `updater.config.json`.

## Configure it

1. Push this folder to a GitHub repository.
2. Edit `updater.config.json`:

```json
{
    "Owner": "your-github-user",
    "Repository": "your-repository",
    "Branch": "main",
    "Files": ["Start.ps1", "SampleScript.ps1", "Update-FromGitHub.ps1"]
}
```

- `Owner` = your GitHub username or organization
- `Repository` = your repository name
- `Branch` = the branch to pull from, usually `main`
- `Files` = the files to update, as paths relative to the repository root

Any value can also be passed on the command line (`-Owner`, `-Repository`, `-Branch`, `-Files`), which overrides the config file.

## Update the configured files

```powershell
.\Update-FromGitHub.ps1
```

Files that already match GitHub are skipped. Add `-Force` to overwrite them anyway.

## Update the whole project folder

```powershell
.\Update-FromGitHub.ps1 -UpdateProject
```

## Update from the latest GitHub Release

```powershell
.\Update-FromGitHub.ps1 -UseRelease
```

The first `.zip` or `.ps1` asset of the latest release is used. If there is no release, the configured files are downloaded from the branch instead.

## Passwords and secrets

This repository is public. Never put passwords, tokens or keys in the scripts. Store them in the local SecretManagement vault and read them with `Get-Secret`.

One-time setup on each computer:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```

Store a secret (you type the value at the prompt, so it never appears in a script or the command history). The first time, you also choose the vault password:

```powershell
Set-Secret -Name MyPassword                      # a plain password
Set-Secret -Name MyLogin -Secret (Get-Credential) # a user name + password
```

Use it in a script:

```powershell
$password   = Get-Secret -Name MyPassword               # SecureString
$credential = Get-Secret -Name MyLogin                  # PSCredential, e.g. -Credential $credential
$plain      = Get-Secret -Name MyPassword -AsPlainText  # only when an API needs plain text
```

Useful commands: `Get-SecretInfo` (list names), `Remove-Secret -Name MyPassword`, `Unlock-SecretStore` (unlock the vault at the start of a session).

### Private repositories

Store a GitHub personal access token with read access to the repository's contents in the vault, then put its name in `updater.config.json`:

```powershell
Set-Secret -Name GitHubToken
```

```json
"TokenSecretName": "GitHubToken"
```

## Never commit passwords

A pre-commit hook blocks commits that look like they contain a secret. Enable it once in every clone:

```powershell
git config core.hooksPath .githooks
```

## Notes

- Keep the file names and folder layout the same on GitHub and locally.
- If scripts are blocked from running, use `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
