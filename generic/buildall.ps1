$RootPath = $PSScriptRoot

. (Join-Path $RootPath "settings.ps1")

$push = $true

$basetags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/dotnet/framework/runtime").tags | Where-Object { $_.StartsWith('4.8-20') } | Sort-Object -Descending  | Where-Object { -not $_.endswith("-1803") }

$basetags

throw "go?"

0..4 | % {
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
        $tags = @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic","mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic-$genericTag","mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic-dev","mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic-dev-$genericTag")
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
