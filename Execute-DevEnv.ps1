[CmdLetBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$args
)

Enter-VsShell
Remove-Item alias:devenv
devenv @args

