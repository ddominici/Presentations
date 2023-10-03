Add-Type -assembly System.Windows.Forms

$main_form = New-Object System.Windows.Forms.Form
$main_form.Text ='Find a customer'
$main_form.Width = 600
$main_form.Height = 400
$main_form.AutoSize = $true

$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Pick a customer:"
$Label.Location  = New-Object System.Drawing.Point(10,12)
$Label.AutoSize = $true
$main_form.Controls.Add($Label)

$cboCustomers = New-Object System.Windows.Forms.ComboBox

$uri = "http://localhost:5000/api/Customers"

$response = Invoke-RestMethod -Method GET -Uri $uri -Headers @{Accept = 'application/json'}
$customers = $response.Value | Select-Object CustomerId, CompanyName, City, Country

Foreach ($c in $customers)
{
    $cboCustomers.Items.Add($c.CompanyName);
}

$cboCustomers.Width = 300
$cboCustomers.Location  = New-Object System.Drawing.Point(120,10)
$main_form.Controls.Add($cboCustomers)

$Button = New-Object System.Windows.Forms.Button
$Button.Location = New-Object System.Drawing.Size(430,12)
$Button.Size = New-Object System.Drawing.Size(120,23)
$Button.Text = "Find"
$main_form.Controls.Add($Button)

$lblCompanyName = New-Object System.Windows.Forms.Label
$lblCompanyName.Text = ""
$lblCompanyName.Location  = New-Object System.Drawing.Point(10,60)
$lblCompanyName.AutoSize = $true
$main_form.Controls.Add($lblCompanyName)

$lblCity = New-Object System.Windows.Forms.Label
$lblCity.Text = ""
$lblCity.Location  = New-Object System.Drawing.Point(10,80)
$lblCity.AutoSize = $true
$main_form.Controls.Add($lblCity)

$lblCountry = New-Object System.Windows.Forms.Label
$lblCountry.Text = ""
$lblCountry.Location  = New-Object System.Drawing.Point(10,100)
$lblCountry.AutoSize = $true
$main_form.Controls.Add($lblCountry)

$Button.Add_Click({
        $lblCompanyName.Text = "Company Name: " + $customers[$cboCustomers.SelectedIndex].CompanyName
        $lblCity.Text = "City: " + $customers[$cboCustomers.SelectedIndex].City
        $lblCountry.Text = "Country: " + $customers[$cboCustomers.SelectedIndex].Country
})

$main_form.ShowDialog()