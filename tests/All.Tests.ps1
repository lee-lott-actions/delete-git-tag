Write-Host "Running all module tests..."

. "$PSScriptRoot/Resolve-TagRefSuccess.Tests.ps1"
. "$PSScriptRoot/Remove-GitTag.Tests.ps1"

Write-Host "All tests completed."