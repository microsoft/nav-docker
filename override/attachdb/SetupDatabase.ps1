if ($restartingInstance) {
    # Nothing to do
}
else {
    $dbpath = "c:\mydb"
    $mdf = (Get-Item (Join-Path $dbpath "*.mdf")).FullName
    $ldf = (Get-Item (Join-Path $dbpath "*.ldf")).FullName
    $databaseName = "MYCRONUS"
    $databaseServer = "localhost"
    $databaseInstance = "SQLEXPRESS"
    $attachcmd = "USE [master] CREATE DATABASE [$DatabaseName] ON (FILENAME = '$mdf'),(FILENAME = '$ldf') FOR ATTACH"
    Write-Host "Attaching database in $mdf/$ldf as $DatabaseName"
    Invoke-Sqlcmd -ServerInstance localhost\SQLEXPRESS -QueryTimeOut 0 -ea Stop -Query $attachcmd
}
