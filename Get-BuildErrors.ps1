[CmdLetBinding()]
param(
    [switch]$IncludeWarnings
)

function ConvertTo-BuildDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Line
    )
    process {
        # MSBuild: [> ]path(line[,col]): error|warning CODE: message
        if ($Line -match '([^(>]+)\((\d+)(?:,(\d+))?\):\s*(error|warning)\s+(\w+):\s*(.+)') {
            return [PSCustomObject]@{
                PSTypeName = 'PwrDev.BuildDiagnostic'
                Severity   = $Matches[4]
                File       = (Get-Item $Matches[1].Trim() -ErrorAction SilentlyContinue) ?? $Matches[1].Trim()
                LineNumber = [int]$Matches[2]
                Column     = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
                Code       = $Matches[5]
                Message    = $Matches[6].Trim()
                RawLine    = $Line
            }
        }

        # Kotlin: e:|w: file:///path:line:col: error|warning: message
        if ($Line -match '^[ew]:\s+file:///(.+):(\d+):(\d+):\s*(error|warning):\s*(.+)') {
            return [PSCustomObject]@{
                PSTypeName = 'PwrDev.BuildDiagnostic'
                Severity   = $Matches[4]
                File       = (Get-Item $Matches[1] -ErrorAction SilentlyContinue) ?? $Matches[1]
                LineNumber = [int]$Matches[2]
                Column     = [int]$Matches[3]
                Code       = ''
                Message    = $Matches[5].Trim()
                RawLine    = $Line
            }
        }

        # C/C++ (clang via Gradle CMake): [C/C++: ]drive:/path:line:col: error|warning: message
        if ($Line -match '^(?:C/C\+\+:\s+)?([A-Za-z]:[/\\][^:]+):(\d+):(\d+):\s*(error|warning):\s*(.+)') {
            return [PSCustomObject]@{
                PSTypeName = 'PwrDev.BuildDiagnostic'
                Severity   = $Matches[4]
                File       = (Get-Item $Matches[1] -ErrorAction SilentlyContinue) ?? $Matches[1]
                LineNumber = [int]$Matches[2]
                Column     = [int]$Matches[3]
                Code       = ''
                Message    = $Matches[5].Trim()
                RawLine    = $Line
            }
        }
    }
}

if (Test-Path env:lastBuildLog) {
    $baseLog = $env:lastBuildLog
} else {
    $vsDir   = Join-Path (Get-RepoRoot) '.vs'
    $lastErr = Get-ChildItem (Join-Path $vsDir 'build.*.err') -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime |
                 Select-Object -Last 1
    if ($null -eq $lastErr) {
        if (Test-Path env:_BuildType) {
            $buildErrorsDir = if ($null -ne $global:lastBuildDir) { $global:lastBuildDir } else { ".\" }
            $baseLog = $buildErrorsDir + "\build" + $env:_BuildType
        } else {
            Write-Error "No build error files found. Run a build first."
            return
        }
    } else {
        $baseLog = [System.IO.Path]::Combine(
            $lastErr.DirectoryName,
            [System.IO.Path]::GetFileNameWithoutExtension($lastErr.FullName))
    }
}

$errFile = "$baseLog.err"
$wrnFile = "$baseLog.wrn"

if (Test-Path $errFile) {
    Write-Verbose "Errors from: $errFile"
    Get-Content $errFile | ConvertTo-BuildDiagnostic
}

if ($IncludeWarnings -and (Test-Path $wrnFile)) {
    Write-Verbose "Warnings from: $wrnFile"
    Get-Content $wrnFile | ConvertTo-BuildDiagnostic
}
