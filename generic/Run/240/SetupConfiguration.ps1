﻿# INPUT
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

Write-Host "Modifying Service Tier Config File with Instance Specific Settings"
$CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
$CustomConfig = [xml](Get-Content $CustomConfigFile)

$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value = $databaseServer
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value = $databaseInstance
$customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value = "$databaseName"
$customConfig.SelectSingleNode("//appSettings/add[@key='ServerInstance']").Value = "$serverInstance"
$customConfig.SelectSingleNode("//appSettings/add[@key='ManagementServicesPort']").Value = "$managementServicesPort"
$customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesPort']").Value = "$clientServicesPort"
$customConfig.SelectSingleNode("//appSettings/add[@key='SOAPServicesPort']").Value = "$soapServicesPort"
$customConfig.SelectSingleNode("//appSettings/add[@key='ODataServicesPort']").Value = "$oDataServicesPort"
$customConfig.SelectSingleNode("//appSettings/add[@key='DefaultClient']").Value = "Web"
$customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value = "$multitenant"
if (!$multitenant -and "$applicationInsightsInstrumentationKey" -ne "") {
    $customConfig.SelectSingleNode("//appSettings/add[@key='ApplicationInsightsInstrumentationKey']").Value = "$applicationInsightsInstrumentationKey"
}

$taskSchedulerKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']") -ne $null)
if ($taskSchedulerKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']").Value = "false"
}

$developerServicesKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']") -ne $null)
if ($developerServicesKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesPort']").Value = "$developerServicesPort"
    $customConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesEnabled']").Value = "true"
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='DeveloperServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
}

$SnapshotDebuggerKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='SnapshotDebuggerServicesPort']") -ne $null)
if ($SnapshotDebuggerKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='SnapshotDebuggerServicesPort']").Value = "$snapshotDebuggerServicesPort"
    $customConfig.SelectSingleNode("//appSettings/add[@key='SnapshotDebuggerEnabled']").Value = "true"
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='SnapshotDebuggerServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
}

$customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesCredentialType']").Value = $auth
if ($developerServicesKeyExists) {
    $publicWebBaseUrl = "$protocol$publicDnsName$publicwebClientPort/$WebServerInstance/"
} else {
    $publicWebBaseUrl = "$protocol$publicDnsName$publicwebClientPort/$WebServerInstance/WebClient/"
}
if ($WebClient -ne "N") {
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value = $publicWebBaseUrl
}
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicSOAPBaseUrl']").Value = "$protocol${publicDnsName}:$publicSoapPort/$ServerInstance/WS/"
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicODataBaseUrl']").Value = "$protocol${publicDnsName}:$publicODataPort/$ServerInstance/OData"
$CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWinBaseUrl']").Value = "DynamicsNAV://${publicDnsName}:$publicWinClientPort/$ServerInstance/"
if ($servicesUseSSL) {
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='ServicesCertificateThumbprint']").Value = "$certificateThumbprint"
    $CustomConfig.SelectSingleNode("//appSettings/add[@key='ServicesCertificateValidationEnabled']").Value = "false"
}

$CustomConfig.SelectSingleNode("//appSettings/add[@key='SOAPServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()
$CustomConfig.SelectSingleNode("//appSettings/add[@key='ODataServicesSSLEnabled']").Value = $servicesUseSSL.ToString().ToLower()

$enableSymbolLoadingAtServerStartupKeyExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']") -ne $null)
if ($enableSymbolLoadingAtServerStartupKeyExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='EnableSymbolLoadingAtServerStartup']").Value = "$($enableSymbolLoadingAtServerStartup -eq $true)"
}

$apiServicesEnabledExists = ($customConfig.SelectSingleNode("//appSettings/add[@key='ApiServicesEnabled']") -ne $null)
if (($enableApiServices -ne $null) -and $apiServicesEnabledExists) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='ApiServicesEnabled']").Value = "$($enableApiServices -eq $true)"
}

if ($isBcSandbox) {
    $customConfig.SelectSingleNode("//appSettings/add[@key='EnableTaskScheduler']").Value = "true"
    Set-ConfigSetting -customSettings "TenantEnvironmentType=Sandbox" -parentPath "//appSettings" -leafName "add" -customConfig $customConfig -silent
    Set-ConfigSetting -customSettings "EnableSaasExtensionInstall=true" -parentPath "//appSettings" -leafName "add" -customConfig $customConfig -silent
}

if ($customNavSettings -ne "") {
    Write-Host "Modifying Service Tier Config File with settings from environment variable"    
    Set-ConfigSetting -customSettings $customNavSettings -parentPath "//appSettings" -leafName "add" -customConfig $CustomConfig
}

if ($auth -eq "AccessControlService") {
    if ($appIdUri -eq "") {
        $appIdUri = "$publicWebBaseUrl"
    }
    if ("$aadTenant" -eq "") {
        $aadTenant = "Common"
    }
    if ($federationMetadata -eq "") {
        $federationMetadata = "https://login.microsoftonline.com/$aadTenant/FederationMetadata/2007-06/FederationMetadata.xml"
    }
    if ($federationLoginEndpoint -eq "") {
        $federationLoginEndpoint = "https://login.microsoftonline.com/$aadTenant/wsfed?wa=wsignin1.0%26wtrealm=$appIdUri"
    }

    $customConfig.SelectSingleNode("//appSettings/add[@key='AppIdUri']").Value = $appIdUri
    $clientServicesFederationMetadataLocationNode = $customConfig.SelectSingleNode("//appSettings/add[@key='ClientServicesFederationMetadataLocation']")
    if ($clientServicesFederationMetadataLocationNode) {
        $clientServicesFederationMetadataLocationNode.Value = $federationMetadata
    }
    $WSFederationLoginEndpointNode = $customConfig.SelectSingleNode("//appSettings/add[@key='WSFederationLoginEndpoint']")
    if ($WSFederationLoginEndpointNode) {
        $WSFederationLoginEndpointNode.Value = $federationLoginEndpoint
    }
    $ADOpenIdMetadataLocationNode = $customConfig.SelectSingleNode("//appSettings/add[@key='ADOpenIdMetadataLocation']")
    if ($ADOpenIdMetadataLocationNode -and $ADOpenIdMetadataLocationNode.Value -eq "") {
        $ADOpenIdMetadataLocationNode.Value = "https://login.microsoftonline.com/common/.well-known/openid-configuration"
    }
}

$CustomConfig.Save($CustomConfigFile)

$managementServicesPort,$soapServicesPort,$oDataServicesPort,$developerServicesPort,$SnapshotDebuggerServicesPort | % {
    netsh http add urlacl url=$protocol+:$_/$ServerInstance user="NT AUTHORITY\SYSTEM" | Out-Null
    if ($servicesUseSSL) {
        netsh http add sslcert ipport=0.0.0.0:$_ certhash=$certificateThumbprint appid="{00112233-4455-6677-8899-AABBCCDDEEFF}" | Out-Null
    }
}
netsh http add urlacl url=http://+:$clientServicesPort/$ServerInstance user="NT AUTHORITY\SYSTEM" | Out-Null

if ($developerServicesKeyExists) {
    $serverConfigFile = Join-Path $ServiceTierFolder "Microsoft.Dynamics.Nav.Server.exe.config"
    $serverConfig = [xml](Get-Content -Path $serverConfigFile)
    $legacySecurityPolicyNode = $serverConfig.SelectSingleNode("//configuration/runtime/NetFx40_LegacySecurityPolicy")
    if ($legacySecurityPolicyNode) {
        $legacySecurityPolicyNode.enabled = "false"
    }
    $serverConfig.Save($serverConfigFile)
}
