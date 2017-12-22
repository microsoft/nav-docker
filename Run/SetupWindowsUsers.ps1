# INPUT
#     $auth
#     $username (optional)
#     $password (optional)
#
# OUTPUT
#

if (($securePassword) -and $username -ne "") { 
    Write-Host "Creating Windows user $username"
    New-LocalUser -AccountNeverExpires -FullName $username -Name $username -Password $securePassword -ErrorAction Ignore | Out-Null
    Add-LocalGroupMember -Group administrators -Member $username -ErrorAction Ignore
}

