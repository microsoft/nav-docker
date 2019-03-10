# INPUT
#     $auth
#     $databaseServer
#     $username (optional)
#     $securePassword (optional)
#
# OUTPUT
#

if ($securePassword) {
    Write-Host "Setting SA Password and enabling SA"
    $sqlcmd = "ALTER LOGIN sa with password='" + ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)).Replace('"','""').Replace('''','''''')) + "',CHECK_POLICY = OFF;ALTER LOGIN sa ENABLE;"
    Invoke-SqlCmd -ServerInstance "$databaseServer\$databaseInstance" -QueryTimeout 0 -ErrorAction Stop -Query $sqlcmd

	if ($auth -ne "Windows" -and $username -ne "") {
		Write-Host "Creating $username as SQL User and add to sysadmin"
		$sqlcmd = 
			"IF NOT EXISTS 
				(SELECT name  
				FROM master.sys.server_principals
				WHERE name = '$username')
			BEGIN
				CREATE LOGIN $username with password='" + ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)).Replace('"','""').Replace('''','''''')) + "',CHECK_POLICY = OFF
				EXEC sp_addsrvrolemember '$username', 'sysadmin'
			END

			ALTER LOGIN [$username] ENABLE
			GO"
			
		Invoke-SqlCmd -ServerInstance "$databaseServer\$databaseInstance" -QueryTimeout 0 -ErrorAction Stop -Query $sqlcmd
	}
} else {
	if ($auth -eq "Windows" -and $username -ne "") {
		Write-Host "Adding $username to sysadmin"
		$sqlcmd = 
			"IF NOT EXISTS 
				(SELECT name  
				FROM master.sys.server_principals
				WHERE name = '$username')
			BEGIN
				CREATE LOGIN [$username] FROM WINDOWS
				EXEC sp_addsrvrolemember '$username', 'sysadmin'
			END
			
			ALTER LOGIN [$username] ENABLE
			GO"
			
		Invoke-SqlCmd -ServerInstance "$databaseServer\$databaseInstance" -QueryTimeout 0 -ErrorAction Stop -Query $sqlcmd
	}
}
