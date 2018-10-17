Param(
    [string] $acr = "navgeneric",
    [string] $baseimage = "microsoft/dynamics-nav:generic",
    [string] $navdvdurl = "https://bcdocker.blob.core.windows.net/public/NAV.10.0.21832.W1.DVD.zip",
    [string] $legal = "http://go.microsoft.com/fwlink/?LinkId=724017",
    [string] $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm"),
    [string] $nav = "2017",
    [string] $cu = "cu18",
    [string] $country = "w1",
    [string] $version = "10.0.21832.0",
    [string[]] $oss = @("ltsc2016"),
    [string[]] $tags = @("microsoft/dynamics-nav:2017-cu18-w1",
                         "microsoft/dynamics-nav:2017-cu18",
                         "microsoft/dynamics-nav:10.0.21832.0-w1")
)

$oss | ForEach-Object {

    $osSuffix = "-$_"
    $thisbaseimage = "$baseimage$osSuffix"
    $image = "nav:$version-$country$osSuffix"

    docker pull $thisbaseimage
    docker rmi $image -f 2>NULL | Out-Null

    docker build --build-arg baseimage=$thisbaseimage `
                 --build-arg navdvdurl=$navdvdurl `
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

        $tags | ForEach-Object {
            docker tag $image $_$osSuffix
            docker push $_$osSuffix
        }
    }
}
