[CmdletBinding()]
param(
    [string[]] $Tasks = @('build'),
    [string]   $Configuration,
    [switch]   $Clean
)

begin {
    # Walk up from cwd to repo root (.git boundary) looking for the Gradle wrapper.
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
            # Stop at repo root
            if (Test-Path (Join-Path $dir '.git')) {
                Write-Verbose "Reached .git boundary at $dir; wrapper not found."
                return $null
            }
            $parent = Split-Path $dir -Parent
            if ($parent -eq $dir) { return $null }   # filesystem root
            $dir = $parent
        }
    }

    # Refresh JAVA_HOME / ANDROID_HOME / GRADLE_USER_HOME from the user-scoped registry
    # so sessions that predate setup-android-env.ps1 pick them up.
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

        # Ensure JAVA_HOME\bin is on PATH so gradlew can find java.
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

    # Remove HTTP_PROXY / HTTPS_PROXY — empty string causes a parse error in
    # Java's proxy stack (sdkmanager, Gradle HTTP client).  Remove entirely.
    $savedHttpProxy  = $env:HTTP_PROXY
    $savedHttpsProxy = $env:HTTPS_PROXY
    Remove-Item Env:HTTP_PROXY  -ErrorAction SilentlyContinue
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    $env:JAVA_TOOL_OPTIONS = '-Djava.net.useSystemProxies=false'
    Write-Verbose "Cleared HTTP_PROXY / HTTPS_PROXY for Gradle JVM"
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
    & $wrapper @gradleTasks @extraArgs
    $script:exitCode = $LASTEXITCODE
}

end {
    # Restore proxy vars
    if ($savedHttpProxy)  { $env:HTTP_PROXY  = $savedHttpProxy }
    if ($savedHttpsProxy) { $env:HTTPS_PROXY = $savedHttpsProxy }
    Remove-Item Env:JAVA_TOOL_OPTIONS -ErrorAction SilentlyContinue

    if ($script:exitCode -ne 0) {
        Write-Error "Gradle build failed with exit code $script:exitCode"
    }
    exit $script:exitCode
}
