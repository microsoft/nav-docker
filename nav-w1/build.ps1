Param( [PSCustomObject] $json )

# Json format:
#
# $json = '{L
#     "platform": "<platform ex. ltsc2019>",
#     "baseimage": "<baseimage ex. microsoft/dynamics-nav:generic>",
#     "navdvdbloburl":  "<url>",
#     "vsixbloburl":  "<url>",
#     "country":  "<country>",
#     "navversion":  "<version ex. 2016>",
#     "legal":  "<legal url>",
#     "cu":  "<cu ex. cu1>",
#     "version":  "<version ex. 9.0.43402.0>",
#     "tags":  "<tags ex. microsoft/dynamics-nav:9.0.43402.0-ltsc2019,microsoft/dynamics-nav:2016-cu1-ltsc2019,microsoft/dynamics-nav:2016-cu1-w1-ltsc2019>",
# }' | ConvertFrom-Json

$json.platform | ForEach-Object {

    $osSuffix = $_
    $thisbaseimage = $json.baseimage
    if (!($thisbaseimage.EndsWith($osSuffix))) {
        $thisbaseimage += "-$osSuffix"
    }
    
    $image = "nav:$($json.version)-base-$osSuffix"

    docker pull $thisbaseimage 2>NULL
    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }

    Write-Host "Build $image from $thisbaseimage"
    $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")

    docker build --build-arg baseimage="$thisbaseimage" `
                 --build-arg navdvdurl="$($json.navdvdbloburl)" `
                 --build-arg vsixurl="$($json.vsixbloburl)" `
                 --build-arg legal="$($json.legal)" `
                 --build-arg created="$created" `
                 --build-arg nav="$($json.navversion)" `
                 --build-arg cu="$($json.cu)" `
                 --build-arg country="$($json.country)" `
                 --build-arg version="$($json.version)" `
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
        }
    }
}
