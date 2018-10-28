if ($restartingInstance) {

    # Nothing to do

} elseif ($databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {

    # Setup tenant
    Copy-NavDatabase -SourceDatabaseName "tenant" -DestinationDatabaseName $TenantId
    Mount-NavDatabase -ServerInstance $ServerInstance -TenantId $TenantId -DatabaseName $TenantId

}