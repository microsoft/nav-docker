$baseimage = "mcr.microsoft.com/dotnet/framework/runtime:4.8-20200527-windowsservercore-2004"
$image = "mygeneric:latest"
$version = "0.1.0.1"

docker pull $baseimage
$osversion = docker inspect --format "{{.OsVersion}}" $baseImage
$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm") 

docker images --format "{{.Repository}}:{{.Tag}}" | % { 
    if ($_ -eq $image) 
    {
        docker rmi $image -f
    }
}

$isolation = "hyperv"

docker build --build-arg baseimage=$baseimage `
             --build-arg created=$created `
             --build-arg tag="$version" `
             --build-arg osversion="$osversion" `
             --isolation=$isolation `
             --memory 8G `
             --tag $image `
             $PSScriptRoot

if ($LASTEXITCODE -ne 0) {
    throw "Failed with exit code $LastExitCode"
}
Write-Host "SUCCESS"
