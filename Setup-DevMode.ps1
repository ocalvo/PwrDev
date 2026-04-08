# Setup-DevMode.ps1
# Enables Windows Developer Mode so that developers can create symbolic links
# without requiring administrator privileges.
#
# Must be run once as Administrator:
#   pwsh.exe -NoProfile -ExecutionPolicy Bypass -File Setup-DevMode.ps1
# Or via the convenience wrapper:
#   iTunes\Scripts\setup-devmode.cmd

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host ""
    Write-Host "Re-launch from an elevated prompt, or run:"
    Write-Host "  iTunes\Scripts\setup-devmode.cmd"
    exit 1
}

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"

if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

$current = (Get-ItemProperty -Path $registryPath -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense

if ($current -eq 1) {
    Write-Host "Developer Mode is already enabled." -ForegroundColor Green
    exit 0
}

Set-ItemProperty -Path $registryPath -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
Write-Host "Developer Mode enabled." -ForegroundColor Green
Write-Host ""
Write-Host "Developers can now create symbolic links without administrator privileges."
Write-Host "No reboot required — takes effect immediately for new processes."
