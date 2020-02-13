Param( [PSCustomObject] $json )

# Json format:
#
# $json = '{
#     "platform": "<platform ex. ltsc2019>",
#     "baseimage": "<baseimage ex. microsoft/dynamics-nav:9.0.43402.0>",
#     "genericimage": "<genericimage ex. microsoft/dynamics-nav:generic>",
#     "countrybloburl":  "<url>",
#     "country":  "<country>",
#     "tags":  "<tags ex. microsoft/dynamics-nav:2016-cu1-dk-ltsc2019,microsoft/dynamics-nav:9.0.43402.0-dk-ltsc2019>",
# }' | ConvertFrom-Json

cd $PSScriptRoot

$json.platform | ForEach-Object {

    $osSuffix = $_
    $thisbaseimage = $json.baseimage
    if (!($thisbaseimage.EndsWith($osSuffix))) {
        $thisbaseimage += "-$osSuffix"
    }

    $thisgenericimage = $($json.genericimage)
    $thisgenericimage = $thisgenericimage.Replace("microsoft/dynamics-nav:generic","mcr.microsoft.com/dynamicsnav:generic")
    if (!($thisgenericimage.EndsWith($osSuffix))) {
        $thisgenericimage += "-$osSuffix"
    }
    
    $image = "nav:$($json.version)-$($json.country)-$osSuffix"

    docker pull $thisgenericimage 2>NULL
    $inspect = docker inspect $thisgenericimage | ConvertFrom-Json
    $genericversion = [Version]::Parse("$($inspect.Config.Labels.tag)")

    docker pull $thisbaseimage 2>NULL
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

    if ($osSuffix -eq "ltsc2016") {
        $isolation = "process"
    }
    else {
        $isolation = "hyperv"
    }

    docker build --build-arg baseimage="$thisbaseimage" `
                 --build-arg created="$created" `
                 --build-arg countryurl="$($json.countrybloburl)" `
                 --build-arg country="$($json.country)" `
                 --isolation=$isolation `
                 --tag $image `
                 $PSScriptRoot

    if ($LASTEXITCODE) {
        throw "Error building image"
    } else {
        if ($json.tags) {
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
}
