[CmdLetBinding()]
param(
  [switch]$NoRestore,
  [switch]$clean,
  [switch]$noBuild,
  [switch]$noParallel,
  [switch]$rawOutput,
  [switch]$noConsoleLoger,
  [switch]$enableAutoResponse,
  $Id = "",
  $NUGET_PACKAGES = $env:NUGET_PACKAGES,
  $baseResultDir = "$NUGET_PACKAGES/msblogs",
  $Project = "auto",
  $Target,
  [hashtable]$Properties = @{},
  $Configuration,
  $Platform,
  $ConsoleVerbosity = "m",
  $Verbosity="diag",
  $ConsoleLoggerParameters = "Verbosity=${ConsoleVerbosity}"
)

begin {
  Write-Verbose "Begin"

  Enter-VsShell | Write-Verbose

  $script:errorLevel = 0

  if (-Not (Test-Path $baseResultDir)) {
    New-Item $baseResultDir -ItemType Directory | Out-Null
  }

  $script:msBuildArgs = @()

  if (-Not $noParallel) {
    Write-Verbose "Running in parallel"
    $msbuildArgs += "/m"
  }
  if (-Not $rawOutput) {
    Write-Verbose "Using new terminal output"
    $msbuildArgs += "/tl"
  }
  if (-Not $enableAutoResponse) {
    Write-Verbose "Not using auto response files"
    $msbuildArgs += "-noautoresponse"
  }
  if ($noConsoleLogger) {
    Write-Verbose "Disabling console logger"
    $msbuildArgs += "-noconsolelogger"
  }
  if ("" -ne $ConsoleLoggerParameters) {
    Write-Verbose "Settings console logging parameters:$ConsoleLoggerParameters"
    $msbuildArgs += "-clp:$ConsoleLoggerParameters"
  }
  if ($null -ne $Target) {
    Write-Verbose "Build target:$Target"
    $msbuildArgs += "/t:$Target"
  }

  # Build the /p: arguments
  $msBuildArgs += $Properties.GetEnumerator() | ForEach-Object {
    $key = $_.Key
    $value = $_.Value
    Write-Verbose "Setting property: $key -> $value"
    "/p:$Key=$Value"
  }

  if ($null -ne $Platform) {
    Write-Verbose "Setting platform:$Platform"
    $msBuildArgs += "/p:Platform=$Platform"
  }

  if ($null -ne $Configuration) {
    Write-Verbose "Setting config:$Platform"
    $msBuildArgs += "/p:Configuration=$Configuration"
  }

  if ((-Not $NoRestore)) {
    Write-Verbose "Setting restore flag"
    $msBuildArgs += "-restore"
  }

  $bPath = (pwd).Path
  $dir = $bPath

  if ("auto" -eq $Project) {
    Write-Verbose ("Looking for project in directory:{0}" -f $dir)
    $projectItem = Get-ChildItem -File ("${dir}/*.sln*","${dir}/*.*proj") | Select-Object -First 1
    if ($null -eq $projectItem) {
      Write-Error "Project not found in $dir"
      $script:errorLevel = 404
      return
    }
  } else {
    $projectItem = Get-Item $Project
  }

  $script:errorLevel = 0
}

process {

  function Get-GlobalPackagesFolder {
    param($dir)
    if (Test-Path "$dir/NuGet.config") {
      $nugetGConfig = [xml](Get-Content "$dir/NuGet.config")
      $nugetConfig = $nugetGConfig.configuration.config.add
      if ($null -ne $nugetConfig) {
        return $nugetConfig.GetEnumerator() | where { $_.key -eq "globalPackagesFolder" } | select -ExpandProperty value
      }
    }
    return $null
  }

  if (0 -ne $script:errorLevel) {
    Write-Verbose ("Already failed with error code {0}" -f $script:errorLevel)
    return
  }

  Write-Verbose ("Building project:{0}" -f $projectItem.FullName)

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
  $suffixName = (($time,$projName,$tN,$br,$Configuration,$Platform) | where { $_ }) -join '.'
  $env:lastBuildLog = "$resultDir\build.$suffixName"
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
    $script:errorLevel = $LASTEXITCODE
    if (0 -ne $script:errorLevel) {
      Write-Error "Cannot clean, error code ${script:errorLevel}"
      return
    }
  }

  $hasCppPackages = $false
  if ($projectItem.Extension.StartsWith(".sln")) {
    $firstConfigFile = Get-ChildItem packages.config -Path $dir -File -Recurse -Depth 4 -FollowSymlink:$false | Select-Object -First 1
    $hasCppPackages = $null -ne $firstConfigFile
    if ($hasCppPackages) {
      $packagesDir = "$dir/packages"
    } else {
      $packagesDir = Get-GlobalPackagesFolder -dir $dir
    }
    if (($null -ne $packagesDir) -and (Test-Path env:NUGET_PACKAGES)) {
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

  if ($hasCppPackages) {
    $script:msBuildArgs += "/p:RestorePackagesConfig=true"
  }

  Write-Verbose ("MSBuild params:{0}" -f ($script:msBuildArgs -join ' '))

  if ($noBuild) {
    Write-Host "No build, nothing else todo"
  }

  Write-Verbose "LogFile:$logFileBuildBL"
  $script:start = [DateTime]::Now
  msbuild $projectItem.FullName "-bl:LogFile=$LogFileBuildBL" "-flp:Logfile=$LogTxtFileName;Verbosity=$Verbosity" "-flp2:LogFile=$logErrFileName;errorsonly" "-flp3:LogFile=$logWrnFileName;warningsonly" "/v:$Verbosity" @msbuildArgs
  $script:errorLevel = $LASTEXITCODE
  $script:end = [DateTime]::Now
}

end {
  Write-Verbose "End"

  function Write-Url {
    param(
      $message,
      $file)

    $esc = "`e"  # PowerShell escape for ASCII 27
    $sequence = "${esc}]8;;$file`a$message${esc}]8;;`a"
    Write-Host $sequence
  }

  if ($null -ne $script:end -and $null -ne $script:start) {
    $duration = $script:end - $script:start
    $durationStr = $duration.ToString("hh\:mm\:ss\.fff")
    Write-Verbose "Duration:$durationStr"
    Set-Content -Value $durationStr -Path $logDurationFile
  }

  if ($null -ne $logExitLevelFile) {
    Set-Content -Value $errorLevel -Path $logExitLevelFile
  }

  if (($null -ne $logErrFileName) -and (Test-Path $logErrFileName)) {
    Get-Content $logErrFileName | Write-Host
  }
  if (($null -ne $logFileBuildBL) -and (Test-Path $logFileBuildBL)) {
    Write-Url -Message "$logFileBuildBL" -File $logFileBuildBL
  }
  Write-Verbose "End build for $dir"

  Write-Verbose ("Exiting with error level {0}" -f $script:errorlevel)
  Exit $script:errorlevel
}


