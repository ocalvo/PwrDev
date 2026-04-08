@echo off
:: Enables Windows Developer Mode so developers can create symlinks without admin.
:: Run this script once as Administrator.
where pwsh.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-DevMode.ps1" %*
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-DevMode.ps1" %*
)
