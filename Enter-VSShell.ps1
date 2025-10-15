[CmdLetBinding()]
param(
  [Parameter(Mandatory=$false)][String]$vsVersion = "Enterprise",
  [Parameter(Mandatory=$false)][String]$vsYear = "2022",
  $vsWhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
)

$msbuildCmd = Get-Command msbuild -ErrorAction Ignore

if ($null -ne $msbuildCmd)
{
   $msVer = msbuild -nologo -version | Select-Object -Last 1
   Write-Output "Already Under DevShell:${msVer}"
   return;
}

$script:__platform = switch -Regex ([System.Runtime.InteropServices.RuntimeInformation]::OSDescription) {
   'Windows' { 'Windows' }
   'Darwin'  { 'macOS' }
   'Linux'   { 'Linux' }
   default   { 'Unknown OS' }
}

function global:Invoke-DotnetMSBuild {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
  )

  $command = @("msbuild") + $Args
  Write-Verbose "Running: dotnet $($command -join ' ')"

  & dotnet @command
}

if (($__platform) -eq 'Windows' -and (Test-Path $vsWhere)) {

  $installPath = & $vsWhere -version 16.0 -prerelease -all -products * -property installationpath
  $vsVersions = $installPath |
    Select-Object @{Name='Version';Expression={Split-Path $_ -Leaf | Select-Object -First 1}},
      @{Name='Year';Expression={Split-Path (Split-Path $_) -Leaf | Select-Object -First 1}},
      @{Name='Path';Expression={$_}}

  Write-Verbose "Found the following versions:"
  $vsVersions |% {
    $y = $_.Year
    $vsV = $_.Version
    $p = $_.Path
    Write-Verbose "Year: $y, Version: $vsV, Path $p"
  }

  if ($null -eq $vsVersions) {
    Write-Error "Not VS Tools found"
    return
  }

  function Find-VsVer {
    param($ver,$year)
    Write-Verbose "Looking for version: $ver and year $year"
    $v = $vsVersions | Where-Object { ($_.Version -eq $ver) -and ($_.Year -eq $year) } | Select-Object -First 1
    return $v
  }

  $requestedEditionsOrder = @(
    @($vsVersion, $vsYear),
    @('Insiders', '18'),
    @('Enterprise', $vsYear),
    @('Preview', '2022'),
    @('Professional', '2022')
    @('Community', '2022'),
    @($vsVersion, '2019'),
    @('Enterprise', '2019'),
    @('Preview', '2019'),
    @('Professional', '2019'),
    @('Community', '2019')
  )

  $ver = $requestedEditionsOrder |% { Find-VsVer -ver $_[0] -year $_[1] } | Select-Object -First 1
  if ($null -eq $ver) {
    Write-Error "Could not find a match for VS Tools"
    return
  }
  Write-Verbose "Match the following versions:"
  Write-Verbose ("  "+$ver)

  $devShellModule = Join-Path $ver.Path "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
  Write-Verbose "Loading module $devShellModule"
  Import-Module $devShellModule
  $vsVerPath = $ver.Path
  Write-Verbose "Loading VS Shell from $vsVerPath"
  Enter-VsDevShell -VsInstallPath $vsVerPath -SkipAutomaticLocation | Write-Verbose

  Write-Host "DevShell:${env:VSCMD_VER}"
} else {
  $dotnetCmd = Get-Command dotnet -ErrorAction Ignore
  if ($dotNetCmd -eq $null) {
    Write-Error "dotnet not found"
    return
  }
  Write-Verbose "Installing msbuild alias: msbuild -> Invoke-DotnetMSBuild"
  set-alias msbuild Invoke-DotnetMSBuild -scope Global
  $msVer = msbuild -nologo -version | Select-Object -Last 1
  Write-Output "DevShell:${msVer}"
}

