Param( [PSCustomObject] $json )

# Json format:
#
# $json = '{
#     "platform": "<platform ex. ltsc2019",
#     "version":  "<version ex. 0.0.8.1>"
# }' | ConvertFrom-Json

$push = $true

$myos = (Get-CimInstance Win32_OperatingSystem)
if ($myos.OSType -ne 18 -or !$myos.Version.StartsWith("10.0.")) {
    throw "Unknown Host Operating System"
}

if ($myos.BuildNumber -ge 18362) {
    $json = '{
        "platform": "1903",
        "version": "0.0.9.98"
    }' | ConvertFrom-Json
}

if ($myos.BuildNumber -ge 18363) {
    $json = '{
        "platform": "1903,1909",
        "version": "0.0.9.98"
    }' | ConvertFrom-Json
}

$json.platform.Split(',') | ForEach-Object {

    $os = $_
    $version = $json.version

    $baseimage = "mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-$os"
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

    if ($os -eq "ltsc2016") {
        $isolation = "process"
    }
    else {
        $isolation = "hyperv"
    }
    
    docker build --build-arg baseimage=$baseimage `
                 --build-arg created=$created `
                 --build-arg tag="$version" `
                 --build-arg osversion="$osversion" `
                 --isolation=$isolation `
                 --tag $image `
                 $PSScriptRoot
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed with exit code $LastExitCode"
    }
    Write-Host "SUCCESS"

    if ($push) {
        $tags = @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:generic-$os","mcrbusinesscentral.azurecr.io/public/dynamicsnav:generic-$version-$os")
        if ($os -eq "ltsc2016") {
            $tags += @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:generic")
        }
        
        $tags | ForEach-Object {
            docker tag $image $_
            docker push $_
        }
    }

}