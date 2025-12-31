<#
    .SYNOPSIS
    Build a Docker image for Business Central.

    .DESCRIPTION
    This script builds a Docker image for Business Central using the specified parameters.
    It also pushes the image to a specified Azure Container Registry if requested.

    .PARAMETER BaseImage
    The base image to use for building the Docker image (mcr.microsoft.com/dotnet/framework/runtime or mcr.microsoft.com/windows/servercore)
    Example: mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025

    .PARAMETER LtscTag
    The LTSC tag to use for the image. 
    For example: ltsc2016, ltsc2019, ltsc2022 or ltsc2025

    .PARAMETER FilesOnly
    A switch indicating whether to build only the files.

    .PARAMETER Only24
    A switch indicating whether to build the BC24 image.

    .PARAMETER GenericTag
    The generic tag to use for the image.
    Example: 1.2.3.4

    .PARAMETER PushRegistry
    The Azure Container Registry to push the image to (default: mcrbusinesscentral.azurecr.io).

    .PARAMETER PushToDev
    A switch indicating whether to push the image to the development registry.

    .PARAMETER PushToProd
    A switch indicating whether to push the image to the production registry.

    .EXAMPLE
    ./build.ps1 -BaseImage 'mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025' -LtscTag ltsc2025 -FilesOnly $false -Only24 $false -GenericTag "1.2.3.5"
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $BaseImage,
    [Parameter(Mandatory = $true)]
    [string] $LtscTag,
    [Parameter(Mandatory = $true)]
    [bool] $FilesOnly,
    [Parameter(Mandatory = $true)]
    [bool] $Only24,
    [Parameter(Mandatory = $true)]
    [string] $GenericTag,
    [Parameter(Mandatory = $false)]
    [string] $PushRegistry = "mcrbusinesscentral.azurecr.io",
    [Parameter(Mandatory = $false)]
    [switch] $PushToDev,
    [Parameter(Mandatory = $false)]
    [switch] $PushToProd
)

$erroractionpreference = "STOP"
Set-StrictMode -version 2.0

# Print all the parameters
Write-Host "Building Image with the following parameters:" -ForegroundColor Green
Write-Host "BaseImage: $BaseImage" -ForegroundColor Green
Write-Host "LtscTag: $LtscTag" -ForegroundColor Green
Write-Host "FilesOnly: $FilesOnly" -ForegroundColor Green
Write-Host "Only24: $Only24" -ForegroundColor Green
Write-Host "GenericTag: $GenericTag" -ForegroundColor Green
Write-Host "PushRegistry: $PushRegistry" -ForegroundColor Green
Write-Host "PushToDev: $PushToDev" -ForegroundColor Green
Write-Host "PushToProd: $PushToProd" -ForegroundColor Green

function Get-OsVersion {
    param(
        [string]$Baseimage
    )
    $imageInspect = docker inspect $Baseimage
    $imageInspect | Out-Host
    $osversion = ($imageInspect | ConvertFrom-Json).OSVersion

    # Test if the OS version is empty
    if ([string]::IsNullOrEmpty($osversion)) {
        throw "OS version is empty. Please inspect the base image: $Baseimage"
    }


    return $osversion
}

try {
    Push-Location "generic"
    $rootPath = Get-Location

    $setupUrlsFile = Join-Path $rootPath "Run/SetupUrls.ps1"
    Get-Content -Path $setupUrlsFile | Out-Host
    $dockerfile = Join-Path $rootPath "DOCKERFILE"
    
    
    $strFilesOnly = ''
    $str24 = ''
    if ($only24) {
        $str24 = "-24"
    }
    if ($filesOnly) {
        $strFilesOnly = "-filesonly"
        $dockerfile += '-filesonly'
    }
    $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")
    docker pull $baseimage
    $osversion = Get-OsVersion -Baseimage $baseimage

    $success = $false
    $image = "my:$osversion-$GenericTag$str24$strFilesOnly"
    docker build --build-arg baseimage=$baseimage `
        --build-arg created=$created `
        --build-arg tag="$GenericTag" `
        --build-arg osversion="$osversion" `
        --build-arg filesonly="$filesonly" `
        --build-arg only24="$only24" `
        --isolation=hyperv `
        --memory 8G `
        --tag $image `
        --file $dockerfile `
        $RootPath | ForEach-Object {
            $_ | Out-Host
            if ($_ -like "Successfully built*") {
                $success = $true
            }
    }
    if (!$success) {
        throw "Error building image"
    }
} finally {
    Pop-Location
}

if ($PushToDev -or $PushToProd) {
    $newtags = @(
        "$PushRegistry/public/businesscentral:$osversion$str24$strFilesonly-dev"
        "$PushRegistry/public/businesscentral:$ltscTag$str24$strFilesonly-dev"
    )
    if ($PushToProd) {
        $newtags += @(
            "$PushRegistry/public/businesscentral:$osversion$str24$strFilesonly"
            "$PushRegistry/public/businesscentral:$osversion-$GenericTag$str24$strFilesonly"
            "$PushRegistry/public/businesscentral:$ltscTag$str24$strFilesonly"
        )
    }
    
    az acr login --name $PushRegistry
    $newtags | ForEach-Object {
        Write-Host "Pushing $image with tag $_"
        docker tag $image $_
        docker push $_
    }
}

return $image