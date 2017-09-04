# INPUT
#     $auth
#     $username (optional)
#     $password (optional)
#
# OUTPUT
#

if ($password -ne "" -and $username -ne "") { 
    Write-Host "Create Windows user"
    New-LocalUser -AccountNeverExpires -FullName $username -Name $username -Password (ConvertTo-SecureString -AsPlainText -String $password -Force) -ErrorAction Ignore | Out-Null
    Add-LocalGroupMember -Group administrators -Member $username -ErrorAction Ignore
}

