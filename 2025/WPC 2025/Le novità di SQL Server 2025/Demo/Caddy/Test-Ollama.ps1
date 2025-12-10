$body = @{
 model = "nomic-embed-text"
 input = "Who invented PowerShell and why?"
} | ConvertTo-Json -Depth 10 -Compress

# Send the POST request and save the response to a variable
Invoke-RestMethod -Uri "https://192.168.184.217:11443/api/embed" -Method Post -ContentType "application/json" -Body $body
