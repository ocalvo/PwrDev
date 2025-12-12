
set-alias Get-BuildErrors $PSScriptRoot\Get-BuildErrors.ps1 -scope global
Export-ModuleMember -Alias Get-BuildErrors

function global:Open-Editor($fileName,$lineNumber)
{
  if ("vscode" -eq $env:TERM_PROGRAM)
  {
    $codeParam = ($fileName+":"+$lineNumber)
    code --goto $codeParam
    return
  }

  $vimPath = (get-command vim.exe -ErrorAction Ignore)
  if ($null -ne $vimPath)
  {
    .$vimPath -y $fileName ("+"+$lineNumber)
    return
  }

  if ($null -ne $env:SDEDITOR)
  {
    .$env:SDEDITOR $fileName
    return
  }

  Write-Warning "No editor found, falling back to notepad"
  .notepad $fileName
}
Export-ModuleMember -Function Open-Editor

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
  Get-BuildErrors | Select-Object -First $first -Skip $skip |ForEach-Object { Open-Editor $_.Item1 $_.Item2 }
}
Export-ModuleMember -Function Edit-BuildErrors

set-alias goerror Edit-BuildErrors -scope global
Export-ModuleMember -Alias goerror

set-alias Enter-VsShell $PSScriptRoot\Enter-VsShell.ps1 -scope global
Export-ModuleMember -Alias Enter-VsShell

set-alias build $PSScriptRoot\Build.ps1 -scope global
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

