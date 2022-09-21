
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
    param()

    $currentBranch = (git branch --show-current)
    if ($null -eq $currentBranch)
    {
        Write-Error "No git branch detected"
        return;
    }

    $branchFullName = ('refs/heads/'+$currentBranch)
    $currentPR = az repos pr list | ConvertFrom-Json | Where-Object -Property sourceRefName -EQ $branchFullName

    $lastCommit = (git log --format="%H" -n 1)

    return $currentPR
}

Export-ModuleMember -Function Get-PullRequest

function global:Test-PullRequestUpToDate
{
    param(
      [Parameter(Mandatory=$true)]$pullRequest)

    return (git log --format="%H" -n 1) -eq $pullRequest.lastMergeSourceCommit.commitId
}

Export-ModuleMember -Function Test-PullRequestUpToDate

function global:Get-PullRequestChecks
{

    if ($null -eq $pullRequest)
    {
        $pullRequest = Get-PullRequest | Select -First 1
    }

    $checks = az repos pr policy list --id ($pullRequest.pullRequestId) | ConvertFrom-Json
    return $checks
}

Export-ModuleMember -Function Get-PullRequestChecks


function global:Get-PullRequestBuildActions
{
    param(
      [Parameter(Mandatory=$true)]$PullRequestChecks)

    $buildActions = $PullRequestChecks | Where-Object { $null -ne $_.context.buildDefinitionId }

    return $buildActions
}

Export-ModuleMember -Function Get-PullRequestBuildActions

function global:Start-PullRequestBuildAction
{
    param(
        [Parameter(Mandatory=$true)]$PullRequest,
        [Parameter(Mandatory=$true)]$Checks
    )

    $action = $Checks |% { az repos pr policy queue --evaluation-id $_.evaluationId --id $PullRequest.pullRequestId | ConvertFrom-Json }
    return $action
}

Export-ModuleMember -Function Start-PullRequestBuildAction

function global:Get-PullRequestBuildActionStatus
{
    param(
        [Parameter(Mandatory=$true)]$BuildAction
    )

    $NewBuildAction = $BuildAction |% { az pipelines runs show --id $_.context.buildId | ConvertFrom-Json }

    return $NewBuildAction
}

Export-ModuleMember -Function Get-PullRequestBuildActionStatus

