Param( [PSCustomObject] $json )

# Json format:
#
# $json = '{
#     "platform": "<platform ex. ltsc2019",
#     "version":  "<version ex. 0.0.8.1>"
# }' | ConvertFrom-Json

$myos = (Get-CimInstance Win32_OperatingSystem)
if ($myos.OSType -ne 18 -or !$myos.Version.StartsWith("10.0.")) {
    throw "Unknown Host Operating System"
}

if ($myos.Version -eq "10.0.18362") {
    $json = '{
        "platform": "1903",
        "version":  "0.0.9.93"
    }' | ConvertFrom-Json
}

$os = $json.platform

$baseimage = "mcr.microsoft.com/dotnet/framework/runtime:4.7.2-windowsservercore-$os"

if ($os.StartsWith("ltsc")) {
    $isolation = "process"
} else {
    $isolation = "hyperv"
}
if ($os -eq "1903") {
    $baseimage = "mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-$os"
    $isolation = "process"
}
$image = "generic:$os"

docker pull $baseimage
$osversion = docker inspect --format "{{.OsVersion}}" $baseImage
$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm") 

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

$tags = @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:generic-$os","mcrbusinesscentral.azurecr.io/public/dynamicsnav:generic-$($json.version)-$os")
if ($os -eq "ltsc2016") {
    $tags += @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:generic")
}

$tags | ForEach-Object {
    docker tag $image $_
    docker push $_
}
