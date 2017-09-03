# Remove Default Web Site
Get-WebSite | Remove-WebSite
Get-WebBinding | Remove-WebBinding

$certparam = @{}
if ($servicesUseSSL) {
    $certparam += @{CertificateThumbprint = $certificateThumbprint}
}

if (Test-Path "C:\Program Files\dotnet\shared\Microsoft.NETCore.App" -PathType Container) {
    
    Write-Host "Create DotNetCore NAV Web Server Instance"
    $publishFolder = "$webClientFolder\WebPublish"

    Import-Module "$webClientFolder\Scripts\NAVWebClientManagement.psm1"
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
    $config | ConvertTo-Json | set-content $navSettingsFile

} else {
    # Create Web Client
    Write-Host "Create Web Site"
    New-NavWebSite -WebClientFolder $WebClientFolder `
                   -inetpubFolder (Join-Path $runPath "inetpub") `
                   -AppPoolName "NavWebClientAppPool" `
                   -SiteName "NavWebClient" `
                   -Port $webClientPort `
                   -Auth $Auth @certparam

    Write-Host "Create NAV Web Server Instance"
    New-NAVWebServerInstance -Server "localhost" `
                             -ClientServicesCredentialType $auth `
                             -ClientServicesPort 7046 `
                             -ServerInstance "NAV" `
                             -WebServerInstance "NAV"

    # Give Everyone access to resources
    $ResourcesFolder = "$WebClientFolder".Replace('C:\Program Files\', 'C:\ProgramData\Microsoft\')
    $user = New-Object System.Security.Principal.NTAccount("NT AUTHORITY\Everyone")
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, "ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
    $acl = Get-Acl -Path $ResourcesFolder
    Set-Acl -Path $ResourcesFolder $acl
    $acl = $null
    $acl = Get-Acl -Path $ResourcesFolder
    $acl.AddAccessRule($rule)
    Set-Acl -Path $ResourcesFolder $acl
    $acl = $null
}
