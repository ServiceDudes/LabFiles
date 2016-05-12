[string]$PFXDN           = "pfx.filemilk.net"
[string]$DestinationPath = "C:\PFXSite"

# Perform certificate request
Get-Certificate -Template DSCEncryption -CertstoreLocation Cert:\LocalMachine\My -SubjectName "CN=$($PFXDN)" -DnsName $PFXDN

# Validate and get installed certificate
$Certificate = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=$($PFXDN)"}

# Create a secure password for certificate export
$SecurePassword = ConvertTo-SecureString “P@ssw0rd” -AsPlainText -Force

# Export the PFX certificate file with private key
Export-PfxCertificate -Cert $Certificate.PSPath -Password $SecurePassword -FilePath "$($DestinationPath)\$($Certificate.Subject.TrimStart('CN=')).pfx" -ChainOption EndEntityCertOnly -Force

# Export the public CER certificate file
Export-Certificate -Cert $Certificate.PSPath -FilePath "$($DestinationPath)\$($Certificate.Subject.TrimStart('CN=')).cer" -Type CERT -Force

# Create a file with thumbprint
$Certificate.Thumbprint | Out-File "$($DestinationPath)\$($Certificate.Subject.TrimStart('CN=')).txt"

# Enable download for CER file extensions
Add-WebConfigurationProperty //staticContent -name collection -value @{fileExtension='.cer'; mimeType='application/octet-stream'}

# Remove the certificate from the local machine, only public used on the pull server
Remove-Item $Certificate.PSPath -Force