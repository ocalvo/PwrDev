---
name: pwrdev-build
description: "Read before building, compiling, deploying or sideloading anything here, or when reading build errors. PwrDev wraps the toolchain - use build / dpb / Get-BuildErrors / goerror / ef and never invoke msbuild or dotnet build directly. Covers checking for .slnx before .sln, the BUILD_* environment variables, the hard rule that build output must never be piped through Out-String because it breaks MSBuild's terminal logger, WSL re-invocation on the Windows side, and why Edit-File.ps1 is sensitive and must be tested in three terminal contexts."
---

# PwrDev - build and deploy

Build and deployment tooling for C++ and .NET. **Never invoke `msbuild` or
`dotnet build` directly** - PwrDev wraps the correct toolchain, sets up the
developer shell, and surfaces errors through `Get-BuildErrors`. This applies to
Windows (MSBuild/vcxproj) and Android (Gradle) alike.

**Check for a `.slnx` file** (the newer solution format) before falling back to
`.sln`, and run `build` from the directory that contains it - PwrDev
auto-detects. Example: `TVAppServices.slnx` is at the repo root, so run `build`
there, not in a subdirectory.

## Commands

| Command / alias | Description |
|---|---|
| `build` | Build; auto-detects `.slnx`/`.sln`/`.*proj` in cwd |
| `dpb` / `Deploy-ProjectBuild` | Build and sideload the appx package |
| `Enter-VsShell` | Initialise the VS developer shell |
| `goerror` / `Edit-BuildErrors` | Open build error(s) in the editor |
| `Get-BuildErrors` | Build errors as objects |
| `ef` / `Edit-File` | Open a file at a line, terminal-aware |
| `Get-RepoRoot` | Find the git repository root |
| `Confirm-DevMode` / `Setup-DevMode` | Check / enable Windows Developer Mode |
| `test-build` | Incremental build benchmarks |
| `Open-LastBinLog` | Open the last `.binlog` in a viewer |
| `Invoke-OnWindowsIfWsl` | Re-invoke a script on the Windows side from WSL |

```powershell
build
build -Configuration Release -Platform ARM64ec
dpb                          # reads BUILD_CUSTOM_PARAM01, Debug, x64
dpb -Configuration Release
dpb -SkipBuild               # redeploy last output
Get-BuildErrors
goerror                      # first error
goerror -first 2 -skip 1     # 2nd and 3rd
ef src\foo.cpp 42
```

## Never pipe build output through `Out-String`

**Do not pipe `build`, `dpb` or any PwrDev build command through `| Out-String`
or `2>&1 | Out-String`.** These use MSBuild's terminal logger (`-tl`), which
writes live output straight to the terminal; piping breaks it.

```powershell
# CORRECT
build
dpb -Configuration Release

# WRONG - breaks terminal logger output
build 2>&1 | Out-String
```

This is a deliberate exception to the general rule that tool output must be piped
through `Out-String` to be visible.

## Environment variables

```powershell
$env:BUILD_CUSTOM_PARAM01  = "TV"                          # package name token, {0}
$env:BUILD_DEFAULT_TARGET  = "Apps\{0}\{0}Package"
$env:BUILD_APPX_RECIPE     = ".\BuildResults\{0}-{1}\{2}Package\bin\{2}Package\{2}Package.build.appxrecipe"
                                                            # {0}=Configuration {1}=Platform {2}=package
```

A bare `dpb` equals:

```powershell
dpb -UserParam01 TV -Target "Apps\TV\TVPackage" -Configuration Debug -Platform x64
```

## WSL behaviour

- `build` auto-detects C++ projects (`.vcxproj`) and re-invokes on Windows.
- `dpb` always runs on Windows, via `Invoke-OnWindowsIfWsl` internally.
- Symlink creation during builds needs Windows Developer Mode
  (`Confirm-DevMode`).

## `Edit-File.ps1` is sensitive

**Do not modify `Edit-File.ps1` without testing all three terminal contexts.
This file has broken multiple times.**

1. **Visual Studio terminal** (Claude Code inside VS) → must open in VS via DTE
2. **Claude Code with redirected stdin** (standalone, VS in background) → must
   open vim in a **new window**
3. **Plain terminal** (no VS) → must open vim inline

| Priority | Condition | Editor |
|---|---|---|
| 1 | `devenv` or `DevHub` in the ancestor process tree | VS DTE, running instance |
| 2 | stdin redirected (`[Console]::IsInputRedirected`) | `Start-Process vim.exe`, new window |
| 3 | `$env:TERM_PROGRAM -eq 'vscode'` | `code --goto file:line` |
| 4 | Other | `vim.exe` inline |

## Module source

Key files under `$mod.ModuleBase`: `Invoke-BuildTool.ps1` (`build`),
`Deploy-ProjectBuild.ps1` (`dpb`), `Get-BuildErrors.ps1`, `Edit-File.ps1`,
`Enter-VsShell.ps1`.

## Contributing

release-please with Conventional Commits; never commit to `main`. Branch slugs
like `feat/build-arm64`, `fix/vsshell-path`. See the `release-please-prs` skill
for the full title grammar and version-bump table.
