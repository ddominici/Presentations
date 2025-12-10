<#
 # DEMO: Write to InfluxDB v2 using Powershell
 #
 # PLEASE FOLLOW THE WARNING INSTRUCTIONS BELOW IN THE CODE !!!!
 #>

# In order to write to Influxdb v2 we need the Authorization Token
# WARNING !!! This is an example. You must create a new API token and copy the token here, replacing the existing one
$Header = @{Authorization = "Token zLBah09_nej12ia2sEBGNM5oRJ_NXrgNsqCZoy47aT9KxoFdDlfQOC3l62jCofs5N-vHtrVglqIzxXd887P19w=="}

$temp = Get-Random -Minimum 18.0 -Maximum 26.0
$humidity = Get-random -Minimum 45.0 -Maximum 75.0

$i = 1
while ($i -lt 120)
{
    $increment1 = Get-Random -Minimum -2.0 -Maximum 2.0
    $increment2 = Get-Random -Minimum -2.0 -Maximum 2.0
    $temp = $temp + $increment1
    $humidity = $humidity + $increment2

    $body = "room1,room=living temp=$($temp),humidity=$($humidity)"
    Write-Output "temp=$($temp),humidity=$($humidity)"

    # WARNING !!! Remember to change the IP address, organization name and bucket name before running the example
    $response = Invoke-WebRequest -Uri 'http://192.168.184.51:8086/api/v2/write?org=PASS22&bucket=iot' -Headers $Header -Method POST -Body $body
    $i = $i + 1

    Start-Sleep -Milliseconds 1000
}