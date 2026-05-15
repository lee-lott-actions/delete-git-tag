Import-Module "$PSScriptRoot/../modules/Remove-GitTag.psm1" -Force

Describe "Remove-GitTag" {
    BeforeAll {
        $script:OrgName    = "my-org"
        $script:RepoName   = "my-repo"
        $scriptTagName    = "v1.2.3"
        $script:Token      = "test-token"
        $script:MockApiUrl  = "http://127.0.0.1:3000"
    }
    
    BeforeEach {
        $env:GITHUB_OUTPUT = New-TemporaryFile
        $env:MOCK_API = $script:MockApiUrl
    }

    AfterEach {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        Remove-Variable -Name MOCK_API -Scope Global -ErrorAction SilentlyContinue
    }

    Context "Success Cases" {
        It "unit: Remove-GitTag succeeds with HTTP 200" {
            Mock Invoke-WebRequest {
                param($Uri, $Headers, $Method)
                if ($Method -eq "Get") {
                    [PSCustomObject]@{ StatusCode = 200; Content = '{"ref":"refs/tags/v1.2.3"}' }
                }
            } -ModuleName Remove-GitTag
            
            Mock Resolve-TagRefSuccess {
                Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"
            } -ModuleName Remove-GitTag
            
            Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=success"
        }   
    }

    Context "HTTP Failure Cases" {
        It "unit: Remove-GitTag fails with HTTP 404" {
            Mock Invoke-WebRequest {
                [PSCustomObject]@{ StatusCode = 404; Content = '{"message":"Not Found"}' }
            }  -ModuleName Remove-GitTag
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            
            Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=not-found"
            $output | Should -Contain "error-message=Warning: Tag '$TagName' does not exist on $OrgName/$RepoName."
        }
    
        It "unit: Remove-GitTag fails with HTTP 500" {
            Mock Invoke-WebRequest {
                [PSCustomObject]@{ StatusCode = 500; Content = '{"message":"Internal Error"}' }
            }  -ModuleName Remove-GitTag
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            
            Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Error: Failed to delete tag. Status: 500" } | Should -Not -BeNullOrEmpty
        }

        It "unit: Remove-GitTag fails with null Response" {
            Mock Invoke-WebRequest { return $null } -ModuleName Remove-GitTag
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            
            Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token
        
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "Failed contacting GitHub API for tag check." } | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Parameter Validation Failure Cases" {
         It "unit: Remove-GitTag fails with empty RepoName" {
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            Remove-GitTag -RepoName "" -OrgName $OrgName -TagName $TagName -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
        }
    
        It "unit: Remove-GitTag fails with empty OrgName" {
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            Remove-GitTag -RepoName $RepoName -OrgName "" -TagName $TagName -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
        }
    
        It "unit: Remove-GitTag fails with empty TagName" {
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName "" -Token $Token
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
        }
    
        It "unit: Remove-GitTag fails with empty Token" {
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token ""
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Should -Contain "error-message=Missing required parameters: RepoName, OrgName, TagName, and Token must be provided."
        }    
    }

    Context "Exception Failure Cases" {
        It "unit: Remove-GitTag fails with exception" {
            Mock Invoke-WebRequest { throw "API Error" }  -ModuleName Remove-GitTag
            Mock Resolve-TagRefSuccess {} -ModuleName Resolve-TagRefSuccess
            
            try { 
                Remove-GitTag -RepoName $RepoName -OrgName $OrgName -TagName $TagName -Token $Token 
            } catch {}
            
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=failure"
            $output | Where-Object { $_ -match "error-message=Delete Git Tag threw an exception and failed." } | Should -Not -BeNullOrEmpty
        }
    }
}
