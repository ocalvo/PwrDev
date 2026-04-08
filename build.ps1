[CmdLetBinding()]
param(
  [switch]$NoRestore,
  [switch]$clean,
  [switch]$noBuild,
  [switch]$noParallel,
  [switch]$rawOutput,
  [switch]$noConsoleLoger,
  [switch]$enableAutoResponse,
  [string]$Id = "",
  $baseResultDir = (Join-Path ((Get-Location).Path) '.vs'),
  $Project = "auto",
  [string]$Target,
  [Parameter()]
  [hashtable]$Properties = @{},
  [Parameter()]
  [ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      'Release','Debug' | Where-Object { $_ -like "$wordToComplete*" }
    })]
  [string]$Configuration,
  [Parameter()]
  [ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      'ARM64ec','x64','x86','ARM64','AnyCPU' | Where-Object { $_ -like "$wordToComplete*" }
    })]
  [string]$Platform,
  [Parameter()]
  [ValidateSet('Quiet','Minimal','Normal','Detailed','Diagnostic')]
  [ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      'Quiet','Minimal','Normal','Detailed','Diagnostic' |
        Where-Object { $_ -like "$wordToComplete*" }
    })]  
  [string]$ConsoleVerbosity = "Minimal",
  [Parameter()]
  [ValidateSet('Quiet','Minimal','Normal','Detailed','Diagnostic')]
  [ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      'Quiet','Minimal','Normal','Detailed','Diagnostic' |
        Where-Object { $_ -like "$wordToComplete*" }
    })]  
  [string]$Verbosity='Diagnostic',
  [string]$ConsoleLoggerParameters = "Verbosity=${ConsoleVerbosity}"
)

begin {
  function Get-RepoRoot {
    param($marker = '.git')
    $repoRoot = Get-Item -Path . -Force | ForEach-Object {
      $d = $_.FullName
      while ($d -and -not (Test-Path (Join-Path $d $marker))) {
        $d = Split-Path $d -Parent
      }
      $d
    }
  }

  function Test-IsGitRepo { ($null -ne (Get-RepoRoot)) }

  function Test-SymLinks {
    $testDir = [System.IO.Path]::GetTempPath()
    $testLink = Join-Path $testDir "symlink-test-$PID"
    $testTarget = Join-Path $testDir "symlink-target-$PID"
    try {
      New-Item -ItemType Directory -Path $testTarget -Force | Out-Null
      New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop | Out-Null
      return $true
    } catch {
      return $false
    } finally {
      Remove-Item -LiteralPath $testLink -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $testTarget -Force -ErrorAction SilentlyContinue
    }
  }

  $script:canCreateSymLinks = Test-SymLinks
  Write-Verbose "SymLink support: $script:canCreateSymLinks"

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
  if ("" -ne $Target) {
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

  if (("" -eq $Platform) -and (Test-IsGitRepo)) {
    Write-Verbose "Setting platform:$Platform"
    $hasCpp = Get-ChildItem *.vcxproj -File -Recurse -Depth 3 | Select-Object -First 1
    if ($hasCpp) {
      $Platform = $hasCpp ? $env:PROCESSOR_ARCHITECTURE : "AnyCPU"
      if ($Platform -eq "AMD64") { $Platform = "X64" }
    }
  }
  if ("" -ne $Platform) {
    $msBuildArgs += "/p:Platform=$Platform"
    Write-Verbose "Platform:$Platform"
  }

  if ("" -ne $Configuration) {
    Write-Verbose "Setting config:$Configuration"
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
    $projectItem = Get-ChildItem -File (
      (Join-Path $dir '*.sln*'),
      (Join-Path $dir '*.*proj')) | Select-Object -First 1
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
    $nugetConfigPath = Join-Path $dir 'nuget.config'
    if (Test-Path $nugetConfigPath) {
      $nugetGConfig = [xml](Get-Content $nugetConfigPath)
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
  $env:lastBuildLog = Join-Path $resultDir "build.$suffixName"
  $logFileBuildBL = Join-Path $resultDir "build.$suffixName.binlog"
  $logFileName = Join-Path $resultDir "build.$suffixName"
  $logErrFileName = "$logFileName.err"
  $logTxtFileName = Join-Path $resultDir "build.$suffixName.log"
  Write-Verbose "ErrFileName: $logErrFileName"
  $logWrnFileName = "$logFileName.wrn"
  Write-Verbose "WrnFileName: $logWrnFileName"
  $logDurationFile = Join-Path $resultDir "build.$suffixName.txt"
  $logExitLevelFile = Join-Path $resultDir "build.$suffixName.exitcode"

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
      $packagesDir = Join-Path $dir 'packages'
    } else {
      $packagesDir = Get-GlobalPackagesFolder -dir $dir
    }
    if (($null -ne $packagesDir) -and (Test-Path env:NUGET_PACKAGES)) {
      $nugetPackagesTarget = $env:NUGET_PACKAGES
    } elseif ($null -ne $packagesDir) {
      $nugetPackagesTarget = "$env:USERPROFILE\.nuget\packages"
    }
    if ($null -ne $nugetPackagesTarget) {
      Write-Verbose "SymLink $packagesDir -> $nugetPackagesTarget"
      $existingItem = Get-Item -LiteralPath $packagesDir -Force -ErrorAction SilentlyContinue
      if ($null -ne $existingItem) {
        $isSymLink = $existingItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint
        if ([System.IO.FileAttributes]::ReparsePoint -ne $isSymLink) {
          # Real directory/file — remove it
          Remove-Item $packagesDir -Rec -Force
        } else {
          # Symlink (valid or broken) — remove so New-Item can replace it
          Remove-Item -LiteralPath $packagesDir -Force
        }
      }
      if ($script:canCreateSymLinks) {
        New-Item $packagesDir -ItemType SymbolicLink -Target $nugetPackagesTarget -Force | Out-Null
      } else {
        Write-Verbose "Skipping symlink for packages dir (symlinks not available on this machine)"
      }
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
  if ($script:errorLevel -ne 0)
  {
    Write-Error "Build failed with error code: $script:errorLevel"
  }

  Exit $script:errorlevel
}

