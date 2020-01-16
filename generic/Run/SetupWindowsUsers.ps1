# INPUT
#     $auth
#     $username (optional)
#     $password (optional)
#
# OUTPUT
#

if ($auth -eq "Windows") {
    if (($securePassword) -and $username -ne "") { 
        Write-Host "Creating Windows user $username"
        New-LocalUser -AccountNeverExpires -PasswordNeverExpires -FullName $username -Name $username -Password $securePassword | Out-Null
        Add-LocalGroupMember -Group administrators -Member $username
    }
}

