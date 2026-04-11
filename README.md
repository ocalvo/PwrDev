# PwrDev

PowerShell module providing build, deploy, and error-navigation tooling for C++ and .NET projects in Visual Studio environments. Works natively on Windows and transparently bridges WSL to the Windows toolchain for builds that require it.

## Installation

**From the PowerShell Gallery:**
```powershell
Install-Module PwrDev -Scope CurrentUser
```

**From source:**
```powershell
# PowerShell Core
git clone https://github.com/ocalvo/PwrDev.git "$HOME\Documents\PowerShell\Modules\PwrDev"

# Windows PowerShell
git clone https://github.com/ocalvo/PwrDev.git "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\PwrDev"
```

Then in a PowerShell session:
```powershell
Import-Module PwrDev
```

## Core Commands

### Build

```powershell
# Auto-detect solution/project and build
build

# Specific configuration and platform
build -Configuration Release -Platform ARM64ec

# Build a specific target
build -Target "Apps\MyApp\MyAppPackage"
```

`build` auto-detects `.sln` and `.*proj` files in the working directory. If a `.vcxproj` is found and you're in WSL, it transparently re-invokes on the Windows side.

### Deploy (Build + Sideload)

```powershell
# Build and sideload the default package (reads BUILD_CUSTOM_PARAM01)
dpb

# Build and sideload a Release build
dpb -Configuration Release

# Skip the build step, just redeploy last output
dpb -SkipBuild
```

`dpb` (`Deploy-ProjectBuild`) always runs on the Windows side (invokes Windows from WSL if needed).

### Build Errors

```powershell
# Open the first build error in your editor
goerror

# Open the 2nd and 3rd errors (skip first)
goerror -first 2 -skip 1

# List all errors as objects
Get-BuildErrors

# Include warnings
Get-BuildErrors -IncludeWarnings
```

### File Editing

```powershell
# Open a file at a specific line (terminal-aware editor)
edit src\foo.cpp 42
```

`Edit-File` (aliased as `edit`) selects the right editor based on the current terminal:

| Terminal | Editor |
|----------|--------|
| Visual Studio (DevHub) | VS DTE — opens in the running VS instance |
| VS Code | `code --goto file:line` |
| Claude Code | `vim.exe` in a new window |
| Other | `vim.exe` inline |

### VS Developer Shell

```powershell
# Initialize the Visual Studio developer environment
Enter-VsShell
```

Finds the latest Visual Studio installation (Enterprise → Professional → Community, 2022 → 2019) and loads its developer shell. Falls back to `dotnet msbuild` on Linux/macOS.

## Environment Variables

These control default `dpb` behavior and can be set in your profile:

```powershell
$env:BUILD_CUSTOM_PARAM01  = "MyApp"              # Package name token
$env:BUILD_DEFAULT_TARGET  = "Apps\{0}\{0}Package" # MSBuild target template
$env:BUILD_APPX_RECIPE     = ".\BuildResults\{0}-{1}\{2}Package\bin\{2}Package\{2}Package.build.appxrecipe"
```

`{0}` = `BUILD_CUSTOM_PARAM01`, `{1}` = Platform, `{2}` = package name.

## Developer Mode (Windows)

Symlink creation during builds requires Windows Developer Mode. PwrDev provides helpers:

```powershell
# Check whether Developer Mode is enabled
Confirm-DevMode

# Enable Developer Mode (requires admin)
Setup-DevMode
```

## WSL Support

`Invoke-OnWindowsIfWsl` transparently re-invokes the calling script on the Windows side when running from WSL. This is used automatically by `build` (for C++ projects) and `dpb` (always). You can use it in your own scripts:

```powershell
Invoke-OnWindowsIfWsl  # at the top of any script that requires Windows tooling
```

## All Exported Commands

| Command / Alias | Description |
|-----------------|-------------|
| `build` | Build project (auto-detects solution/project) |
| `dpb` / `Deploy-ProjectBuild` | Build and sideload appx package |
| `Enter-VsShell` | Initialize VS developer shell |
| `goerror` / `Edit-BuildErrors` | Open build errors in editor |
| `Get-BuildErrors` | List build errors as objects |
| `edit` / `Edit-File` | Open file at line in terminal-aware editor |
| `Invoke-OnWindowsIfWsl` | Re-invoke script on Windows side from WSL |
| `Get-RepoRoot` | Find the git repository root |
| `Confirm-DevMode` | Check Windows Developer Mode status |
| `Setup-DevMode` | Enable Windows Developer Mode (admin) |
| `test-build` | Run incremental build benchmarks |
| `Open-LastBinLog` | Open the last build `.binlog` in a viewer |

## See Also

- [CHANGELOG](CHANGELOG.md)
- [GitHub repository](https://github.com/ocalvo/PwrDev)
