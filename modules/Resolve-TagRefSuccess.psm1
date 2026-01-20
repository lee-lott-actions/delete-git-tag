function Resolve-TagRefSuccess {
    param(
        $content,
        $TagName,
        $OrgName,
        $RepoName,
        $refUrl,
        $headers
    )

    # If it's an array (multiple refs found), tag does not exist exactly
    if ($content -is [System.Collections.IEnumerable] -and
        -not ($content.PSObject.TypeNames -contains "System.Collections.Hashtable")) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "result=not-found"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Tag '$TagName' not found (prefix match, but no exact match)."
        Write-Host "Tag '$TagName' does not exist—only tags starting with '$TagName' exist."
    }
    # If there is an exact match, proceed to delete
    elseif ($content.ref -eq "refs/tags/$TagName") {
        $delResp = Invoke-WebRequest -Uri $refUrl -Headers $headers -Method Delete

        if ($null -eq $delResp) {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Failed contacting GitHub API for tag deletion."
            Write-Host "Failed contacting GitHub API for tag deletion."
            return
        }

        if ($delResp.StatusCode -eq 204) {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"
            Write-Host "Successfully deleted tag '$TagName' from $OrgName/$RepoName."
        } else {
            $msg = ""
            if ($delResp.Content) {
                try { $msg = ($delResp.Content | ConvertFrom-Json).message } catch {}
            }
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Failed to delete tag: $msg"
            Write-Host "Failed to delete tag '$TagName'. Status: $($delResp.StatusCode)"
        }
    } else {
        # No exact match
        Add-Content -Path $env:GITHUB_OUTPUT -Value "result=not-found"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Tag '$TagName' not found (response ref: $($content.ref))."
        Write-Host "Tag '$TagName' does not exist as an exact ref."
    }
}