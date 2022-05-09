#Requires -Version 4
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Gets the information about the Business Central web server instances that are registered on a computer.
.DESCRIPTION
You can use Get-NAVWebServerInstance cmdlet to get the following information about Business Central web server instances that are registered in IIS on the computer.

WebServerInstance: The name of the Business Central web server instance
Uri: Unified Resource Locator of web server instance.
SiteDeploymentType: The deployment type of the web server instance. Possible values are: RootSite or SubSite
Server: The computer that is running the Business Central Server that the Business Central web server instance connects to.
ServerInstance: The Business Central Server instance that the Business Central web server instance connects to.
ClientServicesPort: Specifies the listening TCP port for the Business Central Server instance that the Business Central web server instance connects to.
ManagementServicesPort: Specifies the listening TCP port that is used to manage the Business Central Server instance.
DNSIdenity: Specifies the subject name or common name of the service certificate for Business Central Server instance. This parameter is only relevant when the ClientServicesCredentialType in the Business Central Server instance configuration is set to UserName, NavUserPassword, or AccessControlService. These credential types requires that security certificates are used on the Dynamics NAV web server and Business Central Server instances to protect communication.
Configuration File: The location of the navsettings.json file that is used by the Business Central web server instance.
Version: The platform version of the Business Central web server instance.
.PARAMETER WebServerInstance
Specifies the name of the Business Central web server instance that you want information about. If you omit this parameter, then the cmdlet returns information about all Business Central web server instances.
.EXAMPLE
Get-NAVWebServerInstance -WebServerInstance DynamicsNAV
This example gets information about the Business Central web server instance that is named 'DynamicsNAV'.
#>
function Get-NAVWebServerInstance
(
    [string] $WebServerInstance
) {
    $instances = @()

    Import-Module WebAdministration

    foreach ($site in Get-Website) {
        $exePath = Join-Path $site.PhysicalPath "Prod.Client.WebCoreApp.exe"
        if (Test-Path $exePath) {
            $settingFilePath = Join-Path $site.PhysicalPath "navsettings.json"
            $settings = Get-Content $settingFilePath -Raw | ConvertFrom-Json

            $instance = [PSCustomObject]@{
                WebServerInstance            = $site.Name
                Website                      = $site.Name
                Uri                          = Get-NavWebSiteUrl -WebSite $site
                SiteDeploymentType           = "RootSite"
                "Configuration File"         = $settingFilePath
                ClientServicesPort           = $settings.NAVWebSettings.ClientServicesPort
                ManagementServicesPort       = $settings.NAVWebSettings.ManagementServicesPort
                ClientServicesCredentialType = $settings.NAVWebSettings.ClientServicesCredentialType
                DnsIdentity                  = $settings.NAVWebSettings.DnsIdentity
                Server                       = $settings.NAVWebSettings.Server
                ServerInstance               = $settings.NAVWebSettings.ServerInstance
                Version                      = Get-ChildItem -Path $exePath | % versioninfo | % fileversion
            }

            $instances += $instance
        }

        foreach ($application in  Get-WebApplication -Site $site.Name) {
            $exePath = Join-Path $application.PhysicalPath "Prod.Client.WebCoreApp.exe"
            if (Test-Path $exePath) {
                $settingFilePath = Join-Path $application.PhysicalPath "navsettings.json"
                $settings = Get-Content $settingFilePath -Raw | ConvertFrom-Json

                $instance = [PSCustomObject]@{
                    WebServerInstance            = $application.Path.Trim('/')
                    Website                      = $site.Name
                    Uri                          = Get-NavWebSiteUrl -WebSite $site -Application $application
                    SiteDeploymentType           = "SubSite"
                    "Configuration File"         = $settingFilePath
                    ClientServicesPort           = $settings.NAVWebSettings.ClientServicesPort
                    ManagementServicesPort       = $settings.NAVWebSettings.ManagementServicesPort
                    ClientServicesCredentialType = $settings.NAVWebSettings.ClientServicesCredentialType
                    DnsIdentity                  = $settings.NAVWebSettings.DnsIdentity
                    Server                       = $settings.NAVWebSettings.Server
                    ServerInstance               = $settings.NAVWebSettings.ServerInstance
                    Version                      = Get-ChildItem -Path $exePath | % versioninfo | % fileversion
                }

                $instances += $instance
            }
        }
    }
    if ($WebServerInstance){
        $instances | where {$_.WebServerInstance -eq $WebServerInstance} | Write-Output
    }
    else {
        Write-Output $instances
    }
}

<#
.SYNOPSIS
Changes a configuration value for a Business Central web server instance.
.DESCRIPTION
Each web server instance has a configuration file called the navsettings.json file, which is stored in the physical path of the web server instance. This file contains several key-value pairs that configure various settings. The key-value pairs have the format "KeyName":  "KeyValue", such as "ClientServicesCredentialType":  "Windows". You can use this cmdlet to change the value of any key in the configuration file.  The changes will be applied to the web server instance automatically because the application pool is recycled. When the application pool is recycled by the IIS, static state such as client sessions in the Business Central Web client will be lost.
.PARAMETER WebServerInstance
Specifies the name of the web server instance in IIS.
.PARAMETER KeyName
Specifies the configuration key name as it appears in the web server instance’s configuration file (navsettings.json).
.PARAMETER KeyValue
Specifies configuration key value.
.PARAMETER SiteDeploymentType
Specifies the deployment type of web server instance. There are two possible values: SubSite and RootSite.
-   Use SubSite if the web server instance was created as a subsite (web application) to a container website. If you specify SubSite, you will have to set the -ContainerSiteName parameter. If the subsite is under the default container website 'Microsoft Dynamics 365 Business Central Web Client' then you can omit this parameter.
-   RootSite if the web server instance was created as a root-level website.
.PARAMETER ContainerSiteName
Specifies the name of the container website that the SubSite-type web server instance belongs to. This setting is only used if SiteDeploymentType has been set to "SubSite". If the subsite is under the default container website 'Microsoft Dynamics 365 Business Central Web Client' then you can omit this parameter.
.EXAMPLE
Set-NAVWebServerInstanceConfiguration -WebServerInstance DynamicsNAV -KeyName ClientServicesCredentialType -KeyValue NavUserPassword
This example sets the 'ClientServicesCredentialType' configuration setting to 'NavUserNamePassword'.
#>
function Set-NAVWebServerInstanceConfiguration
(
    [Parameter(Mandatory = $true)]
    [string] $WebServerInstance,
    [Parameter(Mandatory = $true)]
    [string] $KeyName,
    [Parameter(Mandatory = $true)]
    [string] $KeyValue,
    [ValidateSet('SubSite', 'RootSite')]
    [string] $SiteDeploymentType = "SubSite",
    [string] $ContainerSiteName
) {
    Import-Module WebAdministration

    $ContainerSiteName = Validate-NavWebContainerSiteName -ContainerSiteName $ContainerSiteName -SiteDeploymentType $SiteDeploymentType

    $iisEntity = Get-NavWebsiteOrApplication -WebServerInstance $WebServerInstance -SiteDeploymentType $SiteDeploymentType -ContainerSiteName $ContainerSiteName
    $physicalPath = $iisEntity.PhysicalPath
    $applicationPool =  $iisEntity.ApplicationPool

    $navSettingFile = Join-Path $physicalPath "navsettings.json"

    if (!(Test-Path -Path $navSettingFile -ErrorAction Stop)) {
        throw "$navSettingFile does not exist"
    }

    $config = Get-Content $navSettingFile -Raw | ConvertFrom-Json

    if ($config.'NAVWebSettings'| get-member -Name $KeyName -MemberType NoteProperty){
        $config.'NAVWebSettings'.$KeyName = $KeyValue
    }
    else {
        $config.'NAVWebSettings'| add-member -Name $KeyName -value $KeyValue -MemberType NoteProperty -Force
    }

    $config | ConvertTo-Json | Set-Content $navSettingFile

    # Manually recycle IIS App pool
    Restart-WebAppPool -Name $applicationPool -ErrorAction Ignore
}

<#
.SYNOPSIS
Gets a specific configuration value for a Business Central web server instance.
.DESCRIPTION
Use this cmdlet to get the value of a setting in the configuration file (navsettings.json) for a web server instance. The settings in the navsettings.json are defined by a key-value pair.
.PARAMETER WebServerInstance
Specifies the name of the web server instance in IIS.
.PARAMETER KeyName
Specifies the configuration key name as it appears in the web server instance’s configuration file.
.PARAMETER SiteDeploymentType
Specifies the deployment type of web server instance. There are two possible values: RootSite and SubSite.
-   Use SubSite if the web server instance was created as a sub-site (web application) to a container website. If you specify SubSite, you will have to set the -ContainerSiteName parameter. If the subsite is under the default container website 'Microsoft Dynamics 365 Business Central Web Client' then you can omit this parameter.
-   RootSite is the web server instance was created as a root-level website.
.PARAMETER ContainerSiteName
Specifies the name of the container website that the SubSite-type web server instance belongs to. This setting is only used if SiteDeploymentType has been set to "SubSite". If the subsite is under the default container website 'Microsoft Dynamics 365 Business Central Web Client' then you can omit this parameter.
.EXAMPLE
Get-NAVWebServerInstanceConfiguration -WebServerInstance DynamicsNAV -KeyName ClientServicesCredentialType
This example reads 'ClientServicesCredentialType' confgiration value.
#>
function Get-NAVWebServerInstanceConfiguration
(
    [Parameter(Mandatory = $true)]
    [string] $WebServerInstance,
    [Parameter(Mandatory = $true)]
    [string] $KeyName,
    [ValidateSet('SubSite', 'RootSite')]
    [string] $SiteDeploymentType = "SubSite",
    [string] $ContainerSiteName
) {
    Import-Module WebAdministration

    $ContainerSiteName = Validate-NavWebContainerSiteName -ContainerSiteName $ContainerSiteName -SiteDeploymentType $SiteDeploymentType

    $iisEntity = Get-NavWebsiteOrApplication -WebServerInstance $WebServerInstance -SiteDeploymentType $SiteDeploymentType -ContainerSiteName $ContainerSiteName
    $physicalPath = $iisEntity.PhysicalPath

    $navSettingFile = Join-Path $physicalPath "navsettings.json"

    if (!(Test-Path -Path $navSettingFile -ErrorAction Stop)) {
        throw "$navSettingFile does not exist"
    }

    $config = Get-Content $navSettingFile -Raw | ConvertFrom-Json
    return $config.'NAVWebSettings'.$KeyName
}

function Get-NavWebsiteOrApplication(
    [Parameter(Mandatory = $true)]
    [string] $WebServerInstance,
    [ValidateSet('SubSite', 'RootSite')]
    [string] $SiteDeploymentType = "SubSite",
    [string] $ContainerSiteName
) {
    if ($SiteDeploymentType -eq "SubSite") {
        $webApplication = Get-WebApplication -Name $WebServerInstance -Site $ContainerSiteName
        return $webApplication
    }
    else {
        $website = Get-Website -Name $WebServerInstance
        return $website
    }
    return $physicalPath;
}

<#
.SYNOPSIS
Removes an existing Microsoft Dynamics 365 Business Central web server instance.

.DESCRIPTION
The Business Central Web, Phone, and Tablet clients use a Business Central web server instance on IIS. Use the Remove-NAVWebServerInstance cmdlet to delete a specific web server instance. The cmdlet deletes all subfolders, web applications, and components that are associated with the web server instance.

.PARAMETER WebServerInstance
Specifies the name of the web server instance in IIS that you want to remove.

.PARAMETER SiteDeploymentType
Specifies the deployment type of web server instance. There are two possible values: SubSite and RootSite.
-   Use SubSite if the web server instance was created as a sub-site (web application) to a container website. If you specify SubSite, you will have to set the -ContainerSiteName parameter. If the subsite is under the default container website 'Microsoft Dynamics 365 Business Central Web Client' then you can omit this parameter.
-   Use RootSite if the web server instance was created as a root-level website. If you use this value, all folders and subsites of the instance will be removed.

.PARAMETER ContainerSiteName
Specifies the name of the container website that the SubSite-type web server instance belongs to. This setting is only used if SiteDeploymentType has been set to "SubSite". If the subsite is under the default container website 'Microsoft Dynamics 365 Business Central Web Client' then you can omit this parameter.

.PARAMETER RemoveContainer
Specifies to remove the container website that the SubSite web server instance belongs to. This will remove all folders and subsites (web applications) of the container website.

.EXAMPLE
Remove-NAVWebServerInstance -WebServerInstance DynamicsNAV -SiteDeploymentType RootSite

This example removes a root-level web server instance.
.EXAMPLE
Remove-NAVWebServerInstance -WebServerInstance DynamicsNAV-AAD

This example removes a web server instance that was created as a SubSite type.
#>
function Remove-NAVWebServerInstance {
    [CmdletBinding(HelpURI = "https://go.microsoft.com/fwlink/?linkid=401381")]
    PARAM
    (
        [Parameter(Mandatory = $true)]
        [string]$WebServerInstance,
        [ValidateSet('SubSite', 'RootSite')]
        [string] $SiteDeploymentType = "SubSite",
        [string] $ContainerSiteName,
        [switch] $RemoveContainer

    )
    Import-Module WebAdministration

    $ContainerSiteName = Validate-NavWebContainerSiteName -ContainerSiteName $ContainerSiteName -SiteDeploymentType $SiteDeploymentType

    if ($SiteDeploymentType -eq "SubSite") {
        $website = Get-WebApplication -Name $WebServerInstance
    }
    else {
        $website = Get-Website -Name $WebServerInstance
    }

    if ($website) {
        $appPool = $website.applicationPool

        Write-Host "Remove application pool: $WebServerInstance"
        Remove-WebAppPool -Name $appPool

        Write-Host "Remove website: $WebServerInstance"

        if ($SiteDeploymentType -eq "SubSite") {
            Remove-WebApplication -Name $WebServerInstance -Site $ContainerSiteName
            if ($RemoveContainer) {

                $hasExistingWebApps = Get-WebApplication -Site $ContainerSiteName

                if ($hasExistingWebApps) {
                    Write-Warning "'$ContainerSiteName' site will not be removed because it contains other web applications"
                    $RemoveContainer = $false
                }
                else {
                    Remove-Website -Name $ContainerSiteName
                }
            }
        }
        else {
            Remove-Website -Name $WebServerInstance
        }
    }

    $wwwRoot = Get-WWWRootPath
    $siteRootFolder = Join-Path $wwwRoot $WebServerInstance
    if (Test-Path $siteRootFolder -ErrorAction Stop) {
        Write-Host "Remove $siteRootFolder"
        Remove-Item $siteRootFolder -Recurse -Force
    }

    if ($RemoveContainer -and ($SiteDeploymentType -eq "SubSite")) {
        $containerFolder = Join-Path $wwwRoot $ContainerSiteName
        Write-Host "Remove $containerFolder"
        Remove-Item $containerFolder -Recurse -Force
    }
}

function Validate-NavWebContainerSiteName(
    [string] $ContainerSiteName,
    [string] $SiteDeploymentType = "SubSite"
) {
    $registryProps = Get-NavWebClientInstallationProperties
    if (!$ContainerSiteName -and $SiteDeploymentType -eq "SubSite") {
        if ($registryProps) {
            $ContainerSiteName = $registryProps.Name
            Write-Host "Using container name from registry: $ContainerSiteName"
        }
        else {
            $ContainerSiteName = "NavWebApplicationContainer"
            Write-Host "Using default container name: $ContainerSiteName"
        }
    }

    return $ContainerSiteName
}

<#
.SYNOPSIS
Creates new a Business Central web server instance.

.DESCRIPTION
Creates a new Business Central web server instance on IIS for hosting the Business Central Web, Phone, and Tablet clients.

To create a new web server instance, you need access to the **WebPublish** folder that contains the content files for serving the Business Central Web Client.
- This folder is available on the Dynamics NAV installation media (DVD) and has the path "DVD\WebClient\Microsoft Dynamics NAV\200\Web Client\WebPublish".
- If you installed the Business Central Web Server Components, this folder has the path "%systemroot%\Program Files\Microsoft Dynamics NAV\[version number]\Web Client\WebPublish".
You can use either of these locations or you can copy the folder to more convenient location on your computer or network.

.PARAMETER WebServerInstance
Specifies the name to assign the web server instance in IIS, such as DynamicsNAV-AAD. If you are creating a SubSite type web server instance, the name will become part of the URL for the Business Central Web client. For example, if you set the parameter to MyNavWeb, the URL would be something like ‘http://myWebServer:8080/MyNavWeb/’.  If you are creating a RootSite type web server instance, the name is only used in IIS and does not become part of the URL. For example, if you set the parameter to MyNavWeb, the URL would be something like ‘http://myWebServer:8080/’.

.PARAMETER Server
Specifies the name of the computer that the Business Central Server instance is installed on. This parameter accepts "localhost" if the server instance and the new web server instance are installed on the same computer.

.PARAMETER ServerInstance
Specifies the name of the Business Central Server instance that the web server instance will connect to. You can specify either the full name of an instance, such as ‘MicrosoftDynamicsNavServer$myinstance-2’, or the short name such as ‘myinstance-2’.

.PARAMETER ClientServicesCredentialType
Specifies the credential type that is used for authenticating client users. The value must match the credential type that is configured for the Business Central Server instance that the web server instance connects to. Possible values include: Windows, UserName, NavUserPassword, or AccessControlService.

.PARAMETER ClientServicesPort
Specifies the TCP port that is configured on the Business Central Server instance for communicating with client services. This value must match the client services port that is configured for the Business Central Server instance that the web server instance connects to.

.PARAMETER ManagementServicesPort
Specifies the TCP port that is configured on the Business Central Server instance for communicating with the management services. This value must match the management services port that is configured for the Business Central Server instance that the web server instance connects to.

.PARAMETER SiteDeploymentType
Specifies how the web server instance is installed IIS regarding its hierarchical structure and relationships. There are two possible values: RootSite and SubSite.

-   RootSite a adds the web server instance as root-level website in IIS that has its own bindings. The URL for the web server has the format: [http://[WebserverComputerName]:[port]/](http://[WebserverComputerName]:[port]/).
-   SubSite adds the web server instance as an application under an existing or new container website, which you specify with the -ContainerSiteName parameter. If you are adding the SubSite instance to a new container website, you will also have to set the -WebSitePort parameter to setup the binding. You can add multiple SubSites to a container website. The SubSites inherit the binding defined on the container website.

If you omit this parameter, a subsite instance will be added to the default container website called 'Microsoft Dynamics 365 Business Central Web Client". If this contianer website does not exist, it will be added.

.PARAMETER ContainerSiteName
Specifies the name the container website to which you want to add the web server instance. This setting is only used if the -SiteDeploymentType parameter is set to ‘SubSite’. If you specify a container name that does not exist, a new site with is created as a container for the new web server instance. The website has no content but has binding on the port that specify with the -WebSitePort parameter.

.PARAMETER WebSitePort
Specifies the TCP port number under which the web server instance will be running. This is the port will be used to access the Business Central Web client and will be part of the URL. This parameter is only used if the -SiteDeploymentType parameter is set to ‘RootSite’ or set to ‘SubSite’ if you are creating a new container website.

.PARAMETER AppPoolName
Specifies the application pool that the web server instance will use. If you do not specify an application pool, the default Business Central Web Client application pool will be used.

.PARAMETER PublishFolder
Specifies the location of the WebPublish folder that contains the content file that is required for Business Central Web client. If you omit this parameter, the cmdlet will look for the folder path '%systemroot%\Program Files\Microsoft Dynamics NAV\[version number]\Web Client\WebPublish'

.PARAMETER DnsIdentity
Specifies the DNS identity of the Business Central Server instance that the web server instance connects to. You set the value to either the Subject or common name (CN) of the security certificate that is used by the Business Central Server instance. This parameter is only relevant when the ClientServicesCredentialType is set to UserName, NavUserPassword, or AccessControlService because these authentication methods require that security certificates are used on the Business Central Server and web server instances o protect communication.

Typically, the Subject is prefixed with "CN" (for common name), for example, "CN = NavServer.com", but it can also just be "NavServer.com". It is also possible for the Subject field to be blank, in which case the validation rules will be applied to the Subject Alternative Name field of the certificate.

.PARAMETER CertificateThumbprint
Specifies the thumbprint of the security certificate to use to configure an HTTPS binding for the web server instance. The certificate must be installed in the local computer certificate store.

.PARAMETER AddFirewallException
Specifies whether to allow inbound communication on the TCP port that is specified by the -WebSitePort parameter. If you use this parameter, an inbound rule for the port will be added to Windows Firewall.

.PARAMETER HelpServer
Specifies the name of computer that hosts the Business Central Help Server that provides online help to Business Central Web client users.

.PARAMETER HelpServerPort
Specifies the TCP port (such as 49000) that is used by the Business Central Help Server on the computer specified by the -HelpServer parameter.

.EXAMPLE
New-NAVWebServerInstance -WebServerInstance DynamicsNAV200-UP -Server localhost -ServerInstance DynamicsNAV200 -ClientServicesCredentialType NavUserPassword

This example adds a new 'SubSite' web server instance under the existing default container website 'Microsoft Dynamics 365 Business Central Web Client'. The new website instance will be configured for NavUserNamePassword authentication.
.EXAMPLE
New-NAVWebServerInstance -WebServerInstance DynamicsNAV-Root -Server localhost -ServerInstance DynamicsNAV200 -SiteDeploymentType RootSite

This example adds a RootSite type web server instance called 'DynamicsNAV-Root'.
.EXAMPLE
New-NAVWebServerInstance -PublishFolder "C:\NAV\WebClient\Microsoft Dynamics NAV\200\Web Client\WebPublish" -WebServerInstance DynamicsNAV200-Root -Server localhost -ServerInstance DynamicsNAV200 -SiteDeploymentType RootSite

This example adds a new RootSite type web server instance from a web publish folder that is located 'C:\NAV\WebClient\Microsoft Dynamics NAV\200\Web Client\WebPublish'.
#>
function New-NAVWebServerInstance {
    [CmdletBinding(HelpURI = "https://go.microsoft.com/fwlink/?linkid=401381")]
    PARAM
    (
        [Parameter(Mandatory = $true)]
        [string]$WebServerInstance,

        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $true)]
        [string]$ServerInstance,

        [ValidateSet('Windows', 'UserName', 'NavUserPassword', 'AccessControlService')]
        [string]$ClientServicesCredentialType = "Windows",

        [int]$ClientServicesPort = 7046,

        [int]$ManagementServicesPort = 7045,

        [ValidateSet('SubSite', 'RootSite')]
        [string]$SiteDeploymentType = 'SubSite',

        [string]$ContainerSiteName,

        [int]$WebSitePort,

        [string]$AppPoolName,

        [string]$PublishFolder,

        [string]$DnsIdentity,

        [string]$CertificateThumbprint,

        [switch]$AddFirewallException,

        [string]$HelpServer,

        [int]$HelpServerPort
    )
    Write-Host "1"
    $registryProps = Get-NavWebClientInstallationProperties

    # Add default parameter values
    if (!$PublishFolder) {
        if ($registryProps) {
            $PublishFolder = Join-Path $registryProps.Path "WebPublish"
            Write-Host "Using publish web folder from registry: $PublishFolder"
        }
    }

    if (!$AppPoolName) {
        $AppPoolName = $WebServerInstance
        Write-Host "Using application pool name: $AppPoolName"
    }

    if ($ContainerSiteName -and $SiteDeploymentType -eq "RootSite") {
        throw "ContainerSiteName parameter is only valid when 'SiteDeploymentType' is set to SubSite"
    }


    if (!$ContainerSiteName) {
        if ($registryProps) {
            $ContainerSiteName = $registryProps.Name
            Write-Host "Using container name from registry: $ContainerSiteName"
        }
        else {
            $ContainerSiteName = "NavWebApplicationContainer"
            Write-Host "Using default container name: $ContainerSiteName"
        }
    }

    if ($WebSitePort -eq 0) {
        if ($CertificateThumbprint) {
            $WebSitePort = 443
        }
        else {
            $WebSitePort = 80
        }

        Write-Host "Using default website port: $WebSitePort"
    }

    if (!(Test-Path -Path $PublishFolder -ErrorAction Stop)) {
        throw "$PublishFolder does not exist"
    }

    Import-Module WebAdministration

    # Create the website
    $siteRootFolder = New-NavWebSite -SourcePath $PublishFolder -WebServerInstance $WebServerInstance -ContainerSiteName $ContainerSiteName -SiteDeploymentType $SiteDeploymentType -AppPoolName $AppPoolName  -Port $WebSitePort -CertificateThumbprint $CertificateThumbprint

    # Set the Nav configuration
    Write-Host "Update configuration: navsettings.json"

    $navSettingFile = Join-Path $siteRootFolder "navsettings.json"
    if (!(Test-Path $navSettingFile -ErrorAction Stop)) {
        throw "$navSettingFile does not exist"
    }

    $config = Get-Content $navSettingFile -Raw | ConvertFrom-Json
    $config.NAVWebSettings.Server = $Server
    $config.NAVWebSettings.ServerInstance = $ServerInstance
    $config.NAVWebSettings.ClientServicesCredentialType = $ClientServicesCredentialType
    $config.NAVWebSettings.DnsIdentity = $DnsIdentity

    if ($HelpServer) {
        $config.NAVWebSettings.HelpServer = $HelpServer
    }

    if ($HelpServerPort -gt 0) {
        $config.NAVWebSettings.HelpServerPort = $HelpServerPort
    }

    if (!$CertificateThumbprint) {
        # Disable requiring SSL when no SSL thumbprint was specified (insecure)
        $config.NAVWebSettings.RequireSsl = "false"
    }

    $config.NAVWebSettings.ManagementServicesPort = $ManagementServicesPort
    $config.NAVWebSettings.ClientServicesPort = $ClientServicesPort
    $config.NAVWebSettings.UnknownSpnHint = "(net.tcp://${Server}:${ClientServicesPort}/${ServerInstance}/Service)=NoSpn"
    $config | ConvertTo-Json | set-content $navSettingFile

    # Set firewall rule
    if ($AddFirewallException) {
        Set-NavWebFirewallRule -Port $WebSitePort
    }

    Write-Host "Done Configuring Web Client"

    # Ignore errors if the site cannot start in cases when e.g. the port is being already used
    Restart-WebAppPool -Name $AppPoolName -ErrorAction Ignore
}

function New-NavWebSite
(
    [string] $SourcePath,
    [string] $WebServerInstance,
    [string] $ContainerSiteName,
    [ValidateSet('SubSite', 'RootSite')]
    [string] $SiteDeploymentType,
    [string] $AppPoolName,
    [string] $Port,
    [string] $CertificateThumbprint
) {
    $wwwRoot = Get-WWWRootPath
    $siteRootFolder = Join-Path $wwwRoot $WebServerInstance

    if (Test-Path $siteRootFolder) {
        Write-Host "Remove $siteRootFolder"
        Remove-Item $siteRootFolder -Recurse -Force
    }

    Write-Host "Copy files to WWW root $siteRootFolder"
    Copy-Item $SourcePath -Destination $siteRootFolder -Recurse -Container -Force


    Write-Host "Create the application pool $AppPoolName"
    if (Test-Path "IIS:\AppPools\$AppPoolName") {
        Write-Host "Removing existing application pool $AppPoolName"
        Remove-WebAppPool $AppPoolName
    }

    $appPool = New-WebAppPool -Name $AppPoolName -Force
    $appPool.managedRuntimeVersion = '' # No Managed Code
    $appPool.managedPipelineMode = "Integrated"
    $appPool.startMode = "AlwaysRunning"
    $appPool.enable32BitAppOnWin64 = "false"
    $appPool.recycling.logEventOnRecycle = "Time,Requests,Schedule,Memory,IsapiUnhealthy,OnDemand,ConfigChange,PrivateMemory"
    $appPool.processModel.identityType = "ApplicationPoolIdentity"
    $appPool.processModel.loadUserProfile = "true"
    $appPool.processModel.idleTimeout = "1.00:00:00"
    $appPool | Set-Item

    $user = New-Object System.Security.Principal.NTAccount("IIS APPPOOL\$($appPool.Name)")
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, "ListDirectory, ReadAndExecute, Write, Delete", "ContainerInherit, ObjectInherit", "None", "Allow")

    # Get and Set the same ACL to make sure ACL is in canonical form
    $acl = Get-Acl -Path $siteRootFolder
    Set-Acl -Path $siteRootFolder $acl
    $acl = $null

    $extractedResourcesFolder = Join-Path $siteRootFolder "\wwwroot\Resources\ExtractedResources"
	Create-FolderIfMissing $extractedResourcesFolder
    $acl = Get-Acl -Path $extractedResourcesFolder
    $acl.AddAccessRule($rule)
    Set-Acl -Path $extractedResourcesFolder $acl
    $acl = $null

    $thumbnailsFolder = Join-Path $siteRootFolder "\wwwroot\Thumbnails"
	Create-FolderIfMissing $thumbnailsFolder
    $acl = Get-Acl -Path $thumbnailsFolder
    $acl.AddAccessRule($rule)
    Set-Acl -Path $thumbnailsFolder $acl
    $acl = $null

    $reportsFolder = Join-Path $siteRootFolder "\wwwroot\Reports"
	Create-FolderIfMissing $reportsFolder
    $acl = Get-Acl -Path $reportsFolder
    $acl.AddAccessRule($rule)
    Set-Acl -Path $reportsFolder $acl
    $acl = $null

    if ($SiteDeploymentType -eq "SubSite") {

        # Create NavWebContainer if does not exist
        $containerDirectory = Join-Path $wwwRoot $ContainerSiteName
        New-Item $containerDirectory -type directory -Force | Out-Null

        # Create container website
        $containerSite = Get-Website -Name $ContainerSiteName
        if (!$containerSite) {
            New-NavSiteWithBindings -PhysicalPath $containerDirectory -SiteName $ContainerSiteName -CertificateThumbprint $CertificateThumbprint -Port $Port -CreateDefaultWebConfig
        }
        if (Get-WebApplication -Site $ContainerSiteName -Name $WebServerInstance) {
            Remove-WebApplication -Site $ContainerSiteName -Name $WebServerInstance
        }
        New-WebApplication -Site $ContainerSiteName -Name $WebServerInstance -PhysicalPath $siteRootFolder -ApplicationPool $AppPoolName | Out-Null

        Set-NavSiteAuthenticationSettings -SiteLocation "$ContainerSiteName/$WebServerInstance"
    }
    else {
        New-NavSiteWithBindings -PhysicalPath $siteRootFolder -SiteName $WebServerInstance -AppPoolName $AppPoolName -CertificateThumbprint $CertificateThumbprint -Port $Port
        Set-NavSiteAuthenticationSettings -SiteLocation $WebServerInstance
    }

    return $siteRootFolder
}

function Create-FolderIfMissing
(
	[string] $FolderPath
) {
	If (!(Test-Path $FolderPath)) {
		New-Item -ItemType Directory -Force -Path $FolderPath | Out-Null
	}
}

function Set-NavSiteAuthenticationSettings
(
    [string] $SiteLocation
) {
    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/windowsAuthentication' -Name enabled -Value true -Location $SiteLocation -Force
    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/anonymousAuthentication' -Name enabled -Value true -Location $SiteLocation -Force
}

function New-NavSiteWithBindings
(
    [string] $PhysicalPath,
    [string] $SiteName,
    [string] $CertificateThumbprint,
    [string] $AppPoolName,
    [int] $Port,
    [switch] $CreateDefaultWebConfig
) {
    # Remove existing site
    Get-WebSite -Name $SiteName | Remove-WebSite

    if ($CertificateThumbprint) {
        Write-Host "Create website: $SiteName with SSL"
        New-Website -Name $SiteName -ApplicationPool $AppPoolName -PhysicalPath $PhysicalPath -Port $Port -Ssl | Out-Null
        $binding = Get-WebBinding -Name $SiteName -Protocol "https"
        $binding.AddSslCertificate($CertificateThumbprint, 'My') | Out-Null
    }
    else {
        Write-Host "Create website: $SiteName without SSL"
        New-Website -Name $SiteName -ApplicationPool $AppPoolName -PhysicalPath $PhysicalPath -Port $Port | Out-Null
    }

    if ($CreateDefaultWebConfig) {$DefaultWebConfig = @"
<?xml version=`"1.0`" encoding=`"UTF-8`"?>
<configuration>
    <location path=`".`" inheritInChildApplications=`"false`">
        <system.webServer>
            <httpProtocol>
                <customHeaders>
                    <remove name=`"X-Powered-By`" />
                    <add name=`"X-Frame-Options`" value=`"SAMEORIGIN`" />
                </customHeaders>
            </httpProtocol>
        </system.webServer>
    </location>
</configuration>
"@
        New-Item -Path $PhysicalPath -Name "web.config" -Value $DefaultWebConfig -Force | Out-Null
    }
}

function Get-NavWebClientInstallationProperties
() {
    $keyPath = "HKLM:\Software\Microsoft\Microsoft Dynamics NAV\200\Web Client"
    if (Test-Path $keyPath) {
        return Get-ItemProperty -Path $keyPath
    }
}

function Set-NavWebFirewallRule
(
    [int] $Port
) {
    $firewallRule = Get-NetFirewallRule -DisplayName "Microsoft Dynamics NAV Web Client" -ErrorAction Ignore

    if (!$firewallRule) {
        New-NetFirewallRule -DisplayName "Microsoft Dynamics NAV Web Client" -Direction Inbound -LocalPort $Port -Protocol "TCP" -Action Allow -RemoteAddress "any" | Out-Null
        return
    }

    $ports = $firewallRule | Get-NetFirewallPortFilter
    if ($ports.LocalPort -is [array]) {
        if (!($ports.LocalPort -contains $Port)) {
            Set-NetFirewallRule -DisplayName "Microsoft Dynamics NAV Web Client" -LocalPort ($ports.LocalPort + $Port)
        }

        return
    }
    if ($ports.LocalPort -ne $Port) {
        Set-NetFirewallRule -DisplayName "Microsoft Dynamics NAV Web Client" -LocalPort ($ports.LocalPort, $Port)
    }
}

function Get-WWWRootPath {
    $wwwRootPath = (Get-Item "HKLM:\SOFTWARE\Microsoft\InetStp").GetValue("PathWWWRoot")
    $wwwRootPath = [System.Environment]::ExpandEnvironmentVariables($wwwRootPath)

    return $wwwRootPath
}

function Get-NavWebSiteUrl(
    $Website,
    $Application
) {
    $protocol = $Website.Bindings.Collection.protocol
    $port = $Website.Bindings.Collection.bindingInformation -replace ".*\:([\d]+)\:", '$1'

    if ($Application) {
        return "${protocol}://${env:computername}:$port/" + $Application.Path.Trim('/')
    }
    else {
        return "${protocol}://${env:computername}:$port"
    }
}

Export-ModuleMember -Function Get-NAVWebServerInstance, New-NAVWebServerInstance, Remove-NAVWebServerInstance, Set-NAVWebServerInstanceConfiguration, Get-NAVWebServerInstanceConfiguration


# SIG # Begin signature block
# MIIn4gYJKoZIhvcNAQcCoIIn0zCCJ88CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBfUdsn3O8u5/2W
# mB0VKiSB7yvPFh7DewToOAKCrSjdtKCCDYEwggX/MIID56ADAgECAhMzAAACUosz
# qviV8znbAAAAAAJSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjEwOTAyMTgzMjU5WhcNMjIwOTAxMTgzMjU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDQ5M+Ps/X7BNuv5B/0I6uoDwj0NJOo1KrVQqO7ggRXccklyTrWL4xMShjIou2I
# sbYnF67wXzVAq5Om4oe+LfzSDOzjcb6ms00gBo0OQaqwQ1BijyJ7NvDf80I1fW9O
# L76Kt0Wpc2zrGhzcHdb7upPrvxvSNNUvxK3sgw7YTt31410vpEp8yfBEl/hd8ZzA
# v47DCgJ5j1zm295s1RVZHNp6MoiQFVOECm4AwK2l28i+YER1JO4IplTH44uvzX9o
# RnJHaMvWzZEpozPy4jNO2DDqbcNs4zh7AWMhE1PWFVA+CHI/En5nASvCvLmuR/t8
# q4bc8XR8QIZJQSp+2U6m2ldNAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUNZJaEUGL2Guwt7ZOAu4efEYXedEw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDY3NTk3MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAFkk3
# uSxkTEBh1NtAl7BivIEsAWdgX1qZ+EdZMYbQKasY6IhSLXRMxF1B3OKdR9K/kccp
# kvNcGl8D7YyYS4mhCUMBR+VLrg3f8PUj38A9V5aiY2/Jok7WZFOAmjPRNNGnyeg7
# l0lTiThFqE+2aOs6+heegqAdelGgNJKRHLWRuhGKuLIw5lkgx9Ky+QvZrn/Ddi8u
# TIgWKp+MGG8xY6PBvvjgt9jQShlnPrZ3UY8Bvwy6rynhXBaV0V0TTL0gEx7eh/K1
# o8Miaru6s/7FyqOLeUS4vTHh9TgBL5DtxCYurXbSBVtL1Fj44+Od/6cmC9mmvrti
# yG709Y3Rd3YdJj2f3GJq7Y7KdWq0QYhatKhBeg4fxjhg0yut2g6aM1mxjNPrE48z
# 6HWCNGu9gMK5ZudldRw4a45Z06Aoktof0CqOyTErvq0YjoE4Xpa0+87T/PVUXNqf
# 7Y+qSU7+9LtLQuMYR4w3cSPjuNusvLf9gBnch5RqM7kaDtYWDgLyB42EfsxeMqwK
# WwA+TVi0HrWRqfSx2olbE56hJcEkMjOSKz3sRuupFCX3UroyYf52L+2iVTrda8XW
# esPG62Mnn3T8AuLfzeJFuAbfOSERx7IFZO92UPoXE1uEjL5skl1yTZB3MubgOA4F
# 8KoRNhviFAEST+nG8c8uIsbZeb08SeYQMqjVEmkwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZtzCCGbMCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAlKLM6r4lfM52wAAAAACUjAN
# BglghkgBZQMEAgEFAKCB7zAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgHhLDhiSL
# eY18/h6jMg0KuwDKJwi+wsxpzsG+NKjLFIkwgYIGCisGAQQBgjcCAQwxdDByoFSA
# UgBNAGkAYwByAG8AcwBvAGYAdAAuAEQAeQBuAGEAbQBpAGMAcwAuAE4AYQB2AC4A
# UwBlAHIAdgBpAGMAZQAuAEEAcwBwAE4AZQB0AEMAbwByAGWhGoAYaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tMA0GCSqGSIb3DQEBAQUABIIBAMtly+i8VXNhhktaH0Ue
# FEKGmzKRO2ZXArCuQ9ns9mwF2zSsm+IAtvNe754YVus8WgM6I0uVBRBzIV11HKKL
# 33P5L9nRw6xTM88LojAC/DAUAMta9GWUzRZiLed8gptf3ekpfRkFqsJ6P25PTSjL
# a9a7Zz7Kyt2Aop5WT+9E3AJBXBl17ySx4+P4GpvCWcLZEl9+GAWoIfLuTqlbUzAa
# E3U/vIcKHIj+aQVgAo9hp0hm3bOtn8XwE0arRCwaEtOvxEJU1iNM3seVAjl4FwNZ
# 5SWugTo7RyGyB6cqrUneIXabqn5nqlwbY46RQIXy3xfUu9PX2DROZuT8olkvaRTd
# dvihghcAMIIW/AYKKwYBBAGCNwMDATGCFuwwghboBgkqhkiG9w0BBwKgghbZMIIW
# 1QIBAzEPMA0GCWCGSAFlAwQCAQUAMIIBUQYLKoZIhvcNAQkQAQSgggFABIIBPDCC
# ATgCAQEGCisGAQQBhFkKAwEwMTANBglghkgBZQMEAgEFAAQgUFTv2Kv3nW2xvund
# CbTM8U7ubou7x7Bnn60XPf0vRdcCBmJpvjrQUxgTMjAyMjA1MDYyMTU2NTAuMjk4
# WjAEgAIB9KCB0KSBzTCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQG
# A1UECxMdVGhhbGVzIFRTUyBFU046REQ4Qy1FMzM3LTJGQUUxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghFXMIIHDDCCBPSgAwIBAgITMwAA
# AZwPpk1h0p5LKAABAAABnDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMDAeFw0yMTEyMDIxOTA1MTlaFw0yMzAyMjgxOTA1MTlaMIHK
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNT
# IEVTTjpERDhDLUUzMzctMkZBRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANtSKgwZ
# XUkWP6zrXazTaYq7bco9Q2zvU6MN4ka3GRMX2tJZOK4DxeBiQACL/n7YV/sKTslw
# pD0f9cPU4rCDX9sfcTWo7XPxdHLQ+WkaGbKKWATsqw69bw8hkJ/bjcp2V2A6vGsv
# wcqJCh07BK3JPmUtZikyy5PZ8fyTyiKGN7hOWlaIU9oIoucUNoAHQJzLq8h20eNg
# HUh7eI5k+Kyq4v6810LHuA6EHyKJOZN2xTw5JSkLy0FN5Mhg/OaFrFBl3iag2Tqp
# 4InKLt+Jbh/Jd0etnei2aDHFrmlfPmlRSv5wSNX5zAhgEyRpjmQcz1zp0QaSAefR
# kMm923/ngU51IbrVbAeHj569SHC9doHgsIxkh0K3lpw582+0ONXcIfIU6nkBT+qA
# DAZ+0dT1uu/gRTBy614QAofjo258TbSX9aOU1SHuAC+3bMoyM7jNdHEJROH+msFD
# BcmJRl4VKsReI5+S69KUGeLIBhhmnmQ6drF8Ip0ZiO+vhAsD3e9AnqnY7Hcge850
# I9oKvwuwpVwWnKnwwSGElMz7UvCocmoUMXk7Vn2aNti+bdH28+GQb5EMsqhOmvuZ
# OCRpOWN33G+b3g5unwEP0eTiY+LnWa2AuK43z/pplURJVle29K42QPkOcglB6sjL
# mNpEpb9basJ72eA0Mlp1LtH3oYZGXsggTfuXAgMBAAGjggE2MIIBMjAdBgNVHQ4E
# FgQUu2kJZ1Ndjl2112SynL6jGMID+rIwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXS
# ZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0
# YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAK
# BggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAgEApwAqpiMYRzNNYyz3PSbtijbe
# yCpUXcvIrqA4zPtMIcAk34W9u9mRDndWS+tlR3WwTpr1OgaV1wmc6YFzqK6EGWm9
# 03UEsFE7xBJMPXjfdVOPhcJB3vfvA0PX56oobcF2OvNsOSwTB8bi/ns+Cs39Puzs
# +QSNQZd8iAVBCSvxNCL78dln2RGU1xyB4AKqV9vi4Y/Gfmx2FA+jF0y+YLeob0M4
# 0nlSxL0q075t7L6iFRMNr0u8ROhzhDPLl+4ePYfUmyYJoobvydel9anAEsHFlhKl
# +aXb2ic3yNwbsoPycZJL/vo8OVvYYxCy+/5FrQmAvoW0ZEaBiYcKkzrNWt/hX9r5
# KgdwL61x0ZiTZopTko6W/58UTefTbhX7Pni0MApH3Pvyt6N0IFap+/LlwFRD1zn7
# e6ccPTwESnuo/auCmgPznq80OATA7vufsRZPvqeX8jKtsraSNscvNQymEWlcqdXV
# 9hYkjb4T/Qse9cUYaoXg68wFHFuslWfTdPYPLl1vqzlPMnNJpC8KtdioDgcq+y1B
# aSqSm8EdNfwzT37+/JFtVc3Gs915fDqgPZDgOSzKQIV+fw3aPYt2LET3AbmKKW/r
# 13Oy8cg3+D0D362GQBAJVv0NRI5NowgaCw6oNgWOFPrN72WSEcca/8QQiTGP2XpL
# iGpRDJZ6sWRpRYNdydkwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAV
# MA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK
# 4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLem
# jkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+
# NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+y
# OSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTes
# y+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9z
# fUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUD
# o9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDq
# hFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8w
# dJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N
# +VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOC
# Ad0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5k
# xJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBc
# BgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYD
# VR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYD
# VR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxi
# aNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3Nv
# ZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMu
# Y3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQw
# DQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+Tkdk
# eLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYe
# eNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3Uk
# V7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wX
# sFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mj
# dAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY
# 3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmR
# aw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyh
# YWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+
# 57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7t
# fqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOh
# cGbyoYICzjCCAjcCAQEwgfihgdCkgc0wgcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkREOEMtRTMzNy0yRkFFMSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4D
# AhoDFQDN2Wnq3fCz9ucStub1zQz7129TQKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA5h9xJzAiGA8yMDIyMDUw
# NjE4MDQyM1oYDzIwMjIwNTA3MTgwNDIzWjB3MD0GCisGAQQBhFkKBAExLzAtMAoC
# BQDmH3EnAgEAMAoCAQACAhmEAgH/MAcCAQACAhFiMAoCBQDmIMKnAgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMB
# hqAwDQYJKoZIhvcNAQEFBQADgYEAPyNpx/5Du5iuOD8kvaYeNIUrQCfej6KJwReg
# rO/oItcaY1CulzRF1a/Wnz6o204cJFR/AGOJbrWgoM7WwLV8kzZVgJwarshopSFR
# pMAIfVddk5NMU0bChsErhK5X8a7G9StWrieWHFwEtEJ6VFVEHEUtIFnCKagk3Bce
# emknnqYxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MAITMwAAAZwPpk1h0p5LKAABAAABnDANBglghkgBZQMEAgEFAKCCAUowGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCCcdrnhTFszfRp8
# MlE6YetclqWZ6sk8tOeV64G18RaNMDCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQw
# gb0EIDcPRYUgjSzKOhF39d4QgbRZQgrPO7Lo/qE5GtvSeqa8MIGYMIGApH4wfDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAGcD6ZNYdKeSygAAQAAAZww
# IgQgARfC91ACQO24TmSPmkf6nZJaqK8zm5NTpPDkJENSLbAwDQYJKoZIhvcNAQEL
# BQAEggIANsXkrtQ+lP1QNcrNt/8mriFVSpJ/O6sps9QsFXSVDRmSjrEyK1u7b9A7
# fTHQa0wez8+WhQseuI+T3w8XWW4EQ1LV5ZrNn7D0W9V3klspJQiNHc/9v3GFl2qn
# d6KvYuNiRFLjPOYwpk7StAObUmBEtcQs6E/7663Dq2dtgMC+uLmlyoiEDE4ILcYa
# mCqeLMMzYuTIsLonIPVMTtUv0PEY3hqNnQuewCgelY0TT99jtfOLX/1Rr5sIQ8Wc
# 5JDltc18S+OsTJYwrHivzX34wspdH4iVux/Sn6SnNdCfGAZRxVazlWCYFz/yJVQ0
# wUeQnZAkqh4dsMkqL8B65+vi05hk8EZi7NXn4ZghCbQ/Z7rZnKWMUCkYmszoot9Z
# ae6c0QRmkFC50gl4ENJEZx/7A0f8EGwHxBUiSVj8TZioOcRSgrTbjhE478XjotJs
# 7VjgPJzYkE6sadSsbbHsy+Ffcf+Cfz4WG9NPrdo0zo2elU3mPNUjKoyMVvRvRUs+
# QUFpN+VB1Wq+9ajhjMGbP2G3xclkOh1/nDmGicKONfDq+TscUlURUAHoO+7+cXtg
# 1WnjlLVv8zIiKtlkehQr2oVyAZs4P49mOo8aHUHHjfhH6CECAQKFtf9QiZOqTLyp
# YoYgmjnCZf9fDO5xxfRIS3t5g5CCtdj8hnn08t76m173Tkn1nbk=
# SIG # End signature block
