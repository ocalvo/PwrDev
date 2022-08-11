Param([switch]$msBuildAlias)

$global:lastBuildErrors = $null
if ($null -eq $env:_msBuildPath)
{
  $env:_msBuildPath = (get-command msbuild -ErrorAction Ignore).Definition
  if ($null -eq $env:_msBuildPath)
  {
      Write-Error "MSbuild not detected"
      return
  }
}

$env:_MSBUILD_VERBOSITY = "m"
$env:_MSBUILD_EXTRAPARAMS = "/p:NuGetInteractive=true"

function global:msb()
{
  $global:lastBuildErrors = $null
  $global:lastBuildDir = (Get-Location).Path
  $date = [datetime]::Now

  #$dMarker = $date.ToString("yyMMdd-HHmmss.")
  #$logFileName = (".\build"+$dMarker+$env:_BuildType)
  $logFileName = ("build"+$env:_BuildType) # If you change this, update Get-BuildErrors

  .$env:_msBuildPath "/bl:LogFile=$logFileName.binlog" /nologo /v:$env:_MSBUILD_VERBOSITY $env:_MSBUILD_EXTRAPARAMS /m $args "-flp2:LogFile=$logFileName.err;errorsonly" "-flp3:LogFile=$logFileName.wrn;warningsonly"
  $global:lastBuildErrors = Get-BuildErrors
  if ($null -ne $global:lastBuildErrors)
  {
    Write-Warning "Build errors detected:`$lastBuildErrors"
  }
}

set-alias msbuild msb -scope global
Export-ModuleMember -alias msbuild

#if ($msBuildAlias.IsPresent)
#{
#  $env:path = ($PSScriptRoot+';'+$env:path)
#}
