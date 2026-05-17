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
        $errorMsg = "Warning: Tag '$TagName' does not exist. Only tags starting with '$TagName' exist."
        Add-Content -Path $env:GITHUB_OUTPUT -Value "result=not-found"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
        Write-Host $errorMsg
    }
    # If there is an exact match, proceed to delete
    elseif ($content.ref -eq "refs/tags/$TagName") {
        $delResp = Invoke-WebRequest -Uri $refUrl -Headers $headers -Method Delete -SkipHttpErrorCheck

        if ($null -eq $delResp) {
            $errorMsg = "Error: Failed contacting GitHub API for tag deletion."
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
            Write-Host $errorMsg
            return
        }

        if ($delResp.StatusCode -eq 204) {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"
            Write-Host "Successfully deleted tag '$TagName' from $OrgName/$RepoName."
        } else {
            $msg = ""
            if ($delResp.Content) {
                try { $msg = ($delResp.Content | ConvertFrom-Json).message
                } catch {
                    $msg = $delResp.Content
                }
            }

            $errorMsg = "Error: Failed to delete tag '$TagName'. Status: $($delResp.StatusCode)."
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg Message: $msg"
            Write-Host $errorMsg
        }
    } else {
        # No exact match
        $errorMsg = "Error: Tag '$TagName' not found."
        Add-Content -Path $env:GITHUB_OUTPUT -Value "result=not-found"
        Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
        Write-Host $errorMsg
    }
}
