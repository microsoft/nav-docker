# az login --tenant 72f988bf-86f1-41af-91ab-2d7cd011db47
# az acr login -n mcrbusinesscentral.azurecr.io

$RootPath = $PSScriptRoot
$filesOnly = $false
$ENV:DOCKER_SCAN_SUGGEST = "false"
$hostOs = (Get-CimInstance Win32_OperatingSystem)

. (Join-Path $RootPath "settings.ps1")

function Head($text) {
    try {
        $s = (New-Object System.Net.WebClient).DownloadString("http://artii.herokuapp.com/make?text=$text")
    } catch {
        $s = $text
    }
    Write-Host -ForegroundColor Yellow $s
}

$push = $true
if ($hostOs.BuildNumber -eq 20348) {
    $supported = @(
        "10.0.20348.0"
    )
}
else {
    $supported = @(
        "10.0.19042.0"
        "10.0.19041.0"
        "10.0.17763.0"
        "10.0.14393.0"
    )
}

Write-Host -ForegroundColor Yellow "Latest BusinessCentral tags:"
$ver = [Version]"10.0.0.0"
if ($filesOnly) {
    $allbctags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/businesscentral").tags | 
        Where-Object { $_ -like "*-filesOnly" -and $_.Split('-').Count -eq 2 } |
        Where-Object { [Version]::TryParse($_.Split('-')[0], [ref] $ver) } | % {
            $_.Split('-')[0]
        }
}
else {
    $allbctags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/businesscentral").tags | 
        Where-Object { [Version]::TryParse($_, [ref] $ver) }
}

$bctags = $allbctags | Sort-Object -Descending { [Version]$_ } | 
    Group-Object { [Version]"$(([Version]$_).Major).$(([Version]$_).Minor).$(([Version]$_).Build).0" } | % { if ($supported.contains($_.Name)) { $_.Group[0] } }

$bctags | Out-Host

Write-Host -ForegroundColor Yellow "Latest Servercore tags:"
$ver = [Version]"10.0.0.0"
$servercoretags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/windows/servercore").tags | 
    Where-Object { [Version]::TryParse($_, [ref] $ver) } | 
    Sort-Object -Descending { [Version]$_ } | 
    Group-Object { [Version]"$(([Version]$_).Major).$(([Version]$_).Minor).$(([Version]$_).Build).0" } | % { if ($supported.contains($_.Name)) { $_.Group[0] } }

$servercoretags | Out-Host

if ($hostOs.BuildNumber -eq 20348) {
    $basetags = @(
        "4.8-windowsservercore-ltsc2022"
    )
}
else {
    $basetags = @(
        "4.8-windowsservercore-20H2"
        "4.8-windowsservercore-2004"
        "4.8-windowsservercore-ltsc2019"
        "4.8-windowsservercore-ltsc2016"
    )
}

Write-Host -ForegroundColor Yellow "Latest DotNetFramework OSVersions:"
$basetags | % {
    $image = "mcr.microsoft.com/dotnet/framework/runtime:$_"
    docker pull $image > $Null
    $inspect = docker inspect $image | ConvertFrom-Json
    Write-Host $inspect.OsVersion
}

#$basetags = (Get-BcContainerImageTags -imageName "mcr.microsoft.com/dotnet/framework/runtime").tags | Where-Object { $_ -like "4.8-2*" } | Where-Object { $_ -like "*-windowsservercore-20H2" -or $_ -like "*-windowsservercore-2004" -or $_ -like "*-windowsservercore-1909" -or $_ -like "*-windowsservercore-ltsc2019" -or $_ -like "*-windowsservercore-ltsc2016" } | Sort-Object -Descending

if ($filesOnly) {
    $dockerfile = Join-Path $RootPath "DOCKERFILE.filesonly"
}
else {
    $dockerfile = Join-Path $RootPath "DOCKERFILE"
}

Write-Host "Using dockerfile: $dockerfile"

if ((Read-Host -prompt "Continue (yes/no)?") -ne "Yes") {
    throw "Mission aborted"
}

$waitfor = ""

$start = 0
$start..($basetags.count-1) | % {
    $tag = $basetags[$_]

    $os = $tag.SubString($tag.LastIndexOf('-')+1)
    Head "$os"
    
    $baseimage = "mcr.microsoft.com/dotnet/framework/runtime:$tag"
    $image = "generic:$os"
    
    docker pull $baseimage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage

    if ($osversion -eq $waitfor -or $waitfor -eq "") {
        $waitfor = ""

        docker images --format "{{.Repository}}:{{.Tag}}" | % { 
            if ($_ -eq $image) 
            {
                docker rmi $image -f
            }
        }

        if ($true -or ($allbctags -notcontains $osversion)) {

            head $osversion

            if ($hostOs.BuildNumber -eq 20348) {
                $isolation = "process"
            }
            else {
                $isolation = "hyperv"
            }
            $success = $false
            try {
                docker build --build-arg baseimage=$baseimage `
                             --build-arg created=$created `
                             --build-arg tag="$genericTag" `
                             --build-arg osversion="$osversion" `
                             --isolation=$isolation `
                             --memory 10G `
                             --tag $image `
                             --file $dockerfile `
                             $RootPath | % {
                    $_ | Out-Host
                    if ($_ -like "Successfully built*") {
                        $success = $true
                    }
                }
            } catch {}
            if (!$success) {
                if ($LASTEXITCODE -ne 0) {
                    throw "Docker Build failed with exit code $LastExitCode"
                } else {
                    throw "Docker Build didn't indicate successfully built"
                }
            }
            Write-Host "SUCCESS"
        
            if ($push) {
                if ($filesOnly) {
                    $tags = @(
                        "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-filesonly"
                        "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-$genericTag-filesonly"
                        "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-filesonly-dev"
                    )
                }
                else {
                    $tags = @(
                        "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion"
                        "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-$genericTag"
                        "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-dev"
                    )
                }
                $tags | ForEach-Object {
                    Write-Host "Push $_"
                    docker tag $image $_
                    docker push $_
                }
                $tags | ForEach-Object {
                    Write-Host "Remove $_"
                    docker rmi $_
                }
                docker rmi $image
            }
        }
    }
}
