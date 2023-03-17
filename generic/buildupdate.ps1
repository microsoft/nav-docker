$RootPath = $PSScriptRoot
$ErrorActionPreference = "Stop"
$filesOnly = $false

. (Join-Path $RootPath "settings.ps1")

function Head($text) {
    Write-Host -ForegroundColor Yellow $text
}

$testImages = $false

$pushto = @()
$pushto = @("dev")
$pushto += @("prod")

$ver = [Version]"10.0.0.0"
if ($filesOnly) {
    $filesOnlyStr = "-filesonly"
    $tags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/businesscentral").tags | 
        Where-Object { $_ -like "*-filesOnly" -and $_.Split('-').Count -eq 2 } |
        Where-Object { [Version]::TryParse($_.Split('-')[0], [ref] $ver) } | % {
            $_.Split('-')[0]
        }
}
else {
    $filesonlyStr = ""
    $tags = (get-navcontainerimagetags -imageName "mcr.microsoft.com/businesscentral").tags | 
        Where-Object { [Version]::TryParse($_, [ref] $ver) }
}

[Array]::Reverse($tags)

# Pull all
$tags | % {
    $osversion = $_
    head $osversion
    $image = "mcr.microsoft.com/businesscentral:$osversion$filesonlyStr"
    docker pull $image
}

docker system prune --force

if ((Read-Host -prompt "Continue (yes/no)?") -ne "Yes") {
    throw "Mission aborted"
}

$buildrest = $true
#$firstTag = "10.0.19042.572"
$tags | % {
#    if ($_ -eq $firstTag) {
#        $buildRest = $true
#    }
    if ($buildrest) {
        $osversion = $_
        
        head $osversion
        
        $isolation = "hyperv"
        $baseimage = "mcr.microsoft.com/businesscentral:$osversion$filesonlyStr"
    
        docker pull $baseimage
    
        $inspect = docker inspect $baseimage | ConvertFrom-Json
        if ([version]$inspect.config.Labels.tag -ge [version]$generictag) {
            Write-Host -ForegroundColor Green "Image already built"
        }
        else {
            $image = "my:$osversion-$genericTag$filesonlyStr"
        
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
    

            $success = $false
            try {
                docker build --isolation=$isolation `
                             --tag $image `
                             --file $dockerfile `
                             --memory 4G `
                             $RootPath | % {
                   $_ | Out-Host
                   if ($_ -like "Successfully built*") {
                       $success = $true
                   }
                }
            } catch {}
            if (!$success) {
                if ($LASTEXITCODE -ne 0) {
                    throw "Docker Build failed with exit code $LastExitCode"
                } else {
                    throw "Docker Build didn't indicate successfully built"
                }
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
                    "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion$filesonlyStr-dev"
                )
            }
            if ($pushto.Contains("prod")) {
                $newtags += @(
                    "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion$filesonlyStr",
                    "mcrbusinesscentral.azurecr.io/public/businesscentral:$osversion-$genericTag$filesonlyStr")
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
            docker rmi $image
        }
    }
}
