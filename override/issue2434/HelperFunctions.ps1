$SqlServiceName = 'MSSQL$SQLEXPRESS'
$SqlWriterServiceName = "SQLWriter"
$SqlBrowserServiceName = "SQLBrowser"
$IisServiceName = "W3SVC"

function randomchar([string]$str)
{
    $rnd = Get-Random -Maximum $str.length
    [string]$str[$rnd]
}

function Get-RandomPassword {
    $cons = 'bcdfghjklmnpqrstvwxz'
    $voc = 'aeiouy'
    $numbers = '0123456789'

    ((randomchar $cons).ToUpper() + `
     (randomchar $voc) + `
     (randomchar $cons) + `
     (randomchar $voc) + `
     (randomchar $numbers) + `
     (randomchar $numbers) + `
     (randomchar $numbers) + `
     (randomchar $numbers))
}

function WaitForService
(
    [string]$ServiceName
)
{
    Write-Host "Wait for $ServiceName to start"
    while ((Get-service -name $ServiceName).Status -ne 'Running') { 
        Start-Sleep -Seconds 5
    }
    Write-Host "$ServiceName started"

}

function Get-WWWRootPath
{
    $wwwRootPath = (Get-Item "HKLM:\SOFTWARE\Microsoft\InetStp").GetValue("PathWWWRoot")
    $wwwRootPath = [System.Environment]::ExpandEnvironmentVariables($wwwRootPath)

    return $wwwRootPath
}

function Get-gMSAName
{
    <#
        This function will return gMSA account name.
        All NT AUTHORITY\NETWORK SERVICES or NT AUTHORITY\SYSTEM will act as gMSA to be able interact with the domain resources.
    #>

    [CmdletBinding()]
    param(        
    )

    $gMSA = ((Get-WmiObject -Class Win32_NTDomain) | Where-Object { $_.DomainName -ne $null }).DomainName + "\" + $env:COMPUTERNAME + "$"

    return $gMSA
}

function Restore-BacpacWithRetry
{
	Param
	(
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseInstance = "SQLEXPRESS",
		[Parameter(Mandatory=$true)]
		[string]$DatabaseName,
		[Parameter(Mandatory=$True)]
		[string]$Bacpac,
		[Parameter(Mandatory=$false)]
		[int]$maxattempts = 10
    )

    $dacdll = Get-Item "C:\Program Files\Microsoft SQL Server\*\DAC\bin\Microsoft.SqlServer.Dac.dll"
    if (!($dacdll))
    {
        InstallPrerequisite -Name "Dac Framework 18.2" -MsiPath "c:\download\DacFramework.msi" -MsiUrl "https://download.microsoft.com/download/9/2/2/9228AAC2-90D1-4F48-B423-AF345296C7DD/EN/x64/DacFramework.msi" | Out-Null
        $dacdll = Get-Item "C:\Program Files\Microsoft SQL Server\*\DAC\bin\Microsoft.SqlServer.Dac.dll"
    }
    Add-Type -path $dacdll.FullName
    $conn = "Data Source=$DatabaseServer\$DatabaseInstance;Initial Catalog=master;Connection Timeout=0;Integrated Security=True;"

    $attempt = 0
    while ($true) {
        try {
            $attempt++
            Write-Host "Restoring Database from $Bacpac as $DatabaseName"
            $AppimportBac = New-Object Microsoft.SqlServer.Dac.DacServices $conn
            $ApploadBac = [Microsoft.SqlServer.Dac.BacPackage]::Load($Bacpac)
            $AppimportBac.ImportBacpac($ApploadBac, $DatabaseName)
            break
        } catch {
            if ($attempt -ge $maxattempts) {
                Write-Warning "Error restoring Database, giving up..."
                throw
            }
            Write-Warning "Error restoring Database, retrying"
            Start-Sleep -Seconds (30*$attempt)
        }
    }
}

function Get-NavDatabaseFiles
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    Invoke-SqlCmdWithRetry -Query "SELECT f.physical_name FROM sys.sysdatabases db INNER JOIN sys.master_files f ON f.database_id = db.dbid WHERE db.name = '$DatabaseName'" | % {
        $file = $_.physical_name
        if (Test-Path $file)
        {
            $file = Resolve-Path $file
        }
        $file
    }
}

function Get-UniqueFilename
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$Filename
    )

    [System.IO.FileInfo]$FileInfo = $Filename
    $SeqNo=1

    while (test-path $Filename)
    {
        $Filename = "{0}\{1}_{2}{3}" -f $FileInfo.DirectoryName,$FileInfo.BaseName,$SeqNo,$FileInfo.Extension
        $SeqNo++
    }
    $Filename
}
function Copy-NavDatabase
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseInstance = "SQLEXPRESS",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$databaseCredentials,
        [Parameter(Mandatory=$true)]
        [string]$SourceDatabaseName,
        [Parameter(Mandatory=$true)]
        [string]$DestinationDatabaseName
    )

    $DatabaseServerInstance = "$DatabaseServer"
    if ("$DatabaseInstance" -ne "") {
        $DatabaseServerInstance += "\$DatabaseInstance"
    }

    Write-Host "Copying Database on $DatabaseServerInstance from $SourceDatabaseName to $DestinationDatabaseName"

    if (Test-NavDatabase -DatabaseServer $databaseServer `
                         -DatabaseInstance $databaseInstance `
                         -DatabaseCredentials $databaseCredentials `
                         -DatabaseName $DestinationDatabaseName)
    {
        Remove-NavDatabase -DatabaseServer $databaseServer `
                           -DatabaseInstance $databaseInstance `
                           -DatabaseCredentials $databaseCredentials `
                           -DatabaseName $DestinationDatabaseName
    }

    if ($DatabaseServer -eq "localhost" -and $DatabaseInstance -eq "SQLEXPRESS") {

        try
        {
            Write-Host "Taking database $SourceDatabaseName offline"
            Invoke-SqlCmdWithRetry -Query ("ALTER DATABASE [{0}] SET OFFLINE WITH ROLLBACK IMMEDIATE" -f $SourceDatabaseName)
    
            Write-Host "Copying database files"
            $files = ""
            Get-NavDatabaseFiles -DatabaseName $SourceDatabaseName | % {
                $FileInfo = Get-Item -Path $_
                $DestinationFile = "{0}\{1}{2}" -f $FileInfo.DirectoryName, $DestinationDatabaseName, $FileInfo.Extension
                $DestinationFile = Get-UniqueFilename -Filename $DestinationFile
                Copy-Item -Path $FileInfo.FullName -Destination $DestinationFile -Force
                if ("$files" -ne "") { $files += ", " }
                $Files += "(FILENAME = N'$DestinationFile')"                
            }
    
            Write-Host "Attaching files as new Database $DestinationDatabaseName"
            Invoke-SqlCmdWithRetry -Query ("CREATE DATABASE [{0}] ON {1} FOR ATTACH" -f $DestinationDatabaseName, $Files.ToString())
        }
        finally
        {
            Write-Host "Putting database $SourceDatabaseName back online"
            Invoke-SqlCmdWithRetry -Query ("ALTER DATABASE [{0}] SET ONLINE" -f $SourceDatabaseName)
        }

    } else {

        $engineEdition = (Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                                 -DatabaseInstance $databaseInstance `
                                                 -DatabaseCredentials $databaseCredentials `
                                                 -Query "select SERVERPROPERTY('EngineEdition')").Column1

        Write-Host "EngineEdition $engineEdition"
        if ("$engineEdition" -eq "5") {

            # Azure SQL
            Write-Host "Creating $DestinationDatabaseName on $DatabaseServerInstance as copy of $SourceDatabaseName"
            Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                   -DatabaseInstance $databaseInstance `
                                   -DatabaseCredentials $databaseCredentials `
                                   -Query "CREATE Database [$DestinationDatabaseName] AS COPY OF [$SourceDatabaseName];"
        
            Write-Host "Waiting for Database copy to complete"
            $sqlCommandText = "select * from sys.dm_database_copies"
            while ((Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                    -DatabaseInstance $databaseInstance `
                                    -DatabaseCredentials $databaseCredentials `
                                    -Query $sqlCommandText) -ne $null) {
                Start-Sleep -Seconds 10
            }
        } else {

            $files = Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                   -DatabaseInstance $databaseInstance `
                                   -DatabaseCredentials $databaseCredentials `
                                   -Query "SELECT f.Name,f.Physical_name FROM sys.sysdatabases db INNER JOIN sys.master_files f ON f.database_id = db.dbid WHERE db.name = '$SourceDatabaseName'"
            $dbfolder = [System.IO.Path]::GetDirectoryName($files[0].Physical_name).TrimEnd('\')

            $backupQuery = "backup database [$SourceDatabaseName] to disk = '$dbfolder\$sourceDatabaseName.bak' with init, stats=10;"
            Write-Host $backupQuery
            Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                   -DatabaseInstance $databaseInstance `
                                   -DatabaseCredentials $databaseCredentials `
                                   -Query $backupQuery

            $move = (($files | % { $_.name+[System.IO.Path]::GetExtension($_.physical_name) }) -join "', move '").Replace(".mdf","' to '$dbfolder\$DestinationDatabaseName.mdf").Replace(".ldf","' to '$dbfolder\$DestinationDatabaseName.ldf")

            $restoreQuery = "restore database [$DestinationDatabaseName] from disk = '$dbfolder\$sourceDatabaseName.bak' with stats=10, recovery, move '$move'"
            Write-Host $restoreQuery
            Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                   -DatabaseInstance $databaseInstance `
                                   -DatabaseCredentials $databaseCredentials `
                                   -Query $restoreQuery
        }
    }
}

function Test-NavDatabase
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseInstance = "SQLEXPRESS",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$databaseCredentials,
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    $sqlCommandText = @"
USE [master]
SELECT '1' FROM sys.sysdatabases WHERE name = '$DatabaseName'
GO
"@

    return ((Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                    -DatabaseInstance $databaseInstance `
                                    -DatabaseCredentials $databaseCredentials `
                                    -Query $sqlCommandText) -ne $null)
}

function Remove-NavDatabase
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseInstance = "SQLEXPRESS",
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$databaseCredentials,
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    $DatabaseServerInstance = "$DatabaseServer"
    if ("$DatabaseInstance" -ne "") {
        $DatabaseServerInstance += "\$DatabaseInstance"
    }

    Write-Host "Removing Database $DatabaseName from $DatabaseServerInstance"
 
    $DatabaseFiles = @()
    if ($DatabaseServer -eq "localhost") {
        # Get database files in case they are not removed by the DROP
        $DatabaseFiles = Get-NavDatabaseFiles -DatabaseName $DatabaseName

        # SQL Express - take database offline
        Invoke-SqlCmdWithRetry -Query "ALTER DATABASE [$DatabaseName] SET OFFLINE WITH ROLLBACK IMMEDIATE"
    }
 
    Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                           -DatabaseInstance $databaseInstance `
                           -DatabaseCredentials $databaseCredentials `
                           -Query "DROP DATABASE [$DatabaseName]"
 
    # According to MSDN database files are not removed after dropping an offline database, we need to manually delete them
    $DatabaseFiles | ? { Test-Path $_ } | Remove-Item -Force

}

function Mount-NavDatabase
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string] $ServerInstance = "NAV",
        [Parameter(Mandatory=$true)]
        [string] $TenantId,
        [Parameter(Mandatory=$false)]
        [string] $DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string] $DatabaseInstance = "SQLEXPRESS",
        [Parameter(Mandatory=$true)]
        [string] $DatabaseName,
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] $databaseCredentials,
        [Parameter(Mandatory=$false)]
        [string[]] $AlternateId = @(),
        [Parameter(Mandatory=$false)]
        [string] $AadTenantId,
        [switch] $allowAppDatabaseWrite,
        [string] $applicationInsightsInstrumentationKey = ""
    )

    $DatabaseServerInstance = "$DatabaseServer"
    if ("$DatabaseInstance" -ne "") {
        $DatabaseServerInstance += "\$DatabaseInstance"
    }

    $Params = @{ "Force"=$true }
    if ($TenantId -eq "default") {
        $allowAppDatabaseWrite = $defaultTenantHasAllowAppDatabaseWrite -or $allowAppDatabaseWrite
    }
    $Params += @{"AllowAppDatabaseWrite" = $allowAppDatabaseWrite }
    Write-Host "Mounting Database for $TenantID on server $DatabaseServerInstance with AllowAppDatabaseWrite = $allowAppDatabaseWrite"
    if ($DatabaseCredentials) {
        $Params += @{ "DatabaseCredentials"=$DatabaseCredentials }
    }
    
    $CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
    $CustomConfig = [xml](Get-Content $CustomConfigFile)
    $tenantEnvironmentType = $customConfig.SelectSingleNode("//appSettings/add[@key='TenantEnvironmentType']")
    if ($tenantEnvironmentType -ne $null) {
        $Params += @{"EnvironmentType" = $tenantEnvironmentType.value }
    }
    if ($applicationInsightsInstrumentationKey) {
        $Params += @{"ApplicationInsightsKey" = $applicationInsightsInstrumentationKey }
    }
    if ($AadTenantId) {
        $Params += @{"AadTenantId" = $AadTenantId }
    }

    Mount-NAVTenant -ServerInstance $ServerInstance `
                    -DatabaseServer $DatabaseServer `
                    -DatabaseInstance $DatabaseInstance `
                    -DatabaseName $DatabaseName `
                    -Id $TenantID `
                    -AlternateId $AlternateId `
                    -OverwriteTenantIdInDatabase @Params

    Write-Host "Sync'ing Tenant"    
    Sync-NAVTenant  -ServerInstance $ServerInstance `
                    -Tenant $TenantId `
                    -Force
}

function Invoke-SqlCmdWithRetry
{
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseInstance = "SQLEXPRESS",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseName,
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$databaseCredentials,
        [Parameter(Mandatory=$true)]
        [string]$Query,
        [int]$maxattempts = 0
    )

    $DatabaseServerInstance = "$DatabaseServer"
    if ("$DatabaseInstance" -ne "") {
        $DatabaseServerInstance += "\$DatabaseInstance"
    }
    $DatabaseServerParams = @{
        'ServerInstance' = $DatabaseServerInstance
        'QueryTimeout' = 0
        'ea' = 'stop'
    }
    if ($databaseCredentials) {
        $DatabaseServerParams += @{ 'Username' = $databaseCredentials.UserName; 'Password' = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($databaseCredentials.Password))) }
    }

    if ($maxattempts -eq 0) {
        $maxattempts = 10
        if ($DatabaseServer -eq 'localhost') {
            $maxattempts = 3
        }
    }
    $attempt = 1
    $success = $false
    while (!$success) {
        try
        {
            if ($DatabaseName) {
                Invoke-SqlCmd @DatabaseServerParams -Database $DatabaseName -Query $Query
            } else {
                Invoke-SqlCmd @DatabaseServerParams -Query $Query
            }
            $success = $true
        }
        catch {
            if ($attempt -ge $maxattempts) {
                Write-Host -ForegroundColor Red "Error when running: $Query"
                throw    
            }
            Write-Host -ForegroundColor Yellow  "Warning, exception when running: $Query"
            Write-Host -ForegroundColor Yellow "Exception was: $($_.Exception.Message)"
            Write-Host -NoNewline "Waiting"
            1..$attempt*3 | % {
                Start-Sleep -Seconds 10
                Write-Host -NoNewline "."
            }
            Write-Host " - retrying"
            $attempt = $attempt + 1
        }
    }
}

function Copy-ItemMultiDest()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$Source,
        [Parameter(Mandatory=$true)]
        [string[]]$Destination,
        [Parameter(Mandatory=$false)]
        [switch]$Confirm=$false,
        [Parameter(Mandatory=$false)]
        [switch]$Force=$false,
        [Parameter(Mandatory=$false)]
        [switch]$Recurse=$false
    )

    $Destination | ForEach-Object { Microsoft.PowerShell.Management\Copy-Item $Source -Destination $_ -Confirm:$Confirm -Force:$Force -Recurse:$Recurse -ErrorAction Ignore }
}

function set-DatabaseCompatibilityLevel
{
    Param(
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseInstance = "SQLEXPRESS",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseName
    )

    Write-Host "Setting CompatibilityLevel for $databaseName on $databaseServer\$databaseInstance"
    Import-Module 'sqlps'

    $databaseServerInstance = $DatabaseServer
    if ($DatabaseInstance) {
        $databaseServerInstance += "\$DatabaseInstance"
    }

    $smoServer = New-Object Microsoft.SqlServer.Management.Smo.Server $databaseServerInstance
    $smoServer.Databases[$databaseName].CompatibilityLevel = $smoServer.Databases['model'].CompatibilityLevel
    $smoServer.Databases[$databaseName].Alter()
}

function Install-NAVSipCryptoProvider
{
    $sipPath = "C:\Windows\System32\NavSip.dll"
    Test-Path -Path $sipPath -ErrorAction Stop | Out-Null

    Write-Host "Installing SIP crypto provider: '$sipPath'"

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllCreateIndirectData\{36FFA03E-F824-48E7-8E07-4A2DCB034CC7}'
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'Dll' -Value $sipPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'FuncName' -Value 'NavSIPCreateIndirectData' -Force | Out-Null

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetCaps\{36FFA03E-F824-48E7-8E07-4A2DCB034CC7}'
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'Dll' -Value $sipPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'FuncName' -Value 'NavSIPGetCaps' -Force | Out-Null

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg\{36FFA03E-F824-48E7-8E07-4A2DCB034CC7}'
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'Dll' -Value $sipPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'FuncName' -Value 'NavSIPGetSignedDataMsg' -Force | Out-Null

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllIsMyFileType2\{36FFA03E-F824-48E7-8E07-4A2DCB034CC7}'
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'Dll' -Value $sipPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'FuncName' -Value 'NavSIPIsFileSupportedName' -Force | Out-Null

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllPutSignedDataMsg\{36FFA03E-F824-48E7-8E07-4A2DCB034CC7}'
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'Dll' -Value $sipPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'FuncName' -Value 'NavSIPPutSignedDataMsg' -Force | Out-Null

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllRemoveSignedDataMsg\{36FFA03E-F824-48E7-8E07-4A2DCB034CC7}'
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'Dll' -Value $sipPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'FuncName' -Value 'NavSIPRemoveSignedDataMsg' -Force | Out-Null

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllVerifyIndirectData\{36FFA03E-F824-48E7-8E07-4A2DCB034CC7}'
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'Dll' -Value $sipPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -PropertyType string -Name 'FuncName' -Value 'NavSIPVerifyIndirectData' -Force | Out-Null
}

function GetMsiProductName([string]$path) {
    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $database = $installer.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $installer, @($path, 0))
        $query = "SELECT * FROM Property WHERE Property = 'ProductName'"
        $view = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $database, $query)
        $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null) | Out-Null
        $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        $name = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 2)
        return $name.Trim()
    } catch {
        throw "Failed to get MSI file version the error was: {0}." -f $_
    } finally {
        [Void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($installer)
    }
}

function Set-ConfigSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$customSettings,
        [Parameter(Mandatory=$true)]
        [string]$parentPath,
        [Parameter(Mandatory=$true)]
        [string] $leafName,
        [Parameter(Mandatory=$true)]
        [xml]$customConfig,
        [switch]$silent
    )

    $customSettingsArray = $customSettings -split ","

    foreach ($customSetting in $customSettingsArray) {
        $customSettingArray = $customSetting -split "="
        $customSettingKey = $customSettingArray[0]
        $customSettingValue = $customSettingArray[1]
        
        if ($customConfig.SelectSingleNode("$parentPath/$leafName[@key='$customSettingKey']") -eq $null) {
            if (!$silent) {
                Write-Host "Creating $customSettingKey and setting it to $customSettingValue"
            }
            [xml] $tmpDoc = [xml] ""
            $tmpDoc.LoadXml("<add key='$customSettingKey' value='$customSettingValue' />") | Out-Null
            $tmpNode = $customConfig.ImportNode($tmpDoc.get_DocumentElement(), $true)
            $customConfig.SelectSingleNode($parentPath).AppendChild($tmpNode) | Out-Null
        } else {
            if (!$silent) {
                Write-Host "Setting $customSettingKey to $customSettingValue"
            }
            $customConfig.SelectSingleNode("$parentPath/$leafName[@key='$customSettingKey']").Value = "$customSettingValue"
        }
    }
}

function InstallPrerequisite {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$MsiPath,
        [Parameter(Mandatory=$true)]
        [string]$MsiUrl
    )

    if (!(Test-Path $MsiPath)) {
        Write-Host "Downloading $Name"
        $MsiFolder = [System.IO.Path]::GetDirectoryName($MsiPath)
        if (!(Test-Path $MsiFolder)) {
            New-Item -Path $MsiFolder -ItemType Directory | Out-Null
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        (New-Object System.Net.WebClient).DownloadFile($MsiUrl, $MsiPath)
    }
    Write-Host "Installing $Name"
    start-process $MsiPath -ArgumentList "/quiet /qn /passive" -Wait
}

function SetDatabaseServerCollation {
    Param(
        [string] $collation
    )
    # Left empty if anybody uses the file for override in older generic images
}

function Download-File {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $sourceUrl,
        [Parameter(Mandatory=$true)]
        [string] $destinationFile,
        [switch] $dontOverwrite
    )

    $replaceUrls = @{
        "https://go.microsoft.com/fwlink/?LinkID=844461" = "https://bcartifacts.azureedge.net/prerequisites/DotNetCore.1.0.4_1.1.1-WindowsHosting.exe"
        "https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi" = "https://bcartifacts.azureedge.net/prerequisites/rewrite_2.0_rtw_x64.msi"
        "https://download.microsoft.com/download/5/5/3/553C731E-9333-40FB-ADE3-E02DC9643B31/OpenXMLSDKV25.msi" = "https://bcartifacts.azureedge.net/prerequisites/OpenXMLSDKv25.msi"
        "https://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi" = "https://bcartifacts.azureedge.net/prerequisites/ReportViewer.msi"
        "https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x86/SQLSysClrTypes.msi" = "https://bcartifacts.azureedge.net/prerequisites/SQLSysClrTypes.msi"
    }

    if ($replaceUrls.ContainsKey($sourceUrl)) {
        $sourceUrl = $replaceUrls[$sourceUrl]
    }

    if (Test-Path $destinationFile -PathType Leaf) {
        if ($dontOverwrite) { 
            return
        }
        Remove-Item -Path $destinationFile -Force
    }
    $path = [System.IO.Path]::GetDirectoryName($destinationFile)
    if (!(Test-Path $path -PathType Container)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host "Downloading $destinationFile"
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}

function Download-Artifacts {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $artifactUrl,
        [switch] $includePlatform,
        [switch] $force,
        [switch] $forceRedirection,
        [string] $basePath = 'c:\dl'
    )

    if (-not (Test-Path $basePath)) {
        New-Item $basePath -ItemType Directory | Out-Null
    }

    do {
        $redir = $false
        $appUri = [Uri]::new($artifactUrl)

        $appArtifactPath = Join-Path $basePath $appUri.AbsolutePath
        $exists = Test-Path $appArtifactPath
        if ($exists -and $force) {
            Remove-Item $appArtifactPath -Recurse -Force
            $exists = $false
        }
        if ($exists -and $forceRedirection) {
            $appManifestPath = Join-Path $appArtifactPath "manifest.json"
            $appManifest = Get-Content $appManifestPath | ConvertFrom-Json
            if ($appManifest.PSObject.Properties.name -eq "applicationUrl") {
                Remove-Item $appArtifactPath -Recurse -Force
                $exists = $false
            }
        }
        if (-not $exists) {
            Write-Host "Downloading application artifact $($appUri.AbsolutePath)"
            $appZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
            try {
                Download-File -sourceUrl $artifactUrl -destinationFile $appZip
            }
            catch {
                if ($artifactUrl.Contains('.azureedge.net/')) {
                    $artifactUrl = $artifactUrl.Replace('.azureedge.net/','.blob.core.windows.net/')
                    Write-Host "Retrying download..."
                    Download-File -sourceUrl $artifactUrl -destinationFile $appZip
                }
            }
            Write-Host "Unpacking application artifact"
            Expand-Archive -Path $appZip -DestinationPath $appArtifactPath -Force
            Remove-Item -path $appZip -force
        }
        try { [System.IO.File]::WriteAllText((Join-Path $appArtifactPath 'lastused'), "$([datetime]::UtcNow.Ticks)") } catch {}

        $appManifestPath = Join-Path $appArtifactPath "manifest.json"
        $appManifest = Get-Content $appManifestPath | ConvertFrom-Json

        if ($appManifest.PSObject.Properties.name -eq "applicationUrl") {
            $redir = $true
            $artifactUrl = $appManifest.ApplicationUrl
            if ($artifactUrl -notlike 'https://*') {
                $artifactUrl = "https://$($appUri.Host)/$artifactUrl$($appUri.Query)"
            }
        }

    } while ($redir)

    $appArtifactPath

    if ($includePlatform) {
        if ($appManifest.PSObject.Properties.name -eq "platformUrl") {
            $platformUrl = $appManifest.platformUrl
        }
        else {
            $platformUrl = "$($appUri.AbsolutePath.Substring(0,$appUri.AbsolutePath.LastIndexOf('/')))/platform".TrimStart('/')
        }
    
        if ($platformUrl -notlike 'https://*') {
            $platformUrl = "https://$($appUri.Host.TrimEnd('/'))/$platformUrl$($appUri.Query)"
        }
        $platformUri = [Uri]::new($platformUrl)
         
        $platformArtifactPath = Join-Path $basePath $platformUri.AbsolutePath
        $exists = Test-Path $platformArtifactPath
        if ($exists -and $force) {
            Remove-Item $platformArtifactPath -Recurse -Force
            $exists = $false
        }
        if (-not $exists) {
            Write-Host "Downloading platform artifact $($platformUri.AbsolutePath)"
            $platformZip = Join-Path ([System.IO.Path]::GetTempPath()) "$([Guid]::NewGuid().ToString()).zip"
            try {
                Download-File -sourceUrl $platformUrl -destinationFile $platformZip
            }
            catch {
                if ($platformUrl.Contains('.azureedge.net/')) {
                    $platformUrl = $platformUrl.Replace('.azureedge.net/','.blob.core.windows.net/')
                    Write-Host "Retrying download..."
                    Download-File -sourceUrl $platformUrl -destinationFile $platformZip
                }
            }
            Write-Host "Unpacking platform artifact"
            Expand-Archive -Path $platformZip -DestinationPath $platformArtifactPath -Force
            Remove-Item -path $platformZip -force
    
            $prerequisiteComponentsFile = Join-Path $platformArtifactPath "Prerequisite Components.json"
            if (Test-Path $prerequisiteComponentsFile) {
                $prerequisiteComponents = Get-Content $prerequisiteComponentsFile | ConvertFrom-Json
                Write-Host "Downloading Prerequisite Components"
                $prerequisiteComponents.PSObject.Properties | % {
                    $path = Join-Path $platformArtifactPath $_.Name
                    if (-not (Test-Path $path)) {
                        $dirName = [System.IO.Path]::GetDirectoryName($path)
                        $filename = [System.IO.Path]::GetFileName($path)
                        if (-not (Test-Path $dirName)) {
                            New-Item -Path $dirName -ItemType Directory | Out-Null
                        }
                        $url = $_.Value
                        Download-File -sourceUrl $url -destinationFile $path
                    }
                }
            }
        }
        try { [System.IO.File]::WriteAllText((Join-Path $platformArtifactPath 'lastused'), "$([datetime]::UtcNow.Ticks)") } catch {}

        $platformArtifactPath
    }
}

function GetTestToolkitApps {
    Param(
        [switch] $includeTestLibrariesOnly,
        [switch] $includeTestFrameworkOnly,
        [switch] $includePerformanceToolkit
    )

    # Add Test Framework
    $apps = @(get-childitem -Path "C:\Applications\TestFramework\TestLibraries\*.*" -recurse -filter "*.app")
    $apps += @(get-childitem -Path "C:\Applications\TestFramework\TestRunner\*.*" -recurse -filter "*.app")


    if (!$includeTestFrameworkOnly) {
        
        $version = [Version](Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe").VersionInfo.FileVersion

        # Add Test Libraries
        $apps += "Microsoft_System Application Test Library.app", "Microsoft_Tests-TestLibraries.app" | % {
            @(get-childitem -Path "C:\Applications\*.*" -recurse -filter $_)
        }

        if (!$includeTestLibrariesOnly) {

            # Add Tests
            $apps += @(get-childitem -Path "C:\Applications\*.*" -recurse -filter "Microsoft_Tests-*.app") | Where-Object { $_ -notlike "*\Microsoft_Tests-TestLibraries.app" -and ($version.Major -ge 17 -or ($_ -notlike "*\Microsoft_Tests-Marketing.app")) -and $_ -notlike "*\Microsoft_Tests-SINGLESERVER.app" }
        }
    }

    if ($includePerformanceToolkit) {
        $apps += @(get-childitem -Path "C:\Applications\TestFramework\PerformanceToolkit\*.*" -recurse -filter "*Toolkit.app")
        if (!$includeTestFrameworkOnly) {
            $apps += @(get-childitem -Path "C:\Applications\TestFramework\PerformanceToolkit\*.*" -recurse -filter "*.app" -exclude "*Toolkit.app")
        }
    }

    $apps | % {
        $appFile = Get-ChildItem -path "c:\applications.*\*.*" -recurse -filter ($_.Name).Replace(".app","_*.app")
        if (!($appFile)) {
            $appFile = $_
        }
        $appFile
    }
}

function ImportNAVServerLicense {
    Param(
        [string] $LicenseFile, `
        [string] $ServerInstance, `
        [string] $Database
    )

    $CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
    $CustomConfig = [xml](Get-Content $CustomConfigFile)
    $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
    $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
    $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value

    if ($databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {
        [Byte[]] $licenseData = get-content -Encoding Byte $LicenseFile
        $licenseAsHex = "0x$(($licenseData | ForEach-Object ToString X2) -join '')"
        Invoke-SqlCmdWithRetry -DatabaseName $databaseName -Query "UPDATE [dbo].[`$ndo`$dbproperty] SET license = $licenseAsHex"
    }
    else {
        Import-NAVServerLicense -LicenseFile $licenseFilePath -ServerInstance $ServerInstance -Database NavDatabase -WarningAction SilentlyContinue
    }
}

function RoboCopyFiles {
    Param(
        [string] $source,
        [string] $destination,
        [string] $files = "*",
        [switch] $e
    )

    Write-Host $source
    if ($e) {
        RoboCopy "$source" "$destination" "$files" /e /NFL /NDL /NJH /NJS /nc /ns /np /mt /z /nooffload | Out-Null
        Get-ChildItem -Path $source -Filter $files -Recurse | ForEach-Object {
            $destPath = Join-Path $destination $_.FullName.Substring($source.Length)
            while (!(Test-Path $destPath)) {
                Write-Host "Waiting for $destPath to be available"
                Start-Sleep -Seconds 1
            }
        }
    }
    else {
        RoboCopy "$source" "$destination" "$files" /NFL /NDL /NJH /NJS /nc /ns /np /mt /z /nooffload | Out-Null
        Get-ChildItem -Path $source -Filter $files | ForEach-Object {
            $destPath = Join-Path $destination $_.FullName.Substring($source.Length)
            while (!(Test-Path $destPath)) {
                Write-Host "Waiting for $destPath to be available"
                Start-Sleep -Seconds 1
            }
        }
    }
}