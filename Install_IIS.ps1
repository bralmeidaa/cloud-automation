# Parameter to receive the ports
param (
    [string[]]$CustomPorts
)

# Convert the string of ports into an array
$CustomPorts = $CustomPorts -split ','

# Check and install IIS and Telnet if necessary
$features = @("Web-Server", "Web-Mgmt-Console", "Telnet-Client")
foreach ($feature in $features) {
    if (-not (Get-WindowsFeature -Name $feature).Installed) {
        Install-WindowsFeature -Name $feature
    }
}


# Add ports to IIS
Import-Module WebAdministration
if (-not (Test-Path IIS:\Sites\'Default Web Site')) {
    New-Website -Name "Default Web Site" -Port 80 -PhysicalPath "C:\inetpub\wwwroot"
}

foreach ($port in $CustomPorts) {
    if (-not (Get-WebBinding -Name "Default Web Site" | Where-Object { $_.bindingInformation -match ":$port" })) {
        New-WebBinding -Name "Default Web Site" -Protocol http -Port $port
    }
}

# Configure HTTPS with the correct certificate
$certs = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.FriendlyName -eq "TenantEncryptionCert" }
if ($certs.Count -gt 0) {
    $cert = $certs | Select-Object -First 1
    if (-not (Get-WebBinding -Name "Default Web Site" | Where-Object { $_.bindingInformation -match ":443:" })) {
        New-WebBinding -Name "Default Web Site" -Protocol https -Port 443
        $binding = Get-WebBinding -Name "Default Web Site" -Protocol https
        $binding.AddSslCertificate($cert.Thumbprint, "My")
    }
}

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
