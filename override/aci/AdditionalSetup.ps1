Write-Host "Creating Windows user $username"
New-LocalUser -AccountNeverExpires -PasswordNeverExpires -FullName $username -Name $username -Password $securePassword | Out-Null
Add-LocalGroupMember -Group administrators -Member $username

Write-Host "Configure WinRM on $publicDnsName with $certificateThumbprint"
winrm create winrm/config/Listener?Address=*+Transport=HTTPS ("@{Hostname=""$publicDnsName""; CertificateThumbprint=""$certificateThumbprint""}")
winrm set winrm/config/service/Auth '@{Basic="true"; Kerberos="false"; Negotiate="false"}'

