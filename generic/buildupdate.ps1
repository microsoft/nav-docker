$RootPath = $PSScriptRoot
$ErrorActionPreference = "Stop"

. (Join-Path $RootPath "settings.ps1")

function Head($text) {
    try {
        $s = (New-Object System.Net.WebClient).DownloadString("http://artii.herokuapp.com/make?text=$text")
    } catch {
        $s = $text
    }
    Write-Host -ForegroundColor Yellow $s
}

$testImages = $false

$pushto = @()
$pushto = @("dev")
#$pushto = @("prod")
#$pushto = @("dev","prod")

$tags = @(
"10.0.14393.2906-1.0.0.0"
"10.0.14393.2972-1.0.0.0"
"10.0.14393.3025-1.0.0.0"
"10.0.14393.3085-1.0.0.0"
"10.0.14393.3144-1.0.0.0"
"10.0.14393.3204-1.0.0.0"
"10.0.14393.3326-1.0.0.0"
"10.0.14393.3384-1.0.0.0"
"10.0.14393.3443-1.0.0.0"
"10.0.14393.3630-1.0.0.0"
"10.0.14393.3750-1.0.0.0"
"10.0.14393.3808-1.0.0.0"
"10.0.14393.3866-1.0.0.0"
"10.0.14393.3930-1.0.0.0"
"10.0.14393.3986-1.0.0.0"
"10.0.14393.4046-1.0.0.0"
"10.0.17134.1006-1.0.0.0"
"10.0.17134.1130-1.0.0.0"
"10.0.17134.706-1.0.0.0"
"10.0.17134.766-1.0.0.0"
"10.0.17134.829-1.0.0.0"
"10.0.17134.885-1.0.0.0"
"10.0.17134.950-1.0.0.0"
"10.0.17763.1158-1.0.0.0"
"10.0.17763.1282-1.0.0.0"
"10.0.17763.1339-1.0.0.0"
"10.0.17763.1397-1.0.0.0"
"10.0.17763.1457-1.0.0.0"
"10.0.17763.1518-1.0.0.0"
"10.0.17763.1577-1.0.0.0"
"10.0.17763.437-1.0.0.0"
"10.0.17763.504-1.0.0.0"
"10.0.17763.557-1.0.0.0"
"10.0.17763.615-1.0.0.0"
"10.0.17763.678-1.0.0.0"
"10.0.17763.737-1.0.0.0"
"10.0.17763.864-1.0.0.0"
"10.0.17763.914-1.0.0.0"
"10.0.17763.973-1.0.0.0"
"10.0.18362.1016-1.0.0.0"
"10.0.18362.1082-1.0.0.0"
"10.0.18362.1139-1.0.0.0"
"10.0.18362.116-1.0.0.0"
"10.0.18362.1198-1.0.0.0"
"10.0.18362.175-1.0.0.0"
"10.0.18362.239-1.0.0.0"
"10.0.18362.295-1.0.0.0"
"10.0.18362.356-1.0.0.0"
"10.0.18362.476-1.0.0.0"
"10.0.18362.535-1.0.0.0"
"10.0.18362.592-1.0.0.0"
"10.0.18362.658-1.0.0.0"
"10.0.18362.778-1.0.0.0"
"10.0.18362.900-1.0.0.0"
"10.0.18362.959-1.0.0.0"
"10.0.18363.1016-1.0.0.0"
"10.0.18363.1082-1.0.0.0"
"10.0.18363.1139-1.0.0.0"
"10.0.18363.1198-1.0.0.0"
"10.0.18363.476-1.0.0.0"
"10.0.18363.535-1.0.0.0"
"10.0.18363.592-1.0.0.0"
"10.0.18363.658-1.0.0.0"
"10.0.18363.778-1.0.0.0"
"10.0.18363.900-1.0.0.0"
"10.0.18363.959-1.0.0.0"
"10.0.19041.329-1.0.0.0"
"10.0.19041.388-1.0.0.0"
"10.0.19041.450-1.0.0.0"
"10.0.19041.508-1.0.0.0"
"10.0.19041.572-1.0.0.0"
"10.0.19041.630-1.0.0.0"
"10.0.19042.572-1.0.0.0"
"10.0.19042.630-1.0.0.0"

)

[Array]::Reverse($tags)

$oldGenericTag = "1.0.0.1"
$tags | % {
    $tag = $_
    
    $osversion = $tag.Substring(0,$tag.IndexOf('-'))
    $image = "my:$osversion-$oldGenericTag"

    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }
}

$tags | % {
    $tag = $_
    head $tag
    $image = "mcr.microsoft.com/businesscentral:$tag"
    docker pull $image
}

throw "go!"

$tags | % {
    $tag = $_
    
    head $tag
    
    $isolation = "hyperv"
    $baseimage = "mcr.microsoft.com/businesscentral:$tag"
    $osversion = $tag.Substring(0,$tag.IndexOf('-'))

    docker pull $baseimage

    $image = "my:$osversion-$genericTag"

    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }
    
    $dockerfile = Join-Path $RootPath "DOCKERFILE.UPDATE"

@"
FROM $baseimage

COPY Run /Run/

LABEL tag="$genericTag" \
      created="$created"
"@ | Set-Content $dockerfile

    docker build --isolation=$isolation `
                 --tag $image `
                 --file $dockerfile `
                 --memory 4G `
                 $RootPath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed with exit code $LastExitCode"
    }
    Write-Host "SUCCESS"
    Remove-Item $dockerfile -Force

    # Test image
    if ($testImages) {
        $artifactUrl = Get-BCArtifactUrl -type OnPrem -country w1
        $password = 'P@ssword1'
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
        $credential = New-Object pscredential 'admin', $securePassword
        
        $parameters = @{
            "accept_eula"               = $true
            "containerName"             = "test"
            "artifactUrl"               = $artifactUrl
            "useGenericImage"           = $image
            "auth"                      = "NAVUserPassword"
            "Credential"                = $credential
            "updateHosts"               = $true
            "doNotCheckHealth"          = $true
            "EnableTaskScheduler"       = $false
            "Isolation"                 = "hyperv"
            "MemoryLimit"               = "8G"
        }
        
        New-NavContainer @parameters
        Remove-NavContainer -containerName "test"
    }

    $newtags = @()
    if ($pushto.Contains("dev")) {
        $newtags += @(
            "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-dev"
        )
    }
    if ($pushto.Contains("prod")) {
        $newtags += @(
            "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion",
            "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-$genericTag")
    }
    $newtags | ForEach-Object {
        Write-Host "Push $_"
        docker tag $image $_
        docker push $_
    }
    $newtags | ForEach-Object {
        Write-Host "Remove $_"
        docker rmi $_
    }
}
