
function global:Get-BuildErrors()
{
  $buildErrorsDir = ".\"
  if ($null -ne $global:lastBuildDir) { $buildErrorsDir = $global:lastBuildDir }

  $buildErrorsFile = ($buildErrorsDir + "\build" + $env:_BuildType + ".err")
  if (!(Test-Path $buildErrorsFile))
  {
    return;
  }
  Get-Content $buildErrorsFile | where-object { $_ -like "*(*)*: error *" } |ForEach-Object {
    $fileStart = $_.IndexOf(">")
    $fileEnd = $_.IndexOf("(")
    $fileName = $_.SubString($fileStart + 1, $fileEnd - $fileStart - 1)
    $lineNumberEnd =  $_.IndexOf(")")
    $lineNumber = $_.SubString($fileEnd + 1, $lineNumberEnd - $fileEnd - 1)
    $errorStart = $_.IndexOf(": ");
    $errorDescription = $_.SubString($errorStart + 2);
    $columnNumberStart= $lineNumber.IndexOf(",")
    if (-1 -ne $columnNumberStart)
    {
      $lineNumber = $lineNumber.substring(0, $columnNumberStart)
    }
    [System.Tuple]::Create($fileName,$lineNumber,$errorDescription)
  }
}
Export-ModuleMember -Function Get-BuildErrors

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

