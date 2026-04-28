[CmdletBinding()]
param(
    [string[]] $Tasks = @('build'),
    [string]   $Configuration,
    [switch]   $Clean
)

begin {
    function Find-GradleWrapper {
        [CmdletBinding()]
        param()

        $wrapperName = if ($IsWindows) { 'gradlew.bat' } else { 'gradlew' }
        $dir = (Get-Location).Path

        while ($true) {
            $candidate = Join-Path $dir $wrapperName
            if (Test-Path $candidate) {
                Write-Verbose "Found Gradle wrapper: $candidate"
                return $candidate
            }
            if (Test-Path (Join-Path $dir '.git')) {
                Write-Verbose "Reached .git boundary at $dir; wrapper not found."
                return $null
            }
            $parent = Split-Path $dir -Parent
            if ($parent -eq $dir) { return $null }
            $dir = $parent
        }
    }

    function Refresh-AndroidEnvVars {
        [CmdletBinding()]
        param()

        $regPath = 'HKCU:\Environment'
        foreach ($var in 'JAVA_HOME','ANDROID_HOME','GRADLE_USER_HOME') {
            $regVal = (Get-ItemProperty -Path $regPath -Name $var -ErrorAction SilentlyContinue).$var
            if ($regVal -and -not (Test-Path "Env:$var")) {
                Set-Item "Env:$var" $regVal
                Write-Verbose "Restored $var = $regVal (from registry)"
            }
        }

        if ($env:JAVA_HOME) {
            $javaBin = Join-Path $env:JAVA_HOME 'bin'
            if ($env:PATH -notlike "*$javaBin*") {
                $env:PATH = "$javaBin;$env:PATH"
                Write-Verbose "Prepended $javaBin to PATH"
            }
        }
    }

    $wrapper = Find-GradleWrapper
    if (-not $wrapper) {
        Write-Error "No Gradle wrapper (gradlew.bat / gradlew) found in this directory or any parent up to the repo root."
        exit 1
    }

    Refresh-AndroidEnvVars

    $savedHttpProxy  = $env:HTTP_PROXY
    $savedHttpsProxy = $env:HTTPS_PROXY
    Remove-Item Env:HTTP_PROXY  -ErrorAction SilentlyContinue
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    $env:JAVA_TOOL_OPTIONS = '-Djava.net.useSystemProxies=false'
    Write-Verbose "Cleared HTTP_PROXY / HTTPS_PROXY for Gradle JVM"

    # Mirror the .vs log directory convention from Invoke-MsBuild.ps1
    $repoRoot = & "$PSScriptRoot\Get-RepoRoot.ps1"
    $resultDir = Join-Path $repoRoot '.vs'
    New-Item $resultDir -ItemType Directory -ErrorAction Ignore | Out-Null

    $time     = [datetime]::Now.ToString("yy.dd.MM-HH.mm.ss")
    $projName = Split-Path (Get-Location).Path -Leaf
    $br       = (git branch --show-current 2>$null) -split '/' | Select-Object -Last 1
    $taskStr  = ($Tasks -join '_') -replace '[\\/:*?"<>|]', '_'

    $suffixName       = (($time, $projName, $taskStr, $br, $Configuration) | Where-Object { $_ }) -join '.'
    $logTxtFileName   = Join-Path $resultDir "build.$suffixName.log"
    $logErrFileName   = Join-Path $resultDir "build.$suffixName.err"
    $logWrnFileName   = Join-Path $resultDir "build.$suffixName.wrn"
    $logDurationFile  = Join-Path $resultDir "build.$suffixName.txt"
    $logExitLevelFile = Join-Path $resultDir "build.$suffixName.exitcode"

    $env:lastBuildLog = Join-Path $resultDir "build.$suffixName"
    Write-Verbose "Log base: $($env:lastBuildLog)"
    Write-Verbose "ErrFileName: $logErrFileName"
    Write-Verbose "WrnFileName: $logWrnFileName"
}

process {
    $gradleTasks = [System.Collections.Generic.List[string]]::new()

    if ($Clean) {
        $gradleTasks.Add('clean')
        Write-Verbose "Prepending 'clean' task"
    }
    foreach ($t in $Tasks) { $gradleTasks.Add($t) }

    $extraArgs = @()
    if ($Configuration) {
        $extraArgs += "-PbuildType=$Configuration"
        Write-Verbose "Passing -PbuildType=$Configuration"
    }

    Write-Verbose "Running: $wrapper $gradleTasks $extraArgs"

    $script:logLines = [System.Collections.Generic.List[string]]::new()
    $script:start = [DateTime]::Now

    # Capture all output (stdout + stderr) while streaming to terminal in real time.
    # Strip ANSI escape codes before writing to log files so they're plain text.
    & $wrapper @gradleTasks @extraArgs 2>&1 | ForEach-Object {
        $line = if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.ToString() } else { [string]$_ }
        Write-Host $line
        $script:logLines.Add(($line -replace '\x1B\[[0-9;]*[mK]', ''))
    }
    $script:exitCode = $LASTEXITCODE
    $script:end = [DateTime]::Now
}

end {
    if ($savedHttpProxy)  { $env:HTTP_PROXY  = $savedHttpProxy }
    if ($savedHttpsProxy) { $env:HTTPS_PROXY = $savedHttpsProxy }
    Remove-Item Env:JAVA_TOOL_OPTIONS -ErrorAction SilentlyContinue

    $script:logLines | Set-Content -Path $logTxtFileName -Encoding UTF8
    Write-Verbose "Full log: $logTxtFileName"

    # Gradle/Kotlin/C++ error patterns
    $errLines = $script:logLines | Where-Object { $_ -match '(?i)(^e:\s|: error:|> Task .+ FAILED|^FAILURE:)' }
    if ($errLines) {
        $errLines | Set-Content -Path $logErrFileName -Encoding UTF8
        Write-Verbose "Error log: $logErrFileName ($(@($errLines).Count) lines)"
    }

    # Gradle/Kotlin/C++ warning patterns
    $wrnLines = $script:logLines | Where-Object { $_ -match '(?i)(^w:\s|: warning:|WARNING:)' }
    if ($wrnLines) {
        $wrnLines | Set-Content -Path $logWrnFileName -Encoding UTF8
        Write-Verbose "Warning log: $logWrnFileName ($(@($wrnLines).Count) lines)"
    }

    if ($null -ne $script:end -and $null -ne $script:start) {
        $duration    = $script:end - $script:start
        $durationStr = $duration.ToString("hh\:mm\:ss\.fff")
        Write-Verbose "Duration: $durationStr"
        Set-Content -Value $durationStr -Path $logDurationFile
    }

    Set-Content -Value $script:exitCode -Path $logExitLevelFile

    if ($script:exitCode -ne 0) {
        Write-Error "Gradle build failed with exit code $script:exitCode"
    }
    exit $script:exitCode
}
