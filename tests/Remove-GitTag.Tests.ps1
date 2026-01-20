Import-Module "$PSScriptRoot/../modules/Remove-GitTag.psm1" -Force

Describe "Remove-GitTag" {

    BeforeEach {
        $env:GITHUB_OUTPUT = "$PSScriptRoot/github_output.temp"
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        $OrgName    = "my-org"
        $RepoName   = "my-repo"
        $TagName    = "v1.2.3"
        $Token      = "test-token"
        $ApiUrl     = "https://api.unit-test.com"
    }

    AfterAll {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
    }

    It "successfully deletes a tag and writes result=success" {
        Mock Invoke-WebRequest {
            param($Uri, $Headers, $Method)
            if ($Method -eq "Get") {
                [PSCustomObject]@{ StatusCode = 200; Content = '{"ref":"refs/tags/v1.2.3"}' }
            }
        } -ModuleName Remove-GitTag
        
        Mock Resolve-TagRefSuccess {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"
        } -ModuleName Remove-GitTag
        
        $env:MOCK_API = $ApiUrl
        
        Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=success"
    }

    It "returns not-found when tag does not exist (404 response)" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 404; Content = '{"message":"Not Found"}' }
        }  -ModuleName Remove-GitTag
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        $env:MOCK_API = $ApiUrl
        
        Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=not-found"
        $output | Should -Contain "error-message=Tag '$TagName' not found."
    }

    It "returns failure for unexpected GET status code (e.g. 500)" {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 500; Content = '{"message":"Internal Error"}' }
        }  -ModuleName Remove-GitTag
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        $env:MOCK_API = $ApiUrl
        
        Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Delete Git Tag: unexpected status 500" } | Should -Not -BeNullOrEmpty
    }

    It "returns failure and error message for null GET response" {
        Mock Invoke-WebRequest { return $null } -ModuleName Remove-GitTag
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        $env:MOCK_API = $ApiUrl
        
        Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "Failed contacting GitHub API for tag check." } | Should -Not -BeNullOrEmpty
    }

    It "returns failure for missing RepoName" {
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        Remove-GitTag -RepoName "" -OrgName $OrgName -TagName $TagName -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
    }

    It "returns failure for missing OrgName" {
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        Remove-GitTag -RepoName $RepoName -OrgName "" -TagName $TagName -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
    }

    It "returns failure for missing TagName" {
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName "" -Token $Token

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
    }

    It "returns failure for missing Token" {
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token ""

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
    }

    It "writes result=failure and error-message on exception" {
        Mock Invoke-WebRequest { throw "API Error" }  -ModuleName Remove-GitTag
        Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
        $env:MOCK_API = $ApiUrl
        
        try { 
            Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token 
        } catch {}
        
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "error-message=Delete Git Tag threw an exception and failed." } | Should -Not -BeNullOrEmpty
    }
}