param(
    [int]$Port = 3000
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Mock server listening on http://127.0.0.1:$Port..." -ForegroundColor Green

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.LocalPath
        $method = $request.HttpMethod

        Write-Host "Mock intercepted: $method $path" -ForegroundColor Cyan

        $responseJson = $null
        $statusCode = 200
        
        # HealthCheck endpoint: GET /HealthCheck
        if ($method -eq "GET" -and $path -eq "/HealthCheck") {
            $statusCode = 200
            $responseJson = @{ status = "ok" } | ConvertTo-Json
        }
        # GET Tag Reference
        elseif ($method -eq "GET" -and $path -match '^/repos/([^/]+)/([^/]+)/git/refs/tags/([^/]+)$') {
            $owner = $Matches[1]
            $repo = $Matches[2]
            $tag = $Matches[3]

            if ($tag -eq "notfound") {
                $statusCode = 404
                $responseJson = @{ message = "Not Found" } | ConvertTo-Json
            }
            elseif ($tag -eq "error") {
                $statusCode = 500
                $responseJson = @{ message = "Some Internal Error" } | ConvertTo-Json
            }
            else {
                $statusCode = 200
                $responseJson = @{
                    ref = "refs/tags/$tag"
                    node_id = "mock-node-id"
                    url = "https://api.github.com/repos/$owner/$repo/git/refs/tags/$tag"
                    object = @{
                        sha = "mocksha123"
                        type = "tag"
                    }
                } | ConvertTo-Json -Compress -Depth 10
            }
        }
        # DELETE Tag Reference
        elseif ($method -eq "DELETE" -and $path -match '^/repos/([^/]+)/([^/]+)/git/refs/tags/([^/]+)$') {
            $tag = $Matches[3]
            if ($tag -eq "error") {
                $statusCode = 500
                $responseJson = @{ message = "Delete Failed" } | ConvertTo-Json
            }
            elseif ($tag -eq "already-missing") {
                $statusCode = 404
                $responseJson = @{ message = "Tag not found" } | ConvertTo-Json
            }
            else {
                $statusCode = 204
                $responseJson = "" # No response body on success
            }
        }
        else {
            $statusCode = 404
            $responseJson = @{ message = "Not Found" } | ConvertTo-Json
        }

        # Send response
        $response.StatusCode = $statusCode
        $response.ContentType = "application/json"
        if ($statusCode -eq 204) {
            $response.ContentLength64 = 0
        }
        else {
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseJson)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        $response.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "Mock server stopped." -ForegroundColor Yellow
}