[CmdLetBinding()]
param(
  [switch]$restore,
  [switch]$clean,
  [switch]$noBuild,
  [switch]$noParallel,
  [switch]$rawOutput,
  $Id = "",
  $baseResultDir = "$env:NUGET_PACKAGES\msblogs",
  $Project = "auto",
  $Target = "Build",
  [hashtable]$Properties = @{},
  $Configuration="Debug",
  $Platform="x64",
  $Verbosity="d"
)

if (-Not (Test-Path $baseResultDir)) {
  mkdir $baseResultDir | Out-Null
}

$msBuildArgs = @()
if (-Not $noParallel) {
  $msbuildArgs += "/m"
}
if (-Not $rawOutput) {
  $msbuildArgs += "/tl"
}
# Build the /p: arguments
$msBuildArgs += $Properties.GetEnumerator() | ForEach-Object {
  $key = $_.Key
  $value = $_.Value
  Write-Verbose "Setting property: $key -> $value"
  "/p:$Key=$Value"
}

function Write-Url {
  param(
    $message,
    $file)

  $esc = "`e"  # PowerShell escape for ASCII 27
  $sequence = "${esc}]8;;$file`a$message${esc}]8;;`a"
  Write-Host $sequence
}

function Do-Build {
  param ($dir)

  if ("auto" -eq $Project) {
    $projectItem = Get-ChildItem "$dir\*.sln" | Select-Object -First 1
    if ($null -eq $projectItem) {
      Write-Error "Solution not found in $dir"
      return
    }
  } else {
    $projectItem = Get-Item $Project
  }

  pushd $dir
  try {
    Write-Verbose "Begin build for $projName"
    $time = [datetime]::Now.ToString("yy.dd.MM-HH.mm.ss")
    $br = git branch --show-current
    $br = ($br -split '/') | Select-Object -Last 1
    if ("" -ne $id) {
      $br += ".$id"
    }
    $projName = $projectItem.BaseName
    $resultDir = "$baseResultDir"
    MkDir $resultDir -ErrorAction Ignore | Out-Null
    $tN = ($target -split '\\') | Select-Object -Last 1
    $tN = $tN.Replace(":",".")
    $suffixName = "$time.$projName.$tN.$br.$Configuration"
    $env:lastBuildLog = "$resultDir\build.$suffixName"
    $logFileRestoreBL = "$resultDir\restore.$suffixName.binlog"
    $logFileBuildBL = "$resultDir\build.$suffixName.binlog"
    $logFileName = "$resultDir\build.$suffixName"
    $logErrFileName = "$logFileName.err"
    Write-Verbose "ErrFileName: $logErrFileName"
    $logWrnFileName = "$logFileName.wrn"
    Write-Verbose "WrnFileName: $logWrnFileName"
    $logDurationFile = "$resultDir\build.$suffixName.txt"
    $logExitLevelFile = "$resultDir\build.$suffixName.exitcode"

    if ($clean) {
      git clean -dfx .
    }

    $packagesDir = "$dir\packages"
    Write-Verbose "SymLink $packagesDir -> ${env:NUGET_PACKAGES}"
    if (Test-Path $packagesDir) {
      $isSymLink = (Get-Item $packagesDir).Attributes -band [System.IO.FileAttributes]::ReparsePoint
      if ([System.IO.FileAttributes]::ReparsePoint -ne $isSymLink) {
        Remove-Item $packagesDir -Rec -Force
      }
    }
    New-Item $packagesDir -ItemType SymbolicLink -Target $env:NUGET_PACKAGES -Force | Out-Null

    if ($restore -or $clean) {
      Write-Verbose "Restore LogFile:$logFileRestoreBL"
      msbuild.exe $projectItem.FullName '/t:Restore' '/p:RestorePackagesConfig=true' "/bl:LogFile=$logFileRestoreBL" "/v:$Verbosity" "/p:Platform=$Platform" "/p:Configuration=$Configuration" @msBuildArgs
    }

    if ($noBuild) {
      Write-Verbose "No build, nothing else todo"
      return
    }

    Write-Verbose "LogFile:$logFileBuildBL"
    $start = [DateTime]::Now
    msbuild.exe $projectItem.FullName "/p:Configuration=$Configuration" "/p:Platform=$Platform" "/t:$target" "/bl:LogFile=$LogFileBuildBL" "/v:$Verbosity" "-flp2:LogFile=$logErrFileName;errorsonly" "-flp3:LogFile=$logWrnFileName;warningsonly" @msbuildArgs
    $errorLevel = $LASTEXITCODE
    $end = [DateTime]::Now
    $duration = $end - $start
    $durationStr = $duration.ToString("hh\:mm\:ss\.fff")
    Write-Verbose "Duration:$durationStr"
    Set-Content -Value $durationStr -Path $logDurationFile
    Set-Content -Value $errorLevel -Path $logExitLevelFile
    Get-Content $logErrFileName | Write-Host
    Write-Url -Message "binlog" -File $logFileBuildBL
    Write-Verbose "End build for $dir"
  } finally {
    popd
  }
}

Enter-VsShell -vsVersion Professional

Do-Build (pwd).Path

