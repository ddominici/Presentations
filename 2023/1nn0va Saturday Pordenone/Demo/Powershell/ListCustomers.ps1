$uri = "https://localhost:5001/api/Customers"

$response = Invoke-RestMethod -Method GET -Uri $uri -Headers @{Accept = 'application/json'}
$response.Value | Select-Object CustomerId, CompanyName, City, Country | out-gridview #Format-Table -AutoSize