$Accept_eula = "$env:Accept_eula"
$Accept_outdated = "$env:Accept_outdated"

$hostname = hostname
$publicDnsName = "$env:PublicDnsName"
if ($publicDnsName -eq "") {
    $publicDnsName = $hostname
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
} else {
    $auth = "NavUserPassword"
}

$username = "$env:username"
if ($username -eq "ContainerAdministrator") { $username = "" }
if ($auth -ne "Windows") {
    if ($username -eq "") { $username = "admin" }
}

$databaseCredentials = $null
if ("$env:databasePassword" -ne "") {
    $databaseCredentials = New-Object PSCredential -ArgumentList "$env:databaseUserName", (ConvertTo-SecureString -String "$env:databasePassword" -AsPlainText -Force)
} elseif ("$env:databaseSecurepassword" -ne "" -and "$env:passwordKeyFile" -ne "" -and $restartingInstance -eq $false) {
    $databaseCredentials = New-Object PSCredential -ArgumentList "$env:databaseUserName", (ConvertTo-SecureString -String "$env:databaseSecurepassword" -Key (Get-Content -Path "$env:passwordKeyFile"))
}

if ("$env:encryptionPassword" -ne "") {
    $EncryptionSecurePassword = ConvertTo-SecureString -String "$env:encryptionPassword" -AsPlainText -Force
} elseif ("$env:encryptionSecurepassword" -ne "" -and "$env:passwordKeyFile" -ne "") {
    $EncryptionSecurePassword = ConvertTo-SecureString -String "$env:databaseSecurepassword" -Key (Get-Content -Path "$env:passwordKeyFile")
} else {
    $EncryptionSecurePassword = ConvertTo-SecureString -String (Get-RandomPassword) -AsPlainText -Force
}

$passwordSpecified = $false
if ("$env:password" -ne "") {
    $securepassword = ConvertTo-SecureString -String "$env:password" -AsPlainText -Force
    Remove-Item env:\password -ErrorAction Ignore
    $passwordSpecified = $true
} elseif ("$env:securepassword" -ne "" -and "$env:passwordKeyFile" -ne "" -and $restartingInstance -eq $false) {
    $securePassword = ConvertTo-SecureString -String "$env:securepassword" -Key (Get-Content -Path "$env:passwordKeyFile")
    Remove-Item env:\securePassword -ErrorAction Ignore
    $passwordSpecified = $true
} else {
    if ($auth -ne "Windows") {
        $securePassword = ConvertTo-SecureString -String (Get-RandomPassword) -AsPlainText -Force
    }
}

if ($env:RemovePasswordKeyFile -ne "N" -and "$env:passwordKeyFile" -ne "") {
    Remove-Item -Path "$env:passwordKeyFile" -Force -ErrorAction Ignore
}
Remove-Item env:\passwordKeyFile -ErrorAction Ignore

$licensefile = "$env:licensefile"

$bakfile = "$env:bakfile"
if ($bakfile -ne "") {
    $databaseServer = "localhost"
    $databaseInstance = "SQLEXPRESS"
    $databaseName = ""
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

# Set public ports
$publicWebClientPort = "$env:publicWebClientPort"
$publicFileSharePort = "$env:publicFileSharePort"
$publicWinClientPort = "$env:publicWinClientPort"
$publicSoapPort      = "$env:publicSoapPort"
$publicODataPort     = "$env:publicODataPort"

# Default public ports
if ($publicWebClientPort -ne "") { $publicWebClientPort = ":$publicWebClientPort" }
if ($publicFileSharePort -eq "") { $publicFileSharePort = "8080" }
if ($publicWinClientPort -eq "") { $publicWinClientPort = "7046" }
if ($publicSoapPort      -eq "") { $publicSoapPort      = "7047" }
if ($publicODataPort     -eq "") { $publicODataPort     = "7048" }

$locale = "$env:locale"
if ($locale)  {
    $cultureInfo = new-object System.Globalization.CultureInfo $locale
    $regionInfo = new-object System.Globalization.RegionInfo $locale
    Set-WinHomeLocation -GeoId $regionInfo.GeoId
    Set-WinSystemLocale -SystemLocale $cultureInfo
    Set-Culture -CultureInfo $cultureInfo
}

$enableSymbolLoadingAtServerStartup = ($env:enableSymbolLoading -eq "Y")

$folders = "$env:folders"