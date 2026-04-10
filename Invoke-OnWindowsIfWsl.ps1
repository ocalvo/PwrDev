function Invoke-OnWindowsIfWsl {
    <#
    .SYNOPSIS
        When called from inside WSL, transparently re-invokes the caller on the Windows side.
    .DESCRIPTION
        Detects WSL via $env:WSL_DISTRO_NAME, converts the working directory and script path
        to Windows paths via wslpath, then re-runs the script using pwsh.exe (or powershell.exe
        as fallback) with the same bound parameters.

        The function exits the calling process immediately after launching the Windows process,
        so it acts as a transparent redirect. When not in WSL it is a no-op.

        Hashtable and array parameters cannot be forwarded over the command line and are skipped
        with a warning.
    .PARAMETER ScriptPath
        Full (Linux) path of the calling script. Pass $MyInvocation.MyCommand.Path.
    .PARAMETER BoundParameters
        The caller's $PSBoundParameters hashtable.
    .PARAMETER RemainingArgs
        Any extra positional/remaining arguments to forward.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [hashtable]$BoundParameters = @{},
        [string[]]$RemainingArgs = @()
    )

    # Only act inside WSL; $env:WSL_DISTRO_NAME is set by the WSL kernel in every distro session.
    if (-not $env:WSL_DISTRO_NAME) { return }

    # Resolve Windows-side paths using wslpath.
    $winScript = (wslpath -w $ScriptPath).Trim()
    $winDir    = (wslpath -w $PWD.Path).Trim()

    # Build a flat argument list from bound parameters.
    # Hashtable and array parameters cannot be forwarded over the command line; skip with a warning.
    $passArgs = @(
        $BoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [System.Collections.IDictionary]) {
                Write-Warning "Invoke-OnWindowsIfWsl: skipping hashtable parameter '-$($_.Key)' (cannot forward over command line)"
            } elseif ($_.Value -is [array]) {
                Write-Warning "Invoke-OnWindowsIfWsl: skipping array parameter '-$($_.Key)' (cannot forward over command line)"
            } elseif ($_.Value -is [switch]) {
                if ($_.Value) { "-$($_.Key)" }
            } else {
                "-$($_.Key)"
                $_.Value.ToString()
            }
        }
    ) + @($RemainingArgs)

    # Prefer PowerShell Core (pwsh.exe); fall back to Windows PowerShell 5.1.
    $ps = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if (-not $ps) { $ps = Get-Command powershell.exe -ErrorAction SilentlyContinue }
    if (-not $ps) { throw "Neither pwsh.exe nor powershell.exe found — cannot re-invoke on Windows." }

    Write-Verbose "WSL detected: re-invoking on Windows via $($ps.Source)"
    Write-Verbose "  Script : $winScript"
    Write-Verbose "  WorkDir: $winDir"
    Write-Verbose "  Args   : $($passArgs -join ' ')"

    # Import PwrDev using the Windows path of the already-loaded module so the script can find all
    # PwrDev commands (Enter-VsShell, msbuild alias, etc.) without relying on the Windows profile.
    $moduleFile = (Get-Module PwrDev -ErrorAction SilentlyContinue).Path
    $importCmd  = if ($moduleFile) {
        $winModule = (wslpath -w $moduleFile).Trim()
        "Import-Module '$winModule'"
    } else {
        "Import-Module PwrDev -ErrorAction SilentlyContinue"
    }

    # Re-invoke on the Windows side: import PwrDev, set working directory, run the script.
    # Extra arguments passed after a -Command string are available as $args inside the command.
    & $ps.Source -NoProfile -Command "$importCmd; Set-Location '$winDir'; & '$winScript' @args" @passArgs
    exit $LASTEXITCODE
}
