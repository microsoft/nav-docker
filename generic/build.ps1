$RootPath = $PSScriptRoot
$ErrorActionPreference = "stop"
Set-StrictMode -Version 2.0

0..3 | % {
$filesOnly = $_ -gt 1
$only24 = $_ -eq 0 -or $_ -eq 2
$genericTag = '1.0.2.16'
$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")
$image = "mygeneric"

$os = (Get-CimInstance Win32_OperatingSystem)
if ($os.OSType -ne 18 -or !$os.Version.StartsWith("10.0.")) {
    throw "Unknown Host Operating System"
}
$UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR).UBR
$hostOsVersion = [System.Version]::Parse("$($os.Version).$UBR")
$hostOsVersion = [System.Version]'10.0.20348.2322'

Write-Host "Host OS Version is $hostOsVersion"

$baseImage = ""
$webclient = New-Object System.Net.WebClient
$basetags = (Get-NavContainerImageTags -imageName "mcr.microsoft.com/dotnet/framework/runtime").tags | Where-Object { $_.StartsWith('4.8-20') } | Sort-Object -Descending  | Where-Object { -not $_.endswith("-1803") }
$basetags | ForEach-Object {
    if (!($baseImage)) {
        $manifest = (($webclient.DownloadString("https://mcr.microsoft.com/v2/dotnet/framework/runtime/manifests/$_") | ConvertFrom-Json).history[0].v1Compatibility | ConvertFrom-Json)
        Write-Host "$hostOsVersion == $($manifest.'os.version')"
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

    $dockerfile = Join-Path $RootPath "DOCKERFILE"
    if ($only24) {
        $image += "-24"
        $baseimage = 'mcr.microsoft.com/windows/servercore:ltsc2022'
    }
    if ($filesOnly) {
        $dockerfile += '-filesonly'
        $image += '-filesonly'
    }
    docker pull $baseimage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage
    $isolation = "hyperv"

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
                 --build-arg filesonly="$filesonly" `
                 --build-arg only24="$only24" `
                 --isolation=$isolation `
                 --memory 64G `
                 --tag $image `
                 --file $dockerfile `
                 $RootPath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed with exit code $LastExitCode"
    }
    else {
        Write-Host "SUCCESS"
    }
}
}