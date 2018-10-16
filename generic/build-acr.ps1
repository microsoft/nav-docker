. (Join-Path $PSScriptRoot "Settings.ps1")

$acr = "navgeneric"

#"1803","1709" | ForEach-Object {
"1709" | ForEach-Object {

    if ($_ -eq "ltsc2019") {
        $baseimage = "mcr.microsoft.com/windows/servercore:$_"
    } else {
        $baseimage = "microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-$_"
    }

    if ($_ -eq "ltsc2016") {
        throw "ltsc2016 cannot be build on ACR"
    }

    $image = "generic:$_"

#    az acr build --registry $acr `
#                 --image $image `
#                 --timeout 7200 `
#                 --os Windows `
#                 --build-arg baseimage=$baseimage `
#                 --build-arg created=$created `
#                 --build-arg tag=$tag `
#                 --file DOCKERFILE `
#                 https://github.com/Microsoft/nav-docker.git#master:generic
    
  #  if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS"

        $tags = @("microsoft/dynamics-nav:generic-$_")
    
        docker pull "$acr.azurecr.io/$image"
        $tags | ForEach-Object {
            docker tag "$acr.azurecr.io/$image" $_
            docker push $_
        }
   # }
}
