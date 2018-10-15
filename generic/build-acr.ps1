. (Join-Path $PSScriptRoot "Settings.ps1")
$acr = "navgeneric"

#az acr run --registry $acr --file build-and-push.yaml --set created=$created --set tag=$tag --os Windows $PSScriptRoot

"1803","1709","ltsc2016" | ForEach-Object {
    
    if ($_ -eq "ltsc2019") {
        $baseimage = "mcr.microsoft.com/windows/servercore:$_"
    } else {
        $baseimage = "microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-$_"
    }

    $image = "generic:$_"

    az acr build --registry $acr `
                 --image $image `
                 --timeout 7200 `
                 --os Windows `
                 --build-arg baseimage=$baseimage `
                 --build-arg created=$created `
                 --build-arg tag=$tag `
                 --file DOCKERFILE `
                 https://github.com/Microsoft/nav-docker.git#master:generic
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS"

        $tags = @("microsoft/dynamics-nav:generic-$_")
    
        docker pull "$acr.azurecr.io/$image"
        $tags | ForEach-Object {
            docker tag "$acr.azurecr.io/$image" $_
            docker push $_
        }
    }
}
