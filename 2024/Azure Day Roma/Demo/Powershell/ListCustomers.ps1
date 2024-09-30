<#
 #	Importa l'elenco dei clienti da Data API Builder via REST (JSON)
 #  e visualizza il risultato su griglia
 #>

$uri = "http://localhost:5000/api/Customers"

$response = Invoke-RestMethod -Method GET -Uri $uri -Headers @{Accept = 'application/json'}
$response.Value | Select-Object CustomerId, CompanyName, City, Country | out-gridview #Format-Table -AutoSize