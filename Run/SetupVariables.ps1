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

$Accept_eula = "$env:Accept_eula"
$useSSL = "$env:UseSSL"
$auth = "$env:Auth"
if ($auth -eq "") {
    if ("$env:WindowsAuth" -eq "Y") {
        $auth = "Windows"
    }
}
$clickOnce = "$env:ClickOnce"
$SqlTimeout = "$env:SqlTimeout"
if ($SqlTimeout -eq "") {
    $SqlTimeout = "300"
}
