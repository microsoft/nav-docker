# INPUT
#     $runPath
#
# OUTPUT
#     $certificateCerFile (if self signed)
#     $certificateThumbprint
#     $dnsIdentity
#

Write-Host "Creating Self Signed Certificate"
$cert = New-SelfSignedCertificate -DnsName @($publicDnsName, $hostName) -CertStoreLocation Cert:\LocalMachine\my

$certificatePfxPassword = Get-RandomPassword
$SecurePfxPassword = ConvertTo-SecureString -String $certificatePfxPassword -AsPlainText -Force

$certificatePfxFile = Join-Path $runPath "certificate.pfx"
$certificateCerFile = Join-Path $runPath "certificate.cer"

$path = "cert:\localMachine\my\$($cert.thumbprint)"
Export-PfxCertificate -Cert $cert -FilePath $certificatePfxFile -Password $SecurePfxPassword | Out-Null
Export-Certificate -Cert $cert -FilePath $CertificateCerFile | Out-Null

$certificateThumbprint = $cert.Thumbprint
Write-Host "Self Signed Certificate Thumbprint $certificateThumbprint"
Import-PfxCertificate -Password $SecurePfxPassword -FilePath $certificatePfxFile -CertStoreLocation "cert:\localMachine\TrustedPeople" | Out-Null

$dnsidentity = $cert.GetNameInfo('SimpleName',$false)
Write-Host "DNS identity $dnsidentity"
