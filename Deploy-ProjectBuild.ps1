[CmdLetBinding()]
param(
  $UserParam01 = $env:BUILD_CUSTOM_PARAM01,
  [Parameter()]
  [string]$Target = $env:BUILD_DEFAULT_TARGET,
  [Parameter()]
  [hashtable]$Properties = @{},
  [Parameter()]
  [ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      'Release','Debug' | Where-Object { $_ -like "$wordToComplete*" }
    })]
  [string]$Configuration = "Debug",
  [Parameter()]
  [ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      'ARM64ec','x64','x86','ARM64','AnyCPU' | Where-Object { $_ -like "$wordToComplete*" }
    })]
  [string]$Platform = 'x64',
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
  [string]$AppxRecipe = $env:BUILD_APPX_RECIPE,
  [switch]$SkipDeploy,
  [switch]$SkipBuild,
  [switch]$Clean)

begin {
  $finalTarget = ($Target -f $UserParam01)
  Write-Verbose "Final Target: $finalTarget"
  $PlatForRecipe = $Platform
  if ($Platform.StartsWith("ARM64")) {
    $PlatForRecipe = "ARM64"
  }
  $finalAppxRecipe = ($AppxRecipe -f $Configuration, $PlatForRecipe, $UserParam01)
  Write-Verbose "Final Appx Recipe: $finalAppxRecipe"
  $errorCode = 0
}

process {
  if (-Not $SkipBuild) {
    Write-Verbose "Starting build for Target: $finalTarget, Platform: $Platform, Config: $Config"
    build -Target $finalTarget -Platform $Platform -Configuration $Configuration -Verbosity $Verbosity -ConsoleVerbosity $ConsoleVerbosity -Clean:$Clean
    $errorCode = $LASTEXITCODE
    Write-Verbose "Build completed with error code: $errorCode"
  } else {
    Write-Verbose "Skipping build as per user request."
    $errorCode = 0
  }
  if (-Not $SkipDeploy -and $errorCode -eq 0) {
    Write-Verbose "Starting deployment using Appx Recipe: $finalAppxRecipe"
    DeployAppRecipe $finalAppxRecipe
    $errorCode = $LASTEXITCODE
    Write-Verbose "Deployment completed with error code: $errorCode"
    if ($errorCode -ne 0)
    {
      Write-Error "Deployment failed with error code: $errorCode"
    }
  }
}

end {
  Exit $errorCode
}

