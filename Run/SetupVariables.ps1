$Accept_eula = "$env:Accept_eula"

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

$password = ""
# decrypt the environment password and remove the key
if ($runPath -eq "") { 
   $runPath = "c:\Run"
}
if ("$env:passwordencrypted" -ne "" -and (Test-Path (Join-Path $runPath "HelperFunctions2.ps1"))) {
    $passwordencrypted = "$env:passwordencrypted"
    $passwordkey       = "$env:passwordkey"

    . (Join-Path $runPath "HelperFunctions2.ps1")
    if ("$passwordkey" -eq "") {
        $passwordkeypath   = "$env:passwordkeypath"
        if ("$passwordkeypath" -eq "" -or !(Test-Path $passwordkeypath)) {
            $runPath           = "c:\Run"
            $myPath            = (Join-Path $runPath "my")
            $passwordkeypath   = (Join-Path $myPath "pwd.key")
        }
        if (Test-Path $passwordkeypath) {
            $passwordkey  = (Get-SecureKey "$env:passwordkeypath")
            Remove-Item "$env:passwordkeypath" -Force -ErrorAction SilentlyContinue
        }
    } else {
        $passwordkey  = ($env:passwordkey | ConvertFrom-Json)
    } 
   
    # get the plain password into the variable
    if (($passwordencrypted -ne "") -and ($passwordkey -ne "")) {
        $password = (Get-PlainSecurePassword $passwordkey $passwordencrypted)
    }

    # clean up the variables (avoid later access)
    $env:passwordencrypted = ""
    $env:passwordkey       = ""
    $env:passwordkeypath   = ""
    $passwordencrypted     = ""
    $passwordkey           = ""
    $passwordkeypath       = ""    
}

# use plain password from environment only, when present 
if ("$env:password" -ne "") {
    $password = "$env:password"
}

$passwordSpecified = ($password -ne "")
if ($auth -ne "Windows") {
    if (!$passwordSpecified) { $password = Get-RandomPassword }
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
