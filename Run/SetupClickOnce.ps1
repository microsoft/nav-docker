# INPUT
#     $navDvdPath
#     $hostname 
#     $httpPath
#     $dnsIdentity
#     $Auth
#     $clickOnceInstallerToolsFolder
#     $roleTailoredClientFolder
#
# OUTPUT
#

Import-Module "$navDvdPath\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"
Import-Module WebAdministration

$clickOnceDirectory = Join-Path $httpPath "NAV"
Remove-Item $clickOnceDirectory -Force -Recurse -ErrorAction SilentlyContinue
$webSiteUrl = "http://${hostname}:8080/NAV"

$ClientUserSettingsFileName = Join-Path (Get-ChildItem -Path "$NavDvdPath\RoleTailoredClient\CommonAppData\Microsoft\Microsoft Dynamics NAV" -Directory | Select-Object -Last 1).FullName "ClientUserSettings.config"
[xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='Server']").value = "$hostname"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ServerInstance']").value="NAV"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ServicesCertificateValidationEnabled']").value="false"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ACSUri']").value = ""
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='DnsIdentity']").value = "$dnsIdentity"
$clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value = "$Auth"

$applicationName = "Microsoft Dynamics NAV Windows Client for $hostname"
$applicationPublisher = "Microsoft Corporation"

# Create empty directory
New-Item $ClickOnceDirectory -type directory | Out-Null

# Copy file structure from the installation folder
$templateFilesFolder  = Join-Path $clickOnceInstallerToolsFolder 'TemplateFiles'
Copy-Item $templateFilesFolder\* -Destination $ClickOnceDirectory -Recurse

# Save config file and copy the relevant WinClient files to the Deployment\ApplicationFiles folder
$clickOnceApplicationFilesDirectory = Join-Path $ClickOnceDirectory 'Deployment\ApplicationFiles'
$clientUserSettingsFile = Join-Path $clickOnceApplicationFilesDirectory 'ClientUserSettings.config'
$ClientUserSettings.Save($clientUserSettingsFile)
. (Get-MyFilePath "SetupClickOnceDirectory.ps1")

$MageExeLocation = Join-Path $runPath 'Install\mage.exe'

$clickOnceApplicationFilesDirectory = Join-Path $clickOnceDirectory 'Deployment\ApplicationFiles'

$applicationManifestFile = Join-Path $clickOnceApplicationFilesDirectory 'Microsoft.Dynamics.Nav.Client.exe.manifest'
$applicationIdentityName = "$hostname ClickOnce"
$applicationIdentityVersion = (Get-Item -Path (Join-Path $clickOnceApplicationFilesDirectory 'Microsoft.Dynamics.Nav.Client.exe')).VersionInfo.FileVersion

Set-ApplicationManifestFileList `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationFilesDirectory $ClickOnceApplicationFilesDirectory `
    -MageExeLocation $MageExeLocation
Set-ApplicationManifestApplicationIdentity `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationIdentityName $ApplicationIdentityName `
    -ApplicationIdentityVersion $ApplicationIdentityVersion

$deploymentManifestFile = Join-Path $clickOnceDirectory 'Deployment\Microsoft.Dynamics.Nav.Client.application'
$deploymentIdentityName = "$hostname ClickOnce"
$deploymentIdentityVersion = $applicationIdentityVersion
$deploymentManifestUrl = ($webSiteUrl + "/Deployment/Microsoft.Dynamics.Nav.Client.application")
$applicationManifestUrl = ($webSiteUrl + "/Deployment/ApplicationFiles/Microsoft.Dynamics.Nav.Client.exe.manifest")

Set-DeploymentManifestApplicationReference `
    -DeploymentManifestFile $DeploymentManifestFile `
    -ApplicationManifestFile $ApplicationManifestFile `
    -ApplicationManifestUrl $ApplicationManifestUrl `
    -MageExeLocation $MageExeLocation
Set-DeploymentManifestSettings `
    -DeploymentManifestFile $DeploymentManifestFile `
    -DeploymentIdentityName $DeploymentIdentityName `
    -DeploymentIdentityVersion $DeploymentIdentityVersion `
    -ApplicationPublisher $ApplicationPublisher `
    -ApplicationName $ApplicationName `
    -DeploymentManifestUrl $DeploymentManifestUrl

# Put a web.config file in the root folder, which will tell IIS which .html file to open
$sourceFile = Join-Path $runPath 'root_web.config'
$targetFile = Join-Path $clickOnceDirectory 'web.config'
Copy-Item $sourceFile -destination $targetFile

# Put a web.config file in the Deployment folder, which will tell IIS to allow downloading of .config files etc.
$sourceFile = Join-Path $runPath 'deployment_web.config'
$targetFile = Join-Path $clickOnceDirectory 'Deployment\web.config'
Copy-Item $sourceFile -destination $targetFile
