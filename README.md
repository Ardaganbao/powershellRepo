# PowerShell GitHub Self-Updater

This project includes a small PowerShell updater that downloads the latest version of your scripts from GitHub and replaces the local files.

## Files

- `Start.ps1` - The entry point. Updates itself and the other scripts, then runs every script that is turned on.
- `Manager.ps1` - Window to turn scripts on and off and run them on demand.
- `Update-FromGitHub.ps1` - Downloads files from GitHub.
- `updater.config.json` - Which GitHub repository, branch and files to update from.
- `SampleScript.ps1` - The main script (put your work here).

## Run it

```powershell
.\Start.ps1
```

Every run:

1. Asks the GitHub API for the latest commit and the hash of every file in it, and compares them with the local files. Only files that are missing or changed are downloaded.
2. If `Start.ps1` changed, it replaces itself and restarts with the new version.
3. Updates `updater.config.json`, then every file listed in `Files`.
4. Runs every script listed in `Scripts` that is turned on (see below).

If GitHub can't be reached, it shows a warning and runs the local versions. Use `.\Start.ps1 -SkipUpdate` to run without checking for updates.

The check uses 2 GitHub API requests per run. GitHub allows 60 requests per hour per network without a token; above that the run continues with the local versions.

### Turn scripts on/off and run them on demand

```powershell
.\Start.ps1 -Gui     # update, then open the Script Manager
.\Manager.ps1        # open it without updating
```

- The list shows every script in `Scripts` in `updater.config.json`.
- **Checked** = `Start.ps1` runs it automatically. Unchecked = skipped. This is saved per computer in `scripts.local.json`, which is not uploaded to GitHub.
- **Run selected** (or double-click) runs a script now, whether it is on or off. **Run all turned on** runs every checked script.
- **Check for updates** downloads changed files from GitHub and reloads the list.
- Scripts run one after another in a hidden PowerShell window; their output appears at the bottom.

To add a script to the manager, add its name to both `Files` and `Scripts` in `updater.config.json`.

`.\Start.ps1 -UpdateOnly` only updates the files without running anything.

### Install and run with one line

```powershell
irm https://raw.githubusercontent.com/Ardaganbao/powershellRepo/main/Start.ps1 | iex
```

This saves `Start.ps1` to `$HOME\powershellRepo`, downloads the other scripts there and opens the Script Manager. Run the same line again any time to update and open it. To run the turned-on scripts without the window, use `& "$HOME\powershellRepo\Start.ps1"`.

To install to another folder:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Ardaganbao/powershellRepo/main/Start.ps1))) -InstallPath C:\Scripts
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
