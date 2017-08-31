# INPUT
#     $auth
#     $databaseServer
#     $username (optional)
#     $password (optional)
#
# OUTPUT
#

if ($databaseServer -eq "localhost") {
    if ($password -ne "") {
        $sqlcmd = "ALTER LOGIN sa with password=" +"'" + $password + "'" + ",CHECK_POLICY = OFF;ALTER LOGIN sa ENABLE;"

        if ($databaseInstance) {
            & sqlcmd -S "$databaseServer\$databaseInstance" -Q $sqlcmd
        } else {
            & sqlcmd -S $databaseServer -Q $sqlcmd
        }

    }
    
    if ($username.Contains('\') -and $auth -eq "Windows") {
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
            
            if ($databaseInstance) {
                & sqlcmd -S "$databaseServer\$databaseInstance" -Q $sqlcmd
            } else {
                & sqlcmd -S $databaseServer -Q $sqlcmd
            }
    }
}
