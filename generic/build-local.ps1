Param(
    [string] $acr = "navgeneric",
    [string[]] $oss = @("ltsc2019","1803","1709")
)

. (Join-Path $PSScriptRoot "Settings.ps1")

$oss | ForEach-Object {
    
    if ($_ -eq "ltsc2019") {
        $baseimage = "mcr.microsoft.com/windows/servercore:$_"
    } else {
        $baseimage = "microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-$_"
    }

    if ($_ -eq "ltsc2016") {
        if ([System.Environment]::OSVersion.Version.Build -ne 14393) {
            throw "ltsc2016 cannot be build on host OS other than ltsc2016"
        }
    }

    $image = "generic:$_"

    docker pull $baseimage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage

    docker rmi $image -f 2>NULL | Out-Null
    docker build --build-arg baseimage=$baseimage `
                 --build-arg created=$created `
                 --build-arg tag=$tag `
                 --build-arg osversion="$osversion" `
                 --tag $image `
                 $PSScriptRoot
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed with exit code $LastExitCode"
    }
    Write-Host "SUCCESS"

    $tags = @("microsoft/dynamics-nav:generic-$_")
    if ($_ -eq "ltsc2016") {
        $tags += "microsoft/dynamics-nav:generic"
    }
    
    $tags | ForEach-Object {
        docker tag $image $_
        docker push $_
    }
}
