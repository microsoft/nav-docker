param(
    [string] $ModulePath,
    [switch] $InternalFeed,
    [string] $Destination = (Join-Path $PSScriptRoot '..\generic\dependencies\SqlServer\22.2.0')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

if ($InternalFeed -and $ModulePath) {
    throw 'Specify InternalFeed or ModulePath, not both.'
}

$temporaryPath = $null
try {
    if (-not $ModulePath) {
        if ($InternalFeed) {
            if ([string]::IsNullOrWhiteSpace($env:SYSTEM_ACCESSTOKEN)) {
                throw 'System.AccessToken is required to read DynamicsSMBPackages.'
            }
        }
        elseif ($env:TF_BUILD -eq 'True') {
            throw 'Azure Pipelines must stage SqlServer from DynamicsSMBPackages using InternalFeed.'
        }

        # Keep the archive and all download state outside the Docker build context.
        $temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ("nav-docker-sqlserver-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $temporaryPath | Out-Null
        if ($InternalFeed) {
            $archivePath = Join-Path $temporaryPath 'SqlServer.zip'
            $ModulePath = Join-Path $temporaryPath 'module'
            $uri = 'https://pkgs.dev.azure.com/dynamicssmb2/_packaging/71e7dd80-1e53-4c33-b5f6-2603011e73b4/nuget/v3/flat2/sqlserver/22.2.0/sqlserver.22.2.0.nupkg'
            $headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(":$env:SYSTEM_ACCESSTOKEN")) }
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            try {
                Invoke-WebRequest -Uri $uri -Headers $headers -OutFile $archivePath -UseBasicParsing | Out-Null
            }
            catch {
                # Do not echo request headers or the original authenticated request error.
                throw 'Could not download SqlServer 22.2.0 from DynamicsSMBPackages. Check feed availability and Feed Reader access for the pipeline build identity.'
            }
            finally {
                $headers.Clear()
            }
            Expand-Archive -LiteralPath $archivePath -DestinationPath $ModulePath
        }
        else {
            Save-Module -Name SqlServer -RequiredVersion 22.2.0 -Repository PSGallery -Path $temporaryPath -Force
            $ModulePath = Join-Path $temporaryPath 'SqlServer\22.2.0'
        }
    }

    $manifestPath = Join-Path $ModulePath 'SqlServer.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $ModulePath 'SqlServer.psm1') -PathType Leaf)) {
        throw 'SqlServer module source must contain SqlServer.psd1 and SqlServer.psm1.'
    }
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    if ($manifest.ModuleVersion -ne '22.2.0') {
        throw 'SqlServer module source must be version 22.2.0.'
    }

    $sourcePath = (Resolve-Path -LiteralPath $ModulePath).Path
    $destinationPath = [System.IO.Path]::GetFullPath($Destination)
    if ($sourcePath.TrimEnd('\') -ne $destinationPath.TrimEnd('\')) {
        if (Test-Path -LiteralPath $destinationPath) {
            Remove-Item -LiteralPath $destinationPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        Get-ChildItem -LiteralPath $sourcePath -Force | Copy-Item -Destination $destinationPath -Recurse -Force
    }
    Write-Host 'Staged SqlServer 22.2.0 for the full-image build.'
}
finally {
    if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath)) {
        Remove-Item -LiteralPath $temporaryPath -Recurse -Force
    }
}
