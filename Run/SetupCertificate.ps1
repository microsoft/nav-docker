# INPUT
#     $runPath
#
# OUTPUT
#     $certificateCerFile (if self signed)
#     $certificateThumbprint
#     $dnsIdentity
#

Write-Host "Create Self Signed Certificate"
$certificatePfxFile = Join-Path $runPath "certificate.pfx"
$certificateCerFile = Join-Path $runPath "certificate.cer"
$certificatePfxPassword = Get-RandomPassword
$SecurePfxPassword = ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force
New-SelfSignedCertificateEx -Subject "CN=$hostname" -IsCA $true -Exportable -Path $certificatePfxFile -Password $SecurePfxPassword | Out-Null
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePfxFile, $certificatePfxPassword)
Export-Certificate -Cert $cert -FilePath $CertificateCerFile | Out-Null
$certificateThumbprint = $cert.Thumbprint
Write-Host "Self Signed Certificate Thumbprint $certificateThumbprint"
Import-PfxCertificate -Password $SecurePfxPassword -FilePath $certificatePfxFile -CertStoreLocation "cert:\localMachine\my" | Out-Null
Import-PfxCertificate -Password $SecurePfxPassword -FilePath $certificatePfxFile -CertStoreLocation "cert:\localMachine\Root" | Out-Null
$dnsidentity = $cert.GetNameInfo('SimpleName',$false)
