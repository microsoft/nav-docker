# How to build and test images locally

## Prerequisites
- Install and run [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/). Make sure it is running Windows containers.
- Install [BcContainerHelper PS module](https://www.powershellgallery.com/packages/BcContainerHelper) (latest available version).
`Install-Module BCContainerHelper -AllowPrerelease` would do.

## Build a new image locally 

If you want to build a new docker image locally you can use the build.ps1 script. The following will produce a new docker image based on Windows Server Core 2025. 
```powershell
    $GenericTag = "1.2.3.4"
    $baseImage = "mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025"
    ./build/build.ps1 -BaseImage $baseImage -LtscTag 'ltsc2025' -FilesOnly $false -Only24 $false -GenericTag $GenericTag
```

If you'd rather use a different base image, you can also use one of the following:
* mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2016
* mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019
* mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2022
* mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025

## Create a docker container with the image

Once you have a local image you can use New-BCContainer to spin up a Business Central container that uses your image. 
```powershell
    New-BcContainer -accept_eula -accept_insiderEula -containerName "MyTestContainer" -artifactUrl (Get-BCArtifactUrl -select NextMajor -accept_insiderEula -country W1) -useGenericImage "my:$GenericTag"
```