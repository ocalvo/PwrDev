# Changelog — PwrDev

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
