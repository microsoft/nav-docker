Write-Host "Installing NAV"
$startTime = [DateTime]::Now

$runPath = "c:\Run"
$navDvdPath = "C:\NAVDVD"

. (Join-Path $runPath "HelperFunctions.ps1")

if (!(Test-Path $navDvdPath -PathType Container)) {
    Write-Error "NAVDVD folder not found.
You must map a folder on the host with the NAVDVD content to $navDvdPath"
    exit 1
}

if (!(Test-Path -Path "c:\navdvd\Prerequisite Components\microsoft-windows-netfx3-ondemand-package.cab")) {
    Write-Error "This NAV version requires .NET 3 which is not on WindowsServerCore.
If you download microsoft-windows-netfx3-ondemand-package.cab from a Windows Server 2016 media and place it in the Prerequisite Components folder on the NAV DVD, then it will be installed automatically."
    Exit 1
}

Write-Host "Installing .NET 3"
Dism /online /enable-feature /all /featurename:NetFX3 /Source:"C:\NAVDVD\Prerequisite Components" | Out-Null

Write-Host "Installing VC Redist"
Start-Process "C:\navdvd\Prerequisite Components\Microsoft Visual C++ 2012\vcredist_x64.exe" -ArgumentList "/passive /norestart" -Wait
Start-Process "C:\navdvd\Prerequisite Components\Microsoft Visual C++ 2012\vcredist_x86.exe" -ArgumentList "/passive /norestart" -Wait

$env:WebClient = "N"

# start the SQL Server
Write-Host "Starting Local SQL Server"
Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
Start-Service -Name $SqlServiceName -ErrorAction Ignore

# start IIS services
Write-Host "Starting Internet Information Server"
Start-Service -name $IisServiceName

# Prerequisites
Write-Host "Installing Url Rewrite"
start-process "$NavDvdPath\Prerequisite Components\IIS URL Rewrite Module\rewrite_2.0_rtw_x64.msi" -ArgumentList "/quiet /qn /passive" -Wait

Write-Host "Installing Report Viewer"
start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2012\SQLSysClrTypes.msi" -ArgumentList "/quiet /qn /passive" -Wait
start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2012\ReportViewer.msi" -ArgumentList "/quiet /qn /passive" -Wait

Write-Host "Installing OpenXML"
start-process "$NavDvdPath\Prerequisite Components\Open XML SDK 2.5 for Microsoft Office\OpenXMLSDKv25.msi" -ArgumentList "/quiet /qn /passive" -Wait

Write-Host "Copying Service Tier Files"
Copy-Item -Path "$NavDvdPath\ServiceTier\Program Files" -Destination "C:\" -Recurse -Force

Write-Host "Copying Web Client Files"
Copy-Item -Path "$NavDvdPath\WebClient\Microsoft Dynamics NAV" -Destination "C:\Program Files\" -Recurse -Force
Copy-Item -Path "$navDvdPath\WebClient\inetpub" -Destination $runPath -Recurse -Force

Write-Host "Copying Windows Client Files"
Copy-Item -Path "$navDvdPath\RoleTailoredClient\program files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force
Copy-Item -Path "$navDvdPath\ClickOnceInstallerTools\Program Files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force

Write-Host "Copying PowerShell Scripts"
Copy-Item -Path "$navDvdPath\WindowsPowerShellScripts\Cloud\NAVAdministration\" -Destination $runPath -Recurse -Force

Write-Host "Copying ClientUserSettings"
Copy-Item (Join-Path (Get-ChildItem -Path "$NavDvdPath\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "ClientUserSettings.config") $runPath

$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName

# Due to dependencies from finsql.exe, we have to copy hlink.dll and ReportBuilder in place inside the container
Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $roleTailoredClientFolder 'hlink.dll')
Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $serviceTierFolder 'hlink.dll')

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

Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.dll"

# Restore CRONUS Demo database to databases folder
Write-Host "Restoring CRONUS Demo Database"
$bak = (Get-ChildItem -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\*.bak")[0]

# Restore database
$databaseServer = "localhost"
$databaseInstance = "SQLEXPRESS"
$databaseName = "CRONUS"
$databaseFolder = "c:\databases"
New-Item -Path $databaseFolder -itemtype Directory -ErrorAction Ignore | Out-Null
$databaseFile = $bak.FullName

New-NAVDatabase -DatabaseServer $databaseServer `
                -DatabaseInstance $databaseInstance `
                -DatabaseName "$databaseName" `
                -FilePath "$databaseFile" `
                -DestinationPath "$databaseFolder" `
                -Timeout 300 | Out-Null

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
$customConfig.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Value = "NAV"
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
New-Service -Name $NavServiceName -BinaryPathName """$serverFile"" `$NAV /config ""$configFile""" -DisplayName 'Microsoft Dynamics NAV Server [NAV]' -Description 'NAV' -StartupType manual -Credential $serviceCredentials -DependsOn @("HTTP") | Out-Null

$serverVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($serverFile)
$versionFolder = ("{0}{1}" -f $serverVersion.FileMajorPart,$serverVersion.FileMinorPart)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft Dynamics NAV\$versionFolder\Service"
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Path' -Value "$serviceTierFolder\" -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'Installed' -Value 1 -Force | Out-Null

Write-Host "Starting NAV Service Tier"
Start-Service -Name $NavServiceName -WarningAction Ignore

Write-Host "Importing CRONUS license file"
$licensefile = (Get-Item -Path "$navDvdPath\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\*\Database\cronus.flf").FullName
Import-NAVServerLicense -LicenseFile $licensefile -ServerInstance 'NAV' -Database NavDatabase -WarningAction SilentlyContinue

if (Test-Path -Path "$PSScriptRoot\powershell.exe.config" -PathType Leaf) {
    Write-Host "Copying PowerShell.exe.config"
    Copy-Item -Path "$PSScriptRoot\powershell.exe.config" -Destination C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe.Config -Force
    Copy-Item -Path "$PSScriptRoot\powershell.exe.config" -Destination C:\Windows\SysWOW64\Windowspowershell\v1.0\powershell.exe.Config -Force
}

$timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
Write-Host "Installation took $timespend seconds"
Write-Host "Installation complete"
