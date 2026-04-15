# PwrDev — Build and Deploy Directives

PwrDev is the build and deployment tooling module for C++ and .NET projects. It is loaded in this session. Use its commands instead of invoking `msbuild` or `dotnet build` directly.

## Module Source

This module's source files are in `$_.ModuleBase` (e.g. `Modules\PwrDev\`). Key files:
- `Invoke-BuildTool.ps1` — `build` implementation
- `Deploy-ProjectBuild.ps1` — `dpb` implementation
- `Get-BuildErrors.ps1` — error parsing
- `Edit-File.ps1` — terminal-aware editor launcher
- `Enter-VsShell.ps1` — VS developer shell setup

## Commands

| Command / Alias | Description |
|----------------|-------------|
| `build` | Build project (auto-detects `.sln`/`.*proj` in cwd) |
| `dpb` / `Deploy-ProjectBuild` | Build and sideload appx package |
| `Enter-VsShell` | Initialize Visual Studio developer shell |
| `goerror` / `Edit-BuildErrors` | Open build error(s) in editor |
| `Get-BuildErrors` | List build errors as objects |
| `edit` / `Edit-File` | Open file at line in terminal-aware editor |
| `Get-RepoRoot` | Find the git repository root |
| `Confirm-DevMode` | Check Windows Developer Mode status |
| `Setup-DevMode` | Enable Windows Developer Mode (admin) |
| `test-build` | Run incremental build benchmarks |
| `Open-LastBinLog` | Open last build `.binlog` in viewer |
| `Invoke-OnWindowsIfWsl` | Re-invoke script on Windows side from WSL |

## Common Workflows

```powershell
# Build (auto-detects solution/project)
build

# Build a specific configuration and platform
build -Configuration Release -Platform ARM64ec

# Build and sideload (default: reads BUILD_CUSTOM_PARAM01, Debug, x64)
dpb

# Build and sideload Release
dpb -Configuration Release

# Skip build, redeploy last output
dpb -SkipBuild

# Show build errors
Get-BuildErrors

# Open first build error in editor
goerror

# Open 2nd and 3rd errors (skip first)
goerror -first 2 -skip 1

# Open a file at a line
edit src\foo.cpp 42
```

## Environment Variables

```powershell
$env:BUILD_CUSTOM_PARAM01  = "TV"                              # Package name token
$env:BUILD_DEFAULT_TARGET  = "Apps\{0}\{0}Package"             # MSBuild target template
$env:BUILD_APPX_RECIPE     = ".\BuildResults\{0}-{1}\{2}Package\bin\{2}Package\{2}Package.build.appxrecipe"
```

`dpb` with no arguments is equivalent to:
```powershell
dpb -UserParam01 TV -Target "Apps\TV\TVPackage" -Configuration Debug -Platform x64
```

## WSL Behavior

- `build` auto-detects C++ projects (`.vcxproj`) and re-invokes on Windows from WSL.
- `dpb` always runs on Windows (uses `Invoke-OnWindowsIfWsl` internally).
- Symlink creation during builds requires Windows Developer Mode (`Confirm-DevMode`).

## Editor Behavior (`Edit-File`)

| Terminal | Editor used |
|----------|-------------|
| Visual Studio (DevHub) | VS DTE — opens in running VS instance |
| VS Code | `code --goto file:line` |
| Claude Code | `Start-Process vim.exe` (new window) |
| Other | `vim.exe` inline |

## Branch and PR Policy (release-please)

**Never commit directly to `main`.** All changes must go through a feature branch and pull request. This repo uses [release-please](https://github.com/googleapis/release-please) to automate versioning and changelog generation from merged PR titles.

1. `git checkout -b <short-slug>` — e.g. `feat/build-arm64`, `fix/vsshell-path`.
2. Commit on that branch.
3. `gh pr create --title "<type>: <description>" --body "..."` — use `--base main`.
4. Squash-merge; GitHub uses the PR title as the commit subject, which release-please parses.
5. Release-please opens/updates a release PR bumping `PwrDev.psd1` and `CHANGELOG.md`. Merge that to publish.

**PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/):**

```
<type>[optional scope][!]: <short description>
```

| Type | Version bump | Use for |
|------|--------------|---------|
| `feat` | minor (`1.2.3` → `1.3.0`) | New features, new commands, new parameters |
| `fix` | patch (`1.2.3` → `1.2.4`) | Bug fixes |
| `feat!` / `fix!` / `BREAKING CHANGE:` footer | major (`1.2.3` → `2.0.0`) | Breaking API or behavior changes |
| `perf` | patch | Performance improvements |
| `refactor` | patch | Internal restructuring, no behavior change |
| `docs` | no release | Documentation-only (README, CLAUDE.md) |
| `chore` | no release | Housekeeping, deps, formatting |
| `ci` | no release | CI/CD config |
| `test` | no release | Test-only changes |

Examples:

```
feat(build): add -Incremental switch to build command
fix(dpb): correct appx recipe path for ARM64ec
perf(Enter-VsShell): cache developer shell detection
feat!: rename Deploy-ProjectBuild to Publish-AppxBuild
docs: update CLAUDE.md with WSL behavior notes
```

Rules:
- **Imperative mood** ("add", "fix", "remove" — not "added", "fixes").
- Under 72 characters.
- No generic messages ("update files", "misc changes").
- Split unrelated changes into separate PRs.
- If a PR title doesn't match the grammar, release-please silently ignores it.
