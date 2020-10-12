$Accept_eula = "$env:Accept_eula"
$Accept_outdated = "$env:Accept_outdated"

$hostname = hostname
$publicDnsName = "$env:PublicDnsName"
if ($publicDnsName -eq "") {
    $publicDnsName = $hostname
}
$clickOnceIdentity = "$env:ClickOnceIdentity"
if ($clickOnceIdentity -eq "") {
    $clickOnceIdentity = $publicDnsName
}

$auth = "$env:Auth"
if ($auth -eq "") {
    if ("$env:WindowsAuth" -eq "Y") {
        $auth = "Windows"
    } else {
        $auth = "NavUserPassword"
    }
} elseif ($auth -eq "windows") {
    $auth = "Windows"
} elseif ($auth -eq "accesscontrolservice" -or $auth -eq "aad") {
    $auth = "AccessControlService"
} else {
    $auth = "NavUserPassword"
}

$username = "$env:username"
if ($username -eq "ContainerAdministrator") { $username = "" }
if ($auth -ne "Windows") {
    if ($username -eq "") { $username = "admin" }
}

$databaseCredentials = $null
$EncryptionSecurePassword = $null
$passwordSpecified = $false
$securepassword = $null

if (!$restartingInstance) {
    if ("$env:databasePassword" -ne "") {
        $databaseCredentials = New-Object PSCredential -ArgumentList "$env:databaseUserName", (ConvertTo-SecureString -String "$env:databasePassword" -AsPlainText -Force)
        Remove-Item env:\databasePassword -ErrorAction Ignore
    } elseif ("$env:databaseSecurepassword" -ne "" -and "$env:passwordKeyFile" -ne "") {
        $databaseCredentials = New-Object PSCredential -ArgumentList "$env:databaseUserName", (ConvertTo-SecureString -String "$env:databaseSecurepassword" -Key (Get-Content -Path "$env:passwordKeyFile"))
        Remove-Item env:\databaseSecurePassword -ErrorAction Ignore
    }

    if ("$env:encryptionPassword" -ne "") {
        $EncryptionSecurePassword = ConvertTo-SecureString -String "$env:encryptionPassword" -AsPlainText -Force
        Remove-Item env:\encryptionPassword -ErrorAction Ignore
    } elseif ("$env:encryptionSecurepassword" -ne "" -and "$env:passwordKeyFile" -ne "") {
        $EncryptionSecurePassword = ConvertTo-SecureString -String "$env:encryptionSecurepassword" -Key (Get-Content -Path "$env:passwordKeyFile")
        Remove-Item env:\encryptionSecurePassword -ErrorAction Ignore
    } else {
        $EncryptionSecurePassword = ConvertTo-SecureString -String (Get-RandomPassword) -AsPlainText -Force
    }

    if ("$env:password" -ne "") {
        $securepassword = ConvertTo-SecureString -String "$env:password" -AsPlainText -Force
        Remove-Item env:\password -ErrorAction Ignore
        $passwordSpecified = $true
    } elseif ("$env:securepassword" -ne "" -and "$env:passwordKeyFile" -ne "") {
        $securePassword = ConvertTo-SecureString -String "$env:securepassword" -Key (Get-Content -Path "$env:passwordKeyFile")
        Remove-Item env:\securePassword -ErrorAction Ignore
        $passwordSpecified = $true
    } else {
        if ($auth -ne "Windows") {
            $securePassword = ConvertTo-SecureString -String (Get-RandomPassword) -AsPlainText -Force
        }
    }
}

if ($env:RemovePasswordKeyFile -ne "N" -and "$env:passwordKeyFile" -ne "") {
    Remove-Item -Path "$env:passwordKeyFile" -Force -ErrorAction Ignore
}
Remove-Item env:\passwordKeyFile -ErrorAction Ignore

$licensefile = "$env:licensefile"

$appBacpac = "$env:appBacpac"
$tenantBacpac = "$env:tenantBacpac"

if ("$env:multitenant" -ne "") {
    $multitenant = ("$env:multitenant" -eq "Y")
}
else {
    try {
        $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
        $CustomConfigFile =  Join-Path $ServiceTierFolder "CustomSettings.config"
        $CustomConfig = [xml](Get-Content $CustomConfigFile)
        $multitenant = ($customConfig.SelectSingleNode("//appSettings/add[@key='Multitenant']").Value -eq "true")
    }
    catch {
        $multitenant = $false
    }
}

if ("$appBacpac" -ne "" -and "$tenantBacpac" -ne "") {
    $multitenant = $true
}

if ($multitenant) {
    $TenantId = "default"
    $tenantParam = @{ "Tenant" = "$tenantId" }
    $webTenantParam = "?tenant=$tenantId"
} else {
    $tenantParam = @{}
    $webTenantParam = ""
}

$bakfile = "$env:bakfile"
if ($bakfile -ne "") {
    $databaseServer = "localhost"
    $databaseInstance = "SQLEXPRESS"
    $databaseName = "mydatabase"
} else {
    $databaseServer = "$env:databaseServer"
    $databaseInstance = "$env:databaseInstance"
    if ($databaseServer -eq "" -and $databaseInstance -eq "") {
        $databaseServer = "localhost"
        $databaseInstance = "SQLEXPRESS"
    }
    $databaseName = "$env:databaseName"
    if ($databaseName -eq "") {
        $databaseName = "CRONUS"
    }
}

$useSSL = "$env:UseSSL"
if ($auth -eq "Windows") {
    $navUseSSL = $false
} else {
    $navUseSSL = $true
}
if ($useSSL -eq "Y") {
    $servicesUseSSL = $true
} elseif ($useSSL -eq "N") {
    $servicesUseSSL = $false
} else {
    $servicesUseSSL = $navUseSSL
}
if ($servicesUseSSL) {
    $protocol = "https://"
    $webClientPort = 443
} else {
    $protocol = "http://"
    $webClientPort = 80
}

$clickOnce = "$env:ClickOnce"
$webClient = "$env:WebClient"
$httpSite = "$env:HttpSite"
$SqlTimeout = "$env:SqlTimeout"
if ($SqlTimeout -eq "") {
    $SqlTimeout = "300"
}

# Set Port overrides
$fileSharePort                 = "$env:fileSharePort"
$managementServicesPort        = "$env:managementServicesPort"
$clientServicesPort            = "$env:clientServicesPort"
$soapServicesPort              = "$env:soapServicesPort"
$oDataServicesPort             = "$env:oDataServicesPort"
$developerServicesPort         = "$env:developerServicesPort"
$snapshotDebuggerServicesPort  = "$env:snapshotDebuggerServicesPort"
if ("$env:webClientPort" -ne "") {
    $webClientPort = "$env:webClientPort"
}

if ("$fileSharePort" -eq "")          { 
    if ($webClientPort -eq "8080") {
        $httpSite = "N"
    }
    else {
        $fileSharePort = "8080"
    }
}
if ("$managementServicesPort" -eq "")       { $managementServicesPort       = "7045" }
if ("$clientServicesPort" -eq "")           { $clientServicesPort           = "7046" }
if ("$soapServicesPort" -eq "")             { $soapServicesPort             = "7047" }
if ("$oDataServicesPort" -eq "")            { $oDataServicesPort            = "7048" }
if ("$developerServicesPort" -eq "")        { $developerServicesPort        = "7049" }
if ("$snapshotDebuggerServicesPort" -eq "") { $snapshotDebuggerServicesPort = "7083" }

# Set public ports
$publicWebClientPort = "$env:publicWebClientPort"
$publicFileSharePort = "$env:publicFileSharePort"
$publicWinClientPort = "$env:publicWinClientPort"
$publicSoapPort      = "$env:publicSoapPort"
$publicODataPort     = "$env:publicODataPort"

# Default public ports
if ($publicWebClientPort -ne "") {
    $publicWebClientPort = ":$publicWebClientPort"
} elseif ("$env:webClientPort" -ne "") {
    $publicWebClientPort = ":$webClientPort"
}

if ($publicFileSharePort -eq "") { $publicFileSharePort = "$fileSharePort" }
if ($publicWinClientPort -eq "") { $publicWinClientPort = "$clientServicesPort" }
if ($publicSoapPort      -eq "") { $publicSoapPort      = "$soapServicesPort" }
if ($publicODataPort     -eq "") { $publicODataPort     = "$oDataServicesPort" }

if ("$env:WebServerInstance" -ne "") {
    $webServerInstance = "$env:WebServerInstance"
}

# AccessControlService
$appIdUri = "$env:appIdUri"
$federationLoginEndpoint = "$env:federationLoginEndpoint"
$federationMetadata = "$env:federationMetadata"
$authenticationEMail = "$env:authenticationEMail"

$locale = "$env:locale"
if ($locale)  {
    $cultureInfo = new-object System.Globalization.CultureInfo $locale
    $regionInfo = new-object System.Globalization.RegionInfo $locale
    try { Set-WinHomeLocation -GeoId $regionInfo.GeoId   } catch {}
    try { Set-WinSystemLocale -SystemLocale $cultureInfo } catch {}
    try { Set-Culture -CultureInfo $cultureInfo          } catch {}
}

$isBcSandbox = ($env:isBcSandbox -eq "Y")
$enableSymbolLoadingAtServerStartup = ($env:enableSymbolLoading -eq "Y")
$enableApiServices = ($env:enableApiServices -eq "Y")

if ("$env:defaultTenantHasAllowAppDatabaseWrite" -ne "") {
    $defaultTenantHasAllowAppDatabaseWrite = $env:defaultTenantHasAllowAppDatabaseWrite -eq "Y"
}
else {
    $defaultTenantHasAllowAppDatabaseWrite = !$isBcSandbox
}

$customNavSettings = "$env:customNavSettings"
$customWebSettings = "$env:customWebSettings"
$customWinSettings = "$env:customWinSettings"

$enableWarningsInLog = ($env:enableWarningsInLog -eq "Y")