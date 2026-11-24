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

    .PARAMETER PublishOnly
    Publish an already built local image without pulling or building again.
    Use the same build parameters on the same agent, with fresh Azure authentication.

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
    [switch] $PushToProd,
    [Parameter(Mandatory = $false)]
    [switch] $PublishOnly
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
Write-Host "PublishOnly: $PublishOnly" -ForegroundColor Green

if ($PublishOnly -and -not ($PushToDev -or $PushToProd)) {
    throw "PublishOnly requires PushToDev or PushToProd"
}

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

# Fails if the tag is already published or if the registry tags cannot be listed (fail closed)
function Assert-TagNotPublished {
    param(
        [string]$Registry,
        [string]$Repository,
        [string]$Tag
    )
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $tagsJson = az acr repository show-tags --name $Registry.Split('.')[0] --repository $Repository --output json --only-show-errors
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $eap
    }
    if ($exitCode -ne 0) {
        throw "Could not list tags of $Repository in $Registry (exit code $exitCode)"
    }
    $tags = ($tagsJson -join '') | ConvertFrom-Json
    if ($tags -contains $Tag) {
        throw "Tag $($Repository):$Tag already exists in $Registry. Refusing to overwrite it."
    }
}

try {
    # Pipelines build separately and authenticate again before invoking PublishOnly.
    if ($PushToDev -or $PushToProd) {
        az acr login --name $PushRegistry
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to log in to $PushRegistry"
        }
    }

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
    if (-not $PublishOnly) {
        docker pull $baseimage
    }
    $osversion = Get-OsVersion -Baseimage $baseimage
    $versionedTag = "$osversion-$GenericTag$str24$strFilesOnly"

    # Fail fast, before the lengthy build, if the versioned tag is already published
    if ($PushToProd -and -not $PublishOnly) {
        Assert-TagNotPublished -Registry $PushRegistry -Repository "public/businesscentral" -Tag $versionedTag
    }

    $image = "my:$osversion-$GenericTag$str24$strFilesOnly"
    if (-not $PublishOnly) {
        $success = $false
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
            "$PushRegistry/public/businesscentral:$versionedTag"
            "$PushRegistry/public/businesscentral:$ltscTag$str24$strFilesonly"
        )
        # Check again right before pushing, as another run may have published the tag during the build
        Assert-TagNotPublished -Registry $PushRegistry -Repository "public/businesscentral" -Tag $versionedTag
    }
    
    $newtags | ForEach-Object {
        Write-Host "Pushing $image with tag $_"
        docker tag $image $_
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to tag $image as $_"
        }
        docker push $_
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push $_"
        }
    }
}

return $image