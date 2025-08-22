[CmdLetBinding()]
param(
  $Target,
  $FilesToTouch,
  $iter = 1,
  $ResultDir = "$env:NUGET_PACKAGES\bbench",
  [switch]$Bundle,
  [switch]$NoSideload,
  [switch]$Nop,
  [switch]$TouchIdlXaml,
  [switch]$Clean
)

$idPrefix = "Inc"
$Properties = @{}
if ($bundle) {
  $idPrefix += ".Bundle"
  $Properties.Add('AppxBundlePlatforms',"x64")
  $Properties.Add('AppxBundle',"Always")
} elseif ($NoSideLoad) {
  $idPrefix += ".NoSideLoad"
  $Properties.Add("BuildAppxSideloadPackageForUap", "false")
}

if ($TouchIdlXaml) {
  $idPrefix += ".TouchXamlIdlCpp"
} elseif (-Not $Nop) {
  $idPrefix += ".TouchCpp"
} elseif ($Nop) {
  $idPrefix += ".NoOp"
}

$BaseResultDir = "$ResultDir\$idPrefix"
MkDir $BaseResultDir -ErrorAction Ignore | Out-Null

1..$iter |% {
  if ($TouchIdlXaml) {
    Write-Verbose "Touching Xaml, Idl, and Cpp"
    (get-item "${FilesToTouch}.*") |% { $_.LastWriteTime = get-date }
  } elseif (-Not $Nop) {
    Write-Verbose "Touching Cpp"
    (get-item "${FilesToTouch}.cpp") |% { $_.LastWriteTime = get-date }
  } elseif ($Nop) {
    Write-Verbose "Not touching anything"
  }
  build -Target $Target -id "$idPrefix.$_" -Properties $Properties -Clean:$Clean -BaseResultDir $BaseResultDir
}

