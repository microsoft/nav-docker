# Remove Default Web Site
Get-WebSite | Remove-WebSite
Get-WebBinding | Remove-WebBinding

$certparam = @{}
if ($servicesUseSSL) {
    $certparam += @{CertificateThumbprint = $certificateThumbprint}
}

Write-Host "Creating DotNetCore NAV Web Server Instance"
$publishFolder = "$webClientFolder\WebPublish"

$NAVWebClientManagementModule = "$webClientFolder\Modules\NAVWebClientManagement\NAVWebClientManagement.psm1"
if (!(Test-Path $NAVWebClientManagementModule)) {
    $NAVWebClientManagementModule = "$webClientFolder\Scripts\NAVWebClientManagement.psm1"
}
Import-Module $NAVWebClientManagementModule
New-NAVWebServerInstance -PublishFolder $publishFolder `
                         -WebServerInstance "NAV" `
                         -Server "localhost" `
                         -ServerInstance "NAV" `
                         -ClientServicesCredentialType $Auth `
                         -ClientServicesPort "7046" `
                         -WebSitePort $webClientPort @certparam

$navsettingsFile = Join-Path $wwwRootPath "nav\navsettings.json"
$config = Get-Content $navSettingsFile | ConvertFrom-Json
Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "Designer" -NotePropertyValue "true" -ErrorAction SilentlyContinue
$config.NAVWebSettings.Designer = $true
Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "RequireSSL" -NotePropertyValue "true" -ErrorAction SilentlyContinue
$config.NAVWebSettings.RequireSSL = $false
Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "PersonalizationEnabled" -NotePropertyValue "true" -ErrorAction SilentlyContinue
$config.NAVWebSettings.PersonalizationEnabled = $true
$config | ConvertTo-Json | set-content $navSettingsFile
