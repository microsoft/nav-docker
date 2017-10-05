function New-NavWebSite
(
    [string]$WebClientFolder,
    [string]$inetpubFolder,
    [string]$AppPoolName,
    [string]$SiteName,
    [string]$Port,
    [string]$Auth,
    [string]$CertificateThumbprint
)
{
    Write-Verbose "Copy files to site container"
    $wwwRoot = Get-WWWRootPath
    $appContainerName = "NavWebApplicationContainer"

    Get-ChildItem -Path $inetpubFolder -Include $appContainerName -Directory -Recurse | Copy-Item -Destination $wwwRoot -Container -Recurse

    $appContainerFullPath = Join-Path $wwwRoot $appContainerName
    Test-Path $appContainerFullPath -ErrorAction Stop | Out-Null

    Write-Verbose "Register event sources"
    Set-NavWebClientEventSource

    Write-Verbose "Write web client registry keys"
    Set-WebClientRegistryKeys -WebClientFolder $WebClientFolder -AppPoolName $AppPoolName -SiteName $SiteName

    Write-Verbose "Creating the application pool $AppPoolName"
    $appPool = New-WebAppPool -Name $AppPoolName -Force
    $appPool.managedRuntimeVersion = 'v4.0'
    $appPool.managedPipelineMode = "Integrated"
    $appPool.startMode = "AlwaysRunning"
    $appPool.enable32BitAppOnWin64 = "false"
    $appPool.recycling.logEventOnRecycle = "Time,Requests,Schedule,Memory,IsapiUnhealthy,OnDemand,ConfigChange,PrivateMemory"
    $appPool.processModel.identityType = "ApplicationPoolIdentity" 
    $appPool.processModel.loadUserProfile = "false"
    $appPool.processModel.idleTimeout = "1.00:00:00"
    $appPool.recycling.logEventOnRecycle = "Time,Requests,Schedule,Memory,IsapiUnhealthy,OnDemand,ConfigChange,PrivateMemory"
    $appPool | Set-Item

    # Give AppPool access to Web Client Folder
    $user = New-Object System.Security.Principal.NTAccount("IIS APPPOOL\$AppPoolName")
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,"ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
    $acl = Get-Acl -Path $WebClientFolder
    Set-Acl -Path $WebClientFolder $acl
    $acl = $null
    $acl = Get-Acl -Path $WebClientFolder
    $acl.AddAccessRule($rule)
    Set-Acl -Path $WebClientFolder $acl
    $acl = $null

    # Give AppPool access to AppContainer
    $user = New-Object System.Security.Principal.NTAccount("IIS APPPOOL\$AppPoolName")
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user,"ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
    $acl = Get-Acl -Path $appContainerFullPath
    Set-Acl -Path $appContainerFullPath $acl
    $acl = $null
    $acl = Get-Acl -Path $appContainerFullPath
    $acl.AddAccessRule($rule)
    Set-Acl -Path $appContainerFullPath $acl
    $acl = $null

    if ($CertificateThumbprint) {
        Write-Verbose "Creating web site: $SiteName"
        New-Website -Name $SiteName -PhysicalPath $appContainerFullPath -ApplicationPool $AppPoolName -Port $Port -Ssl | Out-Null

        $sslBindingPath = "IIS:\SslBindings\0.0.0.0!$Port"
        $certificate = Get-Item Cert:\LocalMachine\My\$CertificateThumbprint -ErrorAction SilentlyContinue
        New-Item $sslBindingPath -Value $certificate | Out-Null
    } else {
        Write-Verbose "Creating web site: $SiteName"
        New-Website -Name $SiteName -PhysicalPath $appContainerFullPath -ApplicationPool $AppPoolName -Port $Port | Out-Null
    }

    Write-Verbose "Disable digest authentication"
    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/digestAuthentication' -Name enabled -Value false -Location $SiteName -Force

    if ($auth -eq "Windows") {
        Write-Verbose "Disable basic authentication"
        Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/basicAuthentication' -Name enabled -Value false -Location $SiteName -Force

        Write-Verbose "Enable Windows authentication"
        Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/windowsAuthentication' -Name enabled -Value true -Location $SiteName -Force
    } else {
        Write-Verbose "Enable basic authentication"
        Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/basicAuthentication' -Name enabled -Value true -Location $SiteName -Force

        Write-Verbose "Disable Windows authentication"
        Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/windowsAuthentication' -Name "enabled" -Value false -Location $SiteName -Force
    }

    Write-Verbose "Enable anonymous authentication"
    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/anonymousAuthentication' -Name enabled -Value true -Location $SiteName -Force

    Write-Verbose "Set static compression level"
    Set-WebConfigurationProperty "/system.webServer/httpCompression/scheme[@name='gzip']" -name staticCompressionLevel -value 9 -Location $SiteName -Force

    Write-Verbose "Set dynamic compression level"
    Set-WebConfigurationProperty "/system.webServer/httpCompression/scheme[@name='gzip']" -name dynamicCompressionLevel -value 4 -Location $SiteName -Force

    Write-Verbose "Set compression of JSON"
    Clear-WebConfiguration -filter "/system.webServer/httpCompression/dynamicTypes/add[@mimeType='application/json']" -WarningAction SilentlyContinue -Location $SiteName  -Force
    Add-WebConfiguration "/system.webServer/httpCompression/dynamicTypes" -value (@{mimeType="application/json";charset="utf-8";enabled="true"}) -Location $SiteName  -Force
}

function Set-NavWebClientEventSource
{
    $frameworkDir =  (Get-Item "HKLM:\SOFTWARE\Microsoft\.NETFramework").GetValue("InstallRoot")
    $FrameworkVersion = "v4.0.30319"
    $keys = "HKLM:\SYSTEM\CurrentControlSet\services\eventlog\Application\MicrosoftDynamicsNAVClientWebClient","HKLM:\SYSTEM\CurrentControlSet\services\eventlog\Application\MicrosoftDynamicsNAVClientClientService"

    $keys | % { New-Item -Path $_ -Force;  Set-ItemProperty -Path $_ -Name EventMessageFile -Value (Join-Path $frameworkDir \$FrameworkVersion\EventLogMessages.dll) } | Out-Null
}

function Set-WebClientRegistryKeys
(
    [string]$WebClientFolder,
    [string]$AppPoolName,
    [string]$SiteName
)
{
    $webClient = Get-ChildItem -Path $WebClientFolder -Include 'Microsoft.Dynamics.Nav.Client.WebClient.dll' -Recurse
    $versionFolder = ("{0}{1}" -f $webClient.VersionInfo.FileMajorPart,$webClient.VersionInfo.FileMinorPart)
    $keyPath = "HKLM:\Software\Microsoft\Microsoft Dynamics NAV\$versionFolder\Web Client"

    New-Item -Path $keyPath -Force | Out-Null

    # Set Registry Entries
    Set-ItemProperty -Path $keyPath -Name Installed -Value 1 -Force | Out-Null
    Set-ItemProperty -Path $keyPath -Name ApplicationPool -Value $AppPoolName -Force | Out-Null
    Set-ItemProperty -Path $keyPath -Name Path -Value "$WebClientFolder\" -Force | Out-Null
    Set-ItemProperty -Path $keyPath -Name Name -Value $SiteName -Force | Out-Null
}

# Remove Default Web Site
Get-WebSite | Remove-WebSite
Get-WebBinding | Remove-WebBinding

$certparam = @{}
if ($servicesUseSSL) {
    $certparam += @{CertificateThumbprint = $certificateThumbprint}
}

if (Test-Path "C:\Program Files\dotnet\shared\Microsoft.NETCore.App" -PathType Container) {
    
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
    $config | ConvertTo-Json | set-content $navSettingsFile

} else {
    # Creating Web Client
    Write-Host "Creating Web Site"
    New-NavWebSite -WebClientFolder $WebClientFolder `
                   -inetpubFolder (Join-Path $runPath "inetpub") `
                   -AppPoolName "NavWebClientAppPool" `
                   -SiteName "NavWebClient" `
                   -Port $webClientPort `
                   -Auth $Auth @certparam

    Write-Host "Creating NAV Web Server Instance"
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
