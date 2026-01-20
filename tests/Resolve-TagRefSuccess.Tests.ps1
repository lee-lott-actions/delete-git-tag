Import-Module "$PSScriptRoot/../modules/Resolve-TagRefSuccess.psm1" -Force

Describe "Resolve-TagRefSuccess" {

    BeforeEach {
        $env:GITHUB_OUTPUT = "$PSScriptRoot/github_output.temp"
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        $OrgName    = "my-org"
        $RepoName   = "my-repo"
        $TagName    = "v1.2.3"
        $headers    = @{ Authorization = "Bearer dummy-token" }
        $refUrl     = "https://api.example.com/repos/my-org/my-repo/git/refs/tags/v1.2.3"
    }

    AfterAll {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
    }

    It "handles prefix match (array) as not-found" {
        $content = @(
            @{ ref = "refs/tags/v1.2.3-SNAPSHOT" },
            @{ ref = "refs/tags/v1.2.3-alpha" }
        )
        Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $refUrl -headers $headers
        
        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=not-found"
        $output | Where-Object { $_ -match "not found \(prefix match" } | Should -Not -BeNullOrEmpty
    }

    It "deletes tag successfully and writes success to output" {
        $content = @{ ref = "refs/tags/$TagName" }
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 204; Content = "" }
        } -Verifiable -ModuleName Resolve-TagRefSuccess
        Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $refUrl -headers $headers

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=success"
    }

    It "writes failure for null DELETE response" {
        $content = @{ ref = "refs/tags/$TagName" }
        Mock Invoke-WebRequest { return $null } -Verifiable -ModuleName Resolve-TagRefSuccess

        Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $refUrl -headers $headers

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "Failed contacting GitHub API for tag deletion." } | Should -Not -BeNullOrEmpty
    }

    It "writes failure if DELETE response is not 204 and parses JSON error" {
        $content = @{ ref = "refs/tags/$TagName" }
        $errorMsgJson = '{"message":"API error while deleting"}'
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 422; Content = $errorMsgJson }
        } -ModuleName Resolve-TagRefSuccess
        
        Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $refUrl -headers $headers

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "Failed to delete tag: API error while deleting" } | Should -Not -BeNullOrEmpty
    }

    It "writes failure if DELETE response is not 204 and contains non-JSON error" {
        $content = @{ ref = "refs/tags/$TagName" }
        $errorMsg = "Something went wrong"
        Mock Invoke-WebRequest {
            [PSCustomObject]@{ StatusCode = 400; Content = $errorMsg }
        } -ModuleName Resolve-TagRefSuccess
        
        Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $refUrl -headers $headers

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=failure"
        $output | Where-Object { $_ -match "Failed to delete tag: $errorMsg" }
    }

    It "writes not-found if no exact match on ref property" {
        $content = @{ ref = "refs/tags/other-tag" }
        
        Resolve-TagRefSuccess -content $content -TagName $TagName -OrgName $OrgName -RepoName $RepoName -refUrl $refUrl -headers $headers

        $output = Get-Content $env:GITHUB_OUTPUT
        $output | Should -Contain "result=not-found"
        $output | Where-Object { $_ -match "not found \(response ref" } | Should -Not -BeNullOrEmpty
    }
}