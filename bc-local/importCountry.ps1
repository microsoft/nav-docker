$ErrorActionPreference = "Stop"
Write-Host "Importing Country"

$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1"

. (Join-Path $PSScriptRoot "HelperFunctions.ps1")

$NavServiceName = 'MicrosoftDynamicsNavServer$NAV'
$SqlServiceName = 'MSSQL$SQLEXPRESS'
$SqlWriterServiceName = "SQLWriter"
$SqlBrowserServiceName = "SQLBrowser"

Write-Host "Downloading database $env:COUNTRYURL"
$countryFile = "C:\COUNTRY.zip"
(New-Object System.Net.WebClient).DownloadFile("$env:COUNTRYURL", $countryFile)
[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
$countryFolder = "$PSScriptRoot\Country"
New-Item -Path $countryFolder -ItemType Directory -ErrorAction Ignore | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($countryFile, $countryFolder)

Write-Host "Starting Local SQL Server"
Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
Start-Service -Name $SqlServiceName -ErrorAction Ignore

# Restore CRONUS Demo database to databases folder

Write-Host "Restore CRONUS Demo Database"
$databaseName = "$env:DatabaseName"
$databaseFolder = "c:\databases\$databaseName"
$databaseServer = "localhost"
$databaseInstance = "SQLEXPRESS"
$bak = (Get-ChildItem -Path "$countryFolder\*.bak")[0]
$databaseFile = $bak.FullName

# Restore database
New-Item -Path $databaseFolder -itemtype Directory | Out-Null
New-NAVDatabase -DatabaseServer $databaseServer `
                -DatabaseInstance $databaseInstance `
                -DatabaseName "$databaseName" `
                -FilePath "$databaseFile" `
                -DestinationPath "$databaseFolder" `
                -timeout 300 | Out-Null

# Shrink the demo database log file
& SQLCMD -Q "USE master;
ALTER DATABASE $DatabaseName SET RECOVERY SIMPLE;
GO
USE $DatabaseName;
GO
DBCC SHRINKFILE(2, 1)
GO"

# run local installers if present
if (Test-Path "$countryFolder\Installers" -PathType Container) {
    Get-ChildItem "$countryFolder\Installers" -Recurse | Where-Object { $_.PSIsContainer } | % {
        $dir = $_.FullName
        Get-ChildItem (Join-Path $dir "*.msi") | % {
            $filepath = $_.FullName
            if ($filepath.Contains('\WebHelp\')) {
                Write-Host "Skipping $filepath"
            } else {
                Write-Host "Installing $filepath"
                Start-Process -FilePath $filepath -WorkingDirectory $dir -ArgumentList "/qn /norestart" -Wait
            }
        }
    }
}

"ConfigurationPackages","TestToolKit","UpgradeToolKit","Extensions" | % {
    if (Test-Path "c:\$_"-PathType Container) {
        Write-Host "Remove old $_"
        Remove-Item "c:\$_" -Recurse -Force
    }
    if (Test-Path "$countryFolder\$_" -PathType Container) {
        Write-Host "Copy $_"
        Copy-Item -Path "$countryFolder\$_" -Destination "c:\" -Recurse
    }
}

$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value = "$databaseName"
$CustomConfig.Save($CustomConfigFile)

Write-Host "Start NAV Service Tier"
Start-Service -Name $NavServiceName -WarningAction Ignore

Write-Host "Import License file"
$licensefile = Join-Path $countryFolder "Cronus.flf"
Import-NAVServerLicense -LicenseFile $licensefile -ServerInstance 'NAV' -Database NavDatabase -WarningAction SilentlyContinue

Write-Host "Remove CRONUS DB"
$cronusFiles = Get-NavDatabaseFiles -DatabaseName "CRONUS"
& sqlcmd -Q "ALTER DATABASE [CRONUS] SET OFFLINE WITH ROLLBACK IMMEDIATE"
& sqlcmd -Q "DROP DATABASE [CRONUS]"
$cronusFiles | % { remove-item $_.Path }

$serverFile = "$ServiceTierFolder\Microsoft.Dynamics.Nav.Server.exe"
$serverVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($serverFile)
if ($serverVersion.FileMajorPart -ge 11) {
    $roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
    Write-Host "Generating Symbol Reference"
    $pre = (get-process -Name "finsql" -ErrorAction Ignore) | % { $_.Id }
    Start-Process -FilePath "$roleTailoredClientFolder\finsql.exe" -ArgumentList "Command=generatesymbolreference, Database=$databaseName, ServerName=localhost\SQLEXPRESS, ntauthentication=1"
    $procs = get-process -Name "finsql" -ErrorAction Ignore
    $procs | Where-Object { $pre -notcontains $_.Id } | Wait-Process
}

Write-Host "Cleanup"
Remove-Item $countryFile -Force
Remove-Item $countryFolder -Force -Recurse
