$RootPath = $PSScriptRoot
$ErrorActionPreference = "stop"
Set-StrictMode -Version 2.0

$isolation = "hyperv"
$filesOnly = $false
$only24 = $false
$image = "mygeneric"

# Get osVersion to use for the right base image
foreach($osVersion in @('ltsc2019')) { 
    $genericImage = "mcr.microsoft.com/businesscentral:$osVersion"
    docker pull $genericImage

    if ($osVersion -notlike 'ltsc20??') {
        throw "Unexpected osversion"
    }
    $freddyGenericImage = "freddyk/businesscentral:$osVersion-sql2025"
    docker pull $freddyGenericImage
    Write-Host "No existing freddy generic image found for $osVersion-sql2025"

    # Get the latest generic tag to use
    # Add one to always have a newer version than the MS one
    $labels = Get-BcContainerImageLabels -imageName $genericImage
    $tagVersion = [System.Version]$labels.tag

    # Get the same from the latest freddy image
    # to determine latest freddy image and ensure newer than both
    $freddyLabels = Get-BcContainerImageLabels -imageName $freddyGenericImage
    try {
        $freddyTagVersion = [System.Version]$freddyLabels.tag
        if ($freddyTagVersion -gt $tagVersion) {
            $tagVersion = $freddyTagVersion+1
        }
    }
    catch {
    }

    $genericTag = "$($tagVersion.Major).$($tagVersion.Minor).$($tagVersion.Build).$($tagVersion.Revision+1)"

    Write-Host "Using osversion $osVersion"
    Write-Host "Using generic tag $genericTag"

    # Manual overrides could be like this:
    # $osVersion = '10.0.19042.1889'   # 20H2
    # $osVersion = '10.0.19041.1415'   # 2004
    # $genericTag = '2.0.0.0'

    $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")

    if ($only24) {
        $baseimage = "mcr.microsoft.com/windows/servercore:$osVersion"
    }
    elseif ($osVersion -like 'ltsc*') {
        $baseImageTags = @{
            "ltsc2016" = "4.8-windowsservercore-ltsc2016"
            "ltsc2019" = "4.8-windowsservercore-ltsc2019"
            "ltsc2022" = "4.8.1-windowsservercore-ltsc2022"
            "ltsc2025" = "4.8.1-windowsservercore-ltsc2025"
        }
        $baseImage = "mcr.microsoft.com/dotnet/framework/runtime:$($baseImageTags."$osVersion")"
    }
    else {
        Write-Host "Using OS Version $osVersion"
        $webclient = New-Object System.Net.WebClient
        $basetags = (Get-NavContainerImageTags -imageName "mcr.microsoft.com/dotnet/framework/runtime").tags | Where-Object { $_.StartsWith('4.8-20') } | Sort-Object -Descending  | Where-Object { -not $_.endswith("-1803") }
        $basetags | ForEach-Object {
            if (!($baseImage)) {
                $manifest = (($webclient.DownloadString("https://mcr.microsoft.com/v2/dotnet/framework/runtime/manifests/$_") | ConvertFrom-Json).history[0].v1Compatibility | ConvertFrom-Json)
                Write-Host "$osVersion == $($manifest.'os.version')"
                if ($osVersion -eq $manifest.'os.version') {
                    $baseImage = "mcr.microsoft.com/dotnet/framework/runtime:$_"
                    Write-Host "$baseImage matches the host OS version"
                }
            }
        }
        if (!($baseImage)) {
            Write-Error "Unable to find a matching mcr.microsoft.com/dotnet/framework/runtime docker image"
        }
    }

    Write-Host "Using base image: $baseImage"
    docker pull $baseImage

    $setupUrlsFile = Join-Path $rootPath "Run/SetupUrls.ps1"
    Get-Content -Path $setupUrlsFile | Out-Host

    $dockerfile = Join-Path $RootPath "DOCKERFILE"
    if ($only24) {
        $image += "-24"
    }
    if ($filesOnly) {
        $dockerfile += '-filesonly'
        $image += '-filesonly'
    }
    docker pull $baseImage
    $osv = docker inspect --format "{{.OsVersion}}" $baseImage

    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }

    docker build --build-arg baseimage=$baseImage `
                 --build-arg created=$created `
                 --build-arg tag="$genericTag" `
                 --build-arg osversion="$osv" `
                 --build-arg filesonly="$filesonly" `
                 --build-arg only24="$only24" `
                 --isolation=$isolation `
                 --memory 32G `
                 --tag $image `
                 --file $dockerfile `
                 $RootPath

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed with exit code $LastExitCode"
    }
    else {
        Write-Host "SUCCESS"
    }
    docker tag mygeneric:latest $freddyGenericImage
    docker push $freddyGenericImage
}
