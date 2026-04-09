[CmdLetBinding()]
param()

if (Test-Path env:lastBuildLog) {
  $lastBinlog = Get-Item "$($env:lastBuildLog).binlog" -ErrorAction SilentlyContinue
} else {
  $vsDir = Join-Path (Get-RepoRoot) '.vs'
  $lastBinlog = Get-ChildItem (Join-Path $vsDir 'build.*.binlog') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime |
    Select-Object -Last 1
}

if ($null -eq $lastBinlog) {
  Write-Error "No binlog files found. Run a build first."
  return
}

Write-Host "Opening: $($lastBinlog.FullName)"
Invoke-Item $lastBinlog.FullName
