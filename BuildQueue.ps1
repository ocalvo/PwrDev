
if ($null -eq (get-command az -ErrorAction Ignore))
{
    Write-Error "AZ command not detected, please install AZ CLI"
    return;
}

if ($null -eq (get-command git -ErrorAction Ignore))
{
    Write-Error "git command not detected, please install Git"
    return;
}

function global:Get-PullRequest()
{
    param(
        [switch]$Verbose
    )

    $currentBranch = (git branch --show-current)
    Write-Verbose "Current branch is $currentBranch" -Verbose:$verbose

    if ($null -eq $currentBranch)
    {
        Write-Error "No git branch detected"
        return;
    }

    $branchFullName = ('refs/heads/'+$currentBranch)
    $currentPR = az repos pr list | ConvertFrom-Json | Where-Object -Property sourceRefName -EQ $branchFullName
    if ($null -eq $currentPR)
    {
        Write-Error "Cannot get pull request"
        return;
    }
    return $currentPR
}

Export-ModuleMember -Function Get-PullRequest

function global:Test-PullRequestUpToDate
{
    param(
        [switch]$Verbose,
        [Parameter(Mandatory=$true)]$pullRequest = (Get-PullRequest -Verbose $verbose | Select-Object -First 1)
    )

    $lastCommitId = $pullRequest.lastMergeSourceCommit.commitId
    Write-Verbose "Last pushed commit $lastCommitId" -Verbose:$verbose

    $gitLastCommit = (git log --format="%H" -n 1)
    Write-Verbose "Last local commit $gitLastCommit" -Verbose:$verbose

    return $gitLastCommit -eq $lastCommitId
}

Export-ModuleMember -Function Test-PullRequestUpToDate

function global:Get-PullRequestChecks
{
    param(
        [switch]$Verbose,
        $PullRequest = (Get-PullRequest -Verbose:$verbose | Select -First 1)
    )

    $prID = $pullRequest.pullRequestId
    Write-Verbose "Getting policy checks for PR $prID" -Verbose:$verbose

    $checks = az repos pr policy list --id ($prID) | ConvertFrom-Json | Where-Object { $null -ne $_.context.buildDefinitionId }
    return $checks
}

Export-ModuleMember -Function Get-PullRequestChecks


function global:Get-PullRequestBuildActions
{
    param(
      [switch]$verbose,
      [Parameter(Mandatory=$true)]$PullRequestChecks)

    $c = $PullRequestChecks.Count
    Write-Verbose "Getting build actions that have a build definition id from $c checks" -Verbose:$verbose

    $buildActions = $PullRequestChecks | Where-Object { $null -ne $_.context.buildDefinitionId }

    return $buildActions
}

Export-ModuleMember -Function Get-PullRequestBuildActions

function global:Get-PullRequestBuildStatus
{
    param(
        #[switch]$verbose,
        [Parameter(Mandatory=$true)]$Build
    )

    $verbose = $true

    $b = $Build | Select-Object -First 1;
    $bId = $b.context.buildId
    Write-Verbose "Getting build status for build $bId" -Verbose:$verbose

    $BuildStatus = $Build |% { az pipelines runs show --id $_.context.buildId | ConvertFrom-Json }

    $status = $BuildStatus.status
    Write-Verbose "Getting build status is $status" -Verbose:$verbose

    return $BuildStatus
}

Export-ModuleMember -Function Get-PullRequestBuildStatus

function global:Monitor-PullRequestBuildActions
{
    param(
        [Parameter(Mandatory=$true)]$Build
    )

    #$v = $false
    #if ($VerbosePreference -eq "Continue") { $v = $true }
    do
    {
        $BuildStatus = Get-PullRequestBuildStatus $Build
        Sleep 1
    } while (!($BuildStatus.status.Contains("completed")))
}

Export-ModuleMember -Function Monitor-PullRequestBuildActions


function global:Start-PullRequestBuildActions
{
    param(
        [switch]$verbose,
        $PullRequest = (Get-PullRequest -Verbose $verbose | Select-Object -First 1),
        $Checks = (Get-PullRequestChecks -Verbose $verbose -PullRequest $PullRequest)
    )

    $prId = $PullRequest.pullRequestId
    Write-Verbose "Queueing new build for PR $prId" -Verbose:$verbose

    $build = $Checks |% { az repos pr policy queue --evaluation-id $_.evaluationId --id $prId | ConvertFrom-Json }

    $bId = $build.context.buildId
    Write-Verbose "Build $bId started" -Verbose:$verbose

    [scriptblock] $monitorFunc = {
        Import-Module PwrDev
        #$v = $false
        #if ($args[1] -ne $null) { $v = $args[1] }
        #if ($v) { $VerbosePreference = "Continue" }
        Monitor-PullRequestBuildActions -Build $args[0]
    }
    #$v = $verbose
    return Start-Job -ScriptBlock $monitorFunc -ArgumentList ($build)
}

Export-ModuleMember -Function Start-PullRequestBuildActions

