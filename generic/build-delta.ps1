Param(
    [string] $acr = "navgeneric",
    [string[]] $oss = @("1803")
)

. (Join-Path $PSScriptRoot "Settings.ps1")

$oss | ForEach-Object {
    
    $baseimage = "microsoft/dynamics-nav:generic-$_"

    if ($_ -eq "ltsc2016") {
        if ([System.Environment]::OSVersion.Version.Build -ne 14393) {
            throw "ltsc2016 cannot be build on host OS other than ltsc2016"
        }
    }

    $image = "generic:$_"

    docker pull $baseimage

    docker rmi $image -f 2>NULL | Out-Null
    docker build --build-arg baseimage=$baseimage `
                 --tag $image `
                 --file (Join-Path $PSScriptRoot "DOCKERFILE.DELTA") `
                 $PSScriptRoot
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS"

    }
}
