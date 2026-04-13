[CmdLetBinding()]
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$FilePath,

  [Parameter(Mandatory=$false, Position=1)]
  [int]$LineNumber = 0
)

function Test-IsVisualStudioTerminal {
  try {
    $proc = Get-Process -Id $PID
    $maxDepth = 5
    for ($i = 0; $i -lt $maxDepth; $i++) {
      $proc = $proc.Parent
      if ($null -eq $proc) { break }
      Write-Verbose "Checking ancestor process: $($proc.ProcessName)"
      if ($proc.ProcessName -eq 'DevHub') { return $true }
    }
  } catch {}
  return $false
}


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


if ($null -ne $resolvedPath) {
  $FilePath = $resolvedPath.Path
}
Write-Verbose "FilePath: $FilePath, LineNumber: $LineNumber"

# 1. Running inside a Claude Code session, or stdin is redirected (piped/CI) -
# launch editor in a new window so it can attach to its own terminal.
# Checked first - cheap, and avoids unnecessary CIM queries below.
if ($env:CLAUDE_CODE_ACTIVE -eq '1' -or [Console]::IsInputRedirected) {
  Write-Verbose "Terminal: Claude / redirected stdin - launching editor in new window via Start-Process"
  $vimPath = Get-Command vim -CommandType Application -ErrorAction Ignore
  if ($null -ne $vimPath) {
    $editorArgs = if ($LineNumber -gt 0) { @($FilePath, "+$LineNumber") } else { @($FilePath) }
    Write-Verbose "Using vim ($($vimPath.Source)) args: $editorArgs"
    Start-Process -FilePath $vimPath.Source -ArgumentList $editorArgs
    return
  }
  $editPath = Get-Command edit -CommandType Application -ErrorAction Ignore
  if ($null -ne $editPath) {
    $editorArgs = if ($LineNumber -gt 0) { @($FilePath, $LineNumber) } else { @($FilePath) }
    Write-Verbose "Using edit ($($editPath.Source)) args: $editorArgs"
    Start-Process -FilePath $editPath.Source -ArgumentList $editorArgs
    return
  }
  Write-Warning "No editor found. Install edit or vim to open files from the terminal."
  return
}

# 2. Visual Studio integrated terminal (requires CIM query to walk process tree)
if (Test-IsVisualStudioTerminal) {
  Write-Verbose "Terminal: Visual Studio (DevHub parent) - using DTE"
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
  }
  Write-Warning "Could not connect to any Visual Studio DTE instance."
  return
}

# 3. VS Code terminal
if ($env:TERM_PROGRAM -eq "vscode") {
  $gotoParam = if ($LineNumber -gt 0) { "${FilePath}:${LineNumber}" } else { $FilePath }
  Write-Verbose "Terminal: VS Code - code --goto $gotoParam"
  code --goto $gotoParam
  return
}

# 4. Other terminals: vim, then edit
$vimPath = Get-Command vim -CommandType Application -ErrorAction Ignore
if ($null -ne $vimPath) {
  Write-Verbose "Terminal: other - using vim ($($vimPath.Source))"
  if ($LineNumber -gt 0) {
    & $vimPath.Source $FilePath ("+$LineNumber")
  } else {
    & $vimPath.Source $FilePath
  }
  return
}

$editPath = Get-Command edit -CommandType Application -ErrorAction Ignore
if ($null -ne $editPath) {
  Write-Verbose "Terminal: other - using edit ($($editPath.Source))"
  if ($LineNumber -gt 0) {
    & $editPath.Source $FilePath $LineNumber
  } else {
    & $editPath.Source $FilePath
  }
  return
}

Write-Warning "No editor found. Install edit or vim to open files from the terminal."
