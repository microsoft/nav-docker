Param( [PSCustomObject] $json )

# Json format:
#
# $json = '{
#     "platform": "<platform ex. ltsc2019",
#     "version":  "<version ex. 0.0.8.1>"
# }' | ConvertFrom-Json

$os = $json.platform

if ($os -eq "ltsc2019") {
    $baseimage = "mcr.microsoft.com/windows/servercore:$os"
} else {
    $baseimage = "microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-$os"
}

if ($os.StartsWith("ltsc")) {
    $isolation = "process"
} else {
    $isolation = "hyperv"
}

$image = "generic:$os"

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

if ($tags) {
    $tags = @("microsoft/dynamics-nav:generic-$os")
    if ($os -eq "ltsc2016") {
        $tags += "microsoft/dynamics-nav:generic"
    }
    
    $tags | ForEach-Object {
        docker tag $image $_
        docker push $_
    }
}

