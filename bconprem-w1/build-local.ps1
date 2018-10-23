Param(
    [string] $acr = "navgeneric",
    [string] $baseimage = "microsoft/dynamics-nav:generic",
    [string] $navdvdurl = "https://bcdocker.blob.core.windows.net/public/NAV.10.0.21832.W1.DVD.zip",
    [string] $vsixurl = "",
    [string] $legal = "http://go.microsoft.com/fwlink/?LinkId=724017",
    [string] $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm"),
    [string] $nav = "2017",
    [string] $cu = "cu18",
    [string] $country = "w1",
    [string] $version = "10.0.21832.0",
    [string[]] $oss = @("ltsc2016"),
    [string[]] $tags = @("microsoft/dynamics-nav:$nav-$cu-$country",
                         "microsoft/dynamics-nav:$nav-$cu",
                         "microsoft/dynamics-nav:$version-$country",
                         "microsoft/dynamics-nav:$version")
)

$oss | ForEach-Object {

    $osSuffix = "-$_"
    $thisbaseimage = "$baseimage$osSuffix"
    $image = "nav:$version-$country$osSuffix"

    docker pull $thisbaseimage
    docker rmi $image -f 2>NULL | Out-Null

    docker build --build-arg baseimage=$thisbaseimage `
                 --build-arg navdvdurl=$navdvdurl `
                 --build-arg vsixurl=$vsixurl `
                 --build-arg legal=$legal `
                 --build-arg created=$created `
                 --build-arg nav=$nav `
                 --build-arg cu=$cu `
                 --build-arg country=$country `
                 --build-arg version=$version `
                 --tag $image `
                 $PSScriptRoot

    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS"

        if ($_ -eq "ltsc2016") {
            $tags | ForEach-Object {
                docker tag $image $_
                docker push $_
            }
        }

        $tags | ForEach-Object {
            docker tag $image $_$osSuffix
            docker push $_$osSuffix
        }
    }
}
