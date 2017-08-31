# INPUT
#     $auth
#     $username (optional)
#     $password (optional)
#
# OUTPUT
#

if ($auth -eq "Windows") {
    if ($passwordSpecified -and ($username -ne "")) {
        Write-Host "Create Windows user"
        New-LocalUser -AccountNeverExpires -FullName $username -Name $username -Password (ConvertTo-SecureString -AsPlainText -String $password -Force) -ErrorAction Ignore | Out-Null
        Add-LocalGroupMember -Group administrators -Member $username -ErrorAction Ignore
    }
    if ($username -ne "") {
        if (!(Get-NAVServerUser -ServerInstance NAV | Where-Object { $_.UserName.EndsWith("\$username", [System.StringComparison]::InvariantCultureIgnoreCase) -or $_.UserName -eq $username })) {
            Write-Host "Create NAV user"
            New-NavServerUser -ServerInstance NAV -WindowsAccount $username
            New-NavServerUserPermissionSet -ServerInstance NAV -WindowsAccount $username -PermissionSetId SUPER
        }
    }
} else {
    if ($username -eq "") { $username = "admin" }
    if (!(Get-NAVServerUser -ServerInstance NAV | Where-Object { $_.UserName -eq $username })) {
        New-NavServerUser -ServerInstance NAV -Username $username -Password (ConvertTo-SecureString -String $password -AsPlainText -Force)
        New-NavServerUserPermissionSet -ServerInstance NAV -username $username -PermissionSetId SUPER
        if (!$passwordSpecified) {
            Write-Host "NAV Admin Username  : $username"
            Write-Host "NAV Admin Password  : $password"
        }
    }
}
21304068