Param( [PSCustomObject] $artifactJson )

# Json format:
#
# $artifactJson = @{
#    "storageAccountName" = "accountname"
#    "storageAccountKey" = "accountkey"
#    "imageName" = "image"
#    "version" = "16.1.12629.13468"
#    "country" = "base"
#    "insider" = $true/$false
#    "master" = $true/$false
#    "latest" = $true/$false
#    "rebuild" = $true/$false
#    "sandbox" = $true/$false
# }




# Temporary solution for generating artifacts from sandbox containers




if (!(Get-Installedmodule -Name navcontainerhelper -erroraction SilentlyContinue)) {
    if (Test-Path "C:\Users\freddyk\Documents\GitHub\Microsoft\navcontainerhelper\NavContainerHelper.ps1") {
        . "C:\Users\freddyk\Documents\GitHub\Microsoft\navcontainerhelper\NavContainerHelper.ps1"
    }
    else {
        Install-module NavContainerHelper -Force
    }
}

$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'P@ssword1' -AsPlainText -Force)

$ErrorActionPreference = "STOP"

if ($artifactJson.insider) {
    if ($artifactJson.master) {
        $repo = "bcinsider.azurecr.io/bcsandbox-master:"
        $redirFolderName = "bcsandbox-master"
        $redirPrefix = ""
    }
    else {
        $redirFolderName = "bcsandbox"
        $redirPrefix = ""
    }
    $containerPermission = "Off"
}
else {
    if ($artifactJson.sandbox) {
        $redirFolderName = "businesscentral"
        $redirPrefix = "sandbox/"
    }
    else {
        $redirFolderName = "businesscentral"
        $redirPrefix = "onprem/"
    }
    $containerPermission = "Container"
}

$blobContext = New-AzureStorageContext -StorageAccountName $artifactJson.storageAccountName -StorageAccountKey $artifactJson.storageAccountKey

# Pull if image doesn't exist
$existingImage = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq $artifactJson.imageName }
if (!($existingImage)) {
    docker pull $artifactJson.imageName
}

$inspect = docker inspect $artifactJson.imageName | ConvertFrom-Json
$platform = $inspect.Config.Labels.platform
$nav = $inspect.Config.Labels.nav
$cu = $inspect.Config.Labels.cu
$version = $inspect.Config.Labels.version
$country = $inspect.Config.Labels.country.ToLowerInvariant()

if ($artifactJson.sandbox) {
    $containerName = "sandbox"
    $baseName = "base"
}
else {
    $containerName = "onprem"
    $baseName = "w1"
}

$platformUrl = "$containerName/$version/platform"

if ($artifactJson.country -eq "base" -or ($artifactJson.country -eq "w1" -and $artifactJson.sandbox)) {

    # generate platform
    $blob = Get-AzureStorageBlob -Context $blobContext -Container $containerName -Blob "$version/platform" -ErrorAction SilentlyContinue
    if ($artifactJson.rebuild -or !($blob)) {

        # Create Platform and application-w1 artifact
        $baseContainerName = "base"
        New-NavContainer `
            -accept_outdated `
            -accept_eula `
            -containerName $baseContainerName `
            -imageName $artifactJson.imageName `
            -auth NavUserPassword `
            -updateHosts `
            -memoryLimit "8g" `
            -Credential $credential `
            -myScripts @(@{ "SetupNavUsers.ps1" = "" })
        
        $folder = "c:\ProgramData\NavContainerHelper\$([Guid]::NewGuid().ToString())"
        $archive = "$folder.zip"
        try {
    
            # Create application-w1 artifact
    
            $applicationUrl = "$containerName/$version/$baseName"
            New-Item -Path $folder -ItemType Directory | Out-Null
            $databaseFolder = Join-Path $folder 'database'
            
            New-Item -Path $databaseFolder -ItemType Directory | Out-Null
            Backup-NavContainerDatabases -containerName $baseContainerName -bakFolder $databaseFolder
    
            $manifest = @{
                "database" = "database\database.bak"
                "licenseFile" = ""
                "platformUrl" = "$platformUrl"
                "platform" = "$platform"
                "version" = "$version"
                "nav" = "$nav"
                "cu" = "$cu"
                "country" = $country
                "isBcSandbox" = $artifactJson.sandbox
            }

            $manifest | ConvertTo-Json -Depth 99 | Set-Content -Path (Join-Path $folder "manifest.json")
            Compress-Archive -Path "$folder\*" -DestinationPath $archive -CompressionLevel Optimal
        
            New-AzureStorageContainer -Name $containerName -Context $blobContext -Permission $containerPermission -ErrorAction Ignore | Out-Null
            Set-AzureStorageBlobContent -File $archive -Context $blobContext -Container $containerName -Blob "$version/$baseName" -Force | Out-Null

            # create redir artifacts
    
            $redirmanifest = @{
                "applicationUrl" = $applicationUrl
            }
    
            Remove-Item $folder -Recurse -Force
            Remove-Item $archive -Recurse -Force
            New-Item -Path $folder -ItemType Directory | Out-Null
    
            $redirmanifestFile = Join-Path $folder "manifest.json"
            $redirmanifest | ConvertTo-Json -Depth 99 | Set-Content $redirmanifestfile
            
            $redirmanifestZipFile = Join-Path $folder "manifest.zip"
            Compress-Archive -Path $redirmanifestFile -DestinationPath $redirmanifestZipFile -CompressionLevel NoCompression
    
            $imageNameTags = @("$version-$($artifactJson.country)")
            if ($artifactJson.country -eq "w1") {
                $imageNameTags += @("$version")
            }
            if ($cu) {
                $imageNameTags += @("$cu-$($artifactJson.country)")
                if ($artifactJson.country -eq "w1") {
                    $imageNameTags += @("$cu")
                }
            }
            if ($artifactJson.latest) {
                $imageNameTags += @("$($artifactJson.country)")
                if ($artifactJson.country -eq "w1") {
                    $imageNameTags += @("latest")
                }
            }
    
            New-AzureStorageContainer -Name $redirFolderName -Context $blobContext -Permission $containerPermission -ErrorAction Ignore | Out-Null
            $imageNameTags | % {
                Write-Host "Tag $_"
                Set-AzureStorageBlobContent -File $redirmanifestZipFile -Context $blobContext -Container $redirFolderName -Blob "$redirPrefix$_" -Force | Out-Null
            }
    
            Remove-Item $folder -Recurse -Force
            Stop-NavContainer $baseContainerName
            Extract-FilesFromStoppedBCContainer -containerName $baseContainerName -path $folder -extract all
            "databases", "Prerequisite Components" | % {
                $removeFolder = Join-Path $folder $_
                if (Test-Path $removeFolder) {
                    Remove-Item $removeFolder -Recurse -Force
                }
            }
            # remove files
            Get-Item -Path (Join-Path $folder "*") | Where { ! $_.PSIsContainer } | Remove-Item
            $prerequisitecomponents = @{
                "Prerequisite Components\IIS URL Rewrite Module\rewrite_2.0_rtw_x64.msi" = "https://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi"
                "Prerequisite Components\Open XML SDK 2.5 for Microsoft Office\OpenXMLSDKv25.msi" = "https://download.microsoft.com/download/5/5/3/553C731E-9333-40FB-ADE3-E02DC9643B31/OpenXMLSDKV25.msi"
                "Prerequisite Components\DotNetCore\DotNetCore.1.0.4_1.1.1-WindowsHosting.exe" = "https://go.microsoft.com/fwlink/?LinkID=844461"
            }    
            $prerequisitecomponents | ConvertTo-Json -Depth 99 | Set-Content (Join-Path $Folder "Prerequisite Components.json")
    
            Compress-Archive -Path "$folder\*" -DestinationPath $archive -CompressionLevel Optimal
        
            New-AzureStorageContainer -Name $containerName -Context $blobContext -Permission $containerPermission -ErrorAction Ignore | Out-Null
            Set-AzureStorageBlobContent -File $archive -Context $blobContext -Container $containerName -Blob "$version/platform" -Force | Out-Null
    
        }
        finally {
            if (Test-Path -path $archive) {
                Remove-Item $archive -Force
            }
            if (Test-Path -Path $folder) {
                Remove-Item $folder -Recurse -Force
            }
        }
    
        Remove-NavContainer $baseContainerName
    }
}
else {
    $countryContainerName = "$country$($version.replace('.',''))"

    Write-Host "Create container $countryContainerName from $($artifactJson.imageName)"
    New-NavContainer `
        -accept_outdated `
        -accept_eula `
        -containerName $countryContainerName `
        -imageName $artifactJson.imageName `
        -auth NavUserPassword `
        -updateHosts `
        -memoryLimit "8g" `
        -Credential $credential `
        -myScripts @(@{ "SetupNavUsers.ps1" = "" })

    $folder = "c:\ProgramData\NavContainerHelper\$([Guid]::NewGuid().ToString())"
    try {
        New-Item -Path $folder -ItemType Directory | Out-Null
        $databaseFolder = Join-Path $folder 'database'
        New-Item -Path $databaseFolder -ItemType Directory | Out-Null
        Backup-NavContainerDatabases -containerName $countryContainerName -bakFolder $databaseFolder

        if ($country -ne "w1") {
            Invoke-ScriptInBCContainer -containerName $countryContainerName -scriptblock { Param($folder, $country)
                "Applications.$country", "ConfigurationPackages", "Extensions" | % {
                    if (Test-Path "C:\$_") {
                        Copy-Item -path "C:\$_" -Destination $folder -Recurse -Force
                    }
                }
            } -argumentlist $folder,$country
        }
        $manifest = @{
            "database" = "database\database.bak"
            "licenseFile" = ""
            "platformUrl" = "$platformUrl"
            "platform" = "$platform"
            "version" = "$version"
            "nav" = "$nav"
            "cu" = "$cu"
            "country" = $country
            "isBcSandbox" = $artifactJson.sandbox
        }
        $manifest | ConvertTo-Json -Depth 99 | Set-Content -Path (Join-Path $folder "manifest.json")
        $appArchive = "$folder.zip"
        Compress-Archive -Path "$folder\*" -DestinationPath $appArchive -CompressionLevel Optimal
    
        New-AzureStorageContainer -Name $containerName -Context $blobContext -Permission $containerPermission -ErrorAction Ignore | Out-Null
        Set-AzureStorageBlobContent -File $appArchive -Context $blobContext -Container $containerName -Blob "$version\$country" -Force | Out-Null

        $applicationArtifactUrl = "$containerName/$Version/$country"

        $redirmanifest = @{
            "applicationUrl" = $applicationArtifactUrl
        }

        Remove-Item $folder -Recurse -Force
        New-Item -Path $folder -ItemType Directory | Out-Null

        $redirmanifestFile = Join-Path $folder "manifest.json"
        $redirmanifest | ConvertTo-Json -Depth 99 | Set-Content $redirmanifestfile
        
        $redirmanifestZipFile = Join-Path $folder "manifest.zip"
        Compress-Archive -Path $redirmanifestFile -DestinationPath $redirmanifestZipFile -CompressionLevel NoCompression

        $imageNameTags = @("$version-$country")
        if ($country -eq "w1") {
            $imageNameTags += @("$version")
        }
        if ($cu) {
            $imageNameTags += @("$cu-$country")
            if ($country -eq "w1") {
                $imageNameTags += @("$cu")
            }
        }
        if ($artifactJson.latest) {
            $imageNameTags += @("$country")
            if ($country -eq "w1") {
                $imageNameTags += @("latest")
            }
        }

        New-AzureStorageContainer -Name $redirFolderName -Context $blobContext -Permission $containerPermission -ErrorAction Ignore | Out-Null
        $imageNameTags | % {
            Write-Host "Tag $_"
            Set-AzureStorageBlobContent -File $redirmanifestZipFile -Context $blobContext -Container $redirFolderName -Blob "$redirPrefix$_" -Force | Out-Null
        }
    }
    finally {
        if (Test-Path -path $appArchive) {
            Remove-Item $appArchive -Force
        }
        if (Test-Path -Path $folder) {
            Remove-Item $folder -Recurse -Force
        }
    }

    Remove-NavContainer $countryContainerName
}

if (!($existingImage)) {
    docker rmi $artifactJson.imageName -f
}
