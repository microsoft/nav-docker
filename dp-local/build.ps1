Param( [PSCustomObject] $json )

# Json format:
#
# $json = '{
#     "platform": "<platform ex. ltsc2019>",
#     "baseimage": "<baseimage ex. microsoft/dynamics-nav:9.0.43402.0>",
#     "genericimage": "<genericimage ex. microsoft/dynamics-nav:generic>",
#     "devpreviewbloburl":  "<url>",
#     "country":  "<country>",
#     "tags":  "<tags ex. microsoft/dynamics-nav:2016-cu1-dk-ltsc2019,microsoft/dynamics-nav:9.0.43402.0-dk-ltsc2019>",
# }' | ConvertFrom-Json

$json.platform | ForEach-Object {

    $osSuffix = "-$_"

    $thisbaseimage = "$($json.baseimage)$osSuffix"
    $thisgenericimage = "$($json.genericimage)$osSuffix"
    $image = "nav:$($json.version)-$($json.country)$osSuffix"

    docker pull $thisgenericimage
    $inspect = docker inspect $thisgenericimage | ConvertFrom-Json
    $genericversion = [Version]::Parse("$($inspect.Config.Labels.tag)")

    docker pull $thisbaseimage
    $inspect = docker inspect $thisbaseimage | ConvertFrom-Json
    $baseversion = [Version]::Parse("$($inspect.Config.Labels.tag)")

    if ($genericVersion -ne $baseversion) {
        throw "Cannot build local image before w1 has been built"
    }

    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }

    Write-Host "Build $image from $thisbaseimage"
    $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")

    docker build --build-arg baseimage="$thisbaseimage" `
                 --build-arg created="$created" `
                 --build-arg devpreviewurl="$($json.devpreviewbloburl)" `
                 --build-arg country="$($json.country)" `
                 --tag $image `
                 $PSScriptRoot

    if ($LASTEXITCODE) {
        throw "Error building image"
    } else {
        $json.tags.Split(',') | ForEach-Object {
            docker tag $image $_
            docker push $_
        }

        $json.tags.Split(',') | ForEach-Object {
            docker rmi $_ -f
        }
        docker rmi $image -f
    }
}
