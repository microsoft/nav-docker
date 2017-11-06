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
		[Parameter(Mandatory=$True)]
		[string]$Bacpac,
		[Parameter(Mandatory=$true)]
		[string]$DatabaseName,
		[Parameter(Mandatory=$false)]
		[int]$maxattempts = 10
    )

    Add-Type -path "C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\Microsoft.SqlServer.Dac.dll"
    $conn = "Data Source=localhost\SQLEXPRESS;Initial Catalog=master;Connection Timeout=0;Integrated Security=True;"

    $attempt = 0
    while ($true) {
        try {
            $attempt++
            Write-Host "Restore Database from $Bacpac as $DatabaseName"
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

function Get-NavDatabaseFiles([string]$DatabaseName)
{
    Invoke-sqlcmd -ea stop -ServerInstance 'localhost\SQLEXPRESS' -QueryTimeout 0 -Query "SELECT f.physical_name FROM sys.sysdatabases db INNER JOIN sys.master_files f ON f.database_id = db.dbid WHERE db.name = '$DatabaseName'" | % {
        $file = $_.physical_name
        if (Test-Path $file)
        {
            $file = Resolve-Path $file
        }
        $file
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

    $Destination | ForEach-Object { Microsoft.PowerShell.Management\Copy-Item $Source -Destination $_ -Confirm:$Confirm -Force:$Force -Recurse:$Recurse }
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
