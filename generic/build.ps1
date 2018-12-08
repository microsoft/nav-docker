Param( [PSCustomObject] $json )

# Json format:
#
# $json = '{
#     "version":  "<version ex. 0.0.8.1>",
# }' | ConvertFrom-Json

if ([System.Environment]::OSVersion.Version.Build -eq 14393) {
    $oss = @("ltsc2016") 
} else {
    $oss = @("ltsc2019","1709","1803")
}

$oss | ForEach-Object {
    
    $baseimage = "mcr.microsoft.com/windows/servercore:$_"
    
    if ($_.StartsWith("ltsc")) {
        $isolation = "process"
    } else {
        $isolation = "hyperv"
    }

    $image = "generic:$_"

    docker pull $baseimage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage

    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }

    docker build --build-arg baseimage=$baseimage `
                 --build-arg created=$created `
                 --build-arg tag="$($json.version)" `
                 --build-arg osversion="$osversion" `
                 --isolation=$isolation `
                 --tag $image `
                 $PSScriptRoot
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed with exit code $LastExitCode"
    }
    Write-Host "SUCCESS"

    $tags = @("microsoft/dynamics-nav:generic-$_")
    if ($_ -eq "ltsc2016") {
        $tags += "microsoft/dynamics-nav:generic"
    }
    
    $tags | ForEach-Object {
        docker tag $image $_
        docker push $_
    }
}
