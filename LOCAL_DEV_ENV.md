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
    $imageName = ./build/build.ps1 -BaseImage $baseImage -LtscTag 'ltsc2025' -FilesOnly $false -Only24 $false -GenericTag $GenericTag
```

For long-running builds, authenticate to Azure after the build completes, then invoke
`build.ps1` again with the same parameters plus `-PublishOnly -PushToDev` (and
`-PushToProd` when needed). Run both invocations on the same agent. `-PublishOnly`
reuses the local base image without pulling or rebuilding, so the production tag
guard checks the version that was actually built. Both publishing pipelines use
this split to avoid relying on an Azure session created before the build.

Full builds stage SqlServer 22.2.0 on the host before Docker runs. Local and GitHub
builds use `Save-Module` from the host's PSGallery registration by default (requires
PowerShellGet/NuGet and permitted gallery access). To use an approved offline or
internal source instead, pass `-SqlServerModulePath 'C:\modules\SqlServer\22.2.0'`
to `build\build.ps1`. The directory must contain the extracted module, including
`SqlServer.psd1` and `SqlServer.psm1`. Staged files go in the ignored
`generic\dependencies\SqlServer\22.2.0` directory. Direct `docker build` callers
must stage it first with `build\Stage-SqlServerModule.ps1 -ModulePath <directory>`.
Only module contents belong in that source directory, never credentials or NuGet
configuration. The full Dockerfile copies it to the PowerShell 7 module path;
Windows PowerShell 5.1 continues using SQLPS. Files-only and `-PublishOnly` builds
do not retrieve or stage this dependency.

If you'd rather use a different base image, you can also use one of the following:
* mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2016
* mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019
* mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2022
* mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2025

## Create a docker container with the image

Once you have a local image you can use New-BCContainer to spin up a Business Central container that uses your image. 
```powershell
    New-BcContainer -accept_eula -accept_insiderEula -containerName "MyTestContainer" -artifactUrl (Get-BCArtifactUrl -select NextMajor -accept_insiderEula -country W1) -useGenericImage $imageName
```

## Azure pipeline

The manual Azure pipeline is defined in `.azure-pipelines/BuildMissingImages.yml`.
It extends the Official 1ES Pipeline Template and uses the pool named by
`AgentPoolName`, letting the pool select its configured image, with the
`NAVDocker-ImagePublisher` Azure Resource Manager service connection.
Authorize access to the template repository,
agent pool, and service connection, and configure approval and Exclusive Lock
checks on that connection.
Runs publish only from `main`. The default `PushToProd: false` still publishes dev
images and marks eligible old images stale; it is not a dry run.

Before full-image builds, the pipeline downloads the pinned SqlServer 22.2.0
package from the organization-scoped `DynamicsSMBPackages` Azure Artifacts feed
using `System.AccessToken`. Grant the pipeline build identity **Feed Reader**
access to that feed if needed. No PAT, extra service connection, or feed permission
changes are performed by the script. Authentication exists only in the staging
task's environment and in-memory request header, never in Docker build arguments,
environment, layers, or context. The temporary package archive is extracted outside
the context and removed after staging. ADO builds do not fall back to PSGallery;
feed failures stop the build. Files-only legs skip the staging task.

Analysis provides a preview before approval. Inside the locked Publish stage, the
pipeline allocates the final revision from current ACR tags before building.
Dev-only runs recheck production tag digests in ACR immediately before stale
marking, excluding candidates that became production images while awaiting the
lock. Keep the GitHub publisher disabled while this pipeline is active; the ADO
lock does not coordinate with GitHub Actions.