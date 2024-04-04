Param( 
    [switch] $installOnly
)

Write-Host "Installing NAV: InstallOnly=$($installOnly.IsPresent)"
$startTime = [DateTime]::Now

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"
$navDvdPath = "C:\NAVDVD"

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

. (Get-MyFilePath "ServiceSettings.ps1")
. (Get-MyFilePath "HelperFunctions.ps1")

if (!(Test-Path $navDvdPath -PathType Container)) {
    Write-Error "NAVDVD folder not found
You must map a folder on the host with the NAVDVD content to $navDvdPath"
    exit 1
}

# start the SQL Server
Write-Host "Starting Local SQL Server"
Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
Start-Service -Name $SqlServiceName -ErrorAction Ignore

# Prerequisites
InstallPrerequisite -Name "Url Rewrite" -MsiPath "$NavDvdPath\Prerequisite Components\IIS URL Rewrite Module\rewrite_2.0_rtw_x64.msi" -MsiUrl "https://bcartifacts.blob.core.windows.net/prerequisites/rewrite_2.0_rtw_x64.msi"
InstallPrerequisite -Name "SQL Clr Types" -MsiPath "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015\SQLSysClrTypes.msi" -MsiUrl "https://bcartifacts.blob.core.windows.net/prerequisites/SQLSysClrTypes.msi"
InstallPrerequisite -Name "Report Viewer" -MsiPath "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015\ReportViewer.msi" -MsiUrl "https://bcartifacts.blob.core.windows.net/prerequisites/ReportViewer.msi"
InstallPrerequisite -Name "OpenXML" -MsiPath "$NavDvdPath\Prerequisite Components\Open XML SDK 2.5 for Microsoft Office\OpenXMLSDKv25.msi" -MsiUrl "https://bcartifacts.blob.core.windows.net/prerequisites/OpenXMLSDKv25.msi"

# start IIS services
Write-Host "Starting Internet Information Server"
Start-Service -name $IisServiceName

Write-Host "Copying Service Tier Files"
Copy-Item -Path "$NavDvdPath\ServiceTier\Program Files" -Destination "C:\" -Recurse -Force
Copy-Item -Path "$NavDvdPath\ServiceTier\System64Folder\NavSip.dll" -Destination "C:\Windows\System32\NavSip.dll" -Force -ErrorAction Ignore

Write-Host "Copying Web Client Files"
Copy-Item -Path "$NavDvdPath\WebClient\Microsoft Dynamics NAV" -Destination "C:\Program Files\" -Recurse -Force
Copy-Item -Path "$navDvdPath\WebClient\inetpub" -Destination $runPath -Recurse -Force

Write-Host "Copying Windows Client Files"
Copy-Item -Path "$navDvdPath\RoleTailoredClient\program files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force
Copy-Item -Path "$navDvdPath\RoleTailoredClient\systemFolder\NavSip.dll" -Destination "C:\Windows\SysWow64\NavSip.dll" -Force -ErrorAction Ignore
Copy-Item -Path "$navDvdPath\ClickOnceInstallerTools\Program Files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force

Write-Host "Copying PowerShell Scripts"
Copy-Item -Path "$navDvdPath\WindowsPowerShellScripts\Cloud\NAVAdministration\" -Destination $runPath -Recurse -Force

"Test Assemblies","TestToolKit","UpgradeToolKit","My" | % {
    $dir = "$navDvdPath\$_" 
    if (Test-Path $dir -PathType Container)
    {
        Write-Host "Copying $_"
        Copy-Item -Path $dir -Destination "C:\" -Recurse
    }
}

Write-Host "Copying ClientUserSettings"
Copy-Item (Join-Path (Get-ChildItem -Path "$NavDvdPath\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "ClientUserSettings.config") $runPath

$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName

# Copy office DLLs to Add-ins folder in service Tier to allow compilation of codeunit 5054 and more
Copy-Item -Path (Join-Path $roleTailoredClientFolder "*office*.dll") -Destination (Join-Path $serviceTierFolder "Add-ins\Office")

# Due to dependencies from finsql.exe, we have to copy hlink.dll and ReportBuilder in place inside the container
Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $roleTailoredClientFolder 'hlink.dll')
Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $serviceTierFolder 'hlink.dll')
Copy-Item -Path (Join-Path $runPath 'Install\t2embed.dll') -Destination "c:\windows\system32\t2embed.dll"

$reportBuilderPath = "C:\Program Files (x86)\ReportBuilder"
$reportBuilderSrc = Join-Path $runPath 'Install\ReportBuilder'
Write-Host "Copying ReportBuilder"
New-Item $reportBuilderPath -ItemType Directory | Out-Null
Copy-Item -Path "$reportBuilderSrc\*" -Destination "$reportBuilderPath\" -Recurse
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction Ignore | Out-null
New-Item "HKCR:\MSReportBuilder_ReportFile_32" -itemtype Directory -ErrorAction Ignore | Out-null
New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell" -itemtype Directory -ErrorAction Ignore | Out-null
New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open" -itemtype Directory -ErrorAction Ignore | Out-null
New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -itemtype Directory -ErrorAction Ignore | Out-null
Set-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -value "$reportBuilderPath\MSReportBuilder.exe ""%1"""

Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1"

$databaseServer = "localhost"
$databaseInstance = "SQLEXPRESS"
$databaseName = "CRONUS"
$skipDb = $false

# Restore CRONUS Demo database to databases folder
if (Test-Path "$navDvdPath\SQLDemoDatabase" -PathType Container) {
    $bak = (Get-ChildItem -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\*.bak")[0]
    
    # Restore database
    $databaseFolder = "c:\databases"
    New-Item -Path $databaseFolder -itemtype Directory -ErrorAction Ignore | Out-Null
    $databaseFile = $bak.FullName

    Write-Host "Restoring CRONUS Demo Database"
    New-NAVDatabase -DatabaseServer $databaseServer `
                    -DatabaseInstance $databaseInstance `
                    -DatabaseName "$databaseName" `
                    -FilePath "$databaseFile" `
                    -DestinationPath "$databaseFolder" `
                    -Timeout 300 | Out-Null
} else {

    if (Test-Path "$navDvdPath\databases") {

        Write-Host "Copying Cronus database"
        Copy-Item -path "$navDvdPath\databases" -Destination "c:\" -Recurse -Force
        $mdf = (Get-Item "C:\databases\*.mdf").FullName
        $ldf = (Get-Item "C:\databases\*.ldf").FullName
        $databaseName = (Get-Item "C:\databases\*.mdf").BaseName

        $attachcmd = @"
USE [master]
GO
CREATE DATABASE [CRONUS] ON (FILENAME = '$mdf'),(FILENAME = '$ldf') FOR ATTACH
GO
"@
        Invoke-Sqlcmd -ServerInstance localhost\SQLEXPRESS -QueryTimeOut 0 -ea Stop -Query $attachcmd
    } else {
        $skipDb = $true
        Write-Host "Skipping restore of Cronus database"
    }
}

# run local installers if present
if (Test-Path "$navDvdPath\Installers" -PathType Container) {
    Get-ChildItem "$navDvdPath\Installers" -Recurse | Where-Object { $_.PSIsContainer } | % {
        Get-ChildItem $_.FullName | Where-Object { $_.PSIsContainer } | % {
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
}

Write-Host "Modifying NAV Service Tier Config File for Docker"
$CustomConfigFile =  Join-Path $serviceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value = $databaseServer
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value = $databaseInstance
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value = "$databaseName"
$customConfig.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Value = "$ServerInstance"
$customConfig.SelectSingleNode("//appSettings/add[@key='ManagementServicesPort']").Value = "7045"
$customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesPort']").Value = "7046"
$customConfig.SelectSingleNode("//appSettings/add[@key='SOAPServicesPort']").Value = "7047"
$customConfig.SelectSingleNode("//appSettings/add[@key='ODataServicesPort']").Value = "7048"
$customConfig.SelectSingleNode("//appSettings/add[@key='DefaultClient']").Value = "Web"
$taskSchedulerKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']") -ne $null)
if ($taskSchedulerKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']").Value = "false"
}
$CustomConfig.Save($CustomConfigFile)

# Creating NAV Service
Write-Host "Creating NAV Service Tier"
$serviceCredentials = New-Object System.Management.Automation.PSCredential ("NT AUTHORITY\SYSTEM", (new-object System.Security.SecureString))
$serverFile = "$serviceTierFolder\Microsoft.Dynamics.Nav.Server.exe"
$configFile = "$serviceTierFolder\Microsoft.Dynamics.Nav.Server.exe.config"
New-Service -Name $NavServiceName -BinaryPathName """$serverFile"" `$$ServerInstance /config ""$configFile""" -DisplayName "Microsoft Dynamics NAV Server [$ServerInstance]" -Description "$ServerInstance" -StartupType manual -Credential $serviceCredentials -DependsOn @("HTTP") | Out-Null

$serverVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($serverFile)
$versionFolder = ("{0}{1}" -f $serverVersion.FileMajorPart,$serverVersion.FileMinorPart)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\$versionFolder\Service"
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Path' -Value "$serviceTierFolder\" -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Installed' -Value 1 -Force | Out-Null

Install-NAVSipCryptoProvider

if (!$skipDb -and ($installOnly -or (Test-Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\cronus.flf"))) {

    Write-Host "Starting NAV Service Tier"
    Start-Service -Name $NavServiceName -WarningAction Ignore

    if (Test-Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\cronus.flf") {
        Write-Host "Importing CRONUS license file"
        $licensefile = (Get-Item -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\cronus.flf").FullName
        Import-NAVServerLicense -LicenseFile $licensefile -ServerInstance $ServerInstance -Database NavDatabase -WarningAction SilentlyContinue
    }

    Write-Host "Stopping NAV Service Tier"
    Stop-Service -Name $NavServiceName -WarningAction Ignore
}

$timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
Write-Host "Installation took $timespend seconds"
Write-Host "Installation complete"
