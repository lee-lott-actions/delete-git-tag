Import-Module "$PSScriptRoot/../modules/Resolve-TagRefSuccess.psm1" -Force

Describe "Resolve-TagRefSuccess" {
     BeforeAll {
        $script:OrgName    = "my-org"
        $script:RepoName   = "my-repo"
        $script:TagName    = "v1.2.3"
        $script:headers    = @{ Authorization = "Bearer dummy-token" }
        $script:MockApiUrl  = "http://127.0.0.1:3000"
    }
    
     BeforeEach {
         $env:GITHUB_OUTPUT = (New-TemporaryFile).FullName
         $env:MOCK_API = $script:MockApiUrl
         $script:refUrl = $env:MOCK_API + "/repos/my-org/my-repo/git/refs/tags/v1.2.3"
     }

     AfterEach {
         if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
         Remove-Item Env:MOCK_API -ErrorAction SilentlyContinue
     }

    Context "Multiple Git Tag Matches Found" {
        It "unit: Resolve-TagRefSuccess finds multiple refs but not an exact match for the TagName" {
            $content = @(
                @{ ref = "refs/tags/v1.2.3-SNAPSHOT" },
                @{ ref = "refs/tags/v1.2.3-alpha" }
            )
            Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $script:refUrl -headers $headers
            
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=not-found"
            $output | Where-Object { $_ -match "Warning: Tag '$TagName' does not exist. Only tags starting with '$TagName' exist." } | Should -Not -BeNullOrEmpty
        }    
    }

    Context "Exact Git Tag Match Found" {
        BeforeEach {
            $content = @{ ref = "refs/tags/$TagName" }
        }
        
        Context "Success Cases" {
            It "unit: Resolve-TagRefSuccess successfully deletes tag and writes success to output" {
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{ StatusCode = 204; Content = "" }
                } -Verifiable -ModuleName Resolve-TagRefSuccess
                Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $script:refUrl -headers $headers
        
                $output = Get-Content $env:GITHUB_OUTPUT
                $output | Should -Contain "result=success"
            }         
        }

        Context "Failure Cases" {
            It "unit: Resolve-TagRefSuccess returns failure for null DELETE response" {
                Mock Invoke-WebRequest { return $null } -Verifiable -ModuleName Resolve-TagRefSuccess
        
                Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $script:refUrl -headers $headers
        
                $output = Get-Content $env:GITHUB_OUTPUT
                $output | Should -Contain "result=failure"
                $output | Where-Object { $_ -match "Error: Failed contacting GitHub API for tag deletion." } | Should -Not -BeNullOrEmpty
            }
    
            It "writes failure if DELETE response is not 204 and parses JSON error" {
                $errorMsgJson = '{"message":"API error while deleting"}'
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{ StatusCode = 422; Content = $errorMsgJson }
                } -ModuleName Resolve-TagRefSuccess
                
                Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $script:refUrl -headers $headers
            
                $output = Get-Content $env:GITHUB_OUTPUT
                $output | Should -Contain "result=failure"
                $output | Where-Object { $_ -match "Error: Failed to delete tag '$TagName'. Status: 422. Message: API error while deleting" } | Should -Not -BeNullOrEmpty
            }
        
            It "writes failure if DELETE response is not 204 and contains non-JSON error" {
                $errorMsg = "Something went wrong"
                Mock Invoke-WebRequest {
                    [PSCustomObject]@{ StatusCode = 400; Content = $errorMsg }
                } -ModuleName Resolve-TagRefSuccess
                
                Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $script:refUrl -headers $headers
        
                $output = Get-Content $env:GITHUB_OUTPUT
                $output | Should -Contain "result=failure"
                $output | Where-Object { $_ -match "Error: Failed to delete tag '$TagName'. Status: 400. Message: Something went wrong" } | Should -Not -BeNullOrEmpty
            }        
        }
    }

    Context "Exact Git Tag Match Not Found" {
        It "unit: Resolve-TagRefSuccess does not find a match" {
            $content = @{ ref = "refs/tags/other-tag" }
            
            Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $script:refUrl -headers $headers
    
            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "result=not-found"
            $output | Where-Object { $_ -match "Error: Tag '$TagName' not found" } | Should -Not -BeNullOrEmpty
        }    
    }
}
