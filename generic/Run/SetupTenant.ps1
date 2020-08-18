if ($restartingInstance) {

    # Nothing to do

} elseif ($databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {

    if (!(Test-NavDatabase -DatabaseName $TenantId)) {
        # Setup tenant
        Copy-NavDatabase -SourceDatabaseName "tenant" -DestinationDatabaseName $TenantId
        Mount-NavDatabase -ServerInstance $ServerInstance -TenantId $TenantId -DatabaseName $TenantId
    }
    $tenantStartTime = [DateTime]::Now
    while ([DateTime]::Now.Subtract($tenantStartTime).TotalSeconds -le 60) {
        $tenantInfo = Get-NAVTenant -ServerInstance $ServerInstance -Tenant $TenantId
        if ($tenantInfo.State -eq "Operational") { break }
        Start-Sleep -Seconds 1
    }
    Write-Host "Tenant is $($TenantInfo.State)"
}