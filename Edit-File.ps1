[CmdLetBinding()]
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$FilePath,

  [Parameter(Mandatory=$false, Position=1)]
  [int]$LineNumber = 0
)

# SENSITIVE: This file has been extensively tested across three terminal contexts:
#   1. Visual Studio terminal (devenv ancestor) → DTE opens file in running VS instance
#   2. Claude Code / redirected stdin           → vim launched in new window via Start-Process
#   3. Plain terminal                           → vim runs inline
#
# The terminal detection logic is fragile and must be tested in ALL three contexts
# before committing any change. Do not modify detection heuristics without testing.

# Marshal.GetActiveObject was removed in .NET Core - use oleaut32 P/Invoke instead
if (-not ([System.Management.Automation.PSTypeName]'ComHelper').Type) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class ComHelper {
    [DllImport("ole32.dll")]
    private static extern int CLSIDFromProgID([MarshalAs(UnmanagedType.LPWStr)] string lpszProgID, out Guid pclsid);
    [DllImport("oleaut32.dll")]
    private static extern int GetActiveObject(ref Guid rclsid, IntPtr pvReserved, [MarshalAs(UnmanagedType.IUnknown)] out object ppunk);
    public static object GetActiveObject(string progId) {
        Guid clsid;
        CLSIDFromProgID(progId, out clsid);
        object obj;
        int hr = GetActiveObject(ref clsid, IntPtr.Zero, out obj);
        if (hr != 0) Marshal.ThrowExceptionForHR(hr);
        return obj;
    }
}
'@
}

function Test-IsVisualStudioTerminal {
  try {
    $proc = Get-Process -Id $PID
    $maxDepth = 5
    for ($i = 0; $i -lt $maxDepth; $i++) {
      $proc = $proc.Parent
      if ($null -eq $proc) { break }
      Write-Verbose "Checking ancestor process: $($proc.ProcessName)"
      if ($proc.ProcessName -eq 'DevHub' -or $proc.ProcessName -eq 'devenv') { return $true }
    }
  } catch {}
  return $false
}

if ($null -ne $resolvedPath) {
  $FilePath = $resolvedPath.Path
}
Write-Verbose "FilePath: $FilePath, LineNumber: $LineNumber"

# 1. Visual Studio integrated terminal (DevHub ancestor) - use DTE.
# DTE is only used when running inside VS's own terminal. When VS is open in the
# background but you're in a separate terminal, ef opens vim there instead.
if (Test-IsVisualStudioTerminal) {
  $dteProgIds = @("VisualStudio.DTE.18.0", "VisualStudio.DTE.17.0", "VisualStudio.DTE.16.0", "VisualStudio.DTE.15.0", "VisualStudio.DTE")
  $dte = $null
  foreach ($progId in $dteProgIds) {
    try {
      $dte = [ComHelper]::GetActiveObject($progId)
      Write-Verbose "Connected to DTE via $progId"
      break
    } catch {
      Write-Verbose "ProgID $progId not available: $_"
    }
  }
  if ($null -ne $dte) {
    try {
      $window = $dte.ItemOperations.OpenFile($FilePath)
      $window.Activate()
      if ($LineNumber -gt 0) {
        $doc = $dte.ActiveDocument
        if ($null -eq $doc) {
          try { $doc = $dte.Documents.Item($FilePath) } catch {}
        }
        if ($null -ne $doc) {
          $doc.Activate()
          $doc.Selection.GotoLine($LineNumber, $false)
        } else {
          Write-Warning "File opened but could not navigate to line $LineNumber"
        }
      }
      return
    } catch {
      Write-Warning "DTE OpenFile failed: $_. Falling back to editor."
    }
  } else {
    Write-Warning "Could not connect to any Visual Studio DTE instance."
  }
  return
}

# 2. VS Code terminal
if ($env:TERM_PROGRAM -eq "vscode") {
  $gotoParam = if ($LineNumber -gt 0) { "${FilePath}:${LineNumber}" } else { $FilePath }
  Write-Verbose "Terminal: VS Code - code --goto $gotoParam"
  code --goto $gotoParam
  return
}

# Helper: locate vim.exe — checks PATH first, then common Windows install locations.
function Find-VimExe {
  $cmd = Get-Command vim -CommandType Application -ErrorAction Ignore | Select-Object -First 1
  if ($null -ne $cmd) { return $cmd.Source }
  $candidates = @(
    "$env:ProgramFiles\Vim\vim*\vim.exe",
    "${env:ProgramFiles(x86)}\Vim\vim*\vim.exe",
    "$env:ProgramData\chocolatey\bin\vim.exe",
    "$env:LOCALAPPDATA\Programs\vim\vim.exe",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\*vim*\vim.exe"
  )
  foreach ($pattern in $candidates) {
    $found = Resolve-Path $pattern -ErrorAction Ignore | Select-Object -Last 1
    if ($null -ne $found) {
      Write-Verbose "Found vim at: $($found.Path)"
      return $found.Path
    }
  }
  return $null
}

# 3. Stdin is redirected (piped/CI or terminal owned by another process) -
# launch editor in a new window so it can attach to its own terminal.
if ([Console]::IsInputRedirected) {
  Write-Verbose "stdin redirected - launching editor in new window via Start-Process"
  $vimExe = Find-VimExe
  if ($null -ne $vimExe) {
    $editorArgs = if ($LineNumber -gt 0) { @($FilePath, "+$LineNumber") } else { @($FilePath) }
    Write-Verbose "Using vim ($vimExe) args: $editorArgs"
    Start-Process -FilePath $vimExe -ArgumentList $editorArgs
    return
  }
  Write-Warning "No editor found. Install vim to open files from the terminal."
  return
}

# 4. Other terminals: vim inline
$vimExe = Find-VimExe
if ($null -ne $vimExe) {
  Write-Verbose "Terminal: other - using vim ($vimExe)"
  if ($LineNumber -gt 0) {
    & $vimExe $FilePath ("+$LineNumber")
  } else {
    & $vimExe $FilePath
  }
  return
}

Write-Warning "No editor found. Install vim to open files from the terminal."
