if ($newPublicDnsName -and $databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {

    if (!(Test-NavDatabase -DatabaseName $TenantId)) {
        Write-Host "Copying template database"
        Copy-NavDatabase -SourceDatabaseName "tenant" -DestinationDatabaseName $TenantId
    }
    else {
        Write-Host "Dismounting Tenant"
        Dismount-NavTenant -ServerInstance $ServerInstance -Tenant $TenantId -Force | Out-Null
    }
    $alternateId = @($hostname, "$hostname-$TenantId")
    if ($publicDnsName -ne $hostname) {
        $alternateId += @($publicDnsName)
    }
    Write-Host "Mounting Tenant"
    Mount-NavDatabase -ServerInstance $ServerInstance -TenantId $TenantId -DatabaseName $TenantId -AlternateId $alternateId
    $tenantStartTime = [DateTime]::Now
    while ([DateTime]::Now.Subtract($tenantStartTime).TotalSeconds -le 60) {
        $tenantInfo = Get-NAVTenant -ServerInstance $ServerInstance -Tenant $TenantId
        if ($tenantInfo.State -eq "Operational") { break }
        Start-Sleep -Seconds 1
    }
    Write-Host "Tenant is $($TenantInfo.State)"
}