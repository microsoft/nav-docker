$RootPath = $PSScriptRoot

. (Join-Path $RootPath "settings.ps1")

function Head($text) {
    try {
        $s = (New-Object System.Net.WebClient).DownloadString("http://artii.herokuapp.com/make?text=$text")
    } catch {
        $s = $text
    }
    Write-Host -ForegroundColor Yellow $s
}

$baseTagVersion = "0.1.0.13"

$testImages = $false

$pushto = @()
$pushto = @("dev")
$pushto = @("prod")
$pushto = @("dev","prod")

$tags = @(
"10.0.14393.2906-generic-$baseTagVersion"
"10.0.17763.437-generic-$baseTagVersion"
"10.0.18362.116-generic-$baseTagVersion"

"10.0.14393.2972-generic-$baseTagVersion"
"10.0.17763.504-generic-$baseTagVersion"
"10.0.18362.175-generic-$baseTagVersion"

"10.0.14393.3025-generic-$baseTagVersion"
"10.0.17763.557-generic-$baseTagVersion"
"10.0.18362.239-generic-$baseTagVersion"

"10.0.14393.3085-generic-$baseTagVersion"
"10.0.17763.615-generic-$baseTagVersion"
"10.0.18362.295-generic-$baseTagVersion"

"10.0.14393.3144-generic-$baseTagVersion"
"10.0.17763.678-generic-$baseTagVersion"
"10.0.18362.356-generic-$baseTagVersion"

"10.0.14393.3204-generic-$baseTagVersion"
"10.0.17763.737-generic-$baseTagVersion"
"10.0.18362.476-generic-$baseTagVersion"
"10.0.18363.476-generic-$baseTagVersion"

"10.0.14393.3326-generic-$baseTagVersion"
"10.0.17763.864-generic-$baseTagVersion"
"10.0.18362.535-generic-$baseTagVersion"
"10.0.18363.535-generic-$baseTagVersion"

"10.0.14393.3384-generic-$baseTagVersion"
"10.0.17763.914-generic-$baseTagVersion"
"10.0.18362.592-generic-$baseTagVersion"
"10.0.18363.592-generic-$baseTagVersion"

"10.0.14393.3443-generic-$baseTagVersion"
"10.0.17763.973-generic-$baseTagVersion"
"10.0.18362.658-generic-$baseTagVersion"
"10.0.18363.658-generic-$baseTagVersion"

"10.0.14393.3506-generic-$baseTagVersion"
"10.0.17763.1040-generic-$baseTagVersion"
"10.0.18362.720-generic-$baseTagVersion"
"10.0.18363.720-generic-$baseTagVersion"

"10.0.14393.3630-generic-$baseTagVersion"
"10.0.17763.1158-generic-$baseTagVersion"
"10.0.18362.778-generic-$baseTagVersion"
"10.0.18363.778-generic-$baseTagVersion"

"10.0.14393.3686-generic-$baseTagVersion"
"10.0.17763.1217-generic-$baseTagVersion"
"10.0.18362.836-generic-$baseTagVersion"
"10.0.18363.836-generic-$baseTagVersion"
"10.0.19041.264-generic-$baseTagVersion"

"10.0.14393.3750-generic-$baseTagVersion"
"10.0.17763.1282-generic-$baseTagVersion"
"10.0.18362.900-generic-$baseTagVersion"
"10.0.18363.900-generic-$baseTagVersion"
"10.0.19041.329-generic-$baseTagVersion"

"10.0.14393.3808-generic-$baseTagVersion"
"10.0.17763.1339-generic-$baseTagVersion"
"10.0.18362.959-generic-$baseTagVersion"
"10.0.18363.959-generic-$baseTagVersion"
"10.0.19041.388-generic-$baseTagVersion"

"10.0.14393.3866-generic-0.1.0.14"
"10.0.17763.1397-generic-0.1.0.14"
"10.0.18362.1016-generic-0.1.0.14"
"10.0.18363.1016-generic-0.1.0.14"
"10.0.19041.450-generic-0.1.0.14"

"10.0.14393.3930-generic-0.1.0.21"
"10.0.17763.1457-generic-0.1.0.21"
"10.0.18362.1082-generic-0.1.0.21"
"10.0.18363.1082-generic-0.1.0.21"
"10.0.19041.508-generic-0.1.0.21"
)

[Array]::Reverse($tags)

$oldGenericTag = "0.1.0.21"
$tags | % {
    $tag = $_
    
    $osversion = $tag.Substring(0,$tag.IndexOf('-'))
    $image = "my:$osversion-generic-$oldGenericTag"

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
    $image = "mcr.microsoft.com/dynamicsnav:$tag"
    docker pull $image
}

throw "go!"

$tags | % {
    $tag = $_
    
    head $tag
    
    $isolation = "hyperv"
    $baseimage = "mcr.microsoft.com/dynamicsnav:$tag"
    $osversion = $tag.Substring(0,$tag.IndexOf('-'))

    docker pull $baseimage

    $image = "my:$osversion-generic-$genericTag"

    docker images --format "{{.Repository}}:{{.Tag}}" | % { 
        if ($_ -eq $image) 
        {
            docker rmi $image -f
        }
    }
    
    $dockerfile = Join-Path $RootPath "DOCKERFILE.UPDATE"

    if ($baseTagVersion -eq "0.1.0.7") {
@"
FROM $baseimage

COPY Run /Run/

RUN . c:\run\helperfunctions.ps1 ; \
    Start-Service -Name `$SqlBrowserServiceName -ErrorAction Ignore -WarningAction Ignore ; \
    Start-Service -Name `$SqlWriterServiceName -ErrorAction Ignore -WarningAction Ignore ; \
    Start-Service -Name `$SqlServiceName -ErrorAction Ignore -WarningAction Ignore ; \
    SetDatabaseServerCollation -collation "Latin1_General_100_CS_AS" ; \
    Invoke-WebRequest -Uri 'https://bcartifacts.azureedge.net/prerequisites/rewrite_2.0_rtw_x64.msi' -OutFile rewrite_amd64.msi ; \
    start-process -Wait -FilePath .\rewrite_amd64.msi -ArgumentList /quiet, /qn, /passive ; \
    Invoke-WebRequest -Uri 'https://bcartifacts.azureedge.net/prerequisites/OpenXMLSDKv25.msi' -OutFile OpenXMLSDKV25.msi ; \
    start-process -Wait -FilePath .\OpenXMLSDKV25.msi -ArgumentList /quiet, /qn, /passive ; \
    Invoke-WebRequest -Uri 'https://bcartifacts.azureedge.net/prerequisites/DotNetCore.1.0.4_1.1.1-WindowsHosting.exe' -OutFile DotNetCore-WindowsHosting.exe ; \
    start-process -Wait -FilePath .\DotNetCore-WindowsHosting.exe -ArgumentList /quiet ; \
    Remove-Item -Recurse -Force rewrite_amd64.msi, OpenXMLSDKV25.msi, DotNetCore-WindowsHosting.exe

LABEL tag="$genericTag" \
      created="$created"
"@ | Set-Content $dockerfile
    }
    elseif ($baseTagVersion -eq "0.1.0.13" -or $baseTagVersion -eq "0.1.0.14") {
@"
FROM $baseimage

COPY Run /Run/

LABEL tag="$genericTag" \
      created="$created"
"@ | Set-Content $dockerfile
    }
    else {
        throw "dockerfile not defined for $baseTagVersion"
    }

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
        $newtags += @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic-dev","mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic-dev-$genericTag")
    }
    if ($pushto.Contains("prod")) {
        $newtags += @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic","mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic-$genericTag")
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
