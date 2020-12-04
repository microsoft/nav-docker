$RootPath = $PSScriptRoot

. (Join-Path $RootPath "settings.ps1")

$push = $true

$supported = @(
    "10.0.19042.0"
    "10.0.19041.0"
    "10.0.18363.0"
    "10.0.18362.0"
    "10.0.17763.0"
    "10.0.14393.0"
)
$ver = [Version]"10.0.0.0"
$servercoretags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/windows/servercore").tags | 
    Where-Object { [Version]::TryParse($_, [ref] $ver) } | 
    Sort-Object -Descending { [Version]$_ } | 
    Group-Object { [Version]"$(([Version]$_).Major).$(([Version]$_).Minor).$(([Version]$_).Build).0" } | % { if ($supported.contains($_.Name)) { $_.Group[0] } }

$servercoretags

$basetags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/dotnet/framework/runtime").tags | 
    Where-Object { $_.StartsWith('4.8-20') } | 
    Sort-Object -Descending

$basetags

#throw "go?"

$start = 0
$start..($basetags.count-1) | % {
    $tag = $basetags[$_]
    $dt = $tag.SubString(4,8)
    $os = $tag.SubString($tag.LastIndexOf('-')+1)

    Write-Host "$dt $os"
    
    $baseimage = "mcr.microsoft.com/dotnet/framework/runtime:$tag"
    $image = "$dt-generic:$os"
    
    docker pull $baseimage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage
    
    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }

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
        docker rmi $baseimage
    }
}
