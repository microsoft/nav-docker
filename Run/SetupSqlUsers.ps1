# INPUT
#     $auth
#     $databaseServer
#     $username (optional)
#     $password (optional)
#
# OUTPUT
#

if ($databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {

    $sqlcmd = "ALTER LOGIN sa with password=" +"'" + $password + "'" + ",CHECK_POLICY = OFF;ALTER LOGIN sa ENABLE;"
    & sqlcmd -S 'localhost\SQLEXPRESS' -Q $sqlcmd
    
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
            
        & sqlcmd -S 'localhost\SQLEXPRESS' -Q $sqlcmd
    }
}
