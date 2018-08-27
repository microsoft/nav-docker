$registry = "microsoft"
$tag = "0.0.6.5"
$latest = $false
$removeImage = $false

"1803","1709" | % {
#"ltsc2016" | % {

    $baseVersionTag = $_
    $baseImage = "microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-$baseVersionTag"
    
    $maintainer = "Dynamics SMB"
    $eula = "https://go.microsoft.com/fwlink/?linkid=861843"
    
    docker pull $baseImage
    $osversion = docker inspect --format "{{.OsVersion}}" $baseImage
    $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")
        
    $imageNameTag = "dynamics-nav:generic"
    $buildImageNameTag = "$imageNameTag-$baseVersionTag"
    Write-Host -ForegroundColor Yellow "Build $buildImageNameTag"

    $imageFolder = $PSScriptRoot
    $dockerFilePath = Join-Path $imageFolder "DOCKERFILE"
    $dockerFile = Get-Content $dockerFilePath
    $dockerFile[0] = "FROM $baseImage"
    $dockerFile | Set-Content $dockerFilePath
        
    docker rmi $buildImageNameTag -f 2>NULL | Out-Null
    docker build --label maintainer="$maintainer" `
                 --label created="$created" `
                 --label tag="$tag" `
                 --label osversion="$osversion" `
                 --label eula="$eula" `
                 -t $buildImageNameTag `
                 $imageFolder
    if ($LastExitCode -ne 0) { throw "Docker build error" }
    
    Write-Host -ForegroundColor Green "Success"
        
    if ($registry -ne "") {
    
        $imageNameTags = @()
        if ($latest) {
            if ($baseVersionTag -eq "ltsc2016") {
                $imageNameTags += "$registry/$imageNameTag"
            }
            $imageNameTags += "$registry/$imageNameTag-$baseVersionTag"
        }
        if ($tag) {
            if ($baseVersionTag -eq "ltsc2016") {
                $imageNameTags += "$registry/$imageNameTag-$tag"
            }
            $imageNameTags += "$registry/$imageNameTag-$tag-$baseVersionTag"
        }
    
        $imageNameTags | % {
            $extraTag = $_
            write-Host -ForegroundColor Yellow "$extraTag"
            docker tag $buildImageNameTag $extraTag
            if ($LastExitCode -ne 0) { throw "Docker tag error" }
            write-Host "push"
            docker push $extraTag | Out-Null
            if ($LastExitCode -ne 0) { throw "Docker push error" }
            write-Host "untag"
            docker rmi $extraTag -f | Out-Null
            if ($LastExitCode -ne 0) { throw "Docker rmi error" }
        }
    }
    
    if ($removeImage) {
        docker rmi $buildImageNameTag -f
        if ($LastExitCode -ne 0) { throw "Docker rmi error" }
    }
}