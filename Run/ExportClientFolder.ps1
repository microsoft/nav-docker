if ([System.String]::IsNullOrEmpty($exportClientFolderPath)) {
    $exportClientFolderPath = $myPath;
}

if (!(Test-Path "$exportClientFolderPath\RoleTailored Client" -PathType Container)) {
    Write-Host "Copying RoleTailoted Client files"
    Copy-Item -path $roleTailoredClientFolder -destination $exportClientFolderPath -force -Recurse -ErrorAction Ignore

    $sqlServerName = if ($databaseServer -eq "localhost") { $hostname } else { $databaseServer }
    if (!([System.String]::IsNullOrEmpty($databaseInstance))) {
        $sqlServerName = "$sqlServerName\$databaseInstance"
    }

    $ntAuth = if ($auth -eq "Windows") { $true } else { $false }

    $ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
    [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='Server']").value = "$hostname"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ServerInstance']").value="NAV"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ServicesCertificateValidationEnabled']").value="false"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesPort']").value="$publicWinClientPort"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ACSUri']").value = ""
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='DnsIdentity']").value = "$dnsIdentity"
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value = "$Auth"
    $clientUserSettings.Save("$exportClientFolderPath\RoleTailored Client\ClientUserSettings.config")

    New-FinSqlExeRunner -FileFullPath "$exportClientFolderPath\RoleTailored Client\_runfinsql.exe" -SqlServerName $sqlServerName -DbName "$databaseName" -NtAuth $ntAuth -Id "docker_$hostname"
}