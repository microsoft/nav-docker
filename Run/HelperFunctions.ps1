$NavServiceName = 'MicrosoftDynamicsNavServer$NAV'
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

    Add-Type -path "C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\Microsoft.SqlServer.Dac.dll"
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
                Write-Error "Error restoring Database, giving up..."
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

    Write-Host "Copying NAV Database on $DatabaseServerInstance from $SourceDatabaseName to $DestinationDatabaseName"

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

        Write-Host "Creating $DestinationDatabaseName on $DatabaseServerInstance as copy of $SourceDatabaseName"
        Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                               -DatabaseInstance $databaseInstance `
                               -DatabaseCredentials $databaseCredentials `
                               -Query "CREATE Database [$DestinationDatabaseName] AS COPY OF [$SourceDatabaseName];"
        
        $engineEdition = (Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                                 -DatabaseInstance $databaseInstance `
                                                 -DatabaseCredentials $databaseCredentials `
                                                 -Query "select SERVERPROPERTY('EngineEdition')").Column1
        if ("$engineEdition" -eq "5") {
            Write-Host "Waiting for Database copy to complete"
            # Azure SQL - Wait for the Database to become ready
            $sqlCommandText = "select * from sys.dm_database_copies"
            while ((Invoke-SqlCmdWithRetry -DatabaseServer $databaseServer `
                                    -DatabaseInstance $databaseInstance `
                                    -DatabaseCredentials $databaseCredentials `
                                    -Query $sqlCommandText) -ne $null) {
                Start-Sleep -Seconds 10
            }
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
USE MASTER
SELECT '1' FROM SYS.DATABASES WHERE NAME = '$DatabaseName'
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
        [string]$ServerInstance = "NAV",
        [Parameter(Mandatory=$true)]
        [string]$TenantId,
        [Parameter(Mandatory=$false)]
        [string]$DatabaseServer = "localhost",
        [Parameter(Mandatory=$false)]
        [string]$DatabaseInstance = "SQLEXPRESS",
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$databaseCredentials,
        [Parameter(Mandatory=$false)]
        [string[]]$AlternateId = @()
    )

    $DatabaseServerInstance = "$DatabaseServer"
    if ("$DatabaseInstance" -ne "") {
        $DatabaseServerInstance += "\$DatabaseInstance"
    }

    Write-Host "Mounting NAV Database for $TenantID on server $DatabaseServerInstance"
    
    $Params = @{}
    if ($TenantId -eq "default") {
        $Params += @{"AllowAppDatabaseWrite"=$true }
    }
    if ($DatabaseCredentials) {
        $Params += @{ "DatabaseCredentials"=$DatabaseCredentials; "Force"=$true }
    }

    Mount-NAVTenant -ServerInstance $ServerInstance `
                    -DatabaseServer $DatabaseServer `
                    -DatabaseInstance $DatabaseInstance `
                    -DatabaseName $DatabaseName `
                    -Id $TenantID `
                    -AlternateId $AlternateId `
                    -OverwriteTenantIdInDatabase @Params

    Write-Host "Sync'ing NAV Tenant"    
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
        [string]$Query
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

    $maxattempts = 10
    if ($DatabaseServer -eq 'localhost') {
        $maxattempts = 3
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

function Install-NAVSipCryptoProvider
{
    $sipPath = "C:\Windows\System32\NavSip.dll"
    Test-Path -Path $sipPath -ErrorAction Stop | Out-Null

    Write-Host "Installing NAV SIP crypto provider: '$sipPath'"

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
        [xml]$customConfig
    )

    $customSettingsArray = $customSettings -split ","

    foreach ($customSetting in $customSettingsArray) {
        $customSettingArray = $customSetting -split "="
        $customSettingKey = $customSettingArray[0]
        $customSettingValue = $customSettingArray[1]
        
        if ($customConfig.SelectSingleNode("$parentPath/$leafName[@key='$customSettingKey']") -eq $null) {
            Write-Host "Creating $customSettingKey and setting it to $customSettingValue"
            [xml] $tmpDoc = [xml] ""
            $tmpDoc.LoadXml("<add key='$customSettingKey' value='$customSettingValue' />") | Out-Null
            $tmpNode = $customConfig.ImportNode($tmpDoc.get_DocumentElement(), $true)
            $customConfig.SelectSingleNode($parentPath).AppendChild($tmpNode)
        } else {
            Write-Host "Setting $customSettingKey to $customSettingValue"
            $customConfig.SelectSingleNode("$parentPath/$leafName[@key='$customSettingKey']").Value = "$customSettingValue"
        }
    }
}
