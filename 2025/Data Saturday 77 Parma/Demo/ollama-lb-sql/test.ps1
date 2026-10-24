# You can run this PowerShell script on your Mac using pwsh (PowerShell Core).
# This script sends concurrent requests to the Ollama endpoint using parallel threads.

$totalWork = 4000
$threads = 4
$port = 443  # Change to 443 for load-balanced endpoint, 444 for single server, or 11434 for direct access
$endpoint = "https://127.0.0.1:$port/api/embed"
$payload = @{
    model = "nomic-embed-text"
    prompt = "test message for load balancer"
}
$headers = @{
    "Content-Type" = "application/json"
}

$jobs = @()
$requestsPerThread = [math]::Ceiling($totalWork / $threads)

$scriptBlock = {
    param($endpoint, $payload, $headers, $requestsPerThread, $threadId)
    $results = @()
    for ($j = 1; $j -le $requestsPerThread; $j++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body ($payload | ConvertTo-Json) -SkipCertificateCheck
            $sw.Stop()
            $duration = $sw.Elapsed.TotalSeconds
            $isLong = [double]$duration -ge 1
            $results += [PSCustomObject]@{
                Thread = $threadId
                Request = $j
                Success = $true
                Duration = $duration
                IsLong = $isLong
            }
            Write-Output "Thread $threadId - Request {$j}: Success ($duration s)"
            if ($isLong) {
                Write-Output "Thread $threadId - Request {$j}: Success (LONG: $duration s)"
            }
        } catch {
            $sw.Stop()
            $duration = $sw.Elapsed.TotalSeconds
            $results += [PSCustomObject]@{
                Thread = $threadId
                Request = $j
                Success = $false
                Duration = $duration
                IsLong = ([double]$duration -ge 1)
            }
            Write-Output "Thread $threadId - Request {$j}: Failed - $_ ($duration s)"
        }
    }
    return ,$results  # Ensure array is always returned
}

$startTime = Get-Date
for ($i = 1; $i -le $threads; $i++) {
    $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $endpoint, $payload, $headers, $requestsPerThread, $i
}

$jobs | ForEach-Object { Wait-Job $_ }
# Collect results from all jobs and flatten the array
$allResults = @()
foreach ($job in $jobs) {
    $jobResults = Receive-Job $job
    if ($jobResults -is [System.Array]) {
        $allResults += $jobResults
    } elseif ($jobResults) {
        $allResults += ,$jobResults
    }
}
$jobs | ForEach-Object { Remove-Job $_ }
$endTime = Get-Date

$totalSeconds = ($endTime - $startTime).TotalSeconds
$totalCalls = $allResults.Count
$callsPerSecond = if ($totalSeconds -gt 0) { [math]::Round($totalCalls / $totalSeconds, 2) } else { 0 }
$longCallCount = ($allResults | Where-Object { $_.Duration -ge 1 }).Count

Write-Output "`n--- Summary ---"
Write-Output "Total API calls: $totalCalls"
Write-Output "Total time (seconds): $totalSeconds"
Write-Output "API calls per second: $callsPerSecond"
Write-Output "Calls > 1 second: $longCallCount"