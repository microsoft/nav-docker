# INPUT
#     $bakFile (optional)
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

    # Restore database
    if (!(Test-Path -Path $databaseFolder -PathType Container)) {
        New-Item -Path $databaseFolder -itemtype Directory | Out-Null
    }

    New-NAVDatabase -DatabaseServer $databaseServer `
                    -DatabaseInstance $databaseInstance `
                    -DatabaseName "$databaseName" `
                    -FilePath "$databaseFile" `
                    -DestinationPath "$databaseFolder" `
                    -Timeout $SqlTimeout | Out-Null

} elseif ($databaseCredentials) {

    if (Test-Path $myPath -PathType Container) {
        $EncryptionKeyFile = Join-Path $myPath 'DynamicsNAV.key'
    } else {
        $EncryptionKeyFile = Join-Path $runPath 'DynamicsNAV.key'
    }
    if (!(Test-Path $EncryptionKeyFile -PathType Leaf)) {
        New-NAVEncryptionKey -KeyPath $EncryptionKeyFile -Password $EncryptionSecurePassword -Force | Out-Null
    }

    Set-NAVServerConfiguration -ServerInstance "NAV" -KeyName "EnableSqlConnectionEncryption" -KeyValue "true" -WarningAction SilentlyContinue
    Set-NAVServerConfiguration -ServerInstance "NAV" -KeyName "TrustSQLServerCertificate" -KeyValue "true" -WarningAction SilentlyContinue

    Write-Host "Import Encryption Key"
    Import-NAVEncryptionKey -ServerInstance NAV `
                            -ApplicationDatabaseServer $databaseServer `
                            -ApplicationDatabaseCredentials $DatabaseCredentials `
                            -ApplicationDatabaseName $DatabaseName `
                            -KeyPath $EncryptionKeyFile `
                            -Password $EncryptionSecurePassword `
                            -WarningAction SilentlyContinue `
                            -Force
    
    Set-NavServerConfiguration -serverinstance "NAV" -databaseCredentials $DatabaseCredentials -WarningAction SilentlyContinue
}

