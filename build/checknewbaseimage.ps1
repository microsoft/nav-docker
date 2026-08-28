<#
    .SYNOPSIS
    Detect whether the Business Central dev images are built on the latest base images.

    .DESCRIPTION
    For each LTSC tag, this script compares the layers of the current base image
    (mcr.microsoft.com/dotnet/framework/runtime:<tag>) with the layers of the currently
    published '<tag>-dev' Business Central image.

    Because a derived image embeds the base image layers byte-for-byte, the base layers
    must all be present in the dev image if it was built on the current base. If any base
    layer is missing, the base image has changed (a new OS, .NET Framework or PowerShell
    servicing update) and the image should be rebuilt.

    The check is stateless: it only inspects manifests (no image pull, no changes to the
    images or the repository).

    .PARAMETER LtscTags
    The LTSC tags to check. Defaults to ltsc2016, ltsc2019, ltsc2022 and ltsc2025.

    .PARAMETER ImageRepo
    The repository to read the published '<tag>-dev' images from
    (default: mcr.microsoft.com/businesscentral).

    .EXAMPLE
    ./checknewbaseimage.ps1
#>
param(
    [Parameter(Mandatory = $false)]
    [string[]] $LtscTags = @('ltsc2016', 'ltsc2019', 'ltsc2022', 'ltsc2025'),
    [Parameter(Mandatory = $false)]
    [string] $ImageRepo = "mcr.microsoft.com/businesscentral"
)

$erroractionpreference = "STOP"

# List of the base image tags used for the Business Central images
# https://mcr.microsoft.com/en-us/artifact/mar/dotnet/framework/runtime
$baseImage = "mcr.microsoft.com/dotnet/framework/runtime"
$baseImageTags = @{
    "ltsc2016" = "4.8-windowsservercore-ltsc2016"
    "ltsc2019" = "4.8-windowsservercore-ltsc2019"
    "ltsc2022" = "4.8.1-windowsservercore-ltsc2022"
    "ltsc2025" = "4.8.1-windowsservercore-ltsc2025"
}

# Return the layer digests for an image reference, following one level of manifest list
# (OCI index) to the windows/amd64 manifest. Returns $null if the image can't be inspected.
function Get-ImageLayers {
    param(
        [string] $Image
    )
    $raw = docker manifest inspect $Image 2>$null
    if (-not $raw) {
        return $null
    }
    $manifest = $raw | ConvertFrom-Json
    if ($manifest.PSObject.Properties.Name -contains 'manifests') {
        $selected = $manifest.manifests | Where-Object { $_.platform.os -eq 'windows' -and $_.platform.architecture -eq 'amd64' } | Select-Object -First 1
        if (-not $selected) {
            return $null
        }
        $repo = $Image.Split(':')[0].Split('@')[0]
        $raw = docker manifest inspect "$repo@$($selected.digest)" 2>$null
        if (-not $raw) {
            return $null
        }
        $manifest = $raw | ConvertFrom-Json
    }
    return @($manifest.layers.digest)
}

$newBaseAvailable = $false
foreach ($ltscTag in $LtscTags) {
    if (-not $baseImageTags.ContainsKey($ltscTag)) {
        Write-Host "Skipping unknown LTSC tag '$ltscTag'" -ForegroundColor Yellow
        continue
    }

    $baseRef = "$($baseImage):$($baseImageTags[$ltscTag])"
    $devRef = "$($ImageRepo):$ltscTag-dev"

    $baseLayers = Get-ImageLayers -Image $baseRef
    if (-not $baseLayers) {
        throw "Unable to inspect base image '$baseRef'"
    }

    $devLayers = Get-ImageLayers -Image $devRef
    if (-not $devLayers) {
        Write-Host "$ltscTag : no published dev image ('$devRef') - rebuild needed" -ForegroundColor Yellow
        $newBaseAvailable = $true
        continue
    }

    $missing = @($baseLayers | Where-Object { $devLayers -notcontains $_ })
    if ($missing.Count -eq 0) {
        Write-Host "$ltscTag : up to date (dev image built on current base)" -ForegroundColor Green
    }
    else {
        Write-Host "$ltscTag : base image changed - rebuild needed" -ForegroundColor Cyan
        $newBaseAvailable = $true
    }
}

Write-Host ""
Write-Host "newBaseAvailable=$newBaseAvailable" -ForegroundColor Green

# Check if this is running in a GitHub Actions environment
if ($ENV:GITHUB_OUTPUT) {
    Add-Content -encoding utf8 -Path $ENV:GITHUB_OUTPUT -Value "newBaseAvailable=$($newBaseAvailable.ToString().ToLower())"
}
