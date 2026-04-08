# Confirm-DevMode.ps1
# Check whether Windows Developer Mode is enabled.
# If $Require is passed as $true, throws an error when Developer Mode is off.

param([switch]$Require)

$script:devModeEnabled = $false

if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    $devModeKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $script:devModeEnabled = (Get-ItemProperty -Path $devModeKey -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1

    if (-not $script:devModeEnabled) {
        Write-Host ""
        Write-Host "WARNING: Windows Developer Mode is not enabled." -ForegroundColor Yellow
        Write-Host "Run the following once as Administrator to enable it:"
        Write-Host "  $PSScriptRoot\setup-devmode.cmd" -ForegroundColor Cyan
        Write-Host ""
        if ($Require) {
            throw "Windows Developer Mode is required. Run $PSScriptRoot\setup-devmode.cmd as Administrator, then retry."
        }
    }
} else {
    $script:devModeEnabled = $true
}
