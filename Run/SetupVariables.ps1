$username = "$env:username"
if ($username -eq "ContainerAdministrator") {
    $username = ""
}
$password = "$env:password"
$licensefile = "$env:licensefile"
$bakfile = "$env:bakfile"
$databaseServer = "$env:databaseServer"
if ($databaseServer -eq "") {
    $databaseServer = "localhost"
}
$databaseInstance = "$env:databaseInstance"
$databaseName = "$env:databaseName"
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
