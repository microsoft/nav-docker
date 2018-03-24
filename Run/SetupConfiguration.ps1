# INPUT
#     $auth
#     $protocol
#     $publicDnsName
#     $ServiceTierFolder
#     $navUseSSL
#     $servicesUseSSL
#     $certificateThumbprint
#
# OUTPUT
#

Write-Host "Modifying NAV Service Tier Config File with Instance Specific Settings"
$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
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
$customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value = "$multitenant"

$taskSchedulerKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']") -ne $null)
if ($taskSchedulerKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']").Value = "false"
}

$developerServicesKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']") -ne $null)
if ($developerServicesKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']").Value = "7049"
    $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesEnabled']").Value = "true"
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
}

$customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value = $auth
if ($developerServicesKeyExists) {
    $publicWebBaseUrl = "$protocol$publicDnsName$publicwebClientPort/NAV/"
} else {
    $publicWebBaseUrl = "$protocol$publicDnsName$publicwebClientPort/NAV/WebClient/"
}
if ($WebClient -ne "N") {
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value = $publicWebBaseUrl
}
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicSOAPBaseUrl']").Value = "$protocol${publicDnsName}:$publicSoapPort/NAV/WS"
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicODataBaseUrl']").Value = "$protocol${publicDnsName}:$publicODataPort/NAV/OData"
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWinBaseUrl']").Value = "DynamicsNAV://${publicDnsName}:$publicWinClientPort/NAV/"
if ($navUseSSL) {
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='ServicesCertificateThumbprint']").Value = "$certificateThumbprint"
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='ServicesCertificateValidationEnabled']").Value = "false"
}

$CustomConfig.SelectSingleNode("//appSettings/add[@key='SOAPServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
$CustomConfig.SelectSingleNode("//appSettings/add[@key='ODataServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()

$enableSymbolLoadingAtServerStartupKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']") -ne $null)
if ($enableSymbolLoadingAtServerStartupKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']").Value = "$($enableSymbolLoadingAtServerStartup -eq $true)"
}

if ($isBcSandbox) {
    Set-ConfigSetting -customSettings "TenantEnvironmentType=Sandbox" -parentPath "//appSettings" -leafName "add" -customConfig $customConfig -silent
    Set-ConfigSetting -customSettings "EnableSaasExtensionInstall=true" -parentPath "//appSettings" -leafName "add" -customConfig $customConfig -silent
}

if ($customNavSettings -ne "") {
    Write-Host "Modifying NAV Service Tier Config File with settings from environment variable"    
    Set-ConfigSetting -customSettings $customNavSettings -parentPath "//appSettings" -leafName "add" -customConfig $CustomConfig
}

if ($auth -eq "AccessControlService") {
    if ($appIdUri -eq "") {
        $appIdUri = "$publicWebBaseUrl"
    }
    if ($federationMetadata -eq "") {
        $federationMetadata = "https://login.windows.net/Common/federationmetadata/2007-06/federationmetadata.xml"
    }
    if ($federationLoginEndpoint -eq "") {
        $federationLoginEndpoint = "https://login.windows.net/Common/wsfed?wa=wsignin1.0%26wtrealm=$appIdUri"
    }

    $customConfig.SelectSingleNode("//appSettings/add[@key='AppIdUri']").Value = $appIdUri
    $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesFederationMetadataLocation']").Value = $federationMetadata
    if ($customConfig.SelectSingleNode("//appSettings/add[@key='WSFederationLoginEndpoint']") -ne $null) {
        $customConfig.SelectSingleNode("//appSettings/add[@key='WSFederationLoginEndpoint']").Value = $federationLoginEndpoint
    }
}

$CustomConfig.Save($CustomConfigFile)

7045,7047,7048,7049 | % {
    netsh http add urlacl url=$protocol+:$_/NAV user="NT AUTHORITY\SYSTEM" | Out-Null
    if ($servicesUseSSL) {
        netsh http add sslcert ipport=0.0.0.0:$_ certhash=$certificateThumbprint appid="{00112233-4455-6677-8899-AABBCCDDEEFF}" | Out-Null
    }
}

if ($navUseSSL) {
    netsh http add urlacl url=https://+:7046/NAV user="NT AUTHORITY\SYSTEM" | Out-Null
    netsh http add sslcert ipport=0.0.0.0:7046 certhash=$certificateThumbprint appid="{00112233-4455-6677-8899-AABBCCDDEEFF}" | Out-Null
} else {
    netsh http add urlacl url=http://+:7046/NAV user="NT AUTHORITY\SYSTEM" | Out-Null
}

if ($developerServicesKeyExists) {
    $serverConfigFile = Join-Path $ServiceTierFolder "Microsoft.Dynamics.Nav.Server.exe.config"
    $serverConfig = [xml](Get-Content -Path $serverConfigFile)
    $serverConfig.SelectSingleNode("//configuration/runtime/NetFx40_LegacySecurityPolicy").enabled = "false"
    $serverConfig.Save($serverConfigFile)
}
