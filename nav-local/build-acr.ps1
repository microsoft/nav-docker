Param(
    [string] $acr = "navgeneric",
    [string] $countryurl = "https://bcdocker.blob.core.windows.net/public/dk.zip",
    [string] $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm"),
    [string] $nav = "2017",
    [string] $cu = "cu18",
    [string] $country = "dk",
    [string] $version = "10.0.21832.0",
    [string[]] $oss = @("1803"),
    [string[]] $tags = @("microsoft/dynamics-nav:$nav-$cu-$country",
                         "microsoft/dynamics-nav:$version-$country")
)

$oss | ForEach-Object {

    $osSuffix = "-$_"
    $thisbaseimage = "microsoft/dynamics-nav:$version-w1$osSuffix"
    $image = "nav:$version-$country$osSuffix"

    az acr build --registry $acr `
                 --image $image `
                 --build-arg baseimage=$thisbaseimage `
                 --build-arg created=$created `
                 --build-arg countryurl=$countryurl `
                 --build-arg country=$country `
                 --timeout 10800 `
                 --os Windows `
                 --file DOCKERFILE `
                 https://github.com/Microsoft/nav-docker.git#master:nav-local

    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS"

#        if ($_ -eq "ltsc2016") {
#            $tags | ForEach-Object {
#                docker tag $image $_
#                docker push $_
#            }
#        }

        $tags | ForEach-Object {
            Write-Host $_$ossuffix
            docker tag $image $_$osSuffix
            docker push $_$osSuffix
        }
    }
}
