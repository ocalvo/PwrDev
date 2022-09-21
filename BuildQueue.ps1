
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

