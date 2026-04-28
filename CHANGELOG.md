# Changelog — PwrDev

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0](https://github.com/ocalvo/PwrDev/compare/v1.0.53...v1.1.0) (2026-04-28)


### Features

* **build:** add Invoke-GradleBuild and extract Invoke-MsBuild dispatcher ([cbd2ab2](https://github.com/ocalvo/PwrDev/commit/cbd2ab22d9496738565fa40b85b6c1ef411483ad))
* **build:** add Invoke-GradleBuild and extract Invoke-MsBuild dispatcher ([dee51e3](https://github.com/ocalvo/PwrDev/commit/dee51e3f5156e16a2c317709703646c1c6246b79))
* **build:** rich BuildDiagnostic objects from Get-BuildErrors, Gradle log capture ([1522d98](https://github.com/ocalvo/PwrDev/commit/1522d9808f095347eceba4d9f61a515bbb541624))


### Bug Fixes

* **build:** capture Gradle logs to .vs folder, use Get-RepoRoot.ps1 ([0df5b4f](https://github.com/ocalvo/PwrDev/commit/0df5b4f5af9facc0b4eac99e270a07b6c31d20a5))

## [1.0.53](https://github.com/ocalvo/PwrDev/compare/v1.0.52...v1.0.53) (2026-04-27)


### Bug Fixes

* **ef:** pipe Get-Command vim through Select-Object -First 1 ([c6fe0c2](https://github.com/ocalvo/PwrDev/commit/c6fe0c2209c46d96b7cf23d34ab3bb123e9008ea))
* **ef:** pipe Get-Command vim through Select-Object -First 1 ([04a6a50](https://github.com/ocalvo/PwrDev/commit/04a6a50f908d6f27a549dafbe72b55a3459a5105))

## [1.0.52](https://github.com/ocalvo/PwrDev/compare/v1.0.51...v1.0.52) (2026-04-22)


### Bug Fixes

* **ef:** find vim in known install paths when not on PATH ([#15](https://github.com/ocalvo/PwrDev/issues/15)) ([2615dcf](https://github.com/ocalvo/PwrDev/commit/2615dcf704c59a8ab96a520d2f796aa8794881b3))

## [1.0.51](https://github.com/ocalvo/PwrDev/compare/v1.0.50...v1.0.51) (2026-04-15)


### Bug Fixes

* **Edit-File:** detect devenv ancestor for VS terminal, add sensitive marker ([#13](https://github.com/ocalvo/PwrDev/issues/13)) ([d4bef0d](https://github.com/ocalvo/PwrDev/commit/d4bef0d138f76fd11462696096f648afae5095b3))

## [1.0.50](https://github.com/ocalvo/PwrDev/compare/v1.0.49...v1.0.50) (2026-04-15)


### Bug Fixes

* **ci:** harden publish job with tag checkout, API key guard, and manifest validation ([5d941db](https://github.com/ocalvo/PwrDev/commit/5d941dbeb21d53734524e2a9ef32f34552ac63df))
* **ci:** harden publish job with tag checkout, API key guard, and manifest validation ([65a0d51](https://github.com/ocalvo/PwrDev/commit/65a0d5194ff7c3a1913a10c2625e49710b398d1f))
* **module:** export missing aliases and remove stale function references ([9f35657](https://github.com/ocalvo/PwrDev/commit/9f356577b5adaaf8c569456a0ce1e6ce1c090161))

## [1.0.49](https://github.com/ocalvo/PwrDev/compare/v1.0.48...v1.0.49) (2026-04-15)


### Bug Fixes

* remove internal company path references from Setup-DevMode.ps1 ([8f79e44](https://github.com/ocalvo/PwrDev/commit/8f79e44a0a940360fc48be221beec717c7a53237))
* remove internal company path references from Setup-DevMode.ps1 ([e17a295](https://github.com/ocalvo/PwrDev/commit/e17a2959521ac904f3ccb5c545c0bdb84f8b4760))

## [1.0.23] - 2026-04-11

### Changed
- Renamed `build.ps1` to `Invoke-BuildTool.ps1` in preparation for supporting additional build systems (clang, xcode, gcc, make, nmake, etc.); `build` alias unchanged

## [1.0.20] - 2026-04-11

### Added
- `Get-RepoRoot` — walks up the directory tree to find the git repository root
- `Open-LastBinLog` — opens the last build `.binlog` in the associated viewer
- `Confirm-DevMode` / `Setup-DevMode` — check and enable Windows Developer Mode (required for symlink creation during builds)
- `test-build` alias for `Test-Build.ps1` — incremental build benchmarking

### Changed
- `Edit-File` now detects Claude Code terminal context and opens vim.exe in a new window (since Claude Code owns the terminal)
- Build log output now generates `.binlog`, `.err`, and `.wrn` files in a structured path under `.vs/`

## [1.0.10] - 2025-08-01

### Added
- `Invoke-OnWindowsIfWsl` — transparently re-invokes the calling script on the Windows side when running inside WSL; used automatically by `build` (C++ projects) and `dpb` (always)
- `Enter-VsShell` searches Enterprise → Professional → Community across VS 2022 and 2019; falls back to `dotnet msbuild` on Linux/macOS

### Changed
- `build` auto-sets Platform from processor architecture; switches to Windows-side invocation when a `.vcxproj` is detected in WSL

## [1.0.3] - 2024-01-01

### Added
- `dpb` / `Deploy-ProjectBuild` — build and sideload appx packages; uses `BUILD_CUSTOM_PARAM01`, `BUILD_DEFAULT_TARGET`, and `BUILD_APPX_RECIPE` environment variable templates
- `-SkipBuild`, `-SkipDeploy`, `-Clean` flags on `Deploy-ProjectBuild`

### Changed
- `build` now generates a symbolic link for the packages directory when running on Windows

## [0.0.2] - 2022-08-11

### Fixed
- Minor fix for VS Code editor integration

## [0.0.1] - 2022-08-11

### Added
- Initial release
- `build` alias — MSBuild wrapper with solution/project auto-detection
- `goerror` / `Get-BuildErrors` / `Edit-BuildErrors` — parse `.err`/`.wrn` log files and open errors in editor
- `Enter-VsShell` — Visual Studio developer shell initialization
- `Edit-File` — terminal-aware file editor (VS, VS Code, vim)
