function Remove-GitTag {
  param(
    [string]$RepoName,
    [string]$OrgName,
    [string]$TagName,
    [string]$Token 
  )
  
  # Validate required inputs
  if ([string]::IsNullOrEmpty($RepoName) -or 
    [string]::IsNullOrEmpty($OrgName) -or 
    [string]::IsNullOrEmpty($TagName) -or
    [string]::IsNullOrEmpty($Token)) 
  {    
    Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
    Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
    Write-Host "Error: Missing required parameters"  
    return
  }

  Import-Module "$PSScriptRoot/Resolve-TagRefSuccess.psm1" -Force
  
  $githubApiUrl = $env:MOCK_API  
  if (-not $githubApiUrl) { $githubApiUrl = "https://api.github.com" }
  
  $headers = @{
      Authorization = "Bearer $Token"
      "Accept" = "application/vnd.github+json"
      "X-GitHub-Api-Version" = "2026-03-10"
  }
  
  try {
    Write-Host "Attempting to delete Git tag '$TagName' from $OrgName/$RepoName ..."
    
    # GitHub API expects tag names to be URL encoded
    $safeTagName = [uri]::EscapeDataString($TagName)
    $uri = "$githubApiUrl/repos/$OrgName/$RepoName/git/refs/tags/$safeTagName"
  
    $getResp = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get
  
    if ($null -eq $getResp) {
      $errorMsg = "Error: Failed contacting GitHub API for tag check."
      Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
      Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
      Write-Host $errorMsg
      return
    }
  
    if ($getResp.StatusCode -eq 200) {
      $content = $getResp.Content | ConvertFrom-Json
      Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $refUrl -headers $headers
    } elseif ($getResp.StatusCode -eq 404) {
      $errorMsg = "Warning: Tag '$TagName' does not exist on $OrgName/$RepoName."
      Add-Content -Path $env:GITHUB_OUTPUT -Value "result=not-found"
      Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
      Write-Host $errorMsg
    } else {
      $errorMsg = "Error: Failed to delete tag. Status: $($getResp.StatusCode)"
      Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
      Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg" 
      Write-Host $errorMsg
    }    
  } catch {
    $errorMsg = "Error: Failed to delete tag. Exception: $($_.Exception.Message)"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
    Write-Host $errorMsg
  }
}
