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

Full builds require the extracted SqlServer 22.2.0 module in
`generic\dependencies\SqlServer\22.2.0` before Docker runs. The Azure pipeline
stages it automatically. For local builds, copy an approved module into that
ignored directory, including `SqlServer.psd1` and `SqlServer.psm1`. Do not include
credentials or NuGet configuration. Docker copies the module to the PowerShell 7
module path; Windows PowerShell 5.1 continues using SQLPS. Files-only builds do
not require this dependency. GitHub publishing is being deprecated and does not
stage the module.

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

Before full-image builds, `DownloadPackage@1` downloads the pinned SqlServer
22.2.0 package from the organization-scoped `DynamicsSMBPackages` Azure Artifacts
feed. It authenticates automatically with the job's OAuth token through
`SYSTEMVSSCONNECTION`; no PAT, service connection, `NuGetAuthenticate` task, or
explicit `System.AccessToken` environment mapping is needed. The job's build
identity must have **Feed Reader** access to that feed. This is the project's
Build Service identity for project-scoped job authorization, or the Project
Collection Build Service identity for collection-scoped authorization. No feed
permissions are changed by the pipeline. Both identities already inherit
Collaborator access through the feed's Package-Collaborators group, so no
additional authentication or feed permission setup is currently required.

With `extract: true`, package entries are extracted directly into
`generic\dependencies\SqlServer\22.2.0`, matching the Docker COPY layout.
The task stores the downloaded `.nupkg` in `Agent.TempDirectory`, outside the
Docker context; the current task implementation retains it there for agent
cleanup. Credentials are not written into the context, Docker arguments, or
image. ADO builds do not fall back to PSGallery; feed failures stop the build.
Files-only legs skip the download task.

Analysis provides a preview before approval. Inside the locked Publish stage, the
pipeline allocates the final revision from current ACR tags before building.
Dev-only runs recheck production tag digests in ACR immediately before stale
marking, excluding candidates that became production images while awaiting the
lock. Keep the GitHub publisher disabled while this pipeline is active; the ADO
lock does not coordinate with GitHub Actions.