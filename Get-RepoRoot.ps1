param($marker = '.git')
$d = (Get-Item -Path . -Force).FullName
while ($d -and -not (Test-Path (Join-Path $d $marker))) {
  $d = Split-Path $d -Parent
}
$d
