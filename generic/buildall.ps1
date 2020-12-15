$RootPath = $PSScriptRoot

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

$supported = @(
    "10.0.19042.0"
    "10.0.19041.0"
    "10.0.18363.0"
    "10.0.17763.0"
    "10.0.14393.0"
)
$ver = [Version]"10.0.0.0"
$servercoretags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/windows/servercore").tags | 
    Where-Object { [Version]::TryParse($_, [ref] $ver) } | 
    Sort-Object -Descending { [Version]$_ } | 
    Group-Object { [Version]"$(([Version]$_).Major).$(([Version]$_).Minor).$(([Version]$_).Build).0" } | % { if ($supported.contains($_.Name)) { $_.Group[0] } }

Write-Host -ForegroundColor Yellow "Latest Servercore tags:"
$servercoretags

$ver = [Version]"10.0.0.0"
$allbctags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/businesscentral").tags | 
    Where-Object { [Version]::TryParse($_, [ref] $ver) }

$bctags = $allbctags | Sort-Object -Descending { [Version]$_ } | 
    Group-Object { [Version]"$(([Version]$_).Major).$(([Version]$_).Minor).$(([Version]$_).Build).0" } | % { if ($supported.contains($_.Name)) { $_.Group[0] } }

Write-Host -ForegroundColor Yellow "Latest BusinessCentral tags:"
$bctags

$basetags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/dotnet/framework/runtime").tags | 
    Where-Object { $_ -like '4.8-20*' -and $_ -notlike '*-2009'  -and $_ -notlike '*-1903'} | 
    Sort-Object -Descending

$basetags = @(
"4.8-windowsservercore-20H2"
"4.8-windowsservercore-2004"
"4.8-windowsservercore-1909"
"4.8-windowsservercore-ltsc2019"
"4.8-windowsservercore-ltsc2016"
)

#throw "start?"

$start = 0
$start..($basetags.count-1) | % {
    $tag = $basetags[$_]

    $os = $tag.SubString($tag.LastIndexOf('-')+1)

    Head "$os"
    
    $baseimage = "mcr.microsoft.com/dotnet/framework/runtime:$tag"
    $image = "generic:$os"
    
    docker pull $baseimage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage

    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }

    if ($allbctags -notcontains $osversion) {

        head $osversion

        $isolation = "hyperv"
        
        docker build --build-arg baseimage=$baseimage `
                     --build-arg created=$created `
                     --build-arg tag="$genericTag" `
                     --build-arg osversion="$osversion" `
                     --isolation=$isolation `
                     --memory 10G `
                     --tag $image `
                     $RootPath
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed with exit code $LastExitCode"
        }
        Write-Host "SUCCESS"
    
        if ($push) {
            $tags = @(
                "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion"
                "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-$genericTag"
                "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-dev"
            )
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
