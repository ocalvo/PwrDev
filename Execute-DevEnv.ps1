[CmdLetBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$args
)

begin {
  $aliasExecuted = $MyInvocation.InvocationName
  Write-Verbose "Executing alias: $aliasExecuted with arguments: $args"
  Enter-VsShell
  $cmd = Get-Command $aliasExecuted -ErrorAction Ignore
  if ($null -eq $cmd) {
    Write-Warning "Alias $aliasExecuted not found after entering VS Shell."
  }
}

process {
  Write-Verbose "Removing PwrDev Aliases that are not needed in DevShell"
  $global:_pwrdev_aliases | ForEach-Object {
    $aliasName = $_
    Remove-Alias -Name $aliasName -scope global
  }
  $global:_pwrdev_aliases = @()
}

end {
  .$aliasExecuted @args
}

