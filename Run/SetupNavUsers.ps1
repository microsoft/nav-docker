# INPUT
#     $auth
#     $username (optional)
#     $password (optional)
#
# OUTPUT
#

if ($auth -eq "Windows") {
    if ($username -ne "") {
        if (!(Get-NAVServerUser -ServerInstance NAV | Where-Object { $_.UserName.EndsWith("\$username", [System.StringComparison]::InvariantCultureIgnoreCase) -or $_.UserName -eq $username })) {
            Write-Host "Creating NAV user"
            New-NavServerUser -ServerInstance NAV -WindowsAccount $username
            New-NavServerUserPermissionSet -ServerInstance NAV -WindowsAccount $username -PermissionSetId SUPER
        }
    }
} else {
    if (!(Get-NAVServerUser -ServerInstance NAV | Where-Object { $_.UserName -eq $username })) {
        Write-Host "Creating NAV user"
        New-NavServerUser -ServerInstance NAV -Username $username -Password (ConvertTo-SecureString -String $password -AsPlainText -Force)
        New-NavServerUserPermissionSet -ServerInstance NAV -username $username -PermissionSetId SUPER
    }
}
