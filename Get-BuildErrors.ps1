[CmdLetBinding()]
param()

if (Test-Path env:lastBuildLog) {
   $buildErrorsFile = ($env:lastBuildLog + ".err")
} else {
  $buildErrorsDir = ".\"
  if ($null -ne $global:lastBuildDir) { $buildErrorsDir = $global:lastBuildDir }
  $buildErrorsFile = ($buildErrorsDir + "\build" + $env:_BuildType + ".err")
}
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
  $fileItem = Get-Item $fileName
  $fileItem | Add-Member -MemberType NoteProperty -Name "LineNumber" -Value $lineNumber
  $fileItem | Add-Member -MemberType NoteProperty -Name "Error" -Value $errorDescription
  return [PSCustomObject]@{
    File = $fileItem
    LineNumber = $lineNumber
    Error = $errorDescription
  }
}