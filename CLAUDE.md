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
