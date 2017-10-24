# INPUT
#     $auth
#     $databaseServer
#     $username (optional)
#     $securePassword (optional)
#
# OUTPUT
#

if ($databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {

    if ($securePassword) {
        Write-Host "Enabling SA"
        $sqlcmd = "ALTER LOGIN sa with password=" +"'" + [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)) + "'" + ",CHECK_POLICY = OFF;ALTER LOGIN sa ENABLE;"
        & sqlcmd -S 'localhost\SQLEXPRESS' -Q $sqlcmd
    }
    
    if ($auth -eq "Windows" -and $username -ne "" -and (!($securePassword))) {
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
            
        & sqlcmd -S 'localhost\SQLEXPRESS' -Q $sqlcmd
    }
}
