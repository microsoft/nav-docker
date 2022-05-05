# INPUT
#     $restartingInstance (optional)
#     $bakFile (optional)
#     $appBacpac and tenantBacpac (optional)
#     $databaseCredentials (optional)
#
# OUTPUT
#     $databaseServer
#     $databaseInstance
#     $databaseName
#

if ($restartingInstance) {

    # Nothing to do

} elseif ($bakfile -ne "") {

    # .bak file specified - restore and use
    # if bakfile specified, download, restore and use
    
    if ($bakfile.StartsWith("https://") -or $bakfile.StartsWith("http://"))
    {
        $bakfileurl = $bakfile
        $databaseFile = (Join-Path $runPath "mydatabase.bak")
        Write-Host "Downloading database backup file '$bakfileurl'"
        (New-Object System.Net.WebClient).DownloadFile($bakfileurl, $databaseFile)
    
    } else {

        Write-Host "Using Database .bak file '$bakfile'"
        if (!(Test-Path -Path $bakfile -PathType Leaf)) {
        	Write-Error "ERROR: Database Backup File not found."
            Write-Error "The file must be uploaded to the container or available on a share."
            exit 1
        }
        $databaseFile = $bakFile
    }

    Write-Host "Determining Database Collation $bakfile"
    $collation = (Invoke-Sqlcmd -ServerInstance localhost\SQLEXPRESS -ConnectionTimeout 300 -QueryTimeOut 300 "RESTORE HEADERONLY FROM DISK = '$bakfile'").Collation
    Write-Host "Database Collation is $collation"
    #SetDatabaseServerCollation -collation $collation
    
    # Restore database
    $databaseFolder = "c:\databases\my"
    
    if (!(Test-Path -Path $databaseFolder -PathType Container)) {
        New-Item -Path $databaseFolder -itemtype Directory | Out-Null
    }

    $databaseServerInstance = $databaseServer
    if ("$databaseInstance" -ne "") {
        $databaseServerInstance += "\$databaseInstance"
    }
    Write-Host "Using database server $databaseServerInstance"

    if (!$multitenant) {
        New-NAVDatabase -DatabaseServer $databaseServer `
                        -DatabaseInstance $databaseInstance `
                        -DatabaseName "$databaseName" `
                        -FilePath "$databaseFile" `
                        -DestinationPath "$databaseFolder" `
                        -Timeout $SqlTimeout | Out-Null

        Set-DatabaseCompatibilityLevel -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseName $databaseName

        if ($roleTailoredClientFolder -and (Test-Path "$roleTailoredClientFolder\finsql.exe")) {
            Start-Process -FilePath "$roleTailoredClientFolder\finsql.exe" -ArgumentList "Command=upgradedatabase, Database=$databaseName, ServerName=$databaseServerInstance, ntauthentication=1, logFile=c:\run\errorlog.txt" -Wait
        }
        else {
            Invoke-NAVApplicationDatabaseConversion -databaseServer $databaseServerInstance -databaseName $databaseName -Force | Out-Null
        }
    } else {
        New-NAVDatabase -DatabaseServer $databaseServer `
                        -DatabaseInstance $databaseInstance `
                        -DatabaseName "tenant" `
                        -FilePath "$databaseFile" `
                        -DestinationPath "$databaseFolder" `
                        -Timeout $SqlTimeout | Out-Null
    
        Set-DatabaseCompatibilityLevel -DatabaseServer $databaseServer -DatabaseInstance $databaseInstance -DatabaseName "tenant"

        if ($roleTailoredClientFolder -and (Test-Path "$roleTailoredClientFolder\finsql.exe")) {
            Start-Process -FilePath "$roleTailoredClientFolder\finsql.exe" -ArgumentList "Command=upgradedatabase, Database=$databaseName, ServerName=$databaseServerInstance, ntauthentication=1, logFile=c:\run\errorlog.txt" -Wait
        }
        else {
            Invoke-NAVApplicationDatabaseConversion -databaseServer $databaseServerInstance -databaseName "tenant" -force | Out-Null
        }

        Write-Host "Exporting Application to $DatabaseName"
        Invoke-sqlcmd -serverinstance $databaseServerInstance -Database "tenant" -query 'CREATE USER "NT AUTHORITY\SYSTEM" FOR LOGIN "NT AUTHORITY\SYSTEM";'
        Export-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -DestinationDatabaseName $databaseName -Force -ServiceAccount 'NT AUTHORITY\SYSTEM' | Out-Null
        Write-Host "Removing Application from tenant"
        Remove-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -Force | Out-Null
    }

} elseif ("$appBacpac" -ne "") {

    # appBacpac and tenantBacpac specified - restore and use

    if (Test-NavDatabase -DatabaseName "tenant") {
        Remove-NavDatabase -DatabaseName "tenant"
    }
    if (Test-NavDatabase -DatabaseName "default") {
        Remove-NavDatabase -DatabaseName "default"
    }
    
    $dbName = "app"
    $appBacpac, $tenantBacpac | % {
        if ($_) {
            if ($_.StartsWith("https://") -or $_.StartsWith("http://"))
            {
                $databaseFile = (Join-Path $runPath "${dbName}.bacpac")
                Write-Host "Downloading ${dbName}.bacpac"
                (New-Object System.Net.WebClient).DownloadFile($_, $databaseFile)
            } else {
                if (!(Test-Path -Path $_ -PathType Leaf)) {
            	    Write-Error "ERROR: Database Backup File not found."
                    Write-Error "The file must be uploaded to the container or available on a share."
                    exit 1
                }
                $databaseFile = $_
            }
            Restore-BacpacWithRetry -Bacpac $databaseFile -DatabaseName $dbName
        }
        $dbName = "tenant"
    }

    $databaseServer = "localhost"
    $databaseInstance = "SQLEXPRESS"
    $databaseName = "app"

    if ("$licenseFile" -eq "") {
        $licenseFile = Join-Path $serviceTierFolder "Cronus.flf"
    }

} elseif ($databaseCredentials) {

    if (Test-Path $myPath -PathType Container) {
        $EncryptionKeyFile = Join-Path $myPath 'DynamicsNAV.key'
    } else {
        $EncryptionKeyFile = Join-Path $runPath 'DynamicsNAV.key'
    }
    if (!(Test-Path $EncryptionKeyFile -PathType Leaf)) {
        New-NAVEncryptionKey -KeyPath $EncryptionKeyFile -Password $EncryptionSecurePassword -Force | Out-Null
    }

    Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "EnableSqlConnectionEncryption" -KeyValue "true" -WarningAction SilentlyContinue
    Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName "TrustSQLServerCertificate" -KeyValue "true" -WarningAction SilentlyContinue

    $databaseServerInstance = $databaseServer
    if ("$databaseInstance" -ne "") {
        $databaseServerInstance += "\$databaseInstance"
    }
    Write-Host "Import Encryption Key"
    Import-NAVEncryptionKey -ServerInstance $ServerInstance `
                            -ApplicationDatabaseServer $databaseServerInstance `
                            -ApplicationDatabaseCredentials $DatabaseCredentials `
                            -ApplicationDatabaseName $DatabaseName `
                            -KeyPath $EncryptionKeyFile `
                            -Password $EncryptionSecurePassword `
                            -WarningAction SilentlyContinue `
                            -Force
    
    Set-NavServerConfiguration -serverinstance $ServerInstance -databaseCredentials $DatabaseCredentials -WarningAction SilentlyContinue

} elseif ($databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS" -and $multitenant) {

    if (!(Test-NavDatabase -DatabaseName "tenant")) {
        Copy-NavDatabase -SourceDatabaseName $databaseName -DestinationDatabaseName "tenant"
        Remove-NavDatabase -DatabaseName $databaseName
        Write-Host "Exporting Application to $DatabaseName"
        Invoke-sqlcmd -serverinstance "$DatabaseServer\$DatabaseInstance" -Database tenant -query 'CREATE USER "NT AUTHORITY\SYSTEM" FOR LOGIN "NT AUTHORITY\SYSTEM";'
        Export-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -DestinationDatabaseName $databaseName -Force -ServiceAccount 'NT AUTHORITY\SYSTEM' | Out-Null
        Write-Host "Removing Application from tenant"
        Remove-NAVApplication -DatabaseServer $DatabaseServer -DatabaseInstance $DatabaseInstance -DatabaseName "tenant" -Force | Out-Null
    }
}

