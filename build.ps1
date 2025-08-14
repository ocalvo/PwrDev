[CmdLetBinding()]
param(
  [switch]$restore,
  [switch]$clean,
  [switch]$noBuild,
  $id = "",
  $baseResultDir = "$env:NUGET_PACKAGES\msblogs",
  $sln = "auto",
  $target = "Build",
  [hashtable]$Properties = @{},
  $Configuration="Debug",
  $Platform="x64"
)

if (-Not (Test-Path $baseResultDir)) {
  mkdir $baseResultDir | Out-Null
}

# Build the /p: arguments
$msbuildProps = $Properties.GetEnumerator() | ForEach-Object {
  "/p:$($_.Key)=$($_.Value)"
}
$msbuildPropsArgs = "$($msbuildProps -join ' ')"

function Do-Build {
  param ($dir)

  if ("auto" -eq $sln) {
    $slnItem = Get-ChildItem "$dir\*.sln" | Select-Object -First 1
    if ($null -eq $slnItem) {
      Write-Error "Solution not found in $dir"
      return
    }
    $sln = $slnItem.Name
  }

  if (-Not (Test-Path "$dir\$sln")) {
     Write-Error "Project $dir\$sln not found"
     return
  }

  $slnItem = get-item "$dir\$sln"
  $projName = $slnItem.BaseName

  pushd $dir
  try {
    Write-Verbose "Begin build for $projName"
    $time = [datetime]::Now.ToString("yy.dd.MM-HH.mm.ss")
    if ("" -eq $id) {
      $br = git branch --show-current
      $br = ($br -split '/') | Select-Object -Last 1
    } else {
      $br = $id
    }
    $resultDir = "$baseResultDir"
    MkDir $resultDir -ErrorAction Ignore | Out-Null
    $tN = ($target -split '\\') | Select-Object -Last 1
    $tN = $tN.Replace(":",".")
    $suffixName = "$time.$projName.$tN.$br.$Configuration"
    $logFileRestoreBL = "$resultDir\restore.$suffixName.binlog"
    $logFileBuildBL = "$resultDir\build.$suffixName.binlog"
    $logFileName = "$resultDir\build.$suffixName"
    $logErrFileName = "$logFileName.err"
    Write-Verbose "ErrFileName: $logErrFileName"
    $logWrnFileName = "$logFileName.wrn"
    Write-Verbose "WrnFileName: $logWrnFileName"
    $logDurationFile = "$resultDir\build.$suffixName.txt"
    ps msbuild* | kill
    ps cl* | kill

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
      msbuild.exe $sln '/t:Restore' '/p:RestorePackagesConfig=true' "/bl:LogFile=$logFileRestoreBL" '/v:d' '-tl' "/p:Platform=$Platform" "/p:Configuration=$Configuration" /m $msbuildPropsArgs
    }

    if ($noBuild) {
      Write-Verbose "No build, nothing else todo"
      return
    }

    Write-Verbose "LogFile:$logFileBuildBL"
    $start = [DateTime]::Now
    msbuild.exe $sln "/p:Configuration=$Configuration" "/p:Platform=$Platform" "/p:AppxBundlePlatforms=$Platform" "/p:AppxBundle=Always" "/t:$target" $msbuildPropsArgs "/bl:LogFile=$LogFileBuildBL" /m /v:d -tl "-flp2:LogFile=$logErrFileName;errorsonly" "-flp3:LogFile=$logWrnFileName;warningsonly"
    $errorLevel = $LASTEXITCODE
    $end = [DateTime]::Now
    $duration = $end - $start
    $durationStr = $duration.ToString("hh\:mm\:ss\.fff")
    Write-Verbose "Duration:$durationStr"
    Set-Content -Value $durationStr -Path $logDurationFile
    Get-Content $logErrFileName | Write-Host
    Write-Host $logFileBuildBL
    Write-Verbose "End build for $dir"
    #if (0 -eq $errorLevel) {
    #  return $duration
    #}
  } finally {
    popd
  }
}

Enter-VsShell -vsVersion Professional

Do-Build (pwd).Path

