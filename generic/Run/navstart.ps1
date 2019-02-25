Write-Host "Initializing..."
$startTime = [DateTime]::Now

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"
$navDvdPath = "C:\NAVDVD"

$publicDnsNameFile = "$RunPath\PublicDnsName.txt"
$restartingInstance = Test-Path -Path $publicDnsNameFile -PathType Leaf

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

$hostname = hostname

. (Get-MyFilePath "ServiceSettings.ps1")
. (Get-MyFilePath "HelperFunctions.ps1")
. (Get-MyFilePath "SetupVariables.ps1")

$newPublicDnsName = $true
if ($restartingInstance) {
    Write-Host "Restarting Container"
    $prevPublicDnsName = Get-Content -Path $publicDnsNameFile
    if ($prevPublicDnsName -eq $publicDnsName) {
        $newPublicDnsName = $false
        Write-Host "PublicDnsName unchanged"
    }
} else {
    Write-Host "Starting Container"
}
Set-Content -Path $publicDnsNameFile -Value $publicDnsName

Write-Host "Hostname is $hostname"
Write-Host "PublicDnsName is $publicDnsName"

if ($Accept_eula -ne "Y")
{
    Write-Error "You must accept the End User License Agreement before this container can start.
Use Docker inspect to locate the Url for the EULA under Labels/legal.
set the environment variable ACCEPT_EULA to 'Y' if you accept the agreement."
    exit 1
}

if (!$restartingImage) {
    $containerAge = [System.DateTime]::Now.Subtract((Get-Item "C:\RUN").CreationTime).Days
    if ($containerAge -gt 90) {
        if ($Accept_outdated -ne "Y") {
            Write-Error "You are trying to run a container which is more than 90 days old.
    Microsoft recommends that you always run the latest version of our containers.
    Set the environment variable ACCEPT_OUTDATED to 'Y' if you want to run this container anyway."
            exit 1
        }
    }

    if (!(Resolve-DnsName -Name download.microsoft.com -erroraction Ignore -Type CNAME)) {
        Write-Host "WARNING: DNS resolution not working from within the container."
    }

    $timeZoneId = (Get-TimeZone).Id
    $timeZone = Get-TimeZone -ListAvailable | Where-Object { $_.Id -eq $timeZoneId } 
    if (!($timeZone)) {
        Write-Host "WARNING: Container starts with TimeZone = $timeZoneId, which is not recognized in the list of TimeZones."
    }
}

Write-Host "Using $auth Authentication"
$usingLocalSQLServer = ($databaseServer -eq "localhost")
if ($usingLocalSQLServer) {
    if ((Get-Service -name $SqlServiceName).Status -ne "Running") {
        # start the SQL Server
        Write-Host "Starting Local SQL Server"
        Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore -WarningAction Ignore
        Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore -WarningAction Ignore
        Start-Service -Name $SqlServiceName -ErrorAction Ignore -WarningAction Ignore
    }
}

if (($webClient -ne "N") -or ($httpSite -ne "N")) {
    if ((Get-Service -name $IisServiceName).Status -ne "Running") {
        # start IIS services
        Write-Host "Starting Internet Information Server"
        Start-Service -name $IisServiceName -ErrorAction Ignore
    }
}

$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName
$clickOnceInstallerToolsFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\ClickOnce Installer Tools").FullName
$WebClientFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Web Client")[0]
$NAVAdministrationScriptsFolder = (Get-Item "$runPath\NAVAdministration").FullName
$CustomConfigFile = Join-Path $serviceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)
$serverInstance = $CustomConfig.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Value

if (Test-Path "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1") {
    Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1" -wa SilentlyContinue
} else {
    Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.dll" -wa SilentlyContinue
}

# Setup Database Connection
. (Get-MyFilePath "SetupDatabase.ps1")

$usingLocalSQLServer = ($databaseServer -eq "localhost")
if (!$usingLocalSQLServer) {
    if ((Get-service -name $SqlServiceName).Status -eq 'Running') {
        Write-Host "Stopping local SQL Server"
        Stop-Service -Name $SqlServiceName -ErrorAction Ignore
        Stop-Service -Name $SqlWriterServiceName -ErrorAction Ignore
        Stop-Service -Name $SqlBrowserServiceName -ErrorAction Ignore
    }
}

if ($newPublicDnsName) {
    # Certificate
    if ($navUseSSL -or $servicesUseSSL) {
        . (Get-MyFilePath "SetupCertificate.ps1")
    }
    . (Get-MyFilePath "SetupConfiguration.ps1")
}

if (!$restartingInstance) {
    . (Get-MyFilePath "SetupAddIns.ps1")
}

$service = Get-Service -name $NavServiceName -ErrorAction Ignore
if (!($service)) {
    Write-Error "Service Tier doesn't exist / is not installed"
} elseif ($service.Status -ne "Running") {
    Write-Host "Starting Service Tier"
    Start-Service -Name $NavServiceName -WarningAction Ignore
} else {
    Write-Host "Restarting Service Tier"
    Restart-Service -Name $NavServiceName -WarningAction Ignore
}

$wwwRootPath = Get-WWWRootPath
$httpPath = Join-Path $wwwRootPath "http"

if ($newPublicDnsName -and $webClient -ne "N") {
    . (Get-MyFilePath "SetupWebClient.ps1")
    . (Get-MyFilePath "SetupWebConfiguration.ps1")
}

. (Get-MyFilePath "SetupLicense.ps1")

if ($multitenant) {
    . (Get-MyFilePath "SetupTenant.ps1")
}

if (!$restartingInstance) {
    if ($httpSite -ne "N") {
        Write-Host "Creating http download site"
        New-Item -Path $httpPath -ItemType Directory | Out-Null
        New-Website -Name http -Port $fileSharePort -PhysicalPath $httpPath | Out-Null
    
        $webConfigFile = Join-Path $httpPath "web.config"
        Copy-Item -Path (Join-Path $runPath "web.config") -Destination $webConfigFile
        get-item -Path $webConfigFile | % { $_.Attributes = "Hidden" }
    
        . (Get-MyFilePath "SetupFileShare.ps1")
    }
    
    . (Get-MyFilePath "SetupWindowsUsers.ps1")

    if ($usingLocalSQLServer) {
        . (Get-MyFilePath "SetupSqlUsers.ps1")
        . (Get-MyFilePath "SetupNavUsers.ps1")
    }
}

if ($newPublicDnsName -and $httpSite -ne "N" -and $clickOnce -eq "Y") {
    Write-Host "Creating ClickOnce Manifest"
    . (Get-MyFilePath "SetupClickOnce.ps1")
}

. (Get-MyFilePath "AdditionalSetup.ps1")

$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)

$ip = "127.0.0.1"
$ips = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1" }
if ($ips) {
    $ips | ForEach-Object {
        if ($ip -eq "127.0.0.1") {
            $ip = $_.IPAddress
        }
        Write-Host "Container IP Address: $($_.IPAddress)"
    }
} else {
    Write-Host "Container IP Address: UNKNOWN"
}
Write-Host "Container Hostname  : $hostname"
Write-Host "Container Dns Name  : $publicDnsName"
if ($webClient -ne "N") {
    Write-Host "Web Client          : $publicWebBaseUrl$webTenantParam"
}
if ($auth -ne "Windows" -and $usingLocalSQLServer -and !$passwordSpecified -and !$restartingInstance) {
    Write-Host "Admin Username      : $username"
    Write-Host ("Admin Password      : "+[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)))
}
if ($httpSite -ne "N") {
    if (Test-Path -Path (Join-Path $httpPath "*.vsix")) {
        Write-Host "Dev. Server         : $protocol$publicDnsName"
        Write-Host "Dev. ServerInstance : $serverInstance"
        if ($multitenant) {
            Write-Host "Dev. Server Tenant  : $tenantId"
        }
    }
    if ($clickOnce -eq "Y") {
        Write-Host "ClickOnce Manifest  : $clickOnceWebSiteUrl"
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

if ($containerAge -gt 60) {
    Write-Host "WARNING: You are running a container which is $containerAge days old.
Microsoft recommends that you always run the latest version of our containers."
    Write-Host
}

if ("$securepassword") {
    Clear-Variable -Name "securePassword"
}

$timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
Write-Host "Initialization took $timespend seconds"
Write-Host "Ready for connections!"
