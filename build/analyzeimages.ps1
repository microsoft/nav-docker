param(
    [Parameter(Mandatory = $false)]
    [int] $RevisionNumber,
    [Parameter(Mandatory = $false)]
    [switch] $PushToProd
)

try {
    $repositoryRoot = Join-Path $PSScriptRoot "..\"
    Push-Location (Join-Path $repositoryRoot "generic")
    $rootPath = Get-Location

    # List of the base image tags used for the Business Central images
    # https://mcr.microsoft.com/en-us/artifact/mar/dotnet/framework/runtime
    $baseImage = "dotnet/framework/runtime"
    $baseImageTags = @{
        "ltsc2016" = "4.8-windowsservercore-ltsc2016"
        "ltsc2019" = "4.8-windowsservercore-ltsc2019"
        "ltsc2022" = "4.8.1-windowsservercore-ltsc2022"
        "ltsc2025" = "4.8.1-windowsservercore-ltsc2025"
    }

    # List of the Business Central tags to be used
    $bctags = @('ltsc2016', 'ltsc2019', 'ltsc2022', 'ltsc2025')

    # Get the tags for the Business Central images
    $tags = @($bctags | ForEach-Object { "$_-dev"; "$_-filesonly-dev" })
    if ($PushToProd) {
        $tags += @($bctags | ForEach-Object { "$_"; "$_-filesonly" })
    }

    # Get the digests for the tags from the Microsoft Container Registry
    $digests = $tags | ForEach-Object {
        $tag = $_
        $manifest = docker manifest inspect mcr.microsoft.com/businesscentral:$tag -v | ConvertFrom-Json
        $digest = $manifest.Descriptor.digest
        Write-Host "Digest for tag $($tag): $digest" -ForegroundColor Cyan
        return $manifest.Descriptor.digest
    } | Select-Object -Unique
    Write-Host "Found $($digests.Count) digests will be marked as stale:"

    # Get the generic tag to use for the images
    $genericTag = (Get-Content -Raw -Path (Join-Path $RootPath 'tag.txt')).Trim(@(13, 10, 32))
    $tagver = [System.Version]$genericTag
    $genericTag = "$($tagver.Major).$($tagver.Minor).$($tagver.Build).$RevisionNumber"
    Write-Host "Using generic Tag $genericTag"


    # Build a list of strings that contain the necessary information to build the Business Central images
    # The format is: "osVersion-genericTag|mcr.microsoft.com/baseImage:baseImageTag|bctag"
    # This will be used in the later steps to build the images
    $webclient = New-Object System.Net.WebClient
    $webclient.Headers.Add('Accept', "application/json")
    $neededBcTags = $bctags | ForEach-Object {
        $osVersion = [System.Version](($webclient.DownloadString("https://mcr.microsoft.com/v2/$baseImage/manifests/$($baseImageTags."$_")") | ConvertFrom-Json).history[0].v1Compatibility | ConvertFrom-Json)."os.version"
        "$osVersion-$genericTag|mcr.microsoft.com/$($baseImage):$($baseImageTags."$_")|$_"
        "$osVersion-$genericTag-filesonly|mcr.microsoft.com/$($baseImage):$($baseImageTags."$_")|$_"
    }
    Write-Host "Needed Tags ($($neededBcTags.Count))"
    $neededBcTags | ForEach-Object { Write-Host "- $_" }
    $alltags = (($webclient.DownloadString("https://mcr.microsoft.com/v2/businesscentral/tags/list") | ConvertFrom-Json)).tags
    $imagesBcTags = @($neededBcTags | Where-Object { $alltags -notcontains $_ })
    Write-Host "Image Tags ($($imagesBcTags.Count))"
    if ($imagesBcTags) {
        $imagesBcTags | ForEach-Object { Write-Host "- $_" }
    }
    else {
        Write-Host '- none'
    }

    # Output digests, generic tag and build images as JSON to be used in the GitHub Actions workflow
    $buildImagesJson = ConvertTo-Json -InputObject $imagesBcTags -Compress
    $digestsJson = ConvertTo-Json -InputObject $digests -Compress
    Write-Host "genericTag=$genericTag" -ForegroundColor Green
    Write-Host "digestsJson=$digestsJson" -ForegroundColor Green
    Write-Host "buildImagesJson=$buildImagesJson" -ForegroundColor Green

    # Check if this is running in a GitHub Actions environment
    if ($ENV:GITHUB_OUTPUT) {
        Add-Content -encoding utf8 -Path $ENV:GITHUB_OUTPUT -Value "genericTag=$genericTag"
        Add-Content -encoding utf8 -Path $ENV:GITHUB_OUTPUT -Value "digestsJson=$digestsJson"
        Add-Content -encoding utf8 -Path $ENV:GITHUB_OUTPUT -Value "buildImagesJson=$buildImagesJson"
    }

}
finally {
    Pop-Location
}