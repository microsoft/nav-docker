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
        "version": "0.0.9.99"
    }' | ConvertFrom-Json
}

if ($myos.BuildNumber -ge 18363) {
    $json = '{
        "platform": "1903,ltsc2019,ltsc2016",
        "version": "0.0.9.99"
    }' | ConvertFrom-Json
}

#1909,1903,ltsc2019,ltsc2016",


'20200211','20200114' | % {
    $dt = $_
    
    $json.platform.Split(',') | ForEach-Object {
    
        $os = $_
        $version = $json.version
    
        $baseimage = "mcr.microsoft.com/dotnet/framework/runtime:4.8-$dt-windowsservercore-$os"
        $image = "$dt-generic:$os"
        
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
    
        if ($push) {
            $tags = @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:$dt-generic-$os","mcrbusinesscentral.azurecr.io/public/dynamicsnav:$dt-generic-$version-$os")
            if ($os -eq "ltsc2016") {
                $tags += @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:$dt-generic")
            }
            
            $tags | ForEach-Object {
                docker tag $image $_
                docker push $_
            }
        }
    
    }
}