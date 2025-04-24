# Remove Default Web Site
Get-WebSite | Remove-WebSite
Get-WebBinding | Remove-WebBinding

$certparam = @{}
if ($servicesUseSSL) {
    Write-Host "CertificateThumprint $certificateThumbprint"
    $certparam += @{CertificateThumbprint = $certificateThumbprint}
}

Write-Host "Registering event sources"
"MicrosoftDynamicsNAVClientWebClient","MicrosoftDynamicsNAVClientClientService" | % {
    if (-not [System.Diagnostics.EventLog]::SourceExists($_)) {
        $frameworkDir =  (Get-Item "HKLM:\SOFTWARE\Microsoft\.NETFramework").GetValue("InstallRoot")
        New-EventLog -LogName Application -Source $_ -MessageResourceFile (get-item (Join-Path $frameworkDir "*\EventLogMessages.dll")).FullName
    }
}

Write-Host "Creating DotNetCore Web Server Instance"
$publishFolder = "$webClientFolder\WebPublish"

$runtimeConfigJsonFile = Join-Path $publishFolder "Prod.Client.WebCoreApp.runtimeconfig.json"
if (Test-Path $runtimeConfigJsonFile) {
    $runtimeConfigJson = Get-Content $runtimeConfigJsonFile | ConvertFrom-Json
    if (!($runtimeConfigJson.runtimeOptions.configProperties.PSObject.Properties.Name -eq "System.Globalization.UseNls")) {
        Add-Member -InputObject $runtimeConfigJson.runtimeOptions.configProperties -NotePropertyName "System.Globalization.UseNls" -NotePropertyValue "true"
        $runtimeConfigJson | ConvertTo-Json -Depth 99 | Set-Content $runtimeConfigJsonFile
    }
}

$NAVWebClientManagementModule = "$webClientFolder\Modules\NAVWebClientManagement\NAVWebClientManagement.psm1"
if (!(Test-Path $NAVWebClientManagementModule)) {
    $NAVWebClientManagementModule = "$webClientFolder\Scripts\NAVWebClientManagement.psm1"
}
# Replace Copy with Robocopy
$WebManagementModuleSource = Get-Content -Path $NAVWebClientManagementModule -Raw -Encoding UTF8
$WebManagementModuleSource = $WebManagementModuleSource.Replace('Copy-Item $SourcePath -Destination $siteRootFolder -Recurse -Container -Force','RoboCopy "$SourcePath" "$siteRootFolder" "*" /e /NFL /NDL /NJH /NJS /nc /ns /np /mt /z /nooffload | Out-Null
Get-ChildItem -Path $SourcePath -Filter "*" -Recurse | ForEach-Object {
    $destPath = Join-Path $siteRootFolder $_.FullName.Substring($SourcePath.Length)
    while (!(Test-Path $destPath)) {
        Write-Host "Waiting for $destPath to be available"
        Start-Sleep -Seconds 1
    }
}')
$WebManagementModuleSource = $WebManagementModuleSource.Replace('Write-Verbose','Write-Host')
$NAVWebClientManagementModule = "c:\run\my\NAVWebClientManagement.psm1"
Set-Content -Path $NAVWebClientManagementModule -Value $WebManagementModuleSource -Encoding UTF8

Import-Module $NAVWebClientManagementModule
New-NAVWebServerInstance -PublishFolder $publishFolder `
                         -WebServerInstance "$WebServerInstance" `
                         -Server "localhost" `
                         -ServerInstance "$ServerInstance" `
                         -ClientServicesCredentialType $Auth `
                         -ClientServicesPort "$clientServicesPort" `
                         -WebSitePort $webClientPort @certparam

$navsettingsFile = Join-Path $wwwRootPath "$WebServerInstance\navsettings.json"
$config = Get-Content $navSettingsFile | ConvertFrom-Json
Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "RequireSSL" -NotePropertyValue "true" -ErrorAction SilentlyContinue
$config.NAVWebSettings.RequireSSL = $false
Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "PersonalizationEnabled" -NotePropertyValue "true" -ErrorAction SilentlyContinue
$config.NAVWebSettings.PersonalizationEnabled = $true
$config.NAVWebSettings.ManagementServicesPort = $ManagementServicesPort

if ($customWebSettings -ne "") {
    Write-Host "Modifying Web Client config with settings from environment variable"        

    $customWebSettingsArray = $customWebSettings -split ","
    foreach ($customWebSetting in $customWebSettingsArray) {
        $customWebSettingArray = $customWebSetting -split "="
        $customWebSettingKey = $customWebSettingArray[0]
        $customWebSettingValue = $customWebSettingArray[1]
        if ($config.NAVWebSettings.$customWebSettingKey -eq $null) {
            Write-Host "Creating $customWebSettingKey and setting it to $customWebSettingValue"
            $config.NAVWebSettings | Add-Member $customWebSettingKey $customWebSettingValue
        } else {
            Write-Host "Setting $customWebSettingKey to $customWebSettingValue"
            $config.NAVWebSettings.$customWebSettingKey = $customWebSettingValue
        }
    }
}

$config | ConvertTo-Json | set-content $navSettingsFile
