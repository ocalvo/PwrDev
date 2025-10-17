[CmdLetBinding()]
param(
  [switch]$restore,
  [switch]$clean,
  [switch]$noBuild,
  [switch]$noParallel,
  [switch]$rawOutput,
  [switch]$noConsoleLoger,
  [switch]$enableAutoResponse,
  $Id = "",
  $NUGET_PACKAGES = (Test-Path env:NUGET_PACKAGES) ? $env:NUGET_PACKAGES : "~/.nuget",
  $baseResultDir = "$NUGET_PACKAGES/msblogs",
  $Project = "auto",
  $Target = "Build",
  [hashtable]$Properties = @{},
  $Configuration="Debug",
  $Platform="x64",
  $ConsoleVerbosity = "m",
  $Verbosity="diag",
  $ConsoleLoggerParameters = "Verbosity=${ConsoleVerbosity}"
)

$script:errorLevel = 0

if (-Not (Test-Path $baseResultDir)) {
  New-Item $baseResultDir -ItemType Directory | Out-Null
}

$msBuildArgs = @()
if (-Not $noParallel) {
  $msbuildArgs += "/m"
}
if (-Not $rawOutput) {
  $msbuildArgs += "/tl"
}
if (-Not $enableAutoResponse) {
  $msbuildArgs += "-noautoresponse"
}
if ($noConsoleLogger) {
  $msbuildArgs += "-noconsolelogger"
}
if ("" -ne $ConsoleLoggerParameters) {
  $msbuildArgs += "-clp:$ConsoleLoggerParameters"
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
    Write-Verbose ("Looking for project in directory:{0}" -f $dir)
    $projectItem = Get-ChildItem -File ("${dir}/*.sln","${dir}/*.*proj") | Select-Object -First 1
    if ($null -eq $projectItem) {
      Write-Error "Project not found in $dir"
      return 404
    }
  } else {
    $projectItem = Get-Item $Project
  }

  pushd $dir
  $script:errorLevel = 0
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
    New-Item $resultDir -ItemType Directory -ErrorAction Ignore | Out-Null
    $tN = ($target -split '\\') | Select-Object -Last 1
    $tN = $tN.Replace(":",".")
    $suffixName = "$time.$projName.$tN.$br.$Configuration.$Platform"
    $env:lastBuildLog = "$resultDir\build.$suffixName"
    $logFileRestoreBL = "$resultDir\restore.$suffixName.binlog"
    $logFileBuildBL = "$resultDir\build.$suffixName.binlog"
    $logFileName = "$resultDir\build.$suffixName"
    $logErrFileName = "$logFileName.err"
    $logTxtFileName = "$resultDir\build.$suffixName.log"
    Write-Verbose "ErrFileName: $logErrFileName"
    $logWrnFileName = "$logFileName.wrn"
    Write-Verbose "WrnFileName: $logWrnFileName"
    $logDurationFile = "$resultDir\build.$suffixName.txt"
    $logExitLevelFile = "$resultDir\build.$suffixName.exitcode"

    if ($clean) {
      git clean -dfx .
    }

    if ($projectItem.Extension -eq ".sln") {
      $firstConfigFile = Get-ChildItem packages.config -Path $dir -File -Recurse -Depth 4 -FollowSymlink:$false | Select-Object -First 1
      $hasCppPackages = $null -ne $firstConfigFile
      if ($hasCppPackages) {
        $packagesDir = "$dir/packages"
        Write-Verbose "SymLink $packagesDir -> ${NUGET_PACKAGES}"
        if (Test-Path $packagesDir) {
          $isSymLink = (Get-Item $packagesDir).Attributes -band [System.IO.FileAttributes]::ReparsePoint
          if ([System.IO.FileAttributes]::ReparsePoint -ne $isSymLink) {
            Remove-Item $packagesDir -Rec -Force
          }
        }
        New-Item $packagesDir -ItemType SymbolicLink -Target $NUGET_PACKAGES -Force | Out-Null
      }
    }

    if ($restore -or $clean) {
      Write-Verbose "Restore LogFile:$logFileRestoreBL"
      msbuild $projectItem.FullName '/t:Restore' '/p:RestorePackagesConfig=true' "/bl:LogFile=$logFileRestoreBL" "/v:$Verbosity" "/p:Platform=$Platform" "/p:Configuration=$Configuration" @msBuildArgs
      $script:errorLevel = $LASTEXITCODE
    }

    if ($noBuild) {
      Write-Host "No build, nothing else todo"
    }

    Write-Verbose "LogFile:$logFileBuildBL"
    $start = [DateTime]::Now
    msbuild $projectItem.FullName "/p:Configuration=$Configuration" "/p:Platform=$Platform" "/t:$target" "-bl:LogFile=$LogFileBuildBL" "-flp:Logfile=$LogTxtFileName;Verbosity=$Verbosity" "-flp2:LogFile=$logErrFileName;errorsonly" "-flp3:LogFile=$logWrnFileName;warningsonly" "/v:$Verbosity" @msbuildArgs
    $script:errorLevel = $LASTEXITCODE
    $end = [DateTime]::Now
    $duration = $end - $start
    $durationStr = $duration.ToString("hh\:mm\:ss\.fff")
    Write-Verbose "Duration:$durationStr"
    Set-Content -Value $durationStr -Path $logDurationFile
    Set-Content -Value $errorLevel -Path $logExitLevelFile
    if (Test-Path $logErrFileName) {
      Get-Content $logErrFileName | Write-Host
    }
    Write-Url -Message "$logFileBuildBL" -File $logFileBuildBL
    Write-Verbose "End build for $dir"
  } finally {
    popd
  }
}

Enter-VsShell | Write-Verbose

$bPath = (pwd).Path
Do-Build $bPath
Exit $script:errorlevel

