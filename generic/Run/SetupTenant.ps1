if ($newPublicDnsName -and $databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {

    if (!(Test-NavDatabase -DatabaseName $TenantId)) {
        Write-Host "Copying template database"
        Copy-NavDatabase -SourceDatabaseName "tenant" -DestinationDatabaseName $TenantId
    }
    else {
        Write-Host "Dismounting Tenant"
        Dismount-NavTenant -ServerInstance $ServerInstance -Tenant $TenantId -Force | Out-Null
    }

    $hostname = hostname
    $dotidx = $hostname.indexOf('.')
    if ($dotidx -eq -1) { $dotidx = $hostname.Length }
    $tenantHostname = $hostname.insert($dotidx,"-$tenantId")
    $alternateId = @($tenantHostname)

    if ($applicationInsightsInstrumentationKey) {
        Write-Host "Mounting Tenant with ApplicationInsightsInstrumentationKey"
    }
    else {
        Write-Host "Mounting Tenant"
    }
    $parameters = @{
        "ServerInstance" = $ServerInstance
        "TenantId" = $TenantId
        "DatabaseName" = $TenantId
        "AlternateId" = $alternateId
        "applicationInsightsInstrumentationKey" = $applicationInsightsInstrumentationKey
    }
    if ($AuthenticationEmail) {
        $aadTenantId = "$env:aadTenant"
        if ($aadTenantId -eq "" -or $aadTenantId -eq "common") {
            $aadTenantId = $AuthenticationEmail.Split('@')[1]
        }
        $parameters += @{
            "AadTenantId" = $aadTenantId
        }
        Write-Host "Setting AadTenantId to $aadTenantId"
    }
    Mount-NavDatabase @parameters
    $tenantStartTime = [DateTime]::Now
    while ([DateTime]::Now.Subtract($tenantStartTime).TotalSeconds -le 60) {
        $tenantInfo = Get-NAVTenant -ServerInstance $ServerInstance -Tenant $TenantId
        if ($tenantInfo.State -eq "Operational") { break }
        Start-Sleep -Seconds 1
    }
    Write-Host "Tenant is $($TenantInfo.State)"
}