[CmdLetBinding()]
param(
  # MSBuild params — passed through to Invoke-MsBuild.ps1
  [switch]$NoRestore,
  [switch]$clean,
  [switch]$noBuild,
  [switch]$noParallel,
  [switch]$rawOutput,
  [switch]$noConsoleLoger,
  [switch]$enableAutoResponse,
  [string]$Id = "",
  $baseResultDir = $null,
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
  [string]$Verbosity = 'Diagnostic',
  [string]$ConsoleLoggerParameters = "Verbosity=${ConsoleVerbosity}",

  # Gradle-specific params (only used when a Gradle project is detected)
  [string[]] $Tasks
)

begin {
  $wrapperName = if ($IsWindows) { 'gradlew.bat' } else { 'gradlew' }

  # Two-level Gradle detection: wrapper first, then build script + system gradle.
  $gradleWrapper = $null

  $candidate = Join-Path (Get-Location).Path $wrapperName
  if (Test-Path $candidate) {
    $gradleWrapper = $candidate
    Write-Verbose "Detected Gradle wrapper: $gradleWrapper"
  } else {
    $gradleScript = Get-Item 'build.gradle','build.gradle.kts','settings.gradle','settings.gradle.kts' `
                      -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gradleScript) {
      Write-Verbose "Gradle build script found ($($gradleScript.Name)); looking for system gradle."
      $sysGradle = Get-Command gradle -ErrorAction SilentlyContinue
      if ($sysGradle) {
        $gradleWrapper = $sysGradle.Source
        Write-Verbose "Using system gradle: $gradleWrapper"
      } else {
        Write-Warning "Gradle project found but no wrapper and 'gradle' not on PATH; falling back to MSBuild detection."
      }
    }
  }

  if ($gradleWrapper) {
    $gradleParams = @{}
    if ($PSBoundParameters.ContainsKey('Tasks'))         { $gradleParams['Tasks']         = $Tasks }
    if ($PSBoundParameters.ContainsKey('Configuration')) { $gradleParams['Configuration'] = $Configuration }
    if ($PSBoundParameters.ContainsKey('clean'))         { $gradleParams['Clean']         = $clean }
    & "$PSScriptRoot\Invoke-GradleBuild.ps1" @gradleParams
    return
  }

  # No Gradle detected — fall through to MSBuild.
  Write-Verbose "No Gradle wrapper detected; dispatching to MSBuild."
  $msBuildParams = @{} + $PSBoundParameters
  # Remove Gradle-only params before forwarding
  $msBuildParams.Remove('Tasks') | Out-Null
  & "$PSScriptRoot\Invoke-MsBuild.ps1" @msBuildParams
}
