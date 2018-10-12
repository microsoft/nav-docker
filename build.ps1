$registry = "" #"microsoft"
$tag = "0.0.7.0"
$latest = $false
$removeImage = $false
$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")

"ltsc2016","1803","1709" | ForEach-Object {

    $baseVersionTag = $_
    $imageNameTag = "dynamics-nav:generic"
    $buildImageNameTag = "$imageNameTag-$baseVersionTag"
    Write-Host -ForegroundColor Yellow "Build $buildImageNameTag"

    $imageFolder = $PSScriptRoot
    $dockerFilePath = Join-Path $imageFolder "DOCKERFILE"
        
    docker rmi $buildImageNameTag -f 2>NULL | Out-Null
    docker build --build-arg created="$created" `
                 --build-arg tag="$tag" `
                 --tag $buildImageNameTag `
                 --file $dockerFilePath
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