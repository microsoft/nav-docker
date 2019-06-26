$ErrorActionPreference = "Stop"
Write-Host "Importing DevPreview"

$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")
. (Join-Path $PSScriptRoot "ServiceSettings.ps1")

$SqlServiceName = 'MSSQL$SQLEXPRESS'
$SqlWriterServiceName = "SQLWriter"
$SqlBrowserServiceName = "SQLBrowser"

Write-Host "Downloading database"
$devPreviewFile = "C:\DEVPREVIEW.zip"
(New-Object System.Net.WebClient).DownloadFile("$env:DEVPREVIEWURL", $devPreviewFile)
[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
$devPreviewFolder = "$PSScriptRoot\DevPreview"
New-Item -Path $devPreviewFolder -ItemType Directory -ErrorAction Ignore | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($devPreviewFile, $devPreviewFolder)

$DatabaseServer = "localhost"
$DatabaseInstance = "SQLEXPRESS"
$modelXmlName = ''

Write-Host "Starting Local SQL Server"
Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
Start-Service -Name $SqlServiceName -ErrorAction Ignore

Write-Host "Remove CRONUS DB"
$cronusFiles = Get-NavDatabaseFiles -DatabaseName "CRONUS"
& sqlcmd -Q "ALTER DATABASE [CRONUS] SET OFFLINE WITH ROLLBACK IMMEDIATE"
& sqlcmd -Q "DROP DATABASE [CRONUS]"
$cronusFiles | % { remove-item $_.Path }

# Restore SaasBacpacs if any
$appBacpac = Get-Item -Path "$devPreviewFolder\*.App.Bacpac"
if ($appBacpac) {

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $modelXmlName = 'c:\run\model.xml'
    # open ZIP archive for reading
    $zip = [System.IO.Compression.ZipFile]::OpenRead($appBacpac.FullName)
    $zip.Entries | Where-Object { $_.name -eq 'model.xml' } | % { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $modelXmlName, $true) }
    $zip.Dispose()
    Remove-Variable zip

    $XPathForDBCollationNode = "/*[local-name()='DataSchemaModel']/*[local-name()='Model']/*[local-name()='Element'][@Type='SqlDatabaseOptions']/*[local-name()='Property'][@Name='Collation']/@Value"
    $dbCollationNode = Select-Xml -Path $modelXmlName -XPath $XPathForDBCollationNode
    $collation = $dbCollationNode.Node.Value

    SetDatabaseServerCollation -collation $collation

    $country = $appBacpac.Name.SubString(0, $appBacpac.Name.Length-11)
    $dbName = "$Country"
    $appDbName = "$Country.AppDb"

    Write-Host "Restore $appDbName"
    Restore-BacpacWithRetry -Bacpac "$devPreviewFolder\$Country.App.bacpac" -DatabaseName $appDbName
    Write-Host "Restore $dbName"
    Restore-BacpacWithRetry -Bacpac "$devPreviewFolder\$Country.Tenant.bacpac" -DatabaseName $dbName

    Write-Host "Remove App Part"
    Remove-NavApplication -DatabaseServer $DatabaseServer -DatabaseInstance $databaseInstance -DatabaseName $dbName -Force | Out-Null
    Write-Host "Import App Part"
    Invoke-sqlcmd -serverinstance "$DatabaseServer\$DatabaseInstance" -Database $appDbName -query 'CREATE USER "NT AUTHORITY\SYSTEM" FOR LOGIN "NT AUTHORITY\SYSTEM";'
    Export-NavApplication -DatabaseServer $DatabaseServer -DatabaseInstance $databaseInstance -DatabaseName $appDbName -DestinationDatabase $dbName -Force -ServiceAccount "NT AUTHORITY\SYSTEM" | Out-Null

    Write-Host "Remove App Database"
    $appDbFiles = Get-NavDatabaseFiles -DatabaseName $appDbName
    & sqlcmd -Q "ALTER DATABASE [$appDbName] SET OFFLINE WITH ROLLBACK IMMEDIATE"
    & sqlcmd -Q "DROP DATABASE [$appDbName]"
    $appDbFiles | % { remove-item $_.Path }

    & sqlcmd -d $dbName -Q 'update [dbo].[$ndo$tenantproperty] set tenantid=''default'''

    & sqlcmd -d $dbName -Q "IF EXISTS (SELECT 'X' FROM sysusers WHERE name = 'NT AUTHORITY\SYSTEM' and isntuser = 1)
              BEGIN DROP USER [NT AUTHORITY\SYSTEM] END"
    
    # Remove ConfigurationPackages and Extensions
    "ConfigurationPackages","TestToolKit","Extensions" | ForEach-Object {
        if (Test-Path "$devPreviewFolder\$_" -PathType Container) {
            if (Test-Path "c:\$_"-PathType Container) {
                # remove old folder if a new folder exists (or not w1)
                Write-Host "Remove old $_"
                Remove-Item "c:\$_" -Recurse -Force
            }
            Write-Host "Copy $_"
            Copy-Item -Path "$devPreviewFolder\$_" -Destination "c:\" -Recurse -Force
        }
    }

    Write-Host "Change DatabaseName Configuration to $dbname"
    $CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
    $CustomConfig = [xml](Get-Content $CustomConfigFile)
    $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value = "$dbName"
    $CustomConfig.Save($CustomConfigFile)

    Write-Host "Start Service Tier"
    Start-Service -Name $NavServiceName -WarningAction Ignore

    Write-Host "Import License file"
    $licensefile = (Get-Item "$devPreviewFolder\*.flf").FullName
    Import-NAVServerLicense -LicenseFile $licensefile -ServerInstance 'NAV' -Database NavDatabase -WarningAction SilentlyContinue

    $serverFile = "$ServiceTierFolder\Microsoft.Dynamics.Nav.Server.exe"
    $serverVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($serverFile)
    if ($serverVersion.FileMajorPart -lt 15) {
        $roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
        Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
    }
    else {
        Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
    }

    Write-Host "Uninstall apps"
    Get-NAVAppInfo NAV | Where-Object { $_.publisher -ne "Microsoft" } | Uninstall-NAVApp -WarningAction Ignore
    Write-Host "Unpublish apps"
    Get-NAVAppInfo NAV | Where-Object { $_.publisher -ne "Microsoft" } | Unpublish-NAVApp -ErrorAction Ignore
    Write-Host "Unpublish apps"
    Get-NAVAppInfo NAV | Where-Object { $_.publisher -ne "Microsoft" } | Unpublish-NAVApp -ErrorAction Ignore

    if ($serverVersion.FileMajorPart -lt 15) {
        Write-Host "Generate Symbol Reference"
        $pre = (get-process -Name "finsql" -ErrorAction Ignore) | % { $_.Id }
        Start-Process -FilePath "$roleTailoredClientFolder\finsql.exe" -ArgumentList "Command=generatesymbolreference, Database=$dbName, ServerName=$databaseServer\$databaseInstance, ntauthentication=1"
        $procs = get-process -Name "finsql" -ErrorAction Ignore
        $procs | Where-Object { $pre -notcontains $_.Id } | Wait-Process -Timeout 1800 -ErrorAction Ignore
    }
}

Write-Host "Cleanup"
Remove-Item $devPreviewFile -Force
Remove-Item $devPreviewFolder -Force -Recurse
if ($modelXmlName) {
    Remove-Item $modelXmlName -Force
}