[CmdLetBinding()]
param(
  [switch]$IncludeWarnings
)

if (Test-Path env:lastBuildLog) {
  $baseLog = $env:lastBuildLog
} else {
  $vsDir = Join-Path (Get-RepoRoot) '.vs'
  $lastErr = Get-ChildItem (Join-Path $vsDir 'build.*.err') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime |
    Select-Object -Last 1
  if ($null -eq $lastErr) {
    if (Test-Path env:_BuildType) {
      $buildErrorsDir = if ($null -ne $global:lastBuildDir) { $global:lastBuildDir } else { ".\" }
      $baseLog = $buildErrorsDir + "\build" + $env:_BuildType
    } else {
      Write-Error "No build error files found. Run a build first."
      return
    }
  } else {
    $baseLog = [System.IO.Path]::Combine($lastErr.DirectoryName, [System.IO.Path]::GetFileNameWithoutExtension($lastErr.FullName))
  }
}

$errFile = "$baseLog.err"
$wrnFile = "$baseLog.wrn"

if (!(Test-Path $errFile)) {
  Write-Verbose "Build error file not found: $errFile"
  return
}

Write-Verbose "Errors from: $errFile"
Get-Content $errFile | Where-Object { $_ -like "*(*)*: error *" } | ForEach-Object {
  $fileStart = $_.IndexOf(">")
  $fileEnd = $_.IndexOf("(")
  $fileName = $_.SubString($fileStart + 1, $fileEnd - $fileStart - 1)
  $lineNumberEnd = $_.IndexOf(")")
  $lineNumber = $_.SubString($fileEnd + 1, $lineNumberEnd - $fileEnd - 1)
  $errorStart = $_.IndexOf(": ")
  $errorDescription = $_.SubString($errorStart + 2)
  $columnNumberStart = $lineNumber.IndexOf(",")
  if (-1 -ne $columnNumberStart) {
    $lineNumber = $lineNumber.substring(0, $columnNumberStart)
  }
  $fileItem = Get-Item $fileName -ErrorAction SilentlyContinue
  return [PSCustomObject]@{
    File       = $fileItem
    LineNumber = $lineNumber
    Error      = $errorDescription
  }
}

if ($IncludeWarnings -and (Test-Path $wrnFile)) {
  Write-Host "Warnings from: $wrnFile"
  Get-Content $wrnFile
}
