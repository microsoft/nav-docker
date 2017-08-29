$Accept_eula = "$env:Accept_eula"

$auth = "$env:Auth"
if ($auth -eq "") {
    if ("$env:WindowsAuth" -eq "Y") {
        $auth = "Windows"
    }
}
$username = "$env:username"
if ($username -eq "ContainerAdministrator") {
    $username = ""
}
$password = "$env:password"

$licensefile = "$env:licensefile"

$bakfile = "$env:bakfile"
if ($bakfile -ne "") {
    $databaseServer = "localhost"
    $databaseInstance = ""
    $databaseName = ""
} else {
    $databaseServer = "$env:databaseServer"
    $databaseInstance = "$env:databaseInstance"
    $databaseName = "$env:databaseName"
    if ($databaseServer -eq "") {
        $databaseServer = "localhost"
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
