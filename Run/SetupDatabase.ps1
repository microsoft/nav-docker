# INPUT
#     $bakFile (optional)
#     $runningGenericImage or $runningSpecificImage (not building or restarting)
#
# OUTPUT
#     $databaseServer
#     $databaseInstance
#     $databaseName
#

if ($restartInstance) {

    # Nothing to do

} else {
    $databaseServer = "localhost"
    $databaseInstance = ""
    if ($bakfile -ne "") 
    {
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
        $databaseName = "mydatabase"
        $restoreDb = $true
    
    } elseif ($runningGenericImage) {
        
        Write-Host "Restore CRONUS Demo Database"
        $bak = (Get-ChildItem -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\*.bak")[0]
        $databaseFile = $bak.FullName
        $databaseName = "CRONUS"
        $restoreDb = $true
    
    } elseif ($runningSpecificImage) {
    
        Write-Host "Using Existing Database"
        $databaseName = "CRONUS"
        $restoreDb = $false
    
    } else {
    
        Write-Error "ERROR: Internal Error"
        exit 1
    
    }

    if ($restoreDb) {
    
        # Restore database
        $databaseFolder = "c:\databases"
        if (!(Test-Path -Path $databaseFolder -PathType Container)) {
            New-Item -Path $databaseFolder -itemtype Directory | Out-Null
        }
    
        New-NAVDatabase -DatabaseServer $databaseServer `
                        -DatabaseInstance $databaseInstance `
                        -DatabaseName "$databaseName" `
                        -FilePath "$databaseFile" `
                        -DestinationPath "$databaseFolder" `
                        -Timeout $SqlTimeout | Out-Null
    }
}