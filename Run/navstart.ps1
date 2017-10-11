Write-Host "Initializing..."

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

$hostname = hostname

. (Get-MyFilePath "HelperFunctions.ps1")
. (Get-MyFilePath "New-SelfSignedCertificateEx.ps1")
. (Get-MyFilePath "SetupVariables.ps1")

Write-Host "Hostname is $hostname"
Write-Host "PublicDnsName is $publicDnsName"

# Ensure correct casing
if ($auth -eq "" -or $auth -eq "navuserpassword") {
    $auth = "NavUserPassword"
} elseif ($auth -eq "windows") {
    $auth = "Windows"
}
$windowsAuth = ($auth -eq "Windows")

$NavServiceName = 'MicrosoftDynamicsNavServer$NAV'
$SqlServiceName = 'MSSQL$SQLEXPRESS'
$SqlWriterServiceName = "SQLWriter"
$SqlBrowserServiceName = "SQLBrowser"
$IisServiceName = "W3SVC"

if ($WindowsAuth) {
    $navUseSSL = $false
} else {
    $navUseSSL = $true
}

if ($useSSL -eq "") {
    $servicesUseSSL = $navUseSSL
} elseif ($useSSL -eq "Y") {
    $servicesUseSSL = $true
} elseif ($useSSL -eq "N") {
    $servicesUseSSL = $false
} else {
    throw "Illegal value for UseSSL"
}

if ($servicesUseSSL) {
    $protocol = "https://"
    $webClientPort = 443
} else {
    $protocol = "http://"
    $webClientPort = 80
}

# Default public ports
if ($publicWebClientPort -ne "") { $publicWebClientPort = ":$publicWebClientPort" }
if ($publicFileSharePort -eq "") { $publicFileSharePort = "8080" }
if ($publicWinClientPort -eq "") { $publicWinClientPort = "7046" }
if ($publicSoapPort      -eq "") { $publicSoapPort      = "7047" }
if ($publicODataPort     -eq "") { $publicODataPort     = "7048" }

# This script is multi-purpose
#
# $buildingImage is true when called during build of specific NAV image (with CRONUS Demo Database and CRONUS license)
# $restartingInstance is true when called due to Docker restart of a running image
# $runningGenericImage is true when running a generic image with NAVDVD on share
# $runningSpecificImage is true when running a specific image (which had buildingImage set true true during image build)
#

if ($buildingImage) { Write-Host "Building Image" }

$publicDnsNameFile = "$RunPath\PublicDnsName.txt"
$publicDnsNameChanged = $false
$restartingInstance = Test-Path -Path $publicDnsNameFile -PathType Leaf
if ($restartingInstance) {
    Write-Host "Restarting Instance"
    $prevPublicDnsName = Get-Content -Path $publicDnsNameFile
    if ($prevPublicDnsName -ne $publicDnsName) {
        $publicDnsNameChanged = $true
        Write-Host "PublicDnsName changed"
    }
}

if (!$buildingImage) {
    Set-Content -Path $publicDnsNameFile -Value $publicDnsName
}

$runningGenericImage = $restartingInstance -and !$buildingImage -and (!(Test-Path "C:\Program Files\Microsoft Dynamics NAV" -PathType Container))
if ($runningGenericImage) { Write-Host "Running Generic Image" }

$runningSpecificImage = (!$restartingInstance) -and (!$runningGenericImage) -and (!$buildingImage)
if ($runningSpecificImage) { Write-Host "Running Specific Image" }

if ($buildingImage + $restartingInstance + $runningGenericImage + $runningSpecificImage -ne 1) {
    Write-Error "ERROR: Cannot determine reason for running script."
    exit 1
}

if ($databaseServer -eq 'localhost') {
    # start the SQL Server
    Write-Host "Starting Local SQL Server"
    Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
    Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore
    Start-Service -Name $SqlServiceName -ErrorAction Ignore
}

if (($webClient -ne "N") -or ($httpSite -ne "N")) {
    # start IIS services
    Write-Host "Starting Internet Information Server"
    Start-Service -name $IisServiceName
}

if ($runningGenericImage -or $runningSpecificImage) {
    Write-Host "Using $auth Authentication"
}

if ($runningGenericImage -or $buildingImage) {
    if (!(Test-Path $navDvdPath -PathType Container)) {
        Write-Error "ERROR: NAVDVD folder not found"
        Write-Error "You must map a folder on the host with the NAVDVD content to $navDvdPath"
        exit 1
    }
}

if ($runningSpecificImage -and $Accept_eula -ne "Y")
{
    Write-Error "ERROR: You must accept the End User License Agreement before this container can start."
    Write-Error "Set the environment variable ACCEPT_EULA to 'Y' if you accept the agreement."
    exit 1 
}

# Prerequisites
if ($runningGenericImage -or $buildingImage) 
{
    if ($webClient -ne "N") {
        Write-Host "Installing Url Rewrite"
        start-process "$NavDvdPath\Prerequisite Components\IIS URL Rewrite Module\rewrite_2.0_rtw_x64.msi" -ArgumentList "/quiet /qn /passive" -Wait
    
        Write-Host "Installing ReportViewer"
        if (Test-Path "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer" -PathType Container) {
            start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer\SQLSysClrTypes.msi" -ArgumentList "/quiet /qn /passive" -Wait
            start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer\ReportViewer.msi" -ArgumentList "/quiet /qn /passive" -Wait
        }
    
        if (Test-Path "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015" -PathType Container) {
            start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015\SQLSysClrTypes.msi" -ArgumentList "/quiet /qn /passive" -Wait
            start-process "$NavDvdPath\Prerequisite Components\Microsoft Report Viewer 2015\ReportViewer.msi" -ArgumentList "/quiet /qn /passive" -Wait
        }
    
        if (Test-Path "$NavDvdPath\Prerequisite Components\DotNetCore" -PathType Container) {
            Write-Host "Installing DotNetCore"
            start-process (Get-ChildItem -Path "$NavDvdPath\Prerequisite Components\DotNetCore" -Filter "*.exe").FullName -ArgumentList "/quiet" -Wait
        }
    }

    Write-Host "Installing OpenXML"
    start-process "$NavDvdPath\Prerequisite Components\Open XML SDK 2.5 for Microsoft Office\OpenXMLSDKv25.msi" -ArgumentList "/quiet /qn /passive" -Wait
}

# Copy Service Tier in place if we are running a Generic Image or Building a specific image
if ($runningGenericImage -or $buildingImage) {
    Write-Host "Copy Service Tier Files"
    Copy-Item -Path "$NavDvdPath\ServiceTier\Program Files" -Destination "C:\" -Recurse -Force
    Copy-Item -Path "$NavDvdPath\ServiceTier\System64Folder\NavSip.dll" -Destination "C:\Windows\System32\NavSip.dll" -Force -ErrorAction Ignore

    Write-Host "Copy Web Client Files"
    Copy-Item -Path "$NavDvdPath\WebClient\Microsoft Dynamics NAV" -Destination "C:\Program Files\" -Recurse -Force
    if (Test-Path "$navDvdPath\WebClient\inetpub" -PathType Container) {
        Copy-Item -Path "$navDvdPath\WebClient\inetpub" -Destination $runPath -Recurse -Force
    }

    Write-Host "Copy RTC Files"
    Copy-Item -Path "$navDvdPath\RoleTailoredClient\program files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force
    Copy-Item -Path "$navDvdPath\RoleTailoredClient\systemFolder\NavSip.dll" -Destination "C:\Windows\SysWow64\NavSip.dll" -Force -ErrorAction Ignore
    Copy-Item -Path "$navDvdPath\ClickOnceInstallerTools\Program Files\Microsoft Dynamics NAV" -Destination "C:\Program Files (x86)\" -Recurse -Force
    Copy-Item -Path "$navDvdPath\*.vsix" -Destination $runPath

    Write-Host "Copy PowerShell Scripts"
    Copy-Item -Path "$navDvdPath\WindowsPowerShellScripts\Cloud\NAVAdministration\" -Destination $runPath -Recurse -Force

    Write-Host "Copy ClientUserSettings"
    Copy-Item (Join-Path (Get-ChildItem -Path "$NavDvdPath\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "ClientUserSettings.config") $runPath
}

$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
$clickOnceInstallerToolsFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\ClickOnce Installer Tools").FullName
$WebClientFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Web Client")[0]
$NAVAdministrationScriptsFolder = (Get-Item "$runPath\NAVAdministration").FullName

if ($runningGenericImage -or $buildingImage) {
    if (!(Test-Path (Join-Path $roleTailoredClientFolder 'hlink.dll'))) {
        Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $roleTailoredClientFolder 'hlink.dll')
    }
    if (!(Test-Path (Join-Path $serviceTierFolder 'hlink.dll'))) {
        Copy-Item -Path (Join-Path $runPath 'Install\hlink.dll') -Destination (Join-Path $serviceTierFolder 'hlink.dll')
    }
    if (!(Test-Path "C:\Program Files (x86)\ReportBuilder" -PathType Container)) {
        $reportBuilderSrc = Join-Path $runPath 'Install\ReportBuilder'
        if (Test-Path $reportBuilderSrc -PathType Container) {
            Write-Host "Copy ReportBuilder"
            Copy-Item -Path $reportBuilderSrc -Destination 'C:\Program Files (x86)' -Recurse
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction Ignore | Out-null
            New-Item "HKCR:\MSReportBuilder_ReportFile_32" -itemtype Directory -ErrorAction Ignore | Out-null
            New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell" -itemtype Directory -ErrorAction Ignore | Out-null
            New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open" -itemtype Directory -ErrorAction Ignore | Out-null
            New-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -itemtype Directory -ErrorAction Ignore | Out-null
            Set-Item "HKCR:\MSReportBuilder_ReportFile_32\shell\Open\command" -value 'c:\program files (x86)\ReportBuilder\MSReportBuilder.exe "%1"'
        }
    }
}

Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1"

# Setup Database Connection
. (Get-MyFilePath "SetupDatabase.ps1")

if ($databaseServer -ne 'localhost') {
    if ((Get-service -name $SqlServiceName).Status -eq 'Running') {
        Write-Host "Stopping local SQL Server"
        Stop-Service -Name $SqlServiceName -ErrorAction Ignore
        Stop-Service -Name $SqlWriterServiceName -ErrorAction Ignore
        Stop-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
    }
}


if ($runningGenericImage -or $buildingImage) {
    # run local installers if present
    if (Test-Path "$navDvdPath\Installers" -PathType Container) {
        Get-ChildItem "$navDvdPath\Installers" | Where-Object { $_.PSIsContainer } | % {
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
}

if ($runningGenericImage -or $runningSpecificImage -or $buildingImage) {

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
}

if ($runningGenericImage -or $runningSpecificImage -or $publicDnsNameChanged) {

    # Certificate
    if ($navUseSSL -or $servicesUseSSL) {
        . (Get-MyFilePath "SetupCertificate.ps1")
    }
    
    . (Get-MyFilePath "SetupConfiguration.ps1")
}

if ($runningGenericImage -or $runningSpecificImage) {

    . (Get-MyFilePath "SetupAddIns.ps1")
}

if ($runningGenericImage -or $buildingImage) {
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

    Install-NAVSipCryptoProvider
}

Write-Host "Start NAV Service Tier"
Start-Service -Name $NavServiceName -WarningAction Ignore

. (Get-MyFilePath "SetupLicense.ps1")

$wwwRootPath = Get-WWWRootPath
$httpPath = Join-Path $wwwRootPath "http"

if ($runningGenericImage -or $runningSpecificImage -or $publicDnsNameChanged) {

    if ($webClient -ne "N") {

        . (Get-MyFilePath "SetupWebClient.ps1")
        . (Get-MyFilePath "SetupWebConfiguration.ps1")
    }

}

if ($runningGenericImage -or $runningSpecificImage) {

    if ($httpSite -ne "N") {
        Write-Host "Creating http download site"
        New-Item -Path $httpPath -ItemType Directory | Out-Null
        New-Website -Name http -Port 8080 -PhysicalPath $httpPath | Out-Null
    
        $webConfigFile = Join-Path $httpPath "web.config"
        Copy-Item -Path (Join-Path $runPath "web.config") -Destination $webConfigFile
        get-item -Path $webConfigFile | % { $_.Attributes = "Hidden" }
    
        . (Get-MyFilePath "SetupFileShare.ps1")
    }

    . (Get-MyFilePath "SetupWindowsUsers.ps1")
    . (Get-MyFilePath "SetupSqlUsers.ps1")
    . (Get-MyFilePath "SetupNavUsers.ps1")
}

if (($runningGenericImage -or $runningSpecificImage -or $publicDnsNameChanged) -and ($httpSite -ne "N") -and ($clickOnce -eq "Y")) {
    Write-Host "Creating ClickOnce Manifest"
    . (Get-MyFilePath "SetupClickOnce.ps1")
}

if ($runningGenericImage -or $runningSpecificImage) {
    . (Get-MyFilePath "AdditionalSetup.ps1")
}

if (!$buildingImage) {

    $CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
    $CustomConfig = [xml](Get-Content $CustomConfigFile)

    $ip = (Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1" })[0].IPAddress
    Write-Host "Container IP Address: $ip"
    Write-Host "Container Hostname  : $hostname"
    Write-Host "Container Dns Name  : $publicDnsName"
    if ($webClient -ne "N") {
        $publicWebBaseUrl = $CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
        Write-Host "Web Client          : $publicWebBaseUrl"
    }
    if ($auth -ne "Windows" -and !$passwordSpecified) {
        Write-Host "NAV Admin Username  : $username"
        Write-Host "NAV Admin Password  : $password"
    }
    if ($httpSite -ne "N") {
        if (Test-Path -Path (Join-Path $httpPath "*.vsix")) {
            Write-Host "Dev. Server         : $protocol$publicDnsName"
            Write-Host "Dev. ServerInstance : NAV"
        }
        if ($clickOnce -eq "Y") {
            Write-Host "ClickOnce Manifest  : http://${publicDnsName}:$publicFileSharePort/NAV"
        }
    }

    . (Get-MyFilePath "AdditionalOutput.ps1")

    Write-Host 
    if ($httpSite -ne "N") {
        Write-Host "Files:"
        Get-ChildItem -Path $httpPath -file | % {
            Write-Host "http://${publicDnsName}:$publicFileSharePort/$($_.Name)"
        }
        Write-Host 
    }

    Write-Host "Ready for connections!"
}
