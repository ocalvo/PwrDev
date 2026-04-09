#!/bin/bash
# WSL helper: runs a PowerShell script using pwsh.exe or powershell.exe.
# Usage: pwsh-executor.sh <script.ps1> [args...]

if command -v pwsh.exe &>/dev/null; then
  POWERSHELL=pwsh.exe
else
  POWERSHELL=powershell.exe
fi

SCRIPT="$1"
shift

if command -v wslpath &>/dev/null; then
  SCRIPT_WIN=$(wslpath -w "$SCRIPT")
else
  SCRIPT_WIN="$SCRIPT"
fi

$POWERSHELL -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_WIN" "$@"
