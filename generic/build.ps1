$RootPath = $PSScriptRoot

. (Join-Path $RootPath "settings.ps1")

$os = (Get-CimInstance Win32_OperatingSystem)
if ($os.OSType -ne 18 -or !$os.Version.StartsWith("10.0.")) {
    throw "Unknown Host Operating System"
}
$UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
$hostOsVersion = [System.Version]::Parse("$($os.Version).$UBR")

Write-Host "Host OS Version is $hostOsVersion"

$baseImage = ""
$webclient = New-Object System.Net.WebClient
$basetags = (Get-NavContainerImageTags -imageName "mcr.microsoft.com/dotnet/framework/runtime").tags | Where-Object { $_.StartsWith('4.8-20') } | Sort-Object -Descending  | Where-Object { -not $_.endswith("-1803") }
$basetags | ForEach-Object {
    if (!($baseImage)) {
        $manifest = (($webclient.DownloadString("https://mcr.microsoft.com/v2/dotnet/framework/runtime/manifests/$_") | ConvertFrom-Json).history[0].v1Compatibility | ConvertFrom-Json)
        if ($hostOsVersion -eq $manifest.'os.version') {
            $baseImage = "mcr.microsoft.com/dotnet/framework/runtime:$_"
            Write-Host "$baseImage matches the host OS version"
        }
    }
}
if (!($baseImage)) {
    Write-Error "Unable to find a matching mcr.microsoft.com/dotnet/framework/runtime docker image"
}
else {
    $image = "mygeneric"
 
    docker pull $baseimage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage

    $isolation = "process"
    if ($osversion -ne $hostOsVersion) {
        $isolation = "hyperv"
    }
    
    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }
    
    docker build --build-arg baseimage=$baseimage `
                 --build-arg created=$created `
                 --build-arg tag="$genericTag" `
                 --build-arg osversion="$osversion" `
                 --isolation=$isolation `
                 --tag $image `
                 $RootPath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed with exit code $LastExitCode"
    }
    else {
        Write-Host "SUCCESS"
    }
}
