Param( [PSCustomObject] $json )

# Json format:
#
#{
#    "version":  "13.1.25940.26534",
#    "task":  "dp-local",
#    "navversion":  "",
#    "tags":  "mcrbusinesscentral.azurecr.io/public/businesscentral/sandbox:13.1.25940.26534-nl,mcrbusinesscentral.azurecr.io/public/businesscentral/sandbox:13.1.25940.26534-nl-ltsc2016",
#    "genericimage":  "microsoft/dynamics-nav:generic",
#    "registry":  "mcrbusinesscentral.azurecr.io/",
#    "baseimage":  "mcrbusinesscentral.azurecr.io/public/businesscentral/sandbox:13.1.25940.26534-base",
#    "disablestrongnamevalidation":  null,
#    "platform":  "ltsc2016",
#    "cu":  "",
#    "country":  "NL",
#    "blobcontainer":  "dvd",
#    "maintainer":  "Dynamics SMB",
#    "devpreviewblobname":  "69137e70-d76a-4e57-8939-80b0f5d53fab",
#    "devpreviewbloburl":  "https://nav2016wswe0.blob.core.windows.net/dvd/69137e70-d76a-4e57-8939-80b0f5d53fab"
#}


$json.platform | ForEach-Object {

    $osSuffix = $_
    $thisbaseimage = $json.baseimage
    if (!($thisbaseimage.EndsWith($osSuffix))) {
        $thisbaseimage += "-$osSuffix"
    }

    $thisgenericimage = $($json.genericimage)
    if (!($thisgenericimage.EndsWith($osSuffix))) {
        $thisgenericimage += "-$osSuffix"
    }

    $image = "dp:$($json.version)-$($json.country)-$osSuffix"

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

    docker build --build-arg baseimage="$thisbaseimage" `
                 --build-arg created="$created" `
                 --build-arg devpreviewurl="$($json.devpreviewbloburl)" `
                 --build-arg country="$($json.country)" `
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
