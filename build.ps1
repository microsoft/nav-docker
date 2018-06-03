$registry = "microsoft"
$tag = "0.0.6.0"
$latest = $false

# "1803","1709","ltsc2016" | % {

"ltsc2016" | % {

    $baseVersionTag = $_
    $baseImage = "microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-$baseVersionTag"
    
    $maintainer = "Dynamics SMB"
    $eula = "https://go.microsoft.com/fwlink/?linkid=861843"
    
    $removeImage = $false
    
    docker pull $baseImage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage
    $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")
        
    $imageNameTag = "dynamics-nav:generic"
    Write-Host -ForegroundColor Yellow "Build $imageNameTag-$baseVersionTag"

    $imageFolder = $PSScriptRoot
    $dockerFilePath = Join-Path $imageFolder "DOCKERFILE"
    $dockerFile = Get-Content $dockerFilePath
    $dockerFile[0] = "FROM $baseImage"
    $dockerFile | Set-Content $dockerFilePath
        
    docker rmi $imageNameTag -f 2>NULL | Out-Null
    docker build --label maintainer="$maintainer" `
                 --label created="$created" `
                 --label tag="$tag" `
                 --label osversion="$osversion" `
                 --label eula="$eula" `
                 -t $imageNameTag `
                 $imageFolder
        
    if ($LastExitCode -ne 0) {
        throw "Docker build error"
    }
    
    Write-Host -ForegroundColor Green "Success"
        
    if ($registry -ne "") {
    
        $imageNameTags = @()
        if ($latest) {
            $imageNameTags += "$registry/$imageNameTag"
            $imageNameTags += "$registry/$imageNameTag-$baseVersionTag"
        }
        if ($tag) {
            $imageNameTags += "$registry/$imageNameTag-$tag"
            $imageNameTags += "$registry/$imageNameTag-$tag-$baseVersionTag"
        }
    
        $imageNameTags | % {
            $extraTag = $_
            write-Host -ForegroundColor Yellow "$extraTag"
            docker tag $imageNameTag $extraTag
            docker push $extraTag | Out-Null
            docker rmi $extraTag -f
        }
    }
    
    if ($removeImage) {
        docker rmi $imageNameTag -f
    }
}