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
    }
}
$username = "$env:username"
if ($username -eq "ContainerAdministrator") { $username = "" }
if ($auth -ne "Windows") {
    if ($username -eq "") { $username = "admin" }
}
 
$passwordSpecified = $false
if ("$env:password" -ne "") {
    $securepassword = ConvertTo-SecureString -String "$env:password" -AsPlainText -Force
    $env:password = ""
    $passwordSpecified = $true
} elseif ("$env:securepassword" -ne "" -and "$env:passwordKeyFile" -ne "") {
    $securePassword = ConvertTo-SecureString -String $adminPassword -Key (Get-Content -Path "$env:passwordKeyFile")
    if ($env:RemovePasswordKeyFile -eq "Y") {
        Remove-Item -Path "$env:passwordKeyFile" -Force
    }
    $env:passwordKeyFile = ""
    $env:securePassword = ""
    $passwordSpecified = $true
} else {
    if ($auth -ne "Windows") {
        $securePassword = ConvertTo-SecureString -String (Get-RandomPassword) -AsPlainText -Force
    }
}

$licensefile = "$env:licensefile"

$bakfile = "$env:bakfile"
if ($bakfile -ne "") {
    $databaseServer = "localhost"
    $databaseInstance = "SQLEXPRESS"
    $databaseName = ""
} else {
    $databaseServer = "$env:databaseServer"
    $databaseInstance = "$env:databaseInstance"
    $databaseName = "$env:databaseName"
    if ($databaseServer -eq "" -and $databaseInstance -eq "") {
        $databaseServer = "localhost"
        $databaseInstance = "SQLEXPRESS"
    }
}

$useSSL = "$env:UseSSL"
$clickOnce = "$env:ClickOnce"
$webClient = "$env:WebClient"
$httpSite = "$env:HttpSite"
$SqlTimeout = "$env:SqlTimeout"
if ($SqlTimeout -eq "") {
    $SqlTimeout = "300"
}

$publicWebClientPort = "$env:publicWebClientPort"
$publicFileSharePort = "$env:publicFileSharePort"
$publicSoapPort = "$env:publicSoapPort"
$publicODataPort = "$env:publicODataPort"
$publicWinClientPort = "$env:publicWinClientPort"

$locale = "$env:locale"
if ($locale)  {
    $cultureInfo = new-object System.Globalization.CultureInfo $locale
    $regionInfo = new-object System.Globalization.RegionInfo $locale
    Set-WinHomeLocation -GeoId $regionInfo.GeoId
    Set-WinSystemLocale -SystemLocale $cultureInfo
    Set-Culture -CultureInfo $cultureInfo
}
