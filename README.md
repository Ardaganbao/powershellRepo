# PowerShell GitHub Self-Updater

This project includes a small PowerShell updater that downloads the latest version of your scripts from GitHub and replaces the local files.

## Files

- `Update-FromGitHub.ps1` - Downloads files from GitHub.
- `updater.config.json` - Which GitHub repository, branch and files to update from.
- `SampleScript.ps1` - Example script that can self-update.

## Configure it

1. Push this folder to a GitHub repository.
2. Edit `updater.config.json`:

```json
{
    "Owner": "your-github-user",
    "Repository": "your-repository",
    "Branch": "main",
    "Files": ["SampleScript.ps1", "Update-FromGitHub.ps1"]
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

## Example local script self-update

```powershell
.\SampleScript.ps1 -Update
```

## Private repositories

Create a GitHub personal access token with read access to the repository's contents, then set it before running the updater:

```powershell
$env:GITHUB_TOKEN = "github_pat_..."
.\Update-FromGitHub.ps1
```

## Never commit passwords

This repository is public. Never put passwords, tokens or keys in the scripts; read them from environment variables instead (for example `$env:GITHUB_TOKEN`).

A pre-commit hook blocks commits that look like they contain a secret. Enable it once in every clone:

```powershell
git config core.hooksPath .githooks
```

## Notes

- Keep the file names and folder layout the same on GitHub and locally.
- If scripts are blocked from running, use `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
