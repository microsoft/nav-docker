. (Join-Path $PSScriptRoot "Settings.ps1")

"1803","1709","ltsc2016" | ForEach-Object {
    
    if ($_ -eq "ltsc2019") {
        $baseimage = "mcr.microsoft.com/windows/servercore:$_"
    } else {
        $baseimage = "microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-$_"
    }

    docker pull $baseimage
    $image = "generic:$_"

    docker rmi $image -f 2>NULL | Out-Null
    docker build --build-arg baseimage=$baseimage `
                 --build-arg created=$created `
                 --build-arg tag=$tag `
                 --isolation hyperv `
                 --tag $image `
                 $PSScriptRoot
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS"

        $tags = @("microsoft/dynamics-nav:generic-$_")

        $tags | ForEach-Object {
            docker tag $image $_
            docker push $_
        }
    }
}
