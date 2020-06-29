$RootPath = $PSScriptRoot

. (Join-Path $RootPath "settings.ps1")

$push = $true

$tags = @(
"10.0.14393.2906-generic-0.1.0.2"
"10.0.14393.2972-generic-0.1.0.2"
"10.0.14393.3025-generic-0.1.0.2"
"10.0.14393.3085-generic-0.1.0.2"
"10.0.14393.3144-generic-0.1.0.2"
"10.0.14393.3204-generic-0.1.0.2"
"10.0.14393.3326-generic-0.1.0.2"
"10.0.14393.3384-generic-0.1.0.2"
"10.0.14393.3443-generic-0.1.0.2"
"10.0.14393.3506-generic-0.0.9.99"
"10.0.14393.3630-generic-0.1.0.2"
"10.0.14393.3686-generic-0.1.0.1"
"10.0.14393.3750-generic-0.1.0.2"
"10.0.17134.1006-generic-0.0.9.99"
"10.0.17134.1130-generic-0.0.9.99"
"10.0.17134.950-generic-0.0.9.99"
"10.0.17763.1040-generic-0.0.9.99"
"10.0.17763.1158-generic-0.1.0.2"
"10.0.17763.1217-generic-0.1.0.1"
"10.0.17763.1282-generic-0.1.0.2"
"10.0.17763.437-generic-0.1.0.2"
"10.0.17763.504-generic-0.1.0.2"
"10.0.17763.557-generic-0.1.0.2"
"10.0.17763.615-generic-0.1.0.2"
"10.0.17763.678-generic-0.1.0.2"
"10.0.17763.737-generic-0.1.0.2"
"10.0.17763.864-generic-0.1.0.2"
"10.0.17763.914-generic-0.1.0.2"
"10.0.17763.973-generic-0.1.0.2"
"10.0.18362.116-generic-0.1.0.2"
"10.0.18362.175-generic-0.1.0.2"
"10.0.18362.239-generic-0.1.0.2"
"10.0.18362.295-generic-0.1.0.2"
"10.0.18362.356-generic-0.1.0.1"
"10.0.18362.476-generic-0.1.0.2"
"10.0.18362.535-generic-0.1.0.2"
"10.0.18362.592-generic-0.1.0.2"
"10.0.18362.658-generic-0.1.0.2"
"10.0.18362.720-generic-0.0.9.99"
"10.0.18362.778-generic-0.1.0.2"
"10.0.18362.836-generic-0.1.0.1"
"10.0.18362.900-generic-0.1.0.2"
"10.0.18363.476-generic-0.1.0.2"
"10.0.18363.535-generic-0.1.0.2"
"10.0.18363.592-generic-0.1.0.2"
"10.0.18363.658-generic-0.1.0.2"
"10.0.18363.720-generic-0.0.9.99"
"10.0.18363.778-generic-0.1.0.2"
"10.0.18363.836-generic-0.1.0.1"
"10.0.18363.900-generic-0.1.0.2"
"10.0.19041.264-generic-0.1.0.1"
"10.0.19041.329-generic-0.1.0.2"
)

[Array]::Reverse($tags)

$oldGenericTag = "0.1.0.6"
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
@"
FROM $baseimage

COPY Run /Run/

LABEL tag="$genericTag" \
      created="$created"
"@ | Set-Content $dockerfile

    docker build --isolation=$isolation `
                 --tag $image `
                 --file $dockerfile `
                 $RootPath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed with exit code $LastExitCode"
    }
    Write-Host "SUCCESS"
    Remove-Item $dockerfile -Force

    if ($push) {
        $newtags = @("mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic","mcrbusinesscentral.azurecr.io/public/dynamicsnav:$osversion-generic-$genericTag")
        $newtags | ForEach-Object {
            Write-Host "Push $_"
            docker tag $image $_
            docker push $_
        }
        $newtags | ForEach-Object {
            Write-Host "Remove $_"
            docker rmi $_
        }
        docker rmi $image
    }
}
