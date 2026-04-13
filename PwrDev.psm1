
set-alias Get-RepoRoot $PSScriptRoot\Get-RepoRoot.ps1 -scope global
Export-ModuleMember -Alias Get-RepoRoot

. $PSScriptRoot\Invoke-OnWindowsIfWsl.ps1
Export-ModuleMember -Function Invoke-OnWindowsIfWsl

set-alias Get-BuildErrors $PSScriptRoot\Get-BuildErrors.ps1 -scope global
Export-ModuleMember -Alias Get-BuildErrors

set-alias Open-LastBinLog $PSScriptRoot\Open-LastBinLog.ps1 -scope global
Export-ModuleMember -Alias Open-LastBinLog

if ("Core" -eq $PSEdition) {
  $env:__PSShell = "pwsh.exe"
  $env:__PSShellDir = "PowerShell"
}
else {
  $env:__PSShell = "powershell.exe"
  $env:__PSShellDir = "WindowsPowerShell"
}

function global:Edit-BuildErrors($first=1,$skip=0)
{
  Get-BuildErrors | Select-Object -First $first -Skip $skip |ForEach-Object { Edit-File $_.File $_.LineNumber }
}
Export-ModuleMember -Function Edit-BuildErrors

set-alias goerror Edit-BuildErrors -scope global
Export-ModuleMember -Alias goerror

set-alias Enter-VsShell $PSScriptRoot\Enter-VsShell.ps1 -scope global
Export-ModuleMember -Alias Enter-VsShell

set-alias build $PSScriptRoot\Invoke-BuildTool.ps1 -scope global
Export-ModuleMember -Alias build

set-alias test-build $PSScriptRoot\Test-Build.ps1 -scope global
Export-ModuleMember -Alias test-build

$global:_pwrdev_aliases = (
  'devenv',
  'msbuild',
  'deployapprecipe'
)

$global:_pwrdev_aliases |ForEach-Object {
  $aliasName = $_
  set-alias $aliasName $PSScriptRoot\Execute-DevEnv.ps1 -scope global
  Export-ModuleMember -Alias $aliasName
}

set-alias Deploy-ProjectBuild $PSScriptRoot\Deploy-ProjectBuild.ps1 -scope global
Export-ModuleMember -Alias Deploy-ProjectBuild
set-alias dpb Deploy-ProjectBuild -scope global
Export-ModuleMember -Alias dpb

set-alias Confirm-DevMode $PSScriptRoot\Confirm-DevMode.ps1 -scope global
Export-ModuleMember -Alias Confirm-DevMode

set-alias Setup-DevMode $PSScriptRoot\Setup-DevMode.ps1 -scope global
Export-ModuleMember -Alias Setup-DevMode

set-alias Edit-File $PSScriptRoot\Edit-File.ps1 -scope global
Export-ModuleMember -Alias Edit-File
set-alias ef Edit-File -scope global
Export-ModuleMember -Alias ef
