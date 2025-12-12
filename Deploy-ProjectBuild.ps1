[CmdLetBinding()]
param(
  $UserParam01 = $env:BUILD_CUSTOM_PARAM01,
  $Platform = "x64",
  $Config = "Debug",
  $Target = $env:BUILD_DEFAULT_TARGET,
  $AppxRecipe = $env:BUILD_APPX_RECIPE,
  [switch]$SkipDeploy,
  [switch]$SkipBuild,
  [switch]$Clean)

begin {
  $finalTarget = ($Target -f $UserParam01)
  Write-Verbose "Final Target: $finalTarget"
  $finalAppxRecipe = ($AppxRecipe -f $Config,$Platform,$UserParam01)
  Write-Verbose "Final Appx Recipe: $finalAppxRecipe"
  $errorCode = 0
}

process {
  if (-Not $SkipBuild) {
    Write-Verbose "Starting build for Target: $finalTarget, Platform: $Platform, Config: $Config"
    build -Target $finalTarget -Platform $Platform -Config $Config -Clean:$Clean
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
  }
}

end {
  Exit $errorCode
}

